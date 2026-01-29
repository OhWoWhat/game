extends Control

@onready var username_input = $VBoxContainer/UsernameInput
@onready var password_input = $VBoxContainer/PasswordInput
@onready var login_button = $VBoxContainer/HBoxContainer/LoginButton
@onready var register_button = $VBoxContainer/HBoxContainer/RegisterButton
@onready var status_label = $VBoxContainer/Label

@onready var http := HTTPRequest.new()

var is_login := true  # flag to check login vs register

func _ready():
	add_child(http)
	http.request_completed.connect(_on_http_request_completed)

	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)

func _on_login_pressed():
	is_login = true
	_send_request("https://readyornotgame.alwaysdata.net/login.php")

func _on_register_pressed():
	var url = "https://readyornotgame.alwaysdata.net/registerweb.php"
	OS.shell_open(url)

func _send_request(url: String):
	var username = username_input.text
	var password = password_input.text

	if username == "" or password == "":
		status_label.text = "❌ Username and password required."
		return

	var body = "username=%s&password=%s" % [
		username.uri_encode(),
		password.uri_encode()
	]

	print("📤 Sending to:", url)
	print("📦 POST body:", body)

	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var text = body.get_string_from_utf8()
	print("📩 Response:", text)

	var json = JSON.parse_string(text)

	if typeof(json) != TYPE_DICTIONARY:
		status_label.text = "❌ Internet Connection Required	."
		return

	if json.success:
		UserSession.user_id = int(json.get("user_id", 0))
		UserSession.is_tutorial_finished = int(json.get("is_tutorial_finished", 0)) == 1
		AchievementManager.load_data()
		ScoreManager.load_data()
		await get_tree().create_timer(1).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		status_label.text = "❌ " + str(json.error)
