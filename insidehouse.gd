extends Node3D

@onready var camera = $Camera3D
@onready var camera_positions = $CameraPositions
@onready var button_next = $Next
@onready var button_prev = $Previous
@onready var button_select = $Select  # <- Make sure this is correct
@onready var animation_player_timmy: AnimationPlayer = $Characters/Timmy/AnimationPlayer
@onready var animation_player_amy: AnimationPlayer = $Characters/Amy/AnimationPlayer
@onready var animation_player_michelle: AnimationPlayer = $Characters/Michelle/AnimationPlayer
@onready var label_character_name: Label = $CharacterNameLabel
@onready var unlock_label: Label = $UnlockRequirementLabel

var current_index := 0
var tween
var character_names = ["Timmy", "Amy", "Michelle"]
var locked_characters = []
var label_tween: Tween
var unlock_label_tween: Tween

func _ready():
	locked_characters.clear()
	
	button_next.pressed.connect(_on_next_pressed)
	button_prev.pressed.connect(_on_prev_pressed)

	# Lock Michelle if survival count is less than 30
	if AchievementManager.total_survivals < 30:
		locked_characters.append("Michelle")

	move_camera_to(current_index)
	update_select_button_text()

	animation_player_timmy.play("Idle0")
	animation_player_amy.play("Idle0")
	animation_player_michelle.play("Idle0")

	fade_character_name(character_names[current_index])

func _on_next_pressed():
	if current_index < camera_positions.get_child_count() - 1:
		current_index += 1
		move_camera_to(current_index)
		update_select_button_text()
		fade_character_name(character_names[current_index])

func _on_prev_pressed():
	if current_index > 0:
		current_index -= 1
		move_camera_to(current_index)
		update_select_button_text()
		fade_character_name(character_names[current_index])

func move_camera_to(index: int):
	var target_node = camera_positions.get_child(index)
	var target_pos = target_node.global_position
	var target_rot = target_node.rotation  # This is in local radians

	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	tween.tween_property(camera, "global_position", target_pos, 0.6)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "rotation", target_rot, 0.6)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)

func fade_character_name(new_name: String):
	# Kill existing tween if running
	if label_tween and label_tween.is_running():
		label_tween.kill()

	label_tween = create_tween()
	label_tween.tween_property(label_character_name, "modulate:a", 0.0, 0.1)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

	label_tween.tween_callback(Callable(self, "_update_label_text").bind(new_name))

	label_tween.tween_property(label_character_name, "modulate:a", 1.0, 1.0)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

	var current_character = character_names[current_index]
	label_character_name.text = current_character

	if current_character == "Michelle" and current_character in locked_characters:
		unlock_label.text = "Faster movement speed!\nUnlock by surviving 30 times!"
		unlock_label.visible = true
		unlock_label.modulate.a = 0.0  # Start transparent

		if unlock_label_tween and unlock_label_tween.is_running():
			unlock_label_tween.kill()

		unlock_label_tween = create_tween()
		unlock_label_tween.tween_property(unlock_label, "modulate:a", 1.0, 1.0)\
			.set_trans(Tween.TRANS_LINEAR)\
			.set_ease(Tween.EASE_IN)
	else:
		if unlock_label_tween and unlock_label_tween.is_running():
			unlock_label_tween.kill()

		unlock_label_tween = create_tween()
		unlock_label_tween.tween_property(unlock_label, "modulate:a", 0.0, 0.1)\
			.set_trans(Tween.TRANS_LINEAR)\
			.set_ease(Tween.EASE_OUT)

		# Call `hide()` after fading out
		unlock_label_tween.tween_callback(Callable(unlock_label, "hide"))

func _update_label_text(new_name: String):
	label_character_name.text = new_name

func _on_select_pressed() -> void:
	var current_character = character_names[current_index]

	if current_character in locked_characters:
		print("❌ Cannot select locked character:", current_character)
		return

	Global.selected_character_index = current_index
	update_select_button_text()
	print("✅ Character selected at index:", current_index)

	if current_index >= 0 and current_index < character_names.size():
		print("🎮 Selected Character:", character_names[current_index])

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func update_select_button_text():
	var current_character = character_names[current_index]

	if current_character in locked_characters:
		button_select.text = "Locked"
		button_select.disabled = true
	elif current_index == Global.selected_character_index:
		button_select.text = "Selected"
		button_select.disabled = true
	else:
		button_select.text = "Select"
		button_select.disabled = false
