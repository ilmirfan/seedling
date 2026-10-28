"""Build a drag-to-Applications DMG on macOS.

Requires Pillow and ds-store (python3 -m pip install Pillow ds-store).
Uses the current app in outputs/Seedling. Does not alter the installed app.
"""
from pathlib import Path
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFont
from ds_store import DSStore
from mac_alias import Alias

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "outputs/Seedling"
APP = OUTPUT / "Seedling.app"
DMG = OUTPUT / "Seedling-macOS.dmg"

GUIDE = """Install Seedling
===============

1. Drag Seedling into the Applications folder beside it.
2. Open Seedling from Applications, then eject this disk image.
3. In Seedling Settings, choose Make Default to open magnet links and
   .torrent files with Seedling. Confirm the change if macOS asks.

Requires an Apple Silicon Mac (M1 or newer) with macOS 14 or later.
Seedling includes its own torrent engine. No separate Transmission app
or other installation is needed.

This development build is locally signed and is not Apple-notarized.
macOS may block its first launch. Only open a copy from someone you trust.
For a trusted copy, review the message in System Settings > Privacy &
Security and use Open Anyway if offered, then follow the macOS prompts.

If an older Seedling is already installed, quit it before replacing it.
Your downloads and settings are stored separately from the app.
"""


def run(*args):
    subprocess.run(args, check=True)


def background(path):
    scale = 2
    image = Image.new("RGB", (640 * scale, 520 * scale), "#f3f8f4")
    draw = ImageDraw.Draw(image)
    fonts = Path("/System/Library/Fonts/Supplemental")

    def text(value, y, size, color, bold=False):
        font = ImageFont.truetype(str(fonts / ("Arial Bold.ttf" if bold else "Arial.ttf")), size * scale)
        draw.text((320 * scale, y * scale), value, anchor="mt", font=font, fill=color)

    text("Welcome to Seedling", 36, 29, "#193326", True)
    text("Drag Seedling into Applications to install.", 84, 17, "#41815a")
    draw.rounded_rectangle((40 * scale, 133 * scale, 600 * scale, 301 * scale), radius=20 * scale, fill="white")
    draw.line((284 * scale, 213 * scale, 354 * scale, 213 * scale), fill="#23834b", width=5 * scale)
    draw.line((337 * scale, 196 * scale, 355 * scale, 213 * scale, 337 * scale, 230 * scale), fill="#23834b", width=5 * scale)
    text("Then open Seedling from Applications.", 312, 15, "#193326")
    text("Apple Silicon (M1 or newer)  ·  macOS 14 or later", 490, 12, "#607568")
    # Finder uses the image's logical dimensions for its background.
    image.save(path, dpi=(144, 144))


def main():
    run("codesign", "--verify", "--deep", "--strict", str(APP))
    with tempfile.TemporaryDirectory(prefix="seedling-dmg-") as temporary:
        base = Path(temporary)
        stage = base / "stage"
        stage.mkdir()
        run("ditto", str(APP), str(stage / "Seedling.app"))
        (stage / "Applications").symlink_to("/Applications", target_is_directory=True)
        (stage / "Install Guide.txt").write_text(GUIDE)
        (stage / ".background").mkdir()
        background(stage / ".background/install.png")
        writable = base / "Seedling-writable.dmg"
        mount = base / "mounted"
        mount.mkdir()
        run("hdiutil", "create", "-size", "32m", "-srcfolder", str(stage), "-volname", "Seedling", "-fs", "HFS+", "-format", "UDRW", str(writable))
        run("hdiutil", "attach", "-nobrowse", "-mountpoint", str(mount), str(writable))
        try:
            alias = Alias.for_file(str(mount / ".background/install.png"))
            with DSStore.open(str(mount / ".DS_Store"), "w+") as store:
                store["."]["bwsp"] = {
                    "ShowStatusBar": False, "ShowToolbar": False,
                    "ShowSidebar": False, "ShowPathbar": False,
                    "ShowTabView": False, "ContainerShowSidebar": False,
                    "PreviewPaneVisibility": False, "SidebarWidth": 0,
                    "WindowBounds": "{{180, 160}, {640, 580}}",
                }
                store["."]["icvp"] = {
                    "viewOptionsVersion": 1, "backgroundType": 2,
                    "backgroundImageAlias": alias.to_bytes(),
                    "iconSize": 88.0, "textSize": 13.0,
                    "gridSpacing": 100.0, "gridOffsetX": 0.0, "gridOffsetY": 0.0,
                    "scrollPositionX": 0.0, "scrollPositionY": 0.0,
                    "backgroundColorRed": 1.0, "backgroundColorGreen": 1.0,
                    "backgroundColorBlue": 1.0,
                    "arrangeBy": "none", "labelOnBottom": True,
                    "showIconPreview": True, "showItemInfo": False,
                }
                store["."]["vSrn"] = ("long", 1)
                store["."]["vstl"] = ("type", b"icnv")
                store["."]["icvl"] = ("type", b"icnv")
                store["Seedling.app"]["Iloc"] = (160, 207)
                store["Applications"]["Iloc"] = (480, 207)
                store["Install Guide.txt"]["Iloc"] = (320, 385)
        finally:
            run("hdiutil", "detach", str(mount))
        run("hdiutil", "convert", str(writable), "-format", "UDZO", "-imagekey", "zlib-level=9", "-ov", "-o", str(DMG))
    run("hdiutil", "verify", str(DMG))
    print(f"Created {DMG}")


if __name__ == "__main__":
    main()
