extends EnemyBase
class_name FrankensteinBoss

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const SPRITE_PATH: String = "res://assets/sprites/frankenstein_boss.png"
const SPRITE_CAST_PATH: String = "res://assets/sprites/frankenstein_boss_cast.png"
const SPRITE_IMPACT_PATH: String = "res://assets/sprites/frankenstein_melee_impact.png"
const AUDIO_ROAR_PATH: String = "res://assets/audio/frankenstein_roar.wav"
const LIGHTNING_SCENE_PATH: String = "res://scenes/Enemies/LightningStrike.tscn"

# ==============================================================================
# ÉQUILIBRAGE JAM (Boss Frankenstein)
# ==============================================================================
@export_group("Equilibrage Boss Frankenstein")
@export var boss_health: float = 2200.0         ## Points de vie colossaux (Très tanky, combat de boss épique)
@export var boss_speed: float = 40.0            ## Déplacement lourd et lent
@export var boss_contact_damage: float = 10.0   ## Dégâts de contact légers en marche
@export var boss_melee_damage: float = 25.0     ## Dégâts infligés en attaque de mêlée (25 PV)
@export var boss_knockback_resistance: float = 0.88 ## Forte résistance au recul (Colosse massif, quasi-inamovible)
@export var melee_range: float = 75.0           ## Distance d'enclenchement de l'attaque de mêlée
@export var melee_cooldown: float = 1.3         ## Temps de recharge entre deux coups de poing
@export var melee_duration: float = 0.5         ## Durée totale de l'attaque de mêlée
@export var lightning_cooldown: float = 4.5     ## Intervalle d'invocation des éclairs (sec)
@export var cast_freeze_duration: float = 1.0   ## Temps d'immobilité pendant l'incantation

var lightning_timer: float = 0.0
var is_casting: bool = false
var cast_timer: float = 0.0
var lightning_scene: PackedScene = null

var melee_timer: float = 0.0
var is_melee_attacking: bool = false
var melee_attack_timer: float = 0.0
var melee_hit_applied: bool = false
var melee_direction: Vector2 = Vector2.DOWN

@onready var audio_roar: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var melee_impact_sprite: Sprite2D = $MeleeImpact

func _init() -> void:
	max_health = boss_health
	current_health = boss_health
	move_speed = boss_speed
	contact_damage = boss_contact_damage
	contact_radius = 48.0
	knockback_resistance = boss_knockback_resistance

func _ready() -> void:
	max_health = boss_health
	move_speed = boss_speed
	contact_damage = boss_contact_damage
	contact_radius = 48.0
	knockback_resistance = boss_knockback_resistance
	
	super._ready()
	
	if melee_impact_sprite == null:
		melee_impact_sprite = get_node_or_null("MeleeImpact")
	
	if ResourceLoader.exists(LIGHTNING_SCENE_PATH):
		lightning_scene = load(LIGHTNING_SCENE_PATH)
		
	if ResourceLoader.exists(SPRITE_PATH):
		sprite.texture = load(SPRITE_PATH)
		sprite.scale = Vector2(0.5, 0.5)
	else:
		queue_redraw()
		
	if melee_impact_sprite != null and ResourceLoader.exists(SPRITE_IMPACT_PATH):
		melee_impact_sprite.texture = load(SPRITE_IMPACT_PATH)
		melee_impact_sprite.visible = false
		
	if ResourceLoader.exists(AUDIO_ROAR_PATH):
		audio_roar.stream = load(AUDIO_ROAR_PATH)
		audio_roar.play()

func _physics_process(delta: float) -> void:
	# 1. Gestion de l'incantation des éclairs
	if is_casting:
		cast_timer += delta
		velocity = Vector2.ZERO
		move_and_slide()
		_update_sprite_direction()
		queue_redraw()
		if cast_timer >= cast_freeze_duration:
			is_casting = false
			cast_timer = 0.0
		return
		
	# 2. Gestion de l'attaque de mêlée (Coup de poing vers le joueur)
	if is_melee_attacking:
		melee_attack_timer += delta
		velocity = Vector2.ZERO
		move_and_slide()
		_update_sprite_direction()
		
		# Animation dynamique du coup de poing vers le joueur
		if melee_attack_timer < 0.16:
			# Phase 1 : Armement / recul du boss avant de frapper
			var pull_prog = melee_attack_timer / 0.16
			sprite.position = -melee_direction * (pull_prog * 12.0)
			sprite.scale = Vector2(0.48, 0.52)
		elif melee_attack_timer < 0.24:
			# Phase 2 : Détente foudroyante du coup de poing vers le joueur
			var strike_prog = (melee_attack_timer - 0.16) / 0.08
			sprite.position = -melee_direction * 12.0 + (melee_direction * 40.0) * strike_prog
			sprite.scale = Vector2(0.55, 0.45)
		else:
			# Phase 3 : Retour progressif à la posture initiale
			var rec_prog = clamp((melee_attack_timer - 0.24) / (melee_duration - 0.24), 0.0, 1.0)
			sprite.position = (melee_direction * 28.0) * (1.0 - rec_prog)
			sprite.scale = Vector2(0.55, 0.45).lerp(Vector2(0.5, 0.5), rec_prog)
		
		# Moment de l'impact du coup au corps-à-corps
		if melee_attack_timer >= 0.22 and not melee_hit_applied:
			melee_hit_applied = true
			_execute_melee_hit()
			
		# Animation du sprite d'impact de mêlée
		if melee_impact_sprite != null and melee_hit_applied:
			var impact_prog = (melee_attack_timer - 0.22) / (melee_duration - 0.22)
			melee_impact_sprite.visible = impact_prog < 0.95
			melee_impact_sprite.modulate.a = 1.0 - impact_prog
			melee_impact_sprite.scale = Vector2(0.5, 0.5) * (1.0 + impact_prog * 0.5)
			
		if melee_attack_timer >= melee_duration:
			is_melee_attacking = false
			melee_attack_timer = 0.0
			sprite.position = Vector2.ZERO
			sprite.scale = Vector2(0.5, 0.5)
			if melee_impact_sprite != null:
				melee_impact_sprite.visible = false
		return
		
	# 3. Vérification du déclenchement de l'attaque de mêlée
	melee_timer += delta
	if is_instance_valid(target_player) and melee_timer >= melee_cooldown:
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= melee_range:
			_start_melee_attack()
			return
			
	# 4. Vérification de l'incantation de l'éclair
	lightning_timer += delta
	if lightning_timer >= lightning_cooldown:
		_cast_lightning_attack()
		lightning_timer = 0.0
		return
		
	# 5. Déplacement standard du boss vers le joueur
	super._physics_process(delta)
	_update_sprite_direction()

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
		melee_impact_sprite.visible = false
		melee_impact_sprite.modulate.a = 1.0
		
	_update_sprite_direction()

func _execute_melee_hit() -> void:
	# Joue le rugissement ou impact
	if audio_roar.stream != null:
		audio_roar.play()
		
	if melee_impact_sprite != null:
		melee_impact_sprite.visible = true
		melee_impact_sprite.modulate.a = 1.0
		
	# Vérifie si le joueur est dans la zone d'impact de mêlée
	if is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= melee_range * 1.3:
			# Inflige 25 points de dégâts au joueur en mêlée
			target_player.take_damage(boss_melee_damage)
			# Impulsion de recul
			if "velocity" in target_player:
				target_player.velocity += melee_direction * 200.0

func _update_sprite_direction() -> void:
	# Priorité 1 : Sprite pendant l'incantation d'éclair
	if is_casting:
		if ResourceLoader.exists(SPRITE_CAST_PATH):
			var cast_tex = load(SPRITE_CAST_PATH)
			if sprite.texture != cast_tex:
				sprite.texture = cast_tex
		return
		
	# Priorité 2 : Sprite pendant l'attaque de mêlée
	if is_melee_attacking:
		var dir_suffix = "bas"
		if abs(melee_direction.x) > abs(melee_direction.y):
			dir_suffix = "droite" if melee_direction.x > 0 else "gauche"
		else:
			dir_suffix = "bas" if melee_direction.y > 0 else "haut"
			
		var atk_path = "res://assets/sprites/frankenstein_boss_attack_%s.png" % dir_suffix
		if ResourceLoader.exists(atk_path):
			var tex = load(atk_path)
			if sprite.texture != tex:
				sprite.texture = tex
				return
		elif ResourceLoader.exists("res://assets/sprites/frankenstein_boss_attack.png"):
			sprite.texture = load("res://assets/sprites/frankenstein_boss_attack.png")
			return
			
	# Priorité 3 : Marche standard directionnelle
	if velocity.length_squared() < 1.0:
		return
		
	var dir_suffix = "bas"
	if abs(velocity.x) > abs(velocity.y):
		dir_suffix = "droite" if velocity.x > 0 else "gauche"
	else:
		dir_suffix = "bas" if velocity.y > 0 else "haut"
		
	var path = "res://assets/sprites/frankenstein_boss_%s.png" % dir_suffix
	if ResourceLoader.exists(path):
		var tex = load(path)
		if sprite.texture != tex:
			sprite.texture = tex

func _cast_lightning_attack() -> void:
	if not is_instance_valid(target_player) or lightning_scene == null:
		return
		
	is_casting = true
	cast_timer = 0.0
	
	if audio_roar.stream != null:
		audio_roar.play()
		
	# Invoque un éclair directement sur la position courante du joueur (ou légèrement anticipée)
	var strike = lightning_scene.instantiate() as Node2D
	strike.global_position = target_player.global_position
	if "target_player" in strike:
		strike.target_player = target_player
	var scene_target = get_tree().current_scene if (get_tree() != null and get_tree().current_scene != null) else (get_tree().root if get_tree() != null else null)
	if scene_target != null:
		scene_target.add_child(strike)

func _draw() -> void:
	if sprite.texture != null:
		return
		
	# Fallback procédural : Colosse de Frankenstein imposant
	# Aura électrique pendant l'incantation
	if is_casting:
		draw_circle(Vector2.ZERO, 40.0, Color(0.2, 0.7, 1.0, 0.25))
		for i in range(4):
			var spark_ang = randf() * TAU
			var spark_end = Vector2.from_angle(spark_ang) * 36.0
			draw_line(Vector2.ZERO, spark_end, Color(0.7, 0.95, 1.0), 2.0)
	
	# Torse massif carré et coutures
	draw_rect(Rect2(-24, -15, 48, 42), Color(0.18, 0.32, 0.22))
	draw_rect(Rect2(-26, -18, 52, 14), Color(0.15, 0.15, 0.18))
	
	# Énormes bras et poings
	draw_rect(Rect2(-36, -8, 12, 34), Color(0.2, 0.35, 0.25))
	draw_rect(Rect2(24, -8, 12, 34), Color(0.2, 0.35, 0.25))
	
	# Tête rectangulaire caractéristique
	draw_rect(Rect2(-16, -42, 32, 26), Color(0.22, 0.38, 0.26))
	draw_rect(Rect2(-16, -44, 32, 7), Color(0.08, 0.08, 0.08))
	
	# Électrodes / Boulons métalliques dans le cou
	draw_rect(Rect2(-22, -26, 6, 8), Color(0.7, 0.7, 0.75))
	draw_rect(Rect2(16, -26, 6, 8), Color(0.7, 0.7, 0.75))
	
	# Cicatrices & coutures noires
	draw_line(Vector2(-8, -36), Vector2(10, -32), Color(0.1, 0.05, 0.05), 2.5)
	draw_line(Vector2(-14, 0), Vector2(14, 12), Color(0.1, 0.05, 0.05), 2.5)
	
	# Yeux jaunes menaçants
	draw_circle(Vector2(-7, -30), 3.0, Color(1.0, 0.85, 0.1))
	draw_circle(Vector2(7, -30), 3.0, Color(1.0, 0.85, 0.1))

func _die() -> void:
	# Frankenstein drop plusieurs gemmes d'XP à sa mort (Boss reward)
	for i in range(5):
		var gem_scene = load(LOOT_GEM_SCENE_PATH) as PackedScene
		if gem_scene != null:
			var gem = gem_scene.instantiate() as Node2D
			gem.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			get_tree().current_scene.call_deferred("add_child", gem)
			
	super._die()
