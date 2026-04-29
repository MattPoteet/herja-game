from PIL import Image
from pathlib import Path
import math

PROJECT_ROOT = Path(__file__).parent

SPRITE_FILES = [
    PROJECT_ROOT / "godot_client" / "art" / "characters" / "viking" / "viking_walk.png",
    PROJECT_ROOT / "godot_client" / "art" / "characters" / "viking" / "viking_attack.png",
]

# These are the fake checkerboard colors ChatGPT/image tools usually bake into PNGs.
# The script removes pixels close to these colors.
CHECKER_COLORS = [
    (255, 255, 255),  # white
    (250, 250, 250),
    (245, 245, 245),
    (240, 240, 240),
    (235, 235, 235),
    (230, 230, 230),
    (225, 225, 225),
]

# Higher = removes more background.
# If it eats into the character, lower it to 12 or 10.
# If checkerboard remains, raise it to 22 or 26.
TOLERANCE = 18


def color_distance(c1, c2):
    return math.sqrt(
        (c1[0] - c2[0]) ** 2 +
        (c1[1] - c2[1]) ** 2 +
        (c1[2] - c2[2]) ** 2
    )


def is_checker_pixel(r, g, b):
    for checker in CHECKER_COLORS:
        if color_distance((r, g, b), checker) <= TOLERANCE:
            return True

    # Extra rule for very light gray/white background pixels
    if r >= 225 and g >= 225 and b >= 225 and abs(r - g) <= 8 and abs(g - b) <= 8:
        return True

    return False


def clean_image(path: Path):
    if not path.exists():
        print(f"Missing file: {path}")
        return

    image = Image.open(path).convert("RGBA")
    pixels = image.load()

    width, height = image.size
    removed = 0

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]

            if is_checker_pixel(r, g, b):
                pixels[x, y] = (255, 255, 255, 0)
                removed += 1

    backup_path = path.with_name(path.stem + "_original.png")
    if not backup_path.exists():
        original = Image.open(path).convert("RGBA")
        original.save(backup_path)

    image.save(path)

    print(f"Cleaned: {path}")
    print(f"Transparent pixels added: {removed}")
    print(f"Backup saved as: {backup_path}")
    print()


def main():
    for sprite_file in SPRITE_FILES:
        clean_image(sprite_file)

    print("Done. Now go back to Godot and reimport viking_walk.png and viking_attack.png.")


if __name__ == "__main__":
    main()