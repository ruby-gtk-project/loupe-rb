# Test parity — loupe

| | |
|---|---|
| Upstream | `main` @ `2593900` |
| Port | `ruby` @ `01ff0bc` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Test command | (none — see below) |

## Upstream has no test suite

Verified directly against `origin/main` in a detached worktree:

```
$ grep -rln '#\[test\]|#\[gtk::test\]|#\[tokio::test\]|mod tests|cfg(test)' src/
(no matches)
$ find . -iname '*test*' -not -path './.git/*'
(no matches)
```

No `tests/` directory, no `#[test]` function anywhere in `src/`, no
`[[test]]` in `Cargo.toml`, no test target in `meson.build`. The census
script (`.claude/skills/test-parity/scripts/test-census.sh`) run against the
worktree returns zero rows, agreeing with the direct grep.

Parity is **0/0 and is met trivially.** Per the skill's own worked case for
this situation (GNOME Tour): **the port therefore inherits no safety net.**
Nothing upstream pinned down as worth testing exists to be dropped, and
nothing in this report should be read as the port having "passed" a suite —
there is no suite to pass or fail against.

## What the port has instead, and why it is `## Extra`, not parity

Since the previous pass of this report, two commits
(`Give the dev shell a display...` already in, plus the test-harness work
landing as `test/gtk_driver.rb` and a rewritten `test/drive_foundation.rb`)
added a reusable "drive a real running main loop" harness and grew the
foundation driver from 27 checks to 50. Re-run directly in this audit:

```
$ nix develop --command xvfb-run -a ruby test/drive_foundation.rb
...
50 of 50 checks passed
DRIVE OK
```

**Reproduces exactly**: 50 checks, 0 failures, matching the runtime gate
handed to this audit (`drive_ok=true, 50 checks passed, 0 failed`) — this
number, unlike the previous round's "43 checks... 13 components", is now
directly reproducible from the repo's own script. Good.

The gate's **"covering 5 components" clause does not reproduce.** The
driver's own section banners (`[0]` through `[13]`, printed by the script
itself) name at least nine distinct port files under test — `config.rb`,
`style.rb`, `util/gettext.rb`, `settings.rb`, `file_model.rb`, `window.rb`,
`error_details.rb`, `shortcuts_dialog.rb`, `about.rb`, `drag_overlay.rb`,
plus `util/root.rb`'s mixin — not 5. No grouping in the script, the test
files, or any report on disk produces 5 as a count of anything. Whatever
"5 components" is meant to mean, it is not sourced from this repo either;
see `accountability-ensurance.md`, which flags this as the same
unreproducible-number pattern as last round's "13 components," just with a
new number.

- `spec/` — **still contains zero `*_spec.rb` files**, unchanged from the
  previous pass. `spec/spec_helper.rb` and `spec/README.md` set up the
  `kettle-test`/RSpec harness, but no spec exists for it to run. `bundle exec
  rspec` would report "0 examples, 0 failures" and that is not evidence of
  anything passing.

Both are extras by the skill's own definition ("extra Ruby tests with no
upstream counterpart... listed in `## Extra`, outside the count") — upstream
owes the port nothing here, so 0/0 stands regardless of how large or small
`drive_foundation.rb` is.

## The real finding: coverage, not count

Because upstream has no tests, the only safety net the port has is whatever
it wrote for itself, and that net is **extremely narrow relative to the
app**. Every one of `drive_foundation.rb`'s 50 checks exercises the support
layer and window chrome described in `component-identification.md`'s
"already ported" column:

- config/style/gettext/util helpers (8 checks)
- settings round-trip, file-model navigation (2 checks)
- window layout state, stack page switching, toasts (6 checks)
- the two dialogs that exist (error details, about), the shortcuts dialog,
  the drag overlay (6 checks)
- icon theme resolution, `Util::Root` plumbing, opened-files-to-file-model
  (5 checks)

**Not one check touches image loading, decoding, rendering, zooming,
panning, rotating, cropping, printing, or metadata/EXIF display** — because,
per `component-identification.md`, none of that code exists yet to check.
"50 checks passed, 0 failed, 5 components" is a true statement about the
check count and a false impression about both "5 components" (see above) and
the whole of the app if read as a release gate. A component no check
exercises is unverified, not done, and 11 of the app's 16 units (per
`component-parity.md`) are in exactly that state — not merely untested, but
with no file for a test to even import.

## Verdict

0/0 against upstream, met trivially, **no inherited safety net**. The port's
own 50-check driver is real, currently green, and reproduces exactly from
`nix develop --command xvfb-run -a ruby test/drive_foundation.rb` — a genuine
improvement in reproducibility over the previous round's unverifiable "43
checks / 13 components." But it is still scoped entirely to the ~30% of the
app that has been written (window chrome, two dialogs, settings, file model,
support helpers), and a green run of it proves nothing about the ~70% that
has not — image loading, rendering, zoom/pan/rotate, crop, print, EXIF/XMP
metadata. Treat "the drive gate passed" and "the test suite is healthy" as
two different, mostly unrelated claims; only the first is currently true,
and the gate's own "5 components" clause is itself unverified against the
repo (see `accountability-ensurance.md`).
