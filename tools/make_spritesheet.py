"""Build a sprite sheet from PNG frames exported out of CapCut.

Usage:
  python tools/make_spritesheet.py --input frames/player_walk --output godot_client/art/characters/player_walk.png --columns 4

Frame filenames should sort in animation order, for example:
  001.png, 002.png, 003.png, 004.png
"""
from __future__ import annotations

import argparse
from pathlib import Path
from PIL import Image


def build_sheet(input_dir: Path, output_file: Path, columns: int) -> None:
    frames = sorted([p for p in input_dir.iterdir() if p.suffix.lower() in {'.png', '.jpg', '.jpeg'}])
    if not frames:
        raise SystemExit(f'No image frames found in {input_dir}')

    images = [Image.open(p).convert('RGBA') for p in frames]
    width, height = images[0].size
    for img in images:
        if img.size != (width, height):
            raise SystemExit('All frames must be the same size. Resize/crop them before making a sheet.')

    rows = (len(images) + columns - 1) // columns
    sheet = Image.new('RGBA', (columns * width, rows * height), (0, 0, 0, 0))

    for index, img in enumerate(images):
        x = (index % columns) * width
        y = (index // columns) * height
        sheet.paste(img, (x, y))

    output_file.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_file)
    print(f'Saved {output_file} with {len(images)} frames, {columns} columns, {rows} rows.')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--columns', type=int, default=4)
    args = parser.parse_args()
    build_sheet(args.input, args.output, args.columns)


if __name__ == '__main__':
    main()
