extends EnemyBase
class_name ZombieBasic

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const SPRITE_BASIC_PATH: String = "res://assets/sprites/zombie_basic.png"
const SPRITE_PUMPKIN_PATH: String = "res://assets/sprites/zombie_pumpkin.png"

# ==============================================================================
# ÉQUILIBRAGE JAM (Zombie Basique)
# ==============================================================================
@export_group("Equilibrage Zombie")
@export var zombie_health: float = 40.0        ## PV du zombie standard (tué en 2 balles de 20 dégâts)
@export var zombie_speed: float = 65.0         ## Vitesse lente et implacable
@export var zombie_contact_damage: float = 12.0 ## Dégâts d'une morsure

# Variant Citrouille (1 chance sur 8)
var is_pumpkin_head: bool = false

func _init() -> void:
	max_health = zombie_health
	current_health = zombie_health
	move_speed = zombie_speed
	contact_damage = zombie_contact_damage

func _ready() -> void:
	max_health = zombie_health
	move_speed = zombie_speed
	contact_damage = zombie_contact_damage
	
	super._ready()
	
	# Tirage aléatoire : 1 chance sur 8 d'avoir la tête de citrouille
	is_pumpkin_head = (randi() % 8 == 0)
	
	if is_pumpkin_head:
		# Variante citrouille visuelle (tous les zombies de base meurent en 2 balles)
		max_health = zombie_health
		current_health = max_health
		if ResourceLoader.exists(SPRITE_PUMPKIN_PATH):
			sprite.texture = load(SPRITE_PUMPKIN_PATH)
			sprite.scale = Vector2(0.22, 0.22)
		else:
			queue_redraw()
	else:
		if ResourceLoader.exists(SPRITE_BASIC_PATH):
			sprite.texture = load(SPRITE_BASIC_PATH)
			sprite.scale = Vector2(0.22, 0.22)
		else:
			queue_redraw()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_sprite_direction()

func _update_sprite_direction() -> void:
	if velocity.length_squared() < 1.0:
		return
	var dir_suffix = "bas"
	if abs(velocity.x) > abs(velocity.y):
		dir_suffix = "droite" if velocity.x > 0 else "gauche"
	else:
		dir_suffix = "bas" if velocity.y > 0 else "haut"
		
	var prefix = "zombie_pumpkin" if is_pumpkin_head else "zombie_basic"
	var path = "res://assets/sprites/%s_%s.png" % [prefix, dir_suffix]
	if ResourceLoader.exists(path):
		var tex = load(path)
		if sprite.texture != tex:
			sprite.texture = tex

func _draw() -> void:
	if sprite.texture != null:
		return
		
	# Fallback procédural : Silhouette zombie stylisée
	if is_pumpkin_head:
		# Corps en haillons sombres
		draw_rect(Rect2(-12, -8, 24, 26), Color(0.18, 0.22, 0.16))
		# Bras tendus vers l'avant
		draw_line(Vector2(-10, 0), Vector2(-18, 4), Color(0.3, 0.45, 0.3), 5.0)
		draw_line(Vector2(10, 0), Vector2(18, 4), Color(0.3, 0.45, 0.3), 5.0)
		# Tête de CITROUILLE (Orange vif)
		draw_circle(Vector2(0, -18), 14.0, Color(0.95, 0.45, 0.05))
		# Tige verte
		draw_line(Vector2(0, -32), Vector2(2, -37), Color(0.2, 0.6, 0.1), 3.0)
		# Yeux sculptés triangulaires jaunes luisants
		draw_circle(Vector2(-5, -20), 2.5, Color(1.0, 0.95, 0.2))
		draw_circle(Vector2(5, -20), 2.5, Color(1.0, 0.95, 0.2))
		# Bouche dentelée
		draw_line(Vector2(-6, -14), Vector2(6, -14), Color(0.1, 0.05, 0.0), 2.0)
	else:
		# Corps zombie vert putride
		draw_rect(Rect2(-10, -6, 20, 24), Color(0.2, 0.25, 0.3))
		# Bras décharnés
		draw_line(Vector2(-8, 2), Vector2(-16, 6), Color(0.35, 0.55, 0.35), 4.0)
		draw_line(Vector2(8, 2), Vector2(16, 6), Color(0.35, 0.55, 0.35), 4.0)
		# Tête verte décomposée
		draw_circle(Vector2(0, -16), 11.0, Color(0.38, 0.58, 0.38))
		# Yeux blancs vides terrifiants
		draw_circle(Vector2(-4, -17), 2.0, Color(0.95, 0.95, 0.9))
		draw_circle(Vector2(4, -17), 2.0, Color(0.95, 0.95, 0.9))
