package com.mare.mare

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
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
        sparkCsv: String = "",
        sparkColor: Int = 0xFF34C759.toInt(),
        boxColorsCsv: String = "",
        boxValuesCsv: String = "",
        subColorsCsv: String = "",
        catColorsCsv: String = "",
        catValuesCsv: String = "",
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
            .putString("w_spark", sparkCsv)
            .putInt("w_spark_color", sparkColor)
            .putString("w_box_colors", boxColorsCsv)
            .putString("w_box_values", boxValuesCsv)
            .putString("w_sub_colors", subColorsCsv)
            .putString("w_cat_colors", catColorsCsv)
            .putString("w_cat_values", catValuesCsv)
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

    fun parseDoubles(csv: String?): List<Double> =
        csv?.split(',')?.mapNotNull { it.trim().toDoubleOrNull() } ?: emptyList()

    fun parseInts(csv: String?): List<Int> =
        csv?.split(',')?.mapNotNull { it.trim().toIntOrNull() } ?: emptyList()
}

private object WidgetGraphics {
    fun sparkline(values: List<Double>, color: Int): Bitmap? {
        if (values.size < 2 || values.all { it <= 0.0 }) return null
        val w = 320
        val h = 96
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val maxV = values.maxOrNull()?.coerceAtLeast(1.0) ?: 1.0
        val minV = values.minOrNull() ?: 0.0
        val span = (maxV - minV).coerceAtLeast(1.0)
        val padY = 12f
        val pts = values.mapIndexed { i, v ->
            val x = i.toFloat() / (values.size - 1) * w
            val y = h - padY - ((v - minV) / span).toFloat() * (h - padY * 2)
            Pair(x, y)
        }
        val line = Path().apply {
            moveTo(pts.first().first, pts.first().second)
            for (i in 0 until pts.size - 1) {
                val (x0, y0) = pts[i]
                val (x1, y1) = pts[i + 1]
                val cx = (x0 + x1) / 2f
                cubicTo(cx, y0, cx, y1, x1, y1)
            }
        }
        val fill = Path(line).apply {
            lineTo(w.toFloat(), h.toFloat())
            lineTo(0f, h.toFloat())
            close()
        }
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            shader = LinearGradient(
                0f, 0f, 0f, h.toFloat(),
                (color and 0x00FFFFFF) or 0x44000000,
                (color and 0x00FFFFFF),
                Shader.TileMode.CLAMP,
            )
        }
        val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 5f
            strokeCap = Paint.Cap.ROUND
            this.color = color
        }
        canvas.drawPath(fill, fillPaint)
        canvas.drawPath(line, linePaint)
        return bmp
    }

    fun segmentedBar(values: List<Double>, colors: List<Int>): Bitmap? {
        val total = values.sum()
        if (values.isEmpty() || total <= 0.0) return null
        val w = 320
        val h = 36
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val gap = 6f
        val avail = (w - gap * (values.size - 1)).coerceAtLeast(20f)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        var x = 0f
        for (i in values.indices) {
            val segW = (values[i] / total * avail).toFloat().coerceAtLeast(10f)
            paint.color = colors.getOrElse(i) { 0xFF30B0C7.toInt() }
            val rect = RectF(x, 4f, (x + segW).coerceAtMost(w.toFloat()), h - 4f)
            canvas.drawRoundRect(rect, 14f, 14f, paint)
            x += segW + gap
        }
        return bmp
    }

    fun subCircles(colors: List<Int>, surfaceColor: Int): Bitmap? {
        if (colors.isEmpty()) return null
        val shown = colors.take(4)
        val r = 28f
        val step = 38f
        val h = 64
        val w = (r * 2 + (shown.size - 1) * step + 8).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = surfaceColor
        }
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }
        for (i in shown.indices) {
            val cx = r + 4f + i * step
            val cy = h / 2f
            canvas.drawCircle(cx, cy, r + 3f, borderPaint)
            fillPaint.color = shown[i]
            canvas.drawCircle(cx, cy, r - 1f, fillPaint)
        }
        return bmp
    }

    fun donut(values: List<Double>, colors: List<Int>): Bitmap? {
        val total = values.sum()
        if (values.isEmpty() || total <= 0.0) return null
        val sz = 160
        val bmp = Bitmap.createBitmap(sz, sz, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val stroke = 20f
        val rect = RectF(stroke, stroke, sz - stroke, sz - stroke)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        var startAngle = -90f
        val gapDeg = if (values.size > 1) 14f else 0f
        val usable = 360f - gapDeg * values.size
        for (i in values.indices) {
            val sweep = (values[i] / total * usable).toFloat().coerceAtLeast(6f)
            paint.color = colors.getOrElse(i) { 0xFF30B0C7.toInt() }
            canvas.drawArc(rect, startAngle, sweep, false, paint)
            startAngle += sweep + gapDeg
        }
        return bmp
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
    graphic: Bitmap?,
    reqCode: Int,
) {
    val openPi = MareWidgetStore.launchIntent(context, MareWidgetStore.ACTION_OPEN_APP, reqCode)
    for (id in ids) {
        val (w, h) = MareWidgetStore.sizeDp(mgr, id, 150, 110)
        val shortH = h < 92
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
            if (graphic != null && !shortH) {
                setImageViewBitmap(R.id.widget_graphic, graphic)
                setViewVisibility(R.id.widget_graphic, View.VISIBLE)
            } else {
                setViewVisibility(R.id.widget_graphic, View.GONE)
            }
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
            val spark = MareWidgetStore.parseDoubles(prefs.getString("w_spark", null))
            val col = prefs.getInt("w_spark_color", 0xFF34C759.toInt())
            val bmp = WidgetGraphics.sparkline(spark, col)
            updateMetricWidget(context, mgr, ids, "Seus Gastos", spent, cycle, bmp, 301)
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
            val vals = MareWidgetStore.parseDoubles(prefs.getString("w_box_values", null))
            val cols = MareWidgetStore.parseInts(prefs.getString("w_box_colors", null))
            val bmp = WidgetGraphics.segmentedBar(vals, cols)
            updateMetricWidget(context, mgr, ids, "Caixinhas", boxes, cap, bmp, 401)
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
            val cols = MareWidgetStore.parseInts(prefs.getString("w_sub_colors", null))
            val surface = context.getColor(R.color.widget_surface)
            val bmp = WidgetGraphics.subCircles(cols, surface)
            updateMetricWidget(context, mgr, ids, "Assinaturas", subs, cap, bmp, 501)
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
            val vals = MareWidgetStore.parseDoubles(prefs.getString("w_cat_values", null))
            val cols = MareWidgetStore.parseInts(prefs.getString("w_cat_colors", null))
            val donutBmp = WidgetGraphics.donut(vals, cols)
            val openPi = MareWidgetStore.launchIntent(context, MareWidgetStore.ACTION_OPEN_APP, 601)
            for (id in ids) {
                val (w, h) = MareWidgetStore.sizeDp(mgr, id, 200, 120)
                val shortH = h < 92
                val narrow = w < 170
                val views = RemoteViews(context.packageName, R.layout.widget_categories).apply {
                    setTextViewText(R.id.widget_cat_1, c1)
                    setTextViewText(R.id.widget_cat_2, c2)
                    setTextViewText(R.id.widget_cat_3, c3)
                    setViewVisibility(R.id.widget_cat_2, if (c2.isEmpty()) View.GONE else View.VISIBLE)
                    setViewVisibility(R.id.widget_cat_3, if (shortH || c3.isEmpty()) View.GONE else View.VISIBLE)
                    if (donutBmp != null && !narrow && !shortH) {
                        setImageViewBitmap(R.id.widget_donut, donutBmp)
                        setViewVisibility(R.id.widget_donut, View.VISIBLE)
                    } else {
                        setViewVisibility(R.id.widget_donut, View.GONE)
                    }
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
