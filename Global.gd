extends Node

var selected_difficulty: String = "Normal"
var selected_map_path: String = "res://scenes/maingame.tscn"
var selected_character_index: int = 0
var show_rate_popup: bool = false
var last_rating: int = 0

var play_count: int = 0        # ✅ counts playthroughs
var rating_shown: bool = false # ✅ ensures only once

func reset() -> void:
	selected_difficulty = "Normal"
	selected_map_path = "res://scenes/maingame.tscn"
	selected_character_index = 0
	last_rating = 0
	play_count = 0
	rating_shown = false
