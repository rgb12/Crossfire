"""
Usage:
    python seed_finder.py --list
    python seed_finder.py CWGERMANY 2
    python seed_finder.py CWGERMANY 2 --results 10
"""

import argparse
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)
SCENARIOS_FILE = os.path.join(REPO_ROOT, "src", "active-scripts", "scenarios.lua")

LCG_A = 1664525
LCG_C = 1013904223
LCG_M = 4294967296  # 2**32


def prng_scenario_index(seed, count):
    """Mirrors rng_int(1, count) on the *first* PRNG draw of establishTheatre()."""
    seed = (LCG_A * seed + LCG_C) % LCG_M
    value = seed / LCG_M
    return int(value * count) + 1  # Lua math.floor(value * count) + 1


def parse_scenarios(path):
    """Returns {theatre_name: [scenario_name, ...]} in file order."""
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    scenarios_block = re.search(r"^scenarios\s*=\s*\{(.*?)^\}", text, re.DOTALL | re.MULTILINE)
    if not scenarios_block:
        raise ValueError(f"Could not find `scenarios = {{ ... }}` table in {path}")
    body = scenarios_block.group(1)

    entries = re.findall(
        r"theater\s*=\s*Theatres\.(\w+).*?name\s*=\s*\"([^\"]*)\"",
        body,
        re.DOTALL,
    )
    if not entries:
        raise ValueError("Found the scenarios table but no theater/name pairs inside it")

    by_theatre = {}
    for theatre, name in entries:
        by_theatre.setdefault(theatre, []).append(name)
    return by_theatre


def find_seeds(target_index, count, num_results, max_seed):
    """Brute-force ascending search; matches occur roughly every `count` seeds."""
    found = []
    seed = 0
    while seed <= max_seed and len(found) < num_results:
        if prng_scenario_index(seed, count) == target_index:
            found.append(seed)
        seed += 1
    return found


def main():
    parser = argparse.ArgumentParser(description="Find Config.theatre.seed values that select a given scenario.")
    parser.add_argument("theatre", nargs="?", help="Theatre enum key, e.g. CAUCASUS, SYRIA, CWGERMANY")
    parser.add_argument("index", nargs="?", type=int, help="1-based scenario index within that theatre's list")
    parser.add_argument("--results", type=int, default=5, help="How many matching seeds to output (default 5)")
    parser.add_argument("--max-seed", type=int, default=2_000_000, help="Upper bound for the search (default 2,000,000)")
    parser.add_argument("--list", action="store_true", help="List theatres and scenario indices, then exit")
    args = parser.parse_args()

    by_theatre = parse_scenarios(SCENARIOS_FILE)

    if args.list or not args.theatre or args.index is None:
        for theatre, names in by_theatre.items():
            print(f"{theatre}:")
            for i, name in enumerate(names, start=1):
                print(f"  {i}. {name}")
        if not args.list:
            parser.print_usage()
        return

    theatre = args.theatre.upper()
    if theatre not in by_theatre:
        raise SystemExit(f"Unknown theatre '{args.theatre}'. Known: {', '.join(by_theatre)}")

    names = by_theatre[theatre]
    count = len(names)
    if not (1 <= args.index <= count):
        raise SystemExit(f"{theatre} has {count} scenario(s); index must be between 1 and {count}")

    print(f"Target: {theatre}[{args.index}] = \"{names[args.index - 1]}\" (of {count} eligible scenarios)")

    seeds = find_seeds(args.index, count, args.results, args.max_seed)
    if not seeds:
        print(f"No seed found below {args.max_seed}. Try raising --max-seed.")
        return

    print("Matching seeds:", ", ".join(str(s) for s in seeds))


if __name__ == "__main__":
    main()
