# frozen_string_literal: true

require "adwaita"

module Loupe
  # Ported from src/widgets/shy_bin.rs.
  #
  # A bin that does not claim its child's full width as its natural width.
  # The header bar is wrapped in one of these so a long file name in the
  # window title cannot grow the window — only the bin's minimum width (the
  # title label's ellipsized minimum) counts toward layout, never its natural
  # width.
  #
  # Upstream drops the default layout manager and implements measure and
  # size_allocate itself. The Ruby bindings expose those same widget-class
  # virtuals as `virtual_do_measure` / `virtual_do_size_allocate` (see
  # gnome-disk-utility-rb's SpaceAllocationBar for the same pattern), so the
  # port overrides them the same way instead of needing a C extension.
  class ShyBin < Adwaita::Bin
    type_register

    def initialize
      super()
      self.layout_manager = nil
      self.hexpand = true
    end

    # Natural width is clamped down to minimum width; every other measure
    # (vertical, and both baselines) passes the child's numbers through.
    def virtual_do_measure(orientation, for_size)
      minimum, natural, min_baseline, nat_baseline = child.measure(orientation, for_size)
      if orientation == :horizontal
        [minimum, minimum, min_baseline, nat_baseline]
      else
        [minimum, natural, min_baseline, nat_baseline]
      end
    end

    def virtual_do_size_allocate(width, height, baseline)
      child.allocate(width, height, baseline, nil)
    end
  end
end
