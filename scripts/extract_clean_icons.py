from PIL import Image
import numpy as np

im = Image.open('assets/figma_ref/node_1_87.png')

# Origin: (-600, -1180), scale: 2.0x
# Icon box size in Figma: 24x24 -> 48x48 in 2x pixels.
# Let's crop 56x56 (with 4px margin around 48x48) so we capture anti-aliasing perfectly!

# Home frame (x=-153, y=-1180):
# vuesax/bold/home: x=-121, y=-408
# px = (-121 - (-600))*2 = 958, py = (-408 - (-1180))*2 = 1544
# vuesax/bulk/calendar: x=-54, y=-408
# px = (-54 - (-600))*2 = 1092, py = 1544
# vuesax/bulk/document-text: x=100, y=-408
# px = (100 - (-600))*2 = 1400, py = 1544
# vuesax/bulk/profile-2user: x=166, y=-408
# px = (166 - (-600))*2 = 1532, py = 1544

# Tasks frame (x=285, y=-1180):
# vuesax/bulk/home: x=317, y=-408
# px = (317 - (-600))*2 = 1834, py = 1544
# vuesax/bold/calendar: x=384, y=-408
# px = (384 - (-600))*2 = 1968, py = 1544

icon_coords = {
    'home_active': (958, 1544),
    'calendar_inactive': (1092, 1544),
    'document_inactive': (1400, 1544),
    'profile_inactive': (1532, 1544),
    'home_inactive': (1834, 1544),
    'calendar_active': (1968, 1544),
}

# Background color in Figma
bg = np.array([238.0, 233.0, 255.0])
# Foreground color
fg = np.array([95.0, 51.0, 225.0])

extracted = {}

for name, (px, py) in icon_coords.items():
    # Crop with 4px margin (total size 56x56)
    crop = np.array(im.crop((px - 4, py - 4, px + 48 + 4, py + 48 + 4)).convert('RGB'), dtype=np.float32)
    h, w, _ = crop.shape
    
    # Calculate alpha based on color distance from background
    # Since fg is darker than bg, especially in Red (238 vs 95) and Green (233 vs 51):
    alpha_r = (bg[0] - crop[:, :, 0]) / (bg[0] - fg[0])
    alpha_g = (bg[1] - crop[:, :, 1]) / (bg[1] - fg[1])
    
    # Combined alpha estimate (weighting green and red heavily as they have largest delta)
    alpha = (alpha_r * 0.4 + alpha_g * 0.6)
    alpha = np.clip(alpha, 0.0, 1.0)
    
    # Clear very low noise below 0.04
    alpha[alpha < 0.04] = 0.0
    
    # Now create RGBA image:
    # Pure foreground color with exact alpha!
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, 0] = int(fg[0])
    rgba[:, :, 1] = int(fg[1])
    rgba[:, :, 2] = int(fg[2])
    rgba[:, :, 3] = (alpha * 255).astype(np.uint8)
    
    out_img = Image.fromarray(rgba, 'RGBA')
    extracted[name] = out_img
    out_img.save(f'assets/figma_ref/clean_{name}.png')
    print(f'Saved clean_{name}.png ({w}x{h}), non-zero alpha={np.count_nonzero(alpha)}')

