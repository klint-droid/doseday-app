import os
from PIL import Image

src_path = 'assets/images/app_logo.png'
base_res = 'android/app/src/main/res'

img = Image.open(src_path).convert('RGBA')

# Standard icon sizes: (standard legacy size, adaptive foreground size)
densities = {
    'mipmap-mdpi': (48, 108),
    'mipmap-hdpi': (72, 162),
    'mipmap-xhdpi': (96, 216),
    'mipmap-xxhdpi': (144, 324),
    'mipmap-xxxhdpi': (192, 432),
}

for folder, (std_size, fore_size) in densities.items():
    dir_path = os.path.join(base_res, folder)
    os.makedirs(dir_path, exist_ok=True)
    
    # 1. Standard ic_launcher.png with clean white background
    icon_canvas = Image.new('RGBA', (std_size, std_size), (255, 255, 255, 255))
    owl_std = img.resize((std_size, std_size), Image.Resampling.LANCZOS)
    icon_canvas.paste(owl_std, (0, 0), owl_std)
    icon_canvas.save(os.path.join(dir_path, 'ic_launcher.png'), 'PNG')
    
    # 2. Foreground for adaptive icon (108x108 safe area is 72x72, i.e. 68% width)
    fg_canvas = Image.new('RGBA', (fore_size, fore_size), (0, 0, 0, 0))
    scale = int(fore_size * 0.70)
    owl_fg = img.resize((scale, scale), Image.Resampling.LANCZOS)
    offset = (fore_size - scale) // 2
    fg_canvas.paste(owl_fg, (offset, offset), owl_fg)
    fg_canvas.save(os.path.join(dir_path, 'ic_launcher_foreground.png'), 'PNG')

# 3. Create anydpi-v26 adaptive-icon xml
anydpi = os.path.join(base_res, 'mipmap-anydpi-v26')
os.makedirs(anydpi, exist_ok=True)
xml_content = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
with open(os.path.join(anydpi, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
    f.write(xml_content)

# 4. Create colors.xml
val_dir = os.path.join(base_res, 'values')
colors_content = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
"""
with open(os.path.join(val_dir, 'colors.xml'), 'w', encoding='utf-8') as f:
    f.write(colors_content)

print("Successfully generated launcher icons and adaptive icon config!")
