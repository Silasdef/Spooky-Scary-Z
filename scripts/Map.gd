extends Node2D
class_name GameMap

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const AUDIO_GAME_BGM_PATH: String = "res://assets/audio/game_theme.wav"
const MAP_TEXTURE_PATH: String = "res://assets/sprites/map_apocalyptic_city_full.png"
const MAP_TEXTURE_FALLBACK: String = "res://assets/sprites/map_apocalyptic_city_seamless.png"
const ZOMBIE_BASIC_SCENE_PATH: String = "res://scenes/Enemies/ZombieBasic.tscn"
const ZOMBIE_DOG_SCENE_PATH: String = "res://scenes/Enemies/ZombieDog.tscn"
const FRANKENSTEIN_SCENE_PATH: String = "res://scenes/Enemies/FrankensteinBoss.tscn"
const CHEST_SCENE_PATH: String = "res://scenes/Chest/Chest.tscn"

# ==============================================================================
# ÉQUILIBRAGE JAM (Arène, Spawns & Hordes Vampire Survivors)
# ==============================================================================
@export_group("Equilibrage Arene & Hordes")
@export var arena_size: float = 3600.0           ## Taille totale de l'arène carrée (px)
@export var max_enemies: int = 450              ## Limite maximale d'ennemis simultanés sur la carte
@export var dog_spawn_time: float = 30.0        ## Temps de survie avant apparition des Chiens Zombies dans les hordes
@export var boss_spawn_interval: float = 75.0   ## Fréquence d'apparition du Boss Frankenstein

var game_time: float = 0.0
var spawn_timer: float = 0.0
var last_boss_time: float = 0.0
var is_game_over: bool = false
var upgrade_queue: Array[String] = []

# Références aux scènes préchargées
var scene_zombie_basic: PackedScene = null
var scene_zombie_dog: PackedScene = null
var scene_frankenstein: PackedScene = null
var scene_chest: PackedScene = null

@onready var background: Sprite2D = $Background if has_node("Background") else null
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
@onready var final_stats_label: Label = $HUD/GameOverScreen/Margin/VBox/StatsLabel
@onready var btn_restart: Button = $HUD/GameOverScreen/Margin/VBox/RestartButton
@onready var btn_menu: Button = $HUD/GameOverScreen/Margin/VBox/MenuButton
@onready var pause_modal: PanelContainer = $HUD/PauseModal
@onready var btn_pause_resume: Button = $HUD/PauseModal/Margin/VBox/ResumeButton
@onready var btn_pause_menu: Button = $HUD/PauseModal/Margin/VBox/MenuButton
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

func _ready() -> void:
	add_to_group("game_map")
	_preload_scenes()
	_setup_arena_walls()
	_spawn_initial_chests()
	
	levelup_modal.visible = false
	game_over_screen.visible = false
	pause_modal.visible = false
	
	# Connexions joueur
	if is_instance_valid(player):
		player.hp_changed.connect(_on_player_hp_changed)
		player.xp_changed.connect(_on_player_xp_changed)
		player.level_up.connect(_on_player_level_up)
		player.player_died.connect(_on_player_died)
		
	# Boutons Game Over & Pause
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)
	btn_pause_resume.pressed.connect(_on_resume_pressed)
	btn_pause_menu.pressed.connect(_on_menu_pressed)
	
	if ResourceLoader.exists(AUDIO_GAME_BGM_PATH):
		bgm_player.stream = load(AUDIO_GAME_BGM_PATH)
		bgm_player.play()
		
	# Initialisation de la texture de ville apocalyptique
	if background != null and background.texture == null:
		if ResourceLoader.exists(MAP_TEXTURE_PATH):
			background.texture = load(MAP_TEXTURE_PATH)
		elif ResourceLoader.exists(MAP_TEXTURE_FALLBACK):
			background.texture = load(MAP_TEXTURE_FALLBACK)
			background.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			background.region_enabled = true
			background.region_rect = Rect2(0, 0, arena_size, arena_size)
		
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
	
	# Gestion du Spawner d'ennemis en hordes progressives
	var current_interval = _calculate_spawn_interval()
	spawn_timer += delta
	if spawn_timer >= current_interval:
		_spawn_horde()
		spawn_timer = 0.0
		
	# Vérification et repositionnement des monstres sortis trop loin de l'écran (> 50% de la fenêtre de base)
	_check_and_relocate_distant_enemies()
		
	# Spawner périodique du Boss Frankenstein
	if game_time - last_boss_time >= boss_spawn_interval:
		_spawn_boss()
		last_boss_time = game_time
		
	queue_redraw()

func _calculate_spawn_interval() -> float:
	if game_time < 25.0:
		return 3.0
	elif game_time < 50.0:
		return 2.4
	elif game_time < 90.0:
		return 1.9
	elif game_time < 150.0:
		return 1.4
	elif game_time < 240.0:
		return 1.1
	else:
		return 0.85

func _calculate_current_horde_size() -> int:
	if game_time < 20.0:
		return randi_range(2, 3)
	elif game_time < 45.0:
		return randi_range(4, 6)
	elif game_time < 80.0:
		return randi_range(8, 12)
	elif game_time < 130.0:
		return randi_range(14, 20)
	elif game_time < 200.0:
		return randi_range(22, 32)
	else:
		return randi_range(35, 50)

func _spawn_horde() -> void:
	if not is_instance_valid(player):
		return
	if enemies_container.get_child_count() >= max_enemies:
		return
		
	var horde_size = _calculate_current_horde_size()
	
	# Nombre de groupes/flancs selon la taille de la horde
	var num_clusters = 1
	if horde_size >= 22:
		num_clusters = 3
	elif horde_size >= 9:
		num_clusters = 2
		
	var per_cluster = int(ceil(float(horde_size) / float(num_clusters)))
	var base_angle = randf() * TAU
	
	for c in range(num_clusters):
		var cluster_angle = base_angle + (c * (TAU / float(num_clusters))) + randf_range(-0.35, 0.35)
		var cluster_dist = randf_range(720.0, 850.0)
		var cluster_center = player.global_position + Vector2.from_angle(cluster_angle) * cluster_dist
		
		for i in range(per_cluster):
			if enemies_container.get_child_count() >= max_enemies:
				break
				
			# Décalage groupé pour former une horde compacte et naturelle
			var spread = randf_range(20.0, 70.0)
			var spread_angle = randf() * TAU
			var spawn_pos = cluster_center + Vector2.from_angle(spread_angle) * spread
			
			# Vérification des bordures de l'arène
			var half = arena_size * 0.48
			spawn_pos.x = clamp(spawn_pos.x, -half, half)
			spawn_pos.y = clamp(spawn_pos.y, -half, half)
			
			_spawn_enemy_instance_at(spawn_pos)

func _spawn_enemy_instance_at(spawn_pos: Vector2) -> void:
	var enemy_instance: Node2D = null
	# Apparition des chiens zombies rapides après dog_spawn_time au sein de la horde
	if game_time > dog_spawn_time and randf() < 0.28:
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

func _check_and_relocate_distant_enemies() -> void:
	if not is_instance_valid(player):
		return
		
	# Fenêtre de base : 1280x720. 50% en plus de la taille de base = demi-largeur 960px, demi-hauteur 540px.
	var max_dist_x: float = 960.0
	var max_dist_y: float = 540.0
	var max_dist_sq: float = 1050.0 * 1050.0
	
	for enemy in enemies_container.get_children():
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
			
		var offset = enemy.global_position - player.global_position
		# Si le mob est sorti trop loin de l'écran (> 50% au-delà de la taille de base de la fenêtre)
		if abs(offset.x) > max_dist_x or abs(offset.y) > max_dist_y or offset.length_squared() > max_dist_sq:
			var new_pos = _find_offscreen_spawn_pos()
			enemy.global_position = new_pos
			if "knockback_velocity" in enemy:
				enemy.knockback_velocity = Vector2.ZERO

func _find_offscreen_spawn_pos() -> Vector2:
	var half = arena_size * 0.48
	# Recherche d'une position hors de la fenêtre du joueur (~533x300 à zoom 1.2, ou 640x360 de base)
	for attempt in range(12):
		var ang = randf() * TAU
		var dist = randf_range(720.0, 860.0)
		var pos = player.global_position + Vector2.from_angle(ang) * dist
		pos.x = clamp(pos.x, -half, half)
		pos.y = clamp(pos.y, -half, half)
		
		# Vérifie impérativement que ce point n'est PAS visible sur l'écran du joueur
		var dx = abs(pos.x - player.global_position.x)
		var dy = abs(pos.y - player.global_position.y)
		if dx > 660.0 or dy > 380.0:
			return pos
			
	# Fallback sécurisé en périphérie
	var fallback_angle = randf() * TAU
	var fallback_pos = player.global_position + Vector2.from_angle(fallback_angle) * 750.0
	fallback_pos.x = clamp(fallback_pos.x, -half, half)
	fallback_pos.y = clamp(fallback_pos.y, -half, half)
	return fallback_pos

func _draw() -> void:
	# Dessin du sol de l'arène et des murs imposants
	var half = arena_size * 0.5
	var arena_rect = Rect2(-half, -half, arena_size, arena_size)
	
	# Si aucun sprite de background n'est assigné, fallback sur sol sombre
	if background == null or background.texture == null:
		draw_rect(arena_rect, Color(0.08, 0.07, 0.09))
		var grid_step = 200.0
		var x = -half
		while x <= half:
			draw_line(Vector2(x, -half), Vector2(x, half), Color(0.12, 0.11, 0.14), 1.0)
			x += grid_step
		var y = -half
		while y <= half:
			draw_line(Vector2(-half, y), Vector2(half, y), Color(0.12, 0.11, 0.14), 1.0)
			y += grid_step
	else:
		# Lueur radioactive animée au-dessus de la fissure toxique centrale
		var pulse = 0.75 + 0.25 * sin(game_time * 3.5)
		draw_circle(Vector2.ZERO, 90.0, Color(0.15, 0.9, 0.25, 0.10 * pulse))
		draw_circle(Vector2.ZERO, 45.0, Color(0.4, 1.0, 0.4, 0.18 * pulse))
		
	# Mur d'enceinte / barrière physique fortifiée
	draw_rect(arena_rect, Color(0.9, 0.15, 0.15, 0.85), false, 8.0)
	draw_rect(Rect2(-half - 20, -half - 20, arena_size + 40, arena_size + 40), Color(0.25, 0.04, 0.04, 0.95), false, 12.0)

func _update_hud_timer_and_kills() -> void:
	var mins = int(game_time) / 60
	var secs = int(game_time) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]
	if is_instance_valid(player):
		kills_label.text = "Kills : %d" % player.enemies_killed

func _update_passives_display() -> void:
	if not is_instance_valid(player):
		return
	var status = "ITEMS & ARMES :
"
	if player.weapon_laser_gun != null:
		var lvl = player.weapon_laser_gun.weapon_level
		status += "• Pistolet Laser BO2 [%s]
" % ("Niv %d (MAX)" % lvl if lvl >= 5 else "Niv %d" % lvl)
	else:
		status += "• Pistolet Laser BO2 [Non possédé]
"
		
	if player.weapon_dragonslayer != null:
		var lvl = player.weapon_dragonslayer.weapon_level
		status += "• Dragonslayer Guts [%s]
" % ("Niv %d (MAX)" % lvl if lvl >= 5 else "Niv %d" % lvl)
	else:
		status += "• Dragonslayer Guts [Non possédé]
"
		
	if player.weapon_boomerang != null:
		var lvl = player.weapon_boomerang.weapon_level
		status += "• Boomerang Communiste [%s]
" % ("Niv %d (MAX)" % lvl if lvl >= 5 else "Niv %d" % lvl)
	else:
		status += "• Boomerang Communiste [Non possédé]
"
		
	status += "• Dash : %s
" % ("ACTIF (MAX)" if player.has_dash else "Inactif")
	status += "• Régénération : %s
" % ("ACTIF (MAX)" if player.has_regen else "Inactif")
	status += "• Tayon (Aimant XP) : %s
" % ("ACTIF (MAX)" if player.has_tayon else "Inactif")
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
	request_upgrade("★ MONTÉE DE NIVEAU %d ★" % lvl)

func request_upgrade(modal_title: String) -> void:
	if levelup_modal.visible:
		upgrade_queue.append(modal_title)
	else:
		_show_upgrade_modal_direct(modal_title)

func _show_upgrade_modal_direct(modal_title: String) -> void:
	if not is_instance_valid(player):
		return
		
	get_tree().paused = true
	levelup_modal.visible = true
	
	var title_node = levelup_modal.get_node_or_null("VBox/Title") as Label
	if title_node != null:
		title_node.text = modal_title
		
	# Nettoie les anciens boutons
	for child in choices_container.get_children():
		child.queue_free()
		
	var pool: Array[Dictionary] = []
	
	# 1. Pistolet Laser BO2
	if player.weapon_laser_gun == null:
		pool.append({
			"id": "laser_gun",
			"type": "weapon",
			"title": "Pistolet Laser (BO2)",
			"desc": "★ NOUVELLE ARME ★
Tirs laser vert perçant"
		})
	elif player.weapon_laser_gun.weapon_level < 5:
		var next_lvl = player.weapon_laser_gun.weapon_level + 1
		pool.append({
			"id": "laser_gun",
			"type": "weapon",
			"title": "Pistolet Laser (BO2)",
			"desc": "★ AMÉLIORATION (Niv %d) ★
+25%% Dégâts & Cadence" % next_lvl
		})
	# Si niveau max (>= 5) : NE PLUS PROPOSER !
	
	# 2. Dragonslayer
	if player.weapon_dragonslayer == null:
		pool.append({
			"id": "dragonslayer",
			"type": "weapon",
			"title": "Dragonslayer (Guts)",
			"desc": "★ NOUVELLE ARME ★
Épée colossale balayant en arc"
		})
	elif player.weapon_dragonslayer.weapon_level < 5:
		var next_lvl = player.weapon_dragonslayer.weapon_level + 1
		pool.append({
			"id": "dragonslayer",
			"type": "weapon",
			"title": "Dragonslayer (Guts)",
			"desc": "★ AMÉLIORATION (Niv %d) ★\nLame colossale allongée & Arc géant" % next_lvl
		})
	# Si niveau max (>= 5) : NE PLUS PROPOSER !
	
	# 3. Boomerang Communiste
	if player.weapon_boomerang == null:
		pool.append({
			"id": "boomerang",
			"type": "weapon",
			"title": "Boomerang Communiste",
			"desc": "★ NOUVELLE ARME ★\nFaucille & marteau orbitaux"
		})
	elif player.weapon_boomerang.weapon_level < 5:
		var next_lvl = player.weapon_boomerang.weapon_level + 1
		pool.append({
			"id": "boomerang",
			"type": "weapon",
			"title": "Boomerang Communiste",
			"desc": "★ AMÉLIORATION (Niv %d) ★\n+%d Boomerangs orbitaux simultanés" % [next_lvl, next_lvl]
		})
	# Si niveau max (>= 5) : NE PLUS PROPOSER !
	
	# 4. Bottes de Dash (Passif)
	if not player.has_dash:
		pool.append({
			"id": "dash",
			"type": "passive",
			"title": "Bottes de Dash",
			"desc": "★ NOUVEAU PASSIF ★
Dash instantané vitesse x3 (Espace)"
		})
	# Si déjà possédé : NE PLUS PROPOSER !
	
	# 5. Régénération (Passif)
	if not player.has_regen:
		pool.append({
			"id": "regen",
			"type": "passive",
			"title": "Régénération",
			"desc": "★ NOUVEAU PASSIF ★\nRestaure +0.75 PV chaque seconde"
		})
	# Si déjà possédé : NE PLUS PROPOSER !
	
	# 6. Tayon (Aimant XP) (Passif)
	if not player.has_tayon:
		pool.append({
			"id": "tayon",
			"type": "passive",
			"title": "Tayon (Aimant XP)",
			"desc": "★ NOUVEAU PASSIF ★
Rayon d'aspiration d'XP accru (+160%)"
		})
	# Si déjà possédé : NE PLUS PROPOSER !
	
	# Si tout est niveau max, proposer un bonus de soin répétable
	if pool.is_empty():
		pool.append({
			"id": "heal",
			"type": "heal",
			"title": "Soin d'Urgence",
			"desc": "★ BONUS DE SANTÉ ★
Restaure +50 Points de Vie"
		})
		
	pool.shuffle()
	var selected_options = pool.slice(0, 3)
	
	for item in selected_options:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(210, 115)
		btn.text = "%s\n\n%s" % [item["title"], item["desc"]]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Styles spooky scary gothiques pour les cartes d'amélioration
		if ResourceLoader.exists("res://assets/sprites/ui/button_spooky_normal.png"):
			var sn = StyleBoxTexture.new()
			sn.texture = load("res://assets/sprites/ui/button_spooky_normal.png")
			sn.texture_margin_left = 16.0
			sn.texture_margin_top = 8.0
			sn.texture_margin_right = 16.0
			sn.texture_margin_bottom = 8.0
			
			var sh = StyleBoxTexture.new()
			sh.texture = load("res://assets/sprites/ui/button_spooky_hover.png")
			sh.texture_margin_left = 16.0
			sh.texture_margin_top = 8.0
			sh.texture_margin_right = 16.0
			sh.texture_margin_bottom = 8.0
			
			var sp = StyleBoxTexture.new()
			sp.texture = load("res://assets/sprites/ui/button_spooky_pressed.png")
			sp.texture_margin_left = 16.0
			sp.texture_margin_top = 8.0
			sp.texture_margin_right = 16.0
			sp.texture_margin_bottom = 8.0
			
			btn.add_theme_stylebox_override("normal", sn)
			btn.add_theme_stylebox_override("hover", sh)
			btn.add_theme_stylebox_override("focus", sh)
			btn.add_theme_stylebox_override("pressed", sp)
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.3, 0.3, 1))
			btn.add_theme_color_override("font_focus_color", Color(1.0, 0.3, 0.3, 1))

		btn.pressed.connect(func():
			if is_instance_valid(player):
				if item["type"] == "weapon":
					player.unlock_or_upgrade_weapon(item["id"])
				elif item["type"] == "passive":
					player.acquire_passive(item["id"])
				elif item["type"] == "heal":
					player.heal(50.0)
					
			_on_upgrade_resolved()
		)
		choices_container.add_child(btn)

	if choices_container.get_child_count() > 0:
		choices_container.get_child(0).grab_focus()

func _on_upgrade_resolved() -> void:
	if upgrade_queue.size() > 0:
		var next_title = upgrade_queue.pop_front()
		_show_upgrade_modal_direct(next_title)
	else:
		levelup_modal.visible = false
		get_tree().paused = false

func _on_player_died() -> void:
	is_game_over = true
	get_tree().paused = true
	var mins = int(game_time) / 60
	var secs = int(game_time) % 60
	final_stats_label.text = "⏱️ Temps survécu : %02d:%02d\n💀 Ennemis abattus : %d\n⚡ Niveau atteint : %d" % [mins, secs, player.enemies_killed, player.current_level]
	game_over_screen.visible = true
	btn_restart.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
		
	# Gestion de la pause avec la touche 'M' ou Échap
	var is_m_key = (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_M or event.physical_keycode == KEY_M or event.keycode == KEY_ESCAPE))
	var is_action_pause = event.is_action_pressed("toggle_pause")
	
	if is_m_key or is_action_pause:
		if is_game_over or levelup_modal.visible:
			return
		_toggle_pause()
		_mark_input_as_handled()
		return
		
	# Navigation au clavier dans le menu Pause
	if pause_modal.visible:
		if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode == KEY_UP or event.keycode == KEY_W or event.keycode == KEY_Z)):
			btn_pause_resume.grab_focus()
			_mark_input_as_handled()
		elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and (event.keycode == KEY_DOWN or event.keycode == KEY_S)):
			btn_pause_menu.grab_focus()
			_mark_input_as_handled()
		return

	# Navigation Game Over avec les flèches ou touches
	if is_game_over:
		if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode == KEY_UP or event.keycode == KEY_W or event.keycode == KEY_Z)):
			btn_restart.grab_focus()
			_mark_input_as_handled()
		elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and (event.keycode == KEY_DOWN or event.keycode == KEY_S)):
			btn_menu.grab_focus()
			_mark_input_as_handled()

func _toggle_pause() -> void:
	if pause_modal.visible:
		_on_resume_pressed()
	else:
		_open_pause_modal()

func _open_pause_modal() -> void:
	pause_modal.visible = true
	get_tree().paused = true
	btn_pause_resume.grab_focus()

func _on_resume_pressed() -> void:
	pause_modal.visible = false
	get_tree().paused = false

func _mark_input_as_handled() -> void:
	if is_inside_tree():
		var vp = get_viewport()
		if vp != null:
			vp.set_input_as_handled()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Menu/MainMenu.tscn")
