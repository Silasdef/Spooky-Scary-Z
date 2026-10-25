extends SceneTree

func _init() -> void:
	print("--- Running Test: Survivor Directional Sprites ---")
	
	var player_scene = load("res://scenes/Player/Player.tscn") as PackedScene
	assert(player_scene != null, "Player scene failed to load")
	
	var player = player_scene.instantiate()
	root.add_child(player)
	if player.sprite == null:
		player.sprite = player.get_node("Sprite2D")
	
	var characters = ["joel", "ellie"]
	var directions = [
		{"vec": Vector2(0, 1), "suffix": "bas"},
		{"vec": Vector2(0, -1), "suffix": "haut"},
		{"vec": Vector2(1, 0), "suffix": "droite"},
		{"vec": Vector2(-1, 0), "suffix": "gauche"}
	]
	
	for char_name in characters:
		player.set_character(char_name)
		print("Testing character: ", char_name)
		
		for dir_info in directions:
			player.facing_direction = dir_info.vec
			player._update_facing_sprite()
			
			var tex = player.sprite.texture
			assert(tex != null, "Texture is null for " + char_name + "_" + dir_info.suffix)
			
			var expected_file = "%s_%s.png" % [char_name, dir_info.suffix]
			var path = tex.resource_path
			print("  Dir ", dir_info.suffix, " -> ", path.get_file(), " size: ", tex.get_size())
			assert(path.get_file() == expected_file, "Expected " + expected_file + " but got " + path.get_file())
			assert(tex.get_width() == 260 and tex.get_height() == 260, "Texture dimensions not 260x260")
	
	print("--- ALL SURVIVOR SPRITE TESTS PASSED ---")
	quit(0)
