extends PopupPanel

var selected_rating: int = 0

func _ready() -> void:
	# Connect stars
	for i in range(1, 6):
		var star_node = $Interface/HBoxContainer.get_node("star" + str(i))
		star_node.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_star_pressed(i)
		)

	# Buttons
	$Interface/CloseButton.pressed.connect(func(): hide())
	$Interface/MaybeLaterButton.pressed.connect(func(): hide())
	$Interface/SubmitButton.pressed.connect(_on_submit_pressed)

func _on_star_pressed(rating: int) -> void:
	selected_rating = rating
	print("⭐ Selected rating:", rating)

	# Highlight selected stars
	for i in range(1, 6):
		var star_node = $Interface/HBoxContainer.get_node("star" + str(i))
		star_node.modulate = Color(1, 1, 1) if i <= rating else Color(0.5, 0.5, 0.5)

func _on_submit_pressed() -> void:
	if selected_rating <= 0:
		print("⚠️ No rating selected!")
		return

	if UserSession.user_id <= 0:
		print("❌ Cannot submit rating — no user logged in.")
		return

	_send_rating_to_server(UserSession.user_id, selected_rating)

func _send_rating_to_server(user_id: int, rating: int):
	var url = "https://readyornotgame.alwaysdata.net/save_rating.php"
	var request = HTTPRequest.new()
	add_child(request)

	var data = {
		"user_id": user_id,
		"rating": rating
	}

	request.request_completed.connect(func(result, response_code, headers, body):
		var body_str = body.get_string_from_utf8().strip_edges()
		print("📩 Server response (code %d): %s" % [response_code, body_str])

		if response_code != 200:
			print("❌ HTTP error when submitting rating.")
			return

		var parsed = JSON.parse_string(body_str)
		if typeof(parsed) != TYPE_DICTIONARY:
			print("❌ JSON parse error — response was not valid JSON.")
			if body_str.find("<") != -1:
				print("ℹ️ Server likely returned HTML (maybe a PHP warning/notice). Check server logs.")
			return

		if parsed.get("success", false):
			print("✅ Rating saved successfully:", parsed.get("rating", "n/a"))
		else:
			print("❌ Error saving rating:", parsed.get("error", "Unknown error"))
	)

	request.request(
		url,
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		http_build_query(data)
	)

func http_build_query(data: Dictionary) -> String:
	var result = []
	for key in data.keys():
		result.append(str(key).uri_encode() + "=" + str(data[key]).uri_encode())
	return "&".join(result)
