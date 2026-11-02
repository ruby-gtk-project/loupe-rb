# frozen_string_literal: true

# Drives the ported foundation headlessly: the support modules on their own,
# then the widgets inside a real GTK application against a virtual display.
#
#   nix develop --command xvfb-run -a ruby test/drive_foundation.rb
#
# Every check is an assertion about behaviour the upstream source specifies,
# not about the port's internals: the filename ordering images are listed in,
# the escape handling in translated strings, the two error-details dialogs
# reached through the window's actions, the custom symbolic icons resolving by
# the names the .ui files ask for.

require "tmpdir"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "loupe"

FAILURES = []

def check(label)
  puts("OK   #{label} -> #{yield.inspect[0, 120]}")
rescue StandardError, GLib::Error => error
  FAILURES << label
  puts("FAIL #{label}: #{error.class}: #{error.message[0, 300]}")
end

def png(path)
  File.binwrite(path, "\x89PNG\r\n\x1a\n")
end

# --- Support modules ---------------------------------------------------------

check("config data dir ships") { Dir.exist?(Loupe::Config.data_dir) }
check("stylesheet ships") { File.exist?(Loupe::Style.stylesheet) }

check("gettext_f fills placeholders in order") do
  Loupe::Util::Gettext.gettext_f("{} of {}", [2, 7]) == "2 of 7"
end

check("unicode escapes are evaluated") do
  Loupe::Util::Gettext.apply_unicode_escapes('abc \u{03a6} \u{2764} d') == "abc \u{03a6} \u{2764} d"
end

check("a bad escape gives nil") do
  Loupe::Util::Gettext.apply_unicode_escapes('a \u{zzzz} b').nil?
end

check("hex_to_char") { Loupe::Util::Gettext.hex_to_char("03a6") == "Φ" }

check("ngettext picks the form and fills the count") do
  [
    Loupe::Util::Gettext.ngettext("{} image", "{} images", 1),
    Loupe::Util::Gettext.ngettext("{} image", "{} images", 3),
  ] == ["1 image", "3 images"]
end

check("filenames order numerically") do
  %w[img10.png img9.png img1.png].sort { |a, b| Loupe::Util.compare_by_name(a, b) } ==
    %w[img1.png img9.png img10.png]
end

check("contrast ratio of black on white is 21") do
  Loupe::Util.contrast_ratio(
    Gdk::RGBA.new(
      0.0,
      0.0,
      0.0,
      1.0,
    ),
    Gdk::RGBA.new(
      1.0,
      1.0,
      1.0,
      1.0,
    ),
  ).round(1) == 21.0
end

check("US measures in inches, DE does not") do
  %w[en_US.UTF-8 de_DE.UTF-8].map do |locale|
    ENV["LC_ALL"] = locale
    Loupe::Util.locale_uses_inch?
  end.tap { ENV.delete("LC_ALL") } == [true, false]
end

check("show-properties defaults false and round-trips") do
  Dir.mktmpdir do |dir|
    File.join(dir, "settings.json").then do |path|
      before = Loupe::Settings.new(path: path).show_properties?
      Loupe::Settings.new(path: path).show_properties = true
      [before, Loupe::Settings.new(path: path).show_properties?] == [false, true]
    end
  end
end

check("file model lists images only, sorted, and navigates") do
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
        ]
      end
  end
end

# --- Widgets -----------------------------------------------------------------

app = Gtk::Application.new("org.rubygtkproject.LoupeDriveFoundation", :default_flags)

app.signal_connect("activate") do
  Loupe::Style.load(Gdk::Display.default)

  check("custom symbolic icons resolve by name") do
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

  window = Loupe::Window.new(app).tap(&:build)
  window.present

  check("window starts wide and not fullscreened") do
    [window.layout_name, window.wide_layout?, window.narrow_layout?, window.not_fullscreened?]
  end

  check("stack shows the image page first, with no editor open") do
    [window.stack.visible_child == window.image_page, window.edit_window.nil?]
  end

  check("show_edit and show_image switch pages") do
    window.show_edit
    window.stack.visible_child.then do |after_edit|
      window.show_image
      [after_edit == window.edit_page, window.stack.visible_child == window.image_page]
    end
  end

  check("toast") do
    window.show_toast("hello", :normal)
    "shown"
  end

  check("show_error posts a toast carrying the details") do
    window.show_error("Could not load image", "the long version", :loader)
    "shown"
  end

  check("the two win. actions open the details dialogs") do
    window.activate_action("show-error", GLib::Variant.new("general details"))
    window.activate_action("show-loader-error", GLib::Variant.new("loader details"))
    "activated"
  end

  check("loader error details point at glycin") do
    Loupe::ErrorDetails.show(window, "loader blew up", :loader).then do |dialog|
      [dialog.issue_uri, dialog.message_view.buffer.text]
    end
  end

  check("general error details point at loupe") do
    Loupe::ErrorDetails.show(window, "general blew up", :general).then do |dialog|
      [dialog.issue_uri, dialog.description_group.description == Loupe::ErrorDetails::GENERAL_DESCRIPTION]
    end
  end

  check("shortcuts dialog has every section and item") do
    Loupe::ShortcutsDialog.new.build.tap { |dialog| dialog.present(window) }.then do
      [
        Loupe::ShortcutsDialog::SECTIONS.length,
        Loupe::ShortcutsDialog::SECTIONS.sum { |section| section[:items].length },
      ]
    end
  end

  check("about dialog carries the debug info") do
    Loupe::About.dialog.then do |about|
      [about.version, about.debug_info.lines.first.chomp, about.developers.length]
    end
  end

  check("drag overlay keeps its css name and starts hidden") do
    Loupe::DragOverlay.new(Gtk::DropTarget.new(Gio::File.gtype, :copy))
      .tap(&:build)
      .tap { |overlay| overlay.content = Gtk::Label.new("content") }
      .then { |overlay| [overlay.css_name, overlay.revealer.reveal_child?, !overlay.content.nil?] }
  end

  check("a child widget reaches the window through Util::Root") do
    Gtk::Label.new("x").tap { |label| window.image_page.child = label }.then do |label|
      [label.try_loupe_window == window, label.loupe_window == window]
    end
  end

  check("a child widget can toast through the window") do
    window.image_page.child.window_show_toast("from a child", :high)
    "shown"
  end

  check("opened files become a file model") do
    Dir.mktmpdir do |dir|
      %w[b2.png a1.png c10.png].each { |name| png(File.join(dir, name)) }
      window.load_files([Gio::File.new_for_path(File.join(dir, "a1.png"))])
      [window.file_model.n_files, File.basename(window.file_model.first.path)]
    end
  end

  GLib::Timeout.add(200) do
    app.quit
    false
  end
end

app.run([])

puts("\n#{FAILURES.empty? ? "ALL PASS" : "FAILURES: #{FAILURES.join(", ")}"}")
exit(FAILURES.empty? ? 0 : 1)
