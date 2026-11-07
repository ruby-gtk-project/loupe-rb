# frozen_string_literal: true

require "gdk_pixbuf2"
require "gio2"

require_relative "decoder/formats"
require_relative "util/gettext"

module Loupe
  # Ported from src/decoder.rs, src/decoder/formats.rs,
  # src/decoder/formats/glycin_proxy.rs and src/decoder/formats/svg.rs.
  #
  # Upstream's decoder is sandboxed, asynchronous and tile-based: it hands a
  # `gio::File` to glycin (which forks a separate process per format to open
  # the file), and as frames or tiles come back it writes them into a
  # `SharedFrameBuffer` (decoder/tiling.rs — 700 lines of chunked, zoom- and
  # viewport-aware buffering for images too large to decode and hold in full
  # at once) and sends a `DecoderUpdate` down an async channel so the LpImage
  # widget's renderer can redraw.
  #
  # None of that machinery has a Ruby equivalent to port it onto: there is no
  # Ruby binding for glycin's sandboxed loader API (the `glycin` and
  # `libglycin-gtk4` RubyGems that exist wrap the GObject-Introspected
  # `Gly`/`GlyGtk4` C libraries, a different, synchronous, unsandboxed API
  # surface with no tile or frame-buffer concept), and this app's gemspec
  # does not declare either — only `libgweather`, for the GPS-to-place lookup
  # in metadata.rb, is a mandated binding this round. Tiling itself is also
  # upstream's own optimisation for pathologically large images; dropping it
  # for a decoder that loads an image in one pass is the kind of
  # simplification the house porting style asks for (see
  # references/planning-methodology.md in the ruby-gtk skill: identify
  # over-engineered aggregator/chunk systems in the source and drop them).
  #
  # So this port decodes synchronously with GdkPixbuf, which every GTK
  # install already carries loaders for (PNG, JPEG, GIF, BMP, TIFF, WebP, and
  # SVG via librsvg's gdk-pixbuf loader module where it is installed): one
  # `GdkPixbuf::PixbufLoader`, fed the file's bytes, is the entire decode.
  # What survives the port is the caller-facing shape upstream's `Decoder`
  # has: `mime_type`, an SVG/raster distinction (Formats.svg?), and the same
  # three error buckets `UpdateSender#send_error` sorts a `glycin::Error`
  # into — unsupported format, the file could not be opened, or some other
  # failure — now sorted from the exceptions GdkPixbuf and GIO actually
  # raise.
  class Decoder
    # One of the buckets `error` can return. Mirrors upstream's
    # `DecoderError` enum, minus the two variants (`NoLoadersConfigured`,
    # `OutOfMemory`) that are specific to glycin's sandboxed-loader protocol
    # and have no analogue in a direct GdkPixbuf decode.
    class Error < StandardError
      attr_reader :kind, :mime_type

      # +kind+ is one of :unsupported_format, :image_source or :generic.
      def initialize(kind, message, mime_type: nil)
        super(message)
        @kind = kind
        @mime_type = mime_type
      end

      def unsupported_format? = kind == :unsupported_format

      def image_source? = kind == :image_source
    end

    READ_CHUNK_SIZE = 1 << 16

    # Decode +file+ (a Gio::File) right away and return the finished
    # decoder. Mirrors upstream's `Decoder::new`, minus the receiver half:
    # callers read `pixbuf`/`error` off the object it returns instead of
    # listening for `DecoderUpdate`s, since there is no asynchronous phase
    # left to report partial progress on.
    def self.load(file) = new(file).tap(&:load)

    def initialize(file)
      @file = file
      @pixbuf = nil
      @mime_type = nil
      @error = nil
    end

    attr_reader :pixbuf, :mime_type, :error

    def loaded? = !@pixbuf.nil?

    # Upstream's `mime_type.split('+').next() == Some("image/svg")` check
    # that chooses the Svg format decoder over the Glycin one.
    def svg? = Formats.svg?(@mime_type)

    def load
      @mime_type = query_mime_type
      @pixbuf = decode_pixbuf
      @error = nil
      self
    rescue GLib::ErrorInfo => error
      @pixbuf = nil
      @error = classify(error)
      self
    end

    private

      def query_mime_type
        @file.query_info("standard::content-type", :none)
             .get_attribute_string("standard::content-type")
      rescue GLib::ErrorInfo
        nil
      end

      # Upstream's loader.load(): read the whole file through a
      # GdkPixbuf::PixbufLoader, then apply any EXIF/embedded orientation so
      # callers see the image the way it should be displayed, same as
      # glycin's own `apply_transformations` would (upstream turns that off
      # only because it reads orientation itself for the rotation widget;
      # this port has no rotation widget yet, so there is nothing that would
      # conflict with letting GdkPixbuf apply it once, here).
      def decode_pixbuf
        loader = GdkPixbuf::PixbufLoader.new
        stream = @file.read
        begin
          until (bytes = stream.read_bytes(READ_CHUNK_SIZE)).size.zero?
            loader.write_bytes(bytes)
          end
          loader.close
        ensure
          stream.close
        end
        loader.pixbuf.apply_embedded_orientation
      end

      # Upstream's `UpdateSender#send_error`, sorted from the exceptions
      # GdkPixbuf and GIO actually raise instead of from `glycin::Error`'s
      # own predicates.
      def classify(error)
        if error.is_a?(GdkPixbuf::PixbufError::UnknownType)
          Error.new(:unsupported_format, error.message, mime_type: @mime_type)
        elsif error.is_a?(Gio::IOError) || error.is_a?(GLib::FileError)
          Error.new(:image_source, error.message)
        else
          Error.new(:generic, error.message)
        end
      end
  end
end
