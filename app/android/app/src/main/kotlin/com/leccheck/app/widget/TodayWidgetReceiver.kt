package com.leccheck.app.widget

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class TodayWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TodayWidget>() {
  override val glanceAppWidget = TodayWidget()
}
