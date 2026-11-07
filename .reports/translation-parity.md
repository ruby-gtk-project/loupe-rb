# Translation parity — loupe

| | |
|---|---|
| Upstream | `main` @ `2593900` |
| Port | `ruby` @ `f914f87` |
| Upstream msgids (source) | 230 (229 single, 1 plural) |
| Ported | 0 |
| Gaps | 230 |
| Upstream shipped languages (`po/*.po`) | 58 |
| Port shipped languages | 0 |

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

## The `po/` directory

Upstream ships `po/*.po` for 58 languages (`ar`, `be`, `bg`, ... `zh_TW`) plus
`po/POTFILES.in` and `po/meson.build`. The port has **no `po/` directory at
all.** There is no catalogue for any of the 230 keys to be translated into,
even for the keys that do eventually get marked.

## Verdict

**0/230.** Every translatable string upstream ships, and every one of the 58
languages behind it, is currently absent from the port. This is not a
reworded-string problem or a retyped-label problem (the kind of narrow gap
the skill distinguishes from wholesale absence) — it is that the UI carrying
those 230 strings has mostly not been built yet (`component-parity.md`:
11/16 units with no port file), so there is nothing yet for a label to be
reworded *in*. The marker machinery in `util/gettext.rb` is sound and ready;
it is wired to nothing.
