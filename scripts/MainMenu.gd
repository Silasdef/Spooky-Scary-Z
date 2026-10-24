extends Control
class_name MainMenu

# ==============================================================================
# CHEMINS D'ACCÈS ASSETS & CONFIG
# ==============================================================================
const MAP_SCENE_PATH: String = "res://scenes/Map/Map.tscn"
const AUDIO_MENU_MUSIC_PATH: String = "res://assets/audio/zombies_menu.mp3"
const AUDIO_FALLBACK_MUSIC_PATH: String = "res://assets/audio/menu_theme.wav"
const AUDIO_CLICK_PATH: String = "res://assets/audio/button_click.wav"
const SETTINGS_FILE_PATH: String = "user://settings.cfg"
const SAVE_GAME_PATH: String = "user://savegame.json"

# ==============================================================================
# RÉFÉRENCES NOEUDS
# ==============================================================================
@onready var continue_button: Button = $ButtonsContainer/ContinueButton
@onready var new_game_button: Button = $ButtonsContainer/NewGameButton
@onready var settings_button: Button = $ButtonsContainer/SettingsButton
@onready var quit_button: Button = $ButtonsContainer/QuitButton
@onready var cursor_container: Control = $CursorContainer
@onready var cursor_skull: TextureRect = $CursorContainer/CursorSkull
@onready var music_player: AudioStreamPlayer = $MusicPlayer

# Modal Paramètres
@onready var settings_modal: CenterContainer = $SettingsModal
@onready var master_slider: HSlider = $SettingsModal/Panel/Margin/VBox/MasterVolRow/MasterSlider
@onready var master_value_label: Label = $SettingsModal/Panel/Margin/VBox/MasterVolRow/Header/Value
@onready var music_slider: HSlider = $SettingsModal/Panel/Margin/VBox/MusicVolRow/MusicSlider
@onready var music_value_label: Label = $SettingsModal/Panel/Margin/VBox/MusicVolRow/Header/Value
@onready var sfx_slider: HSlider = $SettingsModal/Panel/Margin/VBox/SFXVolRow/SFXSlider
@onready var sfx_value_label: Label = $SettingsModal/Panel/Margin/VBox/SFXVolRow/Header/Value
@onready var fullscreen_check: CheckBox = $SettingsModal/Panel/Margin/VBox/FullscreenCheck
@onready var close_settings_button: Button = $SettingsModal/Panel/Margin/VBox/CloseSettingsButton

# État de navigation
var buttons: Array[Button] = []
var selected_button_index: int = 0
var target_cursor_y: float = 408.0
var time_elapsed: float = 0.0

func _ready() -> void:
	buttons = [continue_button, new_game_button, settings_button, quit_button]
	
	# Connexions des 4 boutons principaux
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Gestion du survol et du focus clavier/souris pour chaque bouton
	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.mouse_entered.connect(_on_button_hovered.bind(i))
		btn.focus_entered.connect(_on_button_focused.bind(i))

	# Configuration explicite des voisins de focus pour navigation circulaire clavier/gamepad
	continue_button.focus_neighbor_top = quit_button.get_path()
	continue_button.focus_neighbor_bottom = new_game_button.get_path()
	new_game_button.focus_neighbor_top = continue_button.get_path()
	new_game_button.focus_neighbor_bottom = settings_button.get_path()
	settings_button.focus_neighbor_top = new_game_button.get_path()
	settings_button.focus_neighbor_bottom = quit_button.get_path()
	quit_button.focus_neighbor_top = settings_button.get_path()
	quit_button.focus_neighbor_bottom = continue_button.get_path()

	# Connexions du modal Paramètres
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	close_settings_button.pressed.connect(_on_close_settings_pressed)

	_load_settings()

	var music_path = AUDIO_MENU_MUSIC_PATH
	if not ResourceLoader.exists(music_path) and ResourceLoader.exists(AUDIO_FALLBACK_MUSIC_PATH):
		music_path = AUDIO_FALLBACK_MUSIC_PATH

	if ResourceLoader.exists(music_path):
		var stream = load(music_path)
		if stream is AudioStreamMP3:
			stream.loop = true
		music_player.stream = stream
		music_player.play()

	_update_button_layout()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_update_button_layout)

	_check_save_status()

func _check_save_status() -> void:
	var has_save = FileAccess.file_exists(SAVE_GAME_PATH)
	if has_save:
		var file = FileAccess.open(SAVE_GAME_PATH, FileAccess.READ)
		var lvl = 1
		if file != null:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				var pdata = json.data.get("player", {})
				lvl = int(pdata.get("current_level", 1))
			file.close()
		continue_button.text = "CONTINUER (NIV %d)" % lvl
		continue_button.modulate = Color.WHITE
		_set_selected_button(0, false)
		continue_button.grab_focus()
	else:
		continue_button.text = "CONTINUER"
		continue_button.modulate = Color(0.65, 0.65, 0.65, 0.65)
		_set_selected_button(1, false)
		new_game_button.grab_focus()

func _update_button_layout() -> void:
	if not is_inside_tree():
		return
	var vp_size = get_viewport_rect().size
	var scale_x = vp_size.x / 1672.0
	var scale_y = vp_size.y / 941.0
	
	var btn_w = 340.0 * (vp_size.x / 1920.0)
	var btn_h = 48.0 * (vp_size.y / 1080.0)
	var btn_x = 120.0 * scale_x
	
	var y_centers = [559.0, 619.0, 679.0, 739.0]
	for i in range(buttons.size()):
		var btn = buttons[i]
		var cy = y_centers[i] * scale_y
		btn.position = Vector2(btn_x, cy - btn_h * 0.5)
		btn.size = Vector2(btn_w, btn_h)

	if selected_button_index >= 0 and selected_button_index < buttons.size():
		var sel_btn = buttons[selected_button_index]
		target_cursor_y = sel_btn.position.y + (sel_btn.size.y - cursor_container.size.y) * 0.5
		cursor_container.position.x = sel_btn.position.x - cursor_container.size.x - 8.0

func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return

	# Fermeture de la fenêtre des paramètres avec Échap / Retour
	if settings_modal.visible:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			_on_close_settings_pressed()
			_mark_input_as_handled()
		return

	# Navigation avec les flèches directionnelles (Haut / Bas) ou Z / S / W / S
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode == KEY_UP or event.keycode == KEY_W or event.keycode == KEY_Z)):
		var next_idx = (selected_button_index - 1 + buttons.size()) % buttons.size()
		_set_selected_button(next_idx)
		_mark_input_as_handled()
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and (event.keycode == KEY_DOWN or event.keycode == KEY_S)):
		var next_idx = (selected_button_index + 1) % buttons.size()
		_set_selected_button(next_idx)
		_mark_input_as_handled()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)):
		if selected_button_index >= 0 and selected_button_index < buttons.size():
			buttons[selected_button_index].emit_signal("pressed")
			_mark_input_as_handled()

func _mark_input_as_handled() -> void:
	if is_inside_tree():
		var vp = get_viewport()
		if vp != null:
			vp.set_input_as_handled()

func _process(delta: float) -> void:
	time_elapsed += delta
	
	# Interpolation fluide du réticule crâne vers le bouton sélectionné
	cursor_container.position.y = lerp(cursor_container.position.y, target_cursor_y, 18.0 * delta)
	
	# Effet de pulsation lumineuse des yeux du crâne
	var pulse = 0.8 + 0.25 * sin(time_elapsed * 6.5)
	cursor_container.modulate = Color(1.0, pulse * 0.45, pulse * 0.45, 1.0)
	
	queue_redraw()

func _set_selected_button(index: int, play_sound: bool = true) -> void:
	if index < 0 or index >= buttons.size():
		return
	selected_button_index = index
	var target_btn = buttons[index]
	target_cursor_y = target_btn.position.y + (target_btn.size.y - cursor_container.size.y) * 0.5
	cursor_container.position.x = target_btn.position.x - cursor_container.size.x - 8.0
	
	if not target_btn.has_focus() and target_btn.is_inside_tree():
		target_btn.grab_focus()
	
	if play_sound:
		_play_click_sound()
	queue_redraw()

func _on_button_hovered(index: int) -> void:
	if not settings_modal.visible:
		_set_selected_button(index)

func _on_button_focused(index: int) -> void:
	if not settings_modal.visible:
		_set_selected_button(index, false)

func _play_click_sound() -> void:
	if ResourceLoader.exists(AUDIO_CLICK_PATH):
		var click = AudioStreamPlayer.new()
		click.stream = load(AUDIO_CLICK_PATH)
		add_child(click)
		click.play()
		click.finished.connect(click.queue_free)

# ==============================================================================
# ACTIONS DES BOUTONS DU MENU
# ==============================================================================
func _on_continue_pressed() -> void:
	_play_click_sound()
	get_tree().change_scene_to_file(MAP_SCENE_PATH)

func _on_new_game_pressed() -> void:
	_play_click_sound()
	if FileAccess.file_exists(SAVE_GAME_PATH):
		DirAccess.remove_absolute(SAVE_GAME_PATH)
	get_tree().change_scene_to_file(MAP_SCENE_PATH)

func _on_settings_pressed() -> void:
	_play_click_sound()
	settings_modal.visible = true
	cursor_container.visible = false
	if is_inside_tree() and close_settings_button.is_inside_tree():
		close_settings_button.grab_focus()

func _on_quit_pressed() -> void:
	_play_click_sound()
	get_tree().quit()

# ==============================================================================
# PARAMÈTRES / SETTINGS MODAL
# ==============================================================================
func _on_close_settings_pressed() -> void:
	_play_click_sound()
	_save_settings()
	settings_modal.visible = false
	cursor_container.visible = true
	if is_inside_tree() and settings_button.is_inside_tree():
		settings_button.grab_focus()

func _on_master_volume_changed(value: float) -> void:
	master_value_label.text = "%d%%" % int(value)
	_apply_audio_volume("Master", value)

func _on_music_volume_changed(value: float) -> void:
	music_value_label.text = "%d%%" % int(value)
	_apply_audio_volume("Music", value)

func _on_sfx_volume_changed(value: float) -> void:
	sfx_value_label.text = "%d%%" % int(value)
	_apply_audio_volume("SFX", value)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_audio_volume(bus_name: String, percentage: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		if percentage <= 0.0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			var db = linear_to_db(percentage / 100.0)
			AudioServer.set_bus_volume_db(bus_idx, db)

func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE_PATH)
	
	var master_vol = 100.0
	var music_vol = 80.0
	var sfx_vol = 100.0
	var is_fullscreen = false
	
	if err == OK:
		master_vol = config.get_value("audio", "master_volume", 100.0)
		music_vol = config.get_value("audio", "music_volume", 80.0)
		sfx_vol = config.get_value("audio", "sfx_volume", 100.0)
		is_fullscreen = config.get_value("display", "fullscreen", false)

	master_slider.value = master_vol
	music_slider.value = music_vol
	sfx_slider.value = sfx_vol
	fullscreen_check.button_pressed = is_fullscreen
	
	master_value_label.text = "%d%%" % int(master_vol)
	music_value_label.text = "%d%%" % int(music_vol)
	sfx_value_label.text = "%d%%" % int(sfx_vol)
	
	_apply_audio_volume("Master", master_vol)
	_apply_audio_volume("Music", music_vol)
	_apply_audio_volume("SFX", sfx_vol)
	
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_slider.value)
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	config.set_value("display", "fullscreen", fullscreen_check.button_pressed)
	config.save(SETTINGS_FILE_PATH)
