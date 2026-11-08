# Test parity — loupe

| | |
|---|---|
| Upstream | `main` @ `2593900` |
| Port | `ruby` @ `4fb8595` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Test command | (none — see below) |

## Upstream still has no test suite

Re-confirmed directly against `origin/main` in this pass:

```
$ grep -rln '#\[test\]|#\[gtk::test\]|#\[tokio::test\]|mod tests|cfg(test)' src/
(no matches)
$ find . -iname '*test*' -not -path './.git/*'
(no matches)
```

Unchanged from every previous pass. Parity is **0/0, met trivially**: the
port inherits no safety net because upstream pinned nothing down as worth
testing.

## This round's runtime gate — reproduces exactly on check count, still doesn't on "components"

```
$ nix develop --command xvfb-run -a ruby test/drive_foundation.rb
...
69 of 69 checks passed
DRIVE OK
```

**Reproduces exactly** against this round's stated gate
(`drive_ok=true, 69 checks passed, 0 failed, covering 12 components`) on
the check count: 69/69, 0 failures, same as the gate claims. This is up
from 50/50 last round — `drive_foundation.rb` grew five new sections
(`[13]`–`[17]`) covering the GPS-place lookup (`metadata.rb`), `ShyBin`, and
the new `Decoder`.

**The "12 components" clause still does not reproduce — same unsourced
pattern as the previous two rounds, now with a third different number.**
The script's own section banners run `[0]` through `[18]` (19 sections).
Reading which port files/modules each section actually exercises names at
least these distinct units: `config.rb`, `style.rb`, `util/gettext.rb`,
`settings.rb`, `window.rb`, `error_details.rb`, `shortcuts_dialog.rb`,
`about.rb`, `drag_overlay.rb`, `util/root.rb`, `file_model.rb`,
`metadata.rb`, `shy_bin.rb`, `decoder.rb` — **14**, not 12, by the most
natural "one row per file touched" grouping, and no comment, script output,
or report anywhere in this tree produces 12 by any other grouping either.
Last round's gate said "50 checks... 5 components" against 9+ files touched;
this round says "69 checks... 12 components" against 14 files touched. The
specific wrong number keeps changing; the pattern — a "components covered"
figure with no traceable source in the repo — has now repeated identically
across three consecutive rounds. See `accountability-ensurance.md`.

- `spec/` — **still zero `*_spec.rb` files.** `find spec -type f` returns
  only `spec_helper.rb` and `README.md`, unchanged since the first pass.
  `bundle exec rspec` would report "0 examples, 0 failures." That is still
  not evidence of anything passing, and the dev shell's own banner
  (`run the specs: ruby -e 'require "rspec/core"; ...'`) advertises a
  command that currently runs nothing.

Both the drive script and the empty spec/ directory are extras by the
skill's definition — upstream owes the port no tests, so 0/0 stands
regardless of how large `drive_foundation.rb` grows.

## The real finding: coverage, not count — 5 new checks closed real gaps, the shape of the gap is otherwise unchanged

The five new sections (`[13]`–`[17]`) are not padding: they exercise real,
previously-untested behaviour —

- `[13]` drives an actual GPS-tagged file through `GWeather::Location.world`
  and checks the resolved place name, plus the far-from-any-city
  degrees/minutes/seconds fallback.
- `[14]` builds a real `ShyBin` with a real label child and checks the
  measure-clamp numerically on both axes.
- `[15]`–`[17]` decode a real PNG through `GdkPixbuf::PixbufLoader`, and
  separately drive a missing file and unreadable image data through the
  same decoder to check both error-classification branches.

None of this is a check that merely imports a file and asserts it loaded;
each one drives real behaviour through a real code path. That is a
genuine, material improvement in what the driver actually proves, on top of
last round's genuine improvement in reproducibility.

But the coverage gap `component-parity.md` identifies is otherwise
unchanged in shape: **not one check in the driver opens an image in an
image-viewing widget, zooms it, pans it, rotates it, crops it, prints it, or
shows it in a properties sidebar** — because, per `component-identification`
and `component-parity`, none of those 9 widget units exist yet to check.
The new decoder checks prove a pixbuf can be produced; nothing anywhere in
the driver or the port hands that pixbuf to a widget that displays it.

## Verdict

0/0 against upstream, met trivially, no inherited safety net — unchanged.
The port's own driver grew honestly this round: 69/69 checks, reproducing
the gate's check-count exactly, and the five new checks exercise real
behaviour rather than padding the count. But the gate's "12 components"
clause is, for the third round running, an unsourced number — 14 files are
touched by the 19 sections the script itself prints, not 12, by any
grouping this audit could find in the repo. And the driver's actual reach
is still bounded to the ~35–40% of the app that has a file at all
(`component-parity.md`: 5/16 full-parity units, 9/16 with no file); the
other ~60% — image rendering, zoom, pan, rotate, crop, print, properties —
remains exactly as untested as before, because it remains unbuilt. `spec/`
is still empty and the dev shell's advertised RSpec command still runs zero
examples.
