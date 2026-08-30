# Autonomous Runtime Provenance

## Material-world provenance

Every phrase now binds the current episode's world ID, fingerprint, parent,
generation, handoff, six axes, and progress into the typed plan fingerprint.
The detached generated graph binds the same world plus requested and realized
effect vectors; a mismatch against incoming continuation fails preparation.

No material decision or analysis enters the real-time callback. Core resolves
future score boundaries, detached DSP preparation advances at most one graph
node and renders the existing transition, and the app schedules only accepted
immutable PCM. Route recovery reuses the selected graph exactly.

This document identifies the single shipped path, the owner of each decision,
and the target contract for autonomous adaptation. It distinguishes current
implementation from required future behavior so architectural direction is not
mistaken for a completed feedback system.

## Current implementation

1. Before detached preparation, `TechnoEngine` obtains one opaque `UInt64` from
   its App-owned system-entropy source and constructs the sole
   `AutonomousSessionDirector` for that complete performance. The director owns
   fixed 130 BPM, that private canonical identity, temporal memory, one
   canonical phrase, and successor planning. Pause/resume, live correction,
   playback-timeline reset, route change, and route recovery retain the seed;
   complete shutdown selects the next seed before a later appearance. The
   secondary New Set action explicitly takes that complete boundary: it
   quiesces transport/feedback, cancels and invalidates detached work, clears
   every continuation/cache, selects the next seed, and automatically starts
   the newly prepared phrase. Every preparation-cache key binds the exact seed,
   and stale detached or cached results from another session fail closed. No
   entropy read reaches detached rendering or the realtime callback.
2. Each `AutonomousPhrasePlan` carries a complete musical intention, Scene DNA,
   resolved performance bars, outgoing interlock, spatial-contrast, and
   protagonist-narrative state, plus groove-interest evidence. Supporting-role
   admission is resolved before ensemble arbitration. A resolved bar is the sole
   score source for requested onsets, pitches, durations, gates, and articulation.
   Renderer-owned trajectory evidence records the continuation-dependent applied
   start frequency and gate outcome without creating a second score.
   Pitch semantics are explicit under
   [`PITCH_IDENTITY_CONTRACT.md`](PITCH_IDENTITY_CONTRACT.md): tonal material
   stays in one modal frame, modal percussion retains a tuned inharmonic
   fundamental, named dissonance remains pitched, and indefinite texture cannot
   follow a requested note frequency.
   Each future phrase also carries one director-owned performance character.
   Bounded two-character memory avoids immediate character repetition when another
   compatible interpretation exists. Per-bar foundation behavior, role set, and
   kick grammar must remain compatible with that phrase character; identity
   return resolves to the hypnotic home.
   A derived `PhraseCompositionBar` then coordinates phrase-local slice
   triggers, slice texture/seed, arpeggiator notes, pad voicing,
   harmonic-disclosure stage, and
   voice-leading from that same score and modal identity; it never admits a
   role independently. For an eligible major break, accepted session memory
   offers one of at most four earlier kick recipes no more than 256 bars old;
   it retains no PCM. Detached DSP regenerates that exact canonical kick source.
   Ambient Drift selects bounded granular memory over it and Broken Suspension
   selects exact cut resampling; an absent or invalid recipe falls back to the
   current bar-owned kick or percussion window. Only accepted phrase commit
   advances the recipe memory. The dependent arpeggiator follows the disclosed chord
   without changing its existing onset, duration, velocity, or instrument.
3. `DSPGraphGenerator` produces the deterministic upper-voice topology and its
   bounded mutation from the prior graph.
4. `AutonomousPhrasePreparer` renders immutable attempts into one versioned
   primary-evaluation transaction under quality-contract schema 46, candidate-
   vector schema 38, candidate-transaction schema 11, and canonical engine
   identity `autotechno-canonical-engine.v45`. Each
   attempt carries the complete bounded vector of symbolic, hard-gate, full-mix,
   per-bar masking, role-stem, automatic-mix, score-owned kick-syntax and
   paid-debt climax-arc,
   event-local groove-pulse,
   ordinary closed-hat, score-owned modal-foundation, score-owned instrument,
   score-owned dotted foundation-rhythm and pre-kick pocket,
   score-owned gated/anticipatory percussion-return texture, shared pulse-echo
   return-drive,
   score-bound spatial-FDN,
   cross-phrase terminal/opening seam and inherited-tail continuity,
   phrase-local slice texture/seed/grain geometry/source-position hashes and
   source/output PCM, arpeggiator geometry and exact
   score/render pitch identity, polyphonic pad PCM, harmonic-disclosure
   stage/function, pad rhythmic-modulation consequence, and voice-leading movement,
   score-owned upper-role timing—including a bounded foreground lead-performance
   relation—graph, and pre/post upper-timbre evidence.
   Instrument records bind each resolved architecture, patch, use, automation,
   and compatible effect set to exact architecture-local dry-PCM identity,
   peak, RMS, and event count. Acid assignments additionally bind their durable
   ordered-hollow or metallic-tension relation to same-pass operator-event
   counts, current ratio/index realization, event and operator hashes,
   peak/RMS/crest, low-band energy ratio, and finiteness.
   Every Resonant Mono record also binds its exact unique assignment/event and
   processed-sample counts, applied TPT cutoff/Q and ADAA drive/band-mix ranges,
   pre-core/post-core fingerprints, signal levels, continuation, and finiteness.
   Eligible Metal Veil
   transitions additionally bind one
   rising adjacent-cluster relation to exact component ratios, upward frequency
   geometry, an isolated dry-signal hash, peak/RMS/crest, and finiteness.
   Eligible Tonal Motion release anchors additionally bind one durable
   sustained-wash relation to the exact base/applied sustain and release,
   event identity, isolated dry-signal hash, attack/tail metrics, and finiteness.
   Eligible emerging motif anchors in Resonant Mono or Tonal Motion additionally
   bind one spectral-reveal relation to independent score/render counts and
   fingerprints, active aperture and actual cutoff extrema, and the exact
   isolated-anchor hash/peak/RMS. Home correction retains eligibility while
   resolving the existing filter path to literal home.
   Closed-hat records bind every ordinary hat to
   its score-owned neutral or companion decay role and exact dry-sample
   consequence. Upper-percussion-tail records bind every existing clap,
   open-hat, and metallic event to a post-arbitration natural-body or foreground-
   clearance role, exact attack preservation, and same-pass full/tail PCM
   consequence. The state-free curve runs after the voice's canonical sample
   generation, owns no continuation, and is identical across protected and full
   render passes. Groove-pulse records bind the existing resolved onset to
   score-owned strike zone, damping, deterministic microvariation, exact
   dry-sample identity, and reduced envelope/spectral consequence. Kick-syntax
   records cover every rendered bar and bind the score role and kick-step mask
   to exact detector/audible hashes, nonzero counts, peak/RMS, ducking envelope,
   automatic-mix gain, and kick stem. Each active kick record also binds the
   source-local first-order ADAA conditioner applied to the complete body, sub,
   and click sum through exact pre/post hashes, peak/RMS/crest, physical attack/
   body RMS, and upper-mid energy. The conditioner executes before both
   canonical kick buses, resets per event, and owns no score or continuation.
   After all intended source articulation, one shared state-free terminal
   contract preserves the first 8 ms exactly and releases supported hard-window
   percussion to exact zero: 4 ms for kick/rumble and 2 ms for clap/open-hat/
   metallic events. Same-pass evidence binds each supported score event to
   pre/post full and attack hashes, frame geometry, changed samples, difference
   RMS, and terminal deltas. The audio-safety gate fails closed on missing,
   duplicated, retargeted, attack-changing, or non-zero-terminal evidence.
   This detached step owns no Core decision, continuation, master processor, or
   realtime callback work.
   Only one debt-owned energy-release arc may
   be grounded, withheld, withheld, then recovered; withheld bars must be silent
   in every kick projection while their canonical weak-pulse carrier remains,
   and recovery must restore a positive step-zero kick. The climax-arc projection
   fingerprints the exact incoming
   dramatic debts paid by an energy release, retains their source classes and
   temporal bounds and, when present, cross-checks the rendered four-bar kick
   recovery.
   The final withheld bar at macro position 14 may also own one bounded
   `terminal-recovery-delay` hang: existing weak pulses stop after step 11, an
   8 ms output release reaches exact zero at step 12, and the last beat remains
   silent while every underlying renderer continuation advances. The next-bar
   recovery remains the exact established score and PCM consequence. It adds
   no onset, lane, instrument, effect, clock, controller, callback work, or
   persistent state. The transaction
   binds the one plan fingerprint, engine/policy/evaluator versions,
   attempt-local reasons, and correction provenance. It permits one initial
   render plus one same-plan home-timbre correction, with two render passes
   total. Both attempts begin from the same
   incoming state. Their evidence records the incoming continuation and the
   outgoing render-plus-generated-DSP state before the quality decision; outer
   commit provenance then binds the chosen transaction, selected sample hash,
   outgoing render/DSP state, finalized quality continuation state, and the
   matching live-master continuation. A pending live proposal is applied to a
   copy of incoming render state and becomes durable only in this atomic commit.
   The candidate binds source observation/proposal identity, route and future
   boundary, incoming/outgoing revisions, requested/applied trim, and exact
   terminal pre/post PCM scaling. Rejected or unavailable work cannot mutate
   continuation or request an untrimmed substitute.

   The shipping evaluator is the exact-engine calibrated primary policy. A
   healthy primary is rendered once; only an explicit home-timbre correction
   causes the same plan to render a second time.
   Phrase analysis now streams across immutable render blocks within a recorded
   6 MiB upper bound. A diverse profile, passing adversarial suite, and disjoint
   holdout qualification qualify complete representative-rate engine banks
   offline and supply the same runtime policy. Cancellation is checked within
   each attempt at bounded bar-render
   and evidence boundaries; route changes cancel detached preparation and
   prevent stale route work from committing.
   This transaction does not feed observations into future composition.
   Offline phrase preflight now measures native stereo with ITU-R BS.1770-5
   K-weighting and two-stage 400 ms gating, and measures true peak with the
   published Annex 2 four-phase FIR. The candidate vector retains analyzed
   frame and gating-block counts, integrated/momentary/short-term loudness,
   loudness spread, and dBTP evidence. It also retains physical-time analysis
   windows with zero-padded radix-two FFT geometry, actual spectral
   centroid/bandwidth/flatness/rolloff, positive flux,
   RMS trajectory, active-window counts, and bounded working-memory provenance.
   The maximum RMS-trajectory delta remains a strict local and within-rate
   trajectory dimension. Because one overlapping maximum can move with the
   route sample grid, cross-rate consistency uses the corresponding mean
   trajectory delta; exact silence retains its dedicated causal evidence and
   upper-only-safer professional dimensions.
   A deterministic Professional Evidence v26
   bank requires every named journey checkpoint for every included sample rate,
   plus complete exact-role masking and stem evidence. The bank remains
   observation-only. `ProfessionalQualityPrimaryArtifacts` validates the exact
   engine-v45 profile v26, adversarial suite v19, and disjoint holdout
   qualification v17.
   The profile derives from 36 complete canonical journeys; four untouched
   replacement journeys passed 56/56 local observations and all trajectory/rate
   relationships. Its evaluator maps the Core-owned plan checkpoint into the
   same 68-metric observation and rejects dimensions independently. The eight
   modal dimensions cover active-bar ratio, event density, pitch error,
   attack/body and tail/body relationships, spectral centroid, masking, and
   maximum pole radius.
   The existing modal-percussion articulation now carries the held rhythm
   world's exact material and a clamped `0...0.6` coupling value. The canonical
   renderer preserves one four-slot voice, extends its stable bank from six to
   eight modes, and drives the final four shell modes feed-forward from the
   first four body modes. Typed score, candidate, and continuation fingerprints
   bind material, coupling, and every mode; malformed state fails closed to the
   prior stable body realization. This adds no independent percussion lane,
   graph, renderer, persistent controller, or callback operation.
   Short-program EBU-style loudness range is retained descriptively rather than
   treated as a gate-discontinuous policy dimension; integrated, momentary,
   short-term, true-peak, and the other stable metrics remain evaluative.
   A preloaded route-local preparation evaluator delegates only when exact
   artifacts exist and the route is 44.1 or 48 kHz; otherwise it reports
   qualification unavailable and cannot commit. Exact operational replay and
   offline generalization pass, but neither constitutes listening approval,
   route/interruption validation, or hardware soak.
5. `AutonomousPhraseRenderer` constructs the required synth world and synth
   performance. The synth planner resolves the three-step driver, five-stage
   follower, chapter articulation, internal architecture and patch, four bounded
   automation coordinates, tone-chapter spectral aperture, eligible effect
   access, and bounded breath-chapter companion timing. Resonant Mono, Tonal
   Motion, and
   Spectral Texture remain specialized voices inside this one renderer; they
   are not alternative runtimes or user-selectable instruments. The planner
   maps the existing acid-thread and acid-sequence patches to ordered-hollow
   and metallic-tension spectral intentions. Resonant Mono currently realizes
   those intentions as a bounded two-operator, dark-to-bright-to-dark aperture
   with a renderer-owned anti-alias budget and low-band-protected modulation
   delta. Non-acid and protected-foundation assignments retain the neutral
   operator path. All Resonant Mono assignments then pass through the one shared
   TPT state-variable filter and first-order antiderivative-antialiased tanh
   core under the existing patch automation. This replaces that architecture's
   former one-pole cascade and private saturator; it adds no parallel renderer.
   The semantic relation is durable; current oscillator ratios,
   index curve, high-pass treatment, and blend are replaceable DSP details that
   require a new versioned evidence contract when changed. The planner also
   maps the Broken Suspension response to the response-only Voltage Arc patch.
   Spectral Texture folds its resolved note into a bounded low polyBLEP saw,
   isolates only the driven upper harmonic tail with a moving TPT band-pass,
   and reuses the existing filtered-reverb send. Same-pass score, event,
   frequency, motion, isolated PCM, low-band, and upper-band evidence keeps the
   capability causal without adding a track, architecture, or effect return.
   The patch and `drivenUpperBand` relation are durable; the current fold,
   filter, drive, and LFO realization is explicitly replaceable in place.
   The planner also consumes the resolved performance character and foundation
   behavior.
   Sub Pulse, Monotone, Point, and Pump become distinct bounded Resonant Mono
   assignments. Kick Tail retains the existing rumble; Tuned Percussive maps
   its existing foundation events into score-owned modal articulations rendered
   by one six-mode stable resonator with four fixed continuation slots; Absent
   stays empty. Upper characters select compatible
   existing patches without creating another renderer.
   Each modal bar records exact score/render event counts, articulation and
   state fingerprints, dry PCM identity, protected/full pass equality, route
   validity, pitch, attack/body/tail, centroid, masking, and pole-stability
   facts. Empty bars and inherited tails remain explicit, so missing or forged
   modal evidence cannot be hidden by another metric.
   The voice renderer applies
   the resolved protagonist contour. An emerging lock or contrast anchor may
   also apply one score-owned spectral-reveal aperture to its existing Resonant
   Mono or Tonal Motion cutoff. Exact home preserves the prior path, downstream
   sends consume the same filtered voice, and no track, instrument, effect bus,
   continuation field, or callback work is added. The renderer may place one
   eligible existing event on
   a filtered send into the canonical late spatial field; neither operation creates another
   onset or topology. The renderer also renders full and protected-rhythm
   layers and mirrors exact dry samples into private kick, foundation,
   percussion, upper-tonal, and atmosphere stems. A bounded preparation-time
   fader resolves only the kick/foundation hierarchy from those stems. This is
   the current adaptive controller; it is not a complete output-evaluation loop.
   Percussion is rendered once per layer, and the exact dry percussion tap feeds
   audible center output, the drum reverb send, and role evidence. The existing
   delicate groove-pulse voice remains under one `GroovePulseResolver` contract.
   `PercussionGear` selects center, middle, or edge contact plus bounded damping
   and seeded microvariation for its fixed 45 ms carrier. On a complete
   eight-pulse syncopated-lean bar, the resolver changes only the existing event
   intensities into a cyclic 3-3-2 accent/ghost relation; onset, count, timing,
   and every other voice remain unchanged. Every other eligible score state
   preserves the prior alternating intensity cell and resolves every pulse to the
   score-owned physical contact. Same-pass event evidence is consumed by the
   calibrated primary evaluator.
   Ordinary closed hats retain the existing 50 ms source and RNG order. When a
   resolved open hat shares the same onset, the score labels only that closed
   hat as its companion and the renderer increases its decay rate; every other
   hat remains neutral. A score without that companion relation is fully neutral,
   and bounded
   same-pass evidence makes the event-local PCM consequence attributable.
   The synth performance also projects the existing bounded `machineTexture`
   state into one pulse-echo return articulation. It is active only for a
   memory-chapter bar with score-enabled pulse echo and an assigned instrument
   that has pulse-echo access, and is neutral for conservative, forced-home,
   identity-return, and major-break paths. The existing three-sixteenth delayed
   sample advances its unchanged feedback write before the band-limited audible
   return reaches a bounded pointwise drive stage. The driven sample therefore
   cannot recirculate through feedback.
   On eligible breath-chapter bars, the same planner delays only existing shadow
   and response notes through one absolute 16-bar align-spread-realign aperture:
   shadow reaches half depth, response reaches full depth, and the maximum is
   `0.12` of one sixteenth step. Anchor, atmosphere, and transition roles remain
   sample-aligned; pitch, velocity, duration, gate intent, density, and
   instrument assignment do not change. Macro endpoints, conservative,
   forced-home, identity-return, and major-break paths resolve exact zero timing.
   The late spatial realization is one eight-line Householder FDN derived from
   the same scene and score. It replaces the former 12–20 second mono feedback
   delay while keeping the separate early reflection, rhythmic delay, pulse
   echo, graph diffusion, and gated-percussion return in their existing roles.
   Flat bounded state continues the tail. Ordinary scene/phrase changes retain
   the active route's delay geometry while decay, damping, send, and wet targets
   slew for 120 ms; only a route-rate change or invalid state resets geometry.
   Same-pass records bind exact input/stereo-wet hashes, initial/final
   parameters, and 250 ms opening/terminal wet measurements to configuration
   and score facts without retaining PCM. Renderer continuation retains only
   the final stereo frame and reduced terminal output/wet RMS; the successor
   compares those facts with its actual opening and rejects a missing required
   field or a seam beyond the existing safety limit.
6. The unchanged pre-fader kick remains the ducking detector. The generated
   graph receives the exact `full - protected-rhythm` remainder, and its output
   is recombined with the protected stereo rhythm route. The protected route
   contains kick, foundation, exact percussion, and inherited shared
   continuation, while excluding newly scheduled upper voices. The remainder
   may still contain upper roles plus shared continuation and nonlinear-mix
   interaction, so it remains named graph-input remainder rather than an
   upper-only stem. Dedicated dry anchor and shadow/response taps retain
   role-local articulation attribution. Masking evidence now compares exact
   post-fader foundation, dry percussion, and combined dry-upper taps over all
   sixteen bar windows. The primary evaluator uses the evidence without applying
   callback-time cuts; the existing authored envelope, kick-linked guard,
   ducking, glue, and output-safety stages remain active. Upper-timbre evidence
   schema 3 (quality-report contract schema 8) retains protected rhythm as its
   masking reference and adds bounded onset-local anchor-velocity observations
   from the exact dry anchor tap.
   Score-owned anchor velocity now projects into the authored filter-envelope
   lift (`0.40...1.60`) and in-gate decay (`0.80...1.20`) while every other role
   stays neutral for this response. Retriggers latch the response and legato
   slides inherit it, preserving persistent tails. Tonal Motion patch changes
   reset filter/envelope identity but retain comb, all-pass, echo, DC, and tail
   memory while comb/echo coefficients move through one bounded 500 ms handoff.
   The reduced evidence records
   applied scales, gain-normalized attack high-band ratio, and tail-to-attack
   ratio; incomplete windows remain explicit and cannot be qualified.
7. `TechnoEngine` prepares away from the callback and schedules completed buffers
   by sample time. It derives its read-only waveform on a fixed decibel scale and
   owns transport, visual position, and route recovery, not musical composition.
   The same detached preparation projects each immutable bar into one bounded
   Render Info snapshot containing score labels, synth assignments, semantic
   automation, generated-graph values, fixed effect states, automatic-mix
   values, and already-reduced render evidence. The main actor exposes the first
   accepted bar in the ready state, then publishes a new snapshot only when its
   matching scheduled bar becomes current. The snapshot contains no PCM and
   causes no callback analysis, allocation, or UI work.
   The main actor separately projects the existing successor task, cache, and
   phrase-boundary fallback into one read-only next-phrase status. It reports
   held, queued, preparing, qualified-and-cached, or retrying state together
   with actual preparation attempts, coherent phrase repeats, one concise
   last-failure stage/code, the finite recovery-wave index, and the accepted
   presentation bars elapsed while the successor remains uncommitted. A
   retryable calibrated rejection never becomes permanently blocked merely
   because one finite wave is exhausted. The detached
   pipeline preserves a
   bounded list of exact failed guards or calibrated metric values and bounds,
   and the main actor writes
   that non-PCM context to the local unified log under the
   `successor-preparation` category. These diagnostics observe the canonical
   scheduler only; they do not authorize a plan, alter a deadline, feed quality
   evidence, retain a root seed or PCM, or execute on the callback.
   Before any bar is accepted, the same projection distinguishes `FIRST P1`
   preparation from successor work and reports a bounded blocked reason to the
   UI and log instead of collapsing every preparation failure into audio-route
   unavailability.
   This presentation also defines the canonical progress monitor. Callback
   continuity, increasing LIVE time, qualified current-render health, and
   rotating repeat-hold sidecars prove only that accepted PCM remains safely
   audible. They do not prove that the score advanced. App/runtime and soak
   evidence must separately retain current phrase/bar, successor target/stage,
   attempts, coherent repeats, last failure, selected qualified hold or exact
   fallback, route, and exact process/build identity. `blocked` or `exhausted`
   is an immediate failed-stall outcome even while accepted PCM continues. An
   unchanged successor tuple across two checkpoints separated by a complete
   current-phrase boundary requires detached-log inspection; if no preparation
   state or log progress occurred, the run is stalled. A ready successor that
   does not win its next eligible boundary is independently a scheduler defect.
   New Set or relaunch changes identity and cannot count as recovery evidence
   for the failed witness. The complete procedure is defined in
   [`AUTONOMOUS_RUNTIME_VALIDATION.md`](AUTONOMOUS_RUNTIME_VALIDATION.md).
   A calibrated guardrail rejection, or a hard-gate rejection for which the
   evaluator proves symbolic phrase interest is the only failed gate, produces
   one bounded structured recovery intent. The rejected plan and PCM never
   commit. The same director and
   incoming state retain identity, debt, and long-horizon ownership while
   deriving a new phrase-local realization. Structural kind is retained while
   at least the canonical four-bar minimum fits before every open-debt
   deadline; the retry length is capped at the earliest deadline so a longer
   variant cannot become deterministically ineligible. If even four bars no
   longer fit, only the later retry uses the existing conservative
   energy-release fallback, because no same-kind canonical phrase can satisfy
   the symbolic interest gate. A symbolic-overactivity rejection directs only
   the final serial realization to resolve every non-marker bar through the
   existing score-side `minimalize` gesture. Insufficient spectral spread or
   movement increases existing timbral motion; insufficient kick crest
   reduction strengthens the existing kick body without selecting the
   high-crest transient-recovery articulation. Every direction preserves
   structural macro markers, identity, debt, selection, energy coordination,
   and calibrated thresholds. It is rendered and evaluated normally and still
   fails closed if any unchanged gate rejects it.
   Ordinal zero and the accepted canonical journey remain unchanged. The bounded serial
   vocabulary also alternates kick attack/body pressure around the same
   continuous score-owned morphology trajectory. Its gentle first step handles
   near-boundary misses without crossing a neighboring source-dynamics gate;
   later steps retain moderate, broad, and full-range recovery. Its negative
   branch softens the existing body drive and sub level together with the
   contour, so the exact post-fader stem can prove a bounded reduction in kick
   active energy when the calibrated kick/foundation relationship is high; the
   positive branch remains the inverse exploration. The final four-bar
   realization replaces further body pressure with one bounded
   transient-clarity articulation: shorter/softer existing body, lower sub, and
   stronger existing clicks. Exact 44.1 kHz source evidence must prove that it
   raises attack/body contrast and lowers crest reduction by more than the
   reproduced coupled P12 miss. The renderer and evaluator must prove every
   resulting PCM movement. The first retry in a wave waits for one coherent
   accepted-PCM repeat. The remaining ordinals then run serially in detached
   preparation instead of consuming another whole phrase per attempt.
   Exhausting the finite wave yields until the next coherent boundary and opens
   a deterministically salted wave, allowing recovery work to continue
   indefinitely without unbounded work at any one boundary. Missing/non-finite
   evidence, unavailable policy, graph or signal-safety failure, and invalid
   route/provenance remain terminal. Ordinal zero remains the original plan; no
   variants coexist, rank one another, or bypass primary qualification.
   The same bounded serial retry continuation applies while preparing the first
   phrase. Because no accepted PCM exists yet, each exhausted finite wave opens
   its deterministic successor immediately and yields between detached tasks;
   a calibrated establishment rejection can therefore keep adapting without a
   user repeating the identical rejected request.
   Accepted canonical score/evidence time and presentation time are distinct.
   Each coherent accepted-PCM repeat advances the bounded long-horizon
   presentation clock, so episode and material-world aging reflect elapsed
   listening time, while accepted-bar ownership, evidence use counts, and
   canonical continuation do not advance until a successor actually commits.
   Recovery never issues Pause or New Set; those remain user-owned transport
   actions.
   Ordinary successor delay also owns one bounded presentation-only fallback,
   `autotechno-repeat-hold-evolution.v4`. Core selects it only from the second
   coherent repeat when at least one matching independently qualified sidecar
   exists. DSP derives five deck chains during detached rendering. Each owns a
   full-mix control-rate-smoothed low-pass gesture plus a grid-locked target memory: one-bar whole
   mix, half-bar protected rhythm, quarter-bar melodic remainder, percussion
   one-eighth/one-sixteenth/one-thirty-second, or kick
   one-sixteenth/one-thirty-second. The kick and percussion role taps are
   transient preparation inputs and never survive into canonical blocks. The
   selected target delta intersects the filtered pre-climax mix before existing
   climax, terminal safety, and master trim. Reduced evidence binds exact phrase
   endpoints, full-mix input routing and protected-source attribution, output
   safety, level consequence, whole-mix high-band reduction, primary versus
   family-specific PCM fingerprints, complete capture count, scheduled replay
   count, shortest grid slice, loop-dry crossfade boundaries, and exact use of
   the captured source. Core rotates through only
   the qualified families and exact accepted PCM remains the fallback when none
   qualify. The selected primary plan, blocks, candidate
   evidence, render/graph continuation, quality decision, and engine-v45
   artifacts remain unchanged. App and Windows transports merely choose the
   immutable family at a phrase boundary, and a ready successor always advances. The
   macOS scheduler does not register sidecar occurrences as canonical live-
   feedback sources, so transformed PCM cannot be attributed to the accepted
   candidate. Both filter and looper state are phrase-scoped detached work; no
   state, capture, analysis, allocation, decision, log, or UI work reaches
   either audio callback.
   Runtime terminal qualification uses one Core-owned checkpoint priority for
   the complete phrase: establishment, long continuation from phrase index 16,
   otherwise the structural kind. An ordinary lock also uses the continuation
   population even when it crosses a chapter boundary, because chapter-change
   observations may belong to a structural phrase. Multi-label evidence remains
   available to offline calibration, but separately calibrated whole-phrase
   populations are never intersected at runtime. Optional active modal evidence
   can use only
   bounds already calibrated from active modal checkpoints when the selected
   checkpoint retained the exact inactive sentinel envelope.
   Upper-spectral reveal activation remains conditional on the existing
   narrative eligibility owner: no eligible score events produce the exact
   neutral value, the ratio is one-sided higher-is-safer, and eligible events
   that fail to render stay rejecting.
   It also owns one scheduled-output feedback coordinator. After an exact
   two-probe mixer/player clock map succeeds, the canonical-capture-mixer callback copies only
   bounded app-owned native-stereo packets into the preallocated C11 queue. A
   detached worker assembles the first exact three-second phrase window, reuses
   BS.1770-5/Annex 2 evidence, and reduces it to one attenuation-only proposal.
   Only an unscheduled successor can consume that proposal, and only the primary
   evaluator can commit its future controller state. See
   [`LIVE_FEEDBACK.md`](LIVE_FEEDBACK.md).
   The player reaches that canonical mixer before the main output mixer. A
   host-local mute/volume state changes only the downstream main-mixer output
   gain on the main actor, so listening attenuation cannot change captured PCM,
   quality, continuation, adaptation, or the performance identity.
8. `AutoTechnoTransport` owns the platform-neutral detached planning, rendering,
   installed-policy evaluation, long-horizon update, and waveform transaction.
   The macOS app adds only its bounded Render Info projection before scheduling.
   The Windows host consumes the same immutable prepared phrase through fixed
   waveOut lookahead. Its completion callback performs only fixed-size atomic
   bookkeeping; allocation, conversion, submission, cleanup, preparation,
   continuation, logging, and UI work remain on non-callback queues.
9. The Windows target is a buildable distribution candidate, not a promoted
   runtime claim. Promotion still requires native verification of New Set and
   read-only inspection parity, scheduled-output feedback ownership or the exact
   canonical fallback contract, route/interruption behavior, clean-machine
   redistribution, accessibility, and physical-output soak.

## Implemented percussion-return-texture slice

The canonical director resolves one optional articulation after ensemble
arbitration. A nonconservative contrast bar with the broken-suspension
character, gear-shift gesture, grounded kick syntax, and an existing eligible
percussion event at or before step seven may select `gatedEcho`. The
articulation identifies the earliest eligible event, admits one score step of
its dry percussion role window, begins the delayed return four steps later, and
closes that output gate after four more steps. On the final kick-withheld bar
before an already-resolved energy-release recovery, the same existing owner may
instead select `anticipationSwell`: one event anchors a one-step input window
on the canonical protected percussion stem, whose bounded wet remainder is
reversed and shaped into a crescendo ending at literal zero at the release
boundary. It adds no event, does not alter the dry percussion score, and has no
cross-bar delay continuation. Every ineligible bar is exact neutral.

Detached rendering reduces the admitted source and bounded return to exact
hashes, peak/RMS, frame geometry, nonzero counts, exact-zero output endpoints,
early/late RMS and rise dB, and full/protected pass agreement. The effect is
part of the protected rhythm path; its combined dry-plus-return signal enters
percussion role analysis and masking, while the dry percussion hash and reverb
source remain attributable to the original events. Candidate evidence
cross-checks the semantic relation against kick syntax and absolute macro
position. No PCM loop or reusable sample survives preparation.

The fixed delay, feedback, filter corners, reverse-wet projection, gain, mono
image, and transition curves are explicitly provisional renderer architecture.
A mature DSP revision may improve interpolation, transient-aware reversal,
stereo placement, filtering, diffusion, nonlinear colour, and perceptual
calibration without changing the score-owned answer-or-anticipation relation,
release boundary, evidence owner, exact legacy gate, or one-runtime
contract. Stateful replacements must decay or fade all residual energy inside
the same bounded output gate and remain sample-indexed and block-partition
independent. Descriptive physical metrics are not optimization targets. Such a revision requires a new
engine/schema identity and exact-head qualification against the frozen
development profile.

## Implemented tonal-envelope expansion slice

`SynthPerformancePlan` owns one durable `sustainedWash` relation on the final
eligible Tonal Motion anchor at a canonical energy-release marker. Eligibility
requires a nonconservative release plan, the existing displaced-kick recovery
signature at macro bar 15, a retriggered motif onset no later than step 12, and
the existing Tonal Motion architecture. The relation changes no onset, pitch,
duration, velocity, gate, instrument assignment, effect permission, density, or
transport. An attempt-local home-timbre correction retains the eligibility fact
while forcing the relation home and
clearing any inherited expanded envelope state before the first corrected
onset.

The current renderer maps this meaning to a bounded sustain target and longer
release inside the existing Tonal Motion ADSR. The voice continuation latches
the semantic relation alongside its existing oscillator, filter, comb,
all-pass, and echo state. Detached rendering uses one pooled isolated signal
buffer, then retains only an event fingerprint, base/applied envelope facts,
exact PCM hash, attack/tail metrics, nonzero count, binding, and finiteness.
No captured PCM or new work reaches the real-time callback.

The exact sustain target, release scale, caps, and ADSR topology are realization
v1. A later serious renderer may replace them with higher-resolution MSEG or
exponential curves, envelope-aware dynamics, oversampled tail colour, or
controlled diffusion only after an objective deficit is demonstrated. It must
replace rather than layer another envelope path, preserve the score meaning and
neutral ineligible behavior, advance engine/schema identities, and provide equivalent or
stronger same-pass evidence.

## Implemented pulse-echo return slice

The current implementation extends the existing score-owned pulse-echo
eligibility and the canonical renderer's single shared, filtered return. Effect
compatibility remains permission to send; drive additionally requires the
score-owned memory-chapter articulation described above. The score clamps its
`machineTexture` source to `0...1` and its applied amount to `0...0.55`. This is
one fixed relationship in the existing renderer, not another graph, an
orderable plug-in chain, captured audio, or a new instrument mode.

Its signal order is invariant: an unchanged dry upper source feeds the existing
pulse-echo send; the undriven delayed sample advances the bounded feedback state;
the audible return is high-passed at 180 Hz and low-passed at 3.2 kHz; one
return-only drive stage then acts before wet recombination. The driven result
never enters the delay buffer or its feedback path. The slice does not change
score events, dry voice PCM, the protected-rhythm route, persistent patch or
phrase identity, or the identity-return score. Conservative and otherwise
ineligible candidates resolve the drive to exact neutral and retain the prior
return behavior.

Each full bar emits same-pass bar/BPM/delay/render geometry, score and drive
eligibility, bounded source and applied amount, current-send RMS, exact pre/post
sample hashes, pre/post peak, RMS, and low-band RMS, difference RMS, and finite
status. Candidate-vector schema 40 binds these observations to the score bar,
phrase kind, route rate, and matching instrument effect access. Neutral drive
requires exact pre/post identity and zero difference. Active drive remains
outside feedback, binds exact changed-frame and peak witnesses, and permits only
the transfer's bounded low-level lift up to `3.2x` RMS. The implementation is
present, and its exact-source local structural, signal, protected-routing, and
release-build matrix passed. This evidence remains one non-compensable input; it
does not alone establish professional quality.

## Implemented band-limited phrase-slice interpolation

`PhraseCompositionResolver` remains the only decision owner for phrase-local
PCM reuse. It still resolves the app-owned percussion or kick source window,
three to four bounded triggers, rates from 0.5 to 2, forward/reverse direction,
gain, and the future phrase boundary. `AudioSliceRenderer` replaces only its
former linear lookup with a fixed 16-sample-radius Hann-windowed sinc kernel.
For faster playback the cutoff is `0.94 / playbackRate` relative to source
Nyquist; unity and slower integer positions retain the exact source sample.
Existing 4 ms edge fades, output geometry, score binding, source/output hashes,
RMS, finiteness, protected/full pass equality, and invalid/ineligible neutral
fallback remain authoritative.

The promotion begins from a capability-local measurement, not a tutorial
coefficient: at 48 kHz, the supported 2x path folded a deterministic 18 kHz
source into a false 12 kHz component at amplitude `0.5`. The replacement
measures below `0.000079` on the same path, about 76 dB lower, while a 3 kHz
source retains its expected 6 kHz result and gain. The motivating channel sweep
supplies the creative use—rare phrase-local rate/reverse transformation of
already-owned material—but no external sample, preset, workstation device,
caption value, or comment enters the score or DSP.

The kernel runs only during detached immutable-PCM preparation. It adds no
continuation state, callback work, lock, file/network I/O, microphone capture,
system audio capture, user control, alternate renderer, effect bus, or granular
side engine. Canonical engine and quality identities advance because non-unity
slice PCM changes; the candidate shape remains stable because its current
same-pass record already binds the exact source, rate/direction geometry,
output PCM, and finite level consequence.

## Implemented AudioReakt long-form source articulation

The canonical `ResolvedPerformanceBar` now owns `kickMorphology`. A
deterministic resolver maps the current long-horizon episode/operator and
presentation-relative bar onto four bounded materials. Maintain, rise, and
recall hold balanced; reframe settles at relaxed; payoff holds a rare resonant
body accent; recovery uses a 32-bar morph to relaxed, a 32-bar relaxed plateau,
and a 32-bar morph to held ghost-soft. The exact score record contains
episode/operator/presentation provenance plus start/end source presence, pitch,
body, sub, harmonic, drive, and click parameters; `VoiceRenderer` interpolates
them inside the existing kick event loop. The authored presence multiplies the
complete source before the existing source dynamics, detector, ducking, and
audible paths. The kick-dynamics accumulator hashes the score record before
reducing the actual source pre/post PCM, and candidate binding rehashes the
resolved record so copied or forged evidence cannot enter preparation.

`UpperPercussionTailArticulation` also owns the physical body of its existing
event. Only `.clap` may resolve clap, snare, or rim; open-hat and metallic
events remain native. Phrase kind plus the already-resolved performance
character select the body. Full/protected rendering produces the same body and
same evidence, while the established tail role remains an independent
post-attack relationship.

Both capabilities are finite, state-free render functions applied during
detached phrase preparation. They allocate no additional PCM lane, introduce no
new continuation owner, and add no callback work. Candidate-vector schema 40
binds morphology and body to the exact score event, PCM hashes, physical-time
windows, and scalar consequence. Missing or invalid episode context falls back
to balanced; omitted body construction falls back to clap for clap events and
native for other upper percussion.

## Implemented pad harmonic-disclosure slice

The canonical phrase-composition resolver now owns a bounded disclosure stage
for its single pad capability. An eligible lock bar must already carry the
atmosphere role; it is realized with that existing four-voice pad rather than a
new role or track. A lock phrase begins with exact tonic-only
concealment, then exposes a tonic-to-modal-color partial relation; a major break
uses the established four-function arc as the revealed payoff. Other eligible
phrases retain the established legacy arc, and identity return is exactly
neutral. The dependent arpeggiator reads the same disclosed function, so the
pad and melodic line cannot tell different harmonic stories.

No track, instrument, effect, sequencer clock, continuation buffer, or callback
work is added. The existing four-voice pad, arpeggiator, modal vocabulary,
renderer, and continuation remain canonical. Candidate evidence binds phrase
geometry and disclosure stage/function to exact score/render arpeggiator pitch
fingerprints and the existing pad PCM/voice-leading record. Professional
observation retains revealed-bar prevalence and the bounded number of disclosed
functions; a five-function adversarial attack is non-compensable. The particular
four-function voicing realization remains replaceable as the synthesis and
mixing stack matures, while progressive harmonic revelation and its causal
score-to-render proof remain durable.

## Implemented pad rhythmic-modulation slice

The canonical phrase-composition resolver now retains one bounded rhythmic
modulation value on an existing `PadVoicing`. It is active only on naturally
resolved latter-half major-break pads, with absolute bar modulo three owning the
cell phase. The renderer reuses the pad's existing low-pass and spatial-reverb
send, then projects the same relation as a closed/open/closed amplitude target
over both dry pad and that existing send. One route-derived 6 ms raised-cosine
attack/release stays inside the open sixteenth. Synth, filter, envelope, and
spatial continuation still advance while closed output is exactly zero. This
creates no note source, clock, instrument, effect return, continuation buffer,
or callback state. Literal neutral retains the previous operation order and PCM
exactly.

Every prepared bar reduces relation, phase, exact pattern identity, applied
filter/send/gate extrema, route-derived transition frames, open/closed counts,
pre/post dry and send hashes, exact closed-step silence, and streamed same-pass
difference RMS into the existing phrase-composition evidence. Professional
observation retains active-bar ratio plus level-relative filter, spatial, and
amplitude-gate difference means. Context, phase, pattern, finite/bounded signal,
exact silence, and active-consequence checks are non-compensable. This v1 scale
and amplitude-mask projection is replaceable DSP; the score-owned held-sound
rhythmic intention, absolute phase, advancing continuation, neutral path, and
evidence remain the durable boundary.

## Implemented dotted foundation-rhythm slice

The canonical director extends the existing resolved foundation score rather
than adding a bass track or renderer-side clock. Eligible four-bar-aligned Lock
pairs replace only their existing bass events with complementary two-bar masks
whose onsets continue at three-sixteenth intervals and reset at the phrase
boundary. The existing protected foundation route, score swing, Resonant Mono
architecture, Bass Pluck patch, TPT/ADAA core, and dry center placement remain
authoritative. Kick, non-bass events, harmony, effects, continuation, and the
callback are unchanged; incomplete or ineligible pairs stay established.

Detached same-pass evidence reduces relation, pair phase, score/render counts
and masks, actual start frames, dry hash/peak/RMS, patch assignment, and
full/protected pass equality into candidate-vector schema 40. Professional
observation retains active prevalence and crest factor under the current
exact-engine profile. A later implementation may replace the integer-grid
projection only while preserving this score owner, two-bar reset, exact neutral
path, and causal evidence.

## Implemented foundation pre-kick pocket slice

The dotted score now derives one bounded articulation for its existing Bass
Pluck exactly one step before kick 4 or 12. Core owns the score event, bass/kick
steps, and release steps. `VoiceRenderer` projects those immutable score steps
at the route rate and passes them into the existing Resonant Mono foundation
render call. A state-free raised-cosine multiplier begins `0.1875` step before
the kick and reaches exact zero `0.0625` step before it. It changes no onset,
kick, non-foundation role, bus, random draw, persistent continuation, scheduler,
or callback operation; malformed and ineligible score paths remain neutral.

The same pass records the natural event end, release and kick frames, positive
release/silence counts, and a streamed hash/peak/RMS of the exact dry-
foundation silence interval. Candidate completeness cross-binds that record to
the resolved event and Bass Pluck assignment and requires full/protected
equality. Professional Evidence v26 adds one upper-only safer silence-RMS
dimension and adversarial suite v14 adds one non-compensable contamination
attack. The present curve and exact-zero proxy are replaceable in place; the
dotted score owner, protected route, neutral fallback, and causal evidence are
durable.

## Implemented upper-role timing slice

The current implementation extends the existing resolved upper-note score and
canonical voice scheduler; it does not introduce another clock, sequencer,
voice, renderer, or continuation state. Eligible breath-chapter bars reuse the
absolute 16-bar macro position to delay existing shadow and response attacks by
the bounded half/full aperture described above. Exact-zero ineligible paths
retain the prior schedule bit for bit.

Each rendered bar records bounded score and actual renderer timing tuples,
including base onset, requested offset, expected and applied onset frame,
requested gate end, and renderer-applied gate end. Separate anchor, shadow, and
response dry taps retain finite role-local hash, peak, and RMS evidence. Current
candidate-vector schema 40 reduces those tuples into exact score/render and
renderer-applied-gate fingerprints, relation-specific offset facts, protected-
role neutrality, cascade-aperture or lead-pattern replay, and route-derived
frame geometry. The calibrated evaluator judges this evidence as part of the
single primary transaction.

## Implemented offline long-horizon semantic evidence

`AutoTechnoCore` owns the versioned
`autotechno-long-horizon-semantic.v1` report and its fixed-capacity streaming
accumulator. Given an exact canonical phrase plan and incoming
`AutonomousSessionState`, it validates seed, phrase, bar, resolved-score,
composition, scalar, and dramatic-debt continuity before atomically retaining
descriptive occupancy, recurrence, scalar movement, dwell, periodicity,
capability use, identity recall, and debt lifecycle evidence. Core retains no
PCM and depends on no DSP type.

The accumulator keeps only fixed enum-domain counters and recurrence slots, 64
recent semantic tokens, 64 periodicity lags, 64 recently used event signatures,
16 non-reconstructable identity landmarks, and 16 dramatic debts. Malformed or
discontinuous input terminates availability with a reason code and cannot
partially apply the rejected phrase. A mid-session observation window imports
the exact bounded outstanding-debt ledger before observing successors. Its
report names the root, starting and
next phrase/bar boundaries, engine/schema versions, and a deterministic
trajectory fingerprint.

This is an offline evidence surface, not a shipped control path. The existing
test-only canonical-journey harness streams the real director and continuation
through it, while `AutonomousSessionState`, `AutonomousSessionDirector`, the
prepared-product transaction, renderer, App scheduler, route lifecycle, and
realtime callback do not consume or mutate this standalone report. Valid reports explicitly carry
`qualificationStatus: unavailable` and
`qualificationReason: no-calibrated-long-horizon-policy`; only the compatible
bounded runtime observation may be judged by the exact v9 policy and applied to
an eligible future boundary. The hierarchy and next ownership
boundary are defined in
[`LONG_HORIZON_PERFORMANCE_MAP.md`](LONG_HORIZON_PERFORMANCE_MAP.md).

## Implemented canonical long-horizon continuation state

`TemporalMusicalMemory` now carries
`autotechno-long-horizon-continuation.v4` as part of the one canonical session
continuation. A fresh `AutonomousSessionState` binds it to the exact performance
root and current phrase/bar boundary. Each successful `advancePlanning` first
applies the committed plan to a proposed hierarchy, then retains the accepted
state alongside existing phrase, debt, narrative, interlock, spatial, and
harmonic memory.

The hierarchy owns one current 8-16-macro material-world episode inside one
renewable 3-6-episode arc. It stores causal world parent/generation/handoff and
six axes, fixed-domain capability, character, harmony, and transformation
recency plus bounded recent episodes/worlds, recent operators, identity
landmarks, obligations, and reserve. Its decoder validates the exact schema and
normalizes all retained capacities. Wrong roots, discontinuous phrase/bar
boundaries, inconsistent canonical plans, exhausted obligation capacity, and
counter overflow return a reason-coded preservation result without partially
advancing the hierarchy. `AutonomousSessionState.advance` treats that result as
a failed atomic commit and preserves every musical, quality, and controller
continuation rather than advancing older memories alone.

Phase 2 introduced this as production continuation state without using it as a
control input. Phase 3 now crosses that explicit boundary: the existing director
may consume only context bound to the exact root, phrase index, and bar for an
unscheduled future phrase. A discontinuous context cannot override the previous
conservative policy.

Phase 7 extends the same state with the last exact reason-coded trajectory
decision and a bounded correction count. It can preserve course or replace only
the unscheduled successor episode with one existing recover episode. Invalid,
stale, early, redundant, wrong-root, or overflowed decisions preserve the
accepted hierarchy. The first exact correction phrase is selected by the same
director as the existing major-break recovery; no second planner or renderer is
introduced.

## Implemented long-horizon episode selection

The one `AutonomousSessionDirector.plan(from:)` call first computes its previous
conservative phrase kind, validates the bound episode, and produces one
`LongHorizonPhraseSelection`. Before the episode minimum hold it preserves local
phrasing while protecting a reserved payoff or recall from early use. At
eligibility it maps maintain/rise/recover/reframe/payoff/recall onto the existing
lock/contrast/major-break/energy-release/identity-return vocabulary. A payoff
without open canonical dramatic debt first chooses contrast, then pays that debt
on the next plan. No second director, candidate, style engine, or renderer is
consulted.

The plan retains Codable schema `autotechno-long-horizon-selection.v1` with the
episode ID, operator, existing phrase kind, and reason-coded path. The selected
kind reaches the existing resolved score and renderer and therefore can change
PCM. Unsupported schemas and internally inconsistent decoded selection records
are rejected, and plan construction replaces phrase-kind-mismatched provenance
with the conservative record. The new provenance adds no DSP parameter or
signal path. The hierarchy
continues to advance only with the committed plan. Wrong-root or discontinuous
selection uses the conservative fallback, while an inconsistent commit still
preserves the whole canonical state transactionally.

This phase changes Core phrase selection and its resulting score/PCM, but not
the render graph, DSP implementation, prepared-product candidate count, App
scheduler, route lifecycle, or realtime callback. Semantic trajectory evidence
describes the changed journey offline; it is not yet a feedback input or a
long-horizon quality verdict.

## Implemented long-horizon energy coordination

After episode selection, the same director resolves one immutable
`autotechno-long-horizon-energy-coordination.v1` record for the exact future
phrase boundary. It binds root-validated episode/operator context indirectly
through the selected plan provenance, then records phrase index, start bar,
existing phrase kind, selection reason, coordination reason, and the canonical
eight-coordinate episode target. Codable decoding rejects unsupported schemas
and inconsistent reason/target combinations.

The target changes only existing score owners: compatible performance character
and foundation behavior, two-to-four admitted roles, one-tier percussion gear,
bounded narrative presence, current harmonic disclosure grammar, existing
transformations, the one spatial carrier, and transition/pulse-echo eligibility
at authored gestures. Identity return remains Hypnotic Lock. Fallback,
payoff/recall reserve, and debt establishment use an explicit all-hold target;
minimum-hold progression cannot spend those rare events early.

Detached candidate preparation rejects a plan whose coordination does not match
its selection and boundary, whose character/foundation is not the canonical
projection, or whose per-bar harmonic relationship diverges. This validation
adds no renderer choice and does not run in the realtime callback. The canonical
renderer consumes the already-resolved existing score, and the accepted
continuation advances only with the same atomic plan transaction. Engine v32 is
retained because this phase recombines already reachable score and renderer
behavior without changing a DSP implementation or calibrated primary policy.
Candidate-plan fingerprint domain `candidate-plan.typed.v21` directly binds the
selection record, energy-coordination record, and every per-bar harmonic
relationship plus the optional effect sentence so provenance-distinct plans
cannot share a transaction identity.

## Implemented long-horizon effect sentence and dose evidence

The same canonical phrase plan derives at most one immutable
`autotechno-long-horizon-effect-sentence.v1` from an already-resolved percussion
return relation. Core owns the musical meaning and exact source/answer geometry;
it does not authorize a new event or signal path. Detached canonical validation
re-derives the annotation before rendering.

After the accepted bounded render exists, `AutoTechnoDSP` can expose
`autotechno-long-horizon-effect-dose.v2`. The reduction joins exact existing
graph-input/output timbre evidence, typed instrument effect access, pulse echo,
percussion return, spatial FDN, and masking records by phrase/bar identity. It
keeps fingerprints, RMS, occupancy, causal flags, and bounded recurrence only;
the prepared block's left/right PCM arrays never enter the report.

The fixed-capacity accumulator is detached from the callback and observes exact
root, phrase, and bar continuity transactionally. It distinguishes current-send
activity, tail-only activity, and a later exact clear bar, retains the last
sixteen realized sentences, and marks malformed/discontinuous evidence
unavailable without changing previously accepted counters. It does not affect
selection, score, rendering, candidate choice, commit eligibility, scheduling,
route handling, or callback work. The exact v9 calibrated policy consumes only
compatible realized trajectory evidence after primary qualification.

## Implemented detached long-horizon signal trajectory

After an immutable prepared phrase has passed playback hard gates,
`AutoTechnoDSP` can derive
`autotechno-long-horizon-signal-trajectory.v1`. The record binds the exact root,
phrase/bar boundary, coordination target, typed plan fingerprint, candidate-
evidence fingerprint, PCM fingerprint, and route sample rate to reduced
loudness, true-peak, crest, spectrum, transient, masking, wet/dry, stereo, and
movement dimensions. It joins the already accepted full-mix and effect-dose
records by exact bar identity. Raw blocks, samples, stems, graph state, and
renderer continuation never enter the trajectory report.

The fixed-capacity accumulator supports either contiguous accepted phrases or
representative detached checkpoints. Every skipped phrase and bar is counted so
sparse renders cannot masquerade as continuous PCM. It retains metric ranges,
per-operator physical deltas, bounded episode summaries, the latest 32 phrases
and transitions, and the latest 16 episodes. Root, rate, ordering, episode re-
entry, evidence consistency, and counter arithmetic fail closed
transactionally. The semantic target remains distinct from the realized vector;
the evidence layer does not decide that a rise, recovery, payoff, or recall
succeeded.

This reduction runs only after detached preparation. It changes no score,
renderer, graph, scheduler, route lifecycle, live controller, commit decision,
or realtime callback. Phase 6B binds compatible complete reports to the exact
immutable engine-v45/primary-v26 development, adversarial, and disjoint-holdout
artifacts. Raw PCM remains outside the artifacts and runtime observation.

## Implemented bounded long-horizon future adaptation

`AutoTechnoDSP` owns `autotechno-long-horizon-runtime-observation.v2` and a
fixed-capacity `LongHorizonFutureAdaptationState`. Detached preparation reduces
only an accepted prepared phrase into semantic, operator/signal, and effect
evidence. The runtime state validates exact root, phrase/bar continuity, route
sample rate, and bundled profile identity. It keeps independent signal
accumulators for every calibrated profile rate, but evaluates only the active
route rate. A complete runtime decision requires at least 7,200 observed bars,
twelve signal observations, two realized transitions for every operator at the
active rate, and the next 256-bar interval. Structural invalidity discards the
partial runtime state and cannot authorize a decision. The observation contains
no PCM, samples, waveform, block, stem, renderer continuation, or graph state.

The decision factory emits strict Core schema
`autotechno-long-horizon-trajectory-decision.v2`. Each non-compensable semantic,
operator/signal, and effect failure maps to its own reason; a fully qualified
report maps to `preserve`. A failed report maps to `recover` only when the
projected canonical continuation can legally accept the future correction.
Core alone applies that decision to continuation v3.

`TechnoEngine` carries the exact incoming and outgoing adaptation state with the
one immutable prepared successor. The cache-acceptance guard includes the
incoming adaptation fingerprint. Phrase acceptance advances session, quality,
live-master, and long-horizon adaptation state as one transaction. Route
recovery restores the interrupted phrase's incoming adaptation state, rerenders
at the active rate, and advances it once; late or stale work cannot double-count
the interrupted phrase or replay a payoff as new. Shutdown clears the state.

Planning, reduction, artifact evaluation, and decision construction remain in
detached preparation. No render callback, C handoff, audio buffer, graph,
renderer, or sample scheduler was changed. The main actor only installs the
already-immutable accepted result at the existing scheduled phrase boundary.

## Completed evidence-gated sound maturation assessment

Phase 8 reconciles the exact engine-v45/primary-v26 sound capabilities with the
long-horizon-v13 profile, adversarial suite, and disjoint holdout. Their
fingerprints are `6139c62f14150a56`, `41f2f0052adc68b3`, and
`9c73ae998d25f693`. The primary profile, adversarial suite, and holdout are
independently pinned as `49533dcd68238f05`, `b0733d1aad0de785`, and
`81f20d011441fa5f`. All six current artifacts replay byte for byte. The physical
percussion promotion stays inside the existing score/voice/evidence owners;
other capability families remain unchanged.

No Core decision, resolved score, DSP parameter, render graph, prepared product,
App scheduler, route lifecycle, audio buffer, continuation, or callback changes
for this assessment. A later sound replacement requires repeated independent-
root failures at both representative rates while the score, primary phrase
verdict, route, and unrelated sound-family evidence remain valid. Until then,
the current renderer and neutral/protected paths remain canonical.

## Canonical unified loop

All future musical development extends one persistent loop:

```text
persistent state
  -> generate one bounded semantic plan
  -> render immutable future audio
  -> evaluate planned structure and app-owned PCM
  -> qualify, adjust, or reject that plan
  -> commit plan, render, graph, evaluator, and controller state
  -> adapt only a future sample-indexed boundary
```

This is one mechanism with specialized planners, voices, effects, analyzers, and
controllers. Chapters, synthesis strategies, topology changes, and additional
auto-controlled parameters are internal states of that mechanism, not alternate
engines or user-selectable profiles. A new implementation must state which
existing state and score it extends, which shared render path it uses, which
evidence evaluates it, and how it preserves continuation. If a genuinely new DSP
primitive is needed, it joins the canonical renderer and is selected by the same
score; it does not create a parallel runtime.

The evaluator owns hard safety qualification, professional-quality evidence, and
long-form comparison against the committed history. Controllers own bounded
corrections such as role balance. The session director consumes only qualified,
bounded observations and remains the sole owner of future musical decisions.
Independent controllers must not compete over the same role or parameter; coupled
decisions share one state, bounds, slew policy, and home target.

## Scheduled-output feedback boundary

Detached preparation analyzes its rendered buffers directly. The scheduled-
output path additionally copies app-owned PCM from the canonical-capture-mixer callback into
a fixed-capacity, preallocated C11 single-writer exchange. Invalid tap input
returns before the producer; valid input performs only pointer/frame guards,
reads the sample position, calls the bounded producer, and returns. It never
allocates, locks, waits, analyzes, hashes, logs, performs
file or network I/O, calls UI code, or changes musical state. If the exchange is
full, feedback is dropped and the callback continues.

The canonical capture mixer feeds a separate downstream main output mixer.
Monitoring mute and volume affect only that downstream node; they are excluded
from scheduled occurrence identity, callback packets, evidence, controller
state, and deterministic replay.

A bounded background analyzer consumes the first complete three-second
sample-indexed window of an authenticated scheduled occurrence. It never opens a
microphone, captures ambient or system audio, or analyzes content the app does
not own. Each observation names its source range, occurrence epoch, route,
controller revision, plan, exact installed profile, and earliest eligible future
boundary. One authenticated scheduled occurrence may invalidate one still-
unscheduled successor. A repeated phrase at a newer authenticated range is a
different occurrence unless preserve-course recovery already owns that
source-to-target relationship. A decision may affect only that immutable future
candidate and is applied at its declared sample boundary after primary
acceptance.
Late evidence is ignored or deferred unless the source is the exact playing
occurrence and the target is still unscheduled; late evidence alone never
latches an accepted-PCM hold. That hold begins only when an already authorized
correction is rejected, unavailable, or misses its first boundary. The next
matching boundary releases canonical preserve-course preparation under the
already committed controller state; the candidate remains primary-qualified
and no later correction can replace recovery before score advance.

Route, pause/resume, and timeline reset rotate lifecycle identity and discard
stale packets/results. Route and timeline resets preserve an existing hold and
latch an outstanding authorized correction. A newer authenticated occurrence
cannot authorize another correction while recovery owns the transition. Only a
successfully advanced corrected or preserve-course successor, complete session
reset, or shutdown clears it. No analysis rewrites the current buffer or a
scheduled bar.
The complete contract is [`LIVE_FEEDBACK.md`](LIVE_FEEDBACK.md).

## Reproducibility and product boundary

Fresh-session selection and deterministic replay are separate contracts. A
complete performance boundary chooses a new opaque root seed; after selection,
the same explicit seed, private initial state, and accepted, sample-indexed
feedback state must reproduce the same plan, decision, graph, samples,
controller evolution, and outgoing continuation state. Exact
observation/proposal identity also requires identical packet count and
first/last packet sequence, counters, and ranges.
Valid alternate packetization of the same contiguous PCM may retain the PCM
fingerprint, BS.1770 measurements, and numeric controller outcome, but it changes
evidence and proposal fingerprints. Evaluation inputs and
terminal outcomes are part of continuation provenance, not ambient hidden state.
Route recovery must retain or deterministically rebuild them at the active
sample rate.

The selected `PreparedAutonomousPhrase` and its immutable scheduled blocks are
the only rendered-material commitment. The runtime does not capture or resample
its output into a reusable loop, sample library, or new score source, and it does
not retain a transformed return beyond that prepared phrase. Repetition and
layering are regenerated from the canonical score and continuation inside the
same bounded transaction.

There are no runtime profiles, selectable seeds, reference generators, optional
scene/synth inputs, microphone inputs, or alternate executable entry points.
Historical measurements and retired experiments are evidence only; they do not
re-enter the product architecture.
