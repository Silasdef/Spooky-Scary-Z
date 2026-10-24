#!/usr/bin/env python3
import os
from PIL import Image
import numpy as np
from collections import deque

SPRITES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "sprites")

def flood_fill_transparency(im, bg_pred, min_island=150):
    im = im.convert("RGBA")
    arr = np.array(im)
    h, w, _ = arr.shape
    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    
    # Border pixels
    for y in range(h):
        for x in [0, w - 1]:
            q.append((y, x))
            visited[y, x] = True
    for x in range(w):
        for y in [0, h - 1]:
            if not visited[y, x]:
                q.append((y, x))
                visited[y, x] = True
                
    while q:
        y, x = q.popleft()
        r, g, b, _ = arr[y, x]
        if bg_pred(r, g, b):
            arr[y, x, 3] = 0
            for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                    visited[ny, nx] = True
                    q.append((ny, nx))
                    
    # Island filter to remove noisy specks
    if min_island > 0:
        visited_c = np.zeros((h, w), dtype=bool)
        for y in range(h):
            for x in range(w):
                if arr[y, x, 3] > 0 and not visited_c[y, x]:
                    comp = []
                    cq = deque([(y, x)])
                    visited_c[y, x] = True
                    while cq:
                        cy, cx = cq.popleft()
                        comp.append((cy, cx))
                        for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and not visited_c[ny, nx] and arr[ny, nx, 3] > 0:
                                visited_c[ny, nx] = True
                                cq.append((ny, nx))
                    if len(comp) < min_island:
                        for cy, cx in comp:
                            arr[cy, cx, 3] = 0
                            
    return Image.fromarray(arr)

def save_sprite_set(base_names, directions_dict, default_dir="bas"):
    dir_aliases = {
        "bas": ["bas", "down"],
        "haut": ["haut", "up"],
        "gauche": ["gauche", "left"],
        "droite": ["droite", "right"]
    }
    
    for base in base_names:
        # Default single texture
        default_img = directions_dict.get(default_dir) or next(iter(directions_dict.values()))
        default_path = os.path.join(SPRITES_DIR, f"{base}.png")
        default_img.save(default_path)
        
        for main_d, img in directions_dict.items():
            for alias in dir_aliases[main_d]:
                p = os.path.join(SPRITES_DIR, f"{base}_{alias}.png")
                img.save(p)
    print(f"  Saved variants for {base_names}")

def process_survivor():
    print("Processing Survivor...")
    src = Image.open(os.path.join(SPRITES_DIR, "survivor.jpeg"))
    # Uniform 260x260 centered crop
    bas = src.crop((126, 25, 386, 285))
    haut = src.crop((638, 25, 898, 285))
    droite = src.crop((126, 301, 386, 561))
    gauche = src.crop((638, 301, 898, 561))
    
    bg_pred = lambda r, g, b: (abs(int(r) - int(g)) < 15) and (abs(int(g) - int(b)) < 15) and (r > 130)
    dirs = {
        "bas": flood_fill_transparency(bas, bg_pred, min_island=150),
        "haut": flood_fill_transparency(haut, bg_pred, min_island=150),
        "droite": flood_fill_transparency(droite, bg_pred, min_island=150),
        "gauche": flood_fill_transparency(gauche, bg_pred, min_island=150)
    }
    save_sprite_set(["survivor", "player"], dirs, default_dir="bas")

def process_zombie():
    print("Processing Zombie Basic...")
    src = Image.open(os.path.join(SPRITES_DIR, "zombie.jpeg"))
    # 4 columns: uniform 256x290
    bas = src.crop((0, 140, 256, 430))
    haut = src.crop((256, 140, 512, 430))
    droite = src.crop((512, 140, 768, 430))
    gauche = src.crop((768, 140, 1024, 430))
    
    bg_pred = lambda r, g, b: np.linalg.norm(np.array([r, g, b]) - np.array([25, 25, 25])) < 25
    dirs = {
        "bas": flood_fill_transparency(bas, bg_pred, min_island=150),
        "haut": flood_fill_transparency(haut, bg_pred, min_island=150),
        "droite": flood_fill_transparency(droite, bg_pred, min_island=150),
        "gauche": flood_fill_transparency(gauche, bg_pred, min_island=150)
    }
    save_sprite_set(["zombie", "zombie_basic"], dirs, default_dir="bas")

def process_zombie_citrouille():
    print("Processing Zombie Citrouille...")
    src = Image.open(os.path.join(SPRITES_DIR, "zombie-citrouille.jpeg"))
    # Row 2 (unlabeled): uniform 250x250
    bas = src.crop((10, 310, 260, 560))
    droite = src.crop((265, 310, 515, 560))
    haut = src.crop((515, 310, 765, 560))
    gauche = src.crop((765, 310, 1015, 560))
    
    bg_pred = lambda r, g, b: np.linalg.norm(np.array([r, g, b]) - np.array([135, 135, 135])) < 25
    dirs = {
        "bas": flood_fill_transparency(bas, bg_pred, min_island=150),
        "haut": flood_fill_transparency(haut, bg_pred, min_island=150),
        "droite": flood_fill_transparency(droite, bg_pred, min_island=150),
        "gauche": flood_fill_transparency(gauche, bg_pred, min_island=150)
    }
    save_sprite_set(["zombie_citrouille", "zombie_pumpkin"], dirs, default_dir="bas")

def process_zombie_dog():
    print("Processing Zombie Dog...")
    src = Image.open(os.path.join(SPRITES_DIR, "zombie-dog.jpeg"))
    # Uniform 280x245
    bas = src.crop((0, 25, 280, 270))
    haut = src.crop((250, 25, 530, 270))
    droite = src.crop((665, 25, 945, 270))
    gauche = src.crop((135, 300, 415, 545))
    
    bg_pred = lambda r, g, b: np.linalg.norm(np.array([r, g, b]) - np.array([205, 205, 205])) < 25
    dirs = {
        "bas": flood_fill_transparency(bas, bg_pred, min_island=150),
        "haut": flood_fill_transparency(haut, bg_pred, min_island=150),
        "droite": flood_fill_transparency(droite, bg_pred, min_island=150),
        "gauche": flood_fill_transparency(gauche, bg_pred, min_island=150)
    }
    save_sprite_set(["zombie_dog", "zombie_chien"], dirs, default_dir="bas")

def process_frankenstein():
    print("Processing Frankenstein...")
    src = Image.open(os.path.join(SPRITES_DIR, "frankenstein.jpeg"))
    # Uniform 256x286
    bas = src.crop((0, 0, 256, 286))
    haut = src.crop((256, 0, 512, 286))
    droite = src.crop((0, 286, 256, 572))
    
    bg_pred = lambda r, g, b: (abs(int(r) - int(g)) < 8) and (abs(int(g) - int(b)) < 8) and (50 <= r <= 105)
    f_bas = flood_fill_transparency(bas, bg_pred, min_island=200)
    f_haut = flood_fill_transparency(haut, bg_pred, min_island=200)
    f_droite = flood_fill_transparency(droite, bg_pred, min_island=200)
    f_gauche = f_droite.transpose(Image.FLIP_LEFT_RIGHT)
    
    dirs = {
        "bas": f_bas,
        "haut": f_haut,
        "droite": f_droite,
        "gauche": f_gauche
    }
    save_sprite_set(["frankenstein", "frankenstein_boss"], dirs, default_dir="bas")

def process_dragonslayer():
    print("Processing Dragonslayer...")
    src = Image.open(os.path.join(SPRITES_DIR, "dragonslayer.jpeg"))
    bas = src.crop((49, 34, 188, 529))
    haut = src.crop((288, 34, 426, 529))
    gauche = src.crop((502, 101, 971, 263))
    droite = src.crop((487, 313, 977, 477))
    
    bg_pred = lambda r, g, b: (abs(int(r) - int(g)) < 8) and (abs(int(g) - int(b)) < 8) and (r > 25)
    dirs = {
        "bas": flood_fill_transparency(bas, bg_pred, min_island=150),
        "haut": flood_fill_transparency(haut, bg_pred, min_island=150),
        "gauche": flood_fill_transparency(gauche, bg_pred, min_island=150),
        "droite": flood_fill_transparency(droite, bg_pred, min_island=150)
    }
    save_sprite_set(["dragonslayer"], dirs, default_dir="bas")

def process_laser_gun():
    print("Processing Laser Gun...")
    src = Image.open(os.path.join(SPRITES_DIR, "pistolet-laser.jpeg"))
    bas = src.crop((215, 35, 315, 260))
    haut = src.crop((700, 35, 815, 260))
    droite = src.crop((70, 325, 485, 525))
    gauche = src.crop((540, 325, 955, 525))
    
    bg_pred = lambda r, g, b: (abs(int(r) - int(g)) < 4) and (abs(int(g) - int(b)) < 4) and (7 <= r <= 50)
    dirs = {
        "bas": flood_fill_transparency(bas, bg_pred, min_island=150),
        "haut": flood_fill_transparency(haut, bg_pred, min_island=150),
        "droite": flood_fill_transparency(droite, bg_pred, min_island=150),
        "gauche": flood_fill_transparency(gauche, bg_pred, min_island=150)
    }
    save_sprite_set(["laser_gun", "pistolet_laser"], dirs, default_dir="droite")

def process_faucille_marteau():
    print("Processing Faucille & Marteau...")
    src = Image.open(os.path.join(SPRITES_DIR, "faucille-marteau.jpeg"))
    # 4 columns: uniform 256x260
    f0 = src.crop((10, 130, 266, 390))
    f1 = src.crop((266, 130, 522, 390))
    f2 = src.crop((522, 130, 778, 390))
    f3 = src.crop((778, 130, 1024, 390))
    
    bg_pred = lambda r, g, b: (r > 240) and (g > 240) and (b > 240)
    dirs = {
        "bas": flood_fill_transparency(f0, bg_pred, min_island=150),
        "droite": flood_fill_transparency(f1, bg_pred, min_island=150),
        "haut": flood_fill_transparency(f2, bg_pred, min_island=150),
        "gauche": flood_fill_transparency(f3, bg_pred, min_island=150)
    }
    save_sprite_set(["faucille_marteau", "sickle_hammer"], dirs, default_dir="bas")
    
    # Also save indexed frames (0, 1, 2, 3) for spinning animation
    for i, img in enumerate([dirs["bas"], dirs["droite"], dirs["haut"], dirs["gauche"]]):
        img.save(os.path.join(SPRITES_DIR, f"faucille_marteau_{i}.png"))
        img.save(os.path.join(SPRITES_DIR, f"sickle_hammer_{i}.png"))

def process_chest():
    print("Processing Chest...")
    src = Image.open(os.path.join(SPRITES_DIR, "chest.jpeg"))
    crop = src.crop((220, 120, 800, 650))
    bg_pred = lambda r, g, b: np.linalg.norm(np.array([r, g, b]) - np.array([87, 87, 87])) < 25
    clean = flood_fill_transparency(crop, bg_pred, min_island=200)
    
    dirs = {"bas": clean, "haut": clean, "gauche": clean, "droite": clean}
    save_sprite_set(["chest", "mystery_box"], dirs, default_dir="bas")

def process_dash_boots():
    print("Processing Dash Boots...")
    src = Image.open(os.path.join(SPRITES_DIR, "dash-boots.jpeg"))
    crop = src.crop((245, 90, 795, 470))
    bg_pred = lambda r, g, b: np.linalg.norm(np.array([r, g, b]) - np.array([33, 33, 33])) < 20
    clean_right = flood_fill_transparency(crop, bg_pred, min_island=200)
    clean_left = clean_right.transpose(Image.FLIP_LEFT_RIGHT)
    
    dirs = {"bas": clean_right, "haut": clean_right, "droite": clean_right, "gauche": clean_left}
    save_sprite_set(["dash_boots", "dash", "boots"], dirs, default_dir="droite")

def process_popolife():
    print("Processing Popolife...")
    src = Image.open(os.path.join(SPRITES_DIR, "popolife.jpeg"))
    crop = src.crop((330, 25, 690, 545))
    bg_pred = lambda r, g, b: np.linalg.norm(np.array([r, g, b]) - np.array([77, 77, 77])) < 20
    clean = flood_fill_transparency(crop, bg_pred, min_island=200)
    
    dirs = {"bas": clean, "haut": clean, "gauche": clean, "droite": clean}
    save_sprite_set(["popolife", "potion_vie", "regen"], dirs, default_dir="bas")

def process_aimant():
    print("Processing Aimant...")
    src = Image.open(os.path.join(SPRITES_DIR, "aimant.jpg"))
    crop = src.crop((280, 60, 760, 530))
    bg_pred = lambda r, g, b: (abs(int(r) - int(g)) < 15) and (abs(int(g) - int(b)) < 15) and (r > 180)
    clean = flood_fill_transparency(crop, bg_pred, min_island=200)
    
    dirs = {"bas": clean, "haut": clean, "gauche": clean, "droite": clean}
    save_sprite_set(["aimant", "tayon", "magnet"], dirs, default_dir="bas")

def main():
    print(f"Target sprites directory: {SPRITES_DIR}")
    process_survivor()
    process_zombie()
    process_zombie_citrouille()
    process_zombie_dog()
    process_frankenstein()
    process_dragonslayer()
    process_laser_gun()
    process_faucille_marteau()
    process_chest()
    process_dash_boots()
    process_popolife()
    process_aimant()
    print("All sprites successfully processed and exported!")

if __name__ == "__main__":
    main()
