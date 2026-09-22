package com.example.my_first_app

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.provider.MediaStore
import android.util.Size
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer

/**
 * Records both cameras into one video: the back lens filling a landscape
 * frame, the front lens inset over it the way a streamer's facecam sits on
 * their gameplay.
 *
 * The two cameras cannot be muxed together after the fact, so they are
 * composited live. Each camera gets its own SurfaceTexture here, an OpenGL
 * thread draws both into the encoder's input surface, and MediaCodec turns
 * that into H.264. The preview path is untouched: these are additional
 * camera outputs, and if the device refuses to give a second stream per
 * camera the preview still runs and only recording is unavailable.
 */
class DualRecorder(private val context: Context) {

    /** What one camera contributes: a texture, and the surface it fills. */
    private class Input(
        val textureId: Int,
        val surfaceTexture: SurfaceTexture,
        val surface: Surface,
        val size: Size,
    ) {
        val matrix = FloatArray(16)
        var hasFrame = false
    }

    // ── configuration ────────────────────────────────────────────────────

    var backRotation = 0
    var frontRotation = 0
    var mirrorFront = false

    // ── GL ───────────────────────────────────────────────────────────────

    private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var config: EGLConfig? = null
    private var offscreen: EGLSurface = EGL14.EGL_NO_SURFACE
    private var target: EGLSurface = EGL14.EGL_NO_SURFACE

    private val composite = GlComposite()
    private var back: Input? = null
    private var front: Input? = null

    private var thread: HandlerThread? = null
    private var handler: Handler? = null

    // ── encoding ─────────────────────────────────────────────────────────

    private var encoder: MediaCodec? = null
    private var encoderSurface: Surface? = null
    private var muxer: MediaMuxer? = null
    private var videoTrack = -1
    private var audioTrack = -1
    private var muxing = false
    private val muxerLock = Object()

    private var audio: AudioCapture? = null
    private var wantAudio = false

    private var file: File? = null
    private var recording = false
    private var startedAtNanos = 0L
    private var firstFrameNanos = -1L
    private var frames = 0

    fun isRecording(): Boolean = recording
    fun isReady(): Boolean = back != null && front != null

    /** Milliseconds of video written so far. */
    fun elapsedMillis(): Long =
        if (!recording || startedAtNanos == 0L) 0L
        else (System.nanoTime() - startedAtNanos) / 1_000_000L

    // ── setting up the camera outputs ────────────────────────────────────

    /**
     * Builds the two surfaces the camera session should also render into.
     *
     * Called before the capture session is configured, because a session's
     * outputs are fixed once it exists. Returns null if the GL context will
     * not come up, in which case the caller simply configures preview alone.
     */
    fun prepareInputs(backSize: Size, frontSize: Size): Pair<Surface, Surface>? {
        if (isReady()) {
            return Pair(back!!.surface, front!!.surface)
        }

        val t = HandlerThread("exitzero-dual-recorder").also { it.start() }
        thread = t
        val h = Handler(t.looper)
        handler = h

        var built: Pair<Surface, Surface>? = null
        val done = Object()

        h.post {
            try {
                setUpEgl()
                composite.setUp()
                back = newInput(backSize)
                front = newInput(frontSize)
                built = Pair(back!!.surface, front!!.surface)
            } catch (e: Exception) {
                teardownEgl()
                back = null
                front = null
            }
            synchronized(done) { done.notifyAll() }
        }

        synchronized(done) {
            try {
                done.wait(4000)
            } catch (_: InterruptedException) {
            }
        }

        if (built == null) {
            stopThread()
        }
        return built
    }

    private fun newInput(size: Size): Input {
        val textureId = composite.newTexture()
        val surfaceTexture = SurfaceTexture(textureId)
        surfaceTexture.setDefaultBufferSize(size.width, size.height)
        val input = Input(textureId, surfaceTexture, Surface(surfaceTexture), size)

        // Frames must be consumed even when nothing is being recorded: an
        // unread buffer queue fills up and stalls the camera, which would
        // take the live preview down with it.
        surfaceTexture.setOnFrameAvailableListener({ st ->
            handler?.post { onFrame(input, st) }
        }, handler)

        return input
    }

    private fun onFrame(input: Input, st: SurfaceTexture) {
        try {
            if (eglContext == EGL14.EGL_NO_CONTEXT) return
            makeCurrent(if (recording && target != EGL14.EGL_NO_SURFACE) target else offscreen)
            st.updateTexImage()
            st.getTransformMatrix(input.matrix)
            input.hasFrame = true
        } catch (_: Exception) {
            return
        }

        // The back lens drives the frame rate; the front simply contributes
        // whatever it last delivered, so a slower selfie camera cannot halve
        // the recording's frame rate.
        if (recording && input === back) render(st.timestamp)
    }

    // ── recording ────────────────────────────────────────────────────────

    /** Starts a recording. Returns an error to show the user, or null. */
    fun start(withAudio: Boolean): String? {
        if (recording) return "Already recording."
        if (!isReady()) return "The recorder did not get its camera streams."

        wantAudio = withAudio &&
            context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

        val outputFile = File(
            context.cacheDir,
            "exitzero-rec-${System.currentTimeMillis()}.mp4",
        )

        var error: String? = null
        val done = Object()

        handler?.post {
            try {
                startOnGlThread(outputFile)
            } catch (e: Exception) {
                error = e.message ?: "Could not start recording."
                cleanUpEncoder()
                try { outputFile.delete() } catch (_: Exception) {}
            }
            synchronized(done) { done.notifyAll() }
        } ?: return "The recorder is not running."

        synchronized(done) {
            try {
                done.wait(6000)
            } catch (_: InterruptedException) {
            }
        }

        return error
    }

    private fun startOnGlThread(outputFile: File) {
        val format = MediaFormat.createVideoFormat(
            MediaFormat.MIMETYPE_VIDEO_AVC,
            WIDTH,
            HEIGHT,
        ).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, VIDEO_BITRATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val input = codec.createInputSurface()
        codec.start()

        encoder = codec
        encoderSurface = input

        target = EGL14.eglCreateWindowSurface(
            display,
            config,
            input,
            intArrayOf(EGL14.EGL_NONE),
            0,
        )
        if (target == EGL14.EGL_NO_SURFACE) {
            throw RuntimeException("Could not attach to the encoder.")
        }

        muxer = MediaMuxer(
            outputFile.absolutePath,
            MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4,
        )
        videoTrack = -1
        audioTrack = -1
        muxing = false
        frames = 0
        firstFrameNanos = -1L
        file = outputFile

        if (wantAudio) {
            audio = AudioCapture(
                muxerLock = muxerLock,
                provideMuxer = { muxer },
                onTrack = { trackFormat ->
                    synchronized(muxerLock) {
                        if (audioTrack < 0) {
                            audioTrack = muxer?.addTrack(trackFormat) ?: -1
                            maybeStartMuxer()
                        }
                        audioTrack
                    }
                },
                isMuxing = { muxing },
            ).also {
                if (!it.start()) {
                    // Losing the microphone is not a reason to lose the video.
                    audio = null
                    wantAudio = false
                }
            }
        }

        startedAtNanos = System.nanoTime()
        recording = true
    }

    /** Called with the muxer lock held. */
    private fun maybeStartMuxer() {
        if (muxing) return
        if (videoTrack < 0) return
        if (wantAudio && audioTrack < 0) return
        try {
            muxer?.start()
            muxing = true
        } catch (_: Exception) {
            muxing = false
        }
    }

    private fun render(timestampNanos: Long) {
        if (encoder == null) return
        val backInput = back ?: return
        if (!backInput.hasFrame) return

        try {
            makeCurrent(target)
            GLES20.glViewport(0, 0, WIDTH, HEIGHT)
            composite.clear()

            // Cover, not fit: a landscape video should be filled edge to
            // edge, with whatever hangs over the sides cropped away.
            composite.draw(
                textureId = backInput.textureId,
                stMatrix = backInput.matrix,
                sourceWidth = backInput.size.width,
                sourceHeight = backInput.size.height,
                rotation = backRotation,
                mirror = false,
                left = -1f, top = 1f, right = 1f, bottom = -1f,
                viewportWidth = WIDTH, viewportHeight = HEIGHT,
                cover = true,
            )

            val frontInput = front
            if (frontInput != null && frontInput.hasFrame) {
                composite.panel(
                    PIP_LEFT, PIP_TOP, PIP_RIGHT, PIP_BOTTOM,
                    3, WIDTH, HEIGHT,
                )
                composite.draw(
                    textureId = frontInput.textureId,
                    stMatrix = frontInput.matrix,
                    sourceWidth = frontInput.size.width,
                    sourceHeight = frontInput.size.height,
                    rotation = frontRotation,
                    mirror = mirrorFront,
                    left = PIP_LEFT, top = PIP_TOP,
                    right = PIP_RIGHT, bottom = PIP_BOTTOM,
                    viewportWidth = WIDTH, viewportHeight = HEIGHT,
                    cover = true,
                )
            }

            // Presentation times start at zero, or every player shows the
            // clip as beginning hours into a timeline.
            if (firstFrameNanos < 0) firstFrameNanos = timestampNanos
            val presentation = timestampNanos - firstFrameNanos

            EGLExt.eglPresentationTimeANDROID(display, target, presentation)
            EGL14.eglSwapBuffers(display, target)
            frames++

            drainVideo(endOfStream = false)
        } catch (_: Exception) {
            // A dropped frame is survivable; the next one will try again.
        }
    }

    private fun drainVideo(endOfStream: Boolean) {
        val codec = encoder ?: return
        if (endOfStream) {
            try { codec.signalEndOfInputStream() } catch (_: Exception) {}
        }

        val info = MediaCodec.BufferInfo()
        // Bounded, because an encoder that never reports end of stream would
        // otherwise hang stop() on the GL thread forever.
        var attemptsLeft = if (endOfStream) 250 else Int.MAX_VALUE

        while (attemptsLeft-- > 0) {
            val index = try {
                codec.dequeueOutputBuffer(info, if (endOfStream) 10_000 else 0)
            } catch (_: Exception) {
                return
            }

            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return
                    // Keep waiting: the tail of the stream is still coming.
                }

                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    synchronized(muxerLock) {
                        if (videoTrack < 0) {
                            videoTrack = muxer?.addTrack(codec.outputFormat) ?: -1
                            maybeStartMuxer()
                        }
                    }
                }

                index >= 0 -> {
                    val buffer = try {
                        codec.getOutputBuffer(index)
                    } catch (_: Exception) {
                        null
                    }

                    // Codec config bytes go into the track format, not the
                    // stream; the muxer has already taken them.
                    val isConfig =
                        info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0

                    if (buffer != null && !isConfig && info.size > 0) {
                        synchronized(muxerLock) {
                            if (muxing && videoTrack >= 0) {
                                buffer.position(info.offset)
                                buffer.limit(info.offset + info.size)
                                try {
                                    muxer?.writeSampleData(videoTrack, buffer, info)
                                } catch (_: Exception) {
                                }
                            }
                        }
                    }

                    try { codec.releaseOutputBuffer(index, false) } catch (_: Exception) {}

                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        return
                    }
                }
            }
        }
    }

    /**
     * Ends the recording and files the result in the gallery.
     *
     * Reports the saved name, or why nothing was saved. A recording that
     * caught no frames is deleted rather than published, since a zero byte
     * entry in the gallery is worse than none.
     */
    fun stop(done: (Map<String, Any?>) -> Unit) {
        if (!recording) {
            done(mapOf("ok" to false, "error" to "Not recording."))
            return
        }
        recording = false

        val h = handler
        if (h == null) {
            done(mapOf("ok" to false, "error" to "The recorder is gone."))
            return
        }

        h.post {
            val captured = frames
            try {
                audio?.stop()
                audio = null

                makeCurrent(if (target != EGL14.EGL_NO_SURFACE) target else offscreen)
                drainVideo(endOfStream = true)
            } catch (_: Exception) {
            }

            synchronized(muxerLock) {
                try {
                    if (muxing) muxer?.stop()
                } catch (_: Exception) {
                }
                try { muxer?.release() } catch (_: Exception) {}
                muxer = null
                muxing = false
            }

            cleanUpEncoder()

            val recorded = file
            file = null

            if (recorded == null || !recorded.exists() || recorded.length() == 0L ||
                captured == 0
            ) {
                try { recorded?.delete() } catch (_: Exception) {}
                done(
                    mapOf(
                        "ok" to false,
                        "error" to "Nothing was captured.",
                    ),
                )
                return@post
            }

            done(publish(recorded, captured))
        }
    }

    private fun cleanUpEncoder() {
        try { encoder?.stop() } catch (_: Exception) {}
        try { encoder?.release() } catch (_: Exception) {}
        encoder = null

        if (target != EGL14.EGL_NO_SURFACE) {
            try { EGL14.eglDestroySurface(display, target) } catch (_: Exception) {}
            target = EGL14.EGL_NO_SURFACE
        }
        try { encoderSurface?.release() } catch (_: Exception) {}
        encoderSurface = null

        try { makeCurrent(offscreen) } catch (_: Exception) {}
    }

    /** Copies the finished file into the gallery's Movies collection. */
    private fun publish(source: File, captured: Int): Map<String, Any?> {
        val name = "ExitZero-${System.currentTimeMillis()}.mp4"
        val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val resolver = context.contentResolver
        val legacy = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

        return try {
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, name)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                if (legacy) {
                    val dir = File(
                        android.os.Environment.getExternalStoragePublicDirectory(
                            android.os.Environment.DIRECTORY_MOVIES,
                        ),
                        "ExitZero",
                    )
                    if (!dir.exists()) dir.mkdirs()
                    put(MediaStore.Video.Media.DATA, File(dir, name).absolutePath)
                } else {
                    put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/ExitZero")
                    put(MediaStore.Video.Media.IS_PENDING, 1)
                }
            }

            val uri = resolver.insert(collection, values)
                ?: return mapOf(
                    "ok" to false,
                    "error" to "The gallery refused to create the file.",
                )

            resolver.openOutputStream(uri)?.use { out ->
                source.inputStream().use { it.copyTo(out) }
            } ?: run {
                resolver.delete(uri, null, null)
                return mapOf("ok" to false, "error" to "Could not write the file.")
            }

            if (!legacy) {
                resolver.update(
                    uri,
                    ContentValues().apply {
                        put(MediaStore.Video.Media.IS_PENDING, 0)
                    },
                    null,
                    null,
                )
            }

            try { source.delete() } catch (_: Exception) {}

            mapOf(
                "ok" to true,
                "name" to name,
                "uri" to uri.toString(),
                "frames" to captured,
                "withAudio" to wantAudio,
            )
        } catch (e: Exception) {
            try { source.delete() } catch (_: Exception) {}
            mapOf("ok" to false, "error" to (e.message ?: "Could not save."))
        }
    }

    // ── teardown ─────────────────────────────────────────────────────────

    fun release() {
        recording = false
        val h = handler
        if (h != null) {
            val done = Object()
            h.post {
                try { audio?.stop() } catch (_: Exception) {}
                audio = null
                cleanUpEncoder()
                synchronized(muxerLock) {
                    try { muxer?.release() } catch (_: Exception) {}
                    muxer = null
                    muxing = false
                }
                try { file?.delete() } catch (_: Exception) {}
                file = null

                back?.let {
                    try { it.surface.release() } catch (_: Exception) {}
                    try { it.surfaceTexture.release() } catch (_: Exception) {}
                }
                front?.let {
                    try { it.surface.release() } catch (_: Exception) {}
                    try { it.surfaceTexture.release() } catch (_: Exception) {}
                }
                back = null
                front = null

                try { composite.release() } catch (_: Exception) {}
                teardownEgl()
                synchronized(done) { done.notifyAll() }
            }
            synchronized(done) {
                try { done.wait(3000) } catch (_: InterruptedException) {}
            }
        }
        stopThread()
    }

    private fun stopThread() {
        try { thread?.quitSafely() } catch (_: Exception) {}
        thread = null
        handler = null
    }

    // ── EGL plumbing ─────────────────────────────────────────────────────

    private fun setUpEgl() {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (display == EGL14.EGL_NO_DISPLAY) {
            throw RuntimeException("No EGL display.")
        }

        val version = IntArray(2)
        if (!EGL14.eglInitialize(display, version, 0, version, 1)) {
            throw RuntimeException("Could not initialise EGL.")
        }

        // EGL_RECORDABLE_ANDROID is what lets the output feed a video
        // encoder rather than only a display.
        val attributes = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL_RECORDABLE_ANDROID, 1,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val count = IntArray(1)
        if (!EGL14.eglChooseConfig(
                display, attributes, 0, configs, 0, 1, count, 0,
            ) || count[0] <= 0
        ) {
            throw RuntimeException("No usable EGL config.")
        }
        config = configs[0]

        eglContext = EGL14.eglCreateContext(
            display,
            config,
            EGL14.EGL_NO_CONTEXT,
            intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE),
            0,
        )
        if (eglContext == EGL14.EGL_NO_CONTEXT) {
            throw RuntimeException("Could not create a GL context.")
        }

        // Something has to be current before textures can be made, and there
        // is no encoder surface yet.
        offscreen = EGL14.eglCreatePbufferSurface(
            display,
            config,
            intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE),
            0,
        )
        if (offscreen == EGL14.EGL_NO_SURFACE) {
            throw RuntimeException("Could not create the offscreen surface.")
        }

        makeCurrent(offscreen)
    }

    private fun makeCurrent(surface: EGLSurface) {
        if (surface == EGL14.EGL_NO_SURFACE) return
        EGL14.eglMakeCurrent(display, surface, surface, eglContext)
    }

    private fun teardownEgl() {
        if (display != EGL14.EGL_NO_DISPLAY) {
            try {
                EGL14.eglMakeCurrent(
                    display,
                    EGL14.EGL_NO_SURFACE,
                    EGL14.EGL_NO_SURFACE,
                    EGL14.EGL_NO_CONTEXT,
                )
                if (offscreen != EGL14.EGL_NO_SURFACE) {
                    EGL14.eglDestroySurface(display, offscreen)
                }
                if (eglContext != EGL14.EGL_NO_CONTEXT) {
                    EGL14.eglDestroyContext(display, eglContext)
                }
                EGL14.eglReleaseThread()
                EGL14.eglTerminate(display)
            } catch (_: Exception) {
            }
        }
        offscreen = EGL14.EGL_NO_SURFACE
        eglContext = EGL14.EGL_NO_CONTEXT
        display = EGL14.EGL_NO_DISPLAY
        config = null
    }

    private companion object {
        const val WIDTH = 1280
        const val HEIGHT = 720
        const val VIDEO_BITRATE = 6_000_000
        const val FRAME_RATE = 30
        const val EGL_RECORDABLE_ANDROID = 0x3142

        // The facecam: bottom right, a quarter of the width, with a margin.
        // Exactly 16:9 in pixels (320x180 of 1280x720), so a landscape face
        // fills it without bars: half a clip unit is half the frame on both
        // axes, and the frame's own aspect does the rest.
        const val PIP_RIGHT = 0.94f
        const val PIP_LEFT = 0.44f
        const val PIP_BOTTOM = -0.92f
        const val PIP_TOP = -0.42f
    }
}

/**
 * Microphone track for a recording.
 *
 * Kept apart from the video path deliberately: if the microphone is refused
 * or the encoder will not start, the recording carries on without sound
 * rather than failing outright.
 */
private class AudioCapture(
    private val muxerLock: Object,
    private val provideMuxer: () -> MediaMuxer?,
    private val onTrack: (MediaFormat) -> Int,
    private val isMuxing: () -> Boolean,
) {
    private var recorder: AudioRecord? = null
    private var encoder: MediaCodec? = null
    private var thread: Thread? = null
    @Volatile private var running = false
    private var track = -1

    fun start(): Boolean {
        return try {
            val minBuffer = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            if (minBuffer <= 0) return false

            val format = MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC,
                SAMPLE_RATE,
                1,
            ).apply {
                setInteger(
                    MediaFormat.KEY_AAC_PROFILE,
                    MediaCodecInfo.CodecProfileLevel.AACObjectLC,
                )
                setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, minBuffer * 2)
            }

            val codec = MediaCodec.createEncoderByType(
                MediaFormat.MIMETYPE_AUDIO_AAC,
            )
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            encoder = codec

            val source = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                minBuffer * 4,
            )
            if (source.state != AudioRecord.STATE_INITIALIZED) {
                source.release()
                codec.stop()
                codec.release()
                encoder = null
                return false
            }
            recorder = source
            source.startRecording()

            running = true
            thread = Thread { pump(minBuffer) }.also { it.start() }
            true
        } catch (_: Exception) {
            stop()
            false
        }
    }

    private fun pump(bufferSize: Int) {
        val codec = encoder ?: return
        val source = recorder ?: return
        val buffer = ByteArray(bufferSize)
        val info = MediaCodec.BufferInfo()
        var samples = 0L

        while (running) {
            try {
                val read = source.read(buffer, 0, buffer.size)
                if (read > 0) {
                    val index = codec.dequeueInputBuffer(10_000)
                    if (index >= 0) {
                        val input: ByteBuffer? = codec.getInputBuffer(index)
                        input?.clear()
                        input?.put(buffer, 0, read)
                        // Timestamps derived from samples, not the clock:
                        // the wall clock drifts against the audio and the
                        // track slowly slides out of sync with the video.
                        val presentation = samples * 1_000_000L / SAMPLE_RATE
                        samples += read / 2
                        codec.queueInputBuffer(index, 0, read, presentation, 0)
                    }
                }
                drain(info)
            } catch (_: Exception) {
                break
            }
        }

        try {
            val index = codec.dequeueInputBuffer(10_000)
            if (index >= 0) {
                codec.queueInputBuffer(
                    index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                )
            }
            drain(info)
        } catch (_: Exception) {
        }
    }

    private fun drain(info: MediaCodec.BufferInfo) {
        val codec = encoder ?: return
        while (true) {
            val index = codec.dequeueOutputBuffer(info, 0)
            if (index == MediaCodec.INFO_TRY_AGAIN_LATER) return
            if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                track = onTrack(codec.outputFormat)
                continue
            }
            if (index < 0) return

            val buffer = codec.getOutputBuffer(index)
            val isConfig =
                info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0

            if (buffer != null && !isConfig && info.size > 0) {
                synchronized(muxerLock) {
                    // Samples that arrive before both tracks are registered
                    // are dropped; that is a few milliseconds at the very
                    // start, and buffering them would not be worth the code.
                    if (isMuxing() && track >= 0) {
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        try {
                            provideMuxer()?.writeSampleData(track, buffer, info)
                        } catch (_: Exception) {
                        }
                    }
                }
            }

            codec.releaseOutputBuffer(index, false)
            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
        }
    }

    fun stop() {
        running = false
        try { thread?.join(1500) } catch (_: Exception) {}
        thread = null
        try { recorder?.stop() } catch (_: Exception) {}
        try { recorder?.release() } catch (_: Exception) {}
        recorder = null
        try { encoder?.stop() } catch (_: Exception) {}
        try { encoder?.release() } catch (_: Exception) {}
        encoder = null
    }

    private companion object {
        const val SAMPLE_RATE = 44100
    }
}
