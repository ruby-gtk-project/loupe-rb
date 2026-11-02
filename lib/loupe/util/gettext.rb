# frozen_string_literal: true

module Loupe
  module Util
    # Ported from src/util/gettext.rs.
    #
    # Upstream wraps the `gettextrs` crate with four behaviours on top of a
    # plain catalogue lookup:
    #
    # * `ugettext` evaluates `\u{...}` escape sequences, because the
    #   catalogues spell out characters translators should not have to type
    #   literally (typographic quotes, the multiplication sign);
    # * `gettext_f` substitutes positional `{}` placeholders one at a time, so
    #   a translation can reorder nothing and still read naturally;
    # * `ngettext` picks a plural form and then substitutes the count into it;
    # * `hex_to_char` converts one escape's hex digits to the character.
    #
    # `lookup` is the catalogue lookup itself. The compiled catalogues are
    # built from po/, which this port has not taken over yet, so a msgid
    # resolves to itself — the same string upstream resolves to under the C
    # locale. Everything above the lookup is the full upstream behaviour and
    # applies to the untranslated string exactly as it does to a translated
    # one.
    module Gettext
      module_function

      # Upstream: `pub use gettextrs::gettext`.
      def gettext(msgid) = lookup(msgid)

      # Upstream: same as `gettext` but evaluates unicode escape sequences.
      def ugettext(msgid)
        gettext(msgid).then { |message| apply_unicode_escapes(message) || message }
      end

      # Upstream: `gettext_f(format, args)` — translate, then fill the `{}`
      # placeholders from `args` in order.
      def gettext_f(format, args) = freplace(ugettext(format), args)

      # Upstream: `ngettext(format, format_plural, n)` — pick the plural form,
      # evaluate escapes, then substitute `n` for the single placeholder.
      def ngettext(format, format_plural, count)
        plural_form(format, format_plural, count).then do |message|
          freplace(apply_unicode_escapes(message) || message, [count])
        end
      end

      # Replace unicode escape sequences with the actual character.
      #
      # Returns nil when a sequence's hex digits do not name a character,
      # matching upstream's `Option<String>`.
      def apply_unicode_escapes(string)
        chars = string.to_s.each_char.to_a
        result = +""
        hex = +""
        state = :none
        index = 0
        failed = false

        while index < chars.length
          char = chars[index]
          index += 1

          case state
          when :none
            if char == "\\"
              # Upstream consumes the next two characters unconditionally and
              # only switches state when they are "u" and "{"; a backslash
              # followed by anything else swallows all three.
              opener = chars[index, 2]
              index += 2
              if opener == ["u", "{"]
                state = :unicode_hex
              end
            else
              result << char
            end
          when :unicode_hex
            if char == "}"
              hex_to_char(hex).then do |converted|
                if converted.nil?
                  failed = true
                else
                  result << converted
                end
              end
              hex = +""
              state = :none
            else
              hex << char
            end
          end
        end

        if failed
          nil
        else
          result
        end
      end

      # Convert a hex string to a character, nil when it names none.
      def hex_to_char(hex)
        Integer(hex, 16).chr(Encoding::UTF_8)
      rescue ArgumentError, RangeError
        nil
      end

      # Upstream's private `freplace`: each argument fills the leftmost
      # remaining `{}`.
      def freplace(string, args)
        args.inject(string) { |carried, arg| carried.sub("{}") { arg.to_s } }
      end

      # Upstream delegates to `gettextrs::ngettext`, which selects by the
      # catalogue's plural rule; the English rule is "one versus the rest".
      def plural_form(format, format_plural, count)
        if count == 1
          lookup(format)
        else
          lookup(format_plural)
        end
      end

      def lookup(msgid) = msgid.to_s
    end
  end
end
