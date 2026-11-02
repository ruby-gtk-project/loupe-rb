# frozen_string_literal: true

require "gtk4"

require_relative "util/gettext"

module Loupe
  # Ported from src/util.rs.
  #
  # The grab bag upstream keeps beside the widgets: the metadata date format,
  # file-attribute queries, the filename ordering the image list sorts by,
  # recovering a file from the trash, the small enums the widgets pass around,
  # and the WCAG contrast maths the background-colour code uses.
  #
  # Upstream's enums (`Position`, `Direction`, `Gesture`, `ErrorType`) become
  # symbols here, with the permitted values named as frozen arrays so a typo
  # is catchable rather than silently inert.
  module Util
    # Upstream: `enum Position { First, Last }`.
    POSITIONS = %i[first last].freeze

    # Upstream: `enum Direction { Back, Forward }`.
    DIRECTIONS = %i[back forward].freeze

    # Upstream: `enum Gesture { Rotate(f64), Scale }`. The rotate variant
    # carries a threshold offset, so a gesture is a symbol or a pair.
    GESTURES = %i[rotate scale].freeze

    # Upstream: `enum ErrorType { Loader, General }`.
    ERROR_TYPES = %i[loader general].freeze

    # The attributes upstream joins into FILE_ATTRIBUTE_TRASH before walking
    # trash:/// looking for a file's original path.
    TRASH_ATTRIBUTES = "standard::name,trash::orig-path"

    # Countries that measure in inches, per upstream's locale check.
    INCH_COUNTRIES = %w[US LR].freeze

    module_function

    # Returns the localized date + time string for a GLib::DateTime, or nil
    # when the format in the catalogue cannot be applied.
    #
    # Translators: upstream's format is "%x %X" and follows
    # <https://docs.gtk.org/glib/method.DateTime.format.html>.
    def datetime_fmt(datetime)
      Gettext.gettext("%x %X").then do |format|
        datetime.format(format)
      rescue GLib::Error => error
        warn("Could not format DateTime with '#{format}': #{error.message}")
        nil
      end
    end

    def file_display_name(file)
      query_attributes(file, [Gio::FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME]).display_name
    rescue GLib::Error
      nil
    end

    # Upstream joins the attribute names with commas and queries them in one
    # call; a failure is an error rather than a nil, so callers can say what
    # they were doing.
    def query_attributes(file, attributes)
      file.query_info(attributes.join(","), :none)
    end

    # Upstream compares two names by `glib::FilenameCollationKey`, which
    # splits a name into digit and non-digit runs so that "img9" sorts before
    # "img10". The Ruby bindings do not expose the collation key, so the key
    # is built the same way here: each run becomes a triple whose first slot
    # orders digits after text, and the triples compare element by element.
    def compare_by_name(name_a, name_b)
      collation_key(name_a) <=> collation_key(name_b)
    end

    def collation_key(name)
      name.to_s.scan(/\d+|\D+/).map do |run|
        if run.match?(/\A\d+\z/)
          [1, run.to_i, ""]
        else
          [0, 0, run]
        end
      end
    end

    # Recover a file from the trash.
    #
    # Based on Nautilus' implementation, as upstream notes, because GLib has
    # no untrash call of its own
    # <https://gitlab.gnome.org/GNOME/glib/-/issues/845>. Walks trash:///
    # looking for the entry whose original path is the one asked for, then
    # moves it back, picking "<name> (n).<ext>" when the original path is
    # taken again.
    def untrash(path)
      Gio::File.new_for_uri("trash:///").then do |trash|
        trash_entry(trash, path).then do |entry|
          if entry.nil?
            raise(Error, Gettext.gettext("Failed to restore image from trash"))
          else
            restore(entry, Gio::File.new_for_path(path))
          end
        end
      end
    end

    def trash_entry(trash, path)
      trash.enumerate_children(TRASH_ATTRIBUTES, :nofollow_symlinks).then do |enumerator|
        matching_entry(trash, enumerator, path.to_s)
      end
    rescue GLib::Error
      nil
    end

    def matching_entry(trash, enumerator, path)
      found = nil

      while (info = enumerator.next_file)
        original = info.get_attribute_byte_string("trash::orig-path")

        if original == path
          found = trash.get_child(info.name)
          break
        end
      end

      found
    end

    def restore(trash_file, original_file)
      trash_file.move(available_target(original_file), :nofollow_symlinks)
    rescue GLib::Error => error
      raise(Error, "#{Gettext.gettext("Failed to restore image from trash")}: #{error.message}")
    end

    # The first of the original path and "<stem> (1).<ext>", "<stem> (2).<ext>"
    # … that does not exist yet.
    def available_target(original_file)
      original_file.path.then do |path|
        (0..).lazy.map { |index| numbered_file(path, index) }.find { |file| !file.query_exists }
      end
    end

    def numbered_file(path, index)
      if index.zero?
        Gio::File.new_for_path(path)
      else
        File.extname(path).then do |extension|
          File.join(
            File.dirname(path),
            "#{File.basename(path, extension)} (#{index})#{extension}",
          )
        end.then { |numbered| Gio::File.new_for_path(numbered) }
      end
    end

    # Relative luminance
    # <https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html#dfn-relative-luminance>
    def relative_luminance(color)
      (0.2126 * srgb_linear(color.red)) +
        (0.7152 * srgb_linear(color.green)) +
        (0.0722 * srgb_linear(color.blue))
    end

    # Contrast ratio
    # <https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html#dfn-contrast-ratio>
    def contrast_ratio(color1, color2)
      [relative_luminance(color1), relative_luminance(color2)].then do |luminances|
        (luminances.max + 0.05) / (luminances.min + 0.05)
      end
    end

    def srgb_linear(value)
      if value <= 0.04045
        value / 12.92
      else
        ((value + 0.055) / 1.055)**2.4
      end
    end

    # Upstream reads LC_MEASUREMENT through setlocale and uses inches for the
    # USA and Liberia. The country is the part of the locale name after the
    # underscore.
    def locale_uses_inch?
      measurement_locale.to_s.split("_")[1].to_s[0, 2].then do |country|
        INCH_COUNTRIES.include?(country)
      end
    end

    def measurement_locale
      ENV["LC_ALL"] || ENV["LC_MEASUREMENT"] || ENV["LANG"]
    end

    # Raised where upstream returns an `anyhow::Error` the caller is expected
    # to surface to the user.
    class Error < StandardError; end
  end
end
