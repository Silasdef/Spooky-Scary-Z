extends Area2D
class_name Chest

signal chest_music_started
signal chest_music_finished

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
var weapon_cycle_timer: float = 0.0
var target_player: CharacterBody2D = null

# Objets / Armes potentiellement tirés par la boîte mystère avec icônes officielles
const REWARDS = [
	{"id": "laser_gun", "name": "Pistolet Laser", "type": "weapon", "icon": "res://assets/sprites/laser_gun.png"},
	{"id": "dragonslayer", "name": "Dragonslayer", "type": "weapon", "icon": "res://assets/sprites/dragonslayer_droite.png"},
	{"id": "boomerang", "name": "Boomerang Communiste", "type": "weapon", "icon": "res://assets/sprites/sickle_hammer.png"},
	{"id": "dash", "name": "Bottes de Dash", "type": "passive", "icon": "res://assets/sprites/dash_boots.png"},
	{"id": "regen", "name": "Régénération", "type": "passive", "icon": "res://assets/sprites/regen.png"},
	{"id": "tayon", "name": "Aimant", "type": "passive", "icon": "res://assets/sprites/tayon.png"}
]

var chosen_reward: Dictionary = {}
var roll_display_text: String = "???"
var is_chest_music_playing: bool = false
var current_preview_index: int = 0

@onready var prompt_label: Label = $PromptLabel
@onready var roll_label: Label = $RollLabel
@onready var audio_jingle: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_display: Node2D = $WeaponDisplay
@onready var weapon_sprite: Sprite2D = $WeaponDisplay/WeaponSprite

func _ready() -> void:
	if prompt_label == null:
		prompt_label = get_node_or_null("PromptLabel")
	if roll_label == null:
		roll_label = get_node_or_null("RollLabel")
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if anim_sprite == null:
		anim_sprite = get_node_or_null("AnimatedSprite2D")
	if weapon_display == null:
		weapon_display = get_node_or_null("WeaponDisplay")
	if weapon_sprite == null and weapon_display != null:
		weapon_sprite = weapon_display.get_node_or_null("WeaponSprite")
		
	add_to_group("chests")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	prompt_label.visible = false
	roll_label.visible = false
	if weapon_display != null:
		weapon_display.visible = false
	
	_setup_animated_sprite()
	
	if ResourceLoader.exists(SPRITE_PATH) and sprite != null:
		sprite.texture = load(SPRITE_PATH)
		sprite.scale = Vector2(0.45, 0.45)
	
	var jingle_path = AUDIO_JINGLE_PATH
	if not ResourceLoader.exists(jingle_path) and ResourceLoader.exists(AUDIO_FALLBACK_JINGLE_PATH):
		jingle_path = AUDIO_FALLBACK_JINGLE_PATH
		
	if ResourceLoader.exists(jingle_path):
		audio_jingle.stream = load(jingle_path)
		
	if audio_jingle != null and not audio_jingle.finished.is_connected(_on_audio_jingle_finished):
		audio_jingle.finished.connect(_on_audio_jingle_finished)
		
	queue_redraw()

func _setup_animated_sprite() -> void:
	if anim_sprite == null:
		return
		
	var sprite_frames = SpriteFrames.new()
	
	# 1. Animation "idle" : coffre fermé (frames 0 à 6)
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 6.0)
	sprite_frames.set_animation_loop("idle", true)
	for i in range(7):
		var p = "res://assets/sprites/mystery_box_frames/frame_%02d.png" % i
		if ResourceLoader.exists(p):
			sprite_frames.add_frame("idle", load(p))
			
	# 2. Animation "open" : ouverture et boîte mystère lumineuse pulsante (frames 7 à 65)
	sprite_frames.add_animation("open")
	sprite_frames.set_animation_speed("open", 14.0)
	sprite_frames.set_animation_loop("open", true)
	for i in range(7, 66):
		var p = "res://assets/sprites/mystery_box_frames/frame_%02d.png" % i
		if ResourceLoader.exists(p):
			sprite_frames.add_frame("open", load(p))
			
	# 3. Animation "close" : fermeture de la boîte (frames 66 à 70)
	sprite_frames.add_animation("close")
	sprite_frames.set_animation_speed("close", 12.0)
	sprite_frames.set_animation_loop("close", false)
	for i in range(66, 71):
		var p = "res://assets/sprites/mystery_box_frames/frame_%02d.png" % i
		if ResourceLoader.exists(p):
			sprite_frames.add_frame("close", load(p))
			
	anim_sprite.sprite_frames = sprite_frames
	anim_sprite.scale = Vector2(0.45, 0.45)
	anim_sprite.play("idle")
	if sprite != null:
		sprite.visible = false

func _process(delta: float) -> void:
	if not is_active:
		return
		
	# Gestion de la séquence d'ouverture (Roll type BO2)
	if is_rolling:
		roll_timer += delta
		weapon_cycle_timer += delta
		
		# Défilement rapide des armes au-dessus de la boîte mystère
		if weapon_cycle_timer >= 0.08:
			weapon_cycle_timer = 0.0
			current_preview_index = (current_preview_index + 1) % REWARDS.size()
			var reward = REWARDS[current_preview_index]
			roll_display_text = reward["name"]
			roll_label.text = roll_display_text
			_update_weapon_display_texture(reward["icon"])
			
		# Effet de lévitation et bobbing au-dessus de la boîte
		if weapon_display != null:
			weapon_display.visible = true
			weapon_display.position.y = -65.0 + sin(roll_timer * 12.0) * 8.0
			var pulse = 1.0 + sin(roll_timer * 15.0) * 0.08
			weapon_display.scale = Vector2(pulse, pulse)
			
		queue_redraw()
		
		if roll_timer >= roll_duration:
			_complete_roll()
		return
		
	# Détection d'interaction joueur
	if is_player_nearby and Input.is_action_just_pressed("interact"):
		_open_chest()

func _update_weapon_display_texture(icon_path: String) -> void:
	if weapon_sprite == null or not ResourceLoader.exists(icon_path):
		return
	var tex = load(icon_path) as Texture2D
	weapon_sprite.texture = tex
	if tex != null:
		var s = tex.get_size()
		var max_dim = max(s.x, s.y)
		var target_size = 54.0
		var sc = target_size / max(1.0, max_dim)
		weapon_sprite.scale = Vector2(sc, sc)

func _open_chest() -> void:
	if not is_active or is_rolling:
		return
		
	is_rolling = true
	roll_timer = 0.0
	weapon_cycle_timer = 0.0
	prompt_label.visible = false
	roll_label.visible = true
	
	if anim_sprite != null:
		anim_sprite.play("open")
		
	if weapon_display != null:
		weapon_display.visible = true
		_update_weapon_display_texture(REWARDS[0]["icon"])
	
	# Tirage de la récompense
	chosen_reward = REWARDS[randi() % REWARDS.size()]
	
	# Lancement du jingle musical mythique de la boîte mystère
	if audio_jingle.stream != null and is_inside_tree():
		is_chest_music_playing = true
		audio_jingle.play()
		chest_music_started.emit()
		if get_tree() != null:
			var game_map = get_tree().get_first_node_in_group("game_map")
			if game_map != null and game_map.has_method("on_chest_music_started"):
				game_map.on_chest_music_started()
	queue_redraw()

func _on_audio_jingle_finished() -> void:
	is_chest_music_playing = false
	chest_music_finished.emit()
	if get_tree() != null:
		var game_map = get_tree().get_first_node_in_group("game_map")
		if game_map != null and game_map.has_method("on_chest_music_finished"):
			game_map.on_chest_music_finished()

func _complete_roll() -> void:
	is_rolling = false
	roll_label.text = "★ CHOISISSEZ VOTRE RÉCOMPENSE ★"
	
	# Masque l'arme temporaire : on attend que le joueur choisisse effectivement son arme
	if weapon_display != null:
		weapon_display.visible = false
	queue_redraw()
	
	# Ouvre le panneau de choix d'amélioration en passant le callback de sélection
	var game_map = get_tree().get_first_node_in_group("game_map") if get_tree() != null else null
	if game_map != null and game_map.has_method("request_upgrade"):
		game_map.request_upgrade("★ COFFRE MYSTÈRE - CHOISISSEZ UN BONUS ★", _on_reward_chosen)
	else:
		_schedule_respawn()

func _on_reward_chosen(chosen_item: Dictionary) -> void:
	chosen_reward = chosen_item
	var item_title = chosen_item.get("title", chosen_item.get("name", "ARME"))
	roll_label.text = "★ %s DÉBLOQUÉ ! ★" % item_title
	
	# Trouve l'icône de l'arme choisie
	var icon_path = chosen_item.get("icon", "")
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		for r in REWARDS:
			if r["id"] == chosen_item.get("id", ""):
				icon_path = r["icon"]
				break
				
	_update_weapon_display_texture(icon_path)
	
	# Affiche l'arme choisie fièrement au-dessus de la boîte avec un éclat et un saut
	if weapon_display != null:
		weapon_display.visible = true
		weapon_display.modulate.a = 1.0
		weapon_display.position = Vector2(0, -60.0)
		weapon_display.scale = Vector2(0.5, 0.5)
		var tween = create_tween().set_parallel(true)
		tween.tween_property(weapon_display, "position:y", -75.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(weapon_display, "scale", Vector2(1.2, 1.2), 0.3)
	queue_redraw()
	
	# Disparition et fermeture après que le joueur a contemplé son arme
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(func():
		if anim_sprite != null:
			anim_sprite.play("close")
		if weapon_display != null:
			var fade = create_tween().set_parallel(true)
			fade.tween_property(weapon_display, "modulate:a", 0.0, 0.4)
			fade.tween_property(weapon_display, "position:y", -90.0, 0.4)
	)
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		is_active = false
		visible = false
		prompt_label.visible = false
		roll_label.visible = false
		if weapon_display != null:
			weapon_display.visible = false
			weapon_display.modulate.a = 1.0
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
	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(respawn_cooldown).timeout
	# Réapparaît à une position aléatoire sur la map
	var spawn_dist = randf_range(200.0, 900.0)
	var spawn_ang = randf() * TAU
	if is_instance_valid(target_player):
		global_position = target_player.global_position + Vector2.from_angle(spawn_ang) * spawn_dist
	is_active = true
	visible = true
	if anim_sprite != null:
		anim_sprite.play("idle")
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
		
	# Faisceau céleste mystique ascendant type Call of Duty Zombies
	if is_rolling or (weapon_display != null and weapon_display.visible):
		var beam_height = 95.0
		var beam_pts = PackedVector2Array([
			Vector2(-24, 0),
			Vector2(-40, -beam_height),
			Vector2(40, -beam_height),
			Vector2(24, 0)
		])
		# Faisceau cyan bleuté
		draw_colored_polygon(beam_pts, Color(0.2, 0.7, 1.0, 0.28))
		# Halo lumineux au centre du faisceau
		draw_circle(Vector2(0, -65.0), 30.0, Color(0.3, 0.85, 1.0, 0.25))
		draw_circle(Vector2(0, -65.0), 16.0, Color(1.0, 0.95, 0.6, 0.4))
