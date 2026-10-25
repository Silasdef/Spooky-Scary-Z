extends EnemyBase
class_name ColosseBoss

# ==============================================================================
# BOSS "LE COLOSSE" (THE LAST OF US - BLOATER)
# Boss titanesque et terrifiant armé d'attaques de spores à distance
# et de frappes dévastatrices au corps-à-corps (25 PV).
# ==============================================================================

# Chemins d'accès des sprites et scènes
const SPRITE_BAS_PATH: String = "res://assets/sprites/colosse_boss_bas.png"
const SPRITE_HAUT_PATH: String = "res://assets/sprites/colosse_boss_haut.png"
const SPRITE_DROITE_PATH: String = "res://assets/sprites/colosse_boss_droite.png"
const SPRITE_GAUCHE_PATH: String = "res://assets/sprites/colosse_boss_gauche.png"
const SPRITE_ATTACK_PATH: String = "res://assets/sprites/colosse_boss_attack.png"
const SPRITE_IMPACT_PATH: String = "res://assets/sprites/frankenstein_melee_impact.png"
const SPORE_BOMB_SCENE_PATH: String = "res://scenes/Enemies/SporeBomb.tscn"
const AUDIO_ROAR_PATH: String = "res://assets/audio/frankenstein_roar.wav"

# Équilibrage du Boss Colosse
@export_group("Equilibrage Boss Colosse")
@export var boss_health: float = 2500.0          ## Points de vie massifs
@export var boss_speed: float = 36.0             ## Déplacement lourd et implacable
@export var boss_contact_damage: float = 12.0    ## Dégâts de contact réguliers
@export var boss_melee_damage: float = 25.0      ## Dégâts du coup de mêlée violent (25 PV)
@export var boss_knockback_resistance: float = 0.88 ## Forte résistance au recul
@export var melee_range: float = 80.0            ## Distance pour déclencher la frappe de mêlée
@export var melee_cooldown: float = 1.3          ## Temps de recharge du coup de mêlée
@export var melee_duration: float = 0.5          ## Durée totale de la frappe
@export var spore_cooldown: float = 4.2          ## Fréquence de jet des boules de spores
@export var spore_windup_duration: float = 0.55  ## Temps de préparation du lancer

var spore_timer: float = 0.0
var is_throwing_spore: bool = false
var spore_throw_timer: float = 0.0
var spore_bomb_spawned: bool = false
var spore_bomb_scene: PackedScene = null

var melee_timer: float = 0.0
var is_melee_attacking: bool = false
var melee_attack_timer: float = 0.0
var melee_hit_applied: bool = false
var melee_direction: Vector2 = Vector2.DOWN

var tex_bas: Texture2D = null
var tex_haut: Texture2D = null
var tex_droite: Texture2D = null
var tex_gauche: Texture2D = null
var tex_attack: Texture2D = null

@onready var audio_roar: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var melee_impact_sprite: Sprite2D = $MeleeImpact

func _init() -> void:
	max_health = boss_health
	current_health = boss_health
	move_speed = boss_speed
	contact_damage = boss_contact_damage
	contact_radius = 52.0
	knockback_resistance = boss_knockback_resistance

func _ready() -> void:
	max_health = boss_health
	move_speed = boss_speed
	contact_damage = boss_contact_damage
	contact_radius = 52.0
	knockback_resistance = boss_knockback_resistance
	
	super._ready()
	
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if melee_impact_sprite == null:
		melee_impact_sprite = get_node_or_null("MeleeImpact")
		
	# Chargement des textures directionnelles
	if ResourceLoader.exists(SPRITE_BAS_PATH):
		tex_bas = load(SPRITE_BAS_PATH)
	if ResourceLoader.exists(SPRITE_HAUT_PATH):
		tex_haut = load(SPRITE_HAUT_PATH)
	if ResourceLoader.exists(SPRITE_DROITE_PATH):
		tex_droite = load(SPRITE_DROITE_PATH)
	if ResourceLoader.exists(SPRITE_GAUCHE_PATH):
		tex_gauche = load(SPRITE_GAUCHE_PATH)
	if ResourceLoader.exists(SPRITE_ATTACK_PATH):
		tex_attack = load(SPRITE_ATTACK_PATH)
		
	if ResourceLoader.exists(SPORE_BOMB_SCENE_PATH):
		spore_bomb_scene = load(SPORE_BOMB_SCENE_PATH)
		
	if tex_bas != null:
		sprite.texture = tex_bas
	sprite.scale = Vector2(0.55, 0.55)
	
	if melee_impact_sprite != null and ResourceLoader.exists(SPRITE_IMPACT_PATH):
		melee_impact_sprite.texture = load(SPRITE_IMPACT_PATH)
		melee_impact_sprite.visible = false
		
	if audio_roar != null and ResourceLoader.exists(AUDIO_ROAR_PATH):
		audio_roar.stream = load(AUDIO_ROAR_PATH)
		audio_roar.pitch_scale = 0.75 # Voix plus grave et gutturale pour le Colosse
		audio_roar.play()

func _physics_process(delta: float) -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if melee_impact_sprite == null:
		melee_impact_sprite = get_node_or_null("MeleeImpact")
		
	# 1. Gestion du lancer de la boule de spore
	if is_throwing_spore:
		spore_throw_timer += delta
		velocity = Vector2.ZERO
		move_and_slide()
		
		# Animation du lancer de spore
		if sprite != null and tex_attack != null:
			sprite.texture = tex_attack
			if is_instance_valid(target_player):
				sprite.flip_h = (target_player.global_position.x < global_position.x)
			
		# Phase d'armement : le colosse se soulève puis projette la spore
		if spore_throw_timer < 0.25:
			var pull_prog = spore_throw_timer / 0.25
			sprite.position = Vector2(0, -pull_prog * 10.0)
			sprite.scale = Vector2(0.52, 0.58)
		elif spore_throw_timer < 0.38 and not spore_bomb_spawned:
			spore_bomb_spawned = true
			_spawn_spore_bomb()
			sprite.position = Vector2(0, 6.0)
			sprite.scale = Vector2(0.58, 0.50)
		else:
			var rec_prog = clamp((spore_throw_timer - 0.38) / (spore_windup_duration - 0.38), 0.0, 1.0)
			sprite.position = Vector2(0, 6.0 * (1.0 - rec_prog))
			sprite.scale = Vector2(0.58, 0.50).lerp(Vector2(0.55, 0.55), rec_prog)
			
		if spore_throw_timer >= spore_windup_duration:
			is_throwing_spore = false
			spore_throw_timer = 0.0
			spore_bomb_spawned = false
			sprite.position = Vector2.ZERO
			sprite.scale = Vector2(0.55, 0.55)
			sprite.flip_h = false
		return
		
	# 2. Gestion de l'attaque de mêlée (Coup titanesque vers le joueur)
	if is_melee_attacking:
		melee_attack_timer += delta
		velocity = Vector2.ZERO
		move_and_slide()
		
		if sprite != null and tex_attack != null:
			sprite.texture = tex_attack
			sprite.flip_h = (melee_direction.x < 0)
			
		# Animation dynamique de frappe vers la cible
		if melee_attack_timer < 0.16:
			# Phase 1 : Armement / recul avant l'impact
			var pull_prog = melee_attack_timer / 0.16
			sprite.position = -melee_direction * (pull_prog * 14.0)
			sprite.scale = Vector2(0.52, 0.58)
		elif melee_attack_timer < 0.24:
			# Phase 2 : Détente violente vers l'avant
			var strike_prog = (melee_attack_timer - 0.16) / 0.08
			sprite.position = -melee_direction * 14.0 + (melee_direction * 42.0) * strike_prog
			sprite.scale = Vector2(0.60, 0.48)
		else:
			# Phase 3 : Rétablissement
			var rec_prog = clamp((melee_attack_timer - 0.24) / (melee_duration - 0.24), 0.0, 1.0)
			sprite.position = (melee_direction * 28.0) * (1.0 - rec_prog)
			sprite.scale = Vector2(0.60, 0.48).lerp(Vector2(0.55, 0.55), rec_prog)
			
		# Application du coup au corps-à-corps (25 PV)
		if melee_attack_timer >= 0.22 and not melee_hit_applied:
			melee_hit_applied = true
			_execute_melee_hit()
			
		# Animation de l'onde de choc / impact
		if melee_impact_sprite != null and melee_hit_applied:
			var impact_prog = (melee_attack_timer - 0.22) / (melee_duration - 0.22)
			melee_impact_sprite.visible = impact_prog < 0.95
			melee_impact_sprite.modulate.a = 1.0 - impact_prog
			melee_impact_sprite.scale = Vector2(0.55, 0.55) * (1.0 + impact_prog * 0.6)
			
		if melee_attack_timer >= melee_duration:
			is_melee_attacking = false
			melee_attack_timer = 0.0
			sprite.position = Vector2.ZERO
			sprite.scale = Vector2(0.55, 0.55)
			sprite.flip_h = false
			if melee_impact_sprite != null:
				melee_impact_sprite.visible = false
		return
		
	# 3. Vérification de l'attaque de mêlée
	melee_timer += delta
	if is_instance_valid(target_player) and melee_timer >= melee_cooldown:
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= melee_range:
			_start_melee_attack()
			return
			
	# 4. Vérification du jet de boule de spore
	spore_timer += delta
	if is_instance_valid(target_player) and spore_timer >= spore_cooldown:
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= 750.0 and dist > melee_range * 0.8:
			_start_spore_throw()
			spore_timer = 0.0
			return
			
	# 5. Déplacement vers le joueur
	super._physics_process(delta)
	_update_directional_sprite()

func _start_melee_attack() -> void:
	is_melee_attacking = true
	melee_attack_timer = 0.0
	melee_hit_applied = false
	melee_timer = 0.0
	
	if is_instance_valid(target_player):
		melee_direction = (target_player.global_position - global_position).normalized()
	else:
		melee_direction = Vector2.DOWN
		
	if melee_impact_sprite != null:
		melee_impact_sprite.position = melee_direction * 40.0
		melee_impact_sprite.rotation = melee_direction.angle()
		melee_impact_sprite.visible = false

func _execute_melee_hit() -> void:
	if not is_instance_valid(target_player):
		return
		
	var dist = global_position.distance_to(target_player.global_position)
	# Tolérance de frappe en mêlée : 100 pixels
	if dist <= 100.0:
		if target_player.has_method("take_damage"):
			target_player.take_damage(boss_melee_damage)
		# Léger recul appliqué au joueur
		if "velocity" in target_player:
			target_player.velocity += melee_direction * 180.0

func _start_spore_throw() -> void:
	is_throwing_spore = true
	spore_throw_timer = 0.0
	spore_bomb_spawned = false

func _spawn_spore_bomb() -> void:
	if spore_bomb_scene == null or not is_instance_valid(target_player) or get_parent() == null:
		return
		
	var bomb = spore_bomb_scene.instantiate() as SporeBomb
	if bomb != null:
		get_parent().add_child(bomb)
		bomb.setup(global_position + Vector2(0, -25.0), target_player.global_position)

func _update_directional_sprite() -> void:
	if sprite == null:
		return
	var dir = velocity
	if is_instance_valid(target_player):
		dir = target_player.global_position - global_position
		
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			if tex_droite != null:
				sprite.texture = tex_droite
			sprite.flip_h = false
		else:
			if tex_gauche != null:
				sprite.texture = tex_gauche
			sprite.flip_h = false
	else:
		if dir.y > 0:
			if tex_bas != null:
				sprite.texture = tex_bas
		else:
			if tex_haut != null:
				sprite.texture = tex_haut
		sprite.flip_h = (dir.x < 0)
