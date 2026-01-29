extends Control

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var v_box_container: VBoxContainer = $ScrollContainer/VBoxContainer

func _ready():
	# Remove scrollbar visual styles and size
	var v_scrollbar = scroll_container.get_v_scroll_bar()
	v_scrollbar.add_theme_constant_override("scroll_bar_width", 0)
	v_scrollbar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	
	var h_scrollbar = scroll_container.get_h_scroll_bar()
	h_scrollbar.add_theme_constant_override("scroll_bar_width", 0)
	h_scrollbar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())

	# Wait for layout to update before measuring
	await get_tree().process_frame

	var start_pos = 0.0
	var end_pos = v_box_container.size.y - scroll_container.size.y

	scroll_container.scroll_vertical = start_pos

	var tween := create_tween()
	tween.tween_property(
		scroll_container,
		"scroll_vertical",
		end_pos,
		30.0  # Duration in seconds
	)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
