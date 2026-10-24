extends EnemyBase
class_name FrankensteinBoss

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const SPRITE_PATH: String = "res://assets/sprites/frankenstein_boss.png"
const AUDIO_ROAR_PATH: String = "res://assets/audio/frankenstein_roar.wav"
const LIGHTNING_SCENE_PATH: String = "res://scenes/Enemies/LightningStrike.tscn"

# ==============================================================================
# ÉQUILIBRAGE JAM (Boss Frankenstein)
# ==============================================================================
@export_group("Equilibrage Boss Frankenstein")
@export var boss_health: float = 550.0          ## Points de vie colossaux (Très tanky)
@export var boss_speed: float = 40.0            ## Déplacement lourd et lent
@export var boss_contact_damage: float = 25.0   ## Dégâts de contact dévastateurs
@export var lightning_cooldown: float = 4.5     ## Intervalle d'invocation des éclairs (sec)
@export var cast_freeze_duration: float = 1.0   ## Temps d'immobilité pendant l'incantation

var lightning_timer: float = 0.0
var is_casting: bool = false
var cast_timer: float = 0.0
var lightning_scene: PackedScene = null

@onready var audio_roar: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	max_health = boss_health
	move_speed = boss_speed
	contact_damage = boss_contact_damage
	
	super._ready()
	
	if ResourceLoader.exists(LIGHTNING_SCENE_PATH):
		lightning_scene = load(LIGHTNING_SCENE_PATH)
		
	if ResourceLoader.exists(SPRITE_PATH):
		sprite.texture = load(SPRITE_PATH)
		sprite.scale = Vector2(0.5, 0.5)
	else:
		queue_redraw()
		
	if ResourceLoader.exists(AUDIO_ROAR_PATH):
		audio_roar.stream = load(AUDIO_ROAR_PATH)
		audio_roar.play()

func _physics_process(delta: float) -> void:
	# Gestion de l'incantation des éclairs
	if is_casting:
		cast_timer += delta
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		if cast_timer >= cast_freeze_duration:
			is_casting = false
			cast_timer = 0.0
		return
		
	lightning_timer += delta
	if lightning_timer >= lightning_cooldown:
		_cast_lightning_attack()
		lightning_timer = 0.0
		return
		
	# Déplacement standard du boss vers le joueur
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
	get_tree().current_scene.add_child(strike)

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
	draw_rect(Rect2(-24, -15, 48, 42), Color(0.18, 0.32, 0.22)) # Peau vert sombre putride
	draw_rect(Rect2(-26, -18, 52, 14), Color(0.15, 0.15, 0.18)) # Veste déchirée
	
	# Énormes bras et poings
	draw_rect(Rect2(-36, -8, 12, 34), Color(0.2, 0.35, 0.25))
	draw_rect(Rect2(24, -8, 12, 34), Color(0.2, 0.35, 0.25))
	
	# Tête rectangulaire caractéristique
	draw_rect(Rect2(-16, -42, 32, 26), Color(0.22, 0.38, 0.26))
	# Cheveux plats noirs
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
