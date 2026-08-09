---
name: protect-realtime-audio
description: Review or implement Auto Techno audio rendering without glitches, priority inversions, or unsafe callback work. Use whenever changing AVAudioEngine graphs, render callbacks, sample-time scheduling, DSP, buffers, parameter handoff, live feedback, recording, or audio performance.
---

# Protect Real-time Audio

1. Identify every function that can execute on the audio render thread. Do not
   infer safety from a type or framework name.
2. Keep callback work fixed and bounded. Forbid allocation, locks, waits,
   analysis, file or network I/O, logging, UI work, model inference, and unbounded
   loops.
3. Preallocate buffers and DSP state before playback. Pass immutable parameters
   and evidence through atomic or single-writer lock-free snapshots with explicit
   ownership and lifecycle.
4. Keep composition planning, seeded mutation, quality evaluation, arrangement,
   and controller decisions off the callback. Prepare immutable future audio and
   schedule it by sample time with lookahead.
5. If hybrid feedback is required, copy only a fixed amount of app-owned PCM into
   a preallocated lock-free handoff. Analyze fixed sample-indexed windows in
   bounded background work and apply decisions only to unscheduled future audio.
   Never access a microphone or block playback when feedback is late or dropped.
6. Handle route, sample-rate, buffer-size, interruption, device, sleep/wake,
   cancellation, and stale-work changes explicitly.
7. Validate optimized release builds under sustained autonomous playback. Check
   underruns, successor deadlines, CPU headroom, memory stability, controller
   bounds, pause/resume, sleep/wake, interruption, and output-device switching.
8. Add deterministic DSP, handoff, scheduling, overflow, stale-packet, fallback,
   and offline replay tests wherever the changed path permits.

Sample-time lookahead scheduling is the current baseline. Preserve coherent
prepared playback when a successor or feedback decision is late; never reintroduce
timer-driven sequencing or callback-time planning.
