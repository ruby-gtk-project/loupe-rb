# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "about"
require_relative "config"
require_relative "error_details"
require_relative "file_model"
require_relative "util"
require_relative "util/gettext"

module Loupe
  # Ported from src/widgets/window.rs and src/widgets/window.ui.
  #
  # The outer window: a toast overlay wrapping a view stack whose two pages
  # are the viewer and the editor. Everything a widget deep in the tree needs
  # to reach the user goes through here — toasts, the two error-details
  # actions, the about dialog, and the fullscreen state — which is why
  # Util::Root looks this class up by walking to a widget's root.
  #
  # The layout state upstream keeps as four GObject properties on the window
  # (narrow-layout, wide-layout, layout-name, not-fullscreened) is kept as
  # plain Ruby state here, because the only reason upstream makes them
  # properties is so window.ui can bind and set them: the two breakpoints set
  # layout-name and narrow-layout, and wide-layout and not-fullscreened are
  # inverted bindings of narrow-layout and fullscreened. The breakpoints drive
  # the same state through their apply and unapply signals instead, and the
  # two inverted properties are derived on read.
  #
  # The stack's two pages are the AdwBin pair window.ui declares. Upstream
  # puts LpImageWindow in the first and fills the second with an LpEditWindow
  # when the editor opens; `image_page` and `edit_page` hand those bins out,
  # and `show_image` and `show_edit` switch between them.
  class Window < Adwaita::ApplicationWindow
    type_register

    # Show the window after this many milliseconds even if the image
    # dimensions are not known yet.
    SHOW_WINDOW_AFTER = 2000

    # The breakpoint boundary, in scalable pixels. Upstream's two conditions
    # are min-width and max-width at the same figure, and window.rs's
    # resize_default converts the same number to pixels.
    LAYOUT_BREAKPOINT_SP = 590

    # Upstream's two win. actions, each taking the error text as a string
    # parameter so the toast's button can carry it.
    WINDOW_ACTIONS = {
      "show-error"        => :general,
      "show-loader-error" => :loader,
    }.freeze

    def initialize(application)
      super()
      self.application = application
      @narrow_layout = false
      @layout_name = "wide"
      @file_model = FileModel.new
      set_default_size(600, 498)
      self.width_request = 360
      self.height_request = 294

      if Config.devel?
        add_css_class("devel")
      end
    end

    attr_reader :layout_name, :file_model

    def narrow_layout? = @narrow_layout

    # Upstream's wide-layout property: narrow-layout, inverted.
    def wide_layout? = !@narrow_layout

    # Upstream's not-fullscreened property: fullscreened, inverted.
    def not_fullscreened? = !fullscreened?

    def build
      tap do
        self.content = toast_overlay

        toast_overlay.tap do |overlay|
          overlay.child = stack

          stack.tap do |view_stack|
            view_stack.add(image_page)
            view_stack.add(edit_page)
          end
        end

        add_breakpoint(wide_breakpoint)
        add_breakpoint(narrow_breakpoint)

        add_controller(shortcut_controller)

        install_window_actions

        # Limit the effect of modal dialogs to this window and keep the
        # others usable.
        Gtk::WindowGroup.new.add_window(self)

        signal_connect("close-request") { close_request }

        GLib::Timeout.add(SHOW_WINDOW_AFTER) do
          unless visible?
            present
          end
          false
        end
      end
    end

    # Upstream hands the close request back to the editor so unsaved changes
    # can be confirmed, and destroys the window once that resolves. With no
    # editor open it destroys straight away, which is the path taken until the
    # edit_window port lands.
    def close_request
      destroy
      true
    end

    def toggle_fullscreen(fullscreen)
      self.fullscreened = fullscreen
    end

    # Take over the files the application was opened with.
    #
    # Upstream hands them to the image view, which builds an LpFileModel from
    # them and loads the containing directory so the viewer can page on to the
    # neighbouring images. That model is built here; the view that pages
    # through it comes with the image_view port. A directory that cannot be
    # listed is reported the same way every other failure is, as a toast with
    # the details behind it.
    def load_files(files)
      @file_model = FileModel.from_files(files)

      files.first&.parent.then do |directory|
        unless directory.nil?
          load_directory(directory)
        end
      end

      @file_model
    end

    # The LpEditWindow upstream puts into the second stack page, or nil while
    # the editor is closed.
    def edit_window = edit_page.child

    def add_toast(toast)
      toast_overlay.add_toast(toast)
    end

    def show_toast(text, priority)
      add_toast(Adwaita::Toast.new(text).tap { |toast| toast.priority = priority })
    end

    # A short failure message as a high-priority toast, with a button that
    # opens the full text in an ErrorDetails dialog. The details travel as the
    # action's target so the toast does not have to hold the dialog.
    def show_error(stub, details, error_type)
      Adwaita::Toast.new(stub).tap do |toast|
        toast.priority = :high
        toast.button_label = Util::Gettext.gettext("Show Details")
        toast.action_name = "win.#{action_name_for(error_type)}"
        toast.action_target = GLib::Variant.new(details)
        add_toast(toast)
      end
    end

    def show_error_details(details)
      ErrorDetails.show(self, details, :general)
    end

    def show_loader_error_details(details)
      ErrorDetails.show(self, details, :loader)
    end

    def show_about
      About.dialog.present(self)
    end

    def show_image
      stack.visible_child = image_page
    end

    def show_edit
      stack.visible_child = edit_page
      self.fullscreened = false
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    def stack
      @stack ||= Adwaita::ViewStack.new.tap do |view_stack|
        view_stack.enable_transitions = true
      end
    end

    def image_page = @image_page ||= Adwaita::Bin.new
    def edit_page = @edit_page ||= Adwaita::Bin.new

    # Only the shortcut is added here: the app.shortcuts action itself is
    # registered by the application, as upstream relies on libadwaita doing.
    def shortcut_controller
      @shortcut_controller ||= Gtk::ShortcutController.new.tap do |controller|
        controller.add_shortcut(shortcuts_dialog_shortcut)
      end
    end

    def shortcuts_dialog_shortcut
      Gtk::Shortcut.new(
        Gtk::KeyvalTrigger.new(Gdk::Keyval::KEY_question, Gdk::ModifierType::CONTROL_MASK),
        Gtk::NamedAction.new("app.shortcuts"),
      )
    end

    def wide_breakpoint
      @wide_breakpoint ||= breakpoint("min-width: #{LAYOUT_BREAKPOINT_SP}sp", "wide", false)
    end

    def narrow_breakpoint
      @narrow_breakpoint ||= breakpoint("max-width: #{LAYOUT_BREAKPOINT_SP}sp", "narrow", true)
    end

    private

      def load_directory(directory)
        @file_model.load_directory(directory)
      rescue Util::Error => error
        show_error(
          Util::Gettext.gettext("Could not list other files in directory."),
          error.message,
          :general,
        )
      end

      def breakpoint(condition, name, narrow)
        Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse(condition)).tap do |point|
          point.signal_connect("apply") { apply_layout(name, narrow) }
        end
      end

      def apply_layout(name, narrow)
        @layout_name = name
        @narrow_layout = narrow
      end

      def install_window_actions
        WINDOW_ACTIONS.each_key do |name|
          add_action(error_details_action(name))
        end
      end

      def error_details_action(name)
        Gio::SimpleAction.new(name, GLib::VariantType.new("s")).tap do |action|
          action.signal_connect("activate") do |_action, parameter|
            show_details(WINDOW_ACTIONS.fetch(name), variant_string(parameter))
          end
        end
      end

      # The action's string parameter reaches the handler already unwrapped by
      # the bindings; a GLib::Variant still has to be unwrapped by hand.
      def variant_string(parameter)
        if parameter.is_a?(GLib::Variant)
          parameter.value
        else
          parameter.to_s
        end
      end

      def show_details(error_type, details)
        if error_type == :loader
          show_loader_error_details(details)
        else
          show_error_details(details)
        end
      end

      def action_name_for(error_type)
        WINDOW_ACTIONS.key(error_type) || WINDOW_ACTIONS.key(:general)
      end
  end
end
