package com.example.my_first_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.SessionConfiguration
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Size
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.util.concurrent.Executor

/**
 * Streams a front and a back camera at the same time.
 *
 * Flutter's camera plugin opens one camera and has no concurrent API, so this
 * goes to Camera2 directly. Simultaneous streaming is an optional feature
 * added in Android 11: getConcurrentCameraIds() lists the id combinations the
 * hardware can actually run together, and only a combination holding one
 * front-facing and one back-facing camera is any use here.
 *
 * Each camera renders into its own Flutter texture, so Dart just shows two
 * Texture widgets and never touches a frame. Nothing is captured or written.
 */
class DualCamera(
    private val context: Context,
    private val textures: TextureRegistry,
) {

    private class Feed(
        val lens: String,
        val cameraId: String,
        val entry: TextureRegistry.SurfaceTextureEntry,
    ) {
        var device: CameraDevice? = null
        var session: CameraCaptureSession? = null
        var surface: Surface? = null
        var size: Size = Size(1280, 720)
        var sensorOrientation: Int = 0
    }

    private val feeds = mutableListOf<Feed>()
    private var thread: HandlerThread? = null
    private var handler: Handler? = null

    /** Guards against a second start arriving while the first is mid-flight. */
    private var starting = false

    fun isRunning(): Boolean = feeds.isNotEmpty()

    // ── start ────────────────────────────────────────────────────────────────

    fun start(done: (Map<String, Any>?, String?) -> Unit) {
        if (isRunning()) {
            done(describe(), null)
            return
        }
        if (starting) {
            done(null, "Already starting.")
            return
        }
        if (context.checkSelfPermission(Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            done(null, "Camera permission is not granted.")
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            done(null, "Needs Android 11 or newer for concurrent cameras.")
            return
        }

        val manager =
            context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
        if (manager == null) {
            done(null, "No camera service.")
            return
        }

        val pair = pickFrontAndBack(manager)
        if (pair == null) {
            done(null, "This device has no concurrent front+back combination.")
            return
        }

        starting = true
        startThread()

        try {
            // Back first, so it is index 0 for the Dart side.
            feeds.add(buildFeed(manager, "back", pair.first))
            feeds.add(buildFeed(manager, "front", pair.second))
        } catch (e: Exception) {
            starting = false
            stop()
            done(null, "Could not prepare the cameras: ${e.message}")
            return
        }

        // Open one, then the next, then configure each in turn. Chaining is
        // easier to reason about than two open callbacks racing, and if the
        // second camera refuses -- which is how a device that cannot really do
        // this fails -- there is one obvious place it goes wrong.
        openNext(manager, 0, done)
    }

    private fun openNext(
        manager: CameraManager,
        index: Int,
        done: (Map<String, Any>?, String?) -> Unit,
    ) {
        if (index >= feeds.size) {
            configureNext(0, done)
            return
        }

        val feed = feeds[index]
        try {
            manager.openCamera(
                feed.cameraId,
                object : CameraDevice.StateCallback() {
                    override fun onOpened(device: CameraDevice) {
                        feed.device = device
                        openNext(manager, index + 1, done)
                    }

                    override fun onDisconnected(device: CameraDevice) {
                        device.close()
                        feed.device = null
                        fail(done, "The ${feed.lens} camera disconnected.")
                    }

                    override fun onError(device: CameraDevice, error: Int) {
                        device.close()
                        feed.device = null
                        val why = when (error) {
                            ERROR_CAMERA_IN_USE -> "already in use"
                            ERROR_MAX_CAMERAS_IN_USE ->
                                "too many cameras open at once"
                            ERROR_CAMERA_DISABLED -> "disabled by policy"
                            ERROR_CAMERA_DEVICE -> "device error"
                            ERROR_CAMERA_SERVICE -> "camera service error"
                            else -> "error $error"
                        }
                        fail(done, "The ${feed.lens} camera failed: $why.")
                    }
                },
                handler,
            )
        } catch (e: SecurityException) {
            fail(done, "Camera permission was refused.")
        } catch (e: Exception) {
            fail(done, "Could not open the ${feed.lens} camera: ${e.message}")
        }
    }

    private fun configureNext(
        index: Int,
        done: (Map<String, Any>?, String?) -> Unit,
    ) {
        if (index >= feeds.size) {
            starting = false
            done(describe(), null)
            return
        }

        val feed = feeds[index]
        val device = feed.device
        val surface = feed.surface
        if (device == null || surface == null) {
            fail(done, "The ${feed.lens} camera was not ready.")
            return
        }

        val executor = Executor { r -> handler?.post(r) ?: r.run() }

        try {
            device.createCaptureSession(
                SessionConfiguration(
                    SessionConfiguration.SESSION_REGULAR,
                    listOf(OutputConfiguration(surface)),
                    executor,
                    object : CameraCaptureSession.StateCallback() {
                        override fun onConfigured(session: CameraCaptureSession) {
                            feed.session = session
                            try {
                                val request = device
                                    .createCaptureRequest(
                                        CameraDevice.TEMPLATE_PREVIEW,
                                    )
                                    .apply { addTarget(surface) }
                                    .build()
                                session.setRepeatingRequest(request, null, handler)
                                configureNext(index + 1, done)
                            } catch (e: Exception) {
                                fail(
                                    done,
                                    "Could not start the ${feed.lens} " +
                                        "preview: ${e.message}",
                                )
                            }
                        }

                        override fun onConfigureFailed(
                            session: CameraCaptureSession,
                        ) {
                            fail(
                                done,
                                "The ${feed.lens} camera would not configure " +
                                    "alongside the other one.",
                            )
                        }
                    },
                ),
            )
        } catch (e: Exception) {
            fail(done, "Session setup failed: ${e.message}")
        }
    }

    private fun fail(done: (Map<String, Any>?, String?) -> Unit, message: String) {
        starting = false
        stop()
        done(null, message)
    }

    // ── stop ─────────────────────────────────────────────────────────────────

    fun stop() {
        for (feed in feeds) {
            try { feed.session?.stopRepeating() } catch (_: Exception) {}
            try { feed.session?.close() } catch (_: Exception) {}
            try { feed.device?.close() } catch (_: Exception) {}
            try { feed.surface?.release() } catch (_: Exception) {}
            try { feed.entry.release() } catch (_: Exception) {}
        }
        feeds.clear()
        starting = false
        stopThread()
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    /** A concurrent combination holding one back camera and one front one. */
    private fun pickFrontAndBack(manager: CameraManager): Pair<String, String>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null

        val facing = HashMap<String, Int?>()
        for (id in manager.cameraIdList) {
            facing[id] = manager.getCameraCharacteristics(id)
                .get(CameraCharacteristics.LENS_FACING)
        }

        for (combo in manager.concurrentCameraIds) {
            val back = combo.firstOrNull {
                facing[it] == CameraCharacteristics.LENS_FACING_BACK
            }
            val front = combo.firstOrNull {
                facing[it] == CameraCharacteristics.LENS_FACING_FRONT
            }
            if (back != null && front != null) return Pair(back, front)
        }
        return null
    }

    private fun buildFeed(
        manager: CameraManager,
        lens: String,
        cameraId: String,
    ): Feed {
        val entry = textures.createSurfaceTexture()
        val feed = Feed(lens, cameraId, entry)

        val characteristics = manager.getCameraCharacteristics(cameraId)
        feed.sensorOrientation =
            characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0

        // Running two cameras at once caps what each may stream, so stay well
        // inside the guaranteed envelope rather than asking for the sensor's
        // largest size and having the session refuse to configure.
        val map = characteristics.get(
            CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP,
        )
        val sizes = map?.getOutputSizes(SurfaceTexture::class.java)
        feed.size = sizes
            ?.filter { it.width <= 1280 && it.height <= 720 }
            ?.maxByOrNull { it.width.toLong() * it.height }
            ?: Size(640, 480)

        val texture = entry.surfaceTexture()
        texture.setDefaultBufferSize(feed.size.width, feed.size.height)
        feed.surface = Surface(texture)
        return feed
    }

    private fun describe(): Map<String, Any> = mapOf(
        "feeds" to feeds.map {
            mapOf(
                "lens" to it.lens,
                "textureId" to it.entry.id(),
                "width" to it.size.width,
                "height" to it.size.height,
                "sensorOrientation" to it.sensorOrientation,
            )
        },
    )

    private fun startThread() {
        if (thread != null) return
        val t = HandlerThread("exitzero-dual-camera").also { it.start() }
        thread = t
        handler = Handler(t.looper)
    }

    private fun stopThread() {
        try { thread?.quitSafely() } catch (_: Exception) {}
        thread = null
        handler = null
    }
}
