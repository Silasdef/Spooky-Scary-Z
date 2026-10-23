extends EnemyBase
class_name ZombieDog

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const SPRITE_PATH: String = "res://assets/sprites/zombie_dog.png"
const AUDIO_GROWL_PATH: String = "res://assets/audio/dog_growl.wav"

# ==============================================================================
# ÉQUILIBRAGE JAM (Chien Zombie - Rapide et agressif)
# ==============================================================================
@export_group("Equilibrage Chien Zombie")
@export var dog_health: float = 18.0           ## Moins de vie mais compense par la vitesse
@export var dog_speed: float = 165.0          ## Vitesse d'assaut très rapide
@export var dog_contact_damage: float = 8.0   ## Dégâts des morsures rapides

var running_wiggle: float = 0.0

func _ready() -> void:
	max_health = dog_health
	move_speed = dog_speed
	contact_damage = dog_contact_damage
	
	super._ready()
	
	if ResourceLoader.exists(SPRITE_PATH):
		sprite.texture = load(SPRITE_PATH)
	else:
		queue_redraw()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Orientation du museau vers le joueur
	if velocity.length() > 1.0:
		rotation = velocity.angle()
		running_wiggle += delta * 20.0
		queue_redraw()

func _draw() -> void:
	if sprite.texture != null:
		return
		
	# Fallback procédural : Canidé squelettique / enragé
	# Corps allongé gris/brun décharné
	draw_rect(Rect2(-16, -7, 30, 14), Color(0.28, 0.2, 0.18))
	# Tête / mâchoire avancée
	draw_circle(Vector2(16, 0), 7.0, Color(0.35, 0.22, 0.2))
	# Museau pointu
	var muzzle_pts = PackedVector2Array([
		Vector2(16, -4),
		Vector2(25, 0),
		Vector2(16, 4)
	])
	draw_colored_polygon(muzzle_pts, Color(0.22, 0.14, 0.12))
	# Yeux rouges phosphorescents
	draw_circle(Vector2(18, -3), 1.8, Color(1.0, 0.1, 0.1))
	# Côtes apparentes blanches
	draw_line(Vector2(-6, -6), Vector2(-6, 6), Color(0.7, 0.7, 0.65), 2.0)
	draw_line(Vector2(2, -6), Vector2(2, 6), Color(0.7, 0.7, 0.65), 2.0)
	# Pattes qui courent
	var leg_offset = sin(running_wiggle) * 4.0
	draw_line(Vector2(-10, 7), Vector2(-12 + leg_offset, 14), Color(0.25, 0.18, 0.16), 3.0)
	draw_line(Vector2(8, 7), Vector2(6 - leg_offset, 14), Color(0.25, 0.18, 0.16), 3.0)
	draw_line(Vector2(-10, -7), Vector2(-12 - leg_offset, -14), Color(0.25, 0.18, 0.16), 3.0)
	draw_line(Vector2(8, -7), Vector2(6 + leg_offset, -14), Color(0.25, 0.18, 0.16), 3.0)
