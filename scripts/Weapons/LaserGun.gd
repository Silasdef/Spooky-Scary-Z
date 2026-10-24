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
@export var base_damage: float = 20.0          ## Dégâts de base (20 PV : 2 balles pour un zombie standard à 40 PV, 1 balle pour un chien à 20 PV)
@export var fire_interval: float = 1.05        ## Délai entre chaque tir (cadence de tir)
@export var projectile_speed: float = 400.0    ## Vitesse du projectile laser (px/s)
@export var detection_range: float = 450.0     ## Portée de détection de l'ennemi le plus proche
@export var weapon_level: int = 1              ## Niveau d'amélioration de l'arme

# Synergie passive
var has_dash_synergy: bool = false             ## Débloqué si le joueur possède l'item Dash

var fire_timer: float = 0.0
var projectile_scene: PackedScene = null
var player_owner: CharacterBody2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	if ResourceLoader.exists(PROJECTILE_SCENE_PATH):
		projectile_scene = load(PROJECTILE_SCENE_PATH)
	
	# Référence vers le joueur propriétaire
	if get_parent() != null and get_parent().get_parent() is CharacterBody2D:
		player_owner = get_parent().get_parent() as CharacterBody2D
	
	if ResourceLoader.exists(SPRITE_PATH):
		sprite.texture = load(SPRITE_PATH)
		sprite.scale = Vector2(0.12, 0.12)
		_update_gun_orientation(Vector2.RIGHT)
	else:
		queue_redraw()
		
	if ResourceLoader.exists(AUDIO_FIRE_PATH):
		audio_player.stream = load(AUDIO_FIRE_PATH)

func _draw() -> void:
	# Fallback visuel : pistolet futuriste compact vert et gris sombre
	if sprite.texture == null:
		# Canon du laser en avant du joueur
		draw_rect(Rect2(18, -3, 14, 6), Color(0.18, 0.22, 0.25))
		# Bague de focalisation verte
		draw_rect(Rect2(26, -4, 4, 8), Color(0.1, 1.0, 0.2))
		# Poignée
		draw_line(Vector2(20, 2), Vector2(18, 8), Color(0.12, 0.12, 0.14), 3.0)

func _process(delta: float) -> void:
	fire_timer += delta
	
	# Orientation dynamique vers l'ennemi le plus proche ou la direction regardée par le joueur
	var target = _find_closest_enemy()
	var aim_dir = Vector2.RIGHT
	if target != null:
		aim_dir = (target.global_position - global_position).normalized()
	elif player_owner != null and "facing_direction" in player_owner:
		aim_dir = player_owner.facing_direction
		
	_update_gun_orientation(aim_dir)
	
	# Calcul du cooldown effectif selon le niveau et les synergies
	var current_cooldown = fire_interval / (1.0 + (weapon_level - 1) * 0.2)
	if has_dash_synergy:
		# Synergie Dash : Cadence boostée (+35%)
		current_cooldown *= 0.65
	
	if fire_timer >= current_cooldown:
		if target != null:
			_fire_laser_at(target, aim_dir)
			fire_timer = 0.0

func _update_gun_orientation(aim_dir: Vector2) -> void:
	if sprite == null:
		return
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT
	rotation = aim_dir.angle()
	
	var is_aiming_left = (aim_dir.x < 0)
	sprite.flip_v = is_aiming_left
	if is_aiming_left:
		# Positionné en avant du joueur (20px vers l'avant, main gauche)
		sprite.position = Vector2(20.0, -4.0)
		sprite.offset = Vector2(150.0, 48.0)
	else:
		# Positionné en avant du joueur (20px vers l'avant, main droite)
		sprite.position = Vector2(20.0, 4.0)
		sprite.offset = Vector2(150.0, -48.0)

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

func _fire_laser_at(target: Node2D, aim_dir: Vector2) -> void:
	if projectile_scene == null:
		return
	
	var dir = aim_dir
	var proj = projectile_scene.instantiate() as LaserProjectile
	var scene_target = get_tree().current_scene if (get_tree() != null and get_tree().current_scene != null) else (get_tree().root if get_tree() != null else null)
	if scene_target != null:
		scene_target.add_child(proj)
	
	var dmg_mult = 1.0 + (weapon_level - 1) * 0.25
	var extra_pierce = 0
	
	if has_dash_synergy:
		dmg_mult *= 1.35
		extra_pierce = 2
		
	# Spawn du projectile directement à la sortie du canon (56px en avant)
	var muzzle_pos = global_position + dir * 56.0
	proj.setup(muzzle_pos, dir, dmg_mult, extra_pierce, projectile_speed, base_damage)
	
	if audio_player.stream != null:
		audio_player.play()

func upgrade() -> void:
	weapon_level += 1

func set_dash_synergy(enabled: bool) -> void:
	has_dash_synergy = enabled
