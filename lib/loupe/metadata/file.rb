# frozen_string_literal: true

require "gtk4"

require_relative "../metadata"

module Loupe
  module Metadata
    # Ported from src/metadata/file.rs.
    #
    # The file-system facts the Metadata model shows alongside the EXIF/XMP
    # data: the display name, the size, the two timestamps, the host
    # path a flatpak sandbox exposes through the document portal's xattr,
    # and (not in upstream's version, which gets these from gufo's EXIF
    # parser instead) the GPS coordinates GIO's `metadata::location-*`
    # attributes report when tracker-extract has indexed the file.
    #
    # Upstream queries these asynchronously as a single batch; the Ruby
    # bindings expose only the synchronous `query_info`, so `new` queries
    # eagerly and raises the same way every other file query in this port
    # does, leaving the caller to decide how to report it.
    class FileInfo
      # Upstream's `ATTRIBUTE_HOST_PATH` constant.
      ATTRIBUTE_HOST_PATH = "xattr::document-portal.host-path"

      # Not upstream's: GIO's own GPS attributes, filled in by
      # tracker-extract from a photo's EXIF tags, the same pair Nautilus
      # and GNOME Photos read location out of.
      ATTRIBUTE_GPS_LATITUDE = "metadata::location-latitude"
      ATTRIBUTE_GPS_LONGITUDE = "metadata::location-longitude"

      ATTRIBUTES = [
        Gio::FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME,
        Gio::FILE_ATTRIBUTE_STANDARD_SIZE,
        Gio::FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE,
        Gio::FILE_ATTRIBUTE_TIME_CREATED,
        Gio::FILE_ATTRIBUTE_TIME_MODIFIED,
        ATTRIBUTE_HOST_PATH,
        ATTRIBUTE_GPS_LATITUDE,
        ATTRIBUTE_GPS_LONGITUDE,
      ].join(",")

      def self.new_for_file(file)
        file.query_info(ATTRIBUTES, :none).then { |info| new(info) }
      end

      def initialize(file_info)
        @display_name = file_info.display_name
        # Upstream only keeps a size greater than zero: a size of exactly
        # zero means the attribute was not reported at all.
        @file_size = file_info.size.then { |size| size.positive? ? size : nil }
        @created = file_info.creation_date_time
        @modified = file_info.modification_date_time
        @host_path = file_info.get_attribute_as_string(ATTRIBUTE_HOST_PATH)
        @gps_latitude = attribute_float(file_info, ATTRIBUTE_GPS_LATITUDE)
        @gps_longitude = attribute_float(file_info, ATTRIBUTE_GPS_LONGITUDE)
      end

      attr_reader :display_name, :file_size, :created, :modified, :host_path, :gps_latitude, :gps_longitude

      # "City, Country" (via `Loupe::Metadata`, which calls into
      # `libgweather`) when GPS coordinates were found, falling back to
      # the raw degrees/minutes/seconds, or nil with neither.
      def gps_location_place
        has_gps_location? ? Loupe::Metadata.gps_location_place(gps_latitude, gps_longitude) : nil
      end

      def has_gps_location? = !gps_latitude.nil? && !gps_longitude.nil?

      private

        def attribute_float(file_info, attribute)
          file_info.get_attribute_as_string(attribute).then do |value|
            value.nil? || value.empty? ? nil : Float(value, exception: false)
          end
        end
    end
  end
end
