#!/usr/bin/env python3
"""
Word-first puzzle generator: pick easy words, cross them into a compact grid,
then group results by grid silhouette so each silhouette becomes a level shape
with many different word fills.

Usage:
    python tools/generate_word_first.py [--attempts N] [--shapes-per-spec K] [--seed S]

Adds shapes to data/grid_shapes.json, puzzles to data/puzzle_bank.json and
levels to data/level_data.json. Re-running replaces earlier "wf_" entries.
"""

import argparse
import json
import random
from collections import defaultdict
from pathlib import Path

DATA = Path(__file__).parent.parent / "data"
TOOLS = Path(__file__).parent

MAX_RANK = 2500
MAX_DIM = 5
MAX_PUZZLES = 30
MIN_PUZZLES = 6

# Word lengths per level group, in increasing difficulty.
SPECS = [
    [4, 3, 3],
    [5, 3, 3],
    [4, 4, 3, 3],
    [5, 4, 3, 3],
    [5, 4, 4, 3],
    [5, 5, 3, 3],
]


def load_words():
    freq = {}
    with open(TOOLS / "frequency_dict.txt", encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if parts and parts[0].isalpha() and parts[0].lower() not in freq:
                freq[parts[0].lower()] = len(freq) + 1
    with open(DATA / "words7.txt", encoding="utf-8") as fh:
        valid = {w.strip().lower() for w in fh if w.strip().isalpha()}
    easy = [w for w in valid if freq.get(w, 10**9) <= MAX_RANK and 3 <= len(w) <= 5]
    by_len = defaultdict(list)
    for w in easy:
        by_len[len(w)].append(w)
    return valid, by_len, freq


def try_place(grid, orient, word, r, c, d):
    """Place word at (r,c) going direction d (0=H, 1=V). Returns new cells or None."""
    dr, dc = (0, 1) if d == 0 else (1, 0)
    n = len(word)
    if (r - dr, c - dc) in grid or (r + dr * n, c + dc * n) in grid:
        return None
    crossings = 0
    new = []
    for i, ch in enumerate(word):
        p = (r + dr * i, c + dc * i)
        if p in grid:
            if grid[p] != ch or d in orient[p]:
                return None
            crossings += 1
        else:
            # sideways neighbours must be empty or the word would touch another
            for s in ((dc, dr), (-dc, -dr)):
                if (p[0] + s[0], p[1] + s[1]) in grid:
                    return None
            new.append((p, ch))
    if crossings != 1:
        return None
    return new


def build(spec, by_len):
    words = [random.choice(by_len[n]) for n in spec]
    if len(set(words)) != len(words):
        return None
    grid, orient, placed = {}, {}, []
    first = words[0]
    for i, ch in enumerate(first):
        grid[(0, i)] = ch
        orient[(0, i)] = {0}
    placed.append((first, 0, 0, 0))
    for w in words[1:]:
        options = []
        for (pw, pr, pc, pd) in placed:
            d = 1 - pd
            for i, a in enumerate(pw):
                for j, b in enumerate(w):
                    if a == b:
                        r = pr + (i if pd == 1 else 0) - (j if d == 1 else 0)
                        c = pc + (i if pd == 0 else 0) - (j if d == 0 else 0)
                        options.append((r, c, d))
        random.shuffle(options)
        for r, c, d in options:
            new = try_place(grid, orient, w, r, c, d)
            if new is not None:
                for i, ch in enumerate(w):
                    p = (r + (i if d == 1 else 0), c + (i if d == 0 else 0))
                    grid[p] = ch
                    orient.setdefault(p, set()).add(d)
                placed.append((w, r, c, d))
                break
        else:
            return None
    rs = [p[0] for p in grid]
    cs = [p[1] for p in grid]
    r0, c0 = min(rs), min(cs)
    rows, cols = max(rs) - r0 + 1, max(cs) - c0 + 1
    if rows > MAX_DIM or cols > MAX_DIM:
        return None
    norm = {(r - r0, c - c0): ch for (r, c), ch in grid.items()}
    return rows, cols, norm, sorted(words)


def runs_ok(norm, rows, cols, valid, expected):
    """Every run of >=2 letters must be a valid word and match the chosen word count."""
    found = []
    for horizontal in (True, False):
        for a in range(rows if horizontal else cols):
            run = ""
            for b in range((cols if horizontal else rows) + 1):
                p = (a, b) if horizontal else (b, a)
                if p in norm:
                    run += norm[p]
                else:
                    if len(run) >= 2:
                        found.append(run)
                    run = ""
    return len(found) == expected and all(w in valid for w in found)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--attempts", type=int, default=400_000)
    ap.add_argument("--shapes-per-spec", type=int, default=2)
    ap.add_argument("--seed", type=int, default=None)
    args = ap.parse_args()
    if args.seed is not None:
        random.seed(args.seed)

    valid, by_len, freq = load_words()
    shapes_path, bank_path, levels_path = (
        DATA / "grid_shapes.json", DATA / "puzzle_bank.json", DATA / "level_data.json")
    shapes = json.loads(shapes_path.read_text(encoding="utf-8-sig"))
    bank = json.loads(bank_path.read_text(encoding="utf-8-sig"))
    levels = json.loads(levels_path.read_text(encoding="utf-8-sig"))

    for name in [n for n in shapes if n.startswith("wf_")]:
        shapes.pop(name)
        bank.pop(name, None)
    levels["levels"] = [l for l in levels["levels"] if not l["grid_shape"].startswith("wf_")]
    next_level = max(l["level"] for l in levels["levels"]) + 1

    for spec in SPECS:
        tag = "".join(str(n) for n in spec)
        groups = defaultdict(dict)  # shape key -> {fill key: (fill, words)}
        for _ in range(args.attempts):
            res = build(spec, by_len)
            if res is None:
                continue
            rows, cols, norm, words = res
            if not runs_ok(norm, rows, cols, valid, len(spec)):
                continue
            key = (rows, cols, tuple(sorted(norm)))
            if len(groups[key]) < MAX_PUZZLES * 3:
                fill = [[norm.get((r, c)) for c in range(cols)] for r in range(rows)]
                groups[key][json.dumps(fill)] = (fill, words)
        ranked = sorted(groups.items(), key=lambda kv: -len(kv[1]))
        ranked = [kv for kv in ranked if len(kv[1]) >= MIN_PUZZLES][:args.shapes_per_spec]
        print(f"spec {spec}: {len(groups)} shapes, keeping {len(ranked)}")
        for k, ((rows, cols, cells), fills) in enumerate(ranked, 1):
            name = f"wf_{tag}_{k}"
            shapes[name] = {"rows": rows, "cols": cols, "cells": [list(c) for c in cells]}
            puzzles = []
            for fill, words in list(fills.values()):
                avg = sum(freq.get(w, 5000) for w in words) / len(words)
                puzzles.append({
                    "difficulty": "Easy" if avg <= 800 else "Medium",
                    "fill": fill,
                })
            random.shuffle(puzzles)
            puzzles = puzzles[:MAX_PUZZLES]
            for i, p in enumerate(puzzles, 1):
                p["id"] = i
            bank[name] = puzzles
            levels["levels"].append(
                {"level": next_level, "grid_shape": name, "allowed_piece_ids": []})
            print(f"  level {next_level}: {name} {rows}x{cols}, {len(puzzles)} puzzles")
            next_level += 1

    shapes_path.write_text(json.dumps(shapes, indent=2), encoding="utf-8")
    bank_path.write_text(json.dumps(bank, indent=2), encoding="utf-8")
    levels_path.write_text(json.dumps(levels, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
