# frozen_string_literal: true

module Loupe
  class Decoder
    # Ported from src/decoder/formats.rs.
    #
    # Upstream's `format_decoder` (src/decoder.rs) picks between two decoder
    # backends by MIME type: librsvg for every `image/svg+xml*` variant
    # (including the compressed one, `image/svg+xml-compressed`), glycin for
    # everything else. This port has one decoder, built on GdkPixbuf rather
    # than glycin (see decoder.rb for why), but SVG still needs to be told
    # apart from a raster format: it is the one format GdkPixbuf hands back a
    # fixed-but-arbitrary pixel size for rather than the image's real
    # dimensions, so callers that care about an SVG's native resolution (the
    # editor's crop tool, a future round) still need to know which this is.
    module Formats
      # Upstream's RSVG_MAX_SIZE, carried over verbatim: librsvg's current
      # ceiling on a rendered dimension.
      # https://gitlab.gnome.org/GNOME/librsvg/-/issues/938
      RSVG_MAX_SIZE = 32_767

      # True for both `image/svg+xml` and `image/svg+xml-compressed`, the two
      # MIME types upstream's own `mime_type.split('+').next() == "image/svg"`
      # matches.
      def self.svg?(mime_type)
        mime_type.to_s.split("+").first == "image/svg"
      end
    end
  end
end
