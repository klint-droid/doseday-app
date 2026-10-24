"""
Generate 4 Google Play Store 1080x1920 Promotional Review Screenshots
For DoseDay - Smart Medication Reminder & Pill Tracker
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUTPUT_DIR = r"C:\flutter\medication_reminder\playstore_assets"
os.makedirs(OUTPUT_DIR, exist_ok=True)

WIDTH = 1080
HEIGHT = 1920

FONT_BOLD = r"C:\Windows\Fonts\segoeuib.ttf"
FONT_REGULAR = r"C:\Windows\Fonts\segoeui.ttf"

def get_fonts():
    title_font = ImageFont.truetype(FONT_BOLD, 74)
    subtitle_font = ImageFont.truetype(FONT_REGULAR, 34)
    pill_font = ImageFont.truetype(FONT_BOLD, 26)
    badge_title_font = ImageFont.truetype(FONT_BOLD, 28)
    badge_sub_font = ImageFont.truetype(FONT_REGULAR, 22)
    return title_font, subtitle_font, pill_font, badge_title_font, badge_sub_font

def create_base_canvas(theme_color):
    """Creates a dark mesh gradient background with ambient glowing color."""
    canvas = Image.new("RGBA", (WIDTH, HEIGHT), (12, 10, 23, 255))
    
    # Create glowing radial orb layer
    glow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    
    # Top-center glow
    r, g, b = theme_color
    for radius in range(450, 50, -30):
        alpha = int(40 * (1 - radius / 450))
        gdraw.ellipse([WIDTH//2 - radius, 950 - radius, WIDTH//2 + radius, 950 + radius], 
                      fill=(r, g, b, alpha))
    
    # Corner ambient glow
    for radius in range(350, 50, -30):
        alpha = int(25 * (1 - radius / 350))
        gdraw.ellipse([WIDTH - radius, 200 - radius, WIDTH + radius, 200 + radius], 
                      fill=(95, 51, 225, alpha))

    # Blur glow layer and merge
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    canvas.alpha_composite(glow)
    return canvas

def make_phone_mockup(screen_img_path, target_width=680, target_height=1380):
    """Builds a realistic smartphone chassis with rounded corners and the screen inside."""
    raw_screen = Image.open(screen_img_path).convert("RGBA")
    
    corner_radius = 42
    border_width = 14
    
    phone = Image.new("RGBA", (target_width, target_height), (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(phone)
    
    # Phone outer bezel (dark titanium)
    pdraw.rounded_rectangle(
        [0, 0, target_width, target_height], 
        radius=corner_radius + border_width, 
        fill=(28, 25, 40, 255), 
        outline=(65, 58, 88, 255), 
        width=3
    )
    
    # Screen inner mask
    screen_w = target_width - 2 * border_width
    screen_h = target_height - 2 * border_width
    
    resized_screen = raw_screen.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
    
    # Rounded mask for screen
    mask = Image.new("L", (screen_w, screen_h), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle([0, 0, screen_w, screen_h], radius=corner_radius, fill=255)
    
    phone.paste(resized_screen, (border_width, border_width), mask)
    
    # Camera pill / notch
    notch_w = 160
    notch_h = 32
    notch_x = (target_width - notch_w) // 2
    notch_y = border_width + 12
    pdraw.rounded_rectangle([notch_x, notch_y, notch_x + notch_w, notch_y + notch_h], radius=16, fill=(10, 8, 16, 255))
    
    # Subtle camera dot
    pdraw.ellipse([notch_x + 24, notch_y + 10, notch_x + 36, notch_y + 22], fill=(22, 20, 32, 255))
    
    # Drop shadow
    shadow_pad = 50
    shadow_img = Image.new("RGBA", (target_width + shadow_pad * 2, target_height + shadow_pad * 2), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow_img)
    sdraw.rounded_rectangle(
        [shadow_pad, shadow_pad, shadow_pad + target_width, shadow_pad + target_height],
        radius=corner_radius + border_width,
        fill=(0, 0, 0, 140)
    )
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(35))
    
    shadow_img.alpha_composite(phone, (shadow_pad, shadow_pad))
    return shadow_img, shadow_pad

def draw_pill_badge(canvas, text, icon, x, y, bg_color, text_color):
    draw = ImageDraw.Draw(canvas)
    _, _, pill_font, _, _ = get_fonts()
    
    bbox = draw.textbbox((0, 0), f"{icon}  {text}", font=pill_font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    
    pad_h = 32
    pad_v = 12
    rect = [x, y, x + text_w + pad_h * 2, y + text_h + pad_v * 2]
    
    draw.rounded_rectangle(rect, radius=30, fill=bg_color, outline=(255, 255, 255, 40), width=1)
    draw.text((x + pad_h, y + pad_v - 2), f"{icon}  {text}", fill=text_color, font=pill_font)

def create_slide(filename, screen_path, tag_text, title_text, subtitle_text, theme_color, badges=None, overlay_alert=False):
    canvas = create_base_canvas(theme_color)
    draw = ImageDraw.Draw(canvas)
    title_font, subtitle_font, pill_font, b_title, b_sub = get_fonts()
    
    # 1. Top Category Tag Pill
    tag_x = 90
    tag_y = 90
    draw_pill_badge(canvas, tag_text, "✨", tag_x, tag_y, (95, 51, 225, 60), (196, 178, 255, 255))
    
    # 2. Main Title
    title_y = 175
    draw.text((90, title_y), title_text, fill=(255, 255, 255, 255), font=title_font)
    
    # 3. Subtitle
    sub_y = title_y + 90
    draw.text((90, sub_y), subtitle_text, fill=(185, 180, 205, 255), font=subtitle_font)
    
    # 4. Smartphone Mockup
    phone_with_shadow, pad = make_phone_mockup(screen_path, target_width=680, target_height=1380)
    phone_x = (WIDTH - 680) // 2 - pad
    phone_y = 480 - pad
    
    canvas.alpha_composite(phone_with_shadow, (phone_x, phone_y))
    
    # 5. Optional Heads-up Notification Alert overlay for Slide 3
    if overlay_alert:
        alert_w = 600
        alert_h = 240
        alert_x = (WIDTH - alert_w) // 2
        alert_y = 740
        
        alert = Image.new("RGBA", (alert_w, alert_h), (0, 0, 0, 0))
        adraw = ImageDraw.Draw(alert)
        # Translucent dark glass card with glowing border
        adraw.rounded_rectangle([0, 0, alert_w, alert_h], radius=28, fill=(20, 16, 36, 240), outline=(95, 51, 225, 255), width=2)
        
        # Bell icon + Title
        adraw.text((36, 30), "🔔  Time to take Amoxicillin", fill=(255, 255, 255, 255), font=ImageFont.truetype(FONT_BOLD, 32))
        adraw.text((36, 75), "500 mg • 1 tablet(s) • Morning routine", fill=(175, 170, 195, 255), font=ImageFont.truetype(FONT_REGULAR, 24))
        
        # Audio wave bar / sound tag
        adraw.rounded_rectangle([36, 125, 260, 165], radius=12, fill=(0, 186, 136, 50))
        adraw.text((48, 134), "♫ 44.1kHz Chime Alert", fill=(0, 186, 136, 255), font=ImageFont.truetype(FONT_BOLD, 20))
        
        # Take Dose button
        adraw.rounded_rectangle([330, 120, 560, 180], radius=16, fill=(95, 51, 225, 255))
        adraw.text((385, 134), "✓ Take Dose", fill=(255, 255, 255, 255), font=ImageFont.truetype(FONT_BOLD, 24))
        
        # Alert shadow
        alert_shadow = Image.new("RGBA", (alert_w + 40, alert_h + 40), (0, 0, 0, 0))
        as_draw = ImageDraw.Draw(alert_shadow)
        as_draw.rounded_rectangle([20, 20, alert_w + 20, alert_h + 20], radius=28, fill=(0, 0, 0, 120))
        alert_shadow = alert_shadow.filter(ImageFilter.GaussianBlur(18))
        alert_shadow.alpha_composite(alert, (20, 20))
        
        canvas.alpha_composite(alert_shadow, (alert_x - 20, alert_y - 20))
    
    # 6. Floating badges
    if badges:
        for b in badges:
            bx, by, btext, bicon, bcol = b
            draw_pill_badge(canvas, btext, bicon, bx, by, (28, 24, 48, 230), bcol)
            
    out_path = os.path.join(OUTPUT_DIR, filename)
    canvas.convert("RGB").save(out_path, "PNG", quality=95)
    print(f"Saved: {out_path}")

def main():
    print("Generating Google Play Store 1080x1920 Showcase Slides...")
    
    # Slide 1: Daily Tracking & Adherence
    create_slide(
        filename="slide_1_daily_adherence.png",
        screen_path=r"assets\figma_ref\screen_home.png",
        tag_text="SMART PILL TRACKER",
        title_text="NEVER MISS A DOSE",
        subtitle_text="Visual adherence rings & effortless daily routine tracking",
        theme_color=(95, 51, 225),
        badges=[
            (60, 560, "85% Adherence Ring", "📊", (196, 178, 255, 255)),
            (560, 1680, "Dose Check-off", "✓", (0, 186, 136, 255))
        ]
    )
    
    # Slide 2: Monday to Sunday Weekly Calendar
    create_slide(
        filename="slide_2_weekly_planner.png",
        screen_path=r"assets\figma_ref\screen_tasks.png",
        tag_text="7-DAY SCHEDULE",
        title_text="MONDAY TO SUNDAY STRIP",
        subtitle_text="Structured 7-day cycle with seamless week restarts",
        theme_color=(124, 92, 246),
        badges=[
            (60, 560, "Mon – Sun Continuous Strip", "📅", (124, 92, 246, 255)),
            (540, 1680, "Week-by-Week Restarts", "🔄", (255, 255, 255, 255))
        ]
    )
    
    # Slide 3: Exact Closed-App Alarms & Audio Chimes
    create_slide(
        filename="slide_3_exact_alarms.png",
        screen_path=r"assets\figma_ref\screen_tasks.png",
        tag_text="UNMISSABLE ALERTS",
        title_text="EXACT CLOSED-APP ALARMS",
        subtitle_text="Loud audio chimes that fire even when the app is closed",
        theme_color=(255, 92, 131),
        overlay_alert=True,
        badges=[
            (60, 540, "Wakes Device on Time", "⏰", (255, 107, 139, 255)),
            (540, 1680, "44.1kHz Chime Audio", "🔔", (0, 186, 136, 255))
        ]
    )
    
    # Slide 4: Pill Stock & 100% Offline Privacy
    create_slide(
        filename="slide_4_stock_and_privacy.png",
        screen_path=r"assets\figma_ref\screen_add.png",
        tag_text="INVENTORY & PRIVACY",
        title_text="PILL STOCK & REFILLS",
        subtitle_text="Low-stock restock alerts with 100% offline SQLite storage",
        theme_color=(255, 149, 0),
        badges=[
            (60, 560, "Low Stock Warnings", "📦", (255, 167, 38, 255)),
            (560, 1680, "100% Offline & Private", "🔒", (0, 186, 136, 255))
        ]
    )

if __name__ == "__main__":
    main()
