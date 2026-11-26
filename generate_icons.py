"""
Generates high-resolution NetScope Cyber Icons and updates all assets
across Web, Desktop, PyInstaller, and Installer.
"""
import os
import shutil
import math
from PIL import Image, ImageDraw, ImageFilter

def create_netscope_icon():
    size = 1024
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    margin = 48
    cx, cy = size // 2, size // 2

    # Outer ambient glow
    for r in range(24, 0, -3):
        alpha = int(14 * (1 - r / 24))
        draw.rounded_rectangle(
            [margin - r, margin - r, size - margin + r, size - margin + r],
            radius=160 + r,
            fill=(0, 210, 255, alpha)
        )

    # Base dark cyber squircle (#0a0e1a)
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=160,
        fill=(10, 14, 26, 255)
    )

    # Inner subtle cyber grid lines
    for gx in range(margin + 60, size - margin, 80):
        draw.line([(gx, margin + 20), (gx, size - margin - 20)], fill=(0, 210, 255, 18), width=2)
    for gy in range(margin + 60, size - margin, 80):
        draw.line([(margin + 20, gy), (size - margin - 20, gy)], fill=(0, 210, 255, 18), width=2)

    # Outer neon border
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=160,
        outline=(0, 210, 255, 230),
        width=16
    )
    draw.rounded_rectangle(
        [margin + 8, margin + 8, size - margin - 8, size - margin - 8],
        radius=152,
        outline=(0, 130, 255, 100),
        width=4
    )

    # Concentric radar rings
    for r in [130, 230, 330]:
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(0, 210, 255, 70), width=4)

    # Radar crosshair sweep markers
    draw.line([cx - 350, cy, cx - 140, cy], fill=(0, 210, 255, 80), width=4)
    draw.line([cx + 140, cy, cx + 350, cy], fill=(0, 210, 255, 80), width=4)
    draw.line([cx, cy - 350, cx, cy - 140], fill=(0, 210, 255, 80), width=4)
    draw.line([cx, cy + 140, cx, cy + 350], fill=(0, 210, 255, 80), width=4)

    # Stylized Futuristic NetScope 'N' with network pulse telemetry wave
    left_x = 310
    right_x = 714
    top_y = 310
    bottom_y = 714

    # Left vertical beam
    draw.line([(left_x, bottom_y), (left_x, top_y)], fill=(0, 230, 255, 255), width=42)
    draw.ellipse([left_x - 21, bottom_y - 21, left_x + 21, bottom_y + 21], fill=(0, 230, 255, 255))
    draw.ellipse([left_x - 21, top_y - 21, left_x + 21, top_y + 21], fill=(0, 230, 255, 255))

    # Right vertical beam
    draw.line([(right_x, bottom_y), (right_x, top_y)], fill=(0, 230, 255, 255), width=42)
    draw.ellipse([right_x - 21, bottom_y - 21, right_x + 21, bottom_y + 21], fill=(0, 230, 255, 255))
    draw.ellipse([right_x - 21, top_y - 21, right_x + 21, top_y + 21], fill=(0, 230, 255, 255))

    # Dynamic pulse waveform connecting left and right to complete the 'N'
    pulse_nodes = [
        (left_x, top_y + 30),
        (420, 470),
        (480, 260),  # Peak burst
        (544, 764),  # Rebound burst
        (604, 554),
        (right_x, bottom_y - 30)
    ]

    for i in range(len(pulse_nodes) - 1):
        draw.line([pulse_nodes[i], pulse_nodes[i + 1]], fill=(0, 255, 220, 255), width=38)

    # Glowing node markers
    for pt in pulse_nodes[1:-1]:
        draw.ellipse([pt[0] - 22, pt[1] - 22, pt[0] + 22, pt[1] + 22], fill=(255, 255, 255, 255), outline=(0, 210, 255, 255), width=6)

    # Core center radar ping
    draw.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=(255, 255, 255, 255))

    return img

def main():
    print("Generating NetScope High-Resolution Cyber Icon...")
    icon_1024 = create_netscope_icon()

    # Target directories relative to project root
    project_dir = os.path.dirname(os.path.abspath(__file__))
    web_dir = os.path.join(project_dir, "app", "web")
    build_web_dir = os.path.join(project_dir, "app", "build", "web")
    engine_dir = os.path.join(project_dir, "monitor_engine")
    installer_dir = os.path.join(project_dir, "installer")

    # Multi-resolution PNGs
    resolutions = {
        512: icon_1024.resize((512, 512), Image.Resampling.LANCZOS),
        256: icon_1024.resize((256, 256), Image.Resampling.LANCZOS),
        192: icon_1024.resize((192, 192), Image.Resampling.LANCZOS),
        64: icon_1024.resize((64, 64), Image.Resampling.LANCZOS),
        48: icon_1024.resize((48, 48), Image.Resampling.LANCZOS),
        32: icon_1024.resize((32, 32), Image.Resampling.LANCZOS),
        16: icon_1024.resize((16, 16), Image.Resampling.LANCZOS),
    }

    # Save Windows ICO with all standard sizes
    ico_path = os.path.join(engine_dir, "app_icon.ico")
    resolutions[256].save(
        ico_path,
        format="ICO",
        sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)]
    )
    print(f"Generated Windows ICO: {ico_path}")

    # Copy ICO to installer and Windows runner resources
    shutil.copy2(ico_path, os.path.join(installer_dir, "app_icon.ico"))
    runner_ico = os.path.join(project_dir, "app", "windows", "runner", "resources", "app_icon.ico")
    os.makedirs(os.path.dirname(runner_ico), exist_ok=True)
    shutil.copy2(ico_path, runner_ico)

    # Update Web icons in app/web and app/build/web
    for target in [web_dir, build_web_dir]:
        if os.path.exists(target):
            # Favicon
            resolutions[32].save(os.path.join(target, "favicon.png"))
            icons_sub = os.path.join(target, "icons")
            os.makedirs(icons_sub, exist_ok=True)
            resolutions[192].save(os.path.join(icons_sub, "Icon-192.png"))
            resolutions[512].save(os.path.join(icons_sub, "Icon-512.png"))
            resolutions[192].save(os.path.join(icons_sub, "Icon-maskable-192.png"))
            resolutions[512].save(os.path.join(icons_sub, "Icon-maskable-512.png"))
            print(f"Updated web icons in {target}")

    print("All icons successfully generated and replaced with NetScope Cyber branding!")

if __name__ == "__main__":
    main()
