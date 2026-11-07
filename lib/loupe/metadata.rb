# frozen_string_literal: true

require "libgweather"

require_relative "util/gettext"

module Loupe
  # Ported from the GPS-place half of src/metadata.rs's `Metadata` struct.
  #
  # Upstream's full struct also parses EXIF/XMP (gufo), image/frame details
  # (glycin) and ICC profiles (moxcms); none of those three crates has a
  # Ruby binding, so this port carries over only the piece that needs
  # nothing but a latitude/longitude pair: turning GPS coordinates into
  # "City, Country" with GWeather's bundled world database, or the raw
  # degrees/minutes/seconds when no city is close enough.
  #
  # The coordinates themselves come from GIO's `metadata::location-*`
  # attributes (`Metadata::File`, in file.rb) rather than from gufo's EXIF
  # parser: those attributes are the same ones Nautilus and GNOME Photos
  # read a photo's GPS tags through, populated by tracker-extract.
  module Metadata
    # Upstream's 15km cutoff for trusting GWeather's nearest city.
    MAX_CITY_DISTANCE_KM = 15.0

    module_function

    # Upstream's `gps_location_place`: "City, Country" from GWeather's
    # world database when a city is within 15km of the coordinates,
    # falling back to `gps_location_display` otherwise.
    def gps_location_place(lat, lon)
      nearby_city_name(lat, lon) || gps_location_display(lat, lon)
    end

    # Upstream's `gps_location_display`: degrees/minutes/seconds with
    # N/S/E/W reference letters, one coordinate per line.
    def gps_location_display(lat, lon)
      [dms_line(lat, "N", "S"), dms_line(lon, "E", "W")].join("\n")
    end

    def nearby_city_name(lat, lon)
      GWeather::Location.world.then { |world| world && city_name_within(world, lat, lon) }
    end

    def city_name_within(world, lat, lon)
      world.find_nearest_city(lat, lon).then do |nearest|
        exact = GWeather::Location.new("", nil, lat, lon)
        nearest.get_distance(exact) < MAX_CITY_DISTANCE_KM ? place_name(nearest) : nil
      end
    end

    def place_name(location)
      [location.city_name, location.country_name].then do |city, country|
        city && country ? "#{city}, #{country}" : nil
      end
    end

    def dms_line(value, positive_ref, negative_ref)
      ref = value.negative? ? Util::Gettext.gettext(negative_ref) : Util::Gettext.gettext(positive_ref)
      deg_min_sec(value.abs).then { |deg, min, sec| format("%d° %d′ %05.2f″ %s", deg, min, sec, ref) }
    end

    def deg_min_sec(value)
      value.to_i.then do |deg|
        ((value - deg) * 60).then do |min_float|
          min_float.to_i.then { |min| [deg, min, (min_float - min) * 60] }
        end
      end
    end
  end
end
