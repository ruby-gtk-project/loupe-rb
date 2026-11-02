# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "util/gettext"

module Loupe
  # Ported from src/widgets/drag_overlay.rs and src/widgets/drag_overlay.ui.
  #
  # Wraps its content and crossfades a dashed "Drop Image to View" status page
  # over it while an image is being dragged across the window. Upstream notes
  # the implementation is inspired by Amberol.
  #
  # The reveal is driven entirely by the drop target handed in at
  # construction: upstream watches that target's current-drop property rather
  # than its enter/leave signals, so the overlay follows the drop GTK actually
  # has rather than pointer motion.
  #
  # The CSS name is lpdragoverlay, which style.css's "lpdragoverlay
  # .overlay-status" rules select on.
  class DragOverlay < Adwaita::Bin
    type_register
    set_css_name "lpdragoverlay"

    def initialize(drop_target)
      super()
      @drop_target = drop_target
    end

    attr_reader :drop_target

    def build
      tap do
        self.child = overlay

        overlay.tap do |over|
          over.add_overlay(revealer)

          revealer.tap do |rev|
            rev.child = status_background

            status_background.tap { |background| background.child = status_page }
          end
        end

        drop_target.signal_connect("notify::current-drop") do |target, _param|
          revealer.reveal_child = !target.current_drop.nil?
        end
      end
    end

    # Upstream's `content` property: the widget the overlay sits on top of.
    def content=(widget)
      overlay.child = widget
    end

    def content = overlay.child

    def overlay = @overlay ||= Gtk::Overlay.new

    def revealer
      @revealer ||= Gtk::Revealer.new.tap do |rev|
        rev.can_target = false
        rev.transition_type = :crossfade
      end
    end

    def status_background
      @status_background ||= Adwaita::Bin.new.tap do |bin|
        bin.add_css_class("background")
      end
    end

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = Util::Gettext.gettext("Drop Image to View")
        page.icon_name = "image-round-symbolic"
        page.add_css_class("overlay-status")
      end
    end
  end
end
