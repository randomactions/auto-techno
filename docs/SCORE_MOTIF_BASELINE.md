# Score motif baseline

This contract defines the local, descriptive score evidence introduced by
AT-0025. It answers which resolved upper motifs recur, which symbolic
dimensions changed, and whether interval shape survived transposition. It does
not infer notes from PCM, rank musical quality, change a score, or feed a
runtime decision.

## Authority and scope

`AutonomousPhrasePlan` remains the accepted canonical phrase. The analyzer
reuses the same `SynthPerformancePlan` construction used by the renderer, with
the plan's resolved bars, material world, and phrase-composition bars. Its raw
input is therefore an immutable copy of already-resolved upper-note facts:
role, onset, score timing offset, duration, start/end frequency ratio, and
gate. The adapter neither invokes another composition policy nor changes the
plan.

Three pitch-bearing motif roles are eligible:

- `anchor`, including arpeggiator substitution of the authored anchor motif;
- `shadow`, the existing derived companion to the anchor motif; and
- `response`, the existing score-owned answer role.

`atmosphere` and `transition` remain valid resolved upper notes, but are
excluded from motif comparisons because their long glides and structural
functions are not recurring note-cell claims. Their counts are retained under
their names so exclusion is inspectable. Pads, sequencer metadata, percussion,
and PCM pitch estimates are outside this baseline. A sustained eligible note
or slide remains eligible and keeps its duration and start/end pitch.

## Canonical token

Each eligible resolved note becomes one token with:

- role;
- onset in millisteps, obtained by rounding `onsetStep +
  timingOffsetInSteps` to one thousand units per sixteenth-note step;
- duration in millisteps;
- start and end register in MIDI millinotes;
- start and end pitch class modulo 12,000 millisemitones; and
- retrigger or slide gate.

Register uses C2/MIDI 36 as the scene-root base, adds the scene DNA tonal
center, then adds `round(12 * log2(frequencyRatio) * 1000)`. This is a stable
symbolic coordinate, not detected MIDI. It preserves exact absolute score
pitch, octave displacement, modal transposition, and glides. The 1/1000-unit
quantization is fixed for schema v1 and finer than any currently resolved
score motion.

Tokens are ordered by onset, `SynthRole` declaration order, end pitch,
duration, then source order. Duplicate notes are retained and receive stable
post-sort ordinals. The ordinal is provenance only; exact identity hashes role,
onset, duration, start/end pitch, and gate.

## Bar scopes, density, and register

Every phrase bar produces four records in this exact order: `combined`,
`anchor`, `shadow`, and `response`. A role record contains only that role;
`combined` contains all three eligible roles and retains each token's role.

Per-role density is note count divided by sixteen score cells. Combined
density is note count divided by forty-eight role-cells. This is event density,
not occupied-cell density and not PCM activity. Minimum, arithmetic-mean, and
maximum register use end-pitch MIDI millinotes. They are null for an inactive
scope. An inactive role is a valid score state and is not silently classified
as a repeating motif.

Three identities remain separate:

- exact-token fingerprint: absolute role, timing, duration, pitch, and gate;
- interval-contour fingerprint: ordered signed end-pitch intervals, available
  only for two or more notes; and
- normalized-motif fingerprint: role, onset, duration, gate, and start/end
  pitch after subtracting the first note's end pitch.

The interval fingerprint is pitch-only. The normalized motif also requires
the same timing, duration, role, and gate while permitting uniform
transposition. An octave-displaced or modal-transposed motif can therefore
match normalized identity while exact identity, pitch class, and register
remain separately visible.

## Comparisons and mutation distances

For each current bar, scope, and lag from one through four available prior
bars, the analyzer emits a comparison in current-bar, scope, then ascending-lag
order. History never crosses the accepted phrase boundary in schema v1.

Every sequence mutation distance is Levenshtein edit count divided by the
longer sequence length. A value of zero means equality in that named domain;
one means every aligned element differs or the sequences do not overlap under
the bounded edit model. The report keeps these dimensions separate:

- complete note-token mutation;
- onset mutation;
- duration mutation;
- absolute start/end-pitch mutation;
- pitch-class mutation;
- signed-interval mutation;
- role mutation; and
- note-count, density, and mean-register deltas.

Uniform transposition is reported only when both bars have the same note count
and identical non-empty signed-interval vectors. Single-note bars have no
interval contour and return null rather than claiming a match. Onset rotation
tests all sixteen integer forward rotations of the reference onset grid; the
lowest shift wins a tie. Fractional timing offsets remain in the rotated
millistep sequence, so microtiming is not discarded.

If both scopes are inactive, or only one is active, the comparison has a named
unavailable state and every derived comparison field is null. Inactivity is
therefore distinct from exact recurrence.

## Bounds and fail-closed behavior

Analysis accepts one to sixteen contiguous bars, no more than eighty resolved
upper notes per bar, tonal centers zero through eleven, the five canonical
upper roles, canonical gates, finite values, and the current resolved-note
bounds. Invalid phrase identity, discontinuous bars, unsupported roles or
gates, non-finite data, and values outside those bounds return one explicit
unavailable reason. No partial evidence is emitted.

All work is finite, detached, and opt-in for the local exporter. The runtime,
renderer, evaluator, continuation, controller, scheduler, callbacks, UI, and
fallbacks do not call this analyzer. It adds no parameter and cannot affect
current or future PCM.

## Corpus export and independent verification

`ScoreMotifBaselineIntegrationTests` replays every one of the fourteen exact
accepted AT-0016 case/route identities through the shared preparation path. It
requires the resulting plan, incoming state, and replay fingerprints to match
the current whole-mix manifest. Each asset stores both the raw resolved-note
copy and Swift evidence. The two route rates for a corpus case must have the
same plan, raw score, and motif-evidence fingerprint.

`scripts/score_motif_baseline_report.py` is an independent implementation. It
validates manifest and snapshot provenance, reconstructs every token, bar,
comparison, summary, and FNV fingerprint from the raw score copy, and rejects
mutated pitch, onset, role, duration, units, hashes, normalization, identity,
or provenance. The finalized local report adds one canonical SHA-256 report
fingerprint.

The payload and finalized manifest live under the ignored local directory
`docs/local/reports/score-motif-baseline-v1/`. No copied audio, external model,
reference recording, or third-party research asset is required.

## Interpretation limits

This baseline describes canonical symbolic relationships. It does not prove
that a motif is perceptually salient after synthesis and mixing, that two
different voicings sound equivalent, or that any measured amount of repetition
is suitable for techno. AT-0024 independently describes rendered onset-grid
behavior without score binding. Later work may bind the two evidence families,
but neither may impersonate the other and neither is a quality threshold in
AT-0025.
