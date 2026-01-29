extends Node

signal achievements_loaded

var total_survivals: int = 0

var special_achievements := {
	"10x_survived": false,
	"20x_survived": false,
	"30x_survived": false,
	"survivor": false
}

# Format: { map_name: { disaster_name: true/false } }
var achievement_data := {}
var map_disasters := {
	"BrgyTibay": ["typhoon", "tsunami", "earthquake", "volcano"],
	"MoaScene": ["earthquake", "typhoon", "tsunami"],
	"TaalScene": ["volcano","earthquake", "typhoon"]
}

var map_display_names := {
	"BrgyTibay": "Brgy Tibay",
	"MoaScene": "MOA",
	"TaalScene": "Taal"
}
var disaster_display_names := {
	"volcano": "Volcanic Eruption",
	"typhoon": "Typhoon",
	"tsunami": "Tsunami",
	"earthquake": "Earthquake"
}

func get_disaster_display_name(disaster: String) -> String:
	return disaster_display_names.get(disaster, disaster.capitalize())

func get_display_name(map_name: String) -> String:
	return map_display_names.get(map_name, map_name)

func get_disasters_for_map(map_name: String) -> Array:
	return map_disasters.get(map_name, [])

func mark_survived(map_name: String, disaster_name: String) -> void:
	if not achievement_data.has(map_name):
		achievement_data[map_name] = {}
	achievement_data[map_name][disaster_name] = true

	# Always increment total survivals
	total_survivals += 1
	_check_survival_badges()
	_check_survivor_badge()
	_send_total_survivals_to_server()

	save_data()
func _check_survival_badges():
	if total_survivals >= 10 and not special_achievements["10x_survived"]:
		_unlock_special_achievement("10x_survived")
	if total_survivals >= 20 and not special_achievements["20x_survived"]:
		_unlock_special_achievement("20x_survived")
	if total_survivals >= 30 and not special_achievements["30x_survived"]:
		_unlock_special_achievement("30x_survived")
func _check_survivor_badge():
	for map_name in map_disasters.keys():
		for disaster in map_disasters[map_name]:
			if not has_survived(map_name, disaster):
				return
	if not special_achievements["survivor"]:
		_unlock_special_achievement("survivor")
func _unlock_special_achievement(name: String):
	special_achievements[name] = true
	_send_special_achievement_to_server(name)
	print("🏅 Special achievement unlocked:", name)
func _send_special_achievement_to_server(name: String):
	var url = "https://readyornotgame.alwaysdata.net/save_special_achievement.php"
	var request = HTTPRequest.new()
	add_child(request)

	var data = {
		"user_id": UserSession.user_id,
		"achievement_name": name
	}

	request.request_completed.connect(func(result, response_code, headers, body):
		print("🛰️ Server response:", body.get_string_from_utf8())
	)

	request.request(
		url,
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		http_build_query(data)
	)

func has_survived(map_name: String, disaster_name: String) -> bool:
	return achievement_data.get(map_name, {}).get(disaster_name, false)

func save_data():
	if UserSession.user_id < 0:
		return

	# Save disaster survivals
	for map_name in achievement_data.keys():
		for disaster_name in achievement_data[map_name].keys():
			if achievement_data[map_name][disaster_name]:
				_send_achievement_to_server(map_name, disaster_name)

	# Save badge achievements
	for badge_name in special_achievements.keys():
		if special_achievements[badge_name]:
			_send_special_achievement_to_server(badge_name)

func _send_achievement_to_server(map_name: String, disaster: String):
	print("📡 Sending achievement for:", map_name, "Disaster:", disaster)
	var url = "https://readyornotgame.alwaysdata.net/save_achievement.php"
	var request = HTTPRequest.new()
	add_child(request)

	var data = {
		"user_id": UserSession.user_id,
		"map_name": map_name,
		"disaster": disaster
	}

	request.request_completed.connect(func(result, response_code, headers, body):
		var response = body.get_string_from_utf8()
		print("✅ Achievement save response:", response)
	)

	request.request(
		url,
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		http_build_query(data)
	)

func load_data():
	print("🛰️ AchievementManager.load_data() called for user:", UserSession.user_id)
	if UserSession.user_id < 0:
		return

	var url = "https://readyornotgame.alwaysdata.net/get_achievements.php?user_id=%d" % UserSession.user_id
	var request = HTTPRequest.new()
	add_child(request)

	request.request_completed.connect(_on_achievements_loaded)
	request.request(url)
	
func _send_total_survivals_to_server():
	var url = "https://readyornotgame.alwaysdata.net/save_total_survivals.php"
	var request = HTTPRequest.new()
	add_child(request)

	var data = {
		"user_id": UserSession.user_id,
		"total_survivals": total_survivals
	}

	request.request_completed.connect(func(result, response_code, headers, body):
		var response = body.get_string_from_utf8()
		print("📡 Total survivals save response:", response)
	)

	request.request(
		url,
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		http_build_query(data)
	)

func _on_achievements_loaded(result, response_code, headers, body):
	var response = body.get_string_from_utf8()
	print("📥 Achievements load response:", response)

	if response_code != 200:
		print("❌ Failed to load achievements from server.")
		return

	var json = JSON.parse_string(response)
	if json.success:
		# Reset all data
		achievement_data.clear()
		special_achievements.clear()
		special_achievements = {
			"10x_survived": false,
			"20x_survived": false,
			"30x_survived": false,
			"survivor": false
		}
		total_survivals = int(json.get("total_survivals", 0))

		# Load disaster achievements
		for entry in json.achievements:
			var map = entry["map_name"]
			var disaster = entry["disaster"]
			if not achievement_data.has(map):
				achievement_data[map] = {}
			achievement_data[map][disaster] = true

		# Load special badge achievements
		for badge_name in json.get("special_achievements", []):
			special_achievements[badge_name] = true

		print("✅ Total survivals loaded:", total_survivals)
		print("✅ Special achievements loaded:", special_achievements)
		print("✅ Disaster achievements loaded:", achievement_data)

		# 🔥 Trigger unlocks based on loaded data
		_check_survival_badges()
		_check_survivor_badge()

		emit_signal("achievements_loaded")
	else:
		print("❌ Error loading achievements:", json.error)

func http_build_query(data: Dictionary) -> String:
	var result = []
	for key in data.keys():
		result.append(str(key).uri_encode() + "=" + str(data[key]).uri_encode())
	return "&".join(result)
