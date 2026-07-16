import os

# Build order and repo paths are defined once in insertion_order.py.
from insertion_order import (
    SKELETON_FILE,
    COMPILED_SCRIPT as OUTPUT_FILE,
    INSERTION_ORDER,
)


def compile_lua_script():
    """Reads the skeleton header, then appends each source file in INSERTION_ORDER,
    emitting a marker line before each one, and writes the final compiled script."""

    try:
        # Force UTF-8 to avoid Windows cp1252 decode errors
        with open(SKELETON_FILE, 'r', encoding='utf-8') as f:
            header = f.read()
    except FileNotFoundError:
        print(f"Error: Skeleton file not found at '{SKELETON_FILE}'")
        return

    compiled_parts = [header.rstrip("\n"), "\n\n"]

    missing = []

    for marker, file_name_base, source_dir in INSERTION_ORDER:
        source_file_path = os.path.join(source_dir, f"{file_name_base}.lua")

        # Emit the marker, then the file content.
        compiled_parts.append(marker + "\n")

        try:
            with open(source_file_path, 'r', encoding='utf-8') as source_f:
                source_content = source_f.read()
            compiled_parts.append(source_content.rstrip("\n") + "\n\n")
            print(f"Inserted: {marker} <- {source_file_path}")
        except FileNotFoundError:
            missing.append(source_file_path)
            print(f"  WARNING: Source file not found: {source_file_path}. Skipping insertion.")

    try:
        with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
            f.write("".join(compiled_parts))
        print("\n##### Compilation successful!")
        print(f"Output saved to: {OUTPUT_FILE}")
        if missing:
            print(f"\n{len(missing)} file(s) were missing and skipped:")
            for m in missing:
                print(f"  - {m}")
    except Exception as e:
        print(f"\nError writing output file: {e}")

if __name__ == "__main__":
    compile_lua_script()