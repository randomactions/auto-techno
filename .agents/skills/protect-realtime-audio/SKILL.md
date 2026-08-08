---
name: protect-realtime-audio
description: Review or implement Auto Techno audio rendering without glitches, priority inversions, or unsafe callback work. Use whenever changing AVAudioEngine graphs, render callbacks, scheduling, DSP, buffers, parameter handoff, recording, or audio performance.
---

# Protect Real-time Audio

1. Identify every function that can execute on the audio render thread. Do not infer safety from a type or framework name.
2. Keep callback work bounded. Forbid allocation, locks, file or network I/O, logging, UI work, and unbounded loops.
3. Preallocate buffers and DSP state before playback. Pass parameters through an atomic or lock-free snapshot with clear ownership.
4. Keep composition planning, seeded mutation, model inference, and arrangement generation off the callback. Feed immutable events to rendering ahead of time.
5. Handle route, sample-rate, buffer-size, interruption, and device changes explicitly.
6. Validate release builds under sustained playback while manipulating controls. Check underruns, CPU headroom, memory stability, stop/start, sleep/wake, and output-device switching.
7. Add deterministic DSP tests and offline renders for signal behavior where practical.

Treat timer-based scheduling in the initial scaffold as a prototype limitation. Before claiming production timing, move sequencing to sample-time scheduling with a look-ahead event queue.
