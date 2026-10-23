extends Area2D
class_name LaserProjectile

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const SPRITE_PATH: String = "res://assets/sprites/laser_projectile.png"
const AUDIO_IMPACT_PATH: String = "res://assets/audio/laser_hit.wav"

# ==============================================================================
# ÉQUILIBRAGE JAM (Projectile Laser BO2)
# ==============================================================================
@export_group("Equilibrage Laser")
@export var speed: float = 850.0             ## Vitesse du projectile laser (px/s)
@export var damage: float = 35.0             ## Dégâts infligés aux ennemis
@export var pierce_count: int = 1            ## Nombre d'ennemis traversés avant disparition
@export var lifetime: float = 2.0            ## Durée de vie maximale en secondes

# La couleur verte est explicitement exigée pour le feeling Ray Gun BO2
@export var laser_color: Color = Color(0.1, 1.0, 0.2, 1.0) ## Vert néon Ray Gun

var direction: Vector2 = Vector2.RIGHT
var current_pierce: int = 0
var travel_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Enregistrement et collisions (layer projectiles contre enemies)
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	if ResourceLoader.exists(SPRITE_PATH):
		sprite.texture = load(SPRITE_PATH)
	else:
		queue_redraw()

func _draw() -> void:
	# Dessin procédural du tir laser vert fluo type BO2 Ray Gun
	if sprite == null or sprite.texture == null:
		# Ligne de faisceau principale
		draw_line(Vector2(-14, 0), Vector2(14, 0), laser_color, 4.0)
		# Cœur blanc lumineux au centre
		draw_line(Vector2(-10, 0), Vector2(10, 0), Color.WHITE, 2.0)
		# Anneaux lumineux d'énergie
		draw_circle(Vector2(12, 0), 3.0, laser_color)

func _physics_process(delta: float) -> void:
	travel_time += delta
	if travel_time >= lifetime:
		queue_free()
		return
	
	global_position += direction * speed * delta
	rotation = direction.angle()

func setup(start_pos: Vector2, target_dir: Vector2, dmg_multiplier: float = 1.0, extra_pierce: int = 0) -> void:
	global_position = start_pos
	direction = target_dir.normalized()
	damage *= dmg_multiplier
	pierce_count += extra_pierce
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	_check_hit(body)

func _on_area_entered(area: Node2D) -> void:
	_check_hit(area)

func _check_hit(target: Node2D) -> void:
	if target.is_in_group("enemies") and target.has_method("take_damage"):
		target.take_damage(damage)
		current_pierce += 1
		
		# Effet sonore d'impact
		if ResourceLoader.exists(AUDIO_IMPACT_PATH):
			var sfx = AudioStreamPlayer2D.new()
			sfx.stream = load(AUDIO_IMPACT_PATH)
			get_parent().add_child(sfx)
			sfx.global_position = global_position
			sfx.play()
			sfx.finished.connect(sfx.queue_free)
			
		if current_pierce >= pierce_count:
			queue_free()
