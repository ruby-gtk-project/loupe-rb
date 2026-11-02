# frozen_string_literal: true

require "gtk4"

require_relative "config"

module Loupe
  # Ported from data/resources/style.css, data/resources/edit.css and
  # data/resources/edit_crop.css, plus the custom symbolic icons under
  # data/resources/icons.
  #
  # Upstream compiles all of it into a GResource bundle with
  # `gvdb_macros::include_gresource_from_dir!("/org/gnome/Loupe",
  # "data/resources")`, registers the bundle at startup and lets GTK pick the
  # stylesheet and the icons up from the application's resource base path.
  #
  # The Ruby bindings expose no way to build a GResource bundle from a
  # directory at run time, so the port ships the same files as plain files and
  # registers them against the display directly: the stylesheet through a
  # CssProvider (which resolves style.css's two @import lines relative to the
  # file, so all three sheets load), and the icons by adding their directory
  # to the icon theme's search path. The icons sit under a hicolor/ directory
  # because that is the layout a filesystem search path is scanned in; the
  # icon names the .ui files ask for are unchanged.
  module Style
    STYLESHEET = "style.css"
    ICON_DIRECTORY = "icons"

    def self.load(display)
      Gtk::StyleContext.add_provider_for_display(
        display,
        provider,
        Gtk::StyleProvider::PRIORITY_APPLICATION,
      )

      Gtk::IconTheme.get_for_display(display).add_search_path(icon_search_path)
    end

    def self.provider
      Gtk::CssProvider.new.tap { |css| css.load_from_path(stylesheet) }
    end

    def self.stylesheet = File.join(Config.data_dir, STYLESHEET)

    def self.icon_search_path = File.join(Config.data_dir, ICON_DIRECTORY)
  end
end
