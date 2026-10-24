from PIL import Image, ImageFilter
import numpy as np

# Load clean extracted icons
home_act = Image.open('assets/figma_ref/clean_home_active.png')
home_inact = Image.open('assets/figma_ref/clean_home_inactive.png')
cal_act = Image.open('assets/figma_ref/clean_calendar_active.png')
cal_inact = Image.open('assets/figma_ref/clean_calendar_inactive.png')
doc_inact = Image.open('assets/figma_ref/clean_document_inactive.png')
prof_inact = Image.open('assets/figma_ref/clean_profile_inactive.png')

# 1. Create document active (bold variant with shadow)
doc_inact_arr = np.array(doc_inact)
h, w, _ = doc_inact_arr.shape
doc_act_arr = np.zeros_like(doc_inact_arr)
# Body (where alpha was ~102) becomes solid 255
# Lines (where alpha was 255) become cutouts (0)
alpha_doc_in = doc_inact_arr[:, :, 3]
alpha_doc_out = np.zeros((h, w), dtype=np.float32)

# Non-zero in original:
mask_body = (alpha_doc_in > 40) & (alpha_doc_in < 180)
mask_lines = (alpha_doc_in >= 180)

alpha_doc_out[mask_body] = 1.0
alpha_doc_out[mask_lines] = 0.0 # crisp cutout lines

# Smooth the cutout lines slightly
doc_alpha_img = Image.fromarray((alpha_doc_out * 255).astype(np.uint8))
# Add the Figma drop shadow: offset (0, 6), radius 6, alpha 0.35
shadow_doc = doc_alpha_img.filter(ImageFilter.GaussianBlur(radius=3))
shadow_doc_arr = np.array(shadow_doc, dtype=np.float32) / 255.0

# Shift shadow down by 4px (2x scale of 2px or 6px)
shifted_shadow = np.zeros_like(shadow_doc_arr)
shifted_shadow[4:, :] = shadow_doc_arr[:-4, :] * 0.35

# Combine alpha + shadow
final_doc_alpha = np.maximum(alpha_doc_out, shifted_shadow)
final_doc_alpha = np.clip(final_doc_alpha, 0.0, 1.0)

doc_act_arr[:, :, 0] = 95
doc_act_arr[:, :, 1] = 51
doc_act_arr[:, :, 2] = 225
doc_act_arr[:, :, 3] = (final_doc_alpha * 255).astype(np.uint8)
doc_act = Image.fromarray(doc_act_arr, 'RGBA')

# 2. Create profile active (bold variant with shadow)
prof_inact_arr = np.array(prof_inact)
alpha_prof_in = prof_inact_arr[:, :, 3]
alpha_prof_out = np.zeros((h, w), dtype=np.float32)

# In profile, all non-zero become solid 1.0
mask_prof = alpha_prof_in > 40
alpha_prof_out[mask_prof] = 1.0

# Add crisp gap where outline separates front user and back user
# Back user was 102, front was 255
# Add shadow
prof_alpha_img = Image.fromarray((alpha_prof_out * 255).astype(np.uint8))
shadow_prof = prof_alpha_img.filter(ImageFilter.GaussianBlur(radius=3))
shadow_prof_arr = np.array(shadow_prof, dtype=np.float32) / 255.0
shifted_shadow_prof = np.zeros_like(shadow_prof_arr)
shifted_shadow_prof[4:, :] = shadow_prof_arr[:-4, :] * 0.35

final_prof_alpha = np.maximum(alpha_prof_out, shifted_shadow_prof)
final_prof_alpha = np.clip(final_prof_alpha, 0.0, 1.0)

prof_act_arr = np.zeros_like(prof_inact_arr)
prof_act_arr[:, :, 0] = 95
prof_act_arr[:, :, 1] = 51
prof_act_arr[:, :, 2] = 225
prof_act_arr[:, :, 3] = (final_prof_alpha * 255).astype(np.uint8)
prof_act = Image.fromarray(prof_act_arr, 'RGBA')

# Now put all 8 icons into a uniform 72x72 canvas, centered!
TARGET_SIZE = 72

def standardize(img):
    # Find bounding box
    arr = np.array(img)
    alpha = arr[:, :, 3]
    # threshold
    y_idx, x_idx = np.where(alpha > 15)
    if len(y_idx) == 0:
        return img.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)
    min_y, max_y = y_idx.min(), y_idx.max()
    min_x, max_x = x_idx.min(), x_idx.max()
    
    cropped = img.crop((min_x, min_y, max_x + 1, max_y + 1))
    cw, ch = cropped.size
    
    # Scale so max dimension is 44px (inside 72x72 canvas)
    scale = 44.0 / max(cw, ch)
    new_w = int(round(cw * scale))
    new_h = int(round(ch * scale))
    scaled = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Place in center of 72x72 transparent canvas
    out = Image.new('RGBA', (TARGET_SIZE, TARGET_SIZE), (0, 0, 0, 0))
    offset_x = (TARGET_SIZE - new_w) // 2
    offset_y = (TARGET_SIZE - new_h) // 2
    out.paste(scaled, (offset_x, offset_y), scaled)
    return out

icons = {
    'nav_home_active.png': standardize(home_act),
    'nav_home_inactive.png': standardize(home_inact),
    'nav_schedule_active.png': standardize(cal_act),
    'nav_schedule_inactive.png': standardize(cal_inact),
    'nav_medicines_active.png': standardize(doc_act),
    'nav_medicines_inactive.png': standardize(doc_inact),
    'nav_insights_active.png': standardize(prof_act),
    'nav_insights_inactive.png': standardize(prof_inact),
}

for filename, img in icons.items():
    img.save(f'assets/images/{filename}')
    print(f'Wrote assets/images/{filename} (72x72)')

# Generate a visual preview of the entire bottom navigation bar!
preview_w, preview_h = 375 * 2, 78 * 2 # 750 x 156
preview = Image.new('RGBA', (preview_w, preview_h), (255, 255, 255, 0))

# 1. Background rectangle with rounded corners (r=22*2=44)
bar = Image.new('RGBA', (preview_w, 56 * 2), (238, 233, 255, 255))
# Top corner mask
mask = Image.new('L', (preview_w, 56 * 2), 255)
# Draw rounded corners on mask
from PIL import ImageDraw
draw = ImageDraw.Draw(mask)
draw.rectangle((0, 0, preview_w, 56 * 2), fill=0)
draw.rounded_rectangle((0, 0, preview_w, 56 * 2), radius=44, corners=(True, True, False, False), fill=255)
preview.paste(bar, (0, 22 * 2), mask)

# 2. Icons at positions:
# home: x = 44*2 = 88 center
# calendar: x = 111*2 = 222 center
# medicines: x = 264*2 = 528 center
# insights: x = 331*2 = 662 center
# Y center: 22*2 + (56*2)//2 = 44 + 56 = 100
cy = 100

def paste_icon(img, cx):
    w, h = img.size
    preview.paste(img, (cx - w // 2, cy - h // 2), img)

# Test with Home Active:
paste_icon(icons['nav_home_active.png'], 88)
paste_icon(icons['nav_schedule_inactive.png'], 222)
paste_icon(icons['nav_medicines_inactive.png'], 528)
paste_icon(icons['nav_insights_inactive.png'], 662)

# 3. FAB: 44*2 = 88x88 at center x = 375, y = 44 (center y = 44)
fab = Image.new('RGBA', (88, 88), (0, 0, 0, 0))
fab_draw = ImageDraw.Draw(fab)
fab_draw.ellipse((0, 0, 87, 87), fill=(95, 51, 225, 255))
# plus icon in white
fab_draw.rectangle((41, 24, 47, 64), fill=(255, 255, 255, 255))
fab_draw.rectangle((24, 41, 64, 47), fill=(255, 255, 255, 255))

# FAB shadow
fab_shadow = Image.new('RGBA', (preview_w, preview_h), (0, 0, 0, 0))
s_draw = ImageDraw.Draw(fab_shadow)
s_draw.ellipse((375 - 44 + 4, 44 - 44 + 20, 375 + 44 + 4, 44 + 44 + 20), fill=(95, 51, 225, 125))
fab_shadow = fab_shadow.filter(ImageFilter.GaussianBlur(radius=18))

# Combine preview
final_preview = Image.alpha_composite(Image.new('RGBA', (preview_w, preview_h), (255, 255, 255, 255)), fab_shadow)
final_preview.alpha_composite(preview)
final_preview.paste(fab, (375 - 44, 0), fab)

final_preview.save('assets/figma_ref/bottom_nav_comparison_preview.png')
print('Generated assets/figma_ref/bottom_nav_comparison_preview.png!')
