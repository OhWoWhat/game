extends Control

@onready var resume_button = $Panel/VBoxContainer/ResumeButton
@onready var main_menu_button = $Panel/VBoxContainer/MainMenuButton
@onready var quit_button = $Panel/VBoxContainer/QuitButton


func _ready():
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed():
	get_tree().paused = false
	hide()

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn") # Change as needed

func _on_quit_pressed():
	get_tree().quit()
