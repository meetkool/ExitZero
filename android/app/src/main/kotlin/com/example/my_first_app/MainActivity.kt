package com.example.my_first_app

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "exitzero/camera_capability"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "concurrentSupport" -> result.success(concurrentSupport())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Whether this device can stream a front and a back lens at the same time.
     *
     * Flutter's camera plugin only ever opens one camera, and simultaneous
     * front+back is an optional Camera2 feature added in Android 11 that many
     * devices simply do not have. Rather than guess, ask the platform:
     * getConcurrentCameraIds() returns the combinations the hardware can
     * actually run together, and a pair only counts here if one of its
     * cameras faces forward and another faces back.
     */
    private fun concurrentSupport(): Map<String, Any> {
        val out = HashMap<String, Any>()
        out["sdkInt"] = Build.VERSION.SDK_INT
        out["release"] = Build.VERSION.RELEASE ?: ""
        out["device"] = "${Build.MANUFACTURER} ${Build.MODEL}"

        val manager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager
        if (manager == null) {
            out["supported"] = false
            out["reason"] = "No camera service on this device."
            return out
        }

        // Which way each camera id points, so a combination can be judged.
        val facing = HashMap<String, String>()
        try {
            for (id in manager.cameraIdList) {
                val characteristics = manager.getCameraCharacteristics(id)
                facing[id] = when (characteristics.get(CameraCharacteristics.LENS_FACING)) {
                    CameraCharacteristics.LENS_FACING_FRONT -> "front"
                    CameraCharacteristics.LENS_FACING_BACK -> "back"
                    CameraCharacteristics.LENS_FACING_EXTERNAL -> "external"
                    else -> "unknown"
                }
            }
        } catch (e: Exception) {
            out["reason"] = "Could not read camera list: ${e.message}"
        }
        out["cameras"] = facing

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            out["supported"] = false
            out["reason"] =
                "Needs Android 11 or newer. This is Android ${Build.VERSION.RELEASE}."
            return out
        }

        return try {
            // Set<Set<String>> of id combinations that can run concurrently.
            val combinations = manager.concurrentCameraIds.map { it.toList().sorted() }
            out["pairs"] = combinations

            val frontAndBack = combinations.any { combo ->
                combo.any { facing[it] == "front" } && combo.any { facing[it] == "back" }
            }
            out["supported"] = frontAndBack

            if (!frontAndBack) {
                out["reason"] = if (combinations.isEmpty()) {
                    "This device reports no concurrent camera combinations at all."
                } else {
                    "It can run some cameras together, but no combination pairs a " +
                        "front lens with a back one."
                }
            }
            out
        } catch (e: Exception) {
            out["supported"] = false
            out["reason"] = "Query failed: ${e.message}"
            out
        }
    }
}
