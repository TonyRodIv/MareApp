package com.mare.mare

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews

object MareWidgetStore {
    const val PREFS = "mare_native_prefs"
    const val ACTION_OPEN_APP = "com.mare.mare.ACTION_OPEN_APP"
    const val ACTION_ADD_EXPENSE = "com.mare.mare.ACTION_ADD_EXPENSE"

    fun saveSnapshot(
        context: Context,
        freeBalance: String,
        expensesTotal: String,
        boxesTotal: String,
        boxesCaption: String,
        subsTotal: String,
        subsCaption: String,
        cat1: String,
        cat2: String,
        cat3: String,
        cycleLabel: String,
        caption: String,
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("w_free", freeBalance)
            .putString("w_spent", expensesTotal)
            .putString("w_boxes", boxesTotal)
            .putString("w_boxes_cap", boxesCaption)
            .putString("w_subs", subsTotal)
            .putString("w_subs_cap", subsCaption)
            .putString("w_cat1", cat1)
            .putString("w_cat2", cat2)
            .putString("w_cat3", cat3)
            .putString("w_cycle", cycleLabel)
            .putString("w_caption", caption)
            .apply()
        updateAllWidgets(context)
    }

    fun updateAllWidgets(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        fun upd(cls: Class<*>, fn: (Context, AppWidgetManager, IntArray) -> Unit) {
            val ids = mgr.getAppWidgetIds(ComponentName(context, cls))
            if (ids.isNotEmpty()) fn(context, mgr, ids)
        }
        upd(MareBalanceWidgetProvider::class.java, MareBalanceWidgetProvider::update)
        upd(MareSummaryWidgetProvider::class.java, MareSummaryWidgetProvider::update)
        upd(MareExpensesWidgetProvider::class.java, MareExpensesWidgetProvider::update)
        upd(MareBoxesWidgetProvider::class.java, MareBoxesWidgetProvider::update)
        upd(MareSubsWidgetProvider::class.java, MareSubsWidgetProvider::update)
        upd(MareCategoriesWidgetProvider::class.java, MareCategoriesWidgetProvider::update)
        upd(MareQuickAddWidgetProvider::class.java, MareQuickAddWidgetProvider::update)
    }

    fun launchIntent(context: Context, action: String, reqCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            reqCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun sizeDp(mgr: AppWidgetManager, id: Int, fallbackW: Int = 180, fallbackH: Int = 110): Pair<Int, Int> {
        val opts = mgr.getAppWidgetOptions(id)
        val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        return Pair(if (w > 0) w else fallbackW, if (h > 0) h else fallbackH)
    }
}

class MareBalanceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        update(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        update(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    companion object {
        fun update(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
            val free = prefs.getString("w_free", "R\$ 0,00") ?: "R\$ 0,00"
            val cycle = prefs.getString("w_cycle", "Ciclo atual") ?: "Ciclo atual"
            val caption = prefs.getString("w_caption", "Toque no + para registrar") ?: "Toque no + para registrar"
            val openPi = MareWidgetStore.launchIntent(context, MareWidgetStore.ACTION_OPEN_APP, 101)
            val addPi = MareWidgetStore.launchIntent(context, MareWidgetStore.ACTION_ADD_EXPENSE, 102)
            for (id in ids) {
                val (w, h) = MareWidgetStore.sizeDp(mgr, id, 220, 80)
                val shortH = h < 92
                val narrow = w < 190
                val views = RemoteViews(context.packageName, R.layout.widget_balance).apply {
                    setTextViewText(R.id.widget_subtitle, if (narrow) "Saldo livre" else "maré · $cycle")
                    setTextViewText(R.id.widget_balance, free)
                    setTextViewTextSize(R.id.widget_balance, TypedValue.COMPLEX_UNIT_SP, if (narrow) 18f else 22f)
                    setTextViewText(R.id.widget_caption, caption)
                    setViewVisibility(R.id.widget_caption, if (shortH) View.GONE else View.VISIBLE)
                    setOnClickPendingIntent(R.id.widget_root, openPi)
                    setOnClickPendingIntent(R.id.widget_add_btn, addPi)
                }
                mgr.updateAppWidget(id, views)
            }
        }
    }
}

class MareSummaryWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        update(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        update(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    companion object {
        fun update(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
            val free = prefs.getString("w_free", "R\$ 0,00") ?: "R\$ 0,00"
            val spent = prefs.getString("w_spent", "R\$ 0,00") ?: "R\$ 0,00"
            val boxes = prefs.getString("w_boxes", "R\$ 0,00") ?: "R\$ 0,00"
            val cycle = prefs.getString("w_cycle", "Ciclo atual") ?: "Ciclo atual"
            val openPi = MareWidgetStore.launchIntent(context, MareWidgetStore.ACTION_OPEN_APP, 201)
            val addPi = MareWidgetStore.launchIntent(context, MareWidgetStore.ACTION_ADD_EXPENSE, 202)
            for (id in ids) {
                val (w, h) = MareWidgetStore.sizeDp(mgr, id, 260, 140)
                val shortH = h < 105
                val narrow = w < 210
                val views = RemoteViews(context.packageName, R.layout.widget_summary).apply {
                    setTextViewText(R.id.widget_cycle, if (narrow) "Saldo livre" else "maré · Saldo livre ($cycle)")
                    setTextViewText(R.id.widget_add_btn, if (narrow) "+" else "+ Gasto")
                    setTextViewText(R.id.widget_balance, free)
                    setTextViewTextSize(
                        R.id.widget_balance,
                        TypedValue.COMPLEX_UNIT_SP,
                        if (narrow) 20f else (if (shortH) 22f else 26f),
                    )
                    setViewVisibility(R.id.widget_tiles_row, if (shortH) View.GONE else View.VISIBLE)
                    setTextViewText(R.id.widget_spent, spent)
                    setTextViewText(R.id.widget_boxes, boxes)
                    setTextViewTextSize(R.id.widget_spent, TypedValue.COMPLEX_UNIT_SP, if (narrow) 13f else 15f)
                    setTextViewTextSize(R.id.widget_boxes, TypedValue.COMPLEX_UNIT_SP, if (narrow) 13f else 15f)
                    setOnClickPendingIntent(R.id.widget_root, openPi)
                    setOnClickPendingIntent(R.id.widget_add_btn, addPi)
                }
                mgr.updateAppWidget(id, views)
            }
        }
    }
}

private fun updateMetricWidget(
    context: Context,
    mgr: AppWidgetManager,
    ids: IntArray,
    title: String,
    value: String,
    caption: String,
    reqCode: Int,
) {
    val openPi = MareWidgetStore.launchIntent(context, MareWidgetStore.ACTION_OPEN_APP, reqCode)
    for (id in ids) {
        val (w, h) = MareWidgetStore.sizeDp(mgr, id, 150, 110)
        val shortH = h < 88
        val narrow = w < 150
        val views = RemoteViews(context.packageName, R.layout.widget_metric).apply {
            setTextViewText(R.id.widget_title, title)
            setTextViewText(R.id.widget_value, value)
            setTextViewTextSize(
                R.id.widget_value,
                TypedValue.COMPLEX_UNIT_SP,
                if (narrow) 18f else (if (w >= 240) 24f else 21f),
            )
            setTextViewText(R.id.widget_caption, caption)
            setViewVisibility(R.id.widget_caption, if (shortH) View.GONE else View.VISIBLE)
            setOnClickPendingIntent(R.id.widget_root, openPi)
        }
        mgr.updateAppWidget(id, views)
    }
}

class MareExpensesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        update(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(context: Context, mgr: AppWidgetManager, id: Int, opts: Bundle) {
        update(context, mgr, intArrayOf(id))
    }

    companion object {
        fun update(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
            val spent = prefs.getString("w_spent", "R\$ 0,00") ?: "R\$ 0,00"
            val cycle = prefs.getString("w_cycle", "Neste ciclo") ?: "Neste ciclo"
            updateMetricWidget(context, mgr, ids, "Seus Gastos", spent, cycle, 301)
        }
    }
}

class MareBoxesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        update(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(context: Context, mgr: AppWidgetManager, id: Int, opts: Bundle) {
        update(context, mgr, intArrayOf(id))
    }

    companion object {
        fun update(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
            val boxes = prefs.getString("w_boxes", "R\$ 0,00") ?: "R\$ 0,00"
            val cap = prefs.getString("w_boxes_cap", "Guardado") ?: "Guardado"
            updateMetricWidget(context, mgr, ids, "Caixinhas", boxes, cap, 401)
        }
    }
}

class MareSubsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        update(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(context: Context, mgr: AppWidgetManager, id: Int, opts: Bundle) {
        update(context, mgr, intArrayOf(id))
    }

    companion object {
        fun update(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
            val subs = prefs.getString("w_subs", "R\$ 0,00") ?: "R\$ 0,00"
            val cap = prefs.getString("w_subs_cap", "Por mês") ?: "Por mês"
            updateMetricWidget(context, mgr, ids, "Assinaturas", subs, cap, 501)
        }
    }
}

class MareCategoriesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        update(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(context: Context, mgr: AppWidgetManager, id: Int, opts: Bundle) {
        update(context, mgr, intArrayOf(id))
    }

    companion object {
        fun update(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(MareWidgetStore.PREFS, Context.MODE_PRIVATE)
            val c1 = prefs.getString("w_cat1", "Sem gastos neste ciclo") ?: "Sem gastos neste ciclo"
            val c2 = prefs.getString("w_cat2", "") ?: ""
            val c3 = prefs.getString("w_cat3", "") ?: ""
            val openPi = MareWidgetStore.launchIntent(context, MareWidgetStore.ACTION_OPEN_APP, 601)
            for (id in ids) {
                val (_, h) = MareWidgetStore.sizeDp(mgr, id, 200, 120)
                val shortH = h < 92
                val views = RemoteViews(context.packageName, R.layout.widget_categories).apply {
                    setTextViewText(R.id.widget_cat_1, c1)
                    setTextViewText(R.id.widget_cat_2, c2)
                    setTextViewText(R.id.widget_cat_3, c3)
                    setViewVisibility(R.id.widget_cat_2, if (c2.isEmpty()) View.GONE else View.VISIBLE)
                    setViewVisibility(R.id.widget_cat_3, if (shortH || c3.isEmpty()) View.GONE else View.VISIBLE)
                    setOnClickPendingIntent(R.id.widget_root, openPi)
                }
                mgr.updateAppWidget(id, views)
            }
        }
    }
}

class MareQuickAddWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        update(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(context: Context, mgr: AppWidgetManager, id: Int, opts: Bundle) {
        update(context, mgr, intArrayOf(id))
    }

    companion object {
        fun update(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            val addPi = MareWidgetStore.launchIntent(context, MareWidgetStore.ACTION_ADD_EXPENSE, 701)
            for (id in ids) {
                val (w, _) = MareWidgetStore.sizeDp(mgr, id, 120, 60)
                val views = RemoteViews(context.packageName, R.layout.widget_quick_add).apply {
                    setViewVisibility(R.id.widget_quick_label, if (w < 100) View.GONE else View.VISIBLE)
                    setTextViewText(R.id.widget_quick_label, if (w >= 190) "Adicionar gasto" else "Gasto")
                    setOnClickPendingIntent(R.id.widget_root, addPi)
                }
                mgr.updateAppWidget(id, views)
            }
        }
    }
}
