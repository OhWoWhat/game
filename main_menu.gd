extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/maingame.tscn")


func _on_options_pressed() -> void:
	print("Options Pressed!")


func _on_about_pressed() -> void:
	print("About Pressed!")


func _on_quit_pressed() -> void:
	get_tree().quit()
