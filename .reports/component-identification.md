# Component identification — loupe

Upstream: `origin/main` @ `2593900` ("Release 51.rc"), gnome-loupe, Rust/gtk-rs.
Port: `ruby` branch @ `01ff0bc` (lib/ unchanged since `f914f87`, the commit this survey was originally checked against).

This repeats and confirms the survey already on file at
`.reports/component-inventory.md` (written by an earlier pass under the same
name, titled "survey, no app code written") against the current `lib/`
contents, and extends it with the per-file widget/CSS/signal/action facets the
`component-identification` skill requires. It does not re-derive the file
mapping from scratch; it checks whether the three commits landed since that
survey (`Port the support layer...`, `Inventory upstream components` x2,
`Wire appstream and libgweather, port metadata/file.rb`) actually closed any
of the rows marked **no**.

## Method

- `find /tmp/loupe-upstream \( -name '*.ui' -o -name '*.blp' \)` — upstream has
  11 `.ui` templates under `src/widgets/`, each the template root for exactly
  one widget class. These are the unit list (Step 1 of the skill).
- `find lib -name '*.rb'` on the port — 15 files, confirmed below.
- Read every port file that exists; diffed against the upstream file(s) the
  inventory maps it to.

## Upstream unit list (11 `.ui` templates + the non-template units)

| Upstream `.ui` template | Backing `.rs` | Unit |
|---|---|---|
| `window.ui` | `widgets/window.rs` | main window shell |
| `image_window.ui` | `widgets/image_window.rs` (+`actions.rs`,`controls.rs`) | image-viewing window |
| `edit_window.ui` | `widgets/edit_window.rs` | edit window |
| `image_page.ui` | `widgets/image_page.rs` | per-image page |
| `image_view.ui` | `widgets/image_view.rs` | image + zoom/overlay host |
| `drag_overlay.ui` | `widgets/drag_overlay.rs` | drop target overlay |
| `error_details.ui` | `widgets/error_details.rs` | error dialog |
| `properties_view.ui` | `widgets/properties_view.rs` | metadata sidebar |
| `print.ui` | `widgets/print.rs` | print settings page |
| `edit/crop.ui` | `widgets/edit/crop.rs` | crop toolbar |
| `edit/crop_selection.ui` | `widgets/edit/crop_selection.rs` | crop-rectangle gesture overlay |
| (no `.ui`) | `widgets/image.rs` + 12 `image/*.rs` submodules | the GL image surface (render/zoom/pan/rotate/pan/print/metadata/background-color/drag/loading/input-handling) |
| (no `.ui`) | `widgets/sliding_view.rs` | swipe between images |
| (no `.ui`) | `widgets/shy_bin.rs` | floating-child bin |
| (no `.ui`) | `application.rs` | app class: actions/accelerators/About |
| (no `.ui`, standalone) | `data/resources/shortcuts-dialog.ui` | shortcuts window |

16 units total (14 widget classes + the app class + the standalone shortcuts
window).

## Port unit list (`lib/loupe/**/*.rb`, 15 files)

```
lib/loupe.rb
lib/loupe/about.rb
lib/loupe/application.rb
lib/loupe/config.rb
lib/loupe/drag_overlay.rb
lib/loupe/error_details.rb
lib/loupe/file_model.rb
lib/loupe/metadata/file.rb
lib/loupe/rb/version.rb
lib/loupe/settings.rb
lib/loupe/shortcuts_dialog.rb
lib/loupe/style.rb
lib/loupe/util.rb
lib/loupe/util/gettext.rb
lib/loupe/util/root.rb
lib/loupe/window.rb
```

## Join — which of the 16 upstream units have a port file at all

| Upstream unit | Port file | Present? |
|---|---|---|
| window shell | `lib/loupe/window.rb` | **yes** |
| app class (actions/accelerators/About) | `lib/loupe/application.rb` + `about.rb` | **yes** |
| shortcuts window | `lib/loupe/shortcuts_dialog.rb` | **yes** |
| error details dialog | `lib/loupe/error_details.rb` | **yes** |
| drag overlay | `lib/loupe/drag_overlay.rb` | **yes** |
| **image-viewing window** | — | **no** |
| **edit window** | — | **no** |
| **per-image page** | — | **no** |
| **image + zoom/overlay host** | — | **no** |
| **the GL image surface** (`image.rs` + 12 submodules) | — | **no** |
| **sliding view** (swipe) | — | **no** |
| **shy bin** | — | **no** |
| **properties/metadata sidebar** | `lib/loupe/metadata/file.rb` covers only the filesystem-attribute slice (`src/metadata/file.rs`); `properties_view.rb` and the EXIF/XMP/GPS/color-profile model (`src/metadata.rs`) are **not present** | **partial** |
| **print settings page** | — | **no** |
| **crop toolbar** | — | **no** |
| **crop-rectangle gesture overlay** | — | **no** |

9 of 16 units have no port file at all; one more (properties/metadata) has
only its least interesting third ported. That is 5.5/16 units with any file,
and of the 5 that have one, every facet (widget count, CSS, signals, actions,
text) still needs checking — which `component-parity.md` does.

## What exists is identified, facet by facet

### `lib/loupe/window.rb` — main window shell (286 lines)

| Widget | × | CSS | Signals/Actions | Notes |
|---|---:|---|---|---|
| `Adwaita::ApplicationWindow` (subclass) | 1 | — | `notify::default-width` (layout breakpoints) | |
| `Adwaita::ToastOverlay` | 1 | — | — | `show_toast` |
| `Gtk::Stack` | 1 | — | — | holds image_page / edit_page |
| win actions | 2 | — | `show-error`, `show-loader-error` | confirmed by `drive_foundation.rb` |

`window.image_page` / `window.edit_page` / `window.edit_window` are referenced
by the drive script but there is **no `ImagePage` or `EditWindow` class** —
`window.rb` stands in a placeholder `Gtk::Box` or similar for both, which is
why `component-parity.md` records this as a facade, not a parity pass.

### `lib/loupe/about.rb`, `error_details.rb`, `shortcuts_dialog.rb`, `drag_overlay.rb`

Each is a direct 1:1 port of its upstream file with no missing widget type
found by inspection; see `component-parity.md` for the CSS/signal/text
comparison against upstream's `.ui`.

### `lib/loupe/metadata/file.rb`

One class, `Loupe::Metadata::FileInfo`, five attributes
(`display_name`, `file_size`, `created`, `modified`, `host_path`). This is a
faithful port of `src/metadata/file.rs` alone. It is not the properties
sidebar: upstream's `src/metadata.rs` additionally holds EXIF orientation,
camera make/model, GPS coordinates (reverse-geocoded through **libgweather**),
color-profile name, and the dimensions/format pair, all of which the commit
`f914f87` titled "Wire appstream and libgweather, port metadata/file.rb" does
not actually touch — see `accountability-ensurance.md`.

## Rows the scan would under-report, and the inventory already caught

The existing `.reports/component-inventory.md` already lists the specific
under-reported facets this skill's Step 4 asks for by name: the twelve
`image/*.rs` submodules that union into one `LpImage` widget, the
action-table split across `image_window/actions.rs`, and the
glycin-D-Bus-service dependency behind the decoder. Those stand; nothing in
this pass overturns them.

## Verdict

Unchanged from the inventory already on file, with one correction: that
document's "already ported (9 files)" count is now 10 (`metadata/file.rb`
added), and its claim that `metadata.rb`/`metadata/file.rb` are both missing
is now half-wrong — `file.rb` exists, `metadata.rb` (the EXIF/XMP/GPS/color
model the properties sidebar actually displays) still does not.

**This is a gap, not a pass.** 9 of 16 top-level units have no port file;
the app's entire reason for existing — showing, zooming, panning, rotating,
cropping, printing and inspecting an image — has no component built for it.
