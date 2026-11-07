# frozen_string_literal: true

require_relative "rb/version"

# The part of Loupe that loads without a display.
#
# This file exists because `require "gtk4"` initialises GTK at require time
# and raises Gtk::InitError when there is no display server, so anything that
# reaches a widget class cannot be loaded by a plain `ruby -e` or by a test
# process on a headless machine. The split is along that line and no other:
#
#   require "loupe/rb"   the version constant, settings persistence and the
#                        gettext helpers — no gtk4, no adwaita, loadable
#                        anywhere;
#   require "loupe"      all of the above plus every widget and the
#                        application, which needs a display.
#
# It is also the file the gem's version constant lives under, which is why
# spec/spec_helper.rb requires it: the specs for the display-free half need
# nothing more, and the ones that drive widgets ask for "loupe" themselves.
require_relative "util/gettext"
require_relative "config"
require_relative "settings"
require_relative "decoder/formats"
