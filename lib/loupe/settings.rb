# frozen_string_literal: true

require "fileutils"
require "json"

module Loupe
  # Ported from data/org.gnome.Loupe.gschema.xml.in.
  #
  # The schema holds one key: show-properties, a boolean defaulting to false,
  # summarised as "Show the image properties sidebar". Upstream reads it
  # through gio::Settings, which needs the schema compiled and installed into
  # a system glib-2.0/schemas directory before the app will even start.
  # Requiring an install step to run the port from a checkout is worse than
  # the alternative, so the same key, default and semantics are backed by a
  # small JSON file under XDG_CONFIG_HOME.
  class Settings
    DEFAULTS = {
      "show-properties" => false,
    }.freeze

    def initialize(path: nil)
      @path = path || default_path
      @values = DEFAULTS.merge(read)
    end

    def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

    def []=(key, value)
      @values[key.to_s] = value
      write
      value
    end

    def location = @path

    def show_properties = self["show-properties"]

    def show_properties? = self["show-properties"] == true

    def show_properties=(value)
      self["show-properties"] = value
    end

    private

      def default_path
        File.join(
          ENV.fetch("XDG_CONFIG_HOME", File.expand_path("~/.config")),
          "loupe-rb",
          "settings.json",
        )
      end

      def read
        if File.exist?(@path)
          JSON.parse(File.read(@path))
        else
          {}
        end
      rescue JSON::ParserError => error
        warn("Error parsing #{@path}: #{error.message}")
        {}
      end

      def write
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.pretty_generate(@values))
      end
  end
end
