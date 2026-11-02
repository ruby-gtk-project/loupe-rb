# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "../util"

module Loupe
  module Util
    # Ported from src/util/root.rs.
    #
    # Upstream declares a `ParentWindow` trait and blanket-implements it for
    # every widget, so any widget deep in the tree can reach the LpWindow it
    # sits in and post a toast or an error through it without being handed a
    # reference. The Ruby equivalent is a module mixed into Gtk::Widget, which
    # `Root.install` does at the bottom of this file.
    #
    # The trait's `window` and `try_window` are `loupe_window` and
    # `try_loupe_window` here: Gtk::Widget already answers to names in that
    # neighbourhood, and a mixin into a binding class has no business shadowing
    # them.
    module Root
      # Upstream's `window()`: the root cast to LpWindow, loudly when the cast
      # fails, because a widget that cannot find its window is a bug in the
      # tree rather than a condition to handle.
      def loupe_window
        try_loupe_window.then do |window|
          if window.nil?
            raise(Util::Error, "Couldn't find Loupe::Window for #{self.class}. mapped=#{mapped?}")
          else
            window
          end
        end
      end

      # Upstream's `try_window()`: the same lookup, reporting the miss and
      # handing back nil.
      def try_loupe_window
        root.then do |found|
          if found.is_a?(Loupe::Window)
            found
          else
            warn("Couldn't find Loupe::Window for #{self.class}. mapped=#{mapped?}")
            nil
          end
        end
      end

      # Upstream's `window_inspect`: run the block with the window if there is
      # one, do nothing if there is not.
      def window_inspect
        try_loupe_window.then do |window|
          unless window.nil?
            yield(window)
          end
        end
      end

      def window_show_toast(text, priority)
        window_inspect { |window| window.show_toast(text, priority) }
      end

      def window_add_toast(toast)
        window_inspect { |window| window.add_toast(toast) }
      end

      def window_show_error(stub, details, error_type)
        window_inspect { |window| window.show_error(stub, details, error_type) }
      end

      # Upstream's blanket `impl<T: WidgetExt> ParentWindow for T`.
      def self.install
        Gtk::Widget.include(self)
      end
    end
  end
end

Loupe::Util::Root.install
