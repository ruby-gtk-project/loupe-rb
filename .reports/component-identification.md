# Component identification — loupe

| | |
|---|---|
| Upstream | `origin/main` @ `2593900` ("Release 51.rc") |
| Port | `ruby` @ `4fb8595` |

This is a re-run of the identification pass, against the branch as it stands
today — three commits past the previous pass's `01ff0bc`/`f914f87`
(`6056fcb` "Inventory upstream components", `3c5caa5` "Port shy_bin and the
image decoder model", `4fb8595` "Add the display-free loupe/rb entry
point"). It reuses the previous pass's 16-unit upstream list (confirmed
still accurate against `origin/main`) and re-checks which of those 16 now
have a port file.

## Method

- `git ls-tree -r --name-only origin/main` under `src/` — same 11 `.ui`
  templates, same non-`.ui` units as before; re-confirmed, unchanged.
- `find lib -name '*.rb'` on the port — now **21 files** (up from 15).
- Read every file added or grown since the last pass: `lib/loupe/decoder.rb`,
  `lib/loupe/decoder/formats.rb`, `lib/loupe/metadata.rb`,
  `lib/loupe/metadata/file.rb` (grown), `lib/loupe/shy_bin.rb`,
  `lib/loupe/rb.rb`, `lib/loupe/rb/version.rb`, `lib/loupe/window.rb`
  (grown).

## Upstream unit list (unchanged from the previous pass — 16 units)

| Upstream `.ui` template / unit | Backing `.rs` |
|---|---|
| `window.ui` | `widgets/window.rs` |
| `image_window.ui` | `widgets/image_window.rs`+`actions.rs`+`controls.rs` |
| `edit_window.ui` | `widgets/edit_window.rs` |
| `image_page.ui` | `widgets/image_page.rs` |
| `image_view.ui` | `widgets/image_view.rs` |
| `drag_overlay.ui` | `widgets/drag_overlay.rs` |
| `error_details.ui` | `widgets/error_details.rs` |
| `properties_view.ui` | `widgets/properties_view.rs` + `src/metadata.rs` |
| `print.ui` | `widgets/print.rs` |
| `edit/crop.ui` | `widgets/edit/crop.rs` |
| `edit/crop_selection.ui` | `widgets/edit/crop_selection.rs` |
| (no `.ui`) | `widgets/image.rs` + 12 `image/*.rs` submodules |
| (no `.ui`) | `widgets/sliding_view.rs` |
| (no `.ui`) | `widgets/shy_bin.rs` |
| (no `.ui`) | `application.rs` |
| (no `.ui`, standalone) | `data/resources/shortcuts-dialog.ui` |

## Join — which of the 16 upstream units now have a port file

| Upstream unit | Port file | Present? | Changed since last pass? |
|---|---|---|---|
| window shell | `lib/loupe/window.rb` | yes | grown (file-model wiring) |
| app class | `lib/loupe/application.rb`+`about.rb` | yes | no |
| shortcuts window | `lib/loupe/shortcuts_dialog.rb` | yes | no |
| error details dialog | `lib/loupe/error_details.rb` | yes | no |
| drag overlay | `lib/loupe/drag_overlay.rb` | yes | no |
| **shy bin** | `lib/loupe/shy_bin.rb` | **yes — new this round** | added (`3c5caa5`) |
| image-viewing window | — | no | unchanged |
| edit window | — | no | unchanged |
| per-image page | — | no | unchanged |
| image + zoom/overlay host | — | no | unchanged |
| the GL image surface (image.rs+12 submodules) | — | no | unchanged |
| sliding view | — | no | unchanged |
| **properties/metadata sidebar** | `lib/loupe/metadata.rb` (new) + `metadata/file.rb` | **partial** | `metadata.rb` added (`3c5caa5`), covers only the GPS-place slice; `properties_view.rb` (the actual sidebar widget) still absent |
| print settings page | — | no | unchanged |
| crop toolbar | — | no | unchanged |
| crop-rectangle overlay | — | no | unchanged |

**6 of 16 units now have a port file** (up from 5), plus the
properties/metadata unit remains partial (up from "least interesting
third" to "two of three model slices, still no widget"). **9 of 16 units
still have no port file at all** (down from 10).

## What's new, read file by file

### `lib/loupe/shy_bin.rb` (43 lines) — real, faithful port

One class, `Loupe::ShyBin < Adwaita::Bin`, overriding `virtual_do_measure`
and `virtual_do_size_allocate`. Diffed directly against
`src/widgets/shy_bin.rs`: the Rust `measure()` clamps natural width to
minimum width on the horizontal axis only and passes every other axis
through unchanged; the Ruby does exactly that, same clamp, same pass-
through. `drive_foundation.rb` section `[14]` exercises it against a real
label child and asserts the clamp numerically. This is the cleanest 1:1 in
the port.

### `lib/loupe/decoder.rb` + `decoder/formats.rb` (172 lines) — real, but not one of the 16 units

Ported from `src/decoder.rs`+`decoder/formats.rs` (and explicitly *not*
`decoder/formats/glycin_proxy.rs`, `decoder/tiling.rs`, or
`decoder/formats/svg.rs`'s sandboxed half). This is infrastructure the
missing `image.rs`/`image_view.rs`/`image_window.rs` units will eventually
need, not one of the 16 widget units itself, so it does not move any row in
the table above — but it is a real, honestly-scoped piece of groundwork: it
decodes a real PNG via `GdkPixbuf::PixbufLoader` (confirmed by
`drive_foundation.rb` sections `[15]`–`[17]`) and documents in its own
header comment, correctly, that upstream's async/tiled/sandboxed glycin
pipeline has no Ruby binding and is not what this file does.

### `lib/loupe/metadata.rb` (70 lines) — real, but one-third of its unit

Ported from the GPS-coordinates half of `src/metadata.rs`'s `Metadata`
struct: `gps_location_place`/`gps_location_display`, using `libgweather`'s
`GWeather::Location.world.find_nearest_city` the same way upstream does, with
the same 15km cutoff. Confirmed live against a real GPS-tagged file in
`drive_foundation.rb` section `[13]` ("GWeather resolves it to London,
United Kingdom"). What upstream's `metadata.rs` also holds — EXIF
orientation/camera make/model (gufo), image/frame details and ICC profile
name (glycin, moxcms) — remains absent, same as last pass, and the file's
own header comment says so plainly. The **widget** that would display any
of this, `properties_view.rb`, still does not exist, so a user running the
port still cannot open a properties/metadata sidebar at all regardless of
how much of the model behind it is now built.

### `lib/loupe/rb.rb` + `rb/version.rb` — plumbing, not a unit

A display-free require boundary (`require "loupe/rb"` loads version/
settings/gettext without touching GTK) so the spec suite can load something
without a display. Reasonable, and not one of the 16 units.

## Verdict

**Improved since the last pass, by one full unit (shy_bin) and one partial
slice (metadata.rb's GPS piece), out of 16.** 9 of 16 units still have no
port file at all, and the unit that matters most for "is this an image
viewer yet" — the actual image-rendering/zoom/pan/rotate surface
(`image.rs`+12 submodules, `image_view.rs`, `image_window.rs`,
`image_page.rs`) — remains completely unstarted. The new decoder is real
groundwork toward that surface but is not itself a visible component. The
core finding from the last pass stands: **the app's entire reason for
existing — showing, zooming, panning, rotating, cropping, printing and
inspecting an image — still has no widget built for it**, aside from the
model-layer pieces (decoder, GPS lookup) that such widgets would eventually
call into.
