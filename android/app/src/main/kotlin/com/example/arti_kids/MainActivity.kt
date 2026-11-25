package com.example.arti_kids

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var permissionReply: MethodChannel.Result? = null
    private val capture by lazy { ExerciseCapture(this) }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "artikids/storage").setMethodCallHandler { call, result ->
            if (call.method == "documents") {
                // Match path_provider's documents directory in the installed prototype.
                result.success(getDir("flutter", MODE_PRIVATE).path)
            } else {
                result.notImplemented()
            }
        }
        EventChannel(messenger, "artikids/observations").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    capture.sink = events
                }
                override fun onCancel(arguments: Any?) {
                    capture.sink = null
                    capture.stop()
                }
            }
        )
        MethodChannel(messenger, "artikids/capture").setMethodCallHandler { call, result ->
            when (call.method) {
                "permission" -> {
                    val permission = if (call.arguments == "microphone") {
                        Manifest.permission.RECORD_AUDIO
                    } else {
                        Manifest.permission.CAMERA
                    }
                    if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else if (permissionReply != null) {
                        result.error("busy", null, null)
                    } else {
                        permissionReply = result
                        requestPermissions(arrayOf(permission), 43)
                    }
                }
                "start" -> capture.start(call.arguments == true, result)
                "stop" -> {
                    capture.stop()
                    result.success(null)
                }
                "sample" -> capture.playSample(result)
                "settings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null)))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 43) {
            val reply = permissionReply
            permissionReply = null
            reply?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        }
    }

    override fun onStop() {
        capture.stop()
        super.onStop()
    }

    override fun onDestroy() {
        capture.stop()
        super.onDestroy()
    }
}
