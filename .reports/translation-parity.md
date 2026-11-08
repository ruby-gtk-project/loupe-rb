# Translation parity — loupe

| | |
|---|---|
| Upstream | `main` @ `2593900` |
| Port | `ruby` @ `4fb8595` |
| Upstream msgids (source) | 230 (229 single, 1 plural) |
| Ported (actually translated at runtime) | **13 / 230** |
| Ported (recognized by the census script's marker scan) | 0 / 230 |
| Gaps | 217 |
| Upstream shipped languages (`po/*.po`) | 58 |
| Port's `po/*.po` file count | 58 (byte-identical copy of upstream — still not evidence of parity, see below) |

## This round moved the real number off zero, for the first time

The previous two passes of this report found **0/230**: no call site in
`lib/` outside `util/gettext.rb`'s own marker-function definitions. Re-run
in this pass:

```
$ bash .claude/skills/translation-parity/scripts/msgid-census.sh lib | grep -v '^po'
!unresolved  gettext(msgid) = lookup(msgid)                    util/gettext.rb:28
!unresolved  gettext(msgid).then { ... }                       util/gettext.rb:32
!unresolved  ngettext(format, format_plural, count) ...        util/gettext.rb:41
```

Still **zero marker rows outside `gettext.rb`'s own definitions** — the
script's verdict is unchanged. But reading the port files directly (not
through the census script) shows this is now a **false negative in the
tooling**, not an accurate zero:

```
$ grep -n 'Util::Gettext.gettext\|Gettext.gettext' lib/loupe/*.rb lib/loupe/**/*.rb
```

turns up 17 call sites across `error_details.rb`, `about.rb`,
`drag_overlay.rb`, `window.rb`, `file_model.rb`, `shortcuts_dialog.rb`,
`metadata.rb` and `util.rb`, wrapping **13 distinct literal strings**. Every
one of those 13 was checked against the upstream census
(`msgid-census.sh /tmp/loupe-upstream-src`) and **matches an upstream msgid
exactly, byte for byte**:

```
Copy Error Message
Copyright © 2020–2024 Christopher Davis et al.
Could not list other files in directory.
Drop Image to View
Error Details
Error Message
Failed to restore image from trash
Image Viewer
Report _Issue
Show Details
The GNOME Project
translator-credits
%x %X
```

All 13 round-trip through `Util::Gettext.gettext` at runtime (confirmed by
`drive_foundation.rb`, which reads several of these back — e.g. the about
dialog's `application_name`, the error-details dialog's title). This is a
real, if small, step off zero: **13/230 (5.7%) of upstream's strings are
now both present, worded identically, and actually passed through a
gettext lookup when the port runs.**

## Why the census script (and real `xgettext`) still sees zero — a tooling/convention mismatch worth flagging on its own

The house style in this port calls translation through
`Util::Gettext.gettext("...")` — a namespaced method call — rather than the
bare marker forms (`_("...")`, `gettext("...")`, `N_("...")`) both this
skill's census script and Ruby's standard `gettext` gem's extraction
tooling (`rake gettext:find` / `xgettext` with default keyword list) are
built to recognize. The census script's marker regex explicitly excludes a
preceding `.` as a valid boundary character — by design, so that an
unrelated method happening to be named `gettext` on some other receiver
isn't mistaken for a marker. That design choice is reasonable in general,
but it means this port's actual convention is invisible to it.

This matters beyond this one audit tool: **`po/POTFILES.in` lists this
port's `lib/loupe/*.rb` files as the extraction source** (added in
`80c5bb6`, flagged in the previous round's `accountability-ensurance.md`),
and running real `xgettext`/`rake gettext:find` with the gettext gem's
default keyword list against those files would extract the same zero this
census script extracts — not because the strings aren't there, but because
none of Ruby-gettext's default keywords (`_`, `N_`, `n_`, `s_`, `Nn_`,
`gettext`, `ngettext`, called bare after `include GetText`) match a
qualified call like `Util::Gettext.gettext(...)`. **If this port ever wires
up real catalogue extraction, it will need either a custom `--keyword`
argument naming `Util::Gettext.gettext`/`Util::Gettext.ngettext`, or to
switch the house call convention to the bare marker form upstream's own
`.rs` macros use (`_!(...)`, roughly).** Until one of those happens, the
13 strings that are genuinely translated at runtime still cannot be
re-extracted into an updated catalogue by the tooling already sitting in
`po/POTFILES.in`.

## The `po/` directory — same finding as the last two rounds, unchanged

```
$ diff <(git show origin/main:po/de.po) po/de.po
(no output — byte-identical)
```

Still a verbatim, byte-for-byte copy of upstream's 58 catalogues, still
pointing at upstream source paths (`src/widgets/window.ui:12` and similar)
that don't exist on this branch, still disconnected from the port's actual
13 marked strings (which a real extraction run, even with the keyword gap
above fixed, would produce a catalogue of 13 entries from — not 230, and
not matching upstream's `#:` location comments either way). No change since
the last pass; the finding stands as previously reported.

## Verdict

**13/230 (5.7%), up from 0/230 the last two rounds — a real, if small,
improvement**, and the first round where any upstream string is both
present and functionally wired to a gettext lookup in the running app. The
gap is still 217 of 230 strings, which tracks closely with
`component-parity.md`'s finding that 9 of 16 widget units (most of the
app's UI surface) don't exist yet to carry a label at all. Separately and
more durably: the census tooling and (by the same mechanism) real
`xgettext`/`rake gettext:find` cannot see any of the 13 strings that are
genuinely there, because the house call convention
(`Util::Gettext.gettext(...)`) isn't one of Ruby-gettext's default marker
keywords — a gap between "the string is translated at runtime" and "the
string is extractable into a catalogue" that will need to be closed
separately from writing more call sites. The `po/` directory remains a
byte-identical copy of upstream's 58 catalogues with no live connection to
the port, unchanged from the previous two rounds' finding.
