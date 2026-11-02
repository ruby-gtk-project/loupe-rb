# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "util/gettext"

module Loupe
  # Ported from src/widgets/error_details.rs and
  # src/widgets/error_details.ui.
  #
  # The dialog behind a failure toast's "Show Details" button: the error text
  # in a monospace, read-only, word-char-wrapping TextView inside a card, a
  # button that copies it to the clipboard, and a pill button that opens the
  # issue tracker.
  #
  # Which tracker, and which of the two descriptions the first preferences
  # group carries, depends on the error type. A :loader error came out of the
  # image loader, so it goes to glycin and asks for the offending image; a
  # :general error is the program's own, so it goes to loupe.
  class ErrorDetails < Adwaita::Dialog
    type_register

    ISSUE_URIS = {
      loader:  "https://gitlab.gnome.org/GNOME/glycin/-/issues",
      general: "https://gitlab.gnome.org/GNOME/loupe/-/issues",
    }.freeze

    # Shown for a :loader error, as the .ui file's default.
    LOADER_DESCRIPTION = "The image loader reported the following when trying to load or edit " \
                         "the image. Please include this information when you report an error. " \
                         "If possible, please also provide the image that causes the issue."

    # Swapped in for a :general error.
    GENERAL_DESCRIPTION = "The following error occurred. If you think this is an issue with " \
                          "the program, please include this information when you report the error."

    # Upstream's `LpErrorDetails::new`: build, fill, present, return.
    def self.show(root, text, error_type)
      new(text, error_type).tap do |dialog|
        dialog.build
        dialog.present(root)
      end
    end

    def initialize(text, error_type)
      super()
      @text = text
      @error_type = error_type
      self.title = Util::Gettext.gettext("Error Details")
      self.content_width = 550
      self.content_height = 600
      add_css_class("error-details")
    end

    attr_reader :text, :error_type

    def build
      tap do
        self.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = page
          view.add_bottom_bar(report_button)

          page.tap do |prefs|
            prefs.add(description_group)
            prefs.add(message_group)

            message_group.tap do |group|
              group.header_suffix = copy_button
              group.add(message_scroller)

              message_scroller.tap { |scroller| scroller.child = message_view }
            end
          end
        end

        message_view.buffer.text = text

        copy_button.signal_connect("clicked") { copy_message }

        report_button.signal_connect("clicked") { report_issue }
      end
    end

    def copy_message
      message_view.buffer.then do |buffer|
        buffer.bounds.then do |start_iter, end_iter|
          display.clipboard.set_text(buffer.get_text(start_iter, end_iter, true))
        end
      end
    end

    def report_issue
      Gtk::UriLauncher.new(issue_uri).launch(root_window, nil) { |_launcher, _result| }
    end

    def issue_uri = ISSUE_URIS.fetch(error_type)

    def root_window
      root.then do |found|
        if found.is_a?(Gtk::Window)
          found
        else
          nil
        end
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def page = @page ||= Adwaita::PreferencesPage.new

    def description_group
      @description_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.description = Util::Gettext.gettext(description)
      end
    end

    def description
      if error_type == :general
        GENERAL_DESCRIPTION
      else
        LOADER_DESCRIPTION
      end
    end

    def message_group
      @message_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = Util::Gettext.gettext("Error Message")
      end
    end

    def copy_button
      @copy_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "edit-copy-symbolic"
        button.tooltip_text = Util::Gettext.gettext("Copy Error Message")
        button.add_css_class("flat")
      end
    end

    def message_scroller
      @message_scroller ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.vexpand = true
        scroller.overflow = :hidden
        scroller.add_css_class("card")
      end
    end

    def message_view
      @message_view ||= Gtk::TextView.new.tap do |view|
        view.editable = false
        view.wrap_mode = :word_char
        view.add_css_class("error-message")
        view.add_css_class("monospace")
      end
    end

    def report_button
      @report_button ||= Gtk::Button.new.tap do |button|
        button.halign = :center
        button.margin_bottom = 24
        button.add_css_class("suggested-action")
        button.add_css_class("pill")
        button.child = report_content
      end
    end

    def report_content
      @report_content ||= Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = "external-link-symbolic"
        content.label = Util::Gettext.gettext("Report _Issue")
        content.use_underline = true
      end
    end
  end
end
