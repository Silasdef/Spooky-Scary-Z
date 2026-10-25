#!/usr/bin/env python3
"""
build_survivor_sprites.py
Generates accurate top-down front (bas) and back (haut) sprites for Joel and Ellie,
centered on 260x260 canvases to match the existing game assets and perspective.
"""

import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SPRITES_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites")

def build_joel_sprites():
    print("Building Joel sprites...")
    # Load original survivor front and back
    # survivor_bas tight: (164, 232), survivor_haut tight: (154, 231)
    # Extract tight crops if not already done
    src = Image.open(os.path.join(SPRITES_DIR, "player_bas.png"))
    src_haut = Image.open(os.path.join(SPRITES_DIR, "player_haut.png"))
    
    # 1. joel_bas
    bbox_bas = src.getbbox() # (96, 15, 260, 247)
    tight_bas = src.crop(bbox_bas)
    
    # Enrich Joel's front: salt-and-pepper beard flecks, rugged survivor details
    arr_bas = np.array(tight_bas).copy()
    # Face & beard region in tight_bas is around Y: 75..115, X: 30..135
    # Let's add salt-and-pepper highlights to Joel's beard (lower jaw Y: 92..112)
    np.random.seed(42)
    for y in range(92, 112):
        for x in range(35, 130):
            if arr_bas[y, x, 3] > 100:
                # If dark beard pixel (R < 110, G < 95, B < 80)
                r, g, b = arr_bas[y, x, :3]
                if r < 100 and g < 85 and b < 70 and (r > 15):
                    # 18% chance of salt-and-pepper gray hair
                    if np.random.rand() < 0.18:
                        gray_val = np.random.randint(115, 155)
                        arr_bas[y, x, 0] = gray_val
                        arr_bas[y, x, 1] = gray_val - 5
                        arr_bas[y, x, 2] = gray_val - 10
    
    enhanced_bas = Image.fromarray(arr_bas)
    
    # Place on 260x260 canvas, centered at X=130 and grounded at Y=242
    # tight_bas width = 164, height = 232
    # Torso/feet center of tight_bas is at X=81.5 -> offset = 130 - 81 = 49
    # Feet touch bottom at 242 -> top = 242 - 232 = 10
    joel_bas = Image.new("RGBA", (260, 260), (0, 0, 0, 0))
    joel_bas.paste(enhanced_bas, (49, 10), enhanced_bas)
    
    # 2. joel_haut
    bbox_haut = src_haut.getbbox() # (15, 20, 169, 246)
    tight_haut = src_haut.crop(bbox_haut)
    arr_haut = np.array(tight_haut).copy()
    
    # Hair in haut is Y: 0..80, add slight gray flecks at temples/sides
    for y in range(25, 75):
        for x in range(20, 135):
            if arr_haut[y, x, 3] > 100:
                r, g, b = arr_haut[y, x, :3]
                if r < 80 and g < 70 and b < 60 and (r > 20):
                    if np.random.rand() < 0.12:
                        gray_val = np.random.randint(110, 140)
                        arr_haut[y, x, 0] = gray_val
                        arr_haut[y, x, 1] = gray_val - 5
                        arr_haut[y, x, 2] = gray_val - 10
                        
    enhanced_haut = Image.fromarray(arr_haut)
    
    # Place on 260x260 canvas:
    # tight_haut width = 154, height = 226
    # Center of mass of X is 75 -> offset = 130 - 75 = 55
    # Ground at 242 -> top = 242 - 226 = 16 (or 11 if height is 231)
    joel_haut = Image.new("RGBA", (260, 260), (0, 0, 0, 0))
    joel_haut.paste(enhanced_haut, (55, 242 - tight_haut.height), enhanced_haut)
    
    # Save Joel sprites
    bas_path = os.path.join(SPRITES_DIR, "joel_bas.png")
    haut_path = os.path.join(SPRITES_DIR, "joel_haut.png")
    portrait_path = os.path.join(SPRITES_DIR, "joel.png")
    
    joel_bas.save(bas_path)
    joel_haut.save(haut_path)
    joel_bas.save(portrait_path)
    print("  Saved joel_bas.png, joel_haut.png, and joel.png")

def build_ellie_sprites():
    print("Building Ellie sprites...")
    # Target dimensions: 106w x 198h, placed on 260x260 canvas at X=77, Y=43 (ground Y=241)
    # We will construct ellie_bas and ellie_haut with pixel-precise layers
    canvas_w, canvas_h = 260, 260
    left_x = 77
    top_y = 43
    char_w = 106
    char_h = 198
    
    # Color constants matching Ellie's official palette
    COLOR_SKIN = (248, 176, 150, 255)
    COLOR_SKIN_SHADOW = (220, 150, 125, 255)
    COLOR_SKIN_HIGHLIGHT = (255, 195, 170, 255)
    COLOR_SKIN_DARK = (185, 120, 100, 255)
    
    COLOR_HAIR = (58, 32, 28, 255)
    COLOR_HAIR_LIGHT = (95, 52, 42, 255)
    COLOR_HAIR_HIGHLIGHT = (125, 68, 52, 255)
    COLOR_HAIR_DARK = (38, 20, 18, 255)
    
    COLOR_SHIRT = (155, 55, 48, 255)
    COLOR_SHIRT_LIGHT = (180, 75, 65, 255)
    COLOR_SHIRT_SHADOW = (115, 38, 34, 255)
    COLOR_SHIRT_DARK = (85, 28, 24, 255)
    COLOR_COLLAR_WHITE = (235, 235, 230, 255)
    
    COLOR_STRAP = (65, 75, 52, 255)
    COLOR_STRAP_DARK = (45, 52, 36, 255)
    
    COLOR_PANTS = (52, 58, 68, 255)
    COLOR_PANTS_LIGHT = (72, 80, 94, 255)
    COLOR_PANTS_SHADOW = (38, 42, 50, 255)
    COLOR_PANTS_DARK = (26, 28, 34, 255)
    
    COLOR_SNEAKER_RED = (150, 45, 40, 255)
    COLOR_SNEAKER_RUBBER = (235, 235, 235, 255)
    COLOR_SNEAKER_SOLE = (210, 210, 210, 255)
    COLOR_SNEAKER_SHADOW = (160, 160, 160, 255)
    
    COLOR_BACKPACK = (80, 90, 65, 255)
    COLOR_BACKPACK_LIGHT = (105, 115, 85, 255)
    COLOR_BACKPACK_SHADOW = (55, 65, 45, 255)
    COLOR_BACKPACK_DARK = (38, 45, 30, 255)
    
    # -------------------------------------------------------------
    # 1. ELLIE BAS (Front View)
    # -------------------------------------------------------------
    im_bas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    d_bas = ImageDraw.Draw(im_bas)
    
    # A. Shoes / Feet (Y: 215 to 241)
    # Left foot (X: 92..112)
    d_bas.rounded_rectangle([92, 218, 112, 240], radius=4, fill=COLOR_SNEAKER_RED, outline=COLOR_SHIRT_DARK)
    d_bas.rounded_rectangle([92, 234, 112, 241], radius=2, fill=COLOR_SNEAKER_SOLE, outline=COLOR_SNEAKER_SHADOW)
    d_bas.rounded_rectangle([93, 230, 111, 238], radius=3, fill=COLOR_SNEAKER_RUBBER)
    # Right foot (X: 148..168)
    d_bas.rounded_rectangle([148, 218, 168, 240], radius=4, fill=COLOR_SNEAKER_RED, outline=COLOR_SHIRT_DARK)
    d_bas.rounded_rectangle([148, 234, 168, 241], radius=2, fill=COLOR_SNEAKER_SOLE, outline=COLOR_SNEAKER_SHADOW)
    d_bas.rounded_rectangle([149, 230, 167, 238], radius=3, fill=COLOR_SNEAKER_RUBBER)
    
    # B. Slim Jeans / Legs (Y: 148 to 222)
    # Left leg (X: 95..118)
    d_bas.polygon([(100, 148), (118, 148), (114, 222), (94, 222)], fill=COLOR_PANTS, outline=COLOR_PANTS_DARK)
    d_bas.line([(106, 155), (103, 218)], fill=COLOR_PANTS_LIGHT, width=2)
    # Right leg (X: 142..165)
    d_bas.polygon([(142, 148), (160, 148), (166, 222), (146, 222)], fill=COLOR_PANTS, outline=COLOR_PANTS_DARK)
    d_bas.line([(154, 155), (157, 218)], fill=COLOR_PANTS_LIGHT, width=2)
    # Pelvis / Crotch & Hip waist (Y: 138 to 155, X: 94..166)
    d_bas.polygon([(94, 140), (166, 140), (162, 155), (130, 162), (98, 155)], fill=COLOR_PANTS, outline=COLOR_PANTS_DARK)
    # Belt line
    d_bas.line([(96, 141), (164, 141)], fill=COLOR_PANTS_DARK, width=2)
    # Inseam shadow
    d_bas.line([(130, 152), (130, 175)], fill=COLOR_PANTS_DARK, width=2)
    
    # C. Forearms & Hands (Bare skin)
    # Left arm/hand (X: 78..93, Y: 110 to 148)
    d_bas.rounded_rectangle([78, 110, 93, 144], radius=4, fill=COLOR_SKIN, outline=COLOR_SKIN_SHADOW)
    d_bas.ellipse([78, 140, 92, 152], fill=COLOR_SKIN, outline=COLOR_SKIN_DARK) # left hand
    # Right arm/hand (X: 167..182, Y: 110 to 148)
    d_bas.rounded_rectangle([167, 110, 182, 144], radius=4, fill=COLOR_SKIN, outline=COLOR_SKIN_SHADOW)
    d_bas.ellipse([168, 140, 182, 152], fill=COLOR_SKIN, outline=COLOR_SKIN_DARK) # right hand
    
    # D. Coral / Red T-Shirt Torso (Y: 96 to 142)
    # Main shirt body (X: 92 to 168)
    d_bas.polygon([(96, 98), (164, 98), (170, 142), (90, 142)], fill=COLOR_SHIRT, outline=COLOR_SHIRT_DARK)
    # Subtle shirt shading
    d_bas.polygon([(96, 102), (164, 102), (160, 138), (100, 138)], fill=COLOR_SHIRT_LIGHT)
    # Short sleeves (X: 80..96 and 164..180, Y: 96 to 114)
    d_bas.polygon([(82, 98), (96, 98), (96, 114), (80, 112)], fill=COLOR_SHIRT, outline=COLOR_SHIRT_DARK)
    d_bas.polygon([(164, 98), (178, 98), (180, 112), (164, 114)], fill=COLOR_SHIRT, outline=COLOR_SHIRT_DARK)
    
    # Palm tree / sunset emblem on chest (Y: 112..128, X: 122..138)
    d_bas.ellipse([124, 112, 136, 124], fill=(235, 195, 120, 220)) # sunset circle
    d_bas.line([(130, 115), (130, 126)], fill=COLOR_SHIRT_DARK, width=2) # palm trunk
    d_bas.line([(126, 117), (134, 117)], fill=COLOR_SHIRT_DARK, width=1) # palm fronds
    d_bas.line([(127, 119), (133, 119)], fill=COLOR_SHIRT_DARK, width=1)
    
    # White undershirt round collar (Y: 94..100, X: 118..142)
    d_bas.ellipse([118, 92, 142, 104], fill=COLOR_COLLAR_WHITE, outline=COLOR_SHIRT_DARK)
    
    # Backpack straps (passing vertically over shoulders: X: 104..112 and 148..156)
    d_bas.rounded_rectangle([103, 98, 112, 140], radius=2, fill=COLOR_STRAP, outline=COLOR_STRAP_DARK)
    d_bas.rounded_rectangle([148, 98, 157, 140], radius=2, fill=COLOR_STRAP, outline=COLOR_STRAP_DARK)
    
    # E. Neck (Y: 86 to 96, X: 122 to 138)
    d_bas.rounded_rectangle([122, 86, 138, 96], radius=2, fill=COLOR_SKIN, outline=COLOR_SKIN_SHADOW)
    
    # F. Head & Face (Y: 44 to 90, X: 105 to 155)
    # Hair back layer framing the face
    d_bas.ellipse([102, 43, 158, 92], fill=COLOR_HAIR, outline=COLOR_HAIR_DARK)
    d_bas.ellipse([100, 52, 116, 96], fill=COLOR_HAIR_LIGHT) # left hair curtain
    d_bas.ellipse([144, 52, 160, 96], fill=COLOR_HAIR_LIGHT) # right hair curtain
    
    # Feminine Youthful Face oval (Y: 52 to 88, X: 112 to 148)
    d_bas.ellipse([112, 52, 148, 88], fill=COLOR_SKIN, outline=COLOR_SKIN_SHADOW)
    # Cheeks / skin highlight
    d_bas.ellipse([118, 60, 142, 82], fill=COLOR_SKIN_HIGHLIGHT)
    
    # Eyebrows (X: 118..128 and 132..142, Y: 62..64)
    d_bas.line([(117, 63), (127, 62)], fill=COLOR_HAIR_LIGHT, width=2)
    # Right eyebrow with Ellie's signature scar! (cut in eyebrow)
    d_bas.line([(133, 62), (137, 62)], fill=COLOR_HAIR_LIGHT, width=2)
    d_bas.line([(138, 61), (138, 65)], fill=COLOR_SKIN_HIGHLIGHT, width=1) # scar notch
    d_bas.line([(139, 62), (143, 63)], fill=COLOR_HAIR_LIGHT, width=2)
    
    # Large expressive eyes (Y: 66..70)
    # Left eye
    d_bas.ellipse([118, 65, 127, 70], fill=(250, 250, 250, 255))
    d_bas.ellipse([121, 65, 126, 70], fill=(42, 65, 48, 255)) # green/hazel iris
    d_bas.ellipse([122, 66, 124, 68], fill=(15, 15, 15, 255)) # pupil
    # Right eye
    d_bas.ellipse([133, 65, 142, 70], fill=(250, 250, 250, 255))
    d_bas.ellipse([134, 65, 139, 70], fill=(42, 65, 48, 255)) # green/hazel iris
    d_bas.ellipse([136, 66, 138, 68], fill=(15, 15, 15, 255)) # pupil
    
    # Delicate nose bridge and nostrils (Y: 72..76, X: 128..132)
    d_bas.line([(130, 71), (130, 75)], fill=COLOR_SKIN_SHADOW, width=1)
    d_bas.point([(129, 75), (131, 75)], fill=COLOR_SKIN_DARK)
    
    # Freckles!
    d_bas.point([(124, 72), (126, 74), (134, 73), (136, 72), (130, 73)], fill=COLOR_HAIR_LIGHT)
    
    # Soft coral lips (Y: 79..82, X: 125..135)
    d_bas.polygon([(126, 80), (130, 79), (134, 80), (132, 82), (128, 82)], fill=(215, 115, 105, 255))
    
    # Clean chin - NO beard! Smooth rounded jawline
    d_bas.arc([118, 76, 142, 87], start=0, end=180, fill=COLOR_SKIN_SHADOW, width=1)
    
    # Front Bangs / Hair Fringe covering forehead (Y: 45 to 62)
    d_bas.polygon([(104, 48), (156, 48), (152, 60), (135, 62), (125, 59), (110, 61)], fill=COLOR_HAIR)
    d_bas.line([(108, 48), (128, 59)], fill=COLOR_HAIR_LIGHT, width=2)
    d_bas.line([(120, 48), (140, 59)], fill=COLOR_HAIR_HIGHLIGHT, width=2)
    d_bas.line([(132, 48), (150, 58)], fill=COLOR_HAIR_LIGHT, width=2)
    
    # -------------------------------------------------------------
    # 2. ELLIE HAUT (Back View)
    # -------------------------------------------------------------
    im_haut = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    d_haut = ImageDraw.Draw(im_haut)
    
    # A. Shoes / Feet from Behind (Y: 215 to 241)
    # Left foot heel (X: 92..112)
    d_haut.rounded_rectangle([92, 218, 112, 240], radius=4, fill=COLOR_SNEAKER_RED, outline=COLOR_SHIRT_DARK)
    d_haut.rounded_rectangle([92, 234, 112, 241], radius=2, fill=COLOR_SNEAKER_SOLE, outline=COLOR_SNEAKER_SHADOW)
    d_haut.rounded_rectangle([98, 224, 106, 236], radius=2, fill=COLOR_SNEAKER_RUBBER) # white heel patch
    # Right foot heel (X: 148..168)
    d_haut.rounded_rectangle([148, 218, 168, 240], radius=4, fill=COLOR_SNEAKER_RED, outline=COLOR_SHIRT_DARK)
    d_haut.rounded_rectangle([148, 234, 168, 241], radius=2, fill=COLOR_SNEAKER_SOLE, outline=COLOR_SNEAKER_SHADOW)
    d_haut.rounded_rectangle([154, 224, 162, 236], radius=2, fill=COLOR_SNEAKER_RUBBER) # white heel patch
    
    # B. Slim Jeans from Behind (Y: 148 to 222)
    # Left leg
    d_haut.polygon([(100, 148), (118, 148), (114, 222), (94, 222)], fill=COLOR_PANTS, outline=COLOR_PANTS_DARK)
    d_haut.line([(104, 160), (103, 218)], fill=COLOR_PANTS_SHADOW, width=2)
    # Right leg
    d_haut.polygon([(142, 148), (160, 148), (166, 222), (146, 222)], fill=COLOR_PANTS, outline=COLOR_PANTS_DARK)
    d_haut.line([(156, 160), (157, 218)], fill=COLOR_PANTS_SHADOW, width=2)
    # Back pelvis & back pockets (Y: 138 to 155, X: 94..166)
    d_haut.polygon([(94, 140), (166, 140), (162, 155), (130, 162), (98, 155)], fill=COLOR_PANTS, outline=COLOR_PANTS_DARK)
    # Back pockets
    d_haut.rectangle([102, 144, 114, 154], fill=COLOR_PANTS_LIGHT, outline=COLOR_PANTS_DARK)
    d_haut.rectangle([146, 144, 158, 154], fill=COLOR_PANTS_LIGHT, outline=COLOR_PANTS_DARK)
    
    # C. Bare Arms from Behind
    d_haut.rounded_rectangle([78, 110, 93, 144], radius=4, fill=COLOR_SKIN, outline=COLOR_SKIN_SHADOW)
    d_haut.ellipse([78, 140, 92, 152], fill=COLOR_SKIN, outline=COLOR_SKIN_DARK)
    d_haut.rounded_rectangle([167, 110, 182, 144], radius=4, fill=COLOR_SKIN, outline=COLOR_SKIN_SHADOW)
    d_haut.ellipse([168, 140, 182, 152], fill=COLOR_SKIN, outline=COLOR_SKIN_DARK)
    
    # D. Red T-Shirt Shoulders and Sides
    d_haut.polygon([(96, 98), (164, 98), (170, 142), (90, 142)], fill=COLOR_SHIRT, outline=COLOR_SHIRT_DARK)
    d_haut.polygon([(82, 98), (96, 98), (96, 114), (80, 112)], fill=COLOR_SHIRT, outline=COLOR_SHIRT_DARK)
    d_haut.polygon([(164, 98), (178, 98), (180, 112), (164, 114)], fill=COLOR_SHIRT, outline=COLOR_SHIRT_DARK)
    
    # E. Ellie's Iconic Backpack on Back (Y: 96 to 144, X: 98 to 162)
    # Main canvas bag
    d_haut.rounded_rectangle([98, 98, 162, 142], radius=8, fill=COLOR_BACKPACK, outline=COLOR_BACKPACK_DARK)
    # Top flap
    d_haut.rounded_rectangle([100, 98, 160, 118], radius=6, fill=COLOR_BACKPACK_LIGHT, outline=COLOR_BACKPACK_DARK)
    # Flap straps / buckles
    d_haut.line([(114, 100), (114, 126)], fill=COLOR_STRAP_DARK, width=3)
    d_haut.line([(146, 100), (146, 126)], fill=COLOR_STRAP_DARK, width=3)
    d_haut.rectangle([112, 122, 116, 126], fill=(190, 185, 170, 255)) # silver buckle
    d_haut.rectangle([144, 122, 148, 126], fill=(190, 185, 170, 255)) # silver buckle
    # Lower zipper pouch
    d_haut.rounded_rectangle([104, 126, 156, 140], radius=4, fill=COLOR_BACKPACK_SHADOW, outline=COLOR_BACKPACK_DARK)
    
    # Badges & Pins!
    # Space / iridescent purple spaceship badge (top left)
    d_haut.ellipse([104, 104, 112, 112], fill=(185, 75, 160, 255), outline=(220, 200, 80, 255))
    d_haut.point([(108, 108)], fill=(255, 255, 120, 255))
    # Punk / yellow button (center pocket)
    d_haut.ellipse([126, 128, 134, 136], fill=(235, 205, 50, 255), outline=COLOR_BACKPACK_DARK)
    
    # Flashlight clip on left shoulder strap (Y: 94..104, X: 94..100)
    d_haut.rounded_rectangle([94, 94, 100, 106], radius=2, fill=(45, 45, 50, 255), outline=(180, 180, 190, 255))
    
    # F. Head & Ponytail from Behind (Y: 44 to 96, X: 105 to 155)
    # Back of head rounded hair
    d_haut.ellipse([102, 43, 158, 92], fill=COLOR_HAIR, outline=COLOR_HAIR_DARK)
    d_haut.ellipse([108, 48, 152, 88], fill=COLOR_HAIR_LIGHT)
    
    # Hair gathered into high ponytail tie (Y: 54..60, X: 126..134)
    d_haut.ellipse([126, 54, 134, 62], fill=COLOR_HAIR_DARK) # dark hair band
    
    # Ponytail strands cascading down onto backpack (Y: 60 to 92, X: 122 to 138)
    d_haut.polygon([(126, 60), (134, 60), (138, 76), (135, 92), (129, 94), (125, 90), (122, 76)], fill=COLOR_HAIR)
    d_haut.line([(128, 62), (133, 78), (131, 92)], fill=COLOR_HAIR_HIGHLIGHT, width=2)
    d_haut.line([(126, 64), (125, 80), (128, 90)], fill=COLOR_HAIR_LIGHT, width=1)
    
    # Save Ellie sprites
    bas_path = os.path.join(SPRITES_DIR, "ellie_bas.png")
    haut_path = os.path.join(SPRITES_DIR, "ellie_haut.png")
    portrait_path = os.path.join(SPRITES_DIR, "ellie.png")
    
    im_bas.save(bas_path)
    im_haut.save(haut_path)
    im_bas.save(portrait_path)
    print("  Saved ellie_bas.png, ellie_haut.png, and ellie.png")

if __name__ == "__main__":
    build_joel_sprites()
    build_ellie_sprites()
    print("All sprites successfully built!")
