extends Control

@onready var easy_button = $EasyDiff
@onready var normal_button = $NormalDiff
@onready var hard_button = $HardDiff

func _ready():
	easy_button.pressed.connect(func(): _start_game_with_difficulty("Easy"))
	normal_button.pressed.connect(func(): _start_game_with_difficulty("Normal"))
	hard_button.pressed.connect(func(): _start_game_with_difficulty("Hard"))

func _start_game_with_difficulty(difficulty: String):
	Global.selected_difficulty = difficulty
	Global.selected_map_path = "res://scenes/taalscene.tscn"
	get_tree().change_scene_to_file("res://scenes/cutscene.tscn")

func _load_with_loading_screen(next_scene_path: String):
	var loading_scene = load("res://scenes/LoadingScreen.tscn").instantiate()
	loading_scene.next_scene_path = next_scene_path
	get_tree().current_scene.add_child(loading_scene)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
