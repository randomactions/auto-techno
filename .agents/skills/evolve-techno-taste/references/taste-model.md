# Taste model boundaries

Treat taste as evidence accumulated from explicit comparisons, not as a single style prompt.

Store future observations with: fixed seed, engine version, control values, compared variants, preference strength, and a short reason. Keep raw listening evidence separate from derived rules so rules can be revised.

Learn high-level planning or parameter priors off the audio thread. Keep playback usable without a network connection or model service. A learned layer may propose decisions; the deterministic engine must validate and render them.

Prefer interpretable control dimensions such as energy, tension, density, hypnosis, aggression, brightness, chaos, and release only when each maps to documented low-level consequences.
