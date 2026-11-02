# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "util/gettext"

module Loupe
  # Ported from data/resources/shortcuts-dialog.ui.
  #
  # The keyboard shortcuts window: seven sections, listed here in the order
  # and with the titles, accelerators and action names the .ui file gives.
  #
  # Three shapes of item appear in the .ui file and all three are kept:
  #
  # * an accelerator, spelled the way GTK parses it, and where one action has
  #   two keys ("<Ctrl>plus plus") both are listed in the one string;
  # * an action name instead of an accelerator, which lets libadwaita show
  #   whatever key is currently bound to that action rather than a hardcoded
  #   one;
  # * a text direction, for the four navigation items whose key depends on
  #   whether the interface runs left-to-right or right-to-left.
  #
  # The "shortcut window" message context upstream marks every title with is
  # part of the catalogue lookup, which arrives with the po/ component.
  #
  # AdwShortcutsDialog is a final GType, so this is a plain Ruby subclass
  # rather than a registered one; it adds the sections and nothing to the type.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    SECTIONS = [
      {
        title: "General Shortcuts",
        items: [
          {title: "Copy Image or Selected Text to Clipboard", accelerator: "<Ctrl>C"},
          {title: "Move Image to Trash", accelerator: "Delete"},
          {title: "Permanently Delete Image", accelerator: "<Shift>Delete"},
          {title: "Open Image with Other App", accelerator: "<Ctrl><Shift>O"},
          {title: "Set as Background", accelerator: "<Ctrl>F8"},
          {title: "New Window", action_name: "app.new-window"},
          {title: "Open Help", action_name: "app.help"},
          {title: "Show Keyboard Shortcuts", action_name: "app.shortcuts"},
          {title: "Close Window", action_name: "window.close"},
          {title: "Quit", action_name: "app.quit"},
        ],
      },
      {
        title: "Navigate Images",
        items: [
          {title: "Next Image", accelerator: "Right", direction: :ltr},
          {title: "Previous Image", accelerator: "Left", direction: :ltr},
          {title: "Next Image", accelerator: "Left", direction: :rtl},
          {title: "Previous Image", accelerator: "Right", direction: :rtl},
          {title: "First Image", accelerator: "Home"},
          {title: "Last Image", accelerator: "End"},
        ],
      },
      {
        title: "Rotate Image",
        items: [
          {title: "Rotate Clockwise", accelerator: "<Ctrl>R"},
          {title: "Rotate Counterclockwise", accelerator: "<Ctrl><Shift>R"},
        ],
      },
      {
        title: "Zoom Image",
        items: [
          {title: "Zoom In", accelerator: "<Ctrl>plus plus"},
          {title: "Zoom Out", accelerator: "<Ctrl>minus minus"},
          {title: "Best Fit", accelerator: "<Ctrl>0 0"},
          {title: "Original Scale", accelerator: "<Ctrl>1 1"},
          {title: "200% Scale", accelerator: "<Ctrl>2 2"},
        ],
      },
      {
        title: "Pan View",
        items: [
          {title: "Pan Left", accelerator: "<Ctrl>Left"},
          {title: "Pan Right", accelerator: "<Ctrl>Right"},
          {title: "Pan Up", accelerator: "<Ctrl>Up"},
          {title: "Pan Down", accelerator: "<Ctrl>Down"},
        ],
      },
      {
        title: "View",
        items: [
          {title: "Toggle Fullscreen", accelerator: "F11"},
          {title: "Leave Fullscreen", accelerator: "Escape"},
          {title: "Toggle Image Properties", accelerator: "<Alt>Return F9"},
          {title: "Show Main Menu", accelerator: "F10"},
        ],
      },
      {
        title: "Editing",
        items: [
          {title: "Open Editing View", accelerator: "E"},
          {title: "Replace Original", accelerator: "<Ctrl>S"},
          {title: "Save As", accelerator: "<Ctrl><Shift>S"},
          {title: "Cancel", accelerator: "Escape"},
          {title: "Rotate Clockwise", accelerator: "<Ctrl>R"},
          {title: "Rotate Counterclockwise", accelerator: "<Ctrl><Shift>R"},
          {title: "Mirror Horizontally", accelerator: "H"},
          {title: "Mirror Vertically", accelerator: "V"},
          {title: "Apply Crop", accelerator: "<Ctrl>Return"},
        ],
      },
    ].freeze

    def build
      tap do |dialog|
        SECTIONS.each { |definition| dialog.add(section(definition)) }
      end
    end

    def section(definition)
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = Util::Gettext.gettext(definition.fetch(:title))
        definition.fetch(:items).each { |item| section.add(shortcuts_item(item)) }
      end
    end

    # Positional, not keyword, arguments, and neither may be nil — even for an
    # item that carries an action name rather than an accelerator, where the
    # accelerator starts out empty and libadwaita fills the key in from the
    # action.
    def shortcuts_item(definition)
      Adwaita::ShortcutsItem.new(
        Util::Gettext.gettext(definition.fetch(:title)),
        definition.fetch(:accelerator, ""),
      ).tap do |item|
        definition[:action_name].then do |action_name|
          unless action_name.nil?
            item.action_name = action_name
          end
        end

        definition[:direction].then do |direction|
          unless direction.nil?
            item.direction = direction
          end
        end
      end
    end
  end
end
