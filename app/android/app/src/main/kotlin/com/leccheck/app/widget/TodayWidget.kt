package com.leccheck.app.widget

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.components.CircleIconButton
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.leccheck.app.MainActivity
import com.leccheck.app.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import org.json.JSONArray
import org.json.JSONObject

private val KeyMeeting = ActionParameters.Key<String>("meeting")
private val KeyDate = ActionParameters.Key<String>("date")
private val KeyStatus = ActionParameters.Key<String>("status")

private data class WidgetSession(
  val meeting: String,
  val date: String,
  val course: String,
  val color: Int,
  val detail: String,
  val status: String,
  val statusLabel: String,
  val start: Long,
)

/**
 * "Today" widget: today's sessions with one-tap Attended / Missed buttons for
 * sessions that have started. Renders the JSON snapshot written by the app
 * (lib/core/home_widget/today_widget.dart); buttons call back into Dart.
 */
class TodayWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()
  override val sizeMode = SizeMode.Exact

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { GlanceTheme { Content(currentState()) } }
  }

  @Composable
  private fun Content(state: HomeWidgetGlanceState) {
    val data = state.preferences.getString("today", null)?.let {
      runCatching { JSONObject(it) }.getOrNull()
    }
    val sessions = data?.optJSONArray("sessions")?.let(::parseSessions).orEmpty()
    // Decided at render time, so buttons appear once a session starts.
    val now = System.currentTimeMillis()

    Column(
      modifier = GlanceModifier.fillMaxSize()
        .cornerRadius(24.dp)
        .background(GlanceTheme.colors.widgetBackground)
        .padding(horizontal = 14.dp, vertical = 12.dp)
        .clickable(actionStartActivity<MainActivity>()),
    ) {
      Text(
        text = data?.optString("title").orEmpty().ifEmpty { "LecCheck" },
        style = TextStyle(
          color = GlanceTheme.colors.onSurface,
          fontSize = 16.sp,
          fontWeight = FontWeight.Bold,
        ),
        maxLines = 1,
      )
      val subtitle = data?.optString("subtitle").orEmpty()
      if (subtitle.isNotEmpty()) {
        Text(
          text = subtitle,
          style = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = 12.sp),
          maxLines = 1,
        )
      }
      Spacer(GlanceModifier.height(8.dp))
      if (sessions.isEmpty()) {
        Text(
          text = data?.optString("empty").orEmpty(),
          style = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = 14.sp),
        )
      } else {
        LazyColumn {
          items(sessions) { session -> SessionRow(session, now, data!!) }
        }
      }
    }
  }

  @Composable
  private fun SessionRow(s: WidgetSession, now: Long, data: JSONObject) {
    Row(
      modifier = GlanceModifier.fillMaxWidth().padding(vertical = 4.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Box(
        modifier = GlanceModifier.width(4.dp).height(36.dp)
          .cornerRadius(2.dp)
          .background(ColorProvider(Color(s.color))),
      ) {}
      Spacer(GlanceModifier.width(10.dp))
      Column(modifier = GlanceModifier.defaultWeight()) {
        Text(
          text = s.course,
          style = TextStyle(
            color = GlanceTheme.colors.onSurface,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
          ),
          maxLines = 1,
        )
        Text(
          text = s.detail,
          style = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = 12.sp),
          maxLines = 1,
        )
      }
      if (s.status == "pending" && s.start <= now) {
        CircleIconButton(
          imageProvider = ImageProvider(R.drawable.ic_widget_missed),
          contentDescription = data.optString("missed"),
          onClick = markAction(s, "missed"),
          modifier = GlanceModifier.size(38.dp),
          backgroundColor = GlanceTheme.colors.errorContainer,
          contentColor = GlanceTheme.colors.onErrorContainer,
        )
        Spacer(GlanceModifier.width(6.dp))
        CircleIconButton(
          imageProvider = ImageProvider(R.drawable.ic_widget_attended),
          contentDescription = data.optString("attended"),
          onClick = markAction(s, "attended"),
          modifier = GlanceModifier.size(38.dp),
          backgroundColor = GlanceTheme.colors.primaryContainer,
          contentColor = GlanceTheme.colors.onPrimaryContainer,
        )
      } else if (s.status != "pending") {
        Text(
          text = s.statusLabel,
          style = TextStyle(color = GlanceTheme.colors.primary, fontSize = 12.sp),
          maxLines = 1,
        )
      }
    }
  }

  private fun markAction(s: WidgetSession, status: String) =
    actionRunCallback<MarkSessionAction>(
      actionParametersOf(KeyMeeting to s.meeting, KeyDate to s.date, KeyStatus to status),
    )

  private fun parseSessions(array: JSONArray): List<WidgetSession> =
    (0 until array.length()).mapNotNull { i ->
      val o = array.optJSONObject(i) ?: return@mapNotNull null
      WidgetSession(
        meeting = o.optString("meeting"),
        date = o.optString("date"),
        course = o.optString("course"),
        color = o.optLong("color").toInt(),
        detail = o.optString("detail"),
        status = o.optString("status"),
        statusLabel = o.optString("statusLabel"),
        start = o.optLong("start"),
      )
    }
}

/** Forwards a button press to Dart (`todayWidgetCallback`) in the background. */
class MarkSessionAction : ActionCallback {
  override suspend fun onAction(
    context: Context,
    glanceId: GlanceId,
    parameters: ActionParameters,
  ) {
    val uri = Uri.Builder()
      .scheme("leccheck")
      .authority("mark")
      .appendQueryParameter("meeting", parameters[KeyMeeting])
      .appendQueryParameter("date", parameters[KeyDate])
      .appendQueryParameter("status", parameters[KeyStatus])
      .build()
    HomeWidgetBackgroundIntent.getBroadcast(context, uri).send()
  }
}
