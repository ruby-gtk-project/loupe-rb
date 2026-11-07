# Test parity — loupe

| | |
|---|---|
| Upstream | `main` @ `2593900` |
| Port | `ruby` @ `f914f87` |
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

- `test/drive_foundation.rb` — 27 `check(...)` assertions, run via
  `nix develop --command xvfb-run -a ruby test/drive_foundation.rb`. Re-run in
  this audit: **ALL PASS**, 0 failures, 27 checks (the task description's "43
  checks... 13 components" figure does not match a direct count of this
  file's `check(...)` calls — see `accountability-ensurance.md` for the
  discrepancy and what it implies).
- `spec/` — **contains zero `*_spec.rb` files.** `spec/spec_helper.rb` and
  `spec/README.md` set up the `kettle-test`/RSpec harness, but no spec exists
  for it to run. `bundle exec rspec` would report "0 examples, 0 failures"
  and that is not evidence of anything passing.

Both are extras by the skill's own definition ("extra Ruby tests with no
upstream counterpart... listed in `## Extra`, outside the count") — upstream
owes the port nothing here, so 0/0 stands regardless of how large or small
`drive_foundation.rb` is.

## The real finding: coverage, not count

Because upstream has no tests, the only safety net the port has is whatever
it wrote for itself, and that net is **extremely narrow relative to the
app**. Every one of `drive_foundation.rb`'s 27 checks exercises the support
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
"43 checks passed, 0 failed, 13 components" (or 27, by direct count here) is
a true statement about a narrow slice of the app and a false impression about
the whole of it if read as a release gate. A component no check exercises is
unverified, not done, and 11 of the app's 16 units (per
`component-parity.md`) are in exactly that state — not merely untested, but
with no file for a test to even import.

## Verdict

0/0 against upstream, met trivially, **no inherited safety net**. The port's
own 27-check driver is real and currently green, but it is scoped entirely to
the ~30% of the app that has been written, and a green run of it proves
nothing about the ~70% that has not. Treat "the drive gate passed" and "the
test suite is healthy" as two different, mostly unrelated claims; only the
first is currently true.
