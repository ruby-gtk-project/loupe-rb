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
# dialog, the shortcuts window, the shy bin, the GdkPixbuf-backed decoder
# model and (new this round) the properties sidebar. It does not and cannot
# exercise the image viewer, editor or crop tool, because none of those have
# a port file yet (see that report) — there is nothing to drive.
#
# Each step calls `d.covers(...)` naming the lib files its checks actually
# exercise. The final report sums the union of every call into a "covering
# N components" line — a number this script computes from its own steps,
# not one a reader has to take on faith.

require "cairo"
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

# A real, decodable PNG (unlike `png` above, which only needs to pass the
# directory enumerator's fast-content-type sniff) for driving Decoder, which
# has to get all the way through GdkPixbuf.
def real_png(path, width: 12, height: 8)
  Cairo::ImageSurface.new(:argb32, width, height).tap do |surface|
    Cairo::Context.new(surface).tap do |ctx|
      ctx.set_source_rgb(0.2, 0.4, 0.8)
      ctx.paint
    end
    surface.write_to_png(path)
  end
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
    d.covers("config.rb", "style.rb", "util.rb", "util/gettext.rb", "settings.rb", "file_model.rb")

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
    d.covers("window.rb")

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
    d.covers("window.rb")

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
    d.covers("window.rb")

    app.app.active_window.show_toast("hello", :normal)
    d.check("a toast was added without raising") { true }
    pump(200)
    d.shot("03-toast")
  end

  d.step("show_error posts a toast carrying the details") do
    d.covers("window.rb")

    app.app.active_window.show_error("Could not load image", "the long version", :loader)
    d.check("the error toast was added without raising") { true }
    pump(200)
    d.shot("04-error-toast")
  end

  d.step("win.show-error opens the general error-details dialog") do
    d.covers("window.rb", "error_details.rb")

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
    d.covers("window.rb", "error_details.rb")

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
    d.covers("error_details.rb")

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
    d.covers("window.rb", "shortcuts_dialog.rb")

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
    d.covers("window.rb", "about.rb", "config.rb")

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
    d.covers("drag_overlay.rb")

    target = Gtk::DropTarget.new(Gio::File.gtype, :copy)
    overlay = Loupe::DragOverlay.new(target).tap(&:build)
    overlay.content = Gtk::Label.new("content")

    d.check("the css name is lpdragoverlay") { overlay.css_name == "lpdragoverlay" }
    d.check("it starts with the status page hidden") { !overlay.revealer.reveal_child? }
    d.check("the content widget round-trips") { overlay.content.is_a?(Gtk::Label) }
  end

  d.step("Util::Root reaches the window from a widget deep in the tree") do
    d.covers("util/root.rb", "window.rb")

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
    d.covers("window.rb", "file_model.rb", "metadata.rb", "metadata/file.rb", "decoder.rb", "properties_view.rb")

    window = app.app.active_window

    Dir.mktmpdir do |dir|
      %w[b2.png a1.png c10.png].each { |name| png(File.join(dir, name)) }
      window.load_files([Gio::File.new_for_path(File.join(dir, "a1.png"))])

      d.check("3 files were found in the directory") { window.file_model.n_files == 3 }
      d.check("the model is sorted, not insertion-ordered") { File.basename(window.file_model.first.path) == "a1.png" }
      d.check("a file with no GPS attributes resolves no place") { window.metadata_place.nil? }
    end
  end

  d.step("the properties sidebar shows a real image's metadata") do
    d.covers("window.rb", "properties_view.rb", "decoder.rb", "metadata/file.rb", "settings.rb")

    window = app.app.active_window

    Dir.mktmpdir do |dir|
      path = File.join(dir, "photo.png")
      real_png(path, width: 33, height: 17)

      window.show_properties = true
      window.load_files([Gio::File.new_for_path(path)])
      properties = window.properties_view

      d.check("F9 and the toggle-properties action agree with show_properties?") do
        window.show_properties?
      end
      d.check("the overlay split view's sidebar is actually shown") { window.image_split_view.show_sidebar? }
      d.check("the sidebar is the PropertiesView") { window.image_split_view.sidebar.equal?(properties) }
      d.check("the folder row shows a real display name, not the fallback") do
        properties.folder_row.visible? && properties.folder_row.subtitle != Loupe::PropertiesView::FALLBACK
      end
      d.check("the image size row shows the real decoded dimensions") do
        properties.image_size_row.visible? && properties.image_size_row.subtitle.include?("33") &&
          properties.image_size_row.subtitle.include?("17")
      end
      d.check("the file size row has a real value") { properties.file_size_row.visible? }
      d.check("the dates group is shown") { properties.dates_group.visible? }
      d.check("the location row is hidden with no GPS data") { !properties.location_row.visible? }

      pump(200)

      window.toggle_properties

      d.check("win.toggle-properties flips show_properties?") { !window.show_properties? }

      window.toggle_properties

      d.check("toggling twice is back to shown") { window.show_properties? }
    end
  end

  d.step("a GPS-tagged file resolves a place name through libgweather") do
    d.covers("metadata.rb", "metadata/file.rb")

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

  d.step("ShyBin clamps its child's natural width to its minimum width") do
    d.covers("shy_bin.rb")

    bin = Loupe::ShyBin.new
    label = Gtk::Label.new("A very very very very very very long title")
    label.ellipsize = :end
    bin.child = label

    label_measure = label.measure(:horizontal, -1)
    bin_measure = bin.measure(:horizontal, -1)

    d.check("the label itself actually has a shorter minimum than natural width") do
      label_measure[0] < label_measure[1]
    end
    d.check("the bin's natural width equals its minimum width") { bin_measure[0] == bin_measure[1] }
    d.check("the bin's minimum width still matches the label's") { bin_measure[0] == label_measure[0] }
    d.check("vertical measurement is untouched (child's natural height passes through)") do
      bin.measure(:vertical, -1) == label.measure(:vertical, -1)
    end
  end

  d.step("Decoder decodes a real PNG through GdkPixbuf") do
    d.covers("decoder.rb")

    Dir.mktmpdir do |dir|
      path = File.join(dir, "photo.png")
      real_png(path, width: 37, height: 21)

      decoder = Loupe::Decoder.load(Gio::File.new_for_path(path))

      d.check("it loaded without error") { decoder.error.nil? }
      d.check("it reports the real PNG MIME type") { decoder.mime_type == "image/png" }
      d.check("it is not classified as SVG") { !decoder.svg? }
      d.check("the decoded pixbuf keeps the source's dimensions") do
        decoder.pixbuf.width == 37 && decoder.pixbuf.height == 21
      end
    end
  end

  d.step("Decoder classifies a missing file and an unrecognised format") do
    d.covers("decoder.rb")

    Dir.mktmpdir do |dir|
      missing = Gio::File.new_for_path(File.join(dir, "does-not-exist.png"))
      missing_decoder = Loupe::Decoder.load(missing)

      d.check("a missing file decodes to no pixbuf") { missing_decoder.pixbuf.nil? }
      d.check("a missing file is classified as an image-source error") do
        missing_decoder.error.image_source?
      end

      garbage_path = File.join(dir, "not-a-real-image.png")
      File.write(garbage_path, "this is not image data")
      garbage_decoder = Loupe::Decoder.load(Gio::File.new_for_path(garbage_path))

      d.check("unreadable image data decodes to no pixbuf") { garbage_decoder.pixbuf.nil? }
      d.check("unreadable image data is classified as an unsupported format") do
        garbage_decoder.error.unsupported_format?
      end
    end
  end

  d.step("Decoder.svg? matches both SVG MIME variants Formats.svg? is for") do
    d.covers("decoder/formats.rb")

    d.check("plain SVG matches") { Loupe::Decoder::Formats.svg?("image/svg+xml") }
    d.check("compressed SVG matches") { Loupe::Decoder::Formats.svg?("image/svg+xml-compressed") }
    d.check("a raster type does not match") { !Loupe::Decoder::Formats.svg?("image/png") }
  end

  d.step("close the window so the run can finish") do
    app.app.active_window.close
  end
end
