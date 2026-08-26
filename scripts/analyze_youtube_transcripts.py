#!/usr/bin/env python3
"""Normalize yt-dlp captions and build a bounded technical review index.

The script keeps downloaded captions outside the repository. Its JSON output is
an evidence index for human/agent review, not a musical-quality decision.
"""

from __future__ import annotations

import argparse
import html
import json
import re
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path


TIMING_RE = re.compile(
    r"^(?P<h>\d{2}):(?P<m>\d{2}):(?P<s>\d{2})[.,](?P<ms>\d{3})\s+-->"
)
TAG_RE = re.compile(r"<[^>]+>")
SPACE_RE = re.compile(r"\s+")


# This is deliberately an audit vocabulary, not a product recommendation list.
# It lets a channel sweep retain exact named-device evidence while the final
# repository review decides whether the named behavior is already owned,
# belongs outside the standalone product boundary, or exposes a measurable
# capability deficit. Keep aliases specific enough to avoid generic terms such
# as "live", "analog", "random", or "utility" matching ordinary speech.
NAMED_MENTIONS: tuple[tuple[str, str, tuple[str, ...]], ...] = (
    ("Ableton Analog", "ableton_instrument", ("ableton analog",)),
    ("Ableton Collision", "ableton_instrument", ("ableton collision", "collision instrument")),
    ("Ableton Drift", "ableton_instrument", ("ableton drift", "ableton's drift", "drift synth")),
    ("Ableton Meld", "ableton_instrument", ("ableton meld", "ableton live 12 meld", "meld synth")),
    ("Ableton Operator", "ableton_instrument", ("ableton operator", "ableton's operator", "operator synth", "an operator")),
    ("Ableton Sampler", "ableton_instrument", ("ableton sampler",)),
    ("Ableton Simpler", "ableton_instrument", ("ableton simpler",)),
    ("Ableton Drum Sampler", "ableton_instrument", ("drum sampler", "new drum sampler")),
    ("Ableton Tension", "ableton_instrument", ("ableton tension", "tension instrument")),
    ("Ableton Wavetable", "ableton_instrument", ("ableton wavetable", "wavetable synth")),
    ("Granulator II/III", "ableton_instrument", ("granulator ii", "granulator 2", "granulator iii", "granulator 3")),
    ("Drum Rack", "ableton_instrument", ("drum rack", "drum racks")),
    ("Ableton Arpeggiator", "ableton_midi_effect", ("ableton arpeggiator", "arpeggiator device")),
    ("Ableton Chord", "ableton_midi_effect", ("ableton chord", "chord midi effect")),
    ("Ableton Random", "ableton_midi_effect", ("ableton random", "random midi effect")),
    ("Ableton Scale", "ableton_midi_effect", ("ableton scale", "scale midi effect")),
    ("Auto Filter", "ableton_audio_effect", ("auto filter",)),
    ("Auto Pan", "ableton_audio_effect", ("auto pan", "autopan")),
    ("Beat Repeat", "ableton_audio_effect", ("beat repeat",)),
    ("Chorus-Ensemble", "ableton_audio_effect", ("chorus-ensemble", "chorus ensemble")),
    ("Corpus", "ableton_audio_effect", ("ableton corpus", "corpus resonator", "corpus device")),
    ("Drum Buss", "ableton_audio_effect", ("drum buss", "drum bus device")),
    ("Echo", "ableton_audio_effect", ("ableton echo", "echo device")),
    ("Envelope Follower", "ableton_audio_effect", ("envelope follower",)),
    ("Erosion", "ableton_audio_effect", ("ableton erosion", "erosion effect")),
    ("Frequency Shifter", "ableton_audio_effect", ("frequency shifter",)),
    ("Glue Compressor", "ableton_audio_effect", ("glue compressor",)),
    ("Grain Delay", "ableton_audio_effect", ("grain delay",)),
    ("Hybrid Reverb", "ableton_audio_effect", ("hybrid reverb",)),
    ("LFO", "ableton_audio_effect", ("ableton lfo", "lfo device", "max for live lfo")),
    ("Looper", "ableton_audio_effect", ("ableton looper", "looper device", "looper of ableton", "ableton have a looper")),
    ("Phaser-Flanger", "ableton_audio_effect", ("phaser-flanger", "phaser flanger")),
    ("Redux", "ableton_audio_effect", ("ableton redux", "redux effect")),
    ("Resonators", "ableton_audio_effect", ("ableton resonators", "resonators device")),
    ("Roar", "ableton_audio_effect", ("ableton roar", "ableton live 12 roar", "roar effect")),
    ("Saturator", "ableton_audio_effect", ("ableton saturator", "saturator device")),
    ("Shifter", "ableton_audio_effect", ("ableton shifter", "shifter device")),
    ("Spectral Resonator", "ableton_audio_effect", ("spectral resonator",)),
    ("Spectral Time", "ableton_audio_effect", ("spectral time",)),
    ("Align Delay", "ableton_audio_effect", ("align delay",)),
    ("Ableton Utility", "ableton_audio_effect", ("ableton utility", "utility device")),
    ("Vocoder", "ableton_audio_effect", ("ableton vocoder", "vocoder")),
    ("PunchBOX", "third_party_plugin", ("punchbox", "punch box")),
    ("Kick 2", "third_party_plugin", ("kick 2", "kick2")),
    ("Solstice", "third_party_plugin", ("solstice by minuit", "minuit solstice")),
    ("HydroSwarm", "third_party_plugin", ("hydroswarm", "hydro swarm")),
    ("Sting", "third_party_plugin", ("sting 2", "sting 2.05", "sting sequencer", "developer of sting", "sting by")),
    ("Augur", "third_party_plugin", ("augur +", "augur sequencer", "augur midi")),
    ("Celestine", "third_party_plugin", ("celestine",)),
    ("Slink Filter", "third_party_plugin", ("slink filter",)),
    ("DYAD", "third_party_plugin", ("dyad sequencer", "dyad tutorial")),
    ("Knob Studio", "third_party_plugin", ("knob studio",)),
    ("Drip", "third_party_plugin", ("drip fx", "drip plugin", "drip plug in")),
    ("Tape Fiasco 2", "third_party_plugin", ("tape fiasco", "tape fiasco 2")),
    ("SpaceBlender", "third_party_plugin", ("space blender", "spaceblender")),
    ("HyperPlash", "third_party_plugin", ("hyperplash", "hyper plash")),
    ("Tardigrain", "mobile_audio_app", ("tardigrain", "tardy grain")),
    ("AUM", "mobile_audio_app", ("using aum", "use aum", "a u m mixer")),
    ("FabFilter Volcano", "third_party_plugin", ("fabfilter volcano", "fab filter volcano")),
    ("Valhalla Freq Echo", "third_party_plugin", ("valhalla frequency echo", "valhalla freq echo", "frequency echo")),
    ("Surge XT", "third_party_plugin", ("surge xt", "surge synth", "surge synthesizer")),
    ("Modulation Delay", "max_for_live", ("modulation delay",)),
    ("Modulation Loop/Math", "max_for_live", ("modulation loop", "modulation lup", "modulation math")),
    ("Faderboard", "max_for_live", ("faderboard", "fader board")),
    ("Tree Tone", "max_for_live", ("tree tone", "three tone")),
    ("Snake sequencer", "max_for_live", ("snake sequencer", "here yeah snake")),
    ("Robert Henke Granulator", "max_for_live", ("robert henke", "robert enke")),
    ("Euclidean Sequencer Pro", "sequencer", ("euclidean sequencer pro",)),
    ("MIDI Tools Polyrhythm", "ableton_midi_effect", ("midi tools", "poly rthm", "polyrhythm generator")),
    ("Phase Plant", "third_party_plugin", ("phase plant",)),
    ("Serum", "third_party_plugin", ("xfer serum", "serum synth")),
    ("Vital", "third_party_plugin", ("vital synth",)),
    ("Diva", "third_party_plugin", ("u-he diva", "uhe diva")),
    ("Pigments", "third_party_plugin", ("arturia pigments",)),
    ("FabFilter Pro-Q", "third_party_plugin", ("fabfilter pro-q", "fabfilter pro q", "pro-q 3", "pro q 3")),
    ("FabFilter Pro-C", "third_party_plugin", ("fabfilter pro-c", "fabfilter pro c", "pro-c 2", "pro c 2")),
    ("Valhalla reverb", "third_party_plugin", ("valhalla room", "valhalla vintage verb", "valhalla supermassive")),
    ("Soundtoys", "third_party_plugin", ("soundtoys", "echo boy", "echoboy", "decapitator")),
    ("ShaperBox", "third_party_plugin", ("shaperbox", "volume shaper", "volumeshaper")),
    ("Portal", "third_party_plugin", ("output portal", "portal granular")),
    ("Thermal", "third_party_plugin", ("output thermal", "thermal distortion")),
    ("Torso S-4", "hardware", ("torso s-4", "torso s4")),
    ("SOMA Cosmos", "hardware", ("soma cosmos", "+ cosmos")),
    ("Elektron Digitakt", "hardware", ("elektron digitakt", "digitakt")),
    ("Elektron Digitone", "hardware", ("elektron digitone", "digitone")),
    ("Novation Peak", "hardware", ("novation peak",)),
    ("Moog DFAM", "hardware", ("moog dfam", "dfam")),
    ("Cwejman SM-1", "hardware", ("cwejman sm-1", "cwejman sm1")),
    ("Topobrillo filter", "hardware", ("topobrillo filter", "topper brillo filter")),
    ("Arturia KeyStep", "hardware", ("arturia keystep", "key step")),
    ("Ableton Push", "hardware", ("ableton push",)),
    ("Chase Bliss Blooper", "hardware", ("chase bliss blooper", "blooper pedal")),
    ("Chase Bliss Dark World", "hardware", ("chase bliss dark world", "dark world pedal")),
    ("Eurorack modular", "hardware", ("eurorack", "modular system", "modular synth")),
    ("Bitwig Frequency Split", "daw_effect", ("bitwig frequency split", "frequency split")),
    ("Bitwig modulation system", "daw_modulation", ("bitwig modulation system",)),
)

TECHNIQUE_MENTIONS: tuple[tuple[str, str, tuple[str, ...]], ...] = (
    ("compression", "effect_family", ("compressor", "compression", "kompressor")),
    ("equalization", "effect_family", ("eq eight", "eq8", "equalizer", "equalization", "eqing", "eq-ing")),
    ("reverb", "effect_family", ("reverb", "hallgerät", "faltungshall")),
    ("delay/echo", "effect_family", ("delay", "echo", "verzögerung")),
    ("saturation/distortion", "effect_family", ("saturator", "saturation", "distortion", "overdrive", "wavefold", "wave fold", "verzerrung")),
    ("gate/ducking", "effect_family", ("noise gate", "gating", "sidechain", "ducking", "side chain")),
    ("limiting/clipping", "effect_family", ("limiter", "clipper", "clipping")),
    ("chorus/phaser/flanger", "effect_family", ("chorus", "phaser", "flanger")),
    ("resonator/physical modelling", "effect_family", ("resonator", "resonators", "physical modeling", "physical modelling")),
    ("frequency/pitch shifting", "effect_family", ("frequency shifter", "pitch shifter", "frequency shifting", "pitch shifting")),
    ("granular/resampling", "processing_technique", ("granular", "granulator", "resample", "resampling", "time stretch", "time-stretch")),
    ("looping/stutter memory", "processing_technique", ("glitch stutter", "stutter engine", "looper of ableton", "ableton looper", "looping effect", "loop little segments")),
    ("feedback/self-generation", "processing_technique", ("feedback loop", "self-generating", "self generating", "feedback music", "rückkopplung")),
    ("return/send processing", "effect_chain", ("return channel", "return track", "send effect", "send channel", "return chain")),
    ("serial effect chain", "effect_chain", ("effect chain", "effects chain", "fx chain", "signal chain")),
    ("effect rack/macro", "effect_chain", ("audio effect rack", "effect rack", "macro control", "macro knob")),
    ("parallel/multiband processing", "effect_chain", ("parallel processing", "parallel chain", "multiband", "frequency split")),
    ("automated filter motion", "automation_technique", ("automated filter", "filter automation", "modulated filter", "filter sequencer", "filter movement")),
    ("multi-target modulation", "automation_technique", ("modulation matrix", "cross modulation", "complex modulation", "constant modulation", "moving modulation")),
    ("random/probability sequencing", "sequencing_technique", ("random sequence", "randomized pattern", "probability", "turing machine", "generative midi", "generative sequence")),
    ("polyrhythm/polymeter", "sequencing_technique", ("polyrhythm", "polymeter", "polyrhythmus")),
    ("kick synthesis/layering", "instrument_technique", ("kick synthesis", "kick layer", "click layer", "body layer", "kick rumble", "reverb kick")),
    ("percussion vocoding", "instrument_technique", ("vocoder for percussion", "vocoder percussion", "vocoded percussion")),
)


CATEGORY_TERMS: dict[str, tuple[str, ...]] = {
    "synthesis": (
        "operator", "oscillator", "wavetable", "analog", "fm", "frequency modulation",
        "ring modulation", "noise oscillator", "granulator", "granular", "synth",
        "synthesis", "waveform", "sine wave", "saw wave", "square wave", "resonator",
    ),
    "filter_modulation": (
        "auto filter", "filter", "cutoff", "resonance", "envelope follower", "lfo",
        "automation", "modulation", "modulate", "movement", "macro", "random",
        "shaper", "step modulation", "filterfrequenz", "hüllkurve", "modulieren",
        "modulationen", "bewegung",
    ),
    "effects": (
        "echo", "delay", "reverb", "return channel", "send", "chorus", "phaser",
        "flanger", "frequency shifter", "shifter", "saturator", "distortion", "drive",
        "compression", "compressor", "gate", "convolution", "rack", "effect chain",
        "effektkette", "hall", "verzerrung", "kompressor", "rückkopplung",
    ),
    "rhythm": (
        "groove", "rhythm", "polyrhythm", "polymeter", "arpeggiator", "sequencer",
        "swing", "syncop", "offbeat", "sixteenth", "velocity", "accent", "ghost note",
        "euclidean", "probability", "rhythmus", "polyrhythmus", "sequenz",
        "wahrscheinlichkeit",
    ),
    "percussion": (
        "hi-hat", "hi hat", "hat", "percussion", "drum", "kick", "snare", "clap",
        "rim", "rimshot", "shaker", "tom", "conga", "bongo", "ride", "cymbal",
        "transient", "schlagzeug", "perkussion", "trommel",
    ),
    "kick_foundation": (
        "kick", "rumble", "reverb kick", "kick bass", "kick and bass", "kick drum",
        "punch", "thump", "click layer", "body layer", "kick tail", "bassdrum",
    ),
    "snare_clap": (
        "snare", "clap", "rimshot", "rim shot", "snare wire", "snare body",
        "snare noise",
    ),
    "tonal_voice": (
        "lead", "stab", "pluck", "chord", "pad", "horn", "acid", "303", "arp",
        "arpeggio", "drone", "sequence", "sequenced synth",
    ),
    "timbre_layering": (
        "layering", "layer", "effect chain", "fx chain", "parallel", "resample",
        "resampling", "morph", "variation", "texture", "noise layer", "schichten",
    ),
    "low_end": (
        "bassline", "bass line", "sub bass", "sub-bass", "low end", "low-end", "rumble",
        "mono", "sidechain", "duck", "phase", "fundamental", "tiefton", "basslinie",
    ),
    "space_stereo": (
        "stereo", "width", "wide", "depth", "foreground", "background", "mid side",
        "mid-side", "panning", "pan", "haas", "mono compatible", "atmosphere",
    ),
    "mix_dynamics": (
        "mix", "master", "loudness", "limiter", "clipper", "headroom", "level",
        "gain staging", "eq", "equalizer", "dynamic range", "crest", "reference track",
        "lautstärke", "mischen", "mastering",
    ),
    "arrangement_harmony": (
        "arrangement", "tension", "energy", "contrast", "breakdown", "transition",
        "chord", "harmony", "melody", "scale", "mode", "voice leading", "call and response",
    ),
    "sampling_texture": (
        "sample", "resample", "resampling", "slice", "texture", "field recording",
        "granulator", "granular", "reverse", "stretch", "paulstretch", "warp",
        "aufnahme", "abspielen", "rückwärts",
    ),
    "workflow_only": (
        "finish tracks", "finish your", "productivity", "mindset", "workflow", "habit",
        "label", "career", "depression", "community", "retreat", "template",
    ),
}

TECHNICAL_CATEGORIES = tuple(name for name in CATEGORY_TERMS if name != "workflow_only")


@dataclass(frozen=True)
class Cue:
    seconds: float
    text: str


def cue_seconds(match: re.Match[str]) -> float:
    return (
        int(match.group("h")) * 3600
        + int(match.group("m")) * 60
        + int(match.group("s"))
        + int(match.group("ms")) / 1000
    )


def clean_caption_line(value: str) -> str:
    value = html.unescape(TAG_RE.sub("", value))
    return SPACE_RE.sub(" ", value).strip()


def parse_vtt(path: Path) -> list[Cue]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    cues: list[Cue] = []
    index = 0
    previous = ""
    while index < len(lines):
        match = TIMING_RE.match(lines[index])
        if not match:
            index += 1
            continue
        seconds = cue_seconds(match)
        index += 1
        while index < len(lines) and not lines[index].strip():
            index += 1
        body: list[str] = []
        while (index < len(lines) and lines[index].strip()
               and not TIMING_RE.match(lines[index])):
            cleaned = clean_caption_line(lines[index])
            if cleaned:
                body.append(cleaned)
            index += 1
        if not body:
            continue
        # YouTube rolling captions repeat the previous line and append the new
        # fragment as the final line. Keeping the last line avoids retaining the
        # rolling duplicate while preserving timestamped technical language.
        text = body[-1]
        if text == previous:
            continue
        previous = text
        cues.append(Cue(seconds=seconds, text=text))
    return cues


def format_time(seconds: float) -> str:
    total = int(seconds)
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


def term_pattern(term: str) -> re.Pattern[str]:
    return re.compile(r"(?<![a-z0-9])" + re.escape(term) + r"(?![a-z0-9])", re.IGNORECASE)


PATTERNS = {
    category: tuple(term_pattern(term) for term in terms)
    for category, terms in CATEGORY_TERMS.items()
}

MENTION_PATTERNS = {
    name: tuple(term_pattern(alias) for alias in aliases)
    for name, _, aliases in NAMED_MENTIONS
}
MENTION_KINDS = {name: kind for name, kind, _ in NAMED_MENTIONS}
TECHNIQUE_PATTERNS = {
    name: tuple(term_pattern(alias) for alias in aliases)
    for name, _, aliases in TECHNIQUE_MENTIONS
}
TECHNIQUE_KINDS = {name: kind for name, kind, _ in TECHNIQUE_MENTIONS}

# A very small set of caption-review records retains devices whose spoken name
# is materially corrupted or absent in automatic captions. These entries never
# invent parameters: they preserve the ambiguity explicitly in the audit.
MANUAL_VIDEO_MENTIONS: dict[str, tuple[tuple[str, str], ...]] = {
    "04xckljRLCU": (
        ("Unresolved Max sequencer ('ML' in caption)", "max_for_live"),
    ),
    "wMZDGfg8lxw": (
        ("Unresolved phone effects app", "mobile_audio_app"),
    ),
    "8WoLDwrOW04": (
        ("Surge (caption-inferred)", "third_party_plugin"),
        ("Unresolved free limiter/compressor", "third_party_plugin"),
    ),
}


def cue_categories(cue: Cue) -> set[str]:
    return {
        category
        for category, patterns in PATTERNS.items()
        if any(pattern.search(cue.text) for pattern in patterns)
    }


def context_excerpt(cues: list[Cue], index: int, radius: int = 1) -> dict[str, object]:
    start = max(0, index - radius)
    end = min(len(cues), index + radius + 1)
    return {
        "timestamp": format_time(cues[index].seconds),
        "seconds": cues[index].seconds,
        "text": " ".join(cue.text for cue in cues[start:end]),
        "categories": sorted(cue_categories(cues[index])),
    }


def select_excerpts(cues: list[Cue], limit: int = 18) -> list[dict[str, object]]:
    ranked: list[tuple[int, int]] = []
    for index, cue in enumerate(cues):
        categories = cue_categories(cue)
        technical = categories.intersection(TECHNICAL_CATEGORIES)
        if not technical:
            continue
        specificity = len(technical) * 3
        specificity += sum(
            1 for patterns in PATTERNS.values() for pattern in patterns if pattern.search(cue.text)
        )
        ranked.append((specificity, index))

    selected: list[int] = []
    for _, index in sorted(ranked, key=lambda item: (-item[0], cues[item[1]].seconds)):
        if any(abs(cues[index].seconds - cues[other].seconds) < 20 for other in selected):
            continue
        selected.append(index)
        if len(selected) == limit:
            break
    return [context_excerpt(cues, index) for index in sorted(selected)]


def load_inventory(path: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        # yt-dlp's print templates preserve ``\\t`` literally; accept that
        # durable representation as well as a hand-authored TSV.
        separator = "\\t" if "\\t" in line else "\t"
        parts = line.split(separator, 4)
        if len(parts) != 5:
            continue
        index, video_id, duration, title, url = parts
        rows.append(
            {
                "playlist_index": int(index),
                "id": video_id,
                "duration_seconds": int(float(duration)),
                "title": title,
                "url": url,
            }
        )
    return rows


def find_file(video_dir: Path, suffix: str) -> Path | None:
    matches = sorted(video_dir.glob(f"*{suffix}"))
    return matches[0] if matches else None


def load_metadata(path: Path | None) -> dict[str, object]:
    if path is None:
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def select_caption(
    video_dir: Path,
    metadata: dict[str, object],
) -> tuple[Path | None, str | None, str | None]:
    """Prefer manual English, then an original-language caption.

    Translated automatic tracks can corrupt product names and technical claims.
    We therefore use English only when it is manual or explicitly original,
    then the video's declared original language (notably German in the Mordio
    archive), and finally a bounded filename fallback for older corpora.
    """

    subtitles = metadata.get("subtitles") or {}
    automatic = metadata.get("automatic_captions") or {}
    if not isinstance(subtitles, dict):
        subtitles = {}
    if not isinstance(automatic, dict):
        automatic = {}

    manual_english = sorted(
        language for language in subtitles if language == "en" or language.startswith("en-")
    )
    declared = str(metadata.get("language") or "").lower().split("-", 1)[0]
    original_automatic = sorted(
        language for language in automatic
        if language.endswith("-orig") and language.split("-", 1)[0] in {"en", declared}
    )
    manual_original = sorted(
        language for language in subtitles
        if declared and language.split("-", 1)[0] == declared
    )

    priorities = (
        ("manual", manual_english),
        ("automatic", [language for language in original_automatic if language.startswith("en-")]),
        ("manual", manual_original),
        ("automatic", original_automatic),
    )
    for kind, languages in priorities:
        for language in languages:
            caption = find_file(video_dir, f".{language}.vtt")
            if caption is not None:
                return caption, kind, language

    # Preserve bounded coverage for older corpora whose info JSON did not keep
    # caption dictionaries. This fallback is explicitly reported as unknown.
    for language in ("en-orig", "de-orig", "en", "de"):
        fallback = find_file(video_dir, f".{language}.vtt")
        if fallback is not None:
            return fallback, "unknown", language
    return None, None, None


def evidence_mentions(
    title: str,
    description: str,
    cues: list[Cue],
    entries: tuple[tuple[str, str, tuple[str, ...]], ...],
    patterns_by_name: dict[str, tuple[re.Pattern[str], ...]],
    kinds_by_name: dict[str, str],
) -> list[dict[str, object]]:
    """Retain bounded title/description/caption evidence and contexts."""

    results: list[dict[str, object]] = []
    for name, _, _ in entries:
        patterns = patterns_by_name[name]
        sources: list[str] = []
        contexts: list[dict[str, object]] = []
        if any(pattern.search(title) for pattern in patterns):
            sources.append("title")
        if any(pattern.search(description) for pattern in patterns):
            sources.append("description")
        for index, cue in enumerate(cues):
            if any(pattern.search(cue.text) for pattern in patterns):
                if "caption" not in sources:
                    sources.append("caption")
                if len(contexts) < 8:
                    contexts.append(context_excerpt(cues, index))
        if sources:
            results.append(
                {
                    "name": name,
                    "kind": kinds_by_name[name],
                    "sources": sources,
                    "contexts": contexts,
                }
            )
    return results


def metadata_fields(data: dict[str, object]) -> dict[str, object]:
    if not data:
        return {}
    return {
        "upload_date": data.get("upload_date"),
        "timestamp": data.get("timestamp"),
        "channel": data.get("channel"),
        "availability": data.get("availability"),
        "subtitles": sorted((data.get("subtitles") or {}).keys()),
        "automatic_captions": sorted((data.get("automatic_captions") or {}).keys()),
        "language": data.get("language"),
    }


def analyze(corpus: Path, access_date: str, source: str) -> dict[str, object]:
    rows = load_inventory(corpus / "inventory.tsv")
    normalized = corpus / "normalized"
    normalized.mkdir(parents=True, exist_ok=True)
    videos: list[dict[str, object]] = []
    totals: Counter[str] = Counter()

    for row in rows:
        index = int(row["playlist_index"])
        video_id = str(row["id"])
        video_dirs = sorted((corpus / "videos").glob(f"{index:03d}-{video_id}"))
        direct_video_dir = corpus / "videos" / video_id
        video_dir = (
            video_dirs[0]
            if video_dirs
            else direct_video_dir if direct_video_dir.is_dir() else corpus / "__missing__"
        )
        info = find_file(video_dir, ".info.json")
        metadata = load_metadata(info)
        vtt, caption_kind, caption_language = select_caption(video_dir, metadata)
        cues = parse_vtt(vtt) if vtt else []
        counts: Counter[str] = Counter()
        for cue in cues:
            counts.update(cue_categories(cue))
        totals.update(counts)

        transcript_path = normalized / f"{index:03d}-{video_id}.txt"
        if cues:
            transcript_path.write_text(
                "\n".join(f"[{format_time(cue.seconds)}] {cue.text}" for cue in cues) + "\n",
                encoding="utf-8",
            )

        title_lower = str(row["title"]).lower()
        description = str(metadata.get("description") or "")
        mentions = evidence_mentions(
            str(row["title"]), description, cues,
            NAMED_MENTIONS, MENTION_PATTERNS, MENTION_KINDS
        )
        present_names = {mention["name"] for mention in mentions}
        for name, kind in MANUAL_VIDEO_MENTIONS.get(video_id, ()):
            if name not in present_names:
                mentions.append(
                    {
                        "name": name,
                        "kind": kind,
                        "sources": ["manual-caption-review"],
                        "contexts": [],
                    }
                )
        techniques = evidence_mentions(
            str(row["title"]), description, cues,
            TECHNIQUE_MENTIONS, TECHNIQUE_PATTERNS, TECHNIQUE_KINDS
        )
        original_mix = "original mix" in title_lower or "orignal mix" in title_lower
        workflow_only = counts["workflow_only"] > 0 and sum(
            counts[name] for name in TECHNICAL_CATEGORIES
        ) == 0
        videos.append(
            {
                **row,
                **metadata_fields(metadata),
                "caption_status": "available" if cues else "unavailable",
                "caption_kind": caption_kind if cues else None,
                "caption_language": caption_language if cues else None,
                "caption_path": str(vtt.relative_to(corpus)) if vtt else None,
                "normalized_path": (
                    str(transcript_path.relative_to(corpus)) if cues else None
                ),
                "cue_count": len(cues),
                "category_counts": dict(sorted(counts.items())),
                "original_mix": original_mix,
                "workflow_only": workflow_only,
                "technical_excerpts": select_excerpts(cues),
                "named_mentions": mentions,
                "technique_mentions": techniques,
            }
        )

    return {
        "schema": "autotechno-video-transcript-audit.v3",
        "source": source,
        "access_date": access_date,
        "inventory_count": len(rows),
        "caption_available_count": sum(v["caption_status"] == "available" for v in videos),
        "english_caption_count": sum(
            v["caption_status"] == "available"
            and str(v["caption_language"] or "").startswith("en")
            for v in videos
        ),
        "caption_unavailable_count": sum(v["caption_status"] == "unavailable" for v in videos),
        "caption_language_counts": dict(sorted(Counter(
            str(v["caption_language"])
            for v in videos if v["caption_status"] == "available"
        ).items())),
        "named_mention_totals": dict(sorted(Counter(
            mention["name"]
            for video in videos for mention in video["named_mentions"]
        ).items())),
        "technique_mention_totals": dict(sorted(Counter(
            mention["name"]
            for video in videos for mention in video["technique_mentions"]
        ).items())),
        "category_totals": dict(sorted(totals.items())),
        "videos": videos,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("corpus", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--source",
        required=True,
        help="Canonical channel or playlist URL used to create the inventory",
    )
    parser.add_argument(
        "--access-date",
        required=True,
        help="UTC/local research date in YYYY-MM-DD form",
    )
    args = parser.parse_args()
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", args.access_date):
        parser.error("--access-date must use YYYY-MM-DD")
    output = args.output or args.corpus / "audit.json"
    report = analyze(args.corpus, args.access_date, args.source)
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in report if key != "videos"}, indent=2))


if __name__ == "__main__":
    main()
