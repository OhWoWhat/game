extends Control

@onready var survivals_list = $SurvivalsVBox/SurvivalsList
@onready var badges_list = $BadgesVBox/BadgesList
@onready var back_button = $Back

func _ready():
	load_leaderboard_data()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func load_leaderboard_data():
	var request = HTTPRequest.new()
	add_child(request)

	request.request_completed.connect(_on_leaderboard_loaded)
	var url = "https://readyornotgame.alwaysdata.net/get_leaderboard.php"
	request.request(url)

func _on_leaderboard_loaded(result, response_code, headers, body):
	if response_code != 200:
		print("❌ Failed to load leaderboard.")
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json.success:
		print("❌ Server error:", json.error)
		return

	# Clear old entries safely
	queue_free_children(survivals_list)
	queue_free_children(badges_list)

	# 🏆 Fill Total Survivals
	for i in range(json.top_survivals.size()):
		var entry = json.top_survivals[i]
		var label = Label.new()
		label.text = "%d. %s - %d survivals" % [i + 1, entry.username, entry.total_survivals]
		survivals_list.add_child(label)

	# 🏅 Fill Badge Rankings
	for i in range(json.top_badges.size()):
		var entry = json.top_badges[i]
		var label = Label.new()
		label.text = "%d. %s - %d achievements" % [i + 1, entry.username, entry.total_achievements]
		badges_list.add_child(label)

func queue_free_children(container: VBoxContainer):
	for child in container.get_children():
		child.queue_free()
