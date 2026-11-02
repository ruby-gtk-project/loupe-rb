# frozen_string_literal: true

module Loupe
  # Ported from src/config.rs.
  #
  # Upstream bakes three strings into the binary at compile time with
  # `option_env!`: meson passes APP_ID, VERSION and LOCALEDIR, and each falls
  # back to a literal when the variable is absent. A Ruby gem has no compile
  # step, so the same three names are read from the process environment with
  # the same three fallbacks — a packaging recipe can export them, and a plain
  # checkout still runs.
  module Config
    APP_ID = ENV.fetch("APP_ID", "org.gnome.Loupe.Devel")
    VERSION = ENV.fetch("VERSION", "unknown")
    LOCALEDIR = ENV.fetch("LOCALEDIR", "/usr/share/locale/")

    # Upstream's `resource_base_path` for the GResource bundle built by
    # `gvdb_macros::include_gresource_from_dir!("/org/gnome/Loupe",
    # "data/resources")`.
    RESOURCE_BASE_PATH = "/org/gnome/Loupe"

    # The directory that bundle is built from. The port ships the same files as
    # plain files rather than compiling them into a bundle, so the stylesheets
    # and the custom symbolic icons are loaded from here (see Loupe::Style).
    def self.data_dir = File.expand_path("../../data/resources", __dir__)

    # Upstream checks this suffix to decide whether to add the "devel" CSS
    # class to the window.
    def self.devel? = APP_ID.end_with?(".Devel")
  end
end
