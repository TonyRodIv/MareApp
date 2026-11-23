package com.mare.mare

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var powerReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "com.mare.mare/links")
            .setMethodCallHandler { call, result ->
                if (call.method == "openUrl") {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(messenger, "com.mare.mare/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "getCapabilities") {
                    result.success(readDeviceCapabilities())
                } else {
                    result.notImplemented()
                }
            }

        EventChannel(messenger, "com.mare.mare/power_save")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    unregisterPowerReceiver()
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    events?.success(pm?.isPowerSaveMode == true)
                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            val active = pm?.isPowerSaveMode == true
                            events?.success(active)
                        }
                    }
                    powerReceiver = receiver
                    val filter = IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(receiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    unregisterPowerReceiver()
                }
            })
    }

    private fun readDeviceCapabilities(): Map<String, Any> {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(memInfo)
        val totalRamMb = (memInfo.totalMem / (1024L * 1024L)).toInt()
        return mapOf(
            "isPowerSaveMode" to (pm?.isPowerSaveMode == true),
            "isLowRamDevice" to (am?.isLowRamDevice == true),
            "totalRamMb" to totalRamMb,
            "cpuCores" to Runtime.getRuntime().availableProcessors(),
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    private fun unregisterPowerReceiver() {
        powerReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
            powerReceiver = null
        }
    }

    override fun onDestroy() {
        unregisterPowerReceiver()
        super.onDestroy()
    }
}
