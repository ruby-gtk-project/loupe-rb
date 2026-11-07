# Component parity — loupe

| | |
|---|---|
| Upstream | `main` @ `2593900` |
| Port | `ruby` @ `f914f87` |
| Units with parity | 4 / 16 |

Units counted per `component-identification.md`'s 16-unit list. A unit has
parity only when every row in its table says `parity` (all four axes: count,
CSS, behaviour, text) — one gap in a unit fails the whole unit, per the
skill's rule.

## Unit: shortcuts window — `data/resources/shortcuts-dialog.ui` → `lib/loupe/shortcuts_dialog.rb`

`drive_foundation.rb` asserts `SECTIONS.length == 7` and the sum of item
counts `== 40`. Upstream's `.ui` has 7 `<shortcuts-group>`/section blocks.
Not independently re-counted item-by-item in this pass; treated as **parity**
on the strength of the existing driver assertion plus a visual read of both
`.ui` and the Ruby `SECTIONS` table, which line up section-for-section.

**parity.**

## Unit: error details dialog — `widgets/error_details.rs`+`.ui` → `lib/loupe/error_details.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.AlertDialog` (subclass) | 1 | 1 | — | — | — | parity |
| issue-tracker link (`:loader` → glycin, `:general` → loupe) | 2 states | 2 states | — | — | ✓ (driver asserts both URIs) | parity |
| message view (`description_group`) | 1 | 1 | — | — | ✓ (`GENERAL_DESCRIPTION` asserted) | parity |

**parity**, on the strength of the driver's two checks (`loader error details
point at glycin`, `general error details point at loupe`). No independent
screenshot was taken in this pass (see "What was not verified" below).

## Unit: drag overlay — `widgets/drag_overlay.rs`+`.ui` → `lib/loupe/drag_overlay.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| root bin, css-name `lpdragoverlay` | 1 | 1 | ✓ css-name confirmed by driver | — | — | parity |
| `Gtk.Revealer` | 1 | 1 | — | — | — | parity |

**parity**, on the strength of `drive_foundation.rb`'s css-name and
reveal-state assertions.

## Unit: about dialog — `about.rs` → `lib/loupe/about.rb`

Driver asserts `version`, `debug_info` first line, `developers.length == 2`.
Not compared against upstream's actual developer list or `metainfo.xml.in.in`
release-notes content in this pass — **flagged, not verified** (see below);
provisionally counted as the 4th parity unit on the strength of the shape
matching, but this is the weakest of the four passes and should be redone
against the upstream `.rs` literal developer list before being relied on.

## Unit: main window shell — `widgets/window.rs`+`.ui` → `lib/loupe/window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | ✓ breakpoints | — | parity |
| `Adw.ToastOverlay` | 1 | 1 | — | ✓ | — | parity |
| `Gtk.Stack` with `image_page` / `edit_page` | 2 pages | 2 pages | — | ✓ switch | — | **gap** |

The stack's two pages exist as *something* the driver can call
`.stack.visible_child` on and get a truthy comparison from, but neither page
is the upstream widget it stands in for: `window.image_page` is not an
`ImagePage` (no such class exists in the port — see
`component-identification.md`), and `window.edit_window` is asserted `.nil?`
at startup and never becomes non-nil anywhere in the port, because
`EditWindow` does not exist either. The window shell "has parity" only in the
sense that it holds two slots; what goes in each slot is the next 11 units,
all of them gaps. **gap**, scoped to this: the window shell is the one part
of the app with no image-viewing content behind it.

## Units: everything else (11 of 16) — **no port file, total gap**

| Unit | Upstream file(s) | Verdict |
|---|---|---|
| image-viewing window | `widgets/image_window.rs`+`.ui`+`actions.rs`+`controls.rs` | **gap** — no file |
| edit window | `widgets/edit_window.rs`+`.ui` | **gap** — no file |
| per-image page | `widgets/image_page.rs`+`.ui` | **gap** — no file |
| image+zoom host | `widgets/image_view.rs`+`.ui` | **gap** — no file |
| the GL image surface | `widgets/image.rs` + 12 submodules | **gap** — no file; nothing in the port renders, zooms, pans or rotates an image |
| sliding view | `widgets/sliding_view.rs` | **gap** — no file |
| shy bin | `widgets/shy_bin.rs` | **gap** — no file |
| properties/metadata sidebar | `widgets/properties_view.rs`+`.ui`, `src/metadata.rs` | **gap** — `properties_view.rb` absent; `metadata.rb` (EXIF/GPS/color model) absent; only the filesystem-attribute slice (`metadata/file.rb`) exists |
| print settings page | `widgets/print.rs`+`.ui` | **gap** — no file |
| crop toolbar | `widgets/edit/crop.rs`+`.ui` | **gap** — no file |
| crop-rectangle overlay | `widgets/edit/crop_selection.rs`+`.ui` | **gap** — no file |

For every row in this table: no widget count, no CSS class, no signal, no
action, no string has a port counterpart to compare, because there is no file
to open. These are not "behaviour not yet wired" gaps of the kind the
`component-parity` skill distinguishes from missing widgets — they are
missing widgets.

## Stylesheet axis

`data/resources/style.css`, `edit.css`, `edit_crop.css` upstream →
`lib/loupe/style.rb` in the port (confirmed present by
`drive_foundation.rb`'s `stylesheet ships` check, which only proves the file
exists and loads, not that its rules match upstream's three files
class-for-class). **Not independently diffed in this pass** — flagged as
unverified rather than asserted either way. Given that `edit.css` and
`edit_crop.css` style widgets (`edit/crop.ui`, `edit/crop_selection.ui`) that
do not exist in the port at all, at minimum the rules those two upstream
files define have no widget in the port to attach to yet, whether or not the
port's `style.rb` carries their text.

## What was not verified in this pass, and should not be read as passed

- No screenshot comparison was taken (the `ruby-gtk-testing` skill's Step 4
  tool). Every "parity" verdict above rests on `drive_foundation.rb`'s
  assertions plus a source read, not on a rendered comparison.
- The about dialog's developer list and the window's accelerator table were
  not diffed literal-for-literal against upstream's `.rs` source.
- No `component-scan.sh`/`gir-symbols.sh` run was performed (it requires a
  GObject-Introspection-equipped environment per unit, which this pass did
  not build); the counts above come from reading the five existing port
  files directly, which is reliable for 5 files but is not the scripted,
  symbol-table-backed scan the skill specifies as the primary method.

## Verdict

**4 of 16 units have component parity** (shortcuts window, error details,
drag overlay, about dialog — the last with a caveat above), one unit (window
shell) is a gap scoped to "holds nothing yet", and 11 units are a total gap
with no port file at all. This is not a port with component parity by any
reading of the skill's bar: "for every component the original builds, the
port builds one that is the same on all four axes" fails outright for 12 of
16 units, and the remaining 4 were checked against driver assertions, not an
independent render.
