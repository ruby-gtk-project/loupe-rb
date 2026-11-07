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
place: the runtime-gate claim handed to this audit, and one commit message.

## Finding 1 — the stated drive gate does not reproduce from the repo's own script (most serious)

The task that launched this audit states the runtime gate as **"drive_ok=true,
43 checks passed, 0 failed, covering 13 components."** The only drive script
in the repo is `test/drive_foundation.rb`. Run directly in this audit:

```
nix develop --command xvfb-run -a ruby test/drive_foundation.rb
...
ALL PASS
```

— but counting its actual output gives **27 `OK` lines** (`grep -c
'check("'` on the source gives 28 call sites; one fewer executes or prints,
immaterial to the point), not 43, and the file groups them under two
comment headers ("Support modules", "Widgets"), not 13 named components.
There is no second drive file, no `rake`/`rspec` target that adds 16 more
checks, and no document in the repo that explains where "43" or "13" comes
from. I did not find the source of those numbers; I also could not confirm
them. **A runtime-gate number that cannot be reproduced from the repo that
supposedly produced it is, by itself, a false-green risk**, independent of
whether the underlying 27-28 checks are honest (they are — see
`test-parity.md`). Whoever reports the next gate number should show the
command that produced it in the same sentence, the way `test-parity.md`'s
skill asks ("34/34, suite green" is a claim someone can re-run — "43 checks,
13 components" currently is not).

Separately, and more importantly than the arithmetic: **even if 43/43 were
exactly reproducible, it would still be a false impression of the app's
state**, because every single one of those checks — by direct reading of
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

## Finding 3 — `find-excuses.sh` hits, read by hand

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
and `component-parity.md` say the opposite, in detail. It is saying that,
unusually for this failure mode, **the gap itself is not currently being
hidden by language inside the repo.** The place a false-green claim is
sitting right now is external to the repo: the gate number handed to this
audit, which this repo's own script does not reproduce, and which — even at
face value — covers a small, already-finished slice of a much larger app.

## Verdict

**Not clean.** One unreproducible gate number (Finding 1), one overclaiming
commit subject line against an otherwise-honest body (Finding 2). Zero
excuse-pattern language survives review in `lib/`, `exe/`, or the port's own
reports (Finding 3) — the existing `component-inventory.md` is, if anything,
a model of the blunt admission this skill asks for. The accountability risk
here is not a buried "dropped deliberately" note; it is a narrow, true
number being handed up the chain as if it meant the port is far closer to
finished than `component-identification.md` and `component-parity.md` show
it to be.
