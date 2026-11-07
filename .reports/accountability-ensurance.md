# Accountability ensurance — loupe

## What was grepped

```
grep -rniE 'TODO|FIXME|not implemented|for now|in a future|not yet|placeholder|stub' lib/ exe/ .reports/
bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh . --quiet
```

No `PORTING.md` exists in this port (confirmed: `find . -iname PORTING.md`
returns nothing), so there is no document of that name to hold the kind of
laundered "Dropped deliberately" section the skill's `console-rb` example
warns about. That is not a point in the port's favor by itself — it just
means the risk this skill exists for is currently sitting in a different
place: the runtime-gate claim handed to this audit, two commit messages, and
— new this round — a directory of files that looks like finished work
without being opened.

## Finding 1 — the drive gate's check count now reproduces; its "components" count still does not, and the same pattern repeated across rounds (most serious)

**Updated this round.** The previous pass of this report flagged "43 checks
passed... 13 components" as unreproducible against `test/drive_foundation.rb`
(27-28 actual check sites). This round's task states the gate as
**"drive_ok=true, 50 checks passed, 0 failed, covering 5 components."**
Re-run directly in this audit:

```
$ nix develop --command xvfb-run -a ruby test/drive_foundation.rb
...
50 of 50 checks passed
DRIVE OK
```

The **check count now reproduces exactly** — 50/50, matching the gate. This
is a genuine improvement: `test/gtk_driver.rb` plus the rewritten
`drive_foundation.rb` (added since the previous pass) grew real coverage
from 27 to 50 checks, and whoever wrote the gate this time used the actual
script output.

The **"5 components" clause still does not reproduce**, and in exactly the
same way as last round's "13 components" did not. The script's own section
banners are `[0]` through `[13]` (14 sections), and reading which port files
each section exercises names at least nine distinct files/modules —
`config.rb`, `style.rb`, `util/gettext.rb`, `settings.rb`, `file_model.rb`,
`window.rb`, `error_details.rb`, `shortcuts_dialog.rb`, `about.rb`,
`drag_overlay.rb`, `util/root.rb` — not 5, by any grouping found in the repo.
No comment, report, or script output anywhere in this tree produces 5 as a
count of anything related to this drive run. **The specific wrong number
changed from 43/13 to 50/5, but the failure mode — a "components covered"
figure attached to a gate with no traceable source — is identical across
both rounds.** That recurrence is itself worth flagging: the check-count half
of the gate is now taken seriously enough to get fixed, but the
component-count half is still being asserted rather than computed, two
rounds in a row.

Separately, and more importantly than the arithmetic: **even at 50/50
exactly reproduced, it is still a false impression of the app's state**,
because every one of those 50 checks — by direct reading of
`drive_foundation.rb` — exercises only the ~30% of the app that
`component-parity.md` finds already built (window chrome, two dialogs, the
shortcuts window, settings, file-model, gettext util). Not one check opens
an image, zooms it, pans it, rotates it, crops it, prints it, or shows its
EXIF data, because none of that code exists (`component-identification.md`:
11 of 16 units have no port file). Reporting a drive gate as "passed" without
also reporting what fraction of the app it reaches is exactly the mechanism
this skill exists to catch: a true, narrow number read as a broad claim.

## Finding 2 — commit `f914f87` overclaims in its subject line

Subject: **"Wire appstream and libgweather, port metadata/file.rb."**
"Wire" is a false claim for `appstream`: the commit's own body admits
`appstream has no caller yet` — the gem is added to the Gemfile and proved to
load (`AppStream.constants.size == 97`) but nothing in `lib/` ever requires
or calls it. A gem added to a lockfile and never required by the app it was
added to is not "wired"; it is unused, and the subject line should say so.
The body is otherwise honest and should be the template for how this gets
said: *"appstream has no caller yet... there is nothing in loupe itself for
the gem to back"* is a plain statement of what's missing, not a decision
dressed up as one. The subject line, read on its own in `git log --oneline`
(as this audit initially did), is the part that misleads.

The body is also honest about the larger gap it leaves: *"the rest of
`src/metadata.rs` depends on EXIF/XMP parsing (gufo) and image/profile
details (glycin, moxcms) with no Ruby binding, so it is not ported this
round."* That is a real binding limitation, correctly scoped as a reason the
gap is *hard*, not a reason it is *closed* — it does not claim `metadata.rb`
exists, and `component-identification.md` confirms it does not. This
sentence is the port being honest about a real gap, not an excuse pattern,
and is not counted against the port below.

## Finding 3 — commit `80c5bb6` adds a `po/` directory that looks like translation parity and is not (new this round, serious)

Commit `80c5bb6` ("Port desktop/metainfo/service data files, app icons, and
help/po catalogues") adds `po/*.po` for 58 languages plus `po/POTFILES.in`.
Checked in this pass: every `.po` file is a **byte-identical copy of
upstream's catalogue** (`diff <(git show origin/main:po/de.po) po/de.po`
produces no output), including upstream's own `#:` source-location comments
pointing at `src/widgets/window.ui` and other paths that do not exist on
this branch. `po/POTFILES.in` lists this port's `lib/loupe/*.rb` files as
the extraction source, but grepping those files finds **zero**
`_()`/`N_()`/`ngettext` call sites outside `util/gettext.rb`'s own
definitions — confirmed independently in `translation-parity.md`. Running
`xgettext` against `POTFILES.in` today would extract nothing; the 58 files
are translations of upstream strings that no file this port actually ships
contains.

This is worse than the gap it replaces. A missing `po/` directory (the
previous round's state) cannot be mistaken for coverage. A `po/` directory
containing 58 real, correctly-formatted, upstream-identical catalogue files
can — and will, to anyone who runs `ls po/ | wc -l` or `find . -name
'*.po'` as a parity check without opening a single file to see whether its
msgids still correspond to anything the port marks. The commit's own
message ("Port... help/po catalogues") uses "port" for a verbatim copy-paste
with no port-side wiring, the same overclaiming pattern Finding 2 above
flags in `f914f87`'s "Wire appstream."

## Finding 4 — `find-excuses.sh` hits, read by hand

```
.reports/component-inventory.md:31:n/a:...
.reports/component-inventory.md:112:out of scope:...
.reports/component-inventory.md:114:Out of scope:...
.reports/component-inventory.md:137:unported:...
```

All four hits are inside the *survey* document itself, not inside `lib/` or
`exe/`. Read in context:

- Line 31 ("n/a") is the inventory's own table marking `.desktop.in.in` as
  `n/a` under the "Exists?" column for a packaging file, with the kind
  column already `service/data` and the row explicitly saying "packaging,
  not app code" — a correct classification of a non-component, not an
  excuse for skipping a component. Not a finding.
- Lines 112/114 ("out of scope") head the inventory's "Out of scope for this
  port" section, which explains *why* `meson.build`, CI files, `help/` and
  `news.d/` are not application components — build/release tooling, not
  user-facing behavior. This is the one place "out of scope" is actually
  legitimate: these are not features upstream ships to a user, they are the
  packaging upstream uses to ship it. Not a finding.
- Line 137 ("unported") is the inventory's summary sentence: *"what exists
  today is the app chrome... but no image is actually decoded, rendered,
  zoomed, printed, edited, or inspected yet — that is all of upstream's
  actual purpose as an image viewer, and it is entirely unported."* This is
  the opposite of the failure mode the skill targets — it is the clearest,
  most blunt admission of the gap in the whole repo, not a note that
  launders it. Not a finding; if anything this sentence is the model for
  what Finding 1 and 2 above are asking for elsewhere.

**No excuse-pattern hit in this repo survives being read in context.** The
survey document this port already carries is unusually direct about the
size of the remaining gap, and nothing in `lib/` or `exe/` contains a
`TODO`, `FIXME`, "not implemented", "for now" or "in a future" marker at all
— the grep for those literal strings returned zero hits outside of
docstring prose unrelated to deferred work (`gettext.rb`'s comments about
*how* placeholder substitution works, `window.rb`'s `stub` parameter name in
`show_error`, which is a variable name, not an admission).

## What this report is not saying

It is not saying the port is close to done — `component-identification.md`
and `component-parity.md` say the opposite, in detail. It is saying that
the gap is no longer only sitting in a gate number external to the repo (as
the previous round found) — this round, one commit (`80c5bb6`) planted a
false-looking-green artifact *inside* the repo itself: a `po/` directory
that passes any shallow "does translation coverage exist" check while being
disconnected from the port's actual strings. That is a step in the wrong
direction from the previous round's finding that nothing in `lib/`/`exe/`
contained excuse language.

## Verdict

**Not clean, and one of the three new/updated findings got worse, not
better, since the last pass.** The check-count half of the drive gate is now
reproducible (Finding 1, improved), but its "components" clause is still an
unsourced number, the same failure repeating with different digits. The
`f914f87` commit-subject overclaim stands as previously found (Finding 2).
New and most serious this round: commit `80c5bb6` adds a `po/` directory
that is a byte-for-byte copy of upstream's 58 catalogues pointed at
`lib/loupe/*.rb` files containing zero gettext call sites — a translation
artifact that *looks* like coverage to anyone who counts files instead of
opening them (Finding 3). `find-excuses.sh` still finds nothing live in
`lib/`/`exe/` beyond the inventory's own blunt, non-laundering admissions
(Finding 4). The accountability risk is shifting from "a narrow true number
read as a broad claim" toward "an artifact that reads as parity until
someone diffs it against upstream" — a more serious failure mode because it
survives a shallower check.
