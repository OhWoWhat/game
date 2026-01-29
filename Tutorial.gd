extends Node3D

enum TutorialStep {
	MOVE,
	SPRINT,
	CROUCH,
	JUMP,
	USE_ITEM,     # 🩹 Healing comes before evac
	EVACUATE,     # 🚪 Follow-up step
	FOLLOW_EXIT,
	FINISHED	
}

var current_step := TutorialStep.MOVE

var w := false
var a := false
var s := false
var d := false
var sprint := false
var crouch := false
var has_released_shift := false
var jumped := false
var used_item := false  # ✅ NEW
var player: Node = null

@onready var label := $UI/TutorialLabel
@onready var player_spawn_point: Marker3D = $PlayerSpawnPoint
@onready var locker_falling_animation: AnimationPlayer = $Locker/LockerFallingAnimation
@onready var jump_area: Area3D = $JumpTutorialArea
@onready var door_area := $DoorArea
@onready var tutorial_popup := $TutorialCompletePopup
@onready var back_button := $TutorialCompletePopup/Panel/Button

var transitioning := false
var jump_tutorial_shown := false

var character_scenes := [
	preload("res://scenes/Timmy.tscn"),
	preload("res://scenes/Amy.tscn"),
	preload("res://scenes/Michelle.tscn"),
]
func _ready():
	# ✅ Unlock tutorial immediately when entering
	UserSession.is_tutorial_finished = true  

	# ✅ Send unlock request to DB
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_tutorial_unlock_response)

	var url = "https://readyornotgame.alwaysdata.net/finish_tutorial.php"
	var post_data = "user_id=%s" % str(UserSession.user_id)
	var headers = ["Content-Type: application/x-www-form-urlencoded"]

	print("📤 Unlocking tutorial for user:", UserSession.user_id)
	http.request(url, headers, HTTPClient.METHOD_POST, post_data)

	# ✅ Remove any existing Player (avoids duplicate characters)
	var old_player = get_node_or_null("Player")
	if old_player:
		old_player.queue_free()

	# Instantiate the chosen character
	var selected_scene = character_scenes[Global.selected_character_index]
	player = selected_scene.instantiate()
	player.name = "Player"
	add_child(player)

	# Position at spawn point
	if player_spawn_point:
		player.global_transform.origin = player_spawn_point.global_transform.origin

	# ✅ Add to "player" group (important for ladders/NPCs)
	player.add_to_group("player")

	# Now safe to connect areas
	door_area.body_entered.connect(_on_door_area_entered)
	jump_area.body_entered.connect(_on_jump_area_entered)
	back_button.pressed.connect(_on_button_pressed)

	# Tutorial label setup
	label.visible = true
	label.bbcode_enabled = true
	label.modulate.a = 0.0
	_update_label()
	_fade_in_label()
	set_process(true)

func _on_tutorial_unlock_response(result, response_code, headers, body):
	var text = body.get_string_from_utf8()
	print("📩 Tutorial unlock response:", text)

func _process(_delta):
	if transitioning:
		return

	match current_step:
		TutorialStep.MOVE:
			_check_movement_input()
		TutorialStep.SPRINT:
			_check_sprint_input()
		TutorialStep.CROUCH:
			_check_crouch_input()
		TutorialStep.USE_ITEM:
			_check_use_item_input()

	if jump_tutorial_shown and not jumped and Input.is_action_just_pressed("jump"):
		jumped = true
		label.text = "Press [color=yellow]Spacebar[/color] to jump over obstacles"

		var jump_fade_timer := Timer.new()
		jump_fade_timer.wait_time = 1.2
		jump_fade_timer.one_shot = true
		add_child(jump_fade_timer)
		jump_fade_timer.timeout.connect(func():
			_fade_out_label(func():
				current_step = TutorialStep.FOLLOW_EXIT
				_update_label()
				_fade_in_label()
			)
		)
		jump_fade_timer.start()

func _check_movement_input():
	var changed := false
	if Input.is_action_just_pressed("forward") and not w:
		w = true
		changed = true
	if Input.is_action_just_pressed("left") and not a:
		a = true
		changed = true
	if Input.is_action_just_pressed("backward") and not s:
		s = true
		changed = true
	if Input.is_action_just_pressed("right") and not d:
		d = true
		changed = true

	if changed:
		_update_label()

	if w and a and s and d:
		transitioning = true
		_fade_out_label(func():
			current_step = TutorialStep.SPRINT
			sprint = false
			has_released_shift = false
			_update_label()
			_fade_in_label()
			transitioning = false
		)

func _check_sprint_input():
	if not has_released_shift:
		if not Input.is_action_pressed("run"):
			has_released_shift = true
		return

	if Input.is_action_just_pressed("run") and not sprint:
		sprint = true
		_update_label()
		transitioning = true
		_fade_out_label(func():
			current_step = TutorialStep.CROUCH
			_update_label()
			_fade_in_label()

			if player:
				player.start_earthquake(9999.0, 0.5)

			if locker_falling_animation:
				locker_falling_animation.play("fall_over")

			transitioning = false
		)

func _check_crouch_input():
	if not crouch and Input.is_action_just_pressed("crouch"):
		crouch = true
		_update_label()

		if player:
			player.is_earthquake = false

		transitioning = true
		_fade_out_label(func():
			current_step = TutorialStep.USE_ITEM
			player.take_damage(20)
			call_deferred("spawn_medkit")
			_update_label()
			_fade_in_label()
		)

func _check_use_item_input():
	if Input.is_action_just_pressed("use_item") and not used_item:
		if player.inventory["med_kit"] < 1 or player.current_health == player.max_health:
			return
		player.use_medkit()
		print("✅ Medkit triggered; waiting for animation to finish...")

func _show_evacuation_message():
	label.text = "[b]Evacuate the area![/b]"
	_fade_in_label()

func _on_jump_area_entered(body: Node) -> void:
	if jump_tutorial_shown:
		return

	# Check by group instead of strict name
	if not body.is_in_group("player"):
		return

	jump_tutorial_shown = true

	_fade_out_label(func():
		label.text = "Press Spacebar to jump over obstacles"
		_fade_in_label()
	)

func _on_door_area_entered(body: Node) -> void: 
	if current_step != TutorialStep.FOLLOW_EXIT: 
		return 
	if not body.is_in_group("player"): 
		return 
		
	current_step = TutorialStep.FINISHED 
	tutorial_popup.visible = true 
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 
	get_tree().paused = true

func _update_label():
	match current_step:
		TutorialStep.MOVE:
			var text := "Use "
			text += "[color=yellow]W[/color]" if w else "W"
			text += ", "
			text += "[color=yellow]A[/color]" if a else "A"
			text += ", "
			text += "[color=yellow]S[/color]" if s else "S"
			text += ", "
			text += "[color=yellow]D[/color]" if d else "D"
			text += " to move"
			label.text = text
		TutorialStep.SPRINT:
			label.text = "Hold " + ("[color=yellow]Shift[/color]" if sprint else "Shift") + " to sprint"
		TutorialStep.CROUCH:
			label.text = "Press " + ("[color=yellow]Ctrl[/color]" if crouch else "Ctrl") + " to crouch"
		TutorialStep.USE_ITEM:
			label.text = "Press " + ("[color=yellow]R[/color]" if used_item else "R") + " to use a medkit"
		TutorialStep.EVACUATE:
			label.text = "[b]Evacuate the area![/b]"
		TutorialStep.FOLLOW_EXIT:
			label.text = "Follow the [color=yellow]exit sign[/color]"

func spawn_medkit():
	var medkit_scene = preload("res://resources/Lootables/FinalLootables/med_kit.tscn")
	var medkit = medkit_scene.instantiate()

	call_deferred("_place_medkit", medkit)

func _place_medkit(medkit):
	if not player or not player.is_inside_tree():
		push_warning("Player not found or not in scene tree!")
		return

	var forward = -player.transform.basis.z.normalized()
	medkit.global_transform.origin = player.global_transform.origin + forward * 3.5 + Vector3.UP

	medkit.connect("picked_up", func(item_id):
		print("🎒 Picked up item in tutorial:", item_id)
		player.add_to_inventory(item_id)
	)

	get_tree().get_current_scene().add_child(medkit)

func notify_item_used():
	if current_step == TutorialStep.USE_ITEM and not used_item:
		used_item = true
		_update_label()

		transitioning = true
		_fade_out_label(func():
			current_step = TutorialStep.EVACUATE
			_show_evacuation_message()
			transitioning = false
		)

func _fade_in_label():
	label.visible = true
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _fade_out_label(callback: Callable):
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(callback)

func notify_jump():
	if jump_tutorial_shown and not jumped:
		jumped = true
		label.text = "Press [color=yellow]Spacebar[/color] to jump over obstacles"

		var jump_fade_timer := Timer.new()
		jump_fade_timer.wait_time = 1.2
		jump_fade_timer.one_shot = true
		add_child(jump_fade_timer)
		jump_fade_timer.timeout.connect(func():
			_fade_out_label(func():
				current_step = TutorialStep.FOLLOW_EXIT
				_update_label()
				_fade_in_label()
			)
		)
		jump_fade_timer.start()

func _on_button_pressed():
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
