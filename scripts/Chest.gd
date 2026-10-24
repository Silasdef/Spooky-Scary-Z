extends Area2D
class_name Chest

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const SPRITE_PATH: String = "res://assets/sprites/mystery_box.png"
const AUDIO_JINGLE_PATH: String = "res://assets/audio/cod_zombies_mystery_box.mp3"
const AUDIO_FALLBACK_JINGLE_PATH: String = "res://assets/audio/mystery_box_jingle.wav"

# ==============================================================================
# ÉQUILIBRAGE JAM (Boîte Mystère Type Black Ops 2)
# ==============================================================================
@export_group("Equilibrage Coffre")
@export var interaction_radius: float = 85.0     ## Distance d'activation du coffre
@export var roll_duration: float = 2.2           ## Durée du défilement des armes (jingle BO)
@export var respawn_cooldown: float = 20.0       ## Temps avant réapparition sur la carte

var is_player_nearby: bool = false
var is_active: bool = true
var is_rolling: bool = false
var roll_timer: float = 0.0
var target_player: CharacterBody2D = null

# Objets / Armes potentiellement tirés par la boîte mystère
const REWARDS = [
	{"id": "laser_gun", "name": "Pistolet Laser (BO2)", "type": "weapon"},
	{"id": "dragonslayer", "name": "Dragonslayer (Guts)", "type": "weapon"},
	{"id": "boomerang", "name": "Boomerang Communiste", "type": "weapon"},
	{"id": "dash", "name": "Item Passif : Dash", "type": "passive"},
	{"id": "regen", "name": "Item Passif : Régénération", "type": "passive"},
	{"id": "tayon", "name": "Item Passif : Tayon (Aimant XP)", "type": "passive"}
]

var chosen_reward: Dictionary = {}
var roll_display_text: String = "???"

@onready var prompt_label: Label = $PromptLabel
@onready var roll_label: Label = $RollLabel
@onready var audio_jingle: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("chests")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	prompt_label.visible = false
	roll_label.visible = false
	
	if ResourceLoader.exists(SPRITE_PATH) and sprite != null:
		sprite.texture = load(SPRITE_PATH)
		sprite.scale = Vector2(0.12, 0.12)
	
	var jingle_path = AUDIO_JINGLE_PATH
	if not ResourceLoader.exists(jingle_path) and ResourceLoader.exists(AUDIO_FALLBACK_JINGLE_PATH):
		jingle_path = AUDIO_FALLBACK_JINGLE_PATH
		
	if ResourceLoader.exists(jingle_path):
		audio_jingle.stream = load(jingle_path)
		
	queue_redraw()

func _process(delta: float) -> void:
	if not is_active:
		return
		
	# Gestion de la séquence d'ouverture (Roll type BO2)
	if is_rolling:
		roll_timer += delta
		# Défilement rapide aléatoire des noms d'armes
		var random_index = randi() % REWARDS.size()
		roll_display_text = REWARDS[random_index]["name"]
		roll_label.text = roll_display_text
		queue_redraw()
		
		if roll_timer >= roll_duration:
			_complete_roll()
		return
		
	# Détection d'interaction joueur
	if is_player_nearby and Input.is_action_just_pressed("interact"):
		_open_chest()

func _open_chest() -> void:
	if not is_active or is_rolling:
		return
		
	is_rolling = true
	roll_timer = 0.0
	prompt_label.visible = false
	roll_label.visible = true
	
	# Tirage de la récompense
	chosen_reward = REWARDS[randi() % REWARDS.size()]
	
	# Lancement du jingle musical mythique de la boîte mystère
	if audio_jingle.stream != null:
		audio_jingle.play()
	queue_redraw()

func _complete_roll() -> void:
	is_rolling = false
	roll_label.text = "★ BOÎTE MYSTÈRE DÉVERROUILLÉE ! ★"
	
	# Ouvre le panneau de bonus / amélioration (identique au passage de niveau)
	var game_map = get_tree().get_first_node_in_group("game_map")
	if game_map != null and game_map.has_method("request_upgrade"):
		game_map.request_upgrade("★ COFFRE MYSTÈRE - CHOISISSEZ UN BONUS ★")
		
	# Disparition temporaire après ouverture
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		is_active = false
		visible = false
		prompt_label.visible = false
		roll_label.visible = false
		_schedule_respawn()
	)

func _give_reward_to_player(player: CharacterBody2D, reward: Dictionary) -> void:
	match reward["id"]:
		"laser_gun":
			if player.has_method("unlock_or_upgrade_weapon"):
				player.unlock_or_upgrade_weapon("laser_gun")
		"dragonslayer":
			if player.has_method("unlock_or_upgrade_weapon"):
				player.unlock_or_upgrade_weapon("dragonslayer")
		"boomerang":
			if player.has_method("unlock_or_upgrade_weapon"):
				player.unlock_or_upgrade_weapon("boomerang")
		"dash":
			if player.has_method("acquire_passive"):
				player.acquire_passive("dash")
		"regen":
			if player.has_method("acquire_passive"):
				player.acquire_passive("regen")
		"tayon":
			if player.has_method("acquire_passive"):
				player.acquire_passive("tayon")

func _schedule_respawn() -> void:
	await get_tree().create_timer(respawn_cooldown).timeout
	# Réapparaît à une position aléatoire sur la map
	var spawn_dist = randf_range(200.0, 900.0)
	var spawn_ang = randf() * TAU
	if is_instance_valid(target_player):
		global_position = target_player.global_position + Vector2.from_angle(spawn_ang) * spawn_dist
	is_active = true
	visible = true
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		target_player = body as CharacterBody2D
		if is_active and not is_rolling:
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
		prompt_label.visible = false

func _draw() -> void:
	if not visible:
		return
		
	# Si le sprite officiel est affiché
	if sprite != null and sprite.texture != null:
		if is_rolling:
			var beam_height = 90.0
			var beam_pts = PackedVector2Array([
				Vector2(-20, 0),
				Vector2(-35, -beam_height),
				Vector2(35, -beam_height),
				Vector2(20, 0)
			])
			draw_colored_polygon(beam_pts, Color(0.2, 0.6, 1.0, 0.35))
			draw_circle(Vector2(0, -beam_height * 0.6), 18.0, Color(1.0, 0.85, 0.2, 0.8))
		return
		
	# Dessin de la Boîte Mystère (caisse en bois renforcée de métal et point d'interrogation lumineux)
	var box_w = 48.0
	var box_h = 28.0
	var box_rect = Rect2(-box_w * 0.5, -box_h * 0.5, box_w, box_h)
	
	# Corps en bois foncé
	draw_rect(box_rect, Color(0.35, 0.22, 0.12))
	# Coins et renforts métalliques en bronze / or vieilli
	draw_rect(Rect2(-box_w * 0.5, -box_h * 0.5, 6, box_h), Color(0.75, 0.6, 0.2))
	draw_rect(Rect2(box_w * 0.5 - 6, -box_h * 0.5, 6, box_h), Color(0.75, 0.6, 0.2))
	draw_rect(Rect2(-box_w * 0.5, -box_h * 0.5, box_w, 5), Color(0.75, 0.6, 0.2))
	draw_rect(Rect2(-box_w * 0.5, box_h * 0.5 - 5, box_w, 5), Color(0.75, 0.6, 0.2))
	
	# Aura mystique bleue / dorée type BO2
	if is_rolling:
		var beam_height = 90.0
		var beam_pts = PackedVector2Array([
			Vector2(-20, 0),
			Vector2(-35, -beam_height),
			Vector2(35, -beam_height),
			Vector2(20, 0)
		])
		draw_colored_polygon(beam_pts, Color(0.2, 0.6, 1.0, 0.35)) # Faisceau lumineux ascendant
		draw_circle(Vector2(0, -beam_height * 0.6), 18.0, Color(1.0, 0.85, 0.2, 0.8))
	else:
		# Points d'interrogation "? ?" dorés caractéristiques au centre
		draw_arc(Vector2(-8, -4), 4.0, -PI, 0.2, 6, Color(1.0, 0.85, 0.1), 2.0)
		draw_circle(Vector2(-8, 4), 1.5, Color(1.0, 0.85, 0.1))
		draw_arc(Vector2(8, -4), 4.0, -PI, 0.2, 6, Color(1.0, 0.85, 0.1), 2.0)
		draw_circle(Vector2(8, 4), 1.5, Color(1.0, 0.85, 0.1))
