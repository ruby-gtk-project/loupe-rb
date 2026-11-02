# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "config"
require_relative "settings"
require_relative "shortcuts_dialog"
require_relative "style"
require_relative "util/gettext"
require_relative "util/root"
require_relative "window"

module Loupe
  # Ported from src/application.rs.
  #
  # The application object: the app id and flags, the forced dark colour
  # scheme, the window icon, the three app actions and their accelerators, and
  # the two entry points — activate for a plain launch, open for files handed
  # over by the command line or another app.
  #
  # Upstream subclasses adw::Application. Adwaita::Application works in these
  # bindings, so the port uses it rather than Gtk::Application, by composition
  # as the house style asks: the application is a memoized widget method like
  # any other.
  #
  # Two things upstream gets from its build system or its parent class are
  # done explicitly here. The GResource bundle it registers in main() becomes
  # Style.load, which puts the stylesheets and the custom icons where GTK
  # looks for them. And app.shortcuts, which upstream leaves to libadwaita
  # because the shortcuts dialog comes out of a .ui file, is registered here
  # against the ported ShortcutsDialog.
  class Application
    ACCELS = {
      "app.help"       => ["F1"],
      "app.quit"       => ["<Ctrl>Q"],
      "window.close"   => ["<Ctrl>W"],
      "app.new-window" => ["<Ctrl>N"],
    }.freeze

    HELP_URI = "help:loupe"

    def build
      app.tap do
        app.signal_connect("startup") { startup }

        app.signal_connect("activate") { activate }

        # The bindings hand the open signal the file array itself rather than
        # the array-and-count pair the C signature has.
        app.signal_connect("open") do |_app, files, _hint|
          open(files)
        end

        setup_actions
      end
    end

    def run = app.run([])

    def settings = @settings ||= Settings.new

    def app
      @app ||= Adwaita::Application.new(Config::APP_ID, :handles_open).tap do |application|
        application.resource_base_path = Config::RESOURCE_BASE_PATH
      end
    end

    def startup
      # Force dark theme.
      app.style_manager.color_scheme = :prefer_dark

      Style.load(Gdk::Display.default)

      Gtk::Window.set_default_icon_name(Config::APP_ID)
    end

    def activate
      new_window.present
    end

    # Handles opening files from the command line or other applications.
    def open(files)
      new_window.tap do |window|
        window.load_files(files)
        window.present
      end
    end

    def new_window
      Window.new(app).tap { |window| window.build }
    end

    def setup_actions
      app.add_action(help_action)
      app.add_action(quit_action)
      app.add_action(new_window_action)
      app.add_action(shortcuts_action)
      app.add_action(about_action)

      ACCELS.each { |name, accels| app.set_accels_for_action(name, accels) }
    end

    def help_action
      Gio::SimpleAction.new("help").tap do |action|
        action.signal_connect("activate") { show_help }
      end
    end

    # Give all windows the chance to handle close-request, rather than
    # quitting the application out from under them.
    def quit_action
      Gio::SimpleAction.new("quit").tap do |action|
        action.signal_connect("activate") do
          app.windows.each(&:close)
        end
      end
    end

    def new_window_action
      Gio::SimpleAction.new("new-window").tap do |action|
        action.signal_connect("activate") { activate }
      end
    end

    def shortcuts_action
      Gio::SimpleAction.new("shortcuts").tap do |action|
        action.signal_connect("activate") do
          ShortcutsDialog.new.build.present(app.active_window)
        end
      end
    end

    def about_action
      Gio::SimpleAction.new("about").tap do |action|
        action.signal_connect("activate") do
          app.active_window.then do |window|
            unless window.nil?
              window.show_about
            end
          end
        end
      end
    end

    def show_help
      Gio::AppInfo.launch_default_for_uri(HELP_URI, launch_context)
    rescue GLib::Error => error
      warn("Failed to launch help: #{error.message}")
    end

    def launch_context
      app.active_window.then do |window|
        window&.display&.app_launch_context
      end
    end
  end
end
