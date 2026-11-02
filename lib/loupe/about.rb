# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "config"
require_relative "util/gettext"

module Loupe
  # Ported from src/about.rs.
  #
  # The about dialog, with the same credits, links, licence and debug info as
  # upstream. The debug info is what a bug reporter pastes into an issue:
  # version, app id, whether the app is sandboxed, and the host's os-release.
  #
  # Upstream asks the portal (`ashpd::is_sandboxed`) whether it is sandboxed,
  # and reads /run/host/etc/os-release instead of /etc/os-release when it is.
  # The same two checks the portal makes are done directly here: a Flatpak
  # sandbox has a /.flatpak-info, and a Snap sets SNAP in the environment.
  module About
    DEVELOPERS = [
      "Christopher Davis <christopherdavis@gnome.org>",
      "Sophie Herold <sophieherold@gnome.org>",
    ].freeze

    DESIGNERS = ["Allan Day", "Jakub Steiner", "Tobias Bernard"].freeze

    WEBSITE = "https://apps.gnome.org/Loupe/"
    ISSUE_URL = "https://gitlab.gnome.org/GNOME/loupe/-/issues/"
    SUPPORT_URL = "https://discourse.gnome.org/tag/loupe"

    FLATPAK_INFO = "/.flatpak-info"
    SANDBOX_ETC = "/run/host/etc"
    HOST_ETC = "/etc"

    def self.dialog
      Adwaita::AboutDialog.new.tap do |about|
        about.application_name = Util::Gettext.gettext("Image Viewer")
        about.application_icon = Config::APP_ID
        about.version = Config::VERSION
        about.developer_name = Util::Gettext.gettext("The GNOME Project")
        about.website = WEBSITE
        about.issue_url = ISSUE_URL
        about.support_url = SUPPORT_URL
        about.developers = DEVELOPERS
        about.designers = DESIGNERS
        # Translators: Replace "translator-credits" with your names, one name
        # per line
        about.translator_credits = Util::Gettext.gettext("translator-credits")
        about.copyright = Util::Gettext.gettext("Copyright © 2020–2024 Christopher Davis et al.")
        about.license_type = Gtk::License::GPL_3_0
        about.debug_info = debug_info
      end
    end

    def self.debug_info
      [
        "- Version: #{Config::VERSION}",
        "- App ID: #{Config::APP_ID}",
        "- Sandboxed: #{sandboxed?} #{ENV.fetch("container", "")}",
        "\n##### OS Information\n```\n#{os_release}\n```",
      ].join("\n")
    end

    def self.sandboxed? = File.exist?(FLATPAK_INFO) || !ENV["SNAP"].to_s.empty?

    def self.etc
      if sandboxed?
        SANDBOX_ETC
      else
        HOST_ETC
      end
    end

    def self.os_release
      File.read(File.join(etc, "os-release"))
    rescue SystemCallError
      ""
    end
  end
end
