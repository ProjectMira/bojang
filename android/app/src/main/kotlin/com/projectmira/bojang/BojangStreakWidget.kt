package com.projectmira.bojang

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Home-screen streak widget (plan #25), drawn with RemoteViews.
 *
 * The app writes the data with home_widget (lib/utils/widget_snapshot.dart
 * is the contract): streak, streak_state (none/active/frozen/earn_back),
 * last_done_date, the word of the day and one headline per part of day
 * (line_day, line_evening, line_late, line_last_call, line_done).
 *
 * The part of day and "done today" are worked out here from the clock, so
 * the widget moves from day to last call (and resets after midnight) on
 * its own between app opens. Android redraws it every 30 minutes
 * (updatePeriodMillis), and the app asks for a redraw on every change.
 */
class BojangStreakWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, render(context, widgetData))
        }
    }

    private fun render(context: Context, data: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.bojang_streak_widget)
        val now = Calendar.getInstance()
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now.time)
        val snapshotDay = data.getString("today", null)
        val doneToday = data.getString("last_done_date", "") == today
        var streak = readInt(data, "streak")
        var state = data.getString("streak_state", "none") ?: "none"

        // Data from before yesterday: the streak may have lapsed since. Show
        // a neutral state until the app is opened again.
        if (snapshotDay != null && snapshotDay < yesterday(now) && !doneToday) {
            state = if (state == "earn_back") state else "none"
            if (state == "none") streak = 0
        }

        val part = when (now.get(Calendar.HOUR_OF_DAY)) {
            in 0..15 -> "day"
            in 16..19 -> "evening"
            in 20..21 -> "late"
            else -> "last_call"
        }
        val headline = if (doneToday) data.getString("line_done", null)
        else data.getString("line_$part", null)

        views.setTextViewText(R.id.widget_streak, streak.toString())
        views.setTextViewText(
            R.id.widget_headline,
            headline ?: context.getString(R.string.widget_default_line),
        )
        views.setTextViewText(R.id.widget_word_tibetan, data.getString("word_tibetan", "") ?: "")
        val phonetic = data.getString("word_phonetic", "") ?: ""
        val english = data.getString("word_english", "") ?: ""
        views.setTextViewText(
            R.id.widget_word_meaning,
            if (phonetic.isEmpty()) english else "$phonetic · $english",
        )

        val icon = when {
            state == "frozen" && !doneToday -> R.drawable.widget_ice
            state == "earn_back" -> R.drawable.widget_flame_dim
            doneToday -> R.drawable.widget_flame
            part == "last_call" && streak > 0 -> R.drawable.widget_flame_dim
            streak > 0 -> R.drawable.widget_flame
            else -> R.drawable.widget_flame_dim
        }
        views.setImageViewResource(R.id.widget_icon, icon)
        views.setViewVisibility(R.id.widget_done, if (doneToday) View.VISIBLE else View.GONE)

        val launch = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_root, launch)
        return views
    }

    private fun yesterday(now: Calendar): String {
        val day = now.clone() as Calendar
        day.add(Calendar.DAY_OF_YEAR, -1)
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(day.time)
    }

    // home_widget stores Dart ints as Long.
    private fun readInt(data: SharedPreferences, key: String): Int = try {
        data.getLong(key, 0L).toInt()
    } catch (_: ClassCastException) {
        try { data.getInt(key, 0) } catch (_: ClassCastException) { 0 }
    }
}
