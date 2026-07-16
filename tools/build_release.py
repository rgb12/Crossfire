"""
Crossfire release builder.

Create the 4 era .lua script files

"""

import os
import re
import sys

# Build order and repo paths are defined once in insertion_order.py.
from insertion_order import HERE, COMPILED_SCRIPT, RELEASE_DIR as OUTPUT_DIR

theatre = str(input("Enter the theatre name (e.g. caucasus, syria): ")).strip().lower()
OUTPUT_STEM = f"crossfire_{theatre}"
VERSION = "v6"


# enum:      value written into eras_selected as { Eras.<enum> }
# file_tag:  inserted into the output filename (Modern = "")
# suffix:    value written into save_dir_suffix (Modern = "")
ERAS = [
    {"enum": "WW2",          "file_tag": "_ww2", "suffix": " WW2"},
    {"enum": "EARLYCOLDWAR", "file_tag": "_ecw", "suffix": " ECW"},
    {"enum": "LATECOLDWAR",  "file_tag": "_lcw", "suffix": " LCW"},
    {"enum": "MODERN",       "file_tag": "",     "suffix": ""},
]


def run_compiler():
    """Import and run compile_crossfire so the compiled script is up to date."""
    print("=== Compiling crossfire_script.lua ===")
    sys.path.insert(0, HERE)
    try:
        import compile_crossfire
    except ImportError:
        sys.exit(f"ERROR: compile_crossfire.py not found next to this script ({HERE}).")
    compile_crossfire.compile_lua_script()
    if not os.path.isfile(COMPILED_SCRIPT):
        sys.exit(f"ERROR: compiler did not produce {COMPILED_SCRIPT}.\n"
                 "Check SKELETON_FILE / OUTPUT_FILE / SOURCE_DIR paths in compile_crossfire.py.")
    print()


def patch_config(text, era_enum, suffix, seed):
    """Return the compiled script text with the three per-era config fields replaced.

    Each replacement is anchored and asserted: if a field isn't found exactly once,
    we abort rather than ship a file that silently kept the wrong era.
    """

    def sub_once(pattern, repl, label):
        new_text, n = re.subn(pattern, repl, text_local[0], count=1)
        if n != 1:
            sys.exit(f"ERROR: expected exactly 1 match for {label} in compiled script, found {n}. "
                     "The config layout may have changed; update the regex in build_release.py.")
        text_local[0] = new_text

    text_local = [text]  # boxed so the closure can rebind

    sub_once(
        r"eras_selected\s*=\s*\{[^}]*\}",
        f"eras_selected = {{ Eras.{era_enum} }}",
        "eras_selected",
    )
    sub_once(
        r'save_dir_suffix\s*=\s*"[^"]*"',
        f'save_dir_suffix = "{suffix}"',
        "save_dir_suffix",
    )
    sub_once(
        r"seed\s*=\s*-?\d+",
        f"seed = {seed}",
        "theatre.seed",
    )
    return text_local[0]


def main():
    run_compiler()

    with open(COMPILED_SCRIPT, "r", encoding="utf-8") as f:
        compiled = f.read()

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print(f"=== Building {len(ERAS)} era script files ===")
    print("Enter a seed for each era (integer; -1 = random per mission load).\n")

    built = []
    for era in ERAS:
        label = era["enum"]
        while True:
            raw = input(f"  Seed for {label}: ").strip()
            try:
                seed = int(raw)
                break
            except ValueError:
                print("    Please enter an integer (e.g. 2025 or -1).")

        patched = patch_config(compiled, era["enum"], era["suffix"], seed)
        out_name = f"{OUTPUT_STEM}{era['file_tag']}_{VERSION}.lua"
        out_path = os.path.join(OUTPUT_DIR, out_name)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(patched)
        built.append((label, out_name, seed))
        print(f"    -> {out_name}  (era={label}, seed={seed})\n")

    print("##### Build complete. Output in:", OUTPUT_DIR)
    for label, name, seed in built:
        print(f"  - {name}  [{label}, seed {seed}]")


if __name__ == "__main__":
    main()
