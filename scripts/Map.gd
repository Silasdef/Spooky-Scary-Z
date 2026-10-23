extends Node2D
class_name GameMap

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const AUDIO_GAME_BGM_PATH: String = "res://assets/audio/game_theme.wav"
const ZOMBIE_BASIC_SCENE_PATH: String = "res://scenes/Enemies/ZombieBasic.tscn"
const ZOMBIE_DOG_SCENE_PATH: String = "res://scenes/Enemies/ZombieDog.tscn"
const FRANKENSTEIN_SCENE_PATH: String = "res://scenes/Enemies/FrankensteinBoss.tscn"
const CHEST_SCENE_PATH: String = "res://scenes/Chest/Chest.tscn"

# ==============================================================================
# ÉQUILIBRAGE JAM (Arène, Spawns & Vagues)
# ==============================================================================
@export_group("Equilibrage Arene")
@export var arena_size: float = 3600.0           ## Taille totale de l'arène carrée (px)
@export var base_spawn_interval: float = 1.4    ## Temps entre deux apparitions d'ennemis (sec)
@export var min_spawn_interval: float = 0.45    ## Intervalle de spawn minimum au pic de difficulté
@export var dog_spawn_time: float = 45.0        ## Temps de survie avant apparition des Chiens Zombies
@export var boss_spawn_interval: float = 90.0   ## Fréquence d'apparition du Boss Frankenstein

var game_time: float = 0.0
var spawn_timer: float = 0.0
var last_boss_time: float = 0.0
var is_game_over: bool = false

# Références aux scènes préchargées
var scene_zombie_basic: PackedScene = null
var scene_zombie_dog: PackedScene = null
var scene_frankenstein: PackedScene = null
var scene_chest: PackedScene = null

@onready var player: Player = $Player
@onready var enemies_container: Node2D = $EnemiesContainer
@onready var chests_container: Node2D = $ChestsContainer
@onready var arena_walls: StaticBody2D = $ArenaWalls

# UI HUD
@onready var hud: CanvasLayer = $HUD
@onready var hp_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/TopRow/HPBar
@onready var hp_label: Label = $HUD/MarginContainer/VBoxContainer/TopRow/HPBar/HPLabel
@onready var xp_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/XPBar
@onready var xp_label: Label = $HUD/MarginContainer/VBoxContainer/XPBar/XPLabel
@onready var timer_label: Label = $HUD/MarginContainer/VBoxContainer/TopRow/TimerLabel
@onready var kills_label: Label = $HUD/MarginContainer/VBoxContainer/TopRow/KillsLabel
@onready var passives_label: Label = $HUD/PassiveItemsPanel/PassivesLabel
@onready var levelup_modal: PanelContainer = $HUD/LevelUpModal
@onready var choices_container: HBoxContainer = $HUD/LevelUpModal/VBox/ChoicesContainer
@onready var game_over_screen: PanelContainer = $HUD/GameOverScreen
@onready var final_stats_label: Label = $HUD/GameOverScreen/VBox/StatsLabel
@onready var btn_restart: Button = $HUD/GameOverScreen/VBox/RestartButton
@onready var btn_menu: Button = $HUD/GameOverScreen/VBox/MenuButton
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

func _ready() -> void:
	_preload_scenes()
	_setup_arena_walls()
	_spawn_initial_chests()
	
	levelup_modal.visible = false
	game_over_screen.visible = false
	
	# Connexions joueur
	if is_instance_valid(player):
		player.hp_changed.connect(_on_player_hp_changed)
		player.xp_changed.connect(_on_player_xp_changed)
		player.level_up.connect(_on_player_level_up)
		player.player_died.connect(_on_player_died)
		
	# Boutons Game Over
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)
	
	if ResourceLoader.exists(AUDIO_GAME_BGM_PATH):
		bgm_player.stream = load(AUDIO_GAME_BGM_PATH)
		bgm_player.play()
		
	queue_redraw()

func _preload_scenes() -> void:
	if ResourceLoader.exists(ZOMBIE_BASIC_SCENE_PATH):
		scene_zombie_basic = load(ZOMBIE_BASIC_SCENE_PATH)
	if ResourceLoader.exists(ZOMBIE_DOG_SCENE_PATH):
		scene_zombie_dog = load(ZOMBIE_DOG_SCENE_PATH)
	if ResourceLoader.exists(FRANKENSTEIN_SCENE_PATH):
		scene_frankenstein = load(FRANKENSTEIN_SCENE_PATH)
	if ResourceLoader.exists(CHEST_SCENE_PATH):
		scene_chest = load(CHEST_SCENE_PATH)

func _setup_arena_walls() -> void:
	# Construit les 4 bordures physiques de l'arène carrée
	var half = arena_size * 0.5
	var thickness = 100.0
	
	# Murs : Nord, Sud, Ouest, Est
	var walls_data = [
		{"pos": Vector2(0, -half - thickness * 0.5), "size": Vector2(arena_size + thickness * 2.0, thickness)},
		{"pos": Vector2(0, half + thickness * 0.5), "size": Vector2(arena_size + thickness * 2.0, thickness)},
		{"pos": Vector2(-half - thickness * 0.5, 0), "size": Vector2(thickness, arena_size + thickness * 2.0)},
		{"pos": Vector2(half + thickness * 0.5, 0), "size": Vector2(thickness, arena_size + thickness * 2.0)}
	]
	
	for w in walls_data:
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = w["size"]
		col.shape = shape
		col.position = w["pos"]
		arena_walls.add_child(col)

func _spawn_initial_chests() -> void:
	if scene_chest == null:
		return
		
	# Dispose 4 Boîtes Mystères réparties dans les quadrants pour encourager l'exploration
	var offsets = [
		Vector2(-700, -700),
		Vector2(700, -700),
		Vector2(-700, 700),
		Vector2(700, 700)
	]
	for off in offsets:
		var chest = scene_chest.instantiate() as Node2D
		chest.position = off
		chests_container.add_child(chest)

func _process(delta: float) -> void:
	if is_game_over:
		return
		
	game_time += delta
	_update_hud_timer_and_kills()
	_update_passives_display()
	
	# Gestion du Spawner d'ennemis avec montée progressive de difficulté
	var current_interval = max(min_spawn_interval, base_spawn_interval - (game_time / 300.0) * 0.8)
	spawn_timer += delta
	if spawn_timer >= current_interval:
		_spawn_enemy()
		spawn_timer = 0.0
		
	# Spawner périodique du Boss Frankenstein
	if game_time - last_boss_time >= boss_spawn_interval:
		_spawn_boss()
		last_boss_time = game_time

func _spawn_enemy() -> void:
	if not is_instance_valid(player):
		return
		
	# Spawn en périphérie autour du joueur hors caméra (~750px)
	var spawn_dist = randf_range(720.0, 850.0)
	var spawn_ang = randf() * TAU
	var spawn_pos = player.global_position + Vector2.from_angle(spawn_ang) * spawn_dist
	
	# Vérification des bordures de l'arène
	var half = arena_size * 0.48
	spawn_pos.x = clamp(spawn_pos.x, -half, half)
	spawn_pos.y = clamp(spawn_pos.y, -half, half)
	
	# Choix du type selon le temps écoulé
	var enemy_instance: Node2D = null
	if game_time > dog_spawn_time and randf() < 0.35:
		if scene_zombie_dog != null:
			enemy_instance = scene_zombie_dog.instantiate()
	else:
		if scene_zombie_basic != null:
			enemy_instance = scene_zombie_basic.instantiate()
			
	if enemy_instance != null:
		enemy_instance.global_position = spawn_pos
		enemies_container.add_child(enemy_instance)

func _spawn_boss() -> void:
	if scene_frankenstein == null or not is_instance_valid(player):
		return
	var spawn_ang = randf() * TAU
	var spawn_pos = player.global_position + Vector2.from_angle(spawn_ang) * 800.0
	var boss = scene_frankenstein.instantiate() as Node2D
	boss.global_position = spawn_pos
	enemies_container.add_child(boss)

func _draw() -> void:
	# Dessin du sol de l'arène et des murs imposants
	var half = arena_size * 0.5
	var arena_rect = Rect2(-half, -half, arena_size, arena_size)
	
	# Sol dallé sombre
	draw_rect(arena_rect, Color(0.08, 0.07, 0.09))
	
	# Trame / grille discrète d'ambiance pour ressentir la vitesse
	var grid_step = 200.0
	var x = -half
	while x <= half:
		draw_line(Vector2(x, -half), Vector2(x, half), Color(0.12, 0.11, 0.14), 1.0)
		x += grid_step
	var y = -half
	while y <= half:
		draw_line(Vector2(-half, y), Vector2(half, y), Color(0.12, 0.11, 0.14), 1.0)
		y += grid_step
		
	# Mur d'enceinte / barrière physique fortifiée
	draw_rect(arena_rect, Color(0.85, 0.2, 0.2, 0.8), false, 8.0)
	draw_rect(Rect2(-half - 20, -half - 20, arena_size + 40, arena_size + 40), Color(0.3, 0.05, 0.05, 0.9), false, 12.0)

func _update_hud_timer_and_kills() -> void:
	var mins = int(game_time) / 60
	var secs = int(game_time) % 60
	timer_label.text = "⏱️ %02d:%02d" % [mins, secs]
	if is_instance_valid(player):
		kills_label.text = "💀 Kills : %d" % player.enemies_killed

func _update_passives_display() -> void:
	if not is_instance_valid(player):
		return
	var status = "ITEMS & ARMES :\n"
	status += "• Pistolet Laser BO2 [Niv %d]\n" % (player.weapon_laser_gun.weapon_level if player.weapon_laser_gun else 0)
	status += "• Dragonslayer Guts [%s]\n" % ("Niv %d" % player.weapon_dragonslayer.weapon_level if player.weapon_dragonslayer else "Non possédé")
	status += "• Boomerang Communiste [%s]\n" % ("Niv %d" % player.weapon_boomerang.weapon_level if player.weapon_boomerang else "Non possédé")
	status += "• Dash : %s\n" % ("ACTIF (Espace)" if player.has_dash else "Inactif")
	status += "• Régénération : %s\n" % ("ACTIF (+PV/s)" if player.has_regen else "Inactif")
	status += "• Tayon (Aimant XP) : %s" % ("ACTIF (+160% zone)" if player.has_tayon else "Inactif")
	passives_label.text = status

func _on_player_hp_changed(curr: float, mx: float) -> void:
	hp_bar.max_value = mx
	hp_bar.value = curr
	hp_label.text = "PV : %d / %d" % [int(curr), int(mx)]

func _on_player_xp_changed(curr: int, req: int, lvl: int) -> void:
	xp_bar.max_value = req
	xp_bar.value = curr
	xp_label.text = "Niveau %d  (XP: %d / %d)" % [lvl, curr, req]

func _on_player_level_up(lvl: int) -> void:
	# Affichage de la fenêtre modale de montée de niveau
	_show_levelup_choices(lvl)

func _show_levelup_choices(lvl: int) -> void:
	get_tree().paused = true
	levelup_modal.visible = true
	
	# Nettoie les anciens boutons
	for child in choices_container.get_children():
		child.queue_free()
		
	var pool = [
		{"id": "laser_gun", "title": "Pistolet Laser", "desc": "+Dégâts et cadence laser vert", "type": "weapon"},
		{"id": "dragonslayer", "title": "Dragonslayer", "desc": "Épée colossale en arc ascendant", "type": "weapon"},
		{"id": "boomerang", "title": "Boomerang Communiste", "desc": "Faucille & marteau orbitaux", "type": "weapon"},
		{"id": "dash", "title": "Dash Classique", "desc": "Vitesse x3 pendant 0.2s (sans iframes)", "type": "passive"},
		{"id": "regen", "title": "Régénération", "desc": "Restaure passivement les PV", "type": "passive"},
		{"id": "tayon", "title": "Tayon", "desc": "Agrandit massivement l'aimant d'XP", "type": "passive"}
	]
	
	pool.shuffle()
	var selected_three = pool.slice(0, 3)
	
	for item in selected_three:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(210, 110)
		btn.text = "%s\n\n%s" % [item["title"], item["desc"]]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(func():
			if is_instance_valid(player):
				if item["type"] == "weapon":
					player.unlock_or_upgrade_weapon(item["id"])
				else:
					player.acquire_passive(item["id"])
			levelup_modal.visible = false
			get_tree().paused = false
		)
		choices_container.add_child(btn)

func _on_player_died() -> void:
	is_game_over = true
	var mins = int(game_time) / 60
	var secs = int(game_time) % 60
	final_stats_label.text = "Temps survécu : %02d:%02d\nEnnemis abattus : %d\nNiveau atteint : %d" % [mins, secs, player.enemies_killed, player.current_level]
	game_over_screen.visible = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Menu/MainMenu.tscn")
