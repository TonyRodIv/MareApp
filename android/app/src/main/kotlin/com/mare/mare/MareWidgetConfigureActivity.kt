package com.mare.mare

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView

class MareWidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var selectedStyle = MareWidgetStore.STYLE_SOLID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val isDark = (resources.configuration.uiMode and
            android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
            android.content.res.Configuration.UI_MODE_NIGHT_YES

        val bg = if (isDark) Color.parseColor("#141416") else Color.parseColor("#F5F5F7")
        val cardBg = if (isDark) Color.parseColor("#242426") else Color.WHITE
        val textPrimary = if (isDark) Color.parseColor("#F5F5F7") else Color.parseColor("#141416")
        val textSecondary = if (isDark) Color.parseColor("#A0A0A8") else Color.parseColor("#6B6B72")
        val accent = Color.parseColor("#30B0C7")
        val accentSoft = if (isDark) Color.parseColor("#173A42") else Color.parseColor("#E6F4F7")

        selectedStyle = MareWidgetStore.styleFor(this, appWidgetId)
        val initialHide = MareWidgetStore.hideFor(this, appWidgetId)

        fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
        fun pillDrawable(color: Int, radiusDp: Int = 20): GradientDrawable =
            GradientDrawable().apply {
                setColor(color)
                cornerRadius = dp(radiusDp).toFloat()
            }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bg)
            setPadding(dp(20), dp(44), dp(20), dp(24))
        }

        val title = TextView(this).apply {
            text = "Configurar widget"
            textSize = 24f
            setTypeface(null, Typeface.BOLD)
            setTextColor(textPrimary)
        }
        val subtitle = TextView(this).apply {
            text = "Personalize o fundo e a privacidade deste widget na tela inicial."
            textSize = 14f
            setTextColor(textSecondary)
            setPadding(0, dp(4), 0, dp(20))
        }
        root.addView(title)
        root.addView(subtitle)

        val styleLabel = TextView(this).apply {
            text = "Fundo do widget"
            textSize = 13f
            setTypeface(null, Typeface.BOLD)
            setTextColor(textSecondary)
            setPadding(dp(4), 0, 0, dp(8))
        }
        root.addView(styleLabel)

        val options = listOf(
            Triple(MareWidgetStore.STYLE_SOLID, "Padrão (sólido)", "Mesmo visual dos cards do app"),
            Triple(MareWidgetStore.STYLE_BLUR, "Translúcido (Blur One UI)", "Fundo fosco compatível com o desfoque do launcher"),
            Triple(MareWidgetStore.STYLE_CLEAR, "Transparente", "Apenas textos e gráficos sobre o papel de parede"),
        )

        val optionCards = mutableListOf<Pair<String, LinearLayout>>()
        fun refreshStyles() {
            for ((key, box) in optionCards) {
                val active = key == selectedStyle
                box.background = pillDrawable(if (active) accentSoft else cardBg, 18)
                val tView = box.getChildAt(0) as TextView
                tView.setTextColor(if (active) accent else textPrimary)
            }
        }

        for ((key, name, desc) in options) {
            val box = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(16), dp(14), dp(16), dp(14))
                val lp = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { bottomMargin = dp(10) }
                layoutParams = lp
                setOnClickListener {
                    selectedStyle = key
                    refreshStyles()
                }
            }
            box.addView(TextView(this).apply {
                text = name
                textSize = 16f
                setTypeface(null, Typeface.BOLD)
            })
            box.addView(TextView(this).apply {
                text = desc
                textSize = 12f
                setTextColor(textSecondary)
                setPadding(0, dp(2), 0, 0)
            })
            optionCards.add(key to box)
            root.addView(box)
        }
        refreshStyles()

        val hideSwitch = Switch(this).apply {
            isChecked = initialHide
        }
        val privacyBox = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = pillDrawable(cardBg, 18)
            setPadding(dp(16), dp(14), dp(16), dp(14))
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = dp(8)
                bottomMargin = dp(20)
            }
            layoutParams = lp
        }
        val privacyText = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        privacyText.addView(TextView(this).apply {
            text = "Ocultar valores"
            textSize = 16f
            setTypeface(null, Typeface.BOLD)
            setTextColor(textPrimary)
        })
        privacyText.addView(TextView(this).apply {
            text = "Mostra ••••• no lugar dos valores em reais"
            textSize = 12f
            setTextColor(textSecondary)
        })
        privacyBox.addView(privacyText)
        privacyBox.addView(hideSwitch)
        privacyBox.setOnClickListener { hideSwitch.isChecked = !hideSwitch.isChecked }
        root.addView(privacyBox)

        val spacer = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
        }
        root.addView(spacer)

        val saveBtn = TextView(this).apply {
            text = "Salvar widget"
            textSize = 16f
            setTypeface(null, Typeface.BOLD)
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = pillDrawable(accent, 28)
            setPadding(0, dp(15), 0, dp(15))
            setOnClickListener {
                MareWidgetStore.saveWidgetConfig(
                    this@MareWidgetConfigureActivity,
                    appWidgetId,
                    selectedStyle,
                    hideSwitch.isChecked,
                )
                MareWidgetStore.updateAllWidgets(this@MareWidgetConfigureActivity)
                setResult(
                    RESULT_OK,
                    Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
                )
                finish()
            }
        }
        root.addView(saveBtn)
        setContentView(root)
    }
}
