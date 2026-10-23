extends Control
class_name MainMenu

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS
# ==============================================================================
const MAP_SCENE_PATH: String = "res://scenes/Map/Map.tscn"
const AUDIO_MENU_MUSIC_PATH: String = "res://assets/audio/menu_theme.wav"
const AUDIO_CLICK_PATH: String = "res://assets/audio/button_click.wav"

# ==============================================================================
# ÉQUILIBRAGE & AMBIANCE (Inspiré du film Obsession)
# ==============================================================================
@export_group("Ambiance Obsession")
@export var light_flicker_speed: float = 8.0     ## Vitesse de vacillement de la lumière hors-champ
@export var zombie_twitch_interval: float = 2.5  ## Fréquence des soubresauts terrifiants du zombie

var time_elapsed: float = 0.0
var zombie_sway: float = 0.0
var light_intensity: float = 1.0

@onready var play_button: Button = $UIContainer/VBoxContainer/PlayButton
@onready var quit_button: Button = $UIContainer/VBoxContainer/QuitButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	if ResourceLoader.exists(AUDIO_MENU_MUSIC_PATH):
		music_player.stream = load(AUDIO_MENU_MUSIC_PATH)
		music_player.play()
		
	# Animation terrifiante du zombie dans l'ombre
	_start_zombie_spooky_anim()

func _process(delta: float) -> void:
	time_elapsed += delta
	# Vacillement subtil de la lumière provenant de la pièce hors-champ
	light_intensity = 0.9 + 0.15 * sin(time_elapsed * light_flicker_speed) + 0.05 * sin(time_elapsed * 23.0)
	queue_redraw()

func _start_zombie_spooky_anim() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(self, "zombie_sway", 5.0, 1.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "zombie_sway", -4.0, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		# Soubresaut brusque / spasme de zombie dans le noir
		zombie_sway = randf_range(-10.0, 10.0)
	)

func _draw() -> void:
	var vp_size = get_viewport_rect().size
	
	# 1. Obscurité totale en fond
	draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.015, 0.015, 0.025))
	
	# 2. La Porte (Doorframe) sur le côté gauche/centre
	var door_x = vp_size.x * 0.28
	var door_y = vp_size.y * 0.18
	var door_w = 110.0
	var door_h = vp_size.y * 0.68
	
	# Bâti de porte sombre
	draw_rect(Rect2(door_x - 10, door_y - 10, door_w + 20, door_h + 10), Color(0.06, 0.05, 0.05))
	
	# La pièce allumée hors champ qui projette un cône de lumière intense à travers la porte
	var light_alpha = 0.55 * light_intensity
	var light_beam_pts = PackedVector2Array([
		Vector2(door_x, door_y),
		Vector2(door_x + door_w * 0.7, door_y),
		Vector2(vp_size.x * 0.9, vp_size.y),
		Vector2(door_x - 150, vp_size.y)
	])
	# Halo lumineux chaud / jaunâtre qui tranche avec le noir d'encre
	draw_colored_polygon(light_beam_pts, Color(0.95, 0.82, 0.45, light_alpha * 0.35))
	
	# Ouverture intérieure de la porte (lueur intense de la pièce hors-champ)
	draw_rect(Rect2(door_x, door_y, door_w * 0.7, door_h), Color(1.0, 0.9, 0.6, 0.85 * light_intensity))
	
	# Panneau de la porte entrebâillée
	var door_panel_pts = PackedVector2Array([
		Vector2(door_x + door_w * 0.7, door_y),
		Vector2(door_x + door_w + 10, door_y + 15),
		Vector2(door_x + door_w + 10, door_y + door_h),
		Vector2(door_x + door_w * 0.7, door_y + door_h)
	])
	draw_colored_polygon(door_panel_pts, Color(0.12, 0.08, 0.05))
	
	# 3. LE ZOMBIE TERRIFIANT DANS L'OBSCURITÉ (Positionné à la frontière de l'ombre)
	# Il se tient juste à côté du faisceau lumineux, silhouette voûtée, menaçante
	var z_x = door_x + door_w + 120.0 + zombie_sway
	var z_y = door_y + door_h * 0.48
	
	# Ombre portée au sol
	draw_circle(Vector2(z_x, z_y + 120), 45.0, Color(0.0, 0.0, 0.0, 0.6))
	
	# Silhouette noire terrifiante du zombie
	var zombie_color = Color(0.02, 0.02, 0.03) # Presque invisible dans le noir
	# Corps voûté
	draw_rect(Rect2(z_x - 22, z_y - 20, 44, 90), zombie_color)
	# Tête penchée d'un angle dérangeant
	draw_circle(Vector2(z_x + 8, z_y - 45), 24.0, zombie_color)
	# Bras tordus
	draw_line(Vector2(z_x - 20, z_y), Vector2(z_x - 55, z_y + 35), zombie_color, 12.0)
	draw_line(Vector2(z_x + 20, z_y), Vector2(z_x + 65, z_y + 40), zombie_color, 12.0)
	
	# YEUX PHOSPHORESCENTS EFFRAYANTS DANS L'OBSCURITÉ (Regard braqué sur le joueur)
	var eye_pulse = 0.7 + 0.3 * sin(time_elapsed * 4.0)
	var eye_color = Color(1.0, 0.15, 0.1, eye_pulse) # Yeux rouges sang incandescents
	draw_circle(Vector2(z_x + 3, z_y - 48), 3.5, eye_color)
	draw_circle(Vector2(z_x + 15, z_y - 46), 3.5, eye_color)
	# Petits points pupillaires blancs
	draw_circle(Vector2(z_x + 4, z_y - 48), 1.2, Color.WHITE)
	draw_circle(Vector2(z_x + 16, z_y - 46), 1.2, Color.WHITE)
	
	# Effet de vignettage / brume ténébreuse aux bordures
	draw_rect(Rect2(0, 0, vp_size.x, 30), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(0, vp_size.y - 30, vp_size.x, 30), Color(0, 0, 0, 0.8))

func _on_play_pressed() -> void:
	if ResourceLoader.exists(AUDIO_CLICK_PATH):
		var click = AudioStreamPlayer.new()
		click.stream = load(AUDIO_CLICK_PATH)
		add_child(click)
		click.play()
		await click.finished
		
	get_tree().change_scene_to_file(MAP_SCENE_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()
