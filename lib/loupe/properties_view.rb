# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "metadata/file"
require_relative "util"
require_relative "util/gettext"
require_relative "util/root"

module Loupe
  # Ported from src/widgets/properties_view.rs and
  # src/widgets/properties_view.ui.
  #
  # Upstream reads an `LpImage` for everything this view shows: the file,
  # its decoded pixel size, and a `Metadata` struct built from gufo's EXIF
  # parser and glycin's frame details. This port has neither `LpImage`
  # (the GL-rendered image surface, not yet ported) nor a Ruby binding for
  # gufo or glycin's metadata API, so `set_target` is handed the pieces
  # this port actually has instead: the `Gio::File`, a
  # `Metadata::FileInfo` (file.rb's GIO-attribute query, already carrying
  # the GPS "City, Country" lookup through `libgweather`), and the
  # `GdkPixbuf::Pixbuf` the decoder already produced for on-screen size.
  #
  # That leaves out every EXIF/XMP/ICC row upstream's template has
  # (aperture, exposure, ISO, lens, maker/model, rights, ICC profile,
  # CICP, physical size, pixel density): there is no data source for any
  # of them yet, so rather than show a row that can never have a value
  # this port drops the row itself. Folder, URI, image size, file size,
  # the two file timestamps and GPS location — everything the file-system
  # query in file.rb can actually answer — are ported in full, including
  # the copy-coordinates and open-location actions.
  class PropertiesView < Adwaita::Bin
    FALLBACK = "–"

    def initialize
      super()
      @file = nil
      @metadata = nil
      @pixbuf = nil
    end

    attr_reader :file, :metadata, :pixbuf

    def build
      tap do
        self.child = scroller

        scroller.tap do |window|
          window.child = box

          box.tap do |column|
            column.append(file_group)
            column.append(image_group)
            column.append(dates_group)
            column.append(details_group)

            file_group.tap do |group|
              group.add(folder_row)
              group.add(uri_row)
            end

            image_group.tap do |group|
              group.add(image_size_row)
              group.add(file_size_row)
            end

            dates_group.tap do |group|
              group.add(file_created_row)
              group.add(file_modified_row)
            end

            details_group.tap { |group| group.add(location_row) }
          end
        end

        folder_button.signal_connect("clicked") { open_folder }
        copy_location_button.signal_connect("clicked") { copy_location }
        open_location_button.signal_connect("clicked") { open_location }
      end
    end

    # Upstream's `image` property setter. +pixbuf+ is the decoded image
    # (see the class comment for why this port takes it directly rather
    # than reading it off an LpImage) and may be nil before decoding
    # finishes or when decoding failed.
    def set_target(file, metadata, pixbuf = nil)
      @file = file
      @metadata = metadata
      @pixbuf = pixbuf
      update
      self
    end

    # Upstream's `update`.
    def update
      has_folder = update_folder
      update_row(uri_row, has_folder ? nil : file&.uri)
      update_row(image_size_row, image_size)
      update_row(file_size_row, file_size)

      has_dates = [
        update_row(file_created_row, Util.datetime_fmt(metadata&.created)),
        update_row(file_modified_row, Util.datetime_fmt(metadata&.modified)),
      ].any?
      dates_group.visible = has_dates

      has_details = update_row(location_row, metadata&.gps_location_place)
      details_group.visible = has_details
    end

    # Memoized widget methods

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
        window.propagate_natural_height = true
        window.max_content_height = 316
      end
    end

    def box
      @box ||= Gtk::Box.new(:vertical, 24).tap do |column|
        column.margin_top = 24
        column.margin_bottom = 24
        column.margin_start = 12
        column.margin_end = 12
      end
    end

    def file_group = @file_group ||= Adwaita::PreferencesGroup.new
    def image_group = @image_group ||= Adwaita::PreferencesGroup.new
    def dates_group = @dates_group ||= Adwaita::PreferencesGroup.new
    def details_group = @details_group ||= Adwaita::PreferencesGroup.new

    def folder_row
      @folder_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = Util::Gettext.gettext("Folder")
        row.activatable_widget = folder_button
        row.use_markup = false
        row.add_suffix(folder_button)
        row.add_css_class("property")
      end
    end

    def folder_button
      @folder_button ||= Gtk::Button.new.tap do |button|
        button.valign = :center
        button.icon_name = "folder-open-symbolic"
        button.tooltip_text = Util::Gettext.gettext("Open Containing Folder")
        button.add_css_class("flat")
      end
    end

    def uri_row
      @uri_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = Util::Gettext.gettext("URI")
        row.subtitle_selectable = true
        row.subtitle_lines = 1
        row.use_markup = false
        row.add_css_class("property")
      end
    end

    def image_size_row
      @image_size_row ||= property_row(Util::Gettext.gettext("Image Size"))
    end

    def file_size_row
      @file_size_row ||= property_row(Util::Gettext.gettext("File Size"))
    end

    def file_created_row
      @file_created_row ||= property_row(Util::Gettext.gettext("File Created"))
    end

    def file_modified_row
      @file_modified_row ||= property_row(Util::Gettext.gettext("File Modified"))
    end

    def location_row
      @location_row ||= Adwaita::ActionRow.new.tap do |row|
        # Translators: This is a label for GPS coordinates
        row.title = Util::Gettext.gettext("Location")
        row.subtitle_selectable = true
        row.use_markup = false
        row.add_suffix(copy_location_button)
        row.add_suffix(open_location_button)
        row.add_css_class("numeric")
        row.add_css_class("property")
      end
    end

    def copy_location_button
      @copy_location_button ||= Gtk::Button.new.tap do |button|
        button.valign = :center
        button.icon_name = "edit-copy-symbolic"
        button.tooltip_text = Util::Gettext.gettext("Copy Coordinates")
        button.add_css_class("flat")
      end
    end

    def open_location_button
      @open_location_button ||= Gtk::Button.new.tap do |button|
        button.valign = :center
        button.icon_name = "mark-location-symbolic"
        button.tooltip_text = Util::Gettext.gettext("Open Location")
        button.add_css_class("flat")
      end
    end

    private

      def property_row(title)
        Adwaita::ActionRow.new.tap do |row|
          row.title = title
          row.subtitle_selectable = true
          row.use_markup = false
          row.add_css_class("property")
        end
      end

      # Upstream's `update_row`: sets the subtitle and returns whether the
      # row has a real value to show, hiding it when it does not (with the
      # fallback dash as the subtitle, same as upstream).
      def update_row(row, value)
        if value.nil? || value.to_s.empty?
          row.subtitle = FALLBACK
          row.visible = false
          false
        else
          row.subtitle = value.to_s
          row.visible = true
          true
        end
      end

      # Upstream's folder lookup: the parent of the metadata's host path
      # (the flatpak-portal path, when sandboxed) or the file's own path,
      # shown as a display name rather than a raw path.
      def update_folder
        parent_path = parent_directory(metadata&.host_path || file&.path)
        name = parent_path.nil? ? nil : Util.file_display_name(Gio::File.new_for_path(parent_path))
        has_folder = update_row(folder_row, name)
        folder_button.sensitive = !file&.path.nil?
        has_folder
      end

      def parent_directory(path)
        if path.nil?
          nil
        else
          File.dirname(path)
        end
      end

      def image_size
        if pixbuf.nil?
          nil
        else
          # Translators: Image "<width> x <height>"
          Util::Gettext.gettext_f(
            "{}\u{202F}\u{D7}\u{202F}{}",
            [pixbuf.width.to_s, pixbuf.height.to_s],
          )
        end
      end

      def file_size
        metadata&.file_size.then { |bytes| bytes.nil? ? nil : Util.format_size(bytes) }
      end

      def open_folder
        Gtk::FileLauncher.new(file).open_containing_folder(loupe_window, nil) { |_launcher, _result| }
      end

      def copy_location
        location = metadata&.has_gps_location? ? gps_display : nil
        unless location.nil?
          display.clipboard.set_text(location)
          window_show_toast(Util::Gettext.gettext("Image Coordinates Copied"), :normal)
        end
      end

      def open_location
        unless metadata.nil? || !metadata.has_gps_location?
          Gio::AppInfo.launch_default_for_uri_async(geo_uri, nil, nil) { |_source, _result| }
        end
      end

      # Upstream's `iso_6709`: the same degree/minute/second display the
      # location row shows, reused as the copied text.
      def gps_display
        Metadata.gps_location_display(metadata.gps_latitude, metadata.gps_longitude)
      end

      def geo_uri
        format("geo:%<lat>s,%<lon>s", lat: metadata.gps_latitude, lon: metadata.gps_longitude)
      end
  end
end
