---
name: evolve-techno-taste
description: Turn subjective listening feedback into small deterministic music-engine rules and repeatable comparisons. Use for groove, arrangement, tension, sound-design, variation, or style changes intended to make Auto Techno learn the user's taste.
---

# Evolve Techno Taste

1. Capture one concrete listening observation: what happened, when, and whether it should occur more or less often.
2. Translate it into a falsifiable rule over musical state. Avoid adjectives without a measurable engine consequence.
3. Choose 3 to 5 fixed seeds that expose the behavior. Preserve them before editing.
4. Change the smallest layer that owns the decision: composition and arrangement in `AutoTechnoCore`; rendering and timbre in `AutoTechnoApp`.
5. Add a deterministic unit test for structural rules. For timbre, add an offline render or stable signal metric when available.
6. Compare before and after at matched loudness and identical controls. Change only one musical idea per comparison.
7. Record the observation and outcome in the project taste ledger once it exists.

Read [references/taste-model.md](references/taste-model.md) when introducing high-level controls, preference storage, ratings, or learned models.
