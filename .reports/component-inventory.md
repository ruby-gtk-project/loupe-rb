# Loupe-rb component inventory

Upstream read at `origin/main` (GNOME Loupe, Rust/gtk-rs + GtkBuilder `.ui`),
compared against this fork's `ruby` branch `lib/`. Built with the
`component-identification` skill: upstream's `.ui` template roots are the
component boundary, unioned with the `.rs` file(s) that implement each
template's behaviour.

Kind legend: **window**, **dialog**, **page** (stack/view-stack child),
**widget** (reusable, non-window), **custom-widget** (no `.ui`, built in code),
**module** (non-widget support: app bootstrap, config, settings, i18n, data
model), **data** (GSettings schema, desktop/metainfo/service file, CSS,
icons, help/po catalogues).

## Components that exist on `ruby`

| Upstream file(s) | `lib/*.rb` | Kind | Status |
|---|---|---|---|
| `src/widgets/window.rs` + `src/widgets/window.ui` | `lib/loupe/window.rb` | window | **Present, but stubbed inside.** Builds the outer `AdwApplicationWindow`, toast overlay, view stack, breakpoints and the two `win.*` error actions. Its two stack pages (`image_page`, `edit_page`) are bare `Adwaita::Bin.new` placeholders — the real children (`LpImageWindow`, `LpEditWindow`) are never built, so nothing upstream puts inside those bins exists yet. |
| `src/widgets/error_details.rs` + `.ui` | `lib/loupe/error_details.rb` | dialog | Present |
| `src/widgets/drag_overlay.rs` + `.ui` | `lib/loupe/drag_overlay.rb` | widget | Present |
| `data/resources/shortcuts-dialog.ui` | `lib/loupe/shortcuts_dialog.rb` | dialog | Present |
| `src/about.rs` | `lib/loupe/about.rb` | dialog | Present |
| `src/application.rs` | `lib/loupe/application.rb` | module | Present |
| `src/config.rs` | `lib/loupe/config.rb` | module | Present |
| `src/file_model.rs` | `lib/loupe/file_model.rb` | module (data model) | Present |
| `src/metadata.rs` + `src/metadata/file.rs` | `lib/loupe/metadata/file.rb` | module (data model) | Present (`src/metadata.rs`'s own content, if any beyond re-exporting `file.rs`, needs re-checking against this file) |
| `src/util.rs` | `lib/loupe/util.rb` | module | Present |
| `src/util/gettext.rs` | `lib/loupe/util/gettext.rb` | module | Present |
| `src/util/root.rs` | `lib/loupe/util/root.rb` | module | Present |
| `src/lib.rs` | `lib/loupe.rb` | module | Present |
| `data/org.gnome.Loupe.gschema.xml.in` | `lib/loupe/settings.rb` | data (settings) | Present, reimplemented as a JSON file instead of GSettings (documented in the file's own header as a deliberate runtime-dependency workaround, not a parity gap in the key/value semantics) |
| `data/resources/style.css`, `edit.css`, `edit_crop.css`, `data/resources/icons/**` | `lib/loupe/style.rb` + `data/resources/*.css` | data (styling) | Present |

## Components missing entirely from `ruby`

These upstream files contribute a user-facing component with **no** matching
`lib/*.rb` anywhere in the port. This is the large majority of the app —
everything the user actually came to Loupe to do (view, zoom, pan, rotate,
crop, print, inspect metadata) lives here.

| Upstream file(s) | Proposed `lib/*.rb` | Kind | Status |
|---|---|---|---|
| `src/widgets/image_window.rs` + `.ui` + `src/widgets/image_window/actions.rs` + `src/widgets/image_window/controls.rs` | `lib/loupe/image_window.rb` | window/page | **Missing.** The page that actually hosts the viewer: zoom controls overlay, header bar, properties bottom-sheet toggle, and the `win.*`/`image-window.*` actions (zoom in/out/reset, rotate, flip, properties, print, save, etc). `window.rb`'s `image_page` bin is empty where this should be mounted. |
| `src/widgets/image_page.rs` + `.ui` | `lib/loupe/image_page.rb` | page | **Missing.** Per-file page wrapper around the image view inside the sliding/paging view (prev/next image navigation). |
| `src/widgets/image_view.rs` + `.ui` | `lib/loupe/image_view.rb` | widget | **Missing.** The scrollable/zoomable viewport chrome around the actual rendered image. |
| `src/widgets/image.rs` + `src/widgets/image/background_color.rs` + `drag.rs` + `editing.rs` + `input_handling.rs` + `loading.rs` + `metadata.rs` + `pan.rs` + `printing.rs` + `rendering.rs` + `rotation.rs` + `scrollable.rs` + `zoom.rs` | `lib/loupe/image.rb` | custom-widget | **Missing — this is the core image widget.** Custom-drawn widget with no `.ui` (GL/Cairo rendering), covering: checkerboard/solid background behind transparent images, pointer-drag panning, gesture/keyboard zoom, rotation, drag-and-drop of the image out of the app, printing hookup, and reading embedded metadata for display. None of this exists in the port; it is the single biggest gap. |
| `src/widgets/edit.rs` | `lib/loupe/edit.rb` | module/widget | **Missing.** The editing-mode coordinator referenced by `edit_window.rs`. |
| `src/widgets/edit_window.rs` + `.ui` | `lib/loupe/edit_window.rb` | window/page | **Missing.** `window.rb`'s `edit_page` is an empty bin; nothing builds `LpEditWindow` into it, so entering edit mode is a dead end in the port. |
| `src/widgets/edit/crop.rs` + `.ui` | `lib/loupe/edit/crop.rb` | widget | **Missing.** Crop tool: aspect-ratio presets, orientation toggle, apply/reset. |
| `src/widgets/edit/crop_selection.rs` + `.ui` (template parent `GtkWidget`) | `lib/loupe/edit/crop_selection.rb` | custom-widget | **Missing.** The draggable crop-rectangle overlay itself (custom `Gtk.Widget`, not a composite template over a real parent). |
| `src/widgets/properties_view.rs` + `.ui` | `lib/loupe/properties_view.rb` | widget | **Missing.** The metadata/properties sidebar (`show-properties` toggled by `settings.rb`'s only key, but the sidebar it's meant to show/hide has not been built). |
| `src/widgets/print.rs` + `.ui` | `lib/loupe/print.rb` | window/dialog | **Missing.** Print dialog/flow. |
| `src/widgets/print_preview.rs` | `lib/loupe/print_preview.rb` | widget | **Missing.** Print preview rendering, paired with `print.rs`. |
| `src/widgets/shy_bin.rs` | `lib/loupe/shy_bin.rb` | custom-widget | **Missing.** Custom bin that hides/shows a child (used to auto-hide the scrollbars/controls); no `.ui`, built in code. |
| `src/widgets/sliding_view.rs` | `lib/loupe/sliding_view.rb` | custom-widget | **Missing.** Custom animated swipe/slide transition container used for next/previous image navigation; no `.ui`. |
| `src/decoder.rs` + `src/decoder/formats.rs` + `src/decoder/formats/glycin_proxy.rs` + `src/decoder/formats/svg.rs` + `src/decoder/tiling.rs` | `lib/loupe/decoder.rb` (+ `lib/loupe/decoder/*.rb`) | module (data/loading) | **Missing.** Not a widget, but the image-loading/decoding pipeline every viewer widget above depends on (glycin-backed format decoding, SVG handling, large-image tiling). Without this, `image.rb` has nothing to render even once it exists. |
| `src/editing.rs` + `src/editing/preview.rs` | `lib/loupe/editing.rb` | module | **Missing.** The non-widget editing/save pipeline (apply crop/rotation, write out edited file, live preview) that `edit.rs`/`edit_window.rs` drive. |
| `src/main.rs` | `exe/loupe` (entrypoint) | module | Needs verification — `exe/loupe` exists; confirm it mirrors `main.rs`'s startup sequence (not reviewed line-by-line in this pass). |

## Non-widget assets with no port-side counterpart found

| Upstream | Kind | Status |
|---|---|---|
| `data/org.gnome.Loupe.desktop.in.in` | data (desktop entry) | No equivalent found under `data/` on `ruby`. |
| `data/org.gnome.Loupe.metainfo.xml.in.in` | data (AppStream metadata) | No equivalent found. Notable given this fork is required to wire in the `appstream` gem — there is no metainfo file yet for it to read. |
| `data/org.gnome.Loupe.service.in` | data (D-Bus service file) | No equivalent found. |
| `data/icons/**` (app icons, hicolor + symbolic) | data (icons) | Only the in-app action icons under `data/resources/icons` were checked for; the app/launcher icon set (`data/icons/hicolor/...`, `org.gnome.Loupe.Source.svg`) was not found under `ruby`'s `data/`. |
| `po/*.po` (62 locales) + `po/LINGUAS` + `po/POTFILES.in` | data (translation catalogue) | No `po/` directory exists on `ruby`. Translation parity has not been established (separate from this survey; flagged here because it's visible in the file listing). |
| `help/**` (Mallard help pages + `help/*/*.po`) | data (user documentation) | No `help/` directory exists on `ruby`. |

## Summary

- **14** upstream components/modules have a corresponding `lib/*.rb` file on `ruby`, though one of those (`window.rb`) only builds the shell and leaves its two content slots empty.
- **18** upstream components/modules — including the entire image-viewing widget, the entire editing/crop subsystem, printing, properties sidebar, and the decoder pipeline underneath all of them — have no `lib/*.rb` counterpart at all.
- **5** non-code upstream assets (desktop file, metainfo, D-Bus service file, app icon set, po/help trees) have no counterpart under `ruby` at all.
- This component-identification pass intentionally stops at "does a file exist and what should be in it" — it does not verify widget-by-widget/signal-by-signal parity for the files marked Present; that is the follow-up `component-parity` pass.
