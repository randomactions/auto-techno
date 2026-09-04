# Detached Role-Stem Capture Contract

## Purpose and scope

Phase-1 diagnosis needs role-local PCM aligned with the exact accepted whole
mix. Auto Techno therefore exposes an opt-in diagnostic capture at the existing
detached render boundary. It does not add a renderer, bus, product control,
runtime asset, scheduler input, callback action, or continuation field.

Capture is disabled by default. In that state, `VoiceRenderer` recycles its
workspace as before, `AutonomousPhraseRenderProduct` contains no diagnostic
captures, and `PreparedAutonomousPhrase.diagnosticRoleStemCaptures` is empty.
The macOS host, Windows host, C handoff, scheduled blocks, and route state never
read or request diagnostic PCM. Tests require capture-enabled and capture-
disabled rendering to produce bit-identical `RenderBlock` arrays and identical
outgoing render/graph continuation.

The opt-in local exporter uses the same preparation transaction, evaluator,
bounded correction, and selected candidate as the shipped runtime. A rejected
candidate releases its capture before a correction render. Only the accepted
candidate can reach the local evidence writer, and file I/O begins after
detached preparation returns.

## Captured signals

Every file begins at the accepted phrase's first sample, ends at its last
sample, and uses its native route rate. Mono role files retain the renderer's
exact dry role taps; stereo files retain shared processing stages.

| Signal | Channels | Class | Meaning |
|---|---:|---|---|
| `kick` | 1 | linear role | Post-fader audible dry kick |
| `foundation` | 1 | linear role | Bass, rumble, and foundation-companion contribution |
| `modal-foundation` | 1 | protected subrole | Coupled modal subset of the foundation role, retained because it has a distinct protected insertion path |
| `percussion` | 1 | linear role | Complete audible percussion role, including governed return/slice contribution |
| `upper-tonal` | 1 | linear role | Motif/response upper source |
| `atmosphere` | 1 | linear role | Atmosphere/transition upper source |
| `protected-foundation` | 1 | protected variant | Exact dry kick plus foundation tap from the protected pass |
| `dry-center-reference` | 1 | reconstruction reference | Pre-shared-processing center source |
| `dry-upper-reference` | 1 | reconstruction reference | Pre-shared-processing upper source |
| `protected-rhythm` | 2 | protected variant | Scheduled protected rhythm after its shared voice processing |
| `graph-input` | 2 | processed stage | Full voice-render remainder minus the protected reference |
| `processed-upper` | 2 | processed stage | Generated graph output after carrier handling and upper pump |
| `pre-climax-mix` | 2 | processed stage | Protected rhythm plus processed upper after output safety |
| `output-safety-residual` | 2 | nonlinear residual | Difference introduced by bounded outer output safety |
| `terminal-processing-residual` | 2 | nonlinear residual | Difference introduced by climax hang and accepted live-master trim |

The existing whole-mix WAV remains the final stereo reference. Stem manifests
bind its exact PCM hash rather than copying it into the stem directory.

## Reconstruction contract

For every sample, the verifier measures these relationships in IEEE Float PCM:

```text
protected-foundation ~= kick + foundation
dry-center-reference ~= protected-foundation
                       + percussion
                       - modal-foundation
dry-upper-reference ~= upper-tonal + atmosphere

pre-climax-mix ~= protected-rhythm
                 + processed-upper
                 + output-safety-residual

whole-mix ~= pre-climax-mix + terminal-processing-residual
```

The maximum absolute error for each relation must remain below `0.000001`.
Full and protected passes must retain bit-identical kick, foundation,
percussion, and protected-foundation taps. Every signal must be finite and have
the exact whole-mix frame count.

## Intentional nonlinear and shared exceptions

Dry roles are additive only before shared voice processing. The subtraction in
the dry-center equation prevents the modal subset, already included in
`foundation`, from being counted at the earlier center reference: coupled modal
foundation deliberately bypasses the shared center compressor and is inserted
through its own bounded post-master path. That exception remains explicit as
`modal-post-master-insertion` rather than being hidden by a relaxed sum.

Ducking, delay,
chorus, the spatial FDN, glue, and master safety use shared time-varying state;
the resulting `sourceLeft`/`sourceRight` stage is a reference, not an
independently summable role set. The generated graph and upper pump are likewise
reported as one `processed-upper` stage. This prevents later analysis from
pretending that a nonlinear or state-coupled mix can be recovered by summing
independently processed solo renders.

Two explicit residual files make the remaining recombinations auditable:

- `output-safety-residual` accounts for the bounded nonlinear safety curve
  applied after protected rhythm and processed upper are recombined.
- `terminal-processing-residual` accounts for score-owned climax processing and
  the already accepted live-master trim after the pre-climax mix.

A residual is diagnostic attribution, not another production bus or a reusable
effect return.

## Local artifacts and verification

The opt-in test `StemCaptureIntegrationTests` writes ignored local evidence:

```text
docs/local/audio/baseline-stems-v1/*.wav
docs/local/reports/baseline-stems-v1/manifest.json
```

The manifest binds the tracked corpus, current roadmap contract baseline,
current source fingerprint, Git head, engine identity, exact whole-mix
manifest, accepted plan/state/replay identities, every stem file and PCM hash,
reconstruction maxima, and the named nonlinear exception taxonomy.

Generate only from an isolated local build:

```sh
AUTOTECHNO_RUN_STEM_CAPTURE=1 swift test --no-parallel \
  --filter StemCaptureIntegrationTests
python3 scripts/stem_capture_manifest.py check
```

`scripts/stem_capture_manifest.py` independently parses every WAV, rejects
unknown, missing, duplicate, escaped, non-finite, misaligned, stale, or corrupt
artifacts, recomputes the sums above, and requires exactly fifteen signals for
each of the fourteen Phase-1 corpus identities. These WAVs are measurement
evidence only. They remain ignored, are not bundled, and cannot become runtime
sources, presets, samples, or release assets.

## Realtime safety

All array retention and analysis occur in detached preparation before the
immutable future phrase is eligible for scheduling. Capture performs no work in
the macOS mixer tap, `CAutoTechnoRealtime` producer/consumer, Windows waveOut
completion callback, player scheduling loop, or UI. Cancellation discards the
partial preparation and its arrays. The callback contract remains a bounded
copy into preallocated storage with no allocation, locking, waiting, analysis,
logging, hashing, file/network I/O, microphone access, or UI work.
