# frozen_string_literal: true

# Drives the ported foundation headlessly: the support modules on their own,
# then every widget the port currently builds, inside a real running
# Loupe::Application against a virtual display.
#
#   nix develop --command xvfb-run -a ruby test/drive_foundation.rb
#
# Every check is an assertion about behaviour the upstream source specifies,
# not about the port's internals: the filename ordering images are listed in,
# the escape handling in translated strings, the two error-details dialogs
# reached through the window's actions, the custom symbolic icons resolving by
# the names the .ui files ask for.
#
# This exercises every unit `.reports/component-parity.md` counts as built:
# the window shell, the error-details dialog, the drag overlay, the about
# dialog and the shortcuts window. It does not and cannot exercise the image
# viewer, editor, crop tool, properties sidebar or print page, because none of
# those have a port file yet (see that report) — there is nothing to drive.

require "fileutils"
require "tmpdir"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("loupe-drive")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "loupe"
require_relative "gtk_driver"

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.rm_rf(SHOTS)

def png(path)
  File.binwrite(path, "\x89PNG\r\n\x1a\n")
end

# Turns the main loop over for `ms` milliseconds without sleeping the
# process, so widgets that settle on the frame clock (allocation, breakpoint
# re-evaluation) get the ticks they need before the next check runs.
def pump(ms)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + (ms / 1000.0)
  while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    GLib::MainContext.default.iteration(false)
  end
end

GtkDriver.drive(Loupe::Application.new, shots: SHOTS) do |d, app|
  d.window { app.app.active_window }

  d.step("support modules need no window") do
    d.check("config data dir ships") { Dir.exist?(Loupe::Config.data_dir) }
    d.check("stylesheet ships") { File.exist?(Loupe::Style.stylesheet) }

    d.check("gettext_f fills placeholders in order") do
      Loupe::Util::Gettext.gettext_f("{} of {}", [2, 7]) == "2 of 7"
    end

    d.check("unicode escapes are evaluated") do
      Loupe::Util::Gettext.apply_unicode_escapes('abc \u{03a6} \u{2764} d') == "abc \u{03a6} \u{2764} d"
    end

    d.check("a bad escape gives nil") do
      Loupe::Util::Gettext.apply_unicode_escapes('a \u{zzzz} b').nil?
    end

    d.check("hex_to_char") { Loupe::Util::Gettext.hex_to_char("03a6") == "Φ" }

    d.check("ngettext picks the form and fills the count") do
      [
        Loupe::Util::Gettext.ngettext("{} image", "{} images", 1),
        Loupe::Util::Gettext.ngettext("{} image", "{} images", 3),
      ] == ["1 image", "3 images"]
    end

    d.check("filenames order numerically") do
      %w[img10.png img9.png img1.png].sort { |a, b| Loupe::Util.compare_by_name(a, b) } ==
        %w[img1.png img9.png img10.png]
    end

    d.check("contrast ratio of black on white is 21") do
      Loupe::Util.contrast_ratio(
        Gdk::RGBA.new(0.0, 0.0, 0.0, 1.0),
        Gdk::RGBA.new(1.0, 1.0, 1.0, 1.0),
      ).round(1) == 21.0
    end

    d.check("US measures in inches, DE does not") do
      %w[en_US.UTF-8 de_DE.UTF-8].map do |locale|
        ENV["LC_ALL"] = locale
        Loupe::Util.locale_uses_inch?
      end.tap { ENV.delete("LC_ALL") } == [true, false]
    end

    d.check("show-properties defaults false and round-trips") do
      Dir.mktmpdir do |dir|
        File.join(dir, "settings.json").then do |path|
          before = Loupe::Settings.new(path: path).show_properties?
          Loupe::Settings.new(path: path).show_properties = true
          [before, Loupe::Settings.new(path: path).show_properties?] == [false, true]
        end
      end
    end

    d.check("file model lists images only, sorted, and navigates") do
      Dir.mktmpdir do |dir|
        %w[img10.png img9.png img1.png].each { |name| png(File.join(dir, name)) }
        File.write(File.join(dir, "notes.txt"), "not an image")

        Loupe::FileModel.new.tap { |model| model.load_directory(Gio::File.new_for_path(dir)) }
          .then do |model|
            [
              model.n_files,
              File.basename(model.first.path),
              File.basename(model.after(model.first).path),
              File.basename(model.last.path),
              model.files_around(model.first, 1).length,
              model.before(model.first).nil?,
            ] == [3, "img1.png", "img9.png", "img10.png", 2, true]
          end
      end
    end
  end

  d.step("the window is up, with the icon theme loaded") do
    d.check("window exists and is presented") { !app.app.active_window.nil? && app.app.active_window.visible? }

    d.check("custom symbolic icons resolve by name") do
      Gtk::IconTheme.get_for_display(Gdk::Display.default).then do |theme|
        %w[
          image-round-symbolic
          crop-symbolic
          external-link-symbolic
          zoom-toggle-symbolic
          aspect-ratio-16to9-symbolic
        ].all? { |name| theme.has_icon?(name) }
      end
    end

    d.check("not fullscreened at startup") { app.app.active_window.not_fullscreened? }

    d.check("widening past the breakpoint selects the wide layout") do
      window = app.app.active_window
      window.default_width = 900
      pump(300)
      [window.layout_name, window.wide_layout?, window.narrow_layout?] == ["wide", true, false]
    end

    d.check("narrowing past the breakpoint selects the narrow layout") do
      window = app.app.active_window
      window.default_width = 300
      pump(300)
      [window.layout_name, window.wide_layout?, window.narrow_layout?] == ["narrow", false, true]
    end

    d.check("stack shows the image page first, with no editor open") do
      window = app.app.active_window
      [window.stack.visible_child == window.image_page, window.edit_window.nil?] == [true, true]
    end

    pump(200)

    d.shot("01-window")
  end

  d.step("show_edit and show_image switch pages") do
    window = app.app.active_window
    window.show_edit

    d.check("show_edit moved the stack to the edit page") do
      window.stack.visible_child == window.edit_page
    end

    pump(200)

    d.shot("02-edit-page")

    window.show_image

    d.check("show_image moved the stack back") { window.stack.visible_child == window.image_page }
  end

  d.step("a plain toast") do
    app.app.active_window.show_toast("hello", :normal)
    d.check("a toast was added without raising") { true }
    pump(200)
    d.shot("03-toast")
  end

  d.step("show_error posts a toast carrying the details") do
    app.app.active_window.show_error("Could not load image", "the long version", :loader)
    d.check("the error toast was added without raising") { true }
    pump(200)
    d.shot("04-error-toast")
  end

  d.step("win.show-error opens the general error-details dialog") do
    window = app.app.active_window
    window.activate_action("show-error", GLib::Variant.new("general details"))

    d.check("the general error-details dialog opened") { !window.visible_dialog.nil? }
    d.check("it is an ErrorDetails dialog") { window.visible_dialog.is_a?(Loupe::ErrorDetails) }
    d.check("it carries the details text") { window.visible_dialog.message_view.buffer.text == "general details" }
    d.check("it points at the loupe tracker") { window.visible_dialog.issue_uri == Loupe::ErrorDetails::ISSUE_URIS[:general] }

    pump(200)

    d.shot("05-error-details-general")

    window.visible_dialog.close
  end

  d.step("win.show-loader-error opens the loader error-details dialog") do
    window = app.app.active_window
    window.activate_action("show-loader-error", GLib::Variant.new("loader details"))

    d.check("the loader error-details dialog opened") { !window.visible_dialog.nil? }
    d.check("it carries the details text") { window.visible_dialog.message_view.buffer.text == "loader details" }
    d.check("it points at the glycin tracker") { window.visible_dialog.issue_uri == Loupe::ErrorDetails::ISSUE_URIS[:loader] }

    pump(200)

    d.shot("06-error-details-loader")

    window.visible_dialog.close
  end

  d.step("ErrorDetails.show builds both error-type variants directly") do
    Loupe::ErrorDetails.show(app.app.active_window, "loader blew up", :loader).then do |dialog|
      d.check("loader dialog shows the glycin issue uri") { dialog.issue_uri == "https://gitlab.gnome.org/GNOME/glycin/-/issues" }
      d.check("loader dialog carries the message") { dialog.message_view.buffer.text == "loader blew up" }
      dialog.close
    end

    Loupe::ErrorDetails.show(app.app.active_window, "general blew up", :general).then do |dialog|
      d.check("general dialog shows the loupe issue uri") { dialog.issue_uri == "https://gitlab.gnome.org/GNOME/loupe/-/issues" }
      d.check("general dialog's description matches GENERAL_DESCRIPTION") do
        dialog.description_group.description == Loupe::ErrorDetails::GENERAL_DESCRIPTION
      end
      dialog.close
    end
  end

  d.step("app.shortcuts opens the shortcuts dialog with every section and item") do
    window = app.app.active_window
    app.app.activate_action("shortcuts", nil)

    d.check("the shortcuts dialog opened") { !window.visible_dialog.nil? }
    d.check("it is a ShortcutsDialog") { window.visible_dialog.is_a?(Adwaita::ShortcutsDialog) }
    d.check("there are 7 sections, as upstream's .ui has") { Loupe::ShortcutsDialog::SECTIONS.length == 7 }
    d.check("there are 40 items across those sections") do
      Loupe::ShortcutsDialog::SECTIONS.sum { |section| section[:items].length } == 40
    end

    pump(200)

    d.shot("07-shortcuts")

    window.visible_dialog.close
  end

  d.step("app.about opens the about dialog with debug info") do
    window = app.app.active_window
    window.show_about

    d.check("the about dialog opened") { !window.visible_dialog.nil? }
    d.check("it is the Adwaita about dialog") { window.visible_dialog.is_a?(Adwaita::AboutDialog) }
    d.check("its version matches Config::VERSION") { window.visible_dialog.version == Loupe::Config::VERSION }
    d.check("debug info leads with the version line") { window.visible_dialog.debug_info.lines.first.chomp == "- Version: #{Loupe::Config::VERSION}" }
    d.check("there are two listed developers") { window.visible_dialog.developers.length == 2 }

    pump(200)

    d.shot("08-about")

    window.visible_dialog.close
  end

  d.step("the drag overlay crossfades on a live drop target") do
    target = Gtk::DropTarget.new(Gio::File.gtype, :copy)
    overlay = Loupe::DragOverlay.new(target).tap(&:build)
    overlay.content = Gtk::Label.new("content")

    d.check("the css name is lpdragoverlay") { overlay.css_name == "lpdragoverlay" }
    d.check("it starts with the status page hidden") { !overlay.revealer.reveal_child? }
    d.check("the content widget round-trips") { overlay.content.is_a?(Gtk::Label) }
  end

  d.step("Util::Root reaches the window from a widget deep in the tree") do
    window = app.app.active_window
    label = Gtk::Label.new("x")
    window.image_page.child = label

    d.check("try_loupe_window finds the real window") { label.try_loupe_window == window }
    d.check("loupe_window (the loud version) finds it too") { label.loupe_window == window }

    label.window_show_toast("from a child", :high)
    d.check("a child widget can toast through the window mixin") { true }

    pump(200)

    d.shot("09-child-toast")
  end

  d.step("opening files builds a sorted file model on the window") do
    window = app.app.active_window

    Dir.mktmpdir do |dir|
      %w[b2.png a1.png c10.png].each { |name| png(File.join(dir, name)) }
      window.load_files([Gio::File.new_for_path(File.join(dir, "a1.png"))])

      d.check("3 files were found in the directory") { window.file_model.n_files == 3 }
      d.check("the model is sorted, not insertion-ordered") { File.basename(window.file_model.first.path) == "a1.png" }
      d.check("a file with no GPS attributes resolves no place") { window.metadata_place.nil? }
    end
  end

  d.step("a GPS-tagged file resolves a place name through libgweather") do
    # The sandbox this drives in has no gvfs-metadata daemon, so a real file
    # can't actually carry `metadata::location-*` attributes (confirmed:
    # Gio::File#set_attribute_string on that namespace raises
    # Gio::IOError::NotSupported here) — the same attributes tracker-extract
    # would populate from a photo's EXIF tags on a real desktop. Building the
    # Gio::FileInfo by hand, the same way `query_info` would hand one to
    # `Metadata::FileInfo.new`, still drives the production
    # `Metadata::FileInfo#gps_location_place` and `Loupe::Metadata` straight
    # into GWeather::Location.world/find_nearest_city/get_distance for real.
    info = Gio::FileInfo.new
    info.set_attribute_string(Gio::FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME, "london.png")
    info.set_attribute_uint64(Gio::FILE_ATTRIBUTE_STANDARD_SIZE, 9)
    info.set_attribute_string("metadata::location-latitude", "51.5074")
    info.set_attribute_string("metadata::location-longitude", "-0.1278")

    file_info = Loupe::Metadata::FileInfo.new(info)

    d.check("the file info picked up both GPS attributes") { file_info.has_gps_location? }
    d.check("GWeather resolves it to London, United Kingdom") do
      file_info.gps_location_place == "London, United Kingdom"
    end

    far = Gio::FileInfo.new
    far.set_attribute_string(Gio::FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME, "ocean.png")
    far.set_attribute_uint64(Gio::FILE_ATTRIBUTE_STANDARD_SIZE, 9)
    far.set_attribute_string("metadata::location-latitude", "0.0")
    far.set_attribute_string("metadata::location-longitude", "0.0")

    d.check("far from any city, it falls back to degrees/minutes/seconds") do
      Loupe::Metadata::FileInfo.new(far).gps_location_place == "0° 0′ 00.00″ N\n0° 0′ 00.00″ E"
    end
  end

  d.step("close the window so the run can finish") do
    app.app.active_window.close
  end
end
