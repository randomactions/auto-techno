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


CATEGORY_TERMS: dict[str, tuple[str, ...]] = {
    "synthesis": (
        "operator", "oscillator", "wavetable", "analog", "fm", "frequency modulation",
        "ring modulation", "noise oscillator", "granulator", "granular", "synth",
        "synthesis", "waveform", "sine wave", "saw wave", "square wave", "resonator",
    ),
    "filter_modulation": (
        "auto filter", "filter", "cutoff", "resonance", "envelope follower", "lfo",
        "automation", "modulation", "modulate", "movement", "macro", "random",
        "shaper", "step modulation",
    ),
    "effects": (
        "echo", "delay", "reverb", "return channel", "send", "chorus", "phaser",
        "flanger", "frequency shifter", "shifter", "saturator", "distortion", "drive",
        "compression", "compressor", "gate", "convolution", "rack", "effect chain",
    ),
    "rhythm": (
        "groove", "rhythm", "polyrhythm", "polymeter", "arpeggiator", "sequencer",
        "swing", "syncop", "offbeat", "sixteenth", "velocity", "accent", "ghost note",
        "euclidean", "probability",
    ),
    "percussion": (
        "hi-hat", "hi hat", "hat", "percussion", "drum", "kick", "clap", "rim",
        "shaker", "tom", "ride", "cymbal", "transient",
    ),
    "low_end": (
        "bassline", "bass line", "sub bass", "sub-bass", "low end", "low-end", "rumble",
        "mono", "sidechain", "duck", "phase", "fundamental",
    ),
    "space_stereo": (
        "stereo", "width", "wide", "depth", "foreground", "background", "mid side",
        "mid-side", "panning", "pan", "haas", "mono compatible", "atmosphere",
    ),
    "mix_dynamics": (
        "mix", "master", "loudness", "limiter", "clipper", "headroom", "level",
        "gain staging", "eq", "equalizer", "dynamic range", "crest", "reference track",
    ),
    "arrangement_harmony": (
        "arrangement", "tension", "energy", "contrast", "breakdown", "transition",
        "chord", "harmony", "melody", "scale", "mode", "voice leading", "call and response",
    ),
    "sampling_texture": (
        "sample", "resample", "resampling", "slice", "texture", "field recording",
        "granulator", "granular", "reverse", "stretch", "paulstretch", "warp",
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


def metadata_fields(path: Path | None) -> dict[str, object]:
    if path is None:
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {
        "upload_date": data.get("upload_date"),
        "timestamp": data.get("timestamp"),
        "channel": data.get("channel"),
        "availability": data.get("availability"),
        "subtitles": sorted((data.get("subtitles") or {}).keys()),
        "automatic_captions": sorted((data.get("automatic_captions") or {}).keys()),
    }


def analyze(corpus: Path, access_date: str) -> dict[str, object]:
    rows = load_inventory(corpus / "inventory.tsv")
    normalized = corpus / "normalized"
    normalized.mkdir(parents=True, exist_ok=True)
    videos: list[dict[str, object]] = []
    totals: Counter[str] = Counter()

    for row in rows:
        index = int(row["playlist_index"])
        video_id = str(row["id"])
        video_dirs = sorted((corpus / "videos").glob(f"{index:03d}-{video_id}"))
        video_dir = video_dirs[0] if video_dirs else corpus / "__missing__"
        vtt = find_file(video_dir, ".en.vtt")
        info = find_file(video_dir, ".info.json")
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
        original_mix = "original mix" in title_lower or "orignal mix" in title_lower
        workflow_only = counts["workflow_only"] > 0 and sum(
            counts[name] for name in TECHNICAL_CATEGORIES
        ) == 0
        videos.append(
            {
                **row,
                **metadata_fields(info),
                "caption_status": "english" if cues else "unavailable",
                "caption_path": str(vtt.relative_to(corpus)) if vtt else None,
                "normalized_path": (
                    str(transcript_path.relative_to(corpus)) if cues else None
                ),
                "cue_count": len(cues),
                "category_counts": dict(sorted(counts.items())),
                "original_mix": original_mix,
                "workflow_only": workflow_only,
                "technical_excerpts": select_excerpts(cues),
            }
        )

    return {
        "schema": "autotechno-video-transcript-audit.v1",
        "source": "https://www.youtube.com/@hypnotictechnoproduction/videos",
        "access_date": access_date,
        "inventory_count": len(rows),
        "english_caption_count": sum(v["caption_status"] == "english" for v in videos),
        "caption_unavailable_count": sum(v["caption_status"] == "unavailable" for v in videos),
        "category_totals": dict(sorted(totals.items())),
        "videos": videos,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("corpus", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--access-date",
        required=True,
        help="UTC/local research date in YYYY-MM-DD form",
    )
    args = parser.parse_args()
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", args.access_date):
        parser.error("--access-date must use YYYY-MM-DD")
    output = args.output or args.corpus / "audit.json"
    report = analyze(args.corpus, args.access_date)
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in report if key != "videos"}, indent=2))


if __name__ == "__main__":
    main()
