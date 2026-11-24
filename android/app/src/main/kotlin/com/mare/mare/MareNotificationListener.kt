package com.mare.mare

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale
import java.util.UUID

object BankSuggestionStore {
    const val KEY_ENABLED = "bank_notif_enabled"
    const val KEY_PENDING = "bank_pending_suggestions"
    const val KEY_APPROVED = "bank_approved_suggestions"
    const val ACTION_SAVE = "com.mare.mare.BANK_SUGGESTION_SAVE"
    const val ACTION_IGNORE = "com.mare.mare.BANK_SUGGESTION_IGNORE"
    const val ACTION_CHANGED = "com.mare.mare.BANK_SUGGESTION_CHANGED"
    const val EXTRA_ID = "suggestion_id"
    const val EXTRA_NOTIF_ID = "notif_id"
    const val CHANNEL_ID = "mare_bank_suggestions"

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    fun addPending(context: Context, parsed: ParsedBankExpense): String {
        val prefs = context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
        val arr = readArray(prefs.getString(KEY_PENDING, null))
        val id = UUID.randomUUID().toString()
        val obj = JSONObject().apply {
            put("id", id)
            put("name", parsed.name)
            put("cents", parsed.cents)
            put("bankName", parsed.bankName)
            put("packageName", parsed.packageName)
            put("timestamp", System.currentTimeMillis())
        }
        val next = JSONArray()
        next.put(obj)
        for (i in 0 until minOf(arr.length(), 19)) {
            next.put(arr.getJSONObject(i))
        }
        prefs.edit().putString(KEY_PENDING, next.toString()).apply()
        notifyChanged(context)
        return id
    }

    fun getPendingList(context: Context): List<Map<String, Any>> {
        val prefs = context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
        val arr = readArray(prefs.getString(KEY_PENDING, null))
        return toList(arr)
    }

    fun approveById(context: Context, id: String) {
        val prefs = context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
        val pending = readArray(prefs.getString(KEY_PENDING, null))
        val approved = readArray(prefs.getString(KEY_APPROVED, null))
        val nextPending = JSONArray()
        for (i in 0 until pending.length()) {
            val item = pending.getJSONObject(i)
            if (item.optString("id") == id) {
                approved.put(item)
            } else {
                nextPending.put(item)
            }
        }
        prefs.edit()
            .putString(KEY_PENDING, nextPending.toString())
            .putString(KEY_APPROVED, approved.toString())
            .apply()
        notifyChanged(context)
    }

    fun dismissById(context: Context, id: String) {
        val prefs = context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
        val pending = readArray(prefs.getString(KEY_PENDING, null))
        val nextPending = JSONArray()
        for (i in 0 until pending.length()) {
            val item = pending.getJSONObject(i)
            if (item.optString("id") != id) {
                nextPending.put(item)
            }
        }
        prefs.edit().putString(KEY_PENDING, nextPending.toString()).apply()
        notifyChanged(context)
    }

    fun consumeApproved(context: Context): List<Map<String, Any>> {
        val prefs = context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
        val arr = readArray(prefs.getString(KEY_APPROVED, null))
        if (arr.length() == 0) return emptyList()
        prefs.edit().remove(KEY_APPROVED).apply()
        return toList(arr)
    }

    private fun notifyChanged(context: Context) {
        context.sendBroadcast(Intent(ACTION_CHANGED).setPackage(context.packageName))
    }

    private fun readArray(raw: String?): JSONArray {
        if (raw.isNullOrBlank()) return JSONArray()
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }

    private fun toList(arr: JSONArray): List<Map<String, Any>> {
        val out = mutableListOf<Map<String, Any>>()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            out.add(
                mapOf(
                    "id" to o.optString("id"),
                    "name" to o.optString("name"),
                    "cents" to o.optInt("cents"),
                    "bankName" to o.optString("bankName"),
                    "timestamp" to o.optLong("timestamp"),
                )
            )
        }
        return out
    }
}

class MareNotificationListener : NotificationListenerService() {
    private var lastSignature = ""
    private var lastTimeMs = 0L

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        if (!BankSuggestionStore.isEnabled(this)) return
        val pkg = sbn.packageName ?: return
        if (pkg == packageName) return
        if (!BankNotificationParser.isSupportedBank(pkg)) return

        val n = sbn.notification ?: return
        if ((n.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return

        val extras = n.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val text = (bigText ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()).orEmpty()

        val sig = "$pkg|$title|$text"
        val now = System.currentTimeMillis()
        if (sig == lastSignature && (now - lastTimeMs) < 10_000L) return
        lastSignature = sig
        lastTimeMs = now

        val parsed = BankNotificationParser.parse(pkg, title, text) ?: return
        val id = BankSuggestionStore.addPending(this, parsed)
        showSuggestionNotification(id, parsed)
    }

    private fun showSuggestionNotification(id: String, parsed: ParsedBankExpense) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                BankSuggestionStore.CHANNEL_ID,
                "Sugestões de gastos",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Sugestão rápida ao detectar compras em notificações de bancos"
            }
            nm.createNotificationChannel(channel)
        }

        val notifId = id.hashCode()
        val fmt = NumberFormat.getCurrencyInstance(Locale("pt", "BR"))
        val money = fmt.format(parsed.cents / 100.0)

        val saveIntent = Intent(this, MareNotificationActionReceiver::class.java).apply {
            action = BankSuggestionStore.ACTION_SAVE
            putExtra(BankSuggestionStore.EXTRA_ID, id)
            putExtra(BankSuggestionStore.EXTRA_NOTIF_ID, notifId)
        }
        val savePi = PendingIntent.getBroadcast(
            this,
            notifId * 2 + 1,
            saveIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val ignoreIntent = Intent(this, MareNotificationActionReceiver::class.java).apply {
            action = BankSuggestionStore.ACTION_IGNORE
            putExtra(BankSuggestionStore.EXTRA_ID, id)
            putExtra(BankSuggestionStore.EXTRA_NOTIF_ID, notifId)
        }
        val ignorePi = PendingIntent.getBroadcast(
            this,
            notifId * 2 + 2,
            ignoreIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val openIntent = Intent(this, MainActivity::class.java).apply {
            action = MareWidgetStore.ACTION_OPEN_APP
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openPi = PendingIntent.getActivity(
            this,
            notifId * 2 + 3,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, BankSuggestionStore.CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Gasto detectado · ${parsed.bankName}")
            .setContentText("${parsed.name} · $money")
            .setContentIntent(openPi)
            .setAutoCancel(true)
            .addAction(Notification.Action.Builder(null, "Salvar", savePi).build())
            .addAction(Notification.Action.Builder(null, "Ignorar", ignorePi).build())

        try {
            nm.notify(notifId, builder.build())
        } catch (_: SecurityException) {
        }
    }
}

class MareNotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        val id = intent.getStringExtra(BankSuggestionStore.EXTRA_ID) ?: return
        val notifId = intent.getIntExtra(BankSuggestionStore.EXTRA_NOTIF_ID, 0)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        if (notifId != 0) nm?.cancel(notifId)

        when (intent.action) {
            BankSuggestionStore.ACTION_SAVE -> BankSuggestionStore.approveById(context, id)
            BankSuggestionStore.ACTION_IGNORE -> BankSuggestionStore.dismissById(context, id)
        }
    }
}
