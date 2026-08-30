#!/usr/bin/env python3
"""
Generate puzzle_bank.json for GraphemeX.

Usage:
    python tools/generate_puzzles.py [--count N] [--seed S]

Word validity : data/words7.txt  (same list the game validates against at runtime)
Difficulty    : SymSpell en-80k frequency list (downloaded once to tools/frequency_dict.txt)
Output        : data/puzzle_bank.json  (overwrites existing file)
"""

import argparse
import json
import random
import urllib.request
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths & tunables
# ---------------------------------------------------------------------------
TOOLS_DIR  = Path(__file__).parent
DATA_DIR   = TOOLS_DIR.parent / "data"

FREQ_FILE  = TOOLS_DIR / "frequency_dict.txt"
FREQ_URL   = (
    "https://raw.githubusercontent.com/wolfgarbe/SymSpell/master"
    "/SymSpell.FrequencyDictionary/en-80k.txt"
)

WORDS_FILE  = DATA_DIR / "words7.txt"
SHAPES_FILE = DATA_DIR / "grid_shapes.json"
OUTPUT_FILE = DATA_DIR / "puzzle_bank.json"

DEFAULT_COUNT    = 30      # puzzles to generate per shape
MAX_SOLVER_CALLS = 10_000  # backtracker budget per puzzle attempt
MAX_WORD_RANK    = 8_000   # only use words ranked within the top-N most common; filters
                           # proper nouns (joseph) and abbreviations (nth, del) that appear
                           # in corpora but aren't suitable puzzle answers

# ---------------------------------------------------------------------------
# Frequency list
# ---------------------------------------------------------------------------

def ensure_freq_file() -> None:
    if FREQ_FILE.exists():
        return
    print("Downloading SymSpell frequency list...")
    try:
        urllib.request.urlretrieve(FREQ_URL, FREQ_FILE)
        print("Download complete.")
    except Exception as exc:
        print(f"Warning: download failed ({exc}). Difficulty will default to Medium.")


def load_freq_dict() -> dict:
    """Returns {word: rank} where rank 1 = most common English word."""
    freq: dict = {}
    if not FREQ_FILE.exists():
        return freq
    with open(FREQ_FILE, encoding="utf-8") as fh:
        rank = 1
        for line in fh:
            parts = line.strip().split()
            if parts:
                word = parts[0].lower()
                if word.isalpha() and word not in freq:
                    freq[word] = rank
                    rank += 1
    print(f"Loaded {len(freq):,} frequency entries.")
    return freq


# ---------------------------------------------------------------------------
# Word index  (words7.txt is the validity source; freq order drives quality)
# ---------------------------------------------------------------------------

def load_word_index(freq_dict: dict, max_rank: int = MAX_WORD_RANK) -> dict:
    """Returns {length: [words sorted common-first]}, limited to words within max_rank."""
    by_len: dict = {}
    with open(WORDS_FILE, encoding="utf-8") as fh:
        for line in fh:
            w = line.strip().lower()
            if w.isalpha():
                rank = freq_dict.get(w, 999_999)
                if rank <= max_rank:
                    by_len.setdefault(len(w), []).append(w)
    for wlist in by_len.values():
        # Sort common words first; unknown/rare words fall to the end
        wlist.sort(key=lambda w: freq_dict.get(w, 999_999))
    total = sum(len(v) for v in by_len.values())
    print(f"Loaded {total:,} words across {len(by_len)} distinct lengths.")
    return by_len


# ---------------------------------------------------------------------------
# Slot analysis
# ---------------------------------------------------------------------------

def find_slots(cells: list, rows: int, cols: int) -> tuple:
    """
    Returns (h_slots, v_slots).
    Each slot is an ordered list of (row, col) tuples for a consecutive run of >= 2 cells.
    """
    cell_set = set(map(tuple, cells))

    def runs(primary_range, secondary_range, horizontal: bool) -> list:
        result = []
        for p in primary_range:
            run = []
            for s in secondary_range:
                c = (p, s) if horizontal else (s, p)
                if c in cell_set:
                    run.append(c)
                else:
                    if len(run) >= 2:
                        result.append(run[:])
                    run = []
            if len(run) >= 2:
                result.append(run[:])
        return result

    return (
        runs(range(rows), range(cols), horizontal=True),
        runs(range(cols), range(rows), horizontal=False),
    )


def build_crossing_map(all_slots: list) -> dict:
    """
    Returns {slot_i: [(slot_j, pos_in_i, pos_in_j)]} for every shared cell.
    Each cell can be in at most one H-slot and one V-slot.
    """
    cell_to: dict = {}
    for i, slot in enumerate(all_slots):
        for j, cell in enumerate(slot):
            cell_to.setdefault(cell, []).append((i, j))
    crossings: dict = {i: [] for i in range(len(all_slots))}
    for refs in cell_to.values():
        if len(refs) == 2:
            (ia, ja), (ib, jb) = refs
            crossings[ia].append((ib, ja, jb))
            crossings[ib].append((ia, jb, ja))
    return crossings


# ---------------------------------------------------------------------------
# Backtracking solver
# ---------------------------------------------------------------------------

class Solver:
    def __init__(self, all_slots: list, crossings: dict, word_index: dict) -> None:
        self.slots      = all_slots
        self.crossings  = crossings
        self.word_index = word_index
        self.calls      = 0
        self.assignment: dict = {}  # slot_index -> word string

    def solve(self, order: list, depth: int = 0) -> bool:
        if depth == len(order):
            return True
        if self.calls > MAX_SOLVER_CALLS:
            return False

        slot_idx   = order[depth]
        length     = len(self.slots[slot_idx])
        candidates = self.word_index.get(length, [])
        if not candidates:
            return False

        # Letter constraints from already-placed crossing words
        constraints: dict = {}
        for (other_idx, my_pos, other_pos) in self.crossings.get(slot_idx, []):
            if other_idx in self.assignment:
                constraints[my_pos] = self.assignment[other_idx][other_pos]

        # Sample from the common-word prefix; shuffle for variety
        pool_size = min(len(candidates), 500)
        pool = random.sample(candidates[:pool_size], pool_size)

        for word in pool:
            if all(word[p] == ch for p, ch in constraints.items()):
                self.calls += 1
                self.assignment[slot_idx] = word
                if self.solve(order, depth + 1):
                    return True
                del self.assignment[slot_idx]

        return False


# ---------------------------------------------------------------------------
# Difficulty scoring
# ---------------------------------------------------------------------------

DIFFICULTY_TIERS = [
    (1_500,  "Easy"),
    (5_000,  "Medium"),
    (12_000, "Hard"),
    (None,   "Expert"),
]


def score_difficulty(words: list, freq_dict: dict) -> str:
    if not words or not freq_dict:
        return "Medium"
    avg = sum(freq_dict.get(w, 50_000) for w in words) / len(words)
    for threshold, tier in DIFFICULTY_TIERS:
        if threshold is None or avg <= threshold:
            return tier
    return "Expert"


# ---------------------------------------------------------------------------
# Fill construction
# ---------------------------------------------------------------------------

def make_fill(cells: list, rows: int, cols: int,
              assignment: dict, all_slots: list) -> list:
    """Build a rows x cols 2-D grid: letter at shape cells, None elsewhere."""
    grid = [[None] * cols for _ in range(rows)]
    cell_letter: dict = {}
    for slot_idx, word in assignment.items():
        for pos, cell in enumerate(all_slots[slot_idx]):
            cell_letter[cell] = word[pos]
    for cell in map(tuple, cells):
        r, c = cell
        grid[r][c] = cell_letter.get(cell, "?")
    return grid


# ---------------------------------------------------------------------------
# Per-shape generation
# ---------------------------------------------------------------------------

def generate_for_shape(shape_name: str, shape_data: dict,
                       word_index: dict, freq_dict: dict,
                       n_target: int) -> list:
    cells = [tuple(c) for c in shape_data["cells"]]
    rows  = shape_data["rows"]
    cols  = shape_data["cols"]

    h_slots, v_slots = find_slots(cells, rows, cols)
    all_slots = h_slots + v_slots

    if not all_slots:
        print(f"  [{shape_name}] No word slots found.")
        return []

    crossings = build_crossing_map(all_slots)
    # Longer (more constrained) slots go first in the solve order
    order = sorted(range(len(all_slots)), key=lambda i: -len(all_slots[i]))

    puzzles: list = []
    seen:    set  = set()
    attempts = 0

    while len(puzzles) < n_target and attempts < n_target * 60:
        attempts += 1
        solver = Solver(all_slots, crossings, word_index)
        if solver.solve(order):
            fill = make_fill(cells, rows, cols, solver.assignment, all_slots)
            key  = json.dumps(fill, separators=(",", ":"))
            if key in seen:
                continue
            seen.add(key)
            diff = score_difficulty(list(solver.assignment.values()), freq_dict)
            puzzles.append({
                "id":         len(puzzles) + 1,
                "difficulty": diff,
                "fill":       fill,
            })
            if len(puzzles) % 10 == 0 or len(puzzles) == n_target:
                print(f"  {len(puzzles)}/{n_target}")

    if len(puzzles) < n_target:
        print(f"  Warning: only {len(puzzles)}/{n_target} unique puzzles generated.")
    return puzzles


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate GraphemeX puzzle_bank.json"
    )
    parser.add_argument(
        "--count", type=int, default=DEFAULT_COUNT,
        help=f"Puzzles per shape (default: {DEFAULT_COUNT})"
    )
    parser.add_argument(
        "--seed", type=int, default=None,
        help="Random seed for reproducibility"
    )
    parser.add_argument(
        "--max-rank", type=int, default=MAX_WORD_RANK,
        help=f"Only use words ranked within top-N by frequency (default: {MAX_WORD_RANK})"
    )
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    ensure_freq_file()
    freq_dict  = load_freq_dict()
    word_index = load_word_index(freq_dict, args.max_rank)

    with open(SHAPES_FILE) as fh:
        shapes: dict = json.load(fh)

    bank: dict = {}
    for shape_name, shape_data in shapes.items():
        print(f"\n-- {shape_name} --")
        puzzles = generate_for_shape(
            shape_name, shape_data, word_index, freq_dict, args.count
        )
        bank[shape_name] = puzzles
        tally = {t: sum(1 for p in puzzles if p["difficulty"] == t)
                 for t in ("Easy", "Medium", "Hard", "Expert")}
        tally_str = "  ".join(f"{t}:{n}" for t, n in tally.items() if n)
        print(f"  -> {len(puzzles)} puzzles  ({tally_str})")

    with open(OUTPUT_FILE, "w") as fh:
        json.dump(bank, fh, indent=2)

    total = sum(len(v) for v in bank.values())
    print(f"\nWrote {OUTPUT_FILE}  ({total} total puzzles across {len(bank)} shapes)")


if __name__ == "__main__":
    main()
