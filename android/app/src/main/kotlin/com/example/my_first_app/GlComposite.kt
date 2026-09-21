package com.example.my_first_app

import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.Matrix
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Draws camera textures into a frame.
 *
 * Camera frames arrive as GL_TEXTURE_EXTERNAL_OES, which needs its own
 * sampler extension, so this cannot use the ordinary 2D path. Each draw
 * places one camera into a rectangle of the output: the back lens fills the
 * frame, the front sits in a corner over it.
 */
class GlComposite {

    private var program = 0
    private var aPosition = 0
    private var aTexCoord = 0
    private var uMvp = 0
    private var uTexMatrix = 0

    private val quad: FloatBuffer
    private val mvp = FloatArray(16)
    private val texture = FloatArray(16)
    private val scratch = FloatArray(16)

    init {
        // A triangle strip covering the unit square, positions in clip space
        // and texture coordinates alongside them.
        val vertices = floatArrayOf(
            -1f, -1f, 0f, 0f,
            1f, -1f, 1f, 0f,
            -1f, 1f, 0f, 1f,
            1f, 1f, 1f, 1f,
        )
        quad = ByteBuffer
            .allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                put(vertices)
                position(0)
            }
    }

    fun setUp() {
        val vertex = compile(GLES20.GL_VERTEX_SHADER, VERTEX_SHADER)
        val fragment = compile(GLES20.GL_FRAGMENT_SHADER, FRAGMENT_SHADER)

        program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vertex)
        GLES20.glAttachShader(program, fragment)
        GLES20.glLinkProgram(program)

        val linked = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linked, 0)
        if (linked[0] != GLES20.GL_TRUE) {
            val log = GLES20.glGetProgramInfoLog(program)
            GLES20.glDeleteProgram(program)
            program = 0
            throw RuntimeException("Could not link the compositor: $log")
        }

        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
        uMvp = GLES20.glGetUniformLocation(program, "uMvp")
        uTexMatrix = GLES20.glGetUniformLocation(program, "uTexMatrix")

        GLES20.glDeleteShader(vertex)
        GLES20.glDeleteShader(fragment)
    }

    /** A new OES texture id for a camera to render into. */
    fun newTexture(): Int {
        val ids = IntArray(1)
        GLES20.glGenTextures(1, ids, 0)
        val id = ids[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, id)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MIN_FILTER,
            GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MAG_FILTER,
            GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_S,
            GLES20.GL_CLAMP_TO_EDGE,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_T,
            GLES20.GL_CLAMP_TO_EDGE,
        )
        return id
    }

    fun clear() {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
    }

    /**
     * Draws one camera into a rectangle of the output.
     *
     * [left], [top], [right] and [bottom] are in clip space, -1 to 1, with
     * +1 at the top. [stMatrix] is whatever the SurfaceTexture reported for
     * this frame; [rotation] and [mirror] are applied on top of it, so the
     * same numbers that stand the preview upright also stand the recording
     * upright.
     *
     * The image is fitted inside the rectangle rather than stretched to it:
     * a portrait frame in a landscape slot gets bars, not distortion.
     */
    fun draw(
        textureId: Int,
        stMatrix: FloatArray,
        sourceWidth: Int,
        sourceHeight: Int,
        rotation: Int,
        mirror: Boolean,
        left: Float,
        top: Float,
        right: Float,
        bottom: Float,
    ) {
        if (program == 0) return

        val turns = ((rotation % 360) + 360) % 360

        // Rotating the sampled image swaps which way round its aspect reads.
        val swapped = turns == 90 || turns == 270
        val sourceAspect = if (sourceHeight == 0 || sourceWidth == 0) {
            1f
        } else if (swapped) {
            sourceHeight.toFloat() / sourceWidth.toFloat()
        } else {
            sourceWidth.toFloat() / sourceHeight.toFloat()
        }

        val slotWidth = (right - left) / 2f
        val slotHeight = (top - bottom) / 2f
        val centreX = (left + right) / 2f
        val centreY = (top + bottom) / 2f

        // Clip space is square, so a slot's real shape is its size scaled by
        // the frame's own aspect; the viewport takes care of the rest.
        val slotAspect = if (slotHeight == 0f) 1f else slotWidth / slotHeight

        var scaleX = slotWidth
        var scaleY = slotHeight
        if (sourceAspect > slotAspect) {
            scaleY = slotWidth / sourceAspect
        } else {
            scaleX = slotHeight * sourceAspect
        }

        Matrix.setIdentityM(mvp, 0)
        Matrix.translateM(mvp, 0, centreX, centreY, 0f)
        Matrix.scaleM(mvp, 0, scaleX, scaleY, 1f)

        // Texture coordinates rotate about the middle of the image, not its
        // corner, or the frame spins out of view.
        System.arraycopy(stMatrix, 0, texture, 0, 16)
        Matrix.translateM(texture, 0, 0.5f, 0.5f, 0f)
        if (turns != 0) Matrix.rotateM(texture, 0, turns.toFloat(), 0f, 0f, 1f)
        if (mirror) Matrix.scaleM(texture, 0, -1f, 1f, 1f)
        Matrix.translateM(texture, 0, -0.5f, -0.5f, 0f)

        GLES20.glUseProgram(program)

        quad.position(0)
        GLES20.glVertexAttribPointer(
            aPosition, 2, GLES20.GL_FLOAT, false, 16, quad,
        )
        GLES20.glEnableVertexAttribArray(aPosition)

        quad.position(2)
        GLES20.glVertexAttribPointer(
            aTexCoord, 2, GLES20.GL_FLOAT, false, 16, quad,
        )
        GLES20.glEnableVertexAttribArray(aTexCoord)

        GLES20.glUniformMatrix4fv(uMvp, 1, false, mvp, 0)
        GLES20.glUniformMatrix4fv(uTexMatrix, 1, false, texture, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, 0)
    }

    /**
     * Paints the inset's backing: a white border, and black inside it.
     *
     * The black matters. The facecam is fitted into its slot rather than
     * stretched, so a frame whose shape does not match leaves bars -- and
     * bars in the border's white would read as a broken panel.
     */
    fun panel(
        left: Float,
        top: Float,
        right: Float,
        bottom: Float,
        borderPx: Int,
        viewportWidth: Int,
        viewportHeight: Int,
    ) {
        if (viewportWidth <= 0 || viewportHeight <= 0) return

        val x = ((left + 1f) / 2f * viewportWidth).toInt()
        val y = ((bottom + 1f) / 2f * viewportHeight).toInt()
        val w = ((right - left) / 2f * viewportWidth).toInt()
        val h = ((top - bottom) / 2f * viewportHeight).toInt()
        val t = borderPx.coerceAtLeast(1)

        GLES20.glEnable(GLES20.GL_SCISSOR_TEST)

        GLES20.glClearColor(1f, 1f, 1f, 1f)
        GLES20.glScissor(x - t, y - t, w + t * 2, h + t * 2)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glScissor(x, y, w, h)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

        GLES20.glDisable(GLES20.GL_SCISSOR_TEST)
    }

    fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
    }

    private fun compile(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)

        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] != GLES20.GL_TRUE) {
            val log = GLES20.glGetShaderInfoLog(shader)
            GLES20.glDeleteShader(shader)
            throw RuntimeException("Shader would not compile: $log")
        }
        return shader
    }

    private companion object {
        const val VERTEX_SHADER = """
            attribute vec4 aPosition;
            attribute vec4 aTexCoord;
            uniform mat4 uMvp;
            uniform mat4 uTexMatrix;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = uMvp * aPosition;
                vTexCoord = (uTexMatrix * aTexCoord).xy;
            }
        """

        const val FRAGMENT_SHADER = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            varying vec2 vTexCoord;
            uniform samplerExternalOES sTexture;
            void main() {
                gl_FragColor = texture2D(sTexture, vTexCoord);
            }
        """
    }
}
