extends Node

signal data_loaded

var maps_to_load := []
var load_count := 0

var scores := {}

func save_score(map_name: String, score: int) -> bool:
	if not scores.has(map_name) or score > scores[map_name]:
		scores[map_name] = score
		save_data()
		return true
	return false

func get_score(map_name: String) -> int:
	return scores.get(map_name, 0)

func save_data():
	for map_name in scores.keys():
		_send_score_to_server(map_name, scores[map_name])

func _send_score_to_server(map_name: String, score: int):
	print("📡 Sending score to server for:", map_name, "Score:", score)
	var url = "https://readyornotgame.alwaysdata.net/save_score.php"
	var request = HTTPRequest.new()
	add_child(request)

	var data = {
		"user_id": UserSession.user_id,
		"map": map_name,
		"score": score
	}

	request.request_completed.connect(func(result, response_code, headers, body):
		var response = body.get_string_from_utf8()
		print("📤 Score save response:", response)
	)	

	request.request(
		url,
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		http_build_query(data)
	)

func load_data():
	print("🛰️ ScoreManager.load_data() called for user:", UserSession.user_id)

	maps_to_load = ["BrgyTibay", "MoaScene", "TaalScene"]
	load_count = 0
	for map in maps_to_load:
		_request_score_from_server(map)

func _request_score_from_server(map_name: String):
	var url = "https://readyornotgame.alwaysdata.net/get_score.php?user_id=%d&map=%s" % [
		UserSession.user_id,
		map_name.uri_encode()
	]
	var request = HTTPRequest.new()
	add_child(request)

	request.request_completed.connect(func(result, response_code, headers, body):
		_on_score_loaded(result, response_code, headers, body, map_name)
	)

	request.request(url)

func _on_score_loaded(result, response_code, headers, body, map_name):
	var response = body.get_string_from_utf8()
	print("📥 Score load response for %s:" % map_name, response)

	if response_code != 200:
		print("❌ Failed to load score for", map_name)
		load_count += 1
		_check_all_loaded()
		return

	var json = JSON.parse_string(response)
	if json.success:
		scores[map_name] = int(json.high_score)
		print("✅ Score loaded for", map_name, ":", scores[map_name])
	else:
		scores[map_name] = 0
		print("⚠️ Defaulted to 0 for", map_name)

	load_count += 1
	_check_all_loaded()

func _check_all_loaded():
	if load_count >= maps_to_load.size():
		print("🎉 All score data loaded — emitting signal")
		emit_signal("data_loaded")

func http_build_query(data: Dictionary) -> String:
	var result = []
	for key in data.keys():
		result.append(str(key).uri_encode() + "=" + str(data[key]).uri_encode())
	return "&".join(result)
