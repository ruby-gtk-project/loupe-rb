# loupe — upstream component inventory

Survey of `origin/main` (Rust / gtk-rs + GtkBuilder `.ui`) against `lib/` on the
`ruby` branch, for the full-parity Ruby GTK4 / Libadwaita port.

Method: the `component-identification` skill. The declarative UI was read first
(11 `.ui` files, 3 of them menu-bearing), then the Rust sources that back them
for the parts no `.ui` can show — actions, accelerators, runtime dialogs, toasts
and dynamic CSS. Upstream splits most components across a `.rs` and a `.ui` of
the same name, and splits `image_window` and `image` further across an `impl`
directory; those halves are unioned into one port component below.

## Totals

| | upstream | `ruby` branch |
|---|---:|---:|
| Source files contributing UI | 42 `.rs` + 11 `.ui` | 2 `.rb` |
| Template roots (components) | 12 `<template>` + 1 standalone `<object>` | 0 |
| Menu models | 3 (`primary_menu`, `image_menu`, `aspect_ratio_menu`) | 0 |
| Action groups | `app.`, `win.`, `properties.`, `print.`, `edit.`, `edit-crop.` | 0 |
| Distinct actions | 46 | 0 |
| GSettings keys | 1 (`show-properties`) | 0 |
| Stylesheets | 3 (`style.css`, `edit.css`, `edit_crop.css`), 38 rules | 0 |
| Translations | 58 locales in `po/`, 24 in `help/` | 0 |

The `ruby` branch holds `lib/loupe.rb` and `lib/loupe/application.rb`, and
`application.rb` is the scaffold stub: a `Gtk::Application`, an
`Adwaita::ApplicationWindow` 800×600 titled "loupe", an `Adwaita::ToolbarView`
with a bare `Adwaita::HeaderBar`, and an `Adwaita::StatusPage` reading "The Ruby
port has not been written yet." **No upstream component is ported.** Every row
below is `present: no`; `application.rb` exists as a file but holds none of the
upstream application component.

Port paths follow the existing gem layout on `ruby` (`lib/loupe/<thing>.rb`),
not the pilot's flat `lib/<thing>.rb` — `lib/loupe.rb` and
`lib/loupe/application.rb` already set that shape.

---

## Components, in the order a user meets them

### src/application.rs → `lib/loupe/application.rb` — application

| Facet | Detail |
|---|---|
| Type | `Adw.Application` subclass (`LpApplication`), app-id `org.gnome.Loupe`, flags `HANDLES_OPEN`, resource base `/org/gnome/Loupe` |
| Actions | `app.help` (launches `help:loupe`), `app.quit` (closes all windows), `app.new-window` |
| Accels | `app.help` F1 · `app.quit` <Ctrl>Q · `window.close` <Ctrl>W · `app.new-window` <Ctrl>N |
| Behaviour | `startup` forces `ColorScheme::PreferDark` and sets the default window icon; `activate` presents a new `LpWindow`; `open` presents one and feeds it the files |
| Owner of | `gio::Settings` for the app id (see GSettings row) |

Also in this unit: `app.shortcuts` is referenced by the primary menu and bound
to <Ctrl>? in `window.rs`, but it is **installed nowhere in the Rust source** —
the shortcuts dialog is a resource-only component (below), so the port must
install `app.shortcuts` itself.

Present: no (stub file of the same name exists).

### src/widgets/window.rs + src/widgets/window.ui → `lib/loupe/window.rb` — the window

| Widget | × | CSS | Signals / bindings | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (`LpWindow`) | 1 | `devel` (only when APP_ID ends `.Devel`) | `close-request` → `ensure_saved` then destroy; `map` → `resize_default` | 600×498 default, 360×294 minimum; own `Gtk.WindowGroup`; presents itself after a 2000 ms timeout if still hidden |
| `Adw.Breakpoint` | 2 | — | setters on `layout-name` / `narrow-layout` | `min-width: 590sp` → wide, `max-width: 590sp` → narrow |
| `Adw.ToastOverlay` | 1 | — | `add_toast` | every toast in the app lands here |
| `Adw.ViewStack` | 1 | — | `enable-transitions` | children: `LpImageWindow`, and an `Adw.Bin` that holds `LpEditWindow` on demand |
| `Adw.Bin` (`edit_window_child`) | 1 | — | — | `LpEditWindow` is built lazily into it by `show_edit` |

Properties: `narrow-layout`, `wide-layout`, `layout-name`, `not-fullscreened`
(the last two are consumed by `image_window.ui` and `crop.ui` through
`<lookup>`; `wide-layout` and `not-fullscreened` are inverted bindings).

Actions: `win.show-error` and `win.show-loader-error`, both taking a string
target (the detail text). Key bindings: <Ctrl>C → copy image unless metadata
text is selected (then it proceeds to the text selection), <Ctrl>? →
`app.shortcuts`.

Toast / error plumbing the port must reproduce: `show_toast(text, priority)`,
and `show_error(stub, details, type)` which builds an `Adw.Toast` with
priority High and a "Show Details" button targeting `win.show-error` or
`win.show-loader-error`.

Present: no.

### src/widgets/image_window.ui (menu `primary_menu`) → part of `lib/loupe/image_window.rb` — main menu

5 sections, 11 items: `app.new-window` "_New Window" · `win.open` "_Open…" |
`win.open-with` "_Open With…" · `win.print` "_Print…" | a `inline-buttons`
"Rotate" section with two `custom:` slots (`rotate-left`, `rotate-right`) |
`win.set-background` "_Set as Background…" · `win.trash` "_Delete" |
`app.help` "_Help" · `app.shortcuts` "_Keyboard Shortcuts" · `win.about`
"_About Image Viewer".

The two `custom:` slots are component boundaries: each hosts a `Gtk.Button`
(`object-rotate-left-symbolic` / `object-rotate-right-symbolic`, `flat`,
`win.rotate-ccw` / `win.rotate-cw`).

Present: no.

### src/widgets/image_window.rs + .ui → `lib/loupe/image_window.rb` — the viewer shell

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (`LpImageWindow`) | 1 | — | `root` wires everything to the `LpWindow` | |
| `Adw.ToolbarView` | 1 | — | — | top bar + content |
| `Gtk.ShortcutController` | 1 | — | — | scope `global`; receives 30-odd `Gtk.Shortcut`s built from `actions.rs` |
| `LpShyBin` | 1 | — | — | wraps the header bar so it never claims natural width |
| `Adw.HeaderBar` | 1 | `fullscreen-osd` | start/end title buttons bound to `LpWindow.not-fullscreened` | opacity animated in fullscreen |
| `Gtk.Button` (fullscreen) | 1 | — | `win.toggle-fullscreen` | "Toggle Fullscreen" |
| `Gtk.MenuButton` (primary) | 1 | — | `primary`, `open-menu-symbolic` | hosts `primary_menu` in a `Gtk.PopoverMenu` |
| `Gtk.ToggleButton` (properties) | 1 | — | `active` ↔ split view / revealer, bidirectional | `info-outline-symbolic`, "Image Properties" |
| `Gtk.Button` (edit) | 1 | — | `win.edit` | `crop-symbolic`, "Edit Image" |
| `Gtk.EventControllerMotion` | 1 | — | `contains_pointer` gates control hiding | on the header bar |
| `Adw.MultiLayoutView` | 1 | — | `layout-name` from `LpWindow` | |
| `Adw.Layout` "wide" → `Adw.OverlaySplitView` | 1 | — | `show-sidebar` ↔ properties button | sidebar at end, min 255 |
| `Adw.Layout` "narrow" → `Gtk.Box` + `Gtk.Revealer` | 1 | `bottom-properties` | `reveal-child` ↔ properties button | slide-up |
| `Adw.LayoutSlot` | 4 | — | — | `properties` ×2, `content` ×2 |
| `LpDragOverlay` | 1 | — | `drop_target` | |
| `Gtk.Stack` | 1 | `drop-widget` (`:drop(active)` styled) | `visible-child` switched between status page and image view | |
| `Gtk.DropTarget` | 1 | — | `copy` action | |
| `Adw.StatusPage` (empty state) | 1 | — | — | "View and Edit Images" / "Drag and drop images here" |
| `Gtk.Button` (empty state) | 1 | `pill`, `suggested-action` | `win.open` | "_Open Files…" |
| `LpImageView` | 1 | — | — | |
| `Gtk.GestureClick` | 3 | — | button 9 → forward, button 8 → back, plain → `on_click` | |

Runtime dialogs and toasts owned by this file (none of them in any `.ui`):

| What | Shape | Strings |
|---|---|---|
| Open | `Gtk.FileDialog` + `Gio.ListStore` of 2 `Gtk.FileFilter` | "Open Image", "Supported image formats", "All files" |
| Open With | portal / `Gtk.FileLauncher` path | — |
| Set as background | portal wallpaper request | "Set as background.", "Could not set background." (toasts, in `image_view.rs`) |
| Copy | clipboard | "Image copied to clipboard" (High) |
| Trash | toast with Undo button that restores from trash | "Image moved to trash" (High, Undo), "Failed to restore image from trash" (High), "Failed to move image to trash" (Normal) |
| Permanent delete | `Adw.AlertDialog`, responses `cancel` / `delete` (destructive) | "Permanently Delete Image?", body interpolates the filename, "Cancel", "Delete", "Failed to delete image" (Normal) |
| Title | window title falls back to "Image Viewer" | |

Present: no.

### src/widgets/image_window/actions.rs → `lib/loupe/image_window_actions.rb` — the `win.` action set

29 actions, each installed on the `LpImageWindow` class and most of them also
given a `Gtk.Shortcut` on the window's global shortcut controller:

`win.image-left` · `win.image-right` (both direction-aware) · `win.previous` ·
`win.next` · `win.first` (Home) · `win.last` (End) · `win.rotate-cw`
(<Ctrl>R) · `win.rotate-ccw` (<Ctrl><Shift>R) · `win.zoom-out-center` ·
`win.zoom-in-center` · `win.zoom-out-cursor` (minus, <Ctrl>minus, KP_Subtract,
<Ctrl>KP_Subtract) · `win.zoom-in-cursor` (equal, plus, KP_Add, each also with
<Ctrl>) · `win.zoom-best-fit` (0, <Ctrl>0, KP_0, <Ctrl>KP_0) ·
`win.zoom-to-exact-100` (1 / <Ctrl>1 / KP_1 / <Ctrl>KP_1) ·
`win.zoom-to-exact-200` (2 …) · `win.zoom-to-exact-300` (3 …) · `win.open`
(<Ctrl>O) · `win.open-with` (<Ctrl><Shift>O) · `win.print` (<Ctrl>P) ·
`win.copy-image` · `win.set-background` (<Ctrl>F8) ·
`win.toggle-fullscreen` (F11) · `win.leave-fullscreen` (Escape) · `win.trash`
(Delete, KP_Delete) · `win.delete` (<Shift>Delete, <Shift>KP_Delete) ·
`win.toggle-properties` (F9, <Alt>Return) · `win.about` · `win.reload` (F5) ·
`win.edit` (E).

Plus the six **window-level** actions from `window.rs`, which carry app accels
that are added and removed as focus moves: `win.image-left-instant`
(Left, Page_Down) · `win.image-right-instant` (Right, Page_Up) ·
`win.pan-up` (<Ctrl>Up) · `win.pan-right` (<Ctrl>Right) · `win.pan-down`
(<Ctrl>Down) · `win.pan-left` (<Ctrl>Left).

Actions are disabled per state: `update_image_actions_status` turns the image
actions off on the empty page and on the error page, and editing disables the
trash option.

Present: no.

### src/widgets/image_window/controls.rs → `lib/loupe/image_window_controls.rb` — OSD auto-hide

Not widgets: two `Adw.TimedAnimation`s over `Adw.CallbackAnimationTarget`
driving the opacity of `controls_box_start`, `controls_box_end` and (in
fullscreen, flat header only) the header bar, plus a `glib.timeout` that hides
them after an idle period and a `gdk::Cursor::from_name("none")` that hides the
pointer in fullscreen. Hiding is suppressed while the pointer is over either
control box or the hideable header bar, or while the primary menu or the zoom
menu is open. Behaviour, so it belongs on the signal axis of the header bar and
the two OSD boxes, never in the widget count.

Present: no.

### src/widgets/properties_view.rs + .ui → `lib/loupe/properties_view.rb` — properties sidebar / bottom sheet

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (`LpPropertiesView`) | 1 | — | tracks the current image through a signal group | |
| `Gtk.ScrolledWindow` | 1 | — | — | natural height propagated, max 316 |
| `Gtk.Box` | 1 | — | — | vertical, spacing 24 |
| `Adw.PreferencesGroup` | 4 | — | — | file · size/format · `dates` · `details` (last two hidden when empty) |
| `Adw.ActionRow` | 22 | `property` on all; `numeric` additionally on `location` | `subtitle-selectable` on all but `folder` | Folder, URI, Image Size, Physical Size, Resolution, Image Format, File Size, File Created, File Modified, Location, Originally Created, Creator, Copyright, Comment, Aperture, Exposure, ISO, Focal Length, Maker Model, Lens, Software, ICC Profile, CICP |
| `Gtk.Button` | 3 | `flat` | `properties.open-folder`, `properties.copy-location`, `properties.open-location` | "Open Containing Folder", "Copy Coordinates", "Open Location" |

Actions: `properties.open-folder` (async, via portal), `properties.copy-location`,
`properties.open-location`. Dynamic strings the port must reproduce: the format
row composes "Unknown", ", transparent", ", grayscale", ", {} bit"; units
are " cm", "″", " m", " mm", " pc", " pt",
"{} DPI".

Present: no.

### src/widgets/image_view.rs + .ui → `lib/loupe/image_view.rb` — the image view and its OSD

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (`LpImageView`) | 1 | `image-view`; `always-show-scrollbars` added/removed dynamically | css-name `imageview`, focusable | |
| `Gtk.Overlay` | 1 | — | — | |
| `LpSlidingView` | 1 | — | `current-page`, `target-page-reached` | |
| `Gtk.Box` (`controls_box_start`) | 1 | `osd-box` | — | bottom-start |
| `Gtk.Button` prev / next | 2 | `flat` | `win.previous`, `win.next` | "Previous Image", "Next Image" |
| `Gtk.Box` (`controls_box_end`) | 1 | `osd-box` | — | bottom-end |
| `Gtk.Revealer` | 1 | — | `reveal-child` ← `zoom-toggle-state` | slide-left |
| `Gtk.Button` zoom out / in | 2 | `flat` | `win.zoom-out-center`, `win.zoom-in-center` | `minus-large-symbolic`, `plus-large-symbolic` |
| `Gtk.ToggleButton` (`zoom_toggle`) | 1 | `flat` | `clicked`; `active` ↔ `zoom-toggle-state` | `zoom-toggle-symbolic`, "Toggle Zoom" |
| `Gtk.MenuButton` (`zoom_menu_button`) | 1 | `flat` | `active` gates control hiding | direction up, "Zoom to Specific Level" |
| `Gtk.Popover` (zoom) | 1 | `menu` | default widget `submit_zoom` | hand-built, not a `PopoverMenu`, deliberately |
| `Gtk.ListBox` (`zoom_to_list`) | 1 | — | `row-activated` | |
| `Gtk.ListBoxRow` | 5 | — | — | 300 % / 200 % / 100 % (each with a dim-label accel hint Ctrl+3/2/1) / 66 % / 50 % |
| `Gtk.Label` | 8 | `dim-label` on the 3 accel hints | — | |
| `Gtk.Entry` (`zoom_value`) | 1 | — | `insert-text` filtered to digits, `changed` | "Custom Zoom Level", input purpose number, max 8 chars |
| `Gtk.Button` (`submit_zoom`) | 1 | `circular`, `suggested-action` (added/removed on validity) | `clicked` | `check-plain-symbolic` |
| `Gtk.EventControllerMotion` | 2 | — | `contains_pointer` | one per OSD box |
| `Gtk.DragSource` | 1 | — | `prepare`, `drag-begin` | drag icon gets `drag-icon` |

Zoom entry shows "{} %". Set-as-background toasts live here ("Set as
background.", "Could not set background.").

Present: no.

### src/widgets/sliding_view.rs → `lib/loupe/sliding_view.rb` — the swipeable page carousel

Custom `Gtk.Widget` with a hand-written `measure`/`size_allocate`, an
`Adw.SwipeTracker` (`begin-swipe`, `update-swipe`, `end-swipe`), a
`Gtk.EventControllerScroll` (`scroll`), `Adw.SpringAnimation`/`TimedAnimation`
for the slide, a `target-page-reached` custom signal, and a `PositionTracking`
enum. Holds the `LpImagePage` repeater: **one component, N instances**, driven
by the `LpFileModel` list. Not a container the port gets for free — nothing in
GTK does this.

Present: no.

### src/widgets/image_page.ui (menu `image_menu`) → part of `lib/loupe/image_page.rb` — image context menu

3 sections, 6 items: `win.open-with` · `win.print` | `inline-buttons` "Rotate"
with `rotate-left` / `rotate-right` custom slots (same two `flat` buttons as the
primary menu) | `win.set-background` · `win.trash` · `win.copy-image` "_Copy".

Present: no.

### src/widgets/image_page.rs + .ui → `lib/loupe/image_page.rb` — one page: spinner, error, image

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (`LpImagePage`) | 1 | — | — | hexpand/vexpand |
| `Gtk.Stack` | 1 | — | `visible-child` | crossfade; 3 pages |
| `Adw.Bin` + `Gtk.Revealer` + `Adw.Spinner` | 1 each | — | `map` on the revealer starts a delay | loading state: spinner only after a delay |
| `Adw.StatusPage` (`error_page`) | 1 | — | — | `image-missing-symbolic`, "Could not Load Image"; description composed at runtime |
| `Gtk.Button` (`error_more_info`) | 1 | `suggested-action`, `pill` | `clicked` → error details dialog | "More _Information" |
| `Gtk.Button` (reload) | 1 | `pill` | `win.reload` | "_Reload" |
| `Gtk.Box` + `Gtk.ScrolledWindow` | 1 each | — | — | natural width and height propagated |
| `LpImage` | 1 | — | — | |
| `Gtk.GestureClick` | 1 | — | button 3 → popover | |
| `Gtk.GestureLongPress` | 1 | — | touch-only → popover | |
| `Gtk.PopoverMenu` (`popover`) | 1 | — | `image_menu` | no arrow, halign start |

Error-state strings assembled here: "There is not enough free memory available
to load this image.", "Failed to load image file: {}", plus format- and
glycin-specific variants.

Present: no.

### src/widgets/image.rs + src/widgets/image/*.rs (12 files) → `lib/loupe/image.rb` + `lib/loupe/image/*.rb` — the image widget

The app's core custom widget: a `Gtk.Widget` subclass implementing
`Gtk.Scrollable`, with its own snapshot/render path. Split upstream into
`background_color.rs`, `drag.rs`, `editing.rs`, `input_handling.rs`,
`loading.rs`, `metadata.rs`, `pan.rs`, `printing.rs`, `rendering.rs`,
`rotation.rs`, `scrollable.rs`, `zoom.rs` — one port file each, mixed into
`Loupe::Image`. Behaviour, not widget tree: zoom levels and limits, best-fit,
pan, rotation convention, drag-to-pan, tiled rendering via `gsk`, animation
playback, and the properties feed. The single largest unit in the port and the
one with no declarative half at all.

Present: no.

### src/widgets/drag_overlay.rs + .ui → `lib/loupe/drag_overlay.rb` — drop target overlay

`Adw.Bin` (css-name `lpdragoverlay`) → `Gtk.Overlay` → `Gtk.Revealer`
(crossfade, `can-target false`) → `Adw.Bin` `background` → `Adw.StatusPage`
`overlay-status`, "Drop Image to View", `image-round-symbolic`. Reveals on the
bound `Gtk.DropTarget`'s `current-drop` notify. Properties: `content`,
`drop-target` (construct-only).

Present: no.

### src/widgets/shy_bin.rs → `lib/loupe/shy_bin.rb` — header-bar bin

`Adw.Bin` subclass with no layout manager, hexpand, whose `measure` reports its
natural width as its minimum so the header bar cannot widen the window, and
whose `size_allocate` hands the full allocation to its child. No `.ui`. Needs
`ensure_type` at startup because the template references it by name.

Present: no.

### src/widgets/error_details.rs + .ui → `lib/loupe/error_details.rb` — error details dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (`LpErrorDetails`) | 1 | `error-details` | — | "Error Details", 550×600 |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | — | |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 2 | — | — | first carries the loader description; `ErrorType::General` swaps in a different description at runtime |
| `Gtk.Button` (`copy`) | 1 | `flat` | `clicked` → clipboard | "Copy Error Message", `edit-copy-symbolic` |
| `Gtk.ScrolledWindow` | 1 | `card` | — | overflow hidden |
| `Gtk.TextView` (`message`) | 1 | `error-message`, `monospace` | — | non-editable, word-char wrap |
| `Gtk.Button` (`report`) + `Adw.ButtonContent` | 1 each | `suggested-action`, `pill` | `clicked` → `Gtk.UriLauncher` | "Report _Issue", `external-link-symbolic`; URI differs for loader vs general errors |

Present: no.

### data/resources/shortcuts-dialog.ui → `lib/loupe/shortcuts_dialog.rb` — keyboard shortcuts dialog

A standalone `<object>` root, not a `<template>`, and backed by no Rust file —
it is loaded from GResource by `app.shortcuts`, which the port must install.
`Adw.ShortcutsDialog` with 7 `Adw.ShortcutsSection`s and 46
`Adw.ShortcutsItem`s:

- **General Shortcuts** (10): Copy Image or Selected Text to Clipboard <Ctrl>C · Move Image to Trash Delete · Permanently Delete Image <Shift>Delete · Open Image with Other App <Ctrl><Shift>O · Set as Background <Ctrl>F8 · New Window (`app.new-window`) · Open Help (`app.help`) · Show Keyboard Shortcuts (`app.shortcuts`) · Close Window (`window.close`) · Quit (`app.quit`)
- **Navigate Images** (6): Next / Previous Image, one pair per text direction (LTR Right/Left, RTL Left/Right) · First Image Home · Last Image End
- **Rotate Image** (2): Clockwise <Ctrl>R · Counterclockwise <Ctrl><Shift>R
- **Zoom Image** (5): Zoom In <Ctrl>plus plus · Zoom Out <Ctrl>minus minus · Best Fit <Ctrl>0 0 · Original Scale <Ctrl>1 1 · 200 % Scale <Ctrl>2 2
- **Pan View** (4): <Ctrl>Left / Right / Up / Down
- **View** (4): Toggle Fullscreen F11 · Leave Fullscreen Escape · Toggle Image Properties <Alt>Return F9 · Show Main Menu F10
- **Editing** (9): Open Editing View E · Replace Original <Ctrl>S · Save As <Ctrl><Shift>S · Cancel Escape · Rotate CW <Ctrl>R · Rotate CCW <Ctrl><Shift>R · Mirror Horizontally H · Mirror Vertically V · Apply Crop <Ctrl>Return

Every item string carries the `shortcut window` msgctxt.

Present: no.

### src/about.rs → `lib/loupe/about.rb` — about dialog

`Adw.AboutDialog` built in code: application name "Image Viewer", icon and
version from config, developer name "The GNOME Project", website
apps.gnome.org/Loupe/, issue and support URLs, 2 developers, 3 designers,
`translator-credits`, copyright string, GPL-3.0, and a `debug_info` blob
assembled from the version, app id, sandbox state and `/etc/os-release` (read
through `/run/host/etc` when sandboxed). Presented by `win.about`.

Present: no.

### src/widgets/print.rs + .ui → `lib/loupe/print.rb` — print window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Window` (`LpPrint`) | 1 | — | — | 900×650 |
| `Gtk.ShortcutController` + `Gtk.Shortcut` | 1 each | — | `Escape|<Ctrl>w` → `window.close` | scope managed |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | — | top-bar-style raised, no title buttons |
| `Adw.WindowTitle` (`title`) | 1 | — | — | title set at runtime from the file name |
| `Gtk.Button` back / print | 2 | `suggested-action` on print | `print.back`, `print.print` | "_Back", "_Print" |
| `Adw.OverlaySplitView` | 1 | — | — | |
| `Adw.PreferencesPage` | 1 | — | — | 300 wide |
| `Adw.PreferencesGroup` | 3 | — | — | "Layout", "Margins", "Image Size" |
| `Adw.ActionRow` | 1 | — | — | "_Orientation" |
| `Gtk.Box` | 1 | `linked` | — | |
| `Gtk.ToggleButton` | 2 | — | `print.orientation` with targets `"portrait"` / `"landscape"` | "Portrait Page Orientation", "Landscape Page Orientation" |
| `Adw.ComboRow` (`alignment`) | 1 | — | `selected` notify | "_Alignment"; `Gtk.StringList` center/top/bottom/left/right, relabelled at runtime to "Top"/"Center"/"Bottom"/"Left"/"Right" |
| `Gtk.DropDown` | 2 | `flat` | `selected` notify | "Margin Units" cm/in/px, "Image Size Units" cm/in/px/% |
| `Adw.SpinRow` | 4 | — | `value` notify | "_Horizontal", "_Vertical", width (title toggles between "_Width" and "_Scale"), "H_eight" |
| `Adw.SwitchRow` (`fill_space`) | 1 | — | `active` notify | "_Fill Space" |
| `LpPrintPreview` (`preview`) | 1 | — | `print` bound to the window | min 260×260 |

Also a `Gtk.FileDialog`-style print flow with accept label "Continue…" and
title "Print Image", and the unit strings "cm" / "in" / "px". Actions:
`print.print`, `print.back`, `print.orientation` (string target).

Present: no.

### src/widgets/print_preview.rs → `lib/loupe/print_preview.rb` — print preview

Custom widget, css-names `lpprintpreview` / `lpprintpreviewpage` (both styled in
`style.css`), drawing the page outline and the image at the chosen margins,
alignment and size. No `.ui`. Redraws on the parent `LpPrint`'s `image` notify.

Present: no.

### src/widgets/edit_window.rs + .ui → `lib/loupe/edit_window.rb` — editing view

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (`LpEditWindow`) | 1 | — | — | lives in `LpWindow`'s stack |
| `Gtk.ShortcutController` | 1 | — | — | scope global; edit accels |
| `Adw.ToolbarView` | 1 | — | — | top-bar-style raised |
| `Gtk.Overlay` | 1 | — | child bound to the `edit_crop` property | |
| `Gtk.Revealer` (`saving_revealer`) | 1 | — | `can-target` ← own `reveal-child` | crossfade 500 ms |
| `Adw.Bin` | 1 | `saving-overlay` | — | styled in `edit.css` |
| `Gtk.Revealer` (`saving_info`) | 1 | — | — | crossfade 500 ms |
| `Adw.Spinner` | 1 | — | — | 64×64 |
| `Gtk.Label` (`saving_status`) | 1 | `title-2` | — | runtime text: "Editing Image", "Saving Image", "Moving Original to Trash", "Finalizing Save Operation" |
| `Adw.HeaderBar` | 1 | — | — | no title buttons |
| `Gtk.Button` (`cancel`) | 1 | — | `edit.cancel` | "_Cancel" |
| `Gtk.MenuButton` (`save`) | 1 | `suggested-action` (styled via `menubutton.suggested-action button`) | sensitivity recomputed | "_Save" |
| `Gtk.Popover` | 1 | `menu` | — | |
| `Gtk.ListBox` | 1 | — | selection none | |
| `Gtk.ListBoxRow` | 2 | — | `edit.save-copy`, `edit.save-overwrite` | |
| `Gtk.Label` | 4 | `dimmed`+`caption` on the 2 subtitles | — | "_Save As…" / "Keep original and create a new file"; "_Replace Original" / "Original image will be moved to the trash" |

Actions: `edit.cancel`, `edit.save-copy`, `edit.save-overwrite`, all disabled
while a save is running. Runtime dialogs: a `Gtk.FileDialog` for Save As whose
suggested name appends " (Edited)" / " (Edited {})" (ngettext), and an
`Adw.AlertDialog` "Save Changes?" with responses cancel / discard / save, raised
from `ensure_saved` on close. Failure toasts: "Failed to save image.", "Failed
to edit image.", "Failed to Save Image".

Present: no.

### src/widgets/edit/crop.ui (menu `aspect_ratio_menu`) → part of `lib/loupe/edit_crop.rb` — aspect-ratio menu

2 sections: 7 items on `edit-crop.aspect-ratio` with targets free / original /
square / r5to4 / r4to3 / r3to2 / r16to9, labelled "Free", "Original", "Square",
"5:4", "4:3", "3:2", "16:9"; then a single `custom:orientation` slot holding two
`flat` `Gtk.ToggleButton`s on `edit-crop.orientation` ("Orientation Landscape",
"Orientation Portrait").

Present: no.

### src/widgets/edit/crop.rs + .ui → `lib/loupe/edit_crop.rb` — crop and transform view

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (`LpEditCrop`) | 1 | css-name `lpcrop` | — | |
| `Adw.ToolbarView` | 1 | — | `reveal-bottom-bars` ← `LpWindow.narrow-layout` | bottom-bar-style raised |
| `Adw.OverlaySplitView` | 1 | — | `show-sidebar` ← `LpWindow.wide-layout` | sidebar end, min 280 |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 4 | — | — | "Aspect Ratio", "Rotate", "Flip", and an untitled group for Reset |
| `Gtk.Grid` | 3 | — | — | aspect-ratio grid (2 cols × 4 rows), rotate, flip |
| `Gtk.ToggleButton` (aspect) | 7 | — | `edit-crop.aspect-ratio` with 7 targets | each wraps an `Adw.ButtonContent` |
| `Adw.ButtonContent` | 7 | `has-orientation` on the 4 ratio-bearing ones; `button-icons-portrait` added/removed on the grid at runtime | — | `aspect-ratio-*-symbolic` icons |
| `Gtk.ToggleButton` (orientation) | 4 | `flat` on the 2 in the menu | `edit-crop.orientation`, targets `'landscape'` / `'portrait'` | sidebar pair + menu pair |
| `Gtk.Button` rotate | 3 | — | `edit-crop.rotate-ccw` ×2, `edit-crop.rotate-cw` ×1 | "Rotate Counter Clockwise", "Rotate Clockwise" |
| `Gtk.Button` mirror | 3 | — | `edit-crop.mirror-horizontally` ×2, `edit-crop.mirror-vertically` ×1 | |
| `Gtk.Button` reset | 2 | `flat` | `edit-crop.reset` | "_Reset", "Undo Changes in this View" |
| `Gtk.Overlay` | 1 | — | — | 18 px margins |
| `LpImage` (`image`) | 1 | — | insensitive | |
| `LpEditCropSelection` (`selection`) | 1 | — | `cropped` / `orientation` notify | |
| `Adw.Clamp` + `Gtk.Box` | 1 + 4 | `toolbar` on the inner box | — | narrow-mode bottom bar; `Gtk.SizeGroup` ties `box-start` and `box-end` |
| `Gtk.MenuButton` + `Gtk.PopoverMenu` | 1 each | — | `aspect_ratio_menu` | `aspect-ratio-symbolic`, direction up |

Actions: `edit-crop.mirror-horizontally`, `edit-crop.mirror-vertically`,
`edit-crop.rotate-cw`, `edit-crop.rotate-ccw`, `edit-crop.reset`,
`edit-crop.apply-crop`, plus two `Gio.PropertyAction`s —
`edit-crop.aspect-ratio` and `edit-crop.orientation` — in a
`Gio.SimpleActionGroup` on the widget. Enums to port: `LpAspectRatio` (7
values), `LpOrientation`. Failure toast: "Failed to Edit Image".

Present: no.

### src/widgets/edit/crop_selection.rs + .ui → `lib/loupe/edit_crop_selection.rb` — crop selection handles

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Widget` (`LpEditCropSelection`) | 1 | — | hand-written measure / allocate | parent is `GtkWidget`, not a bin |
| `Gtk.GestureDrag` (`selection_move`) | 1 | — | `drag-begin`, `drag-update`, `drag-end` | moves / resizes the selection |
| `Adw.Bin` (space) | 4 | `discarded-area` | — | top / right / bottom / left dimming |
| `Gtk.Overlay` (`selection_overlay`) | 1 | — | — | |
| `Gtk.Button` (`apply_button`) | 1 | `circular`, `osd`, `apply-button` | `edit-crop.apply-crop` | `apply-crop` icon, "Crop Selection" |
| `Gtk.GestureClick` (`apply_button_click`) | 1 | — | `begin`, `released` | works around a gesture bug |
| `Gtk.Grid` (`selection`) | 1 | `selection` | — | 3×3 |
| `Adw.Bin` (handles) | 8 | `handle` on the 4 corners; plus `handle-top-left`, `handle-top`, `handle-top-right`, `handle-right`, `handle-bottom-right`, `handle-bottom`, `handle-bottom-left`, `handle-left` | — | all 13 classes defined in `edit_crop.css` |

Enums to port: `RectHandle`, `HEdge`, `VEdge`.

Present: no.

---

## Supporting units (no widgets, but the components above do not work without them)

| Upstream | Port path | Kind | Present |
|---|---|---|---|
| `src/lib.rs`, `src/main.rs` | `lib/loupe.rb`, `exe/loupe` | entry point: gettext bind, resource register, run | partial (`lib/loupe.rb` exists, requires only `application`) |
| `src/config.rs` | `lib/loupe/config.rb` | app id, version, localedir | no |
| `data/org.gnome.Loupe.gschema.xml.in` | `lib/loupe/settings.rb` | GSettings: one key, `show-properties` (b, false) | no |
| `src/file_model.rs` | `lib/loupe/file_model.rb` | the image list, Nautilus sort order, directory enumeration | no |
| `src/metadata.rs`, `src/metadata/file.rs` | `lib/loupe/metadata.rb`, `lib/loupe/metadata/file.rb` | EXIF / XMP / ICC / CICP feed for the properties view | no |
| `src/decoder.rs`, `decoder/formats.rs`, `formats/glycin_proxy.rs`, `formats/svg.rs`, `decoder/tiling.rs` | `lib/loupe/decoder*.rb` | glycin-backed loading and tiling | no |
| `src/editing.rs`, `src/editing/preview.rs` | `lib/loupe/editing.rb`, `lib/loupe/editing/preview.rb` | the edit operation queue and its preview | no |
| `src/util.rs`, `util/gettext.rs`, `util/root.rs` | `lib/loupe/util.rb` + siblings | `Direction`, `Position`, `ErrorType`, `gettext_f`, `ParentWindow` | no |
| `src/widgets.rs`, `src/widgets/edit.rs` | — | Rust module re-exports; no port file needed | n/a |
| `data/resources/style.css`, `edit.css`, `edit_crop.css` | `lib/loupe/style.rb` + 3 css files | 38 rules; the port must load them through a `Gtk::CssProvider` | no |
| `data/resources/icons/scalable/actions/*.svg` (22) | app resource dir | custom symbolic icons the UI names directly (`apply-crop`, `aspect-ratio-*`, `check-plain`, `crop`, `edit-mirror-*`, `external-link`, `image-round`, `info-outline`, `minus-large`, `page-orientation-*`, `plus-large`, `zoom-toggle`) | no |
| `data/icons/hicolor/**`, `org.gnome.Loupe.Source.svg` | app icons | app icon, devel icon, symbolic | no |
| `data/org.gnome.Loupe.desktop.in.in` | desktop file | 41 MIME types | no |
| `data/org.gnome.Loupe.metainfo.xml.in.in` | appstream | | no |
| `po/` (58 locales), `help/` (24 locales + 7 pages) | `po/`, `help/` | translation and help parity | no |

## Notes for whoever ports next

- **Nothing is ported.** `lib/loupe/application.rb` is the scaffold; it holds a status page, not the application component. The first unit to take is `src/application.rs` + `src/widgets/window.rs` + `src/widgets/window.ui` together, because `LpWindow`'s four layout properties are what every other template looks up.
- **The `.ui` files are the better spec** for 12 of the 13 components, but three things live only in Rust and are easy to lose: the 46-action table with its accelerators (`image_window/actions.rs`, `window.rs`, `application.rs`), the seven runtime dialogs and eleven toasts, and the OSD auto-hide animation.
- **`app.shortcuts` is installed nowhere upstream** — the dialog is a GResource-only component. The port has to add the action.
- **Three components have no declarative half at all** (`LpImage` and its 12 impl files, `LpSlidingView`, `LpShyBin`, `LpPrintPreview`) and are custom `measure`/`size_allocate`/`snapshot` widgets. They are the hard part of this port, not the dialogs.
- **Repeaters**: `LpImagePage` inside `LpSlidingView`, one per file in `LpFileModel`. Everything else is a fixed tree.
- **Conditional components**: the `devel` CSS class on the window (APP_ID only), the `dates` and `details` properties groups (hidden when the image has no such metadata), the narrow-layout bottom bar in `LpEditCrop`, and the error-page buttons.
