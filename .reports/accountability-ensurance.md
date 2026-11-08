# Accountability ensurance — loupe

## What was grepped

```
grep -rniE 'TODO|FIXME|not implemented|for now|in a future|not yet|placeholder|stub' lib/ exe/ .reports/
bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh . --quiet
find . -iname PORTING.md
```

`PORTING.md` still does not exist on this branch, unchanged across every
pass of this audit.

## Finding 1 — the drive gate's "components" clause has now been wrong in three consecutive rounds, with three different numbers (most serious, unresolved for a third round)

This round's task states the gate as **"drive_ok=true, 69 checks passed, 0
failed, covering 12 components."** Re-run directly in this audit:

```
$ nix develop --command xvfb-run -a ruby test/drive_foundation.rb
...
69 of 69 checks passed
DRIVE OK
```

The **check count reproduces exactly** again — 69/69, matching the gate,
continuing the trend of the check-count half being taken from real script
output each round (43→50→69, each one verified reproducible in its own
round's audit).

The **"components" clause still does not reproduce**, for the third round
running:

| Round | Gate claimed | Script's own section banners | Distinct files/modules a plain reading finds |
|---|---|---|---|
| 1 | "43 checks... 13 components" | fewer sections, didn't reproduce at all | — |
| 2 | "50 checks... 5 components" | `[0]`–`[13]` (14 sections) | 9+ files |
| 3 (this round) | "69 checks... 12 components" | `[0]`–`[18]` (19 sections) | 14 files: `config.rb`, `style.rb`, `util/gettext.rb`, `settings.rb`, `window.rb`, `error_details.rb`, `shortcuts_dialog.rb`, `about.rb`, `drag_overlay.rb`, `util/root.rb`, `file_model.rb`, `metadata.rb`, `shy_bin.rb`, `decoder.rb` |

No comment, report, script output, or grouping rule anywhere in this
repository produces 12 as a count of anything connected to this drive run,
the same as 5 didn't reproduce last round and 13 didn't the round before
that. **The specific wrong number keeps changing (13 → 5 → 12) while the
underlying failure — a "components covered" figure attached to the gate
with no traceable source in the repo — repeats unchanged for a third
consecutive round.** The check-count half of the gate got fixed between
round 1 and round 2 and has stayed fixed since; the component-count half
has never once been sourced, across three rounds of this exact finding
being raised. That is itself the finding worth escalating: a true number
(the check count) keeps arriving attached to a number that still isn't
computed from anything in this repo, and nothing between rounds has closed
that gap even though the check-count half demonstrably can be fixed.

Separately, and as in every previous round: **even at 69/69 exactly
reproduced, the gate is still a narrow number read as a broad claim.**
`component-parity.md` finds 5 of 16 widget units with real parity and 9 of
16 with no port file at all; not one of the drive script's 19 sections
opens, zooms, pans, rotates, crops, prints, or inspects an image through a
properties sidebar, because none of those widgets exist. Five new sections
landed this round (`[13]`–`[17]`, covering GPS lookup, ShyBin, and the
decoder) and all five are real, behaviour-driving checks, not padding — see
`test-parity.md` for the detail — but they extend coverage within the
support layer, not into the 9 unbuilt widget units.

## Finding 2 — the previous round's `appstream` overclaim is now fixed; recorded here for continuity, not as a new finding

The previous round flagged commit `f914f87`'s subject ("Wire appstream and
libgweather...") for claiming "wire" on a dependency the commit's own body
admitted had no caller. Checked in this pass: the gemspec no longer lists
`appstream` as a dependency at all —

```
$ grep -n 'appstream\|AppStream' loupe-rb.gemspec lib/**/*.rb
loupe-rb.gemspec:  # Removed: upstream's own AppStream dependency is build-tooling only (CI
```

— and the comment explains why it was dropped rather than wired. This is
the overclaim being resolved the honest way (removing the unused
dependency and saying so) rather than papered over. Not carried forward as
an open finding.

## Finding 3 — the `po/` directory false-green artifact from the previous round is unchanged, neither worse nor fixed

Commit `80c5bb6`'s 58 byte-identical, upstream-sourced `.po` files remain on
the branch, still pointed at `lib/loupe/*.rb` via `po/POTFILES.in`, still
disconnected from the port's actual strings in the way the last round
found (`diff <(git show origin/main:po/de.po) po/de.po` is still empty —
confirmed again in this pass). What changed this round is that the port
now genuinely marks 13 strings for translation (see
`translation-parity.md`), which makes the gap between "po/ looks like
58-language coverage" and "the port actually has 13/230 strings marked, in
a form the po/POTFILES.in-driven extraction tooling can't even see" more
specific than last round's blanket zero, but no less misleading to a
reviewer who counts files instead of opening them. Not escalated further
since the artifact itself hasn't changed, but not resolved either —
carried forward.

## Finding 4 — `find-excuses.sh` hits, read by hand, same result as every previous round

```
.reports/component-inventory.md, .reports/accountability-ensurance.md, .reports/translation-parity.md
```

are the only files the script's literal-string scan touches; every hit is
inside this audit's own report documents, quoting or summarizing prior
findings, not inside `lib/` or `exe/`. Read in context, each one is either
a correct "out of scope" classification of non-application packaging files
or this report's own summary language — not an excuse for skipped
application code. **No excuse-pattern hit survives being read in context,
for the third round running.** `grep -rniE 'TODO|FIXME|not implemented|for
now|in a future|not yet|placeholder|stub' lib/ exe/` returns zero matches
outside two non-substantive hits already dismissed in the previous round
(`window.rb`'s `stub` parameter name — a variable name, not an admission —
and `gettext.rb`'s prose about placeholder *substitution*, which is what
the file's job is, not a note about deferred work).

## What this report is not saying

It is not saying the port is close to done. `component-identification.md`
and `component-parity.md` say the opposite in detail: 9 of 16 widget units
still have no file, and the app's core reason for existing (viewing,
zooming, panning, rotating, cropping, printing, inspecting an image)
remains entirely unbuilt behind a window shell with two empty slots. It is
saying that, within the narrower scope this skill audits — excuse language
in the shipped code, and gate numbers that do or don't reproduce — one
long-standing overclaim (`appstream`) got fixed outright, one false-green
artifact (`po/`) is unchanged, and one specific recurring failure (the
drive gate's "components" count) has now failed to reproduce in three
consecutive rounds with three different wrong numbers, which is worse as a
pattern than any single round's wrong number on its own: it means the gap
between "checks passed" and "components covered" is being re-asserted each
round rather than computed once and fixed.

## Verdict

**Not clean.** Finding 1 (the drive gate's unsourced "components" clause)
is unresolved for a third consecutive round and is the most serious open
item — not because 12 is a large error, but because the same category of
unsourced claim has now survived three rounds of being flagged without
being fixed, while the check-count half of the same gate demonstrably
*has* been fixed twice over the same period. Finding 2 (`appstream`) is
resolved. Finding 3 (`po/`) is unchanged, neither better nor worse.
Finding 4 (`lib/`/`exe/` excuse language) remains clean, as in every prior
round. The real, narrow improvements this round — shy_bin's faithful port,
the decoder's honestly-scoped simplification, 13 real strings now wired to
gettext — are genuine and are credited in the other four reports; none of
them touch the one finding that has now recurred three times running.
