extends Control

@onready var resume_button = $Panel/VBoxContainer/ResumeButton
@onready var main_menu_button = $Panel/VBoxContainer/MainMenuButton
@onready var v_box_container: VBoxContainer = $Panel/VBoxContainer
@onready var options: Panel = $Panel/Options


func _ready():
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _on_resume_pressed():
	get_tree().paused = false
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn") # Change as needed

func _on_quit_pressed():
	get_tree().quit()

func _on_options_pressed() -> void:
	print("Options Pressed!")
	v_box_container.visible = false
	options.visible = true

func _on_back_pressed() -> void:
	v_box_container.visible = true
	options.visible = false
