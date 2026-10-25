extends Area2D
class_name SporeBomb

# ==============================================================================
# PROJECTILE DU COLOSSE : BOULE DE SPORES
# Projetée vers la position du joueur, explose à l'impact et libère un nuage toxique
# ==============================================================================

const SPORE_CLOUD_SCENE_PATH: String = "res://scenes/Enemies/SporeCloud.tscn"

@export var flight_duration: float = 0.85   ## Temps de vol vers la cible
@export var direct_impact_damage: float = 15.0 ## Dégâts directs en cas d'impact avec le joueur

var start_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var elapsed_time: float = 0.0
var has_exploded: bool = false
var cloud_scene: PackedScene = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Détecte le joueur
	
	body_entered.connect(_on_body_entered)
	
	if ResourceLoader.exists(SPORE_CLOUD_SCENE_PATH):
		cloud_scene = load(SPORE_CLOUD_SCENE_PATH)
		
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
		
	# Échelle initiale
	scale = Vector2(0.85, 0.85)

func setup(origin: Vector2, target: Vector2) -> void:
	start_position = origin
	target_position = target
	global_position = origin
	elapsed_time = 0.0

func _physics_process(delta: float) -> void:
	if has_exploded:
		return
		
	elapsed_time += delta
	var prog = clamp(elapsed_time / flight_duration, 0.0, 1.0)
	
	# Trajectoire balistique avec arc parabolique en cloche
	var linear_pos = start_position.lerp(target_position, prog)
	var arc_height = sin(prog * PI) * -50.0 # Élévation en hauteur
	global_position = linear_pos + Vector2(0.0, arc_height)
	
	# Rotation rapide de la spore en vol
	if sprite != null:
		sprite.rotation += 10.0 * delta
		# Échelle dynamique pour effet de perspective (grandit au sommet de l'arc)
		var s = 0.85 + sin(prog * PI) * 0.35
		sprite.scale = Vector2(s, s)
		
	# Explosion à destination
	if prog >= 1.0:
		_explode()

func _on_body_entered(body: Node2D) -> void:
	if has_exploded:
		return
	if body.is_in_group("player") or body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(direct_impact_damage)
		_explode()

func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	
	# Instanciation du nuage de spore toxique persistant
	if cloud_scene != null:
		var cloud = cloud_scene.instantiate() as Node2D
		cloud.global_position = global_position
		get_parent().add_child(cloud)
		
	queue_free()
