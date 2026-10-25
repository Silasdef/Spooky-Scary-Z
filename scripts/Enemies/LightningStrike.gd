extends Area2D
class_name LightningStrike

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const AUDIO_THUNDER_PATH: String = "res://assets/audio/lightning_strike.wav"
const LIGHTNING_SPRITE_PATH: String = "res://assets/sprites/lightning_strike.png"

# ==============================================================================
# ÉQUILIBRAGE JAM (Éclair de Frankenstein)
# ==============================================================================
@export_group("Equilibrage Eclair")
@export var damage: float = 25.0                 ## Dégâts foudroyants infligés au joueur (25 PV si le joueur reste dans la zone)
@export var warning_time: float = 0.85           ## Temps d'avertissement au sol avant l'impact
@export var strike_duration: float = 0.35        ## Durée visuelle du flash de foudre
@export var strike_radius: float = 60.0          ## Rayon d'impact de l'éclair

var time_elapsed: float = 0.0
var has_struck: bool = false
var damage_applied: bool = false
var target_player: CharacterBody2D = null
var bolt_points: PackedVector2Array = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var lightning_sprite: Sprite2D = $LightningSprite

func _ready() -> void:
	if lightning_sprite == null:
		lightning_sprite = get_node_or_null("LightningSprite")
	if lightning_sprite == null:
		lightning_sprite = Sprite2D.new()
		lightning_sprite.name = "LightningSprite"
		lightning_sprite.position = Vector2(0, -300)
		add_child(lightning_sprite)
		
	if ResourceLoader.exists(AUDIO_THUNDER_PATH) and audio_player != null:
		audio_player.stream = load(AUDIO_THUNDER_PATH)
		
	if ResourceLoader.exists(LIGHTNING_SPRITE_PATH):
		lightning_sprite.texture = load(LIGHTNING_SPRITE_PATH)
		
	lightning_sprite.visible = false
	
	_generate_bolt_geometry()
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if has_struck and not damage_applied:
		if body.is_in_group("player") and body.has_method("take_damage"):
			damage_applied = true
			body.take_damage(damage)

func _generate_bolt_geometry() -> void:
	bolt_points.clear()
	# Génère un éclair en zigzag tombant du haut de l'écran vers le sol
	var cur = Vector2(0, -600)
	bolt_points.append(cur)
	while cur.y < 0:
		cur.y += randf_range(30, 60)
		cur.x += randf_range(-25, 25)
		bolt_points.append(cur)
	bolt_points.append(Vector2.ZERO)

func _process(delta: float) -> void:
	time_elapsed += delta
	
	if time_elapsed < warning_time:
		# Phase d'avertissement au sol (cercle télégraphié pulsant)
		lightning_sprite.visible = false
		queue_redraw()
	elif not has_struck:
		# IMPACT DE L'ÉCLAIR
		has_struck = true
		_apply_strike_damage()
		if audio_player.stream != null:
			audio_player.play()
		lightning_sprite.visible = true
		lightning_sprite.modulate = Color(1.4, 1.4, 1.6, 1.0)
		queue_redraw()
	elif time_elapsed >= warning_time + strike_duration:
		queue_free()
	else:
		# Vérifie continuellement si le joueur est dans la zone d'impact pendant le flash
		if not damage_applied:
			_apply_strike_damage()
			
		# Animation d'extinction de l'éclair
		var progress = (time_elapsed - warning_time) / strike_duration
		lightning_sprite.visible = true
		lightning_sprite.modulate = Color(1.2, 1.2, 1.4, clamp(1.0 - progress, 0.0, 1.0))
		lightning_sprite.scale.x = 1.0 + sin(progress * PI * 6.0) * 0.15
		queue_redraw()

func _apply_strike_damage() -> void:
	if damage_applied:
		return
		
	# 1. Vérification directe avec target_player si renseigné
	if is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= strike_radius:
			damage_applied = true
			target_player.take_damage(damage)
			return
			
	# 2. Vérification directe par distance avec tous les joueurs
	if get_tree() != null:
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and p is CharacterBody2D:
				var dist = global_position.distance_to(p.global_position)
				if dist <= strike_radius:
					damage_applied = true
					p.take_damage(damage)
					return
					
	# 3. Vérification par corps en chevauchement
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player") and body.has_method("take_damage"):
			damage_applied = true
			body.take_damage(damage)
			return

func _draw() -> void:
	if time_elapsed < warning_time:
		# Zone d'avertissement : cercle bleu/cyan électrique vibrant
		var progress = time_elapsed / warning_time
		var pulse = sin(time_elapsed * 25.0) * 3.0
		var r = strike_radius + pulse
		draw_circle(Vector2.ZERO, r, Color(0.1, 0.6, 1.0, 0.2 + progress * 0.25))
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(0.4, 0.9, 1.0, 0.8), 2.5)
		# Petits arcs électriques intérieurs
		draw_line(Vector2(-15, -5), Vector2(10, 12), Color(0.8, 1.0, 1.0, 0.7), 2.0)
	else:
		# Onde de choc au point d'impact
		var impact_progress = clamp((time_elapsed - warning_time) / strike_duration, 0.0, 1.0)
		var impact_alpha = 1.0 - impact_progress
		draw_circle(Vector2.ZERO, strike_radius * (1.0 + impact_progress * 0.4), Color(0.4, 0.85, 1.0, 0.5 * impact_alpha))
		draw_circle(Vector2.ZERO, strike_radius * 0.5, Color(1.0, 1.0, 1.0, 0.7 * impact_alpha))
