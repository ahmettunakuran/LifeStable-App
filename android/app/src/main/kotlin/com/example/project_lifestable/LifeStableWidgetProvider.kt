package com.example.project_lifestable

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

class LifeStableWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            val tasksCount = widgetData.getInt("tasks_count", 0)
            val activeHabitsCount = widgetData.getInt("active_habits_count", 0)
            val tasksJsonStr = widgetData.getString("tasks_data", "[]")

            views.setTextViewText(R.id.tv_tasks, "Pending Tasks: \$tasksCount")
            views.setTextViewText(R.id.tv_habits, "Active Habits: \$activeHabitsCount")

            var nextUp = "Next up: None"
            try {
                val tasksArray = JSONArray(tasksJsonStr)
                for (i in 0 until tasksArray.length()) {
                    val task = tasksArray.getJSONObject(i)
                    if (!task.getBoolean("isDone")) {
                        nextUp = "Next up: \${task.getString("title")}"
                        break
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            views.setTextViewText(R.id.tv_next_task, nextUp)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
