extends Node2D
class_name Dragonslayer

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const SPRITE_PATH: String = "res://assets/sprites/dragonslayer.png"
const AUDIO_SWING_PATH: String = "res://assets/audio/sword_swing.wav"

# ==============================================================================
# ÉQUILIBRAGE JAM (Épée Colossale Guts - Attaque en arc de cercle vers le haut)
# ==============================================================================
@export_group("Equilibrage Dragonslayer")
@export var base_damage: float = 75.0           ## Dégâts colossaux par coup d'épée
@export var swing_cooldown: float = 1.2         ## Temps d'attente entre deux coups (secondes)
@export var sword_length: float = 90.0          ## Longueur de la lame en pixels
@export var swing_duration: float = 0.22        ## Vitesse du swing (durée de l'arc en sec)
@export var knockback_force: float = 380.0      ## Force d'expulsion des ennemis touchés
@export var weapon_level: int = 1               ## Niveau d'amélioration

# Synergie passive
var has_regen_synergy: bool = false            ## Synergie Régénération (AOE et dégâts accrus)

# État d'animation du coup
var swing_timer: float = 0.0
var is_swinging: bool = false
var alternate_left_right: bool = false         ## Alterne frappe gauche / frappe droite
var current_sword_angle: float = 0.0
var enemies_hit_this_swing: Array[Node2D] = []

@onready var sword_area: Area2D = $SwordArea
@onready var sword_collision: CollisionShape2D = $SwordArea/CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	sword_area.body_entered.connect(_on_target_entered)
	sword_area.area_entered.connect(_on_target_entered)
	sword_area.monitoring = false
	
	if ResourceLoader.exists(AUDIO_SWING_PATH):
		audio_player.stream = load(AUDIO_SWING_PATH)

func _process(delta: float) -> void:
	if is_swinging:
		return
		
	swing_timer += delta
	var effective_cooldown = swing_cooldown / (1.0 + (weapon_level - 1) * 0.15)
	
	if swing_timer >= effective_cooldown:
		_execute_upward_arc_swing()
		swing_timer = 0.0

func _execute_upward_arc_swing() -> void:
	is_swinging = true
	enemies_hit_this_swing.clear()
	sword_area.monitoring = true
	
	alternate_left_right = !alternate_left_right
	
	# Paramétrage de l'arc de cercle vers le haut :
	# On part du bas/côté et on balaye vers le haut en arc
	var start_angle: float
	var end_angle: float
	
	if alternate_left_right:
		# Frappe montant depuis la droite vers le haut-gauche
		start_angle = deg_to_rad(65.0)
		end_angle = deg_to_rad(-115.0)
	else:
		# Frappe montant depuis la gauche vers le haut-droite
		start_angle = deg_to_rad(115.0)
		end_angle = deg_to_rad(-65.0)
	
	current_sword_angle = start_angle
	sword_area.rotation = current_sword_angle
	queue_redraw()
	
	if audio_player.stream != null:
		audio_player.play()
	
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(angle: float):
			current_sword_angle = angle
			sword_area.rotation = angle
			queue_redraw(),
		start_angle,
		end_angle,
		swing_duration
	)
	
	tween.finished.connect(
		func():
			is_swinging = false
			sword_area.monitoring = false
			queue_redraw()
	)

func _draw() -> void:
	if not is_swinging:
		return
		
	# Calcul géométrique de la lame Dragonslayer
	var effective_length = sword_length
	var effective_width = 18.0
	
	if has_regen_synergy:
		effective_length *= 1.3
		effective_width *= 1.3
	
	var tip = Vector2.from_angle(current_sword_angle) * effective_length
	var normal = Vector2(-sin(current_sword_angle), cos(current_sword_angle)) * (effective_width * 0.5)
	
	# Lame géante noire/acier (esthétique Berserk)
	var blade_pts = PackedVector2Array([
		Vector2.ZERO - normal,
		tip - normal * 0.4,
		tip + Vector2.from_angle(current_sword_angle) * 10.0, # Pointe
		tip + normal * 0.4,
		Vector2.ZERO + normal
	])
	
	var blade_color = Color(0.2, 0.2, 0.25, 0.95)
	if has_regen_synergy:
		blade_color = Color(0.65, 0.1, 0.15, 0.95) # Teinte rouge sang avec la synergie
		
	draw_colored_polygon(blade_pts, blade_color)
	
	# Fil de la lame et reflets
	draw_line(tip - normal * 0.4, tip + normal * 0.4, Color.LIGHT_GRAY, 3.0)
	draw_line(Vector2.ZERO, tip, Color(0.85, 0.85, 0.9), 1.5)
	
	# Arc de vent / tranchant stylisé
	var arc_color = Color(1.0, 0.2, 0.2, 0.7) if has_regen_synergy else Color(0.9, 0.9, 1.0, 0.6)
	draw_arc(Vector2.ZERO, effective_length * 0.95, current_sword_angle - 0.4, current_sword_angle + 0.4, 8, arc_color, 4.0)

func _on_target_entered(node: Node2D) -> void:
	if not is_swinging:
		return
	if node in enemies_hit_this_swing:
		return
		
	if node.is_in_group("enemies") and node.has_method("take_damage"):
		enemies_hit_this_swing.append(node)
		
		var effective_dmg = base_damage * (1.0 + (weapon_level - 1) * 0.25)
		if has_regen_synergy:
			effective_dmg *= 1.4 # Bonus synergie Régénération
			
		node.take_damage(effective_dmg)
		
		# Application du knockback (repousse l'ennemi loin du joueur)
		if node.has_method("apply_knockback"):
			var kb_dir = (node.global_position - global_position).normalized()
			node.apply_knockback(kb_dir * knockback_force)

func upgrade() -> void:
	weapon_level += 1

func set_regen_synergy(enabled: bool) -> void:
	has_regen_synergy = enabled
