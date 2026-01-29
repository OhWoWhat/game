extends Control

func _ready():
	$BrgyTibay/InsideHouseButton.pressed.connect(_on_inside_house_button_pressed)
	$MoaScene/MoaButton.pressed.connect(_on_moa_button_pressed)
	$TaalScene/TaalButton.pressed.connect(_on_taal_button_pressed)

	# ✅ Connect signal before loading
	if not ScoreManager.data_loaded.is_connected(_update_score_labels):
		ScoreManager.data_loaded.connect(_update_score_labels)
	ScoreManager.load_data()

func _on_inside_house_button_pressed():
	get_tree().change_scene_to_file("res://scenes/brgytibaydiff.tscn")

func _on_moa_button_pressed():
	get_tree().change_scene_to_file("res://scenes/moadiff.tscn")

func _on_taal_button_pressed():
	get_tree().change_scene_to_file("res://scenes/taaldiff.tscn")

func _load_with_loading_screen(next_scene_path: String):
	var loading_scene = load("res://scenes/LoadingScreen.tscn").instantiate()
	loading_scene.next_scene_path = next_scene_path
	get_tree().current_scene.add_child(loading_scene)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _update_score_labels():
	var label_map := {
		"BrgyTibay": $ScoreLabel/BrgyTibayScoreLabel,
		"MoaScene": $ScoreLabel/MOAScoreLabel,
		"TaalScene": $ScoreLabel/TaalScoreLabel
	}
	print("📣 _update_score_labels() called")
	for map_name in label_map.keys():
		var score = ScoreManager.get_score(map_name)
		var label = label_map[map_name]

		if label:
			label.text = "High Score: " + str(score)
			print("✅ Updated label for", map_name, "with score:", score)
		else:
			print("❌ Could not find label for", map_name)

func _on_character_selection_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/insidehouse.tscn")
