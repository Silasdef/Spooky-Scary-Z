extends Node2D
class_name CommunistBoomerang

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const SPRITE_PATH: String = "res://assets/sprites/sickle_hammer.png"
const AUDIO_WHOOSH_PATH: String = "res://assets/audio/boomerang_whoosh.wav"

# ==============================================================================
# ÉQUILIBRAGE JAM (Boomerangs Communistes : Multi-Faucilles & Marteaux orbitaux)
# ==============================================================================
@export_group("Equilibrage Boomerang")
@export var base_damage: float = 40.0             ## Dégâts infligés par coup
@export var orbit_radius: float = 125.0           ## Rayon de rotation de base autour du joueur
@export var orbit_speed: float = 4.6              ## Vitesse angulaire de révolution (rad/s)
@export var spin_speed: float = 19.0              ## Vitesse de rotation sur soi-même (rad/s)
@export var cycle_interval: float = 2.4           ## Période de recharge entre deux déploiements
@export var weapon_level: int = 1                 ## Niveau de l'arme (1 à 5)

# Synergie passive
var has_tayon_synergy: bool = false               ## Synergie Tayon : Rayon colossal et projectiles supplémentaires

var current_angle: float = 0.0
var self_spin_angle: float = 0.0
var current_orbit_radius: float = 0.0
var state: int = 0 # 0: En attente, 1: Expansion, 2: Révolution, 3: Retour
var state_timer: float = 0.0
var hit_cooldowns: Dictionary = {}

# Données des projectiles actifs gérés dynamiquement
# Chaque élément : { "area": Area2D, "shape": CollisionShape2D, "sprite": Sprite2D, "phase": float }
var projectile_nodes: Array[Dictionary] = []

@onready var initial_hit_area: Area2D = $HitArea
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	if ResourceLoader.exists(AUDIO_WHOOSH_PATH):
		audio_player.stream = load(AUDIO_WHOOSH_PATH)
		
	_rebuild_projectiles()
	_start_throw()

func _get_total_projectiles_count() -> int:
	# Niveau 1 = 1, Niv 2 = 2, Niv 3 = 3, Niv 4 = 4, Niv 5 = 5
	var count = weapon_level
	if has_tayon_synergy:
		count += 2 # +2 faucilles orbitales colossales avec Tayon
	return maxi(1, count)

func _rebuild_projectiles() -> void:
	# Nettoie les anciens noeuds créés dynamiquement (sauf initial_hit_area)
	for p in projectile_nodes:
		var a: Area2D = p.get("area")
		if is_instance_valid(a) and a != initial_hit_area:
			a.queue_free()
	projectile_nodes.clear()

	var total_count = _get_total_projectiles_count()
	var tex: Texture2D = null
	if ResourceLoader.exists(SPRITE_PATH):
		tex = load(SPRITE_PATH) as Texture2D

	for i in range(total_count):
		var area: Area2D = null
		var shape_node: CollisionShape2D = null
		var sprite_node: Sprite2D = null

		if i == 0 and is_instance_valid(initial_hit_area):
			area = initial_hit_area
			shape_node = area.get_node_or_null("CollisionShape2D") as CollisionShape2D
			sprite_node = area.get_node_or_null("Sprite2D") as Sprite2D
			# S'assure que la connexion n'est pas dupliquée
			if not area.body_entered.is_connected(_on_enemy_hit):
				area.body_entered.connect(_on_enemy_hit)
			if not area.area_entered.is_connected(_on_enemy_hit):
				area.area_entered.connect(_on_enemy_hit)
		else:
			area = Area2D.new()
			area.name = "BoomerangArea_%d" % i
			area.collision_layer = 16
			area.collision_mask = 4
			area.body_entered.connect(_on_enemy_hit)
			area.area_entered.connect(_on_enemy_hit)
			add_child(area)

			shape_node = CollisionShape2D.new()
			var circle = CircleShape2D.new()
			circle.radius = 22.0
			shape_node.shape = circle
			area.add_child(shape_node)

			sprite_node = Sprite2D.new()
			area.add_child(sprite_node)

		if sprite_node != null and tex != null:
			sprite_node.texture = tex
			sprite_node.scale = Vector2(0.18, 0.18)

		var phase = float(i) * (TAU / float(total_count))
		projectile_nodes.append({
			"area": area,
			"shape": shape_node,
			"sprite": sprite_node,
			"phase": phase
		})

	_update_monitoring_and_visibility(state != 0)

func _update_monitoring_and_visibility(is_active: bool) -> void:
	visible = is_active
	for p in projectile_nodes:
		var a: Area2D = p.get("area")
		if is_instance_valid(a):
			a.monitoring = is_active
			a.visible = is_active

func _start_throw() -> void:
	state = 1
	state_timer = 0.0
	current_orbit_radius = 20.0
	hit_cooldowns.clear()
	_update_monitoring_and_visibility(true)
	
	if audio_player.stream != null:
		audio_player.play()

func _process(delta: float) -> void:
	# Mise à jour des immunités individuelles pour éviter les multi-dégâts en 1 frame
	for enemy in hit_cooldowns.keys():
		hit_cooldowns[enemy] -= delta
		if hit_cooldowns[enemy] <= 0:
			hit_cooldowns.erase(enemy)
	
	var target_radius = orbit_radius + (weapon_level - 1) * 12.0
	if has_tayon_synergy:
		target_radius *= 1.6
	
	self_spin_angle += spin_speed * delta
	current_angle += orbit_speed * delta
	
	match state:
		0: # Attente avant prochain jet
			state_timer += delta
			_update_monitoring_and_visibility(false)
			if state_timer >= cycle_interval:
				_start_throw()
		1: # Expansion vers le rayon d'orbite
			current_orbit_radius = move_toward(current_orbit_radius, target_radius, 400.0 * delta)
			if current_orbit_radius >= target_radius:
				state = 2
				state_timer = 0.0
		2: # Révolution soutenue autour du joueur
			state_timer += delta
			var active_duration = 3.6 + (weapon_level - 1) * 0.6
			if state_timer >= active_duration:
				state = 3
		3: # Rétraction / Retour vers le joueur
			current_orbit_radius = move_toward(current_orbit_radius, 0.0, 440.0 * delta)
			if current_orbit_radius <= 16.0:
				state = 0
				state_timer = 0.0
				_update_monitoring_and_visibility(false)

	# Positionnement physique de chaque boomerang en orbite
	var total_count = projectile_nodes.size()
	for i in range(total_count):
		var p = projectile_nodes[i]
		var a: Area2D = p.get("area")
		var s: Sprite2D = p.get("sprite")
		var phase: float = p.get("phase")
		
		if is_instance_valid(a):
			var p_angle = current_angle + phase
			var offset = Vector2(cos(p_angle), sin(p_angle)) * current_orbit_radius
			a.position = offset
			if is_instance_valid(s):
				s.rotation = self_spin_angle + float(i) * 1.2
				# Léger grossissement avec le niveau
				var sc = 0.18 + (weapon_level - 1) * 0.015
				s.scale = Vector2(sc, sc)
				
	queue_redraw()

func _draw() -> void:
	if state == 0 or not visible or projectile_nodes.is_empty():
		return
	
	var gold = Color(1.0, 0.85, 0.15)
	var red = Color(0.95, 0.15, 0.15)
	
	# 1. Anneau d'énergie orbitale rouge
	var ring_alpha = 0.28 + (weapon_level - 1) * 0.06
	draw_arc(Vector2.ZERO, current_orbit_radius, 0.0, TAU, 36, Color(red.r, red.g, red.b, ring_alpha), 2.5)
	
	# 2. Sillage et traînées de feu pour CHAQUE boomerang en rotation
	for p in projectile_nodes:
		var phase: float = p.get("phase")
		var p_angle = current_angle + phase
		
		# Traînée externe rougeoyante
		draw_arc(Vector2.ZERO, current_orbit_radius, p_angle - 0.75, p_angle, 8, Color(red.r, red.g, red.b, 0.65), 3.5)
		# Cœur doré incisif
		draw_arc(Vector2.ZERO, current_orbit_radius, p_angle - 0.35, p_angle, 6, Color(gold.r, gold.g, gold.b, 0.9), 2.0)
		
		# Si le sprite officiel n'est pas chargé, on dessine le fallback procédural
		var s: Sprite2D = p.get("sprite")
		if s == null or s.texture == null:
			var center = Vector2(cos(p_angle), sin(p_angle)) * current_orbit_radius
			draw_circle(center, 5.0, red)
			draw_arc(center, 12.0, self_spin_angle, self_spin_angle + 2.8, 8, gold, 3.5)

func _on_enemy_hit(target: Node2D) -> void:
	if target in hit_cooldowns:
		return
		
	if target.is_in_group("enemies") and target.has_method("take_damage"):
		var effective_dmg = base_damage * (1.0 + (weapon_level - 1) * 0.25)
		if has_tayon_synergy:
			effective_dmg *= 1.4
			
		target.take_damage(effective_dmg)
		hit_cooldowns[target] = 0.30 # Immunité temporaire de 0.3s par cible

func upgrade() -> void:
	weapon_level += 1
	_rebuild_projectiles()

func set_tayon_synergy(enabled: bool) -> void:
	has_tayon_synergy = enabled
	_rebuild_projectiles()
