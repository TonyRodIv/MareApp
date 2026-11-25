package com.mare.mare

import android.Manifest
import android.app.ActivityManager
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var powerReceiver: BroadcastReceiver? = null
    private var bankReceiver: BroadcastReceiver? = null
    private var bankEventSink: EventChannel.EventSink? = null
    private var pendingLaunchAction: String? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val act = intent.action
        if (act == MareWidgetStore.ACTION_ADD_EXPENSE) {
            pendingLaunchAction = act
            bankEventSink?.success("launch_add_expense")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingLaunchAction = intent?.action
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

        MethodChannel(messenger, "com.mare.mare/widgets")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateSnapshot" -> {
                        MareWidgetStore.saveSnapshot(
                            this,
                            call.argument<String>("freeBalance") ?: "R\$ 0,00",
                            call.argument<String>("expensesTotal") ?: "R\$ 0,00",
                            call.argument<String>("boxesTotal") ?: "R\$ 0,00",
                            call.argument<String>("boxesCaption") ?: "Guardado",
                            call.argument<String>("subsTotal") ?: "R\$ 0,00",
                            call.argument<String>("subsCaption") ?: "Por mês",
                            call.argument<String>("cat1") ?: "Sem gastos neste ciclo",
                            call.argument<String>("cat2") ?: "",
                            call.argument<String>("cat3") ?: "",
                            call.argument<String>("cat4") ?: "",
                            call.argument<String>("cycleLabel") ?: "Ciclo atual",
                            call.argument<String>("caption") ?: "Toque no + para registrar",
                            call.argument<String>("sparkCsv") ?: "",
                            call.argument<Number>("sparkColor")?.toInt() ?: 0xFF34C759.toInt(),
                            call.argument<String>("boxColorsCsv") ?: "",
                            call.argument<String>("boxValuesCsv") ?: "",
                            call.argument<String>("subColorsCsv") ?: "",
                            call.argument<String>("subLabelsCsv") ?: "",
                            call.argument<String>("subDomainsCsv") ?: "",
                            call.argument<String>("subInsetsCsv") ?: "",
                            call.argument<Number>("subExtra")?.toInt() ?: 0,
                            call.argument<String>("catColorsCsv") ?: "",
                            call.argument<String>("catValuesCsv") ?: "",
                            call.argument<String>("splitTotal") ?: "R\$ 0,00",
                            call.argument<String>("splitCaption") ?: "Tudo quitado",
                        )
                        result.success(true)
                    }
                    "canPin" -> {
                        val ok = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            AppWidgetManager.getInstance(this).isRequestPinAppWidgetSupported
                        result.success(ok)
                    }
                    "pinWidget" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val kind = call.argument<String>("kind") ?: "balance"
                        val cls = when (kind) {
                            "summary" -> MareSummaryWidgetProvider::class.java
                            "expenses" -> MareExpensesWidgetProvider::class.java
                            "boxes" -> MareBoxesWidgetProvider::class.java
                            "subs" -> MareSubsWidgetProvider::class.java
                            "categories" -> MareCategoriesWidgetProvider::class.java
                            "split" -> MareSplitWidgetProvider::class.java
                            "quick_add" -> MareQuickAddWidgetProvider::class.java
                            else -> MareBalanceWidgetProvider::class.java
                        }
                        val mgr = AppWidgetManager.getInstance(this)
                        if (!mgr.isRequestPinAppWidgetSupported) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val ok = mgr.requestPinAppWidget(ComponentName(this, cls), null, null)
                        result.success(ok)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(messenger, "com.mare.mare/bank_notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(BankSuggestionStore.isEnabled(this))
                    "setEnabled" -> {
                        val v = call.argument<Boolean>("enabled") ?: false
                        BankSuggestionStore.setEnabled(this, v)
                        result.success(true)
                    }
                    "hasAccess" -> result.success(hasNotificationListenerAccess())
                    "hasPostPermission" -> {
                        val granted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    }
                    "requestPostPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4001)
                        }
                        result.success(true)
                    }
                    "openAccessSettings" -> {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                            )
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "openAppInfoSettings" -> {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.fromParts("package", packageName, null)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                            )
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "getPending" -> result.success(BankSuggestionStore.getPendingList(this))
                    "dismissPending" -> {
                        val id = call.argument<String>("id")
                        if (id != null) BankSuggestionStore.dismissById(this, id)
                        result.success(true)
                    }
                    "consumeApproved" -> result.success(BankSuggestionStore.consumeApproved(this))
                    "consumeLaunchAction" -> {
                        val act = pendingLaunchAction
                        pendingLaunchAction = null
                        result.success(act)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(messenger, "com.mare.mare/bank_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    unregisterBankReceiver()
                    bankEventSink = events
                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            events?.success("suggestions_changed")
                        }
                    }
                    bankReceiver = receiver
                    val filter = IntentFilter(BankSuggestionStore.ACTION_CHANGED)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(receiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    bankEventSink = null
                    unregisterBankReceiver()
                }
            })

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

    private fun hasNotificationListenerAccess(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        val flat = ComponentName(this, MareNotificationListener::class.java).flattenToString()
        return enabled.split(':').any { it.equals(flat, ignoreCase = true) || it.contains(packageName) }
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

    private fun unregisterBankReceiver() {
        bankReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
            bankReceiver = null
        }
    }

    override fun onDestroy() {
        unregisterPowerReceiver()
        unregisterBankReceiver()
        super.onDestroy()
    }
}
