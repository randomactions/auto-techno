#!/usr/bin/env python3
"""Render a complete, reviewable Markdown ledger from a transcript audit JSON."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


GRANULAR_NAMES = {
    "Ableton Drum Sampler",
    "Celestine",
    "Chase Bliss Blooper",
    "Granulator II/III",
    "HyperPlash",
    "Looper",
    "Robert Henke Granulator",
    "Solstice",
    "SOMA Cosmos",
    "Tape Fiasco 2",
    "Tardigrain",
    "Torso S-4",
}

KICK_NAMES = {"Kick 2", "PunchBOX"}
SEQUENCER_NAMES = {
    "Ableton Arpeggiator",
    "Ableton Chord",
    "Ableton Random",
    "Ableton Scale",
    "Arturia KeyStep",
    "Augur",
    "DYAD",
    "Euclidean Sequencer Pro",
    "MIDI Tools Polyrhythm",
    "Snake sequencer",
    "Sting",
    "Unresolved Max sequencer ('ML' in caption)",
}
MODULATION_NAMES = {
    "Ableton Utility",
    "Envelope Follower",
    "Faderboard",
    "HydroSwarm",
    "Knob Studio",
    "LFO",
    "Modulation Delay",
    "Modulation Loop/Math",
    "Slink Filter",
}

TECHNIQUE_OWNERS = {
    "automated filter motion": "semantic color/shape/motion plus score-owned filter motion",
    "chorus/phaser/flanger": "GeneratedDSPGraph chorus/phaser/stereo-motion nodes",
    "compression": "kick/source conditioning, mix balancer, and master headroom",
    "delay/echo": "pulse echo, unsynced echo, and graph echo nodes",
    "effect rack/macro": "one score-owned semantic coordinate mapped across existing graph nodes",
    "equalization": "tone guards, source filtering, masking evidence, and mix balance",
    "feedback/self-generation": "bounded protected returns and deterministic FDN/echo feedback",
    "frequency/pitch shifting": "bounded transposition, FM/ring relations, and graph modulation",
    "gate/ducking": "kick ducking, pad rhythmic gate, and gated protected returns",
    "granular/resampling": "PROMOTED: phrase-local slicer granular-memory texture",
    "kick synthesis/layering": "continuous kick morphology and source-dynamics evidence",
    "limiting/clipping": "ADAA source conditioning plus live no-boost headroom controller",
    "looping/stutter memory": "PROMOTED: phrase-local slicer granular-memory texture",
    "multi-target modulation": "score-owned semantic coordinates and bounded modulation relations",
    "parallel/multiband processing": "protected low end, role stems, graph routing, and masking evaluation",
    "percussion vocoding": "modal/tonal percussion interaction; no duplicate vocoder lane",
    "polyrhythm/polymeter": "director cycles, relational percussion, and phrase composition",
    "random/probability sequencing": "seeded director and score; exact replay preserved",
    "resonator/physical modelling": "modal percussion, Resonant Mono, spectral resonator, and graph resonator",
    "return/send processing": "protected return, anticipation return, pulse echo, and FDN sends",
    "reverb": "FDN, diffusion graph, anticipation return, and space semantic",
    "saturation/distortion": "ADAA conditioning, saturation, wavefold, and graph drive",
    "serial effect chain": "one bounded GeneratedDSPGraph under the canonical score",
}


def markdown_cell(value: object) -> str:
    text = str(value or "").replace("|", "\\|").replace("\n", " ")
    return " ".join(text.split())


def named_owner(name: str, kind: str) -> tuple[str, str]:
    if name == "Unresolved free limiter/compressor":
        return (
            "source conditioning, mix balancer, and live no-boost master headroom",
            "name remains unresolved; limiter/compressor behavior is already owned",
        )
    if name in GRANULAR_NAMES:
        return (
            "existing phrase-local AudioSlicePlan/AudioSliceRenderer",
            "hypothesis evidence; converges on granular-memory, not a cloned product",
        )
    if name in KICK_NAMES:
        return (
            "kick morphology plus KickSourceDynamics",
            "reconciled; the preceding AudioReakt slice already matured the measured deficit",
        )
    if name in SEQUENCER_NAMES or kind in {"ableton_midi_effect", "sequencer"}:
        return (
            "canonical director, relational cycles, arpeggiator, and resolved score",
            "reconciled; no parallel sequencer or user preset selector",
        )
    if name in MODULATION_NAMES or kind == "daw_modulation":
        return (
            "semantic color/shape/motion/space and score-owned modulation relations",
            "reconciled; existing bounded multi-target automation owns the behavior",
        )
    if kind in {"ableton_audio_effect", "daw_effect", "max_for_live"}:
        return (
            "GeneratedDSPGraph, protected returns, FDN, source conditioning, or phrase composition",
            "reconciled unless included in the single granular-memory promotion",
        )
    if kind in {"ableton_instrument", "third_party_plugin"}:
        return (
            "Resonant Mono, Tonal Motion, Spectral Texture, kick/percussion, or canonical graph",
            "reconciled by behavior; no VST dependency or branded preset clone",
        )
    if kind == "mobile_audio_app":
        return (
            "standalone boundary plus existing internal sampler/space graph",
            "workflow host is out of scope; reusable behavior is reconciled internally",
        )
    if kind == "hardware":
        return (
            "existing internal synth/percussion/sample owners under one score",
            "hardware workflow is evidence only; no external-device dependency",
        )
    return (
        "canonical score and DSP owners",
        "reconciled; caption evidence does not justify a duplicate runtime owner",
    )


def video_disposition(video: dict[str, object]) -> str:
    if video["caption_status"] == "unavailable":
        return "U — title/metadata only; no caption-dependent technical claim"
    named = {item["name"] for item in video["named_mentions"]}
    techniques = {item["name"] for item in video["technique_mentions"]}
    if named & GRANULAR_NAMES or techniques & {
        "granular/resampling", "looping/stutter memory"
    }:
        return "H — contributes to the bounded granular-memory hypothesis"
    if named or techniques:
        return "R — reconciled to an existing owner or standalone boundary"
    return "N — no bounded synth/FX/chain claim in the usable evidence"


def render(audit: dict[str, object]) -> str:
    videos = audit["videos"]
    unavailable = audit["caption_unavailable_count"]
    available = audit["caption_available_count"]
    dispositions = {key: 0 for key in ("H", "R", "U", "N")}
    for video in videos:
        dispositions[video_disposition(video)[0]] += 1
    lines = [
        "# MORDIO YouTube channel DSP audit",
        "",
        f"Source: [{audit['source']}]({audit['source']})",
        f"Inventory/access date: {audit['access_date']}",
        f"Coverage: **{len(videos)}/{len(videos)} videos inventoried**, "
        f"**{available} original-language caption tracks analyzed**, "
        f"**{unavailable} title/metadata-only records**.",
        "Disposition totals: "
        f"**H {dispositions['H']} / R {dispositions['R']} / "
        f"U {dispositions['U']} / N {dispositions['N']}**.",
        "",
        "This is a reproducible source ledger, not a plugin shopping list or listening approval. "
        "The raw metadata/captions remain outside Git. Original-language captions were preferred "
        "to machine translations; unavailable captions support title/metadata claims only. Product "
        "mentions motivate behavioral hypotheses, then the repository's one-score/one-renderer "
        "contracts decide whether a capability is already owned, out of scope, or measurably absent.",
        "",
        "## Result",
        "",
        "One repeated deficit survived reconciliation: the existing whole-window phrase slicer had "
        "no overlapping micrograin texture. The channel contains repeated granular, looping, "
        "stutter, feedback-sampler, and resampling examples across independent videos. The bounded "
        "promotion therefore extends `AudioSlicePlan`/`AudioSliceRenderer` in place with deterministic "
        "`granular-memory` for Ambient Drift. Broken Suspension retains the exact `cut` path. "
        "All source PCM is bar-local, grain geometry is bounded, the score owns the seed, exact "
        "evidence binds seed/geometry/source positions/PCM, and the real-time callback is unchanged.",
        "",
        "Every other named synth, instrument, effect, effect chain, sequencing device, or automation "
        "technique maps to an existing canonical owner or the standalone boundary; no repeatable "
        "measured deficit justified another engine, branded clone, preset browser, or fixed arrangement.",
        "",
        "Disposition legend: **H** hypothesis contributor; **R** reconciled; **U** caption unavailable; "
        "**N** no bounded DSP claim.",
        "",
        "## Named-device reconciliation",
        "",
        "| Named item | Kind | Videos | Canonical owner | Result |",
        "|---|---:|---:|---|---|",
    ]
    kind_by_name: dict[str, str] = {}
    for video in videos:
        for mention in video["named_mentions"]:
            kind_by_name.setdefault(mention["name"], mention["kind"])
    for name, count in audit["named_mention_totals"].items():
        kind = kind_by_name[name]
        owner, result = named_owner(name, kind)
        lines.append(
            f"| {markdown_cell(name)} | {markdown_cell(kind)} | {count} | "
            f"{markdown_cell(owner)} | {markdown_cell(result)} |"
        )

    lines += [
        "",
        "## Effect, chain, and automation reconciliation",
        "",
        "| Technique | Videos | Canonical owner/result |",
        "|---|---:|---|",
    ]
    for name, count in audit["technique_mention_totals"].items():
        owner = TECHNIQUE_OWNERS.get(
            name, "canonical score/DSP owner; no duplicate mechanism justified"
        )
        lines.append(f"| {markdown_cell(name)} | {count} | {markdown_cell(owner)} |")

    language_counts = ", ".join(
        f"`{language}` {count}"
        for language, count in audit["caption_language_counts"].items()
    )
    lines += [
        "",
        "## Complete video ledger",
        "",
        f"Caption tracks by selected language: {language_counts}.",
        "",
        "| # | Video | Evidence | Named items | Techniques/chains | Disposition |",
        "|---:|---|---|---|---|---|",
    ]
    for video in videos:
        url = f"https://www.youtube.com/watch?v={video['id']}"
        evidence = (
            f"{video['caption_kind']} `{video['caption_language']}`"
            if video["caption_status"] == "available"
            else "caption unavailable"
        )
        names = "; ".join(item["name"] for item in video["named_mentions"]) or "—"
        techniques = "; ".join(
            item["name"] for item in video["technique_mentions"]
        ) or "—"
        lines.append(
            f"| {video['playlist_index']} | [{markdown_cell(video['title'])}]({url}) | "
            f"{markdown_cell(evidence)} | {markdown_cell(names)} | "
            f"{markdown_cell(techniques)} | {markdown_cell(video_disposition(video))} |"
        )
    lines += [
        "",
        "## Limits",
        "",
        "This audit proves inventory and text-evidence reconciliation, not critical listening, "
        "hardware-route behavior, or equivalence to any named product. Caption errors are retained "
        "as uncertainty: an ambiguous product name is not promoted into a technical claim. The "
        "implemented capability is original, bounded, deterministic, and judged only through the "
        "repository's exact-engine automated qualification loop.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("audit", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--expected-count", type=int, default=None)
    args = parser.parse_args()
    audit = json.loads(args.audit.read_text(encoding="utf-8"))
    if args.expected_count is not None and audit["inventory_count"] != args.expected_count:
        raise SystemExit(
            f"inventory mismatch: {audit['inventory_count']} != {args.expected_count}"
        )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render(audit), encoding="utf-8")


if __name__ == "__main__":
    main()
