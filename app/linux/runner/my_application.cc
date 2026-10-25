#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Desktops whose apps draw their own title bar (GTK header bars). Elsewhere
// (Hyprland, Sway, KDE, …) the window manager decides, so no header bar.
static gboolean uses_header_bars() {
  const gchar* desktop = g_getenv("XDG_CURRENT_DESKTOP");
  if (desktop == nullptr) return FALSE;
  g_auto(GStrv) names = g_strsplit(desktop, ":", -1);
  for (gchar** name = names; *name != nullptr; name++) {
    if (g_ascii_strcasecmp(*name, "GNOME") == 0 ||
        g_ascii_strcasecmp(*name, "Unity") == 0 ||
        g_ascii_strcasecmp(*name, "Pantheon") == 0 ||
        g_ascii_strcasecmp(*name, "Budgie") == 0) {
      return TRUE;
    }
  }
  return FALSE;
}

// The window's size and whether it was maximized, kept between launches in
// $XDG_CONFIG_HOME/com.leccheck.app/window.ini. Not its position: Wayland
// compositors place windows themselves.
struct WindowState {
  gint width = 1280;
  gint height = 820;
  gboolean maximized = FALSE;
};
static WindowState window_state;

static gchar* window_state_path() {
  return g_build_filename(g_get_user_config_dir(), APPLICATION_ID,
                          "window.ini", nullptr);
}

static void load_window_state() {
  g_autofree gchar* path = window_state_path();
  g_autoptr(GKeyFile) file = g_key_file_new();
  if (!g_key_file_load_from_file(file, path, G_KEY_FILE_NONE, nullptr)) return;
  g_autoptr(GError) error = nullptr;
  const gint width = g_key_file_get_integer(file, "window", "width", &error);
  if (error != nullptr) return;
  const gint height = g_key_file_get_integer(file, "window", "height", &error);
  if (error != nullptr) return;
  // A broken file shouldn't open a window too small to use.
  if (width >= 360 && height >= 600) {
    window_state.width = width;
    window_state.height = height;
  }
  window_state.maximized =
      g_key_file_get_boolean(file, "window", "maximized", nullptr);
}

static void save_window_state() {
  g_autofree gchar* path = window_state_path();
  g_autofree gchar* dir = g_path_get_dirname(path);
  g_mkdir_with_parents(dir, 0700);
  g_autoptr(GKeyFile) file = g_key_file_new();
  g_key_file_set_integer(file, "window", "width", window_state.width);
  g_key_file_set_integer(file, "window", "height", window_state.height);
  g_key_file_set_boolean(file, "window", "maximized", window_state.maximized);
  g_autoptr(GError) error = nullptr;
  if (!g_key_file_save_to_file(file, path, &error)) {
    g_warning("Window size not saved: %s", error->message);
  }
}

static guint save_source = 0;

static gboolean on_save_due(gpointer) {
  save_source = 0;
  save_window_state();
  return G_SOURCE_REMOVE;
}

// Saves half a second after the last change. Saving on "destroy" never ran:
// Flutter's engine quits the application when the window is closed without
// destroying it, and resizing sends many events.
static void save_soon() {
  if (save_source != 0) g_source_remove(save_source);
  save_source = g_timeout_add(500, on_save_due, nullptr);
}

// Remembers the size while the window isn't maximized, so un-maximizing
// next time goes back to it.
static gboolean on_configure(GtkWidget* widget, GdkEvent*, gpointer) {
  if (!window_state.maximized) {
    gint width, height;
    gtk_window_get_size(GTK_WINDOW(widget), &width, &height);
    if (width != window_state.width || height != window_state.height) {
      window_state.width = width;
      window_state.height = height;
      save_soon();
    }
  }
  return FALSE;
}

static gboolean on_window_state(GtkWidget*, GdkEventWindowState* event,
                                gpointer) {
  const gboolean maximized =
      (event->new_window_state & GDK_WINDOW_STATE_MAXIMIZED) != 0;
  if (maximized != window_state.maximized) {
    window_state.maximized = maximized;
    save_soon();
  }
  return FALSE;
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  // Single instance: launching LecCheck again shows the running window
  // instead of opening a second copy on the same database.
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows != nullptr) {
    gtk_window_present(GTK_WINDOW(windows->data));
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  if (uses_header_bars()) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "LecCheck");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "LecCheck");
  }

  load_window_state();
  gtk_window_set_default_size(window, window_state.width, window_state.height);
  if (window_state.maximized) gtk_window_maximize(window);
  g_signal_connect(window, "configure-event", G_CALLBACK(on_configure),
                   nullptr);
  g_signal_connect(window, "window-state-event", G_CALLBACK(on_window_state),
                   nullptr);
  // Narrower than this and even the phone layout gets cramped.
  GdkGeometry limits = {};
  limits.min_width = 360;
  limits.min_height = 600;
  gtk_window_set_geometry_hints(window, nullptr, &limits, GDK_HINT_MIN_SIZE);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);
  // Dart runs on GTK's main thread by default, so a slow frame also delays
  // GTK's drawing. LECCHECK_UI_THREAD=separate tries its own thread: compare
  // Settings → Developer → Rendering with and without it.
  if (g_strcmp0(g_getenv("LECCHECK_UI_THREAD"), "separate") == 0) {
    fl_dart_project_set_ui_thread_policy(
        project, FL_UI_THREAD_POLICY_RUN_ON_SEPARATE_THREAD);
  }

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // A change from the last half second isn't saved yet.
  if (save_source != 0) {
    g_source_remove(save_source);
    on_save_due(nullptr);
  }

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     static_cast<GApplicationFlags>(0),
                                     nullptr));
}
