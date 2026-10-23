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
@export var zombie_health: float = 30.0        ## PV du zombie standard
@export var zombie_speed: float = 65.0         ## Vitesse lente et implacable
@export var zombie_contact_damage: float = 12.0 ## Dégâts d'une morsure

# Variant Citrouille (1 chance sur 8)
var is_pumpkin_head: bool = false

func _ready() -> void:
	max_health = zombie_health
	move_speed = zombie_speed
	contact_damage = zombie_contact_damage
	
	super._ready()
	
	# Tirage aléatoire : 1 chance sur 8 d'avoir la tête de citrouille
	is_pumpkin_head = (randi() % 8 == 0)
	
	if is_pumpkin_head:
		# Légère variation de stats pour la citrouille
		max_health *= 1.2
		current_health = max_health
		if ResourceLoader.exists(SPRITE_PUMPKIN_PATH):
			sprite.texture = load(SPRITE_PUMPKIN_PATH)
		else:
			queue_redraw()
	else:
		if ResourceLoader.exists(SPRITE_BASIC_PATH):
			sprite.texture = load(SPRITE_BASIC_PATH)
		else:
			queue_redraw()

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
