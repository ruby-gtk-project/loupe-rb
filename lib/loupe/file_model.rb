# frozen_string_literal: true

require "gtk4"

require_relative "util"

module Loupe
  # Ported from src/file_model.rs.
  #
  # The list of images the viewer can page through. Upstream keeps an
  # IndexMap keyed by file URI so a file can be found by URI in constant time
  # while the entries still sit in an arbitrary (sorted) order; a Ruby Hash
  # preserves insertion order, so it serves the same two purposes.
  #
  # Each entry carries the sort key alongside the file: the collation keys of
  # every path segment from the root down to the file name, so that
  # "a/img9.png" sorts before "a/img10.png" and before "b/img1.png".
  #
  # Upstream makes this a GObject purely to own a "changed" signal carrying a
  # FileEvent variant. Here `connect_changed` keeps a list of blocks and
  # `emit_changed` calls them with the same three events: [:new, uri],
  # [:removed, uri] and [:moved, from_uri, to_uri].
  #
  # Upstream's methods are async because every sort key needs a file-info
  # query. The Ruby bindings expose only the synchronous queries, so the
  # port is synchronous; the file monitor callback is where upstream's
  # spawned futures were, and runs inline instead.
  class FileModel
    # The attributes upstream asks the directory enumerator for.
    DIRECTORY_ATTRIBUTES = [
      Gio::FILE_ATTRIBUTE_STANDARD_NAME,
      "standard::fast-content-type",
      "standard::is-hidden",
      Gio::FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME,
    ].join(",")

    # Upstream's three FileMonitorEvent groups.
    ADDED_EVENTS = %i[created moved_in changes_done_hint].freeze
    REMOVED_EVENTS = %i[deleted moved_out unmounted].freeze

    # Create a model holding a single file.
    def self.from_file(file) = from_files([file])

    def self.from_files(files)
      new.tap do |model|
        files.each { |file| model.add(file) }
      end
    end

    def initialize
      @files = {}
      @listeners = []
      @collation_key_cache = {}
      @directory = nil
      @monitor = nil
    end

    attr_reader :directory

    # Load every image in the given directory, keeping any files already
    # present, then sort. Upstream also starts watching the directory so the
    # list follows files appearing, vanishing and being renamed underneath it.
    def load_directory(directory)
      @directory = directory
      watch(directory)

      enumerate(directory).then do |found|
        @files = found.merge(@files)
        sort
      end
    end

    def index_of(file) = @files.keys.index(file.uri)

    def n_files = @files.length

    def contains_file?(file) = @files.key?(file.uri)

    def before(file)
      index_of(file).then do |index|
        if index.nil? || index.zero?
          nil
        else
          file_at(index - 1)
        end
      end
    end

    def after(file)
      index_of(file).then do |index|
        if index.nil?
          nil
        else
          file_at(index + 1)
        end
      end
    end

    # The `n` files before and after the given one, as a Hash of URI => file,
    # the shape the sliding view repeats pages over. Upstream returns an error
    # when the file is not in the model at all, which happens when a file is
    # deleted the moment the view moves onto it.
    def files_around(file, count)
      index_of(file).then do |index|
        if index.nil?
          warn("URI not in model: #{file.uri}")
          nil
        else
          window_around(index, count)
        end
      end
    end

    def first = file_at(0)

    def last = file_at(@files.length - 1)

    def remove(file)
      @files.delete(file.uri).then do |entry|
        entry&.fetch(:file)
      end
    end

    # Add a file without re-sorting, for building a model from an explicit
    # list in the order the caller gave.
    def add(file)
      @files[file.uri] = entry_for(file, nil)
      file
    end

    # Insert a file and re-sort. Returns true when the model changed, as
    # upstream's `insert` does.
    def insert(file)
      @files.key?(file.uri).then do |present|
        unless present
          @files[file.uri] = entry_for(file, nil)
          sort
        end
        !present
      end
    end

    def connect_changed(&block)
      @listeners << block
      block
    end

    def emit_changed(event)
      @listeners.each { |listener| listener.call(event) }
      event
    end

    private

      def file_at(index)
        if index.negative? || index >= @files.length
          nil
        else
          @files.values[index][:file]
        end
      end

      def window_around(index, count)
        offset = [index - count, 0].max
        # Upstream drops as many entries from the end as the start was
        # clamped by, so a file near the front of the list does not pull in
        # extra pages from behind it.
        reduce = [count - index, 0].max
        length = (2 * count) + 1 - reduce

        @files.to_a[offset, length].to_h { |uri, entry| [uri, entry[:file]] }
      end

      def enumerate(directory)
        enumerator = directory.enumerate_children(DIRECTORY_ATTRIBUTES, :none)
        found = {}

        while (info = next_info(enumerator))
          if image_info?(info)
            directory.get_child(info.name).then do |file|
              found[file.uri] = entry_for(file, info)
            end
          end
        end

        found
      rescue GLib::Error => error
        raise(
          Util::Error,
          "#{Util::Gettext.gettext("Could not list other files in directory.")} #{error.message}",
        )
      end

      def next_info(enumerator)
        enumerator.next_file
      rescue GLib::Error => error
        warn("Unreadable entry in directory: #{error.message}")
        nil
      end

      # GVfs smb leaves the content type out when it is ambiguous (png vs
      # apng), so upstream reads the FAST_CONTENT_TYPE: knowing a file is
      # probably an image is enough, and the loader makes the final call from
      # the magic bytes. Hidden files are skipped.
      def image_info?(info)
        info.get_attribute_string("standard::fast-content-type").then do |content_type|
          content_type.to_s.start_with?("image/") && !hidden_info?(info)
        end
      end

      def hidden_info?(info)
        if info.has_attribute?("standard::is-hidden")
          info.hidden?
        else
          false
        end
      end

      def entry_for(file, info)
        {
          file: file,
          sort: sort_key(file, info),
        }
      end

      # The collation keys of every path segment, root first. The info for the
      # file itself is reused when the caller already has it, which is
      # upstream's performance note: each query costs about a millisecond on a
      # local SMB share.
      def sort_key(file, info)
        [].tap do |keys|
          segment = file
          segment_info = info

          while segment
            name = segment_name(segment, segment_info)
            if name.nil?
              break
            end

            keys.unshift(Util.collation_key(name))
            segment = segment.parent
            segment_info = nil
          end
        end
      end

      def segment_name(segment, segment_info)
        unless segment_info.nil?
          @collation_key_cache[segment.uri] = segment_info.display_name
        end

        # Path segments repeat across the files of one directory, so the
        # queries are worth caching.
        @collation_key_cache.fetch(segment.uri) do
          @collation_key_cache[segment.uri] = queried_name(segment)
        end
      end

      def queried_name(segment)
        Util.query_attributes(segment, [Gio::FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME]).display_name
      rescue GLib::Error => error
        warn("Failed to obtain information for sorting '#{segment.uri}': #{error.message}")
        nil
      end

      def sort
        @files = @files.sort_by { |_uri, entry| entry[:sort] }.to_h
      end

      def watch(directory)
        @monitor = directory.monitor_directory(:watch_moves).tap do |monitor|
          monitor.signal_connect("changed") do |_monitor, file, other_file, event|
            file_monitor_cb(event, file, other_file)
          end
        end
      rescue GLib::Error => error
        warn("Cannot monitor directory: #{error.message}")
        nil
      end

      def file_monitor_cb(event, file, other_file)
        event.nick.tr("-", "_").to_sym.then do |name|
          case name
          when *ADDED_EVENTS then monitor_added(file)
          when *REMOVED_EVENTS then monitor_removed(file)
          when :renamed then monitor_renamed(file, other_file)
          end
        end
      end

      # Changing a file's content could in principle make it an image by
      # adding a magic byte, which is why upstream re-checks the type on
      # CHANGES_DONE_HINT too.
      def monitor_added(file)
        if image_file?(file)
          if insert(file)
            emit_changed([:new, file.uri])
          end
        end
      end

      def monitor_removed(file)
        unless remove(file).nil?
          emit_changed([:removed, file.uri])
        end
      end

      def monitor_renamed(file, other_file)
        unless other_file.nil?
          removed = !remove(file).nil?
          added = image_file?(other_file) && insert(other_file)

          if removed || added
            emit_changed([:moved, file.uri, other_file.uri])
          end
        end
      end

      def image_file?(file)
        Util.query_attributes(file, [Gio::FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE]).then do |info|
          info.content_type.to_s.start_with?("image/")
        end
      rescue GLib::Error
        warn("Could not query file info: #{file.uri}")
        false
      end
  end
end
