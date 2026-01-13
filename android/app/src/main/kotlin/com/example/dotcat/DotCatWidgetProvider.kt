package com.example.dotcat

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.view.View
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DotCatWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Widget first enabled
    }

    override fun onDisabled(context: Context) {
        // Widget disabled
    }

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val APP_GROUP_ID = "group.com.petcare.dotcat"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            
            // Get data from shared preferences
            val tasksJson = prefs.getString("todayTasks", "[]") ?: "[]"
            val pendingCount = prefs.getInt("pendingCount", 0)
            val lastUpdate = prefs.getString("lastUpdate", null)
            
            // Update pending badge
            views.setTextViewText(R.id.pending_badge, pendingCount.toString())
            
            // Parse and display tasks
            try {
                val tasks = JSONArray(tasksJson)
                val taskViews = listOf(R.id.task_1, R.id.task_2, R.id.task_3)
                
                // Hide all tasks first
                taskViews.forEach { views.setViewVisibility(it, View.GONE) }
                
                if (tasks.length() == 0) {
                    views.setViewVisibility(R.id.empty_state, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.empty_state, View.GONE)
                    
                    for (i in 0 until minOf(tasks.length(), 3)) {
                        val task = tasks.getJSONObject(i)
                        val title = task.getString("title")
                        val isCompleted = task.optBoolean("isCompleted", false)
                        val time = task.optString("time", "")
                        
                        val displayText = if (time.isNotEmpty()) "$time - $title" else title
                        
                        views.setViewVisibility(taskViews[i], View.VISIBLE)
                        views.setTextViewText(taskViews[i], displayText)
                        
                        // Set icon based on completion status
                        val iconRes = if (isCompleted) R.drawable.ic_task_done else R.drawable.ic_task_pending
                        views.setImageViewResource(taskViews[i], iconRes)
                    }
                }
            } catch (e: Exception) {
                views.setViewVisibility(R.id.empty_state, View.VISIBLE)
            }
            
            // Update last update time
            if (lastUpdate != null) {
                try {
                    val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
                    val date = dateFormat.parse(lastUpdate)
                    val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
                    val formattedTime = timeFormat.format(date ?: Date())
                    views.setTextViewText(R.id.last_update, "Son güncelleme: $formattedTime")
                } catch (e: Exception) {
                    views.setTextViewText(R.id.last_update, "")
                }
            }
            
            // Set click intent to open app
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 
                0, 
                intent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            // Update widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

