# Loupe component inventory (survey, no app code written)

Upstream: `origin/main` (gnome-loupe, Rust/gtk-rs). Port: `ruby` branch,
`lib/loupe/`. Columns: upstream file(s), the `lib/loupe/*.rb` path it should
become, the component's kind, and whether that port file already exists.

Kind legend: **window** (top-level `Adw.Window`/`Gtk.Window`), **page**
(a view swapped into a stack/navigation view), **dialog** (transient,
`Adw.Dialog`/`Adw.AlertDialog`/shortcuts window), **widget** (a composite
child widget, not top-level), **row** (list-row style component),
**app** (the `Adw.Application` subclass: actions, accelerators, lifecycle),
**model** (non-widget domain object: decoder, file model, metadata),
**service/data** (settings, config, style, i18n helpers), **menu/shortcuts**
(declarative-only component with no backing Rust class).

## Application shell

| Upstream file(s) | Port path | Kind | Exists? |
|---|---|---|---|
| `src/application.rs` | `lib/loupe/application.rb` | app | yes |
| `src/about.rs` | `lib/loupe/about.rb` | dialog | yes |
| `src/config.rs` | `lib/loupe/config.rb` | service/data | yes |
| `src/main.rs`, `src/lib.rs` | `lib/loupe.rb` (entry point) | app | yes (entry point present; confirm `main`-equivalent bootstrap matches upstream argv/log-domain setup) |
| `data/org.gnome.Loupe.gschema.xml.in` | `lib/loupe/settings.rb` | service/data | yes |
| `data/resources/style.css`, `data/resources/edit.css`, `data/resources/edit_crop.css` | `lib/loupe/style.rb` | service/data | yes |
| `src/util.rs` | `lib/loupe/util.rb` | service/data | yes |
| `src/util/gettext.rs` | `lib/loupe/util/gettext.rb` | service/data | yes |
| `src/util/root.rs` | `lib/loupe/util/root.rb` | service/data | yes |
| `data/resources/shortcuts-dialog.ui` | `lib/loupe/shortcuts_dialog.rb` | menu/shortcuts (dialog) | yes |
| `data/org.gnome.Loupe.metainfo.xml.in.in` | no port file yet (no `lib/loupe/metainfo.rb` or equivalent) | service/data | **no** — release notes / `<screenshots>` / `<url>` entries referenced by the About dialog are not modeled anywhere; `about.rb` should be checked against it for completeness |
| `data/org.gnome.Loupe.desktop.in.in` | n/a (packaging, not app code) | service/data | n/a |

## Windows

| Upstream file(s) | Port path | Kind | Exists? |
|---|---|---|---|
| `src/widgets/window.rs` + `src/widgets/window.ui` | `lib/loupe/window.rb` | window | yes |
| `src/widgets/image_window.rs` + `src/widgets/image_window.ui` + `src/widgets/image_window/actions.rs` + `src/widgets/image_window/controls.rs` | `lib/loupe/image_window.rb` (+ split for actions/controls per house style, e.g. `lib/loupe/image_window/actions.rb`) | window | **no** — this is the main image-viewing window (toolbar, zoom controls, properties sidebar toggle, open/trash/print/edit actions) and has no port file at all |
| `src/widgets/edit_window.rs` + `src/widgets/edit_window.ui` | `lib/loupe/edit_window.rb` | window | **no** — the image-editing window (crop UI host, save/cancel, unsaved-changes handling) |

## Pages / sub-views

| Upstream file(s) | Port path | Kind | Exists? |
|---|---|---|---|
| `src/widgets/image_page.rs` + `src/widgets/image_page.ui` | `lib/loupe/image_page.rb` | page | **no** — one page per open image (spinner/error/loaded states, drag-and-drop target) |
| `src/widgets/sliding_view.rs` | `lib/loupe/sliding_view.rb` | widget (custom `Gtk.Widget`/`Adw.Swipeable` for next/prev image swipe) | **no** |
| `src/widgets/print_preview.rs` (+ `LpPrintPreviewPage`) | `lib/loupe/print_preview.rb` | widget/page | **no** |

## Core image widgets

| Upstream file(s) | Port path | Kind | Exists? |
|---|---|---|---|
| `src/widgets/image.rs` + submodules `image/background_color.rs`, `image/drag.rs`, `image/editing.rs`, `image/input_handling.rs`, `image/loading.rs`, `image/metadata.rs`, `image/pan.rs`, `image/printing.rs`, `image/rendering.rs`, `image/rotation.rs`, `image/scrollable.rs`, `image/zoom.rs` | `lib/loupe/image.rb` (one class; submodules are facets of the same `LpImage` widget, per the "one upstream unit may be split across files" rule — union them into one port file, possibly split into `lib/loupe/image/*.rb` mixins if the house style calls for it) | widget | **no** — this is the single biggest missing component: the actual GL-rendered, zoomable/pannable/rotatable image surface. Nothing under `lib/loupe/` renders an image yet |
| `src/widgets/image_view.rs` + `src/widgets/image_view.ui` | `lib/loupe/image_view.rb` | widget | **no** — hosts `LpImage` plus zoom/overlay controls |
| `src/widgets/shy_bin.rs` | `lib/loupe/shy_bin.rb` | widget (`Adw.Bin` subclass that hides a floating child based on allocation) | **no** |
| `src/widgets/drag_overlay.rs` + `src/widgets/drag_overlay.ui` | `lib/loupe/drag_overlay.rb` | widget | yes |

## Editing

| Upstream file(s) | Port path | Kind | Exists? |
|---|---|---|---|
| `src/widgets/edit.rs` (facade/mod for edit submodule) | `lib/loupe/edit.rb` (or folded into `edit_window.rb`) | widget | **no** |
| `src/widgets/edit/crop.rs` + `src/widgets/edit/crop.ui` | `lib/loupe/edit/crop.rb` | widget | **no** — aspect-ratio menu, orientation toggle, apply/reset |
| `src/widgets/edit/crop_selection.rs` + `src/widgets/edit/crop_selection.ui` | `lib/loupe/edit/crop_selection.rb` | widget | **no** — the draggable crop-rectangle overlay with gesture-based edge/corner handles |
| `src/editing.rs` | `lib/loupe/editing.rb` | model | **no** — edit-operation/undo-stack domain model backing the crop UI |
| `src/editing/preview.rs` | `lib/loupe/editing/preview.rb` | model | **no** |

## Printing

| Upstream file(s) | Port path | Kind | Exists? |
|---|---|---|---|
| `src/widgets/print.rs` + `src/widgets/print.ui` | `lib/loupe/print.rb` | dialog/page | **no** — print settings page (scale, position, page setup) |

## Properties / metadata

| Upstream file(s) | Port path | Kind | Exists? |
|---|---|---|---|
| `src/widgets/properties_view.rs` + `src/widgets/properties_view.ui` | `lib/loupe/properties_view.rb` | widget (sidebar: dimensions, EXIF, color profile, file size rows) | **no** |
| `src/metadata.rs` | `lib/loupe/metadata.rb` | model | **no** |
| `src/metadata/file.rs` | `lib/loupe/metadata/file.rb` | model | **no** |

## Errors

| Upstream file(s) | Port path | Kind | Exists? |
|---|---|---|---|
| `src/widgets/error_details.rs` + `src/widgets/error_details.ui` | `lib/loupe/error_details.rb` | dialog | yes |
| Error/empty states inside `image_page.ui` (no-image-loaded / decode-failed states) | covered by `image_page.rb` once written | page (state) | **no** (depends on `image_page.rb`) |

## Decoding / file model (non-widget, still user-facing behavior)

| Upstream file(s) | Port path | Kind | Exists? |
|---|---|---|---|
| `src/file_model.rs` | `lib/loupe/file_model.rb` | model | yes |
| `src/decoder.rs` | `lib/loupe/decoder.rb` | model | **no** — this is the format-dispatch/tiling entry point behind every page's loading state |
| `src/decoder/formats.rs` | `lib/loupe/decoder/formats.rb` | model | **no** |
| `src/decoder/formats/glycin_proxy.rs` | `lib/loupe/decoder/formats/glycin_proxy.rb` | model | **no** — glycin is a sandboxed-decoder D-Bus service with no Ruby binding; flag as a likely blocker/hand-roll risk, not something to reimplement from scratch |
| `src/decoder/formats/svg.rs` | `lib/loupe/decoder/formats/svg.rb` | model | **no** |
| `src/decoder/tiling.rs` | `lib/loupe/decoder/tiling.rb` | model | **no** |

## Keyboard shortcuts, menus, actions (cross-cutting, declarative + code)

| Upstream source | Port path | Kind | Exists? |
|---|---|---|---|
| `data/resources/shortcuts-dialog.ui` (shortcut list shown to the user) | `lib/loupe/shortcuts_dialog.rb` | menu/shortcuts | yes |
| `win.*` actions installed in `src/widgets/image_window/actions.rs` (open, trash, print, edit, rotate, copy, show-properties, etc.) | part of `lib/loupe/image_window.rb` (actions submodule) | action set | **no** — depends on `image_window.rb` |
| `app.*` actions / accelerators in `src/application.rs` | `lib/loupe/application.rb` | action set | yes (confirm full accelerator table against upstream once `image_window.rb` exists, since several accels target `win.*` actions that do not exist yet) |

## Localization

| Upstream source | Port path | Kind | Exists? |
|---|---|---|---|
| `po/*.po`, `po/POTFILES.in` | no `po/` directory in the port yet | i18n catalogue | **no** — out of scope for this survey step but flagged since `util/gettext.rb` exists and expects a catalogue to translate against |

## Out of scope for this port (not user-facing components)

`src/widgets/image/*` build/perf-only concerns already folded into `image.rb` above are listed there, not separately. Build files (`meson.build`), CI (`.gitlab-ci.yml`), supply-chain (`supply-chain/*`), help docs (`help/`), and news fragments (`news.d/`) are not application components and are omitted.

## Summary

- **Already ported (9 files):** `about`, `application`, `config`, `drag_overlay`,
  `error_details`, `file_model`, `settings`, `shortcuts_dialog`, `style`,
  plus the `util` family — i.e. the application shell, two simple dialogs, and
  the non-widget config/settings/util layer.
- **Missing — the entire image-viewing and editing experience:** `image.rb`
  (the rendering/zoom/pan/rotate surface itself), `image_view.rb`,
  `image_window.rb` (+ its actions/controls), `image_page.rb`,
  `sliding_view.rb`, `shy_bin.rb`, the full `edit/` subsystem (`edit.rb`,
  `edit/crop.rb`, `edit/crop_selection.rb`, `editing.rb`,
  `editing/preview.rb`), `print.rb`, `print_preview.rb`, `properties_view.rb`,
  `metadata.rb` (+ `metadata/file.rb`), and the whole `decoder.rb` subsystem
  (`decoder/formats.rb`, `decoder/formats/glycin_proxy.rb`,
  `decoder/formats/svg.rs`, `decoder/tiling.rb`).
- In short: what exists today is the app chrome (window frame, about dialog,
  error dialog, shortcuts dialog, settings/config) but **no image is actually
  decoded, rendered, zoomed, printed, edited, or inspected yet** — that is all
  of upstream's actual purpose as an image viewer, and it is entirely
  unported.
