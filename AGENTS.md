# Repository guidance

Keep the product standalone: core playback must not require a DAW, plug-in host, cloud model, or account.

Read `docs/PRODUCT.md` before changing controls, scene state, randomization, transition behavior, or the audio architecture. Preserve its central invariant: every interaction is a musical intention, and both the destination and transition must be coherent.

Do not expose direct DSP controls in the primary UI. Use listener-facing musical language. Show technical state in a read-only **Under the hood** inspector, including current and target values changing in real time and their originating musical intention. Keep telemetry off the audio callback and coalesce it for UI display. Do not merely rename one DSP parameter as one friendly control; semantic controls coordinate multiple musical and rendering decisions.

Preserve deterministic behavior in `AutoTechnoCore`: the same seed and controls must produce the same musical decisions. Keep audio rendering out of the core so rules remain easy to test.

Prefer small, audible increments. For musical changes, compare fixed seeds and record the listening observation that motivated the rule. Use `.agents/skills/evolve-techno-taste` for taste changes and `.agents/skills/protect-realtime-audio` when changing the render path.

Never allocate memory, lock, perform file or network I/O, log, or invoke UI work on a real-time audio callback.
