extends Area2D
class_name SporeCloud

# ==============================================================================
# NUAGE DE SPORES DU COLOSSE
# Nuage gazeux toxique persistant qui inflige un effet de dégâts sur la durée (DoT)
# ==============================================================================

@export var cloud_duration: float = 4.2      ## Durée de vie totale du nuage (secondes)
@export var dot_tick_interval: float = 0.4   ## Intervalle d'application des dégâts
@export var dot_damage: float = 5.0          ## Dégâts infligés par tic (~12.5 PV/sec)
@export var cloud_radius: float = 75.0       ## Rayon de la zone toxique

var lifetime: float = 0.0
var tick_timer: float = 0.0
var overlapping_player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Cible le joueur (Layer 2)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
		
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = cloud_radius
		
	# Animation d'expansion vaporeuse et de dispersion gazeuse
	modulate.a = 0.0
	scale = Vector2(0.25, 0.25)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.95, 0.35)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	lifetime += delta
	tick_timer += delta
	
	# Ondulation et pulsation volumétrique naturelle du gaz toxique (sans rotation de sprite)
	var pulse_x = 1.0 + sin(lifetime * 2.8) * 0.05 + cos(lifetime * 4.2) * 0.02
	var pulse_y = 1.0 + cos(lifetime * 2.5) * 0.05 + sin(lifetime * 3.7) * 0.02
	if sprite != null:
		sprite.scale = Vector2(pulse_x, pulse_y)
		sprite.rotation = sin(lifetime * 1.1) * 0.04 # Léger balancement vaporeux de ~2 degrés
	
	# Dégâts sur la durée (DoT) si le joueur reste dans la zone toxique
	if is_instance_valid(overlapping_player) and overlapping_player.has_method("take_damage"):
		if tick_timer >= dot_tick_interval:
			tick_timer = 0.0
			overlapping_player.take_damage(dot_damage)
			# Flash verdâtre/toxique sur le joueur
			if overlapping_player is CanvasItem:
				var flash_tween = overlapping_player.create_tween()
				overlapping_player.modulate = Color(0.4, 1.6, 0.4, 1.0)
				flash_tween.tween_property(overlapping_player, "modulate", Color.WHITE, 0.15)
				
	# Dissipation progressive en fin de vie
	if lifetime >= cloud_duration - 0.8:
		var fade_prog = (cloud_duration - lifetime) / 0.8
		modulate.a = clamp(fade_prog * 0.95, 0.0, 0.95)
		
	if lifetime >= cloud_duration:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		overlapping_player = body

func _on_body_exited(body: Node2D) -> void:
	if body == overlapping_player:
		overlapping_player = null
