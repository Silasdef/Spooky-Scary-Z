extends CharacterBody2D
class_name EnemyBase

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS GLOBAUX
# ==============================================================================
const LOOT_GEM_SCENE_PATH: String = "res://scenes/Items/LootGem.tscn"
const AUDIO_HURT_PATH: String = "res://assets/audio/enemy_hurt.wav"

# ==============================================================================
# ÉQUILIBRAGE JAM (Paramètres de base surchargeables par chaque type)
# ==============================================================================
@export_group("Equilibrage Ennemi Base")
@export var max_health: float = 40.0            ## Points de vie maximum
@export var move_speed: float = 70.0            ## Vitesse de marche vers le joueur
@export var contact_damage: float = 10.0        ## Dégâts infligés au joueur par contact
@export var contact_radius: float = 28.0        ## Distance de frappe au contact (pas de collision physique bloquante)
@export var attack_cooldown: float = 0.8        ## Fréquence des coups au corps à corps
@export var xp_drop_chance: float = 0.5         ## Chance de drop d'une gemme d'XP (0.5 = 50%, 1 chance sur 2)

var current_health: float = 40.0
var knockback_velocity: Vector2 = Vector2.ZERO
var target_player: CharacterBody2D = null
var attack_timer: float = 0.0
var flash_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	_find_player()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0] as CharacterBody2D

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_player):
		_find_player()
		return
		
	# Gestion du recul (Knockback)
	if knockback_velocity.length() > 5.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	else:
		# Déplacement vers le joueur
		var to_player = (target_player.global_position - global_position).normalized()
		velocity = to_player * move_speed
		
	move_and_slide()
	
	# Gestion des dégâts de contact avec le joueur (sans bloquer le joueur physiquement)
	attack_timer += delta
	if attack_timer >= attack_cooldown and is_instance_valid(target_player):
		var dist_sq = global_position.distance_squared_to(target_player.global_position)
		if dist_sq <= contact_radius * contact_radius:
			target_player.take_damage(contact_damage)
			attack_timer = 0.0
				
	# Flash blanc/rouge de prise de dégâts
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			modulate = Color.WHITE

func take_damage(amount: float) -> void:
	current_health -= amount
	flash_timer = 0.12
	modulate = Color(1.8, 0.4, 0.4, 1.0) # Flash rouge vif
	
	if current_health <= 0.0:
		_die()

func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force

func _die() -> void:
	# Spawn de la gemme de loot XP
	if randf() <= xp_drop_chance and ResourceLoader.exists(LOOT_GEM_SCENE_PATH):
		var gem_scene = load(LOOT_GEM_SCENE_PATH) as PackedScene
		if gem_scene != null:
			var gem = gem_scene.instantiate() as Node2D
			gem.global_position = global_position
			var scene_target = get_tree().current_scene if (get_tree() != null and get_tree().current_scene != null) else (get_tree().root if get_tree() != null else null)
			if scene_target != null:
				scene_target.call_deferred("add_child", gem)
			
	# Notifier le joueur ou le GameManager du kill
	if is_instance_valid(target_player) and target_player.has_method("register_kill"):
		target_player.register_kill()
		
	queue_free()
