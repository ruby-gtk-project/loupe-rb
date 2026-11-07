# loupe-rb component inventory

Surveyed against `origin/main` (gtk-rs upstream) on 2026-11-07. Scope is the
whole app — see `component-identification` for method. This is a map of what
exists and what is missing, not a widget-by-widget CSS/signal breakdown (that
belongs in `component-parity` once a unit is picked for porting).

Upstream has no `.blp`; widgets are gtk-rs subclasses, most paired with a
`.ui` GtkBuilder template (`#[template(file = "...")]`). Where a `.ui` exists
it is listed alongside its `.rs`. `src/widgets/image.rs` is a `mod` block
whose behaviour lives entirely in its 12 sibling files under
`src/widgets/image/`; they are unioned into one component/row because none of
them stands alone.

Legend for **Kind**: `app` = application-class unit, `window` = top-level
window, `widget` = template-backed or code-built widget, `model` = non-widget
logic/state the widgets depend on, `dialog`, `data` = schema/settings file.

## Already ported (exist in `lib/`)

| Upstream file(s) | `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/application.rs` | `lib/loupe/application.rb` | app | yes |
| `src/widgets/window.rs` + `src/widgets/window.ui` | `lib/loupe/window.rb` | window | yes |
| `src/about.rs` | `lib/loupe/about.rb` | dialog | yes |
| `src/config.rs` | `lib/loupe/config.rb` | model | yes |
| `src/widgets/drag_overlay.rs` + `src/widgets/drag_overlay.ui` | `lib/loupe/drag_overlay.rb` | widget | yes |
| `src/widgets/error_details.rs` + `src/widgets/error_details.ui` | `lib/loupe/error_details.rb` | dialog | yes |
| `src/file_model.rs` | `lib/loupe/file_model.rb` | model | yes |
| `src/metadata.rs` (GPS-place slice only; EXIF/XMP/ICC slices have no Ruby binding and are out of scope) | `lib/loupe/metadata.rb` | model | yes (partial — by design) |
| `src/metadata/file.rs` | `lib/loupe/metadata/file.rb` | model | yes |
| `data/org.gnome.Loupe.gschema.xml.in` | `lib/loupe/settings.rb` | data | yes |
| `data/resources/shortcuts-dialog.ui` | `lib/loupe/shortcuts_dialog.rb` | dialog | yes |
| `data/resources/style.css`, `edit.css`, `edit_crop.css`, `data/resources/icons/**` | `lib/loupe/style.rb` | data | yes |
| `src/util.rs` | `lib/loupe/util.rb` | model | yes |
| `src/util/gettext.rs` | `lib/loupe/util/gettext.rb` | model | yes |
| `src/util/root.rs` | `lib/loupe/util/root.rb` | model | yes |

## Missing — the image viewing/editing pipeline (not yet ported)

This is the bulk of the app: everything that actually decodes, displays,
edits and prints an image. None of it exists under `lib/` yet.

| Upstream file(s) | Proposed `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/widgets/image_window.rs` + `image_window/actions.rs` + `image_window/controls.rs` + `src/widgets/image_window.ui` | `lib/loupe/image_window.rb` | window | **no** |
| `src/widgets/image_page.rs` + `src/widgets/image_page.ui` | `lib/loupe/image_page.rb` | widget | **no** |
| `src/widgets/image_view.rs` + `src/widgets/image_view.ui` | `lib/loupe/image_view.rb` | widget | **no** |
| `src/widgets/image.rs` + all 12 of `src/widgets/image/{background_color,drag,editing,input_handling,loading,metadata,pan,printing,rendering,rotation,scrollable,zoom}.rs` (one `LpImage` subclass split across 13 files, no `.ui`) | `lib/loupe/image.rb` | widget | **no** |
| `src/widgets/sliding_view.rs` (no `.ui`; the page-swipe container around `LpImagePage`) | `lib/loupe/sliding_view.rb` | widget | **no** |
| `src/widgets/shy_bin.rs` (no `.ui`; `Adw.Bin` subclass that hides its one child when it would be fully obscured) | `lib/loupe/shy_bin.rb` | widget | **no** |
| `src/widgets/properties_view.rs` + `src/widgets/properties_view.ui` | `lib/loupe/properties_view.rb` | widget | **no** |
| `src/widgets/edit_window.rs` + `src/widgets/edit_window.ui` | `lib/loupe/edit_window.rb` | window | **no** |
| `src/widgets/edit.rs` (re-export shim only, folds into the two files below) | — | n/a | n/a |
| `src/widgets/edit/crop.rs` + `src/widgets/edit/crop.ui` | `lib/loupe/edit/crop.rb` | widget | **no** |
| `src/widgets/edit/crop_selection.rs` + `src/widgets/edit/crop_selection.ui` (no parent class — `parent="GtkWidget"`, custom-drawn) | `lib/loupe/edit/crop_selection.rb` | widget | **no** |
| `src/widgets/print.rs` + `src/widgets/print.ui` | `lib/loupe/print.rb` | dialog | **no** |
| `src/widgets/print_preview.rs` (no `.ui`; `LpPrintPreview` + its page-layout helper `LpPrintPreviewPage`) | `lib/loupe/print_preview.rb` | widget | **no** |
| `src/decoder.rs` + `src/decoder/tiling.rs` + `src/decoder/formats.rs` + `src/decoder/formats/svg.rs` (librsvg backend) + `src/decoder/formats/glycin_proxy.rs` (glycin backend) | `lib/loupe/decoder.rb` (+ `lib/loupe/decoder/tiling.rb`, `lib/loupe/decoder/formats/svg.rb`, `lib/loupe/decoder/formats/glycin_proxy.rb`) | model | **no** |
| `src/editing.rs` (edit-operation queue) + `src/editing/preview.rs` (applies glycin `Operations` to a render node) | `lib/loupe/editing.rb` (+ `lib/loupe/editing/preview.rb`) | model | **no** |

## Not applicable / out of scope

| Item | Note |
|---|---|
| `po/*.po`, `help/**` | translation catalogue and user documentation; `util/gettext.rb` already resolves a msgid to itself pending `po/` adoption — tracked, not a widget |
| `data/org.gnome.Loupe.metainfo.xml.in.in`, `.desktop.in.in`, `.service.in` | packaging metadata, no runtime widget |
| `build-aux/flatpak/*`, `Cargo.toml`/`Cargo.lock`, `deny.toml`, `supply-chain/**` | Rust build/supply-chain tooling, has no Ruby analogue |
| `news.d/**`, `NEWS`, `CONTRIBUTING.md`, `COPYING.md`, `.gitlab-ci.yml`, `.gitlab/**` | release notes / repo process docs |

## Totals

- Ported: 15 upstream units → 15 `lib/` files.
- Missing: 13 upstream units (image_window, image_page, image_view, image
  [13 files unioned], sliding_view, shy_bin, properties_view, edit_window,
  edit/crop, edit/crop_selection, print, print_preview, decoder [5 files
  unioned], editing [2 files unioned]) → 0 of their `lib/` files exist.
- The missing set is the entire actual image-viewing/editing/printing
  pipeline — everything the ported chrome (window, about, shortcuts,
  settings, style) is built around but does not yet host.

## Binding-gem check (per task instructions)

`libgweather` is declared in `loupe-rb.gemspec`, required in
`lib/loupe/metadata.rb`, and called from `GWeather::Location.world` /
`GWeather::Location.new` there — confirmed live, not regressed. No
hand-rolled replacement for it was found in `lib/`. `gtk4`, `adwaita` and
`glib2` are declared and required throughout `lib/`. No gemspec dependency
lacks a `require` under `lib/`.
