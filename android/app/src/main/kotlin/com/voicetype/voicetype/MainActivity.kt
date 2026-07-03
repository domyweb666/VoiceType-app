package com.voicetype.voicetype

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.voicetype/app",
        ).setMethodCallHandler { call, result ->
            if (call.method == "consumeToggleRecordIntent") {
                val v = VoiceTypeLaunchState.pendingToggleRecord
                VoiceTypeLaunchState.pendingToggleRecord = false
                result.success(v)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.voicetype/recording_fg",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, RecordingForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stop" -> {
                    stopService(Intent(this, RecordingForegroundService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        consumeIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeIntent(intent)
    }

    private fun consumeIntent(intent: Intent?) {
        if (intent?.getStringExtra(EXTRA_ACTION) == ACTION_TOGGLE_RECORD) {
            VoiceTypeLaunchState.pendingToggleRecord = true
        }
    }

    companion object {
        const val EXTRA_ACTION = "voicetype_action"
        const val ACTION_TOGGLE_RECORD = "toggle_record"
    }
}
