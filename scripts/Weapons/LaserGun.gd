extends Node2D
class_name LaserGun

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const SPRITE_PATH: String = "res://assets/sprites/laser_gun.png"
const AUDIO_FIRE_PATH: String = "res://assets/audio/laser_shot.wav"
const PROJECTILE_SCENE_PATH: String = "res://scenes/Weapons/LaserProjectile.tscn"

# ==============================================================================
# ÉQUILIBRAGE JAM (Pistolet Laser Type BO2)
# ==============================================================================
@export_group("Equilibrage Pistolet Laser")
@export var base_damage: float = 35.0          ## Dégâts de base par tir laser
@export var fire_interval: float = 0.55        ## Intervalle de tir en secondes (cadence)
@export var detection_range: float = 480.0     ## Portée de détection de l'ennemi le plus proche
@export var weapon_level: int = 1              ## Niveau d'amélioration de l'arme

# Synergie passive
var has_dash_synergy: bool = false             ## Débloqué si le joueur possède l'item Dash

var fire_timer: float = 0.0
var projectile_scene: PackedScene = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	if ResourceLoader.exists(PROJECTILE_SCENE_PATH):
		projectile_scene = load(PROJECTILE_SCENE_PATH)
	
	if ResourceLoader.exists(SPRITE_PATH):
		sprite.texture = load(SPRITE_PATH)
	else:
		queue_redraw()
		
	if ResourceLoader.exists(AUDIO_FIRE_PATH):
		audio_player.stream = load(AUDIO_FIRE_PATH)

func _draw() -> void:
	# Fallback visuel : pistolet futuriste compact vert et gris sombre
	if sprite.texture == null:
		# Canon du laser
		draw_rect(Rect2(0, -3, 14, 6), Color(0.18, 0.22, 0.25))
		# Bague de focalisation verte
		draw_rect(Rect2(8, -4, 4, 8), Color(0.1, 1.0, 0.2))
		# Poignée
		draw_line(Vector2(2, 2), Vector2(0, 8), Color(0.12, 0.12, 0.14), 3.0)

func _process(delta: float) -> void:
	fire_timer += delta
	
	# Calcul du cooldown effectif selon le niveau et les synergies
	var current_cooldown = fire_interval / (1.0 + (weapon_level - 1) * 0.2)
	if has_dash_synergy:
		# Synergie Dash : Cadence boostée (+35%)
		current_cooldown *= 0.65
	
	if fire_timer >= current_cooldown:
		var target = _find_closest_enemy()
		if target != null:
			_fire_laser_at(target)
			fire_timer = 0.0

func _find_closest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node2D = null
	var min_distance_sq: float = detection_range * detection_range
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist_sq = global_position.distance_squared_to(enemy.global_position)
		if dist_sq <= min_distance_sq:
			min_distance_sq = dist_sq
			closest_enemy = enemy
			
	return closest_enemy

func _fire_laser_at(target: Node2D) -> void:
	if projectile_scene == null:
		return
	
	var dir = (target.global_position - global_position).normalized()
	rotation = dir.angle()
	
	var proj = projectile_scene.instantiate() as LaserProjectile
	get_tree().current_scene.add_child(proj)
	
	var dmg_mult = 1.0 + (weapon_level - 1) * 0.25
	var extra_pierce = 0
	
	if has_dash_synergy:
		dmg_mult *= 1.35
		extra_pierce = 2
		
	proj.setup(global_position + dir * 16.0, dir, dmg_mult, extra_pierce)
	
	if audio_player.stream != null:
		audio_player.play()

func upgrade() -> void:
	weapon_level += 1

func set_dash_synergy(enabled: bool) -> void:
	has_dash_synergy = enabled
