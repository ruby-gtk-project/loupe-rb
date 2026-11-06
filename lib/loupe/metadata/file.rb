# frozen_string_literal: true

require "gtk4"

module Loupe
  module Metadata
    # Ported from src/metadata/file.rs.
    #
    # The file-system facts the Metadata model shows alongside the EXIF/XMP
    # data: the display name, the size, the two timestamps, and the host
    # path a flatpak sandbox exposes through the document portal's xattr.
    #
    # Upstream queries these asynchronously as a single batch; the Ruby
    # bindings expose only the synchronous `query_info`, so `new` queries
    # eagerly and raises the same way every other file query in this port
    # does, leaving the caller to decide how to report it.
    class FileInfo
      # Upstream's `ATTRIBUTE_HOST_PATH` constant.
      ATTRIBUTE_HOST_PATH = "xattr::document-portal.host-path"

      ATTRIBUTES = [
        Gio::FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME,
        Gio::FILE_ATTRIBUTE_STANDARD_SIZE,
        Gio::FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE,
        Gio::FILE_ATTRIBUTE_TIME_CREATED,
        Gio::FILE_ATTRIBUTE_TIME_MODIFIED,
        ATTRIBUTE_HOST_PATH,
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
      end

      attr_reader :display_name, :file_size, :created, :modified, :host_path
    end
  end
end
