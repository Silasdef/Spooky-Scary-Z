extends Node2D
class_name CommunistBoomerang

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const SPRITE_PATH: String = "res://assets/sprites/sickle_hammer.png"
const AUDIO_WHOOSH_PATH: String = "res://assets/audio/boomerang_whoosh.wav"

# ==============================================================================
# ÉQUILIBRAGE JAM (Boomerang Communiste : Faucille & Marteau orbitaux)
# ==============================================================================
@export_group("Equilibrage Boomerang")
@export var base_damage: float = 40.0             ## Dégâts infligés par tour / contact
@export var orbit_radius: float = 120.0           ## Rayon de rotation autour du joueur
@export var orbit_speed: float = 4.5              ## Vitesse angulaire de révolution (rad/s)
@export var spin_speed: float = 18.0              ## Vitesse de rotation sur soi-même (rad/s)
@export var cycle_interval: float = 2.5           ## Période entre chaque déploiement
@export var weapon_level: int = 1                 ## Niveau de l'arme

# Synergie passive
var has_tayon_synergy: bool = false               ## Synergie Tayon : Rayon colossal et double projectile

var current_angle: float = 0.0
var self_spin_angle: float = 0.0
var current_orbit_radius: float = 0.0
var state: int = 0 # 0: En attente, 1: Expansion, 2: Révolution, 3: Retour
var state_timer: float = 0.0
var hit_cooldowns: Dictionary = {}

@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	hit_area.body_entered.connect(_on_enemy_hit)
	hit_area.area_entered.connect(_on_enemy_hit)
	
	if ResourceLoader.exists(AUDIO_WHOOSH_PATH):
		audio_player.stream = load(AUDIO_WHOOSH_PATH)
		
	# Démarre le premier cycle
	_start_throw()

func _start_throw() -> void:
	state = 1
	state_timer = 0.0
	current_orbit_radius = 20.0
	hit_cooldowns.clear()
	hit_area.monitoring = true
	
	if audio_player.stream != null:
		audio_player.play()

func _process(delta: float) -> void:
	# Mise à jour des temps d'immunité par ennemi pour éviter le one-shot instantané
	for enemy in hit_cooldowns.keys():
		hit_cooldowns[enemy] -= delta
		if hit_cooldowns[enemy] <= 0:
			hit_cooldowns.erase(enemy)
	
	# Gestion des états d'orbite
	var target_radius = orbit_radius
	if has_tayon_synergy:
		target_radius *= 1.7 # Rayon immense grâce à l'extension Tayon
	
	self_spin_angle += spin_speed * delta
	current_angle += orbit_speed * delta
	
	match state:
		0: # Attente avant prochain jet
			state_timer += delta
			hit_area.monitoring = false
			visible = false
			if state_timer >= cycle_interval:
				_start_throw()
				visible = true
		1: # Expansion vers le rayon d'orbite
			current_orbit_radius = move_toward(current_orbit_radius, target_radius, 350.0 * delta)
			if current_orbit_radius >= target_radius:
				state = 2
				state_timer = 0.0
		2: # Révolution soutenue autour du joueur
			state_timer += delta
			var active_duration = 3.5 + (weapon_level - 1) * 0.5
			if state_timer >= active_duration:
				state = 3
		3: # Rétraction / Retour vers le joueur
			current_orbit_radius = move_toward(current_orbit_radius, 0.0, 400.0 * delta)
			if current_orbit_radius <= 15.0:
				state = 0
				state_timer = 0.0
				hit_area.monitoring = false
				visible = false

	# Positionnement orbital relatif au joueur (noeud parent)
	var offset = Vector2(cos(current_angle), sin(current_angle)) * current_orbit_radius
	hit_area.position = offset
	queue_redraw()

func _draw() -> void:
	if state == 0 or not visible:
		return
	
	var center = hit_area.position
	
	# Dessin procédural : Faucille & Marteau stylisés (rouge et or révolutionnaire)
	# Faucille courbée
	var gold = Color(1.0, 0.85, 0.1)
	var red = Color(0.9, 0.15, 0.15)
	
	# Anneau / traînée orbitale rougeoyante
	draw_arc(Vector2.ZERO, current_orbit_radius, current_angle - 0.7, current_angle, 12, Color(0.9, 0.1, 0.1, 0.45), 2.5)
	
	# Faucille dorée
	draw_arc(center, 12.0, self_spin_angle, self_spin_angle + 2.8, 10, gold, 3.5)
	# Manche de faucille
	var handle_end = center + Vector2.from_angle(self_spin_angle + 3.1) * 16.0
	draw_line(center, handle_end, Color(0.5, 0.25, 0.1), 3.0)
	
	# Marteau croisé
	var hammer_dir = Vector2.from_angle(self_spin_angle + 1.2)
	var hammer_head = center + hammer_dir * 14.0
	draw_line(center - hammer_dir * 8.0, hammer_head, Color(0.5, 0.25, 0.1), 3.0)
	# Tête du marteau
	var perp = hammer_dir.orthogonal() * 6.0
	draw_line(hammer_head - perp, hammer_head + perp, gold, 4.5)
	
	# Étoile centrale ou orbe rouge
	draw_circle(center, 4.0, red)
	
	# Si synergie Tayon active : on dessine un deuxième projectile en opposition (180°)
	if has_tayon_synergy:
		var opp_center = -hit_area.position
		draw_circle(opp_center, 6.0, gold)
		draw_arc(opp_center, 12.0, -self_spin_angle, -self_spin_angle + 2.8, 10, red, 3.0)

func _on_enemy_hit(target: Node2D) -> void:
	if target in hit_cooldowns:
		return
		
	if target.is_in_group("enemies") and target.has_method("take_damage"):
		var effective_dmg = base_damage * (1.0 + (weapon_level - 1) * 0.2)
		if has_tayon_synergy:
			effective_dmg *= 1.35
			
		target.take_damage(effective_dmg)
		hit_cooldowns[target] = 0.35 # Ne retouche pas le même ennemi avant 0.35s

func upgrade() -> void:
	weapon_level += 1

func set_tayon_synergy(enabled: bool) -> void:
	has_tayon_synergy = enabled
