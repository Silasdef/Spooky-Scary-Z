extends Area2D
class_name LightningStrike

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const AUDIO_THUNDER_PATH: String = "res://assets/audio/lightning_strike.wav"

# ==============================================================================
# ÉQUILIBRAGE JAM (Éclair de Frankenstein)
# ==============================================================================
@export_group("Equilibrage Eclair")
@export var damage: float = 35.0                 ## Dégâts foudroyants infligés au joueur
@export var warning_time: float = 0.85           ## Temps d'avertissement au sol avant l'impact
@export var strike_duration: float = 0.35        ## Durée visuelle du flash de foudre
@export var strike_radius: float = 60.0          ## Rayon d'impact de l'éclair

var time_elapsed: float = 0.0
var has_struck: bool = false
var bolt_points: PackedVector2Array = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	if ResourceLoader.exists(AUDIO_THUNDER_PATH):
		audio_player.stream = load(AUDIO_THUNDER_PATH)
	
	_generate_bolt_geometry()
	monitoring = false

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
		queue_redraw()
	elif not has_struck:
		# IMPACT DE L'ÉCLAIR
		has_struck = true
		monitoring = true
		_apply_strike_damage()
		if audio_player.stream != null:
			audio_player.play()
		queue_redraw()
	elif time_elapsed >= warning_time + strike_duration:
		queue_free()
	else:
		queue_redraw()

func _apply_strike_damage() -> void:
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)

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
		# FLASH DE L'ÉCLAIR : Arcs de foudre zigzaguant
		var cyan_glow = Color(0.3, 0.8, 1.0, 0.9)
		var core_white = Color(1.0, 1.0, 1.0, 1.0)
		
		# Trace l'éclair principal
		for i in range(bolt_points.size() - 1):
			draw_line(bolt_points[i], bolt_points[i+1], cyan_glow, 8.0)
			draw_line(bolt_points[i], bolt_points[i+1], core_white, 3.5)
			
		# Onde de choc au point d'impact
		draw_circle(Vector2.ZERO, strike_radius * 1.1, Color(0.7, 0.95, 1.0, 0.6))
