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
const AUDIO_HURT_PATH: String = "res://assets/audio/player_hurt.wav"
const AUDIO_DASH_PATH: String = "res://assets/audio/dash.wav"
const AUDIO_LEVELUP_PATH: String = "res://assets/audio/level_up.wav"

# ==============================================================================
# ÉQUILIBRAGE JAM (Joueur & Capacités)
# ==============================================================================
@export_group("Equilibrage Joueur")
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

var weapon_laser_gun: LaserGun = null
var weapon_dragonslayer: Dragonslayer = null
var weapon_boomerang: CommunistBoomerang = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var weapons_container: Node2D = $WeaponsContainer
@onready var audio_dash: AudioStreamPlayer2D = $AudioDash
@onready var audio_hurt: AudioStreamPlayer2D = $AudioHurt

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	
	_ensure_default_input_actions()
	_update_pickup_radius()
	
	# Initialisation des signaux d'interface
	hp_changed.emit(current_health, max_health)
	xp_changed.emit(current_xp, xp_required, current_level)
	
	# Chargement des armes attachées ou existantes
	_initialize_weapons()
	
	if ResourceLoader.exists(SPRITE_PATH):
		sprite.texture = load(SPRITE_PATH)
		sprite.scale = Vector2(0.24, 0.24)
	else:
		queue_redraw()
		
	if ResourceLoader.exists(AUDIO_DASH_PATH):
		audio_dash.stream = load(AUDIO_DASH_PATH)
	if ResourceLoader.exists(AUDIO_HURT_PATH):
		audio_hurt.stream = load(AUDIO_HURT_PATH)
		
	# Connexion de la zone d'aspiration d'XP
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
		if dash_timer <= 0.0:
			is_dashing = false
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
	
	# Si aucune direction n'est pressée, on dash dans la direction regardée
	if input_vec.length_squared() > 0.01:
		dash_direction = input_vec.normalized()
	else:
		dash_direction = facing_direction
		
	if audio_dash.stream != null:
		audio_dash.play()
		
	# Effet visuel : étincelle de propulsion
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
	var dir_suffix = "bas"
	if abs(facing_direction.x) > abs(facing_direction.y):
		dir_suffix = "droite" if facing_direction.x > 0 else "gauche"
	else:
		dir_suffix = "bas" if facing_direction.y > 0 else "haut"
		
	var path = "res://assets/sprites/player_%s.png" % dir_suffix
	if ResourceLoader.exists(path):
		var tex = load(path)
		if sprite.texture != tex:
			sprite.texture = tex

func _draw() -> void:
	# Effets visuels (Aura Tayon et traînée de Dash)
	var radius = base_pickup_radius * (tayon_radius_multiplier if has_tayon else 1.0)
	var tayon_color = Color(0.1, 0.8, 1.0, 0.08) if has_tayon else Color(1.0, 1.0, 1.0, 0.04)
	draw_circle(Vector2.ZERO, radius, tayon_color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(tayon_color.r, tayon_color.g, tayon_color.b, 0.2), 1.0)
	
	if is_dashing:
		draw_circle(-dash_direction * 18.0, 12.0, Color(0.2, 0.7, 1.0, 0.4))
		draw_circle(-dash_direction * 32.0, 8.0, Color(0.2, 0.7, 1.0, 0.2))
	
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
