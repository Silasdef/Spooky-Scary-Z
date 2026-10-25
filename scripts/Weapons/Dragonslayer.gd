extends Node2D
class_name Dragonslayer

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const BASE_SPRITE_PATH: String = "res://assets/sprites/dragonslayer_droite.png"
const UPGRADED_SPRITE_PATH: String = "res://assets/sprites/dragonslayer_upgraded_droite.png"
const FALLBACK_SPRITE_PATH: String = "res://assets/sprites/dragonslayer.png"
const AUDIO_SWING_PATH: String = "res://assets/audio/sword_swing.wav"

# ==============================================================================
# ÉQUILIBRAGE JAM (Épée Colossale Guts - Attaque en arc de cercle vers le haut)
# ==============================================================================
@export_group("Equilibrage Dragonslayer")
@export var base_damage: float = 75.0           ## Dégâts colossaux de base
@export var swing_cooldown: float = 1.15        ## Temps d'attente entre deux coups (secondes)
@export var base_sword_length: float = 95.0     ## Longueur initiale de la lame
@export var length_per_level: float = 40.0      ## Allongement physique de la lame par niveau
@export var swing_duration: float = 0.20        ## Vitesse d'exécution du swing (sec)
@export var knockback_force: float = 180.0      ## Force de repoussement équilibrée (ne propulse plus les boss à l'infini)
@export var weapon_level: int = 1               ## Niveau d'amélioration (1 à 5)

# Synergie passive
var has_regen_synergy: bool = false            ## Synergie Régénération (AOE et dégâts accrus)

# État d'animation du coup
var swing_timer: float = 0.0
var is_swinging: bool = false
var alternate_left_right: bool = false         ## Alterne frappe gauche / frappe droite
var current_sword_angle: float = 0.0
var swing_progress: float = 0.0                ## Progression 0.0 -> 1.0 du swing en cours
var swing_trail_angles: Array[float] = []      ## Historique d'angles pour l'effet de sillage
var enemies_hit_this_swing: Array[Node2D] = []

@onready var sword_area: Area2D = $SwordArea
@onready var sword_collision: CollisionShape2D = $SwordArea/CollisionShape2D
@onready var sword_sprite: Sprite2D = $SwordArea/Sprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	sword_area.body_entered.connect(_on_target_entered)
	sword_area.area_entered.connect(_on_target_entered)
	sword_area.monitoring = false
	
	if ResourceLoader.exists(AUDIO_SWING_PATH):
		audio_player.stream = load(AUDIO_SWING_PATH)
		
	_update_sword_visuals_and_reach()

func _process(delta: float) -> void:
	if is_swinging:
		return
		
	swing_timer += delta
	var effective_cooldown = swing_cooldown / (1.0 + (weapon_level - 1) * 0.18)
	
	if swing_timer >= effective_cooldown:
		_execute_upward_arc_swing()
		swing_timer = 0.0

func _get_current_sword_length() -> float:
	var len_val = base_sword_length + (weapon_level - 1) * length_per_level
	if has_regen_synergy:
		len_val *= 1.3
	return len_val

func _update_sword_visuals_and_reach() -> void:
	if sword_collision == null or sword_sprite == null:
		return
		
	var cur_len = _get_current_sword_length()
	var cur_width = 34.0 + (weapon_level - 1) * 7.0
	if has_regen_synergy:
		cur_width *= 1.25

	# Mise à jour de la collision physique
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(cur_len, cur_width)
	sword_collision.shape = rect_shape
	sword_collision.position = Vector2(cur_len * 0.5, 0.0)

	# Choix du sprite : Lame de base au niveau 1, Lame Runique Étendue aux niveaux 2+
	if sword_sprite != null:
		var target_tex_path = BASE_SPRITE_PATH
		if weapon_level >= 2 and ResourceLoader.exists(UPGRADED_SPRITE_PATH):
			target_tex_path = UPGRADED_SPRITE_PATH
		elif not ResourceLoader.exists(target_tex_path) and ResourceLoader.exists(FALLBACK_SPRITE_PATH):
			target_tex_path = FALLBACK_SPRITE_PATH

		if ResourceLoader.exists(target_tex_path):
			var tex = load(target_tex_path) as Texture2D
			sword_sprite.texture = tex
			if tex != null:
				var tex_w = float(tex.get_width())
				var tex_h = float(tex.get_height())
				# Échelle proportionnelle pour que la texture s'aligne parfaitement sur la collision
				var scale_x = cur_len / tex_w
				var scale_y = (cur_width * 2.2) / tex_h
				sword_sprite.scale = Vector2(scale_x, scale_y)
				sword_sprite.position = Vector2(cur_len * 0.5, 0.0)

		# Teinte spectrale lorsque l'épée est améliorée
		if weapon_level >= 2:
			sword_sprite.modulate = Color(1.15, 0.95, 0.95, 1.0)
		else:
			sword_sprite.modulate = Color.WHITE
			
		sword_sprite.visible = false

func _execute_upward_arc_swing() -> void:
	is_swinging = true
	enemies_hit_this_swing.clear()
	swing_trail_angles.clear()
	sword_area.monitoring = true
	if sword_sprite != null:
		sword_sprite.visible = true
	
	alternate_left_right = !alternate_left_right
	
	# L'arc de balayage s'élargit avec le niveau de l'arme
	# Centre rigoureusement vers le HAUT (-PI/2, au-dessus du survivant)
	var arc_spread = deg_to_rad(170.0 + (weapon_level - 1) * 15.0) # Jusqu'à 230°
	var half_arc = arc_spread * 0.5
	var center_angle = -PI * 0.5 # -90° = HAUT (axe Y négatif)
	
	var start_angle: float
	var end_angle: float
	
	if alternate_left_right:
		# Swing montant depuis la droite vers la gauche en balayant tout le HAUT
		start_angle = center_angle + half_arc
		end_angle = center_angle - half_arc
	else:
		# Swing montant depuis la gauche vers la droite en balayant tout le HAUT
		start_angle = center_angle - half_arc
		end_angle = center_angle + half_arc
	
	current_sword_angle = start_angle
	sword_area.rotation = current_sword_angle
	swing_progress = 0.0
	queue_redraw()
	
	if audio_player.stream != null:
		audio_player.play()
	
	var dur = swing_duration / (1.0 + (weapon_level - 1) * 0.1)
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(prog: float):
			swing_progress = prog
			# Balayage continu et direct passant toujours par le haut (-PI/2)
			current_sword_angle = start_angle + (end_angle - start_angle) * prog
			sword_area.rotation = current_sword_angle
			swing_trail_angles.append(current_sword_angle)
			if swing_trail_angles.size() > 8:
				swing_trail_angles.pop_front()
			queue_redraw(),
		0.0,
		1.0,
		dur
	)
	
	tween.finished.connect(
		func():
			is_swinging = false
			sword_area.monitoring = false
			swing_trail_angles.clear()
			if sword_sprite != null:
				sword_sprite.visible = false
			queue_redraw()
	)

func _draw() -> void:
	if not is_swinging:
		return
		
	var cur_len = _get_current_sword_length()
	
	# 1. Onde de choc tranchante (Arc de vent et sillage d'énergie colossale)
	var arc_color = Color(1.0, 0.25, 0.25, 0.85) if (has_regen_synergy or weapon_level >= 2) else Color(0.9, 0.95, 1.0, 0.65)
	var core_color = Color(1.0, 0.8, 0.8, 0.95) if weapon_level >= 2 else Color.WHITE
	
	# Sillage rémanent
	if swing_trail_angles.size() >= 2:
		for i in range(swing_trail_angles.size() - 1):
			var a1 = swing_trail_angles[i]
			var a2 = swing_trail_angles[i + 1]
			var alpha_factor = float(i + 1) / float(swing_trail_angles.size())
			var c = arc_color
			c.a *= alpha_factor * 0.7
			draw_arc(Vector2.ZERO, cur_len * 0.98, min(a1, a2), max(a1, a2), 6, c, 5.0 + float(weapon_level))
			if weapon_level >= 2:
				var c_core = core_color
				c_core.a *= alpha_factor
				draw_arc(Vector2.ZERO, cur_len * 0.94, min(a1, a2), max(a1, a2), 6, c_core, 2.5)

	# Grand arc de coupe frontal
	draw_arc(Vector2.ZERO, cur_len * 1.02, current_sword_angle - 0.45, current_sword_angle + 0.45, 10, arc_color, 4.0 + float(weapon_level) * 1.5)
	
	# Si améliorée : flash d'impact / onde de choc rougeoyante
	if weapon_level >= 2:
		var slash_tip = Vector2.from_angle(current_sword_angle) * (cur_len * 1.02)
		draw_circle(slash_tip, 6.0 + float(weapon_level) * 2.0, Color(1.0, 0.2, 0.2, 0.7))
		draw_circle(slash_tip, 3.0 + float(weapon_level), Color.WHITE)

func _on_target_entered(node: Node2D) -> void:
	if not is_swinging:
		return
	if node in enemies_hit_this_swing:
		return
		
	if node.is_in_group("enemies") and node.has_method("take_damage"):
		enemies_hit_this_swing.append(node)
		
		# Dégâts colossaux démultipliés par l'amélioration
		var effective_dmg = base_damage * (1.0 + (weapon_level - 1) * 0.45)
		if has_regen_synergy:
			effective_dmg *= 1.45
			
		node.take_damage(effective_dmg)
		
		# Knockback repoussant modérément les monstres
		if node.has_method("apply_knockback"):
			var kb_dir = (node.global_position - global_position).normalized()
			var effective_kb = knockback_force * (1.0 + (weapon_level - 1) * 0.10)
			node.apply_knockback(kb_dir * effective_kb)

func upgrade() -> void:
	weapon_level += 1
	_update_sword_visuals_and_reach()

func set_regen_synergy(enabled: bool) -> void:
	has_regen_synergy = enabled
	_update_sword_visuals_and_reach()
