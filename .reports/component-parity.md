# Component parity — loupe

| | |
|---|---|
| Upstream | `main` @ `2593900` |
| Port | `ruby` @ `4fb8595` |
| Units with parity | 5 / 16 |

Units counted per `component-identification.md`'s 16-unit list, same rule as
last pass: a unit has parity only when every row in its table says `parity`
on all four axes (count, CSS, behaviour, text) — one gap fails the whole
unit.

## Units unchanged since the last pass (still parity)

- **shortcuts window** — `drive_foundation.rb` section `[8]` asserts 7
  sections / 40 items, matching upstream's `.ui`. **parity.**
- **error details dialog** — section `[5]`–`[7]` assert both issue-tracker
  URIs (loupe/glycin) and the description text. **parity.**
- **drag overlay** — section `[10]` asserts css-name `lpdragoverlay` and the
  reveal states. **parity.**
- **about dialog** — section `[9]` asserts version, debug-info first line,
  two developers. Still not diffed literal-for-literal against upstream's
  `.rs` developer list in this pass either — same caveat as last round,
  carried forward rather than silently dropped.

## Unit: shy bin — `widgets/shy_bin.rs` → `lib/loupe/shy_bin.rb` — **new this round, parity**

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.Bin` subclass, layout manager removed, hexpand | 1 | 1 | — | — | — | parity |
| `measure` clamps natural width to minimum (horizontal only) | 1 | 1 | — | ✓ (driver asserts numerically) | — | parity |
| `size_allocate` passes through to child | 1 | 1 | — | ✓ | — | parity |

Diffed directly against `src/widgets/shy_bin.rs` (read in full for this
pass): the Ruby's `virtual_do_measure`/`virtual_do_size_allocate` match the
Rust `measure`/`size_allocate` overrides line for line in behaviour.
`drive_foundation.rb` section `[14]` builds a real label child and checks
the clamp numerically (natural width reduced to minimum, vertical axis
untouched). **parity** — the strongest-verified unit in the port, including
a behavioural (not just shape) check.

## Unit: main window shell — unchanged verdict, still a gap

Same finding as last pass: the `Gtk.Stack`'s two pages
(`image_page`/`edit_page`) are present as slots the driver can read
`.stack.visible_child` from, but neither slot holds the widget it stands in
for — there is still no `ImagePage` or `EditWindow` class anywhere in the
port. **gap**, unchanged.

## Unit: properties/metadata sidebar — unchanged verdict, still a gap, slightly more model behind it

`lib/loupe/metadata.rb` (new since last pass) now covers the GPS-place
slice of `src/metadata.rs` and is verified live in `drive_foundation.rb`
section `[13]` against both a GPS-tagged file (resolves to "London, United
Kingdom") and a far-from-any-city fallback (degrees/minutes/seconds). That
is real, checked behaviour — but it is model, not the widget. There is
still no `properties_view.rb`, so there is still no sidebar a user can open
to see it, EXIF/camera/color-profile fields are still entirely absent, and
the unit as a whole — "properties/metadata sidebar" — still has no widget.
**gap**, unchanged in verdict though the model behind it grew.

## Units: everything else (9 of 16) — still no port file, total gap

| Unit | Upstream file(s) | Verdict |
|---|---|---|
| image-viewing window | `widgets/image_window.rs`+`.ui`+`actions.rs`+`controls.rs` | **gap** — no file |
| edit window | `widgets/edit_window.rs`+`.ui` | **gap** — no file |
| per-image page | `widgets/image_page.rs`+`.ui` | **gap** — no file |
| image+zoom host | `widgets/image_view.rs`+`.ui` | **gap** — no file |
| the GL image surface | `widgets/image.rs` + 12 submodules | **gap** — no file; decoder.rb (new) feeds a pixbuf to nothing, since no image-rendering widget exists to receive it |
| sliding view | `widgets/sliding_view.rs` | **gap** — no file |
| print settings page | `widgets/print.rs`+`.ui` | **gap** — no file |
| crop toolbar | `widgets/edit/crop.rs`+`.ui` | **gap** — no file |
| crop-rectangle overlay | `widgets/edit/crop_selection.rs`+`.ui` | **gap** — no file |

## Stylesheet axis — still not independently diffed

`data/resources/style.css`/`edit.css`/`edit_crop.css` → `lib/loupe/style.rb`.
Unchanged from last pass: confirmed present and loading, not diffed
class-for-class. `edit.css`/`edit_crop.css` still style widgets
(`edit/crop.ui`, `edit/crop_selection.ui`) that do not exist in the port.

## What was not verified in this pass

- No independent screenshot comparison against upstream renders (the driver
  takes screenshots into `tmp/shots/`, confirmed present for all 9 states it
  covers, but nothing in this pass or the repo compares them pixel-for-pixel
  against a reference render of upstream).
- About dialog's developer list / window accelerator table: still not
  diffed literal-for-literal against the `.rs` source, same gap as last
  round.
- No `component-scan.sh`/`gir-symbols.sh` scripted run; this pass again
  reads the port files directly plus the driver's assertions.

## Verdict

**5 of 16 units have component parity** (shortcuts window, error details,
drag overlay, about dialog, and — new this round — shy bin), up from 4.
The window shell remains a gap scoped to "holds nothing yet" and the
properties/metadata unit remains a gap with more model behind it than last
round but still no widget. **9 of 16 units are a total gap with no port
file at all.** The core verdict from the last pass is unchanged: this is not
a port with component parity by the skill's bar — the image-viewing,
editing, cropping and printing surface that is the actual reason the app
exists has gained one piece of supporting infrastructure (a decoder that
feeds nothing) but not one visible widget.
