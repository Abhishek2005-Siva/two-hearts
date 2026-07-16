package com.twohearts.two_hearts

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Shows the partner's most recently sent drawing (a static PNG cached to
// disk by the Dart FCM handler in main.dart — see
// _handleHomeWidgetDrawingMessage). Tapping the widget opens the app's
// Draw screen via the existing `twohearts://` scheme.
class DrawingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val imagePath = widgetData.getString("drawing_image_path", null)
        val clickIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("twohearts://room/draw")
        )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.drawing_widget)
            views.setOnClickPendingIntent(R.id.drawing_widget_root, clickIntent)

            val bitmap = imagePath?.let { BitmapFactory.decodeFile(it) }
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.drawing_widget_image, bitmap)
                views.setViewVisibility(R.id.drawing_widget_image, View.VISIBLE)
                views.setViewVisibility(R.id.drawing_widget_empty, View.GONE)
            } else {
                views.setViewVisibility(R.id.drawing_widget_image, View.GONE)
                views.setViewVisibility(R.id.drawing_widget_empty, View.VISIBLE)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
