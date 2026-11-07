# Translation parity — loupe

| | |
|---|---|
| Upstream | `main` @ `2593900` |
| Port | `ruby` @ `01ff0bc` |
| Upstream msgids (source) | 230 (229 single, 1 plural) |
| Ported (actually marked in `lib/`) | 0 |
| Gaps | 230 |
| Upstream shipped languages (`po/*.po`) | 58 |
| Port's `po/*.po` file count | 58 (copied verbatim, see below — **not evidence of parity**) |

## Method

```
bash .claude/skills/translation-parity/scripts/msgid-census.sh /tmp/loupe-upstream > up-msgids.tsv
bash .claude/skills/translation-parity/scripts/msgid-census.sh .                   > port-msgids.tsv
```

Upstream census, markers only (`kind` = `single`/`plural`, excluding the
`po` rows the script also collects from `po/*.po` catalogue entries): **310
marker occurrences, 230 distinct (msgctxt, msgid) keys.** A sample of the
distinct keys: `_Cancel`, `Delete`, `Copy Error Message`, `Could Not Load
Image`, `Custom Zoom Level`, `Aspect Ratio`, `Crop Tool`, `CICP`, `DCI P3`,
` (Edited)` (the one plural form).

Port census over `lib/`: **zero marker rows.** The scan did not find a
single `_()`, `N_()`, `n_()`, `Nn_()` or `np_()` call wrapping a string
literal anywhere in the port.

## What `lib/loupe/util/gettext.rb` actually is

The file exists and the port's own driver (`drive_foundation.rb`) exercises
it — `gettext_f`, `apply_unicode_escapes`, `hex_to_char`, `ngettext` all pass
their checks. But reading the file shows why the census returns nothing: it
defines the **marker machinery** (`gettext`, `ngettext`, placeholder
substitution, unicode-escape evaluation) — it does not *call* that machinery
on any of upstream's 230 strings anywhere else in the port. There is no
`require "gettext"` setup wired to a `.mo` catalogue, no `po/` directory, and
grepping every other file in `lib/` for `_(` or `N_(` returns nothing either
(confirmed separately from the census: `grep -rn '_(' lib/` matches only the
definition sites inside `gettext.rb` itself).

In other words: the port built the plumbing a translated string would run
through, and then built zero windows, dialogs or labels that put a string
through it, because — per `component-identification.md` and
`component-parity.md` — the five widget files that exist so far
(`window.rb`, `about.rb`, `error_details.rb`, `shortcuts_dialog.rb`,
`drag_overlay.rb`) build their labels either from data passed in at runtime
(error messages, version strings) or have not yet been checked string-by-
string against upstream's `.ui` labels in this pass. Either way, the 230
keys upstream's translators have 58 languages of coverage for have **no
matching key in the port at all** — not reworded, not retyped, simply absent.

## The `po/` directory — now present, and this is the most serious finding in this report

Since the previous pass, commit `80c5bb6` ("Port desktop/metainfo/service
data files, app icons, and help/po catalogues") added a `po/` directory with
58 `.po` files, `po/POTFILES.in` and `po/LINGUAS`. Read naively this looks
like translation parity closed overnight. It did not:

```
$ git show origin/main:po/de.po > /tmp/up_de.po
$ diff /tmp/up_de.po po/de.po
(no output — byte-identical)
```

Every `.po` file checked is a **verbatim copy of upstream's catalogue**,
msgid for msgid, including upstream's own `#:` source-location comments
pointing at upstream's `.rs`/`.ui` paths (e.g. `src/widgets/window.ui:12`) —
paths that do not exist in this port at all. `po/POTFILES.in` lists this
port's `lib/loupe/*.rb` files as the extraction sources, but:

```
$ grep -rn '_(\|N_(\|ngettext' lib/loupe/*.rb lib/loupe/**/*.rb
(no matches outside gettext.rb's own definitions)
```

Running `xgettext` against `po/POTFILES.in` as it stands today would extract
**zero** msgids from this port's actual source, because — confirmed again
in this pass — there is still not one `_()`/`N_()`/`ngettext` call site
anywhere in `lib/` outside `util/gettext.rb`'s own marker-function
definitions. The 58 `.po` files are translations of 230 strings that no file
in `POTFILES.in` contains. They are decoration copied from upstream, not a
translation catalogue for this port, and a reviewer who sees "58 languages,
po/ directory present" in a file listing and reads that as translation
parity has been actively misled by the repo's own state. This is a more
serious finding than last round's "no po/ directory at all," because an
absent directory cannot be mistaken for coverage — a directory full of
real-looking, byte-identical-to-upstream `.po` files can.

(`help/*/​*.po` under the Mallard help pages were copied the same way, same
caveat: upstream's help pages are reproduced verbatim, which is at least
honestly a straight content copy of static docs rather than a claim about
runtime string marking, but it still is not something this report counts as
"ported" since no port-side help viewer or build step consumes them.)

## Verdict

**0/230, unchanged.** Every translatable string upstream ships, and every
one of the 58 languages behind it, is currently absent from functional use
in the port — the UI carrying those 230 strings has mostly not been built
yet (`component-parity.md`: 11/16 units with no port file), so there is
nothing yet for a label to be reworded *in*, and the marker machinery in
`util/gettext.rb` is sound and ready but wired to nothing. What changed this
round is not the parity number — it is that the repo now contains a `po/`
directory that *looks* like 58-language coverage and is not: 58 files
copied unmodified from upstream, pointed at source paths and `lib/` call
sites that do not exist on this branch. Treat "po/ has 58 files" and
"translation parity" as unrelated claims; the first is now true, the second
remains 0/230.
