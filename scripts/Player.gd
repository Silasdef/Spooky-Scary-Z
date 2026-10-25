extends CharacterBody2D
class_name Player

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal hp_changed(current_hp: float, max_hp: float)
signal xp_changed(current_xp: int, xp_required: int, level: int)
signal level_up(new_level: int)
signal player_died()

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const SPRITE_PATH: String = "res://assets/sprites/player.png"
const CHARACTER_CONFIG_PATH: String = "user://selected_character.cfg"
const AUDIO_HURT_PATH: String = "res://assets/audio/player_hurt.wav"
const AUDIO_DASH_PATH: String = "res://assets/audio/dash.wav"
const AUDIO_LEVELUP_PATH: String = "res://assets/audio/level_up.wav"

# Sélection globale du personnage (Joel ou Ellie)
static var global_selected_character: String = "joel"

# ==============================================================================
# ÉQUILIBRAGE JAM (Joueur & Capacités)
# ==============================================================================
@export_group("Equilibrage Joueur")
@export var selected_character: String = "joel"   ## Personnage incarné ("joel" ou "ellie")
@export var base_speed: float = 140.0            ## Vitesse de marche ralentie (px/s)
@export var max_health: float = 100.0           ## Points de vie max
@export var base_pickup_radius: float = 90.0    ## Rayon d'aspiration d'XP de base

@export_group("Items Passifs")
@export var has_dash: bool = false              ## Dash classique débloqué
@export var has_regen: bool = false             ## Régénération passive de PV débloquée
@export var has_tayon: bool = false             ## Tayon (Extension d'aspiration XP) débloqué

@export_group("Equilibrage Dash")
@export var dash_speed_multiplier: float = 3.0  ## Multiplicateur de vitesse pendant le dash (x3)
@export var dash_duration: float = 0.2          ## Durée éclair du dash (0.2s)
@export var dash_cooldown: float = 1.5          ## Temps de recharge du dash (1.5s)
# Note : AUCUNE frame d'invincibilité pendant le dash (règle stricte d'équilibrage)

@export_group("Equilibrage Regeneration")
@export var regen_hps: float = 0.75              ## Points de vie régénérés par seconde (équilibré, 0.75 PV/s)

@export_group("Equilibrage Tayon")
@export var tayon_radius_multiplier: float = 2.6 ## Multiplicateur de zone d'XP avec Tayon

# Variables d'état
var current_health: float = 100.0
var current_xp: int = 0
var current_level: int = 1
var xp_required: int = 30
var enemies_killed: int = 0

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var facing_direction: Vector2 = Vector2.RIGHT
var dash_ghost_timer: float = 0.0

var weapon_laser_gun: LaserGun = null
var weapon_dragonslayer: Dragonslayer = null
var weapon_boomerang: CommunistBoomerang = null
var base_sprite_scale: Vector2 = Vector2(0.24, 0.24)

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var weapons_container: Node2D = $WeaponsContainer
@onready var audio_dash: AudioStreamPlayer2D = $AudioDash
@onready var audio_hurt: AudioStreamPlayer2D = $AudioHurt

func _ready() -> void:
	z_index = 10
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if pickup_area == null:
		pickup_area = get_node_or_null("PickupArea")
	if pickup_shape == null and pickup_area != null:
		pickup_shape = pickup_area.get_node_or_null("CollisionShape2D")
	if weapons_container == null:
		weapons_container = get_node_or_null("WeaponsContainer")
	if audio_dash == null:
		audio_dash = get_node_or_null("AudioDash")
	if audio_hurt == null:
		audio_hurt = get_node_or_null("AudioHurt")
		
	add_to_group("player")
	current_health = max_health
	
	# Chargement du personnage choisi (Joel ou Ellie)
	var saved_char = _load_saved_character()
	if saved_char != "":
		selected_character = saved_char
	elif global_selected_character != "":
		selected_character = global_selected_character
	global_selected_character = selected_character
	
	_ensure_default_input_actions()
	_update_pickup_radius()
	
	# Initialisation des signaux d'interface
	hp_changed.emit(current_health, max_health)
	xp_changed.emit(current_xp, xp_required, current_level)
	
	# Chargement des armes attachées ou existantes
	_initialize_weapons()
	
	if sprite != null:
		sprite.scale = base_sprite_scale
	_update_facing_sprite()
		
	if ResourceLoader.exists(AUDIO_DASH_PATH):
		audio_dash.stream = load(AUDIO_DASH_PATH)
	if ResourceLoader.exists(AUDIO_HURT_PATH):
		audio_hurt.stream = load(AUDIO_HURT_PATH)
		
	# Connexion de la zone d'aspiration d'XP
	if not pickup_area.area_entered.is_connected(_on_pickup_area_entered):
		pickup_area.area_entered.connect(_on_pickup_area_entered)

func _ensure_default_input_actions() -> void:
	# Garantit que les actions sont utilisables même si le projet est rechargé
	var actions = {
		"move_left": [KEY_A, KEY_Q, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_Z, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"dash": [KEY_SPACE, KEY_SHIFT],
		"interact": [KEY_E, KEY_ENTER]
	}
	for action in actions.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in actions[action]:
				var ev = InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)

func _initialize_weapons() -> void:
	# Déverrouillage par défaut de la première arme : Pistolet Laser BO2
	unlock_or_upgrade_weapon("laser_gun")

func _physics_process(delta: float) -> void:
	# Gestion du cooldown du Dash
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		
	# Gestion de l'état actif du Dash
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * (base_speed * dash_speed_multiplier)
		move_and_slide()
		
		# Traînée bleue de sprites derrière le joueur
		dash_ghost_timer += delta
		if dash_ghost_timer >= 0.03:
			dash_ghost_timer = 0.0
			_spawn_dash_ghost()
			
		_update_facing_sprite()
		
		# Animation dynamique du Dash (impulsion, étirement aérodynamique et inclinaison)
		var dash_prog = clamp(1.0 - (dash_timer / dash_duration), 0.0, 1.0)
		var impulse = sin(dash_prog * PI)
		var norm_dir = dash_direction.normalized() if dash_direction.length_squared() > 0.01 else facing_direction
		sprite.position = norm_dir * (impulse * 8.0)
		sprite.rotation = norm_dir.x * deg_to_rad(12.0) * impulse
		var stretch_x = 1.0 + (abs(norm_dir.x) * 0.28 - abs(norm_dir.y) * 0.12) * impulse
		var stretch_y = 1.0 + (abs(norm_dir.y) * 0.28 - abs(norm_dir.x) * 0.12) * impulse
		sprite.scale = base_sprite_scale * Vector2(stretch_x, stretch_y)
		sprite.modulate = Color(0.65, 0.9, 1.45, 1.0) # Teinte bleutée électrique vive
		
		if dash_timer <= 0.0:
			is_dashing = false
			sprite.position = Vector2.ZERO
			sprite.rotation = 0.0
			sprite.scale = base_sprite_scale
			sprite.modulate = Color.WHITE
			_update_facing_sprite()
		return
		
	# Déplacement 8 directions via Input.get_vector
	var input_vec = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vec.length_squared() > 0.01:
		facing_direction = input_vec.normalized()
		velocity = input_vec * base_speed
		_update_facing_sprite()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, base_speed * 6.0 * delta)
		
	move_and_slide()
	
	# Déclenchement du Dash (si possédé)
	if has_dash and Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		_perform_dash(input_vec)

func _process(delta: float) -> void:
	# Régénération passive des points de vie
	if has_regen and current_health < max_health:
		current_health = min(max_health, current_health + regen_hps * delta)
		hp_changed.emit(current_health, max_health)
	
	queue_redraw()

func _perform_dash(input_vec: Vector2) -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_ghost_timer = 0.0
	
	# Si aucune direction n'est pressée, on dash dans la direction regardée
	if input_vec.length_squared() > 0.01:
		dash_direction = input_vec.normalized()
	else:
		dash_direction = facing_direction
		
	if audio_dash.stream != null:
		audio_dash.play()
		
	_update_facing_sprite()
	_spawn_dash_ghost()
	queue_redraw()

func _update_pickup_radius() -> void:
	var final_radius = base_pickup_radius
	if has_tayon:
		final_radius *= tayon_radius_multiplier
		
	var shape = pickup_shape.shape as CircleShape2D
	if shape != null:
		shape.radius = final_radius

func _on_pickup_area_entered(area: Area2D) -> void:
	if area is LootGem:
		area.attract_to(self)

func add_xp(amount: int) -> void:
	current_xp += amount
	while current_xp >= xp_required:
		current_xp -= xp_required
		current_level += 1
		# Calcul courbe d'XP exponentielle modérée
		xp_required = int(xp_required * 1.35) + 10
		_on_level_up()
		
	xp_changed.emit(current_xp, xp_required, current_level)

func _on_level_up() -> void:
	level_up.emit(current_level)
	if ResourceLoader.exists(AUDIO_LEVELUP_PATH):
		var sfx = AudioStreamPlayer2D.new()
		sfx.stream = load(AUDIO_LEVELUP_PATH)
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)

func take_damage(amount: float) -> void:
	# ATTENTION : Même pendant le dash, AUCUNE frame d'invincibilité n'est accordée
	current_health -= amount
	hp_changed.emit(current_health, max_health)
	
	if audio_hurt.stream != null:
		audio_hurt.play()
		
	# Effet de tremblement / flash
	modulate = Color(1.8, 0.4, 0.4, 1.0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	if current_health <= 0.0:
		_die()

func register_kill() -> void:
	enemies_killed += 1

func _die() -> void:
	player_died.emit()
	set_physics_process(false)
	set_process(false)

const MAX_WEAPON_LEVEL: int = 5

func heal(amount: float) -> void:
	current_health = min(max_health, current_health + amount)
	hp_changed.emit(current_health, max_health)

func unlock_or_upgrade_weapon(weapon_id: String) -> void:
	match weapon_id:
		"laser_gun":
			if weapon_laser_gun == null:
				var scene = load("res://scenes/Weapons/LaserGun.tscn") as PackedScene
				weapon_laser_gun = scene.instantiate() as LaserGun
				weapons_container.add_child(weapon_laser_gun)
				if has_dash:
					weapon_laser_gun.set_dash_synergy(true)
			else:
				if weapon_laser_gun.weapon_level < MAX_WEAPON_LEVEL:
					weapon_laser_gun.upgrade()
		"dragonslayer":
			if weapon_dragonslayer == null:
				var scene = load("res://scenes/Weapons/Dragonslayer.tscn") as PackedScene
				weapon_dragonslayer = scene.instantiate() as Dragonslayer
				weapons_container.add_child(weapon_dragonslayer)
				if has_regen:
					weapon_dragonslayer.set_regen_synergy(true)
			else:
				if weapon_dragonslayer.weapon_level < MAX_WEAPON_LEVEL:
					weapon_dragonslayer.upgrade()
		"boomerang":
			if weapon_boomerang == null:
				var scene = load("res://scenes/Weapons/CommunistBoomerang.tscn") as PackedScene
				weapon_boomerang = scene.instantiate() as CommunistBoomerang
				weapons_container.add_child(weapon_boomerang)
				if has_tayon:
					weapon_boomerang.set_tayon_synergy(true)
			else:
				if weapon_boomerang.weapon_level < MAX_WEAPON_LEVEL:
					weapon_boomerang.upgrade()

func acquire_passive(passive_id: String) -> void:
	match passive_id:
		"dash":
			has_dash = true
			if weapon_laser_gun != null:
				weapon_laser_gun.set_dash_synergy(true)
		"regen":
			has_regen = true
			if weapon_dragonslayer != null:
				weapon_dragonslayer.set_regen_synergy(true)
		"tayon":
			has_tayon = true
			_update_pickup_radius()
			if weapon_boomerang != null:
				weapon_boomerang.set_tayon_synergy(true)

func _update_facing_sprite() -> void:
	var dir = dash_direction if is_dashing else facing_direction
	var dir_suffix = "bas"
	if abs(dir.x) > abs(dir.y):
		dir_suffix = "droite" if dir.x > 0 else "gauche"
	else:
		dir_suffix = "bas" if dir.y > 0 else "haut"
		
	var char_name = selected_character if selected_character != "" else global_selected_character
	if char_name == "":
		char_name = "joel"
		
	var path = "res://assets/sprites/%s_%s.png" % [char_name, dir_suffix]
	if not ResourceLoader.exists(path):
		path = "res://assets/sprites/player_%s.png" % dir_suffix
		
	if ResourceLoader.exists(path):
		var tex = load(path)
		if sprite != null and sprite.texture != tex:
			sprite.texture = tex

func set_character(char_name: String) -> void:
	selected_character = char_name
	global_selected_character = char_name
	save_character_selection(char_name)
	_update_facing_sprite()

static func save_character_selection(char_name: String) -> void:
	global_selected_character = char_name
	var cfg = ConfigFile.new()
	cfg.load(CHARACTER_CONFIG_PATH)
	cfg.set_value("game", "selected_character", char_name)
	cfg.save(CHARACTER_CONFIG_PATH)

func _load_saved_character() -> String:
	var cfg = ConfigFile.new()
	if cfg.load(CHARACTER_CONFIG_PATH) == OK:
		return cfg.get_value("game", "selected_character", "joel")
	return "joel"

func _spawn_dash_ghost() -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if sprite == null or sprite.texture == null or get_parent() == null:
		return
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.scale = sprite.scale
	ghost.rotation = sprite.rotation
	ghost.global_position = global_position + sprite.position
	ghost.z_index = 8 # Bien visible au-dessus du sol/background
	ghost.modulate = Color(0.2, 0.65, 1.0, 0.8) # Traînée bleue électrique éclatante
	get_parent().add_child(ghost)
	
	var tween = ghost.create_tween().set_parallel(true)
	if tween != null:
		tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
		tween.tween_property(ghost, "scale", sprite.scale * 0.85, 0.22)
		tween.chain().tween_callback(ghost.queue_free)

func _draw() -> void:
	# Si le sprite officiel est chargé, on ne dessine pas le corps procédural
	if sprite.texture != null:
		return
		
	# Fallback procédural : Survivant héroïque en vue du dessus
	# Épaules / Veste en cuir sombre
	draw_rect(Rect2(-12, -8, 24, 16), Color(0.25, 0.2, 0.18))
	# Tête
	draw_circle(Vector2(0, 0), 9.0, Color(0.85, 0.72, 0.6))
	# Cheveux bruns
	draw_circle(Vector2(0, -2), 8.5, Color(0.18, 0.12, 0.08))
	
	# Indicateur de visée / lampe torche dans la direction
	var pointer = facing_direction * 16.0
	draw_line(Vector2.ZERO, pointer, Color(1.0, 0.9, 0.5, 0.8), 2.5)

# ==============================================================================
# SAUVEGARDE & CHARGEMENT
# ==============================================================================
func get_save_data() -> Dictionary:
	var laser_lvl = weapon_laser_gun.weapon_level if weapon_laser_gun != null else 0
	var ds_lvl = weapon_dragonslayer.weapon_level if weapon_dragonslayer != null else 0
	var boom_lvl = weapon_boomerang.weapon_level if weapon_boomerang != null else 0
	
	return {
		"selected_character": selected_character,
		"current_health": current_health,
		"max_health": max_health,
		"current_xp": current_xp,
		"current_level": current_level,
		"xp_required": xp_required,
		"enemies_killed": enemies_killed,
		"has_dash": has_dash,
		"has_regen": has_regen,
		"has_tayon": has_tayon,
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"weapons": {
			"laser_gun": laser_lvl,
			"dragonslayer": ds_lvl,
			"boomerang": boom_lvl
		}
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("selected_character"):
		set_character(data["selected_character"])
	current_health = data.get("current_health", current_health)
	max_health = data.get("max_health", max_health)
	current_xp = data.get("current_xp", current_xp)
	current_level = data.get("current_level", current_level)
	xp_required = data.get("xp_required", xp_required)
	enemies_killed = data.get("enemies_killed", enemies_killed)
	
	has_dash = data.get("has_dash", false)
	has_regen = data.get("has_regen", false)
	has_tayon = data.get("has_tayon", false)
	_update_pickup_radius()
	
	if data.has("pos_x") and data.has("pos_y"):
		global_position = Vector2(data["pos_x"], data["pos_y"])
		
	var weapons_data = data.get("weapons", {})
	
	# Laser Gun
	var laser_target_lvl = weapons_data.get("laser_gun", 1)
	if laser_target_lvl > 0:
		if weapon_laser_gun == null:
			unlock_or_upgrade_weapon("laser_gun")
		while weapon_laser_gun != null and weapon_laser_gun.weapon_level < laser_target_lvl:
			weapon_laser_gun.upgrade()
			
	# Dragonslayer
	var ds_target_lvl = weapons_data.get("dragonslayer", 0)
	if ds_target_lvl > 0:
		if weapon_dragonslayer == null:
			unlock_or_upgrade_weapon("dragonslayer")
		while weapon_dragonslayer != null and weapon_dragonslayer.weapon_level < ds_target_lvl:
			weapon_dragonslayer.upgrade()
			
	# Boomerang
	var boom_target_lvl = weapons_data.get("boomerang", 0)
	if boom_target_lvl > 0:
		if weapon_boomerang == null:
			unlock_or_upgrade_weapon("boomerang")
		while weapon_boomerang != null and weapon_boomerang.weapon_level < boom_target_lvl:
			weapon_boomerang.upgrade()
			
	# Synergies passives
	if has_dash and weapon_laser_gun != null:
		weapon_laser_gun.set_dash_synergy(true)
	if has_regen and weapon_dragonslayer != null:
		weapon_dragonslayer.set_regen_synergy(true)
	if has_tayon and weapon_boomerang != null:
		weapon_boomerang.set_tayon_synergy(true)
		
	hp_changed.emit(current_health, max_health)
	xp_changed.emit(current_xp, xp_required, current_level)
