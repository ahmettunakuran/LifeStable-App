package com.example.project_lifestable

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LifeStableWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs: SharedPreferences = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE
        )

        val today = SimpleDateFormat("dd MMM", Locale.getDefault()).format(Date())

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            // Header
            views.setTextViewText(R.id.widget_title, "LifeStable")
            views.setTextViewText(R.id.widget_date, today)

            // Tasks — Flutter shared_preferences adds "flutter." prefix
            val tasksCount = prefs.getString("flutter.widget_tasks_count", "0") ?: "0"
            val tasksDetail = prefs.getString("flutter.widget_tasks_detail", "") ?: ""
            views.setTextViewText(R.id.widget_tasks_count, tasksCount)
            if (tasksDetail.isEmpty()) {
                views.setTextViewText(R.id.widget_tasks, "✓ Bugün görev yok!")
            } else {
                views.setTextViewText(R.id.widget_tasks, tasksDetail)
            }

            // Habits
            val habitsCount = prefs.getString("flutter.widget_habits_count", "0") ?: "0"
            val habitsDetail = prefs.getString("flutter.widget_habits_detail", "") ?: ""
            views.setTextViewText(R.id.widget_habits_count, habitsCount)
            if (habitsDetail.isEmpty()) {
                views.setTextViewText(R.id.widget_habits, "✓ Tüm alışkanlıklar tamamlandı!")
            } else {
                views.setTextViewText(R.id.widget_habits, habitsDetail)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
