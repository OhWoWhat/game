extends Node

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_label: Label = $SkipLabel  # Optional onscreen label

var cutscene_skipped := false

func _ready():
	video_player.play()
	video_player.finished.connect(_on_cutscene_finished)
	if skip_label:
		skip_label.visible = true

func _input(event):
	if event.is_action_pressed("cutscene_skip") and not cutscene_skipped:
		cutscene_skipped = true
		video_player.stop()
		_on_cutscene_finished()

func _on_cutscene_finished():
	if skip_label:
		skip_label.visible = false

	queue_free()  # Remove cutscene scene

	var loading_screen = load("res://scenes/LoadingScreen.tscn").instantiate()
	loading_screen.next_scene_path = Global.selected_map_path
	get_tree().root.add_child(loading_screen)
