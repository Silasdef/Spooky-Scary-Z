extends Area2D
class_name LootGem

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS (Remplaçables pendant la Jam)
# ==============================================================================
const SPRITE_PATH: String = "res://assets/sprites/gem_xp.png"
const AUDIO_PICKUP_PATH: String = "res://assets/audio/xp_pickup.wav"

# ==============================================================================
# ÉQUILIBRAGE JAM (Ajustez ces valeurs pour le rythme du jeu)
# ==============================================================================
@export_group("Equilibrage XP")
@export var xp_value: int = 10                  ## Quantité d'XP donnée au joueur
@export var magnet_acceleration: float = 650.0  ## Vitesse d'aspiration maximale vers le joueur (px/s)
@export var magnet_lerp_weight: float = 7.0     ## Vitesse d'interpolation (lerp) vers le joueur
@export var pickup_distance_threshold: float = 16.0 ## Distance minimale pour consommer la gemme

# État interne
var target_player: CharacterBody2D = null
var is_attracted: bool = false
var current_speed: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Enregistrement dans le groupe pour détection facile
	add_to_group("loot_gems")
	
	# Tentative de chargement du sprite officiel si présent
	if ResourceLoader.exists(SPRITE_PATH):
		sprite.texture = load(SPRITE_PATH)
	else:
		# Fallback visuel : Gemme polygonale brillante procédurale
		queue_redraw()

func _draw() -> void:
	# Si aucun sprite externe n'est chargé, on dessine une gemme néon stylée
	if sprite.texture == null:
		var diamond_points = PackedVector2Array([
			Vector2(0, -9),
			Vector2(7, -2),
			Vector2(0, 9),
			Vector2(-7, -2)
		])
		var gem_color = Color(0.2, 1.0, 0.5, 0.95) # Vert émeraude vibrant
		var inner_color = Color(0.8, 1.0, 0.9, 0.95)
		draw_colored_polygon(diamond_points, gem_color)
		
		var inner_points = PackedVector2Array([
			Vector2(0, -5),
			Vector2(4, -1),
			Vector2(0, 5),
			Vector2(-4, -1)
		])
		draw_colored_polygon(inner_points, inner_color)

func _physics_process(delta: float) -> void:
	if not is_attracted or not is_instance_valid(target_player):
		return
	
	# Mécanique de lerp / accélération vers le joueur
	var direction = (target_player.global_position - global_position).normalized()
	current_speed = move_toward(current_speed, magnet_acceleration, magnet_acceleration * 2.0 * delta)
	
	# Mouvement combiné lerp + accélération directionnelle
	global_position = global_position.lerp(target_player.global_position, magnet_lerp_weight * delta)
	global_position += direction * current_speed * delta
	
	# Vérification de contact direct avec le joueur
	if global_position.distance_to(target_player.global_position) <= pickup_distance_threshold:
		_collect()

func attract_to(player: CharacterBody2D) -> void:
	if not is_attracted:
		is_attracted = true
		target_player = player

func _collect() -> void:
	if is_instance_valid(target_player) and target_player.has_method("add_xp"):
		target_player.add_xp(xp_value)
	
	# Lecture sonore si l'asset existe
	if ResourceLoader.exists(AUDIO_PICKUP_PATH):
		var sfx = AudioStreamPlayer2D.new()
		sfx.stream = load(AUDIO_PICKUP_PATH)
		get_parent().add_child(sfx)
		sfx.global_position = global_position
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
		
	queue_free()
