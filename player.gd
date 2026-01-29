extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var camera: Camera3D = $camera_mount/Camera3D
@onready var animation_player: AnimationPlayer = $visuals/AnimationPlayer
@onready var visuals: Node3D = $visuals
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var label: Label = get_node_or_null("../door_label/Label")
@onready var health_bar: ProgressBar = $"../Health/HealthBar"
@onready var med_kit_label := $"../Inventory/InventoryPanel/VBoxContainer/MedKitBox/MedKitLabel"
@onready var mask_label := $"../Inventory/InventoryPanel/VBoxContainer/MaskBox/MaskLabel"
@onready var raincoat_label := $"../Inventory/InventoryPanel/VBoxContainer/RaincoatBox/RaincoatLabel"
@export var max_slope_angle: float = 45.0  # Default is 45 degrees
@export var step_height: float = 0.4  # How high the player can step
@onready var ashfall_timer: Timer = $AshfallDamageTimer
@onready var pickup_sound: AudioStreamPlayer = $PickupSound
@onready var underwater_overlay: ColorRect = $UI/UnderwaterOverlay
@onready var inventory_panel: CanvasLayer = $"../Inventory"

var damage_multiplier: float = 1.0

# Earthquake shake variables
var is_earthquake = false
var earthquake_timer = 0.0
var earthquake_duration = 0.0
var earthquake_intensity = 0.0

var door_is_close := false
var collider

var on_ladder := false
var ladder_direction := Vector3.UP
@export var climb_speed := 2.5
var last_ladder_input_y := 0.0

# Movement
var SPEED = 2.0
const JUMP_VELOCITY = 4.5
var walking_speed = 2.0
var running_speed = 5.0
var running = false
var is_locked = false
var is_crouching := false
var is_jumping = false
var is_in_flood := false
var flood_speed_multiplier := 0.5  # Adjust as needed (0.5 = 50% slower)

# Camera look sensitivity
@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5

# Camera zoom/collision
var camera_default_distance := 4.0
var camera_min_distance := 1.5
var camera_smooth_speed := 10.0
var camera_offset: Vector3
var last_transition := ""

var camera_crouch_offset := Vector3(0, -3, 0)
var camera_target_offset := Vector3.ZERO

var vertical_camera_offset := 0.0

@export var max_health := 100
var current_health := max_health
var is_alive := true
var is_dying := false

# Inventory System
var inventory := {
	"med_kit": 0,
	"n_95_mask": 0,
	"raincoat": 0
}

func load_new_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_offset = camera.transform.origin

	if health_bar:
		health_bar.value = current_health

	var pause_menu = get_node_or_null("../PauseMenu")
	if pause_menu:
		pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS

var base_camera_rotation_x := 0.0

func _input(event: InputEvent) -> void:
	if not can_accept_input():
		return  # 🚫 Block button presses in mid-air

	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))

		base_camera_rotation_x += deg_to_rad(-event.relative.y * sens_vertical)
		base_camera_rotation_x = clamp(base_camera_rotation_x, deg_to_rad(-40), deg_to_rad(40))

	if event.is_action_pressed("inventory_toggle"):
		inventory_panel.visible = !inventory_panel.visible
		update_inventory_ui()

	if event.is_action_pressed("use_item"):
		use_medkit()

func can_accept_input() -> bool:
	return is_on_floor() or on_ladder

var is_healing = false

func use_medkit():
	if not is_alive:  # 🚫 Dead players cannot heal
		return
	if inventory["med_kit"] > 0 and current_health < max_health:
		inventory["med_kit"] -= 1
		update_inventory_ui()

		is_healing = true
		animation_player.play("InjuredHurtingIdle0")

		if not animation_player.is_connected("animation_finished", Callable(self, "_on_heal_animation_finished")):
			animation_player.connect("animation_finished", Callable(self, "_on_heal_animation_finished"))

func _on_heal_animation_finished(anim_name: StringName) -> void:
	if anim_name == "InjuredHurtingIdle0":
		current_health = min(max_health, current_health + 20)
		health_bar.value = current_health
		is_healing = false

		print("🩹 Finished healing. Current health:", current_health)

		var tutorial = get_tree().get_root().find_child("SchoolScene", true, false)
		if tutorial:
			print("📣 Tutorial node found:", tutorial)
			if tutorial.has_method("notify_item_used"):
				print("📣 Calling notify_item_used()")
				tutorial.notify_item_used()
			else:
				print("❌ Tutorial found but missing notify_item_used()")
		else:
			print("❌ Could not find Tutorial node in scene tree")

func take_damage(amount: float) -> void:
	if not is_alive:
		return

	var actual_damage = amount * damage_multiplier
	current_health -= actual_damage
	current_health = clamp(current_health, 0, max_health)

	if health_bar:
		health_bar.value = current_health

	print("Player took damage! Current health:", current_health)

	if current_health <= 0:
		die()

func _on_ashfall_damage_timer_timeout():
	if not is_alive:
		ashfall_timer.stop()
		return

	if inventory["n_95_mask"] <= 0:
		print("😷 No mask! Taking ashfall damage.")
		take_damage(5)
	else:
		print("😌 Mask equipped. No damage.")

func die():
	is_alive = false
	is_locked = true
	is_dying = true

	is_healing = false
	if animation_player.is_connected("animation_finished", Callable(self, "_on_heal_animation_finished")):
		animation_player.disconnect("animation_finished", Callable(self, "_on_heal_animation_finished"))

	print("Player has died.")
	animation_player.play("DyingBackwards0")

	# Stop the survival timer if it exists
	var main_game = get_tree().get_current_scene()
	if main_game.has_node("survival_timer"):
		main_game.get_node("survival_timer").stop()

	# Wait for the death animation to finish before showing retry screen
	if not animation_player.is_connected("animation_finished", Callable(self, "_on_death_animation_finished")):
		animation_player.connect("animation_finished", Callable(self, "_on_death_animation_finished"))

func _on_death_animation_finished(anim_name: StringName) -> void:
	if anim_name == "DyingBackwards0":
		is_dying = false
		var main_game = get_tree().get_current_scene()
		var retry_screen = main_game.get_node("CanvasLayer/RetryScreen")

		if retry_screen:
			retry_screen.visible = true
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			print("💀 Death animation finished, showing retry screen.")
		else:
			print("❌ RetryScreen not found!")

func show_rating_popup():
	var main_game = get_tree().get_current_scene()
	var rating_popup = main_game.get_node("CanvasLayer/RatingPopup") # adjust path

	if rating_popup:
		rating_popup.visible = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("⭐ Showing rating popup after 5 plays")
	else:
		print("❌ RatingPopup node not found")

func has_in_inventory(item_id: String) -> bool:
	return inventory.has(item_id) and inventory[item_id] > 0

func add_to_inventory(item_id: String):
	if inventory.has(item_id):
		inventory[item_id] += 1
	else:
		inventory[item_id] = 1
	print("✅ Picked up:", item_id, "| Total now:", inventory[item_id])
		# 🔊 Play sound
	if pickup_sound:
		pickup_sound.play()

	if inventory_panel.visible:
		update_inventory_ui()

func update_inventory_ui():
	med_kit_label.text = "Med Kit: " + str(inventory["med_kit"])
	mask_label.text = "N95 Mask: " + str(inventory["n_95_mask"])
	raincoat_label.text = "Raincoat: " + str(inventory["raincoat"])

func _process(delta):
	if underwater_overlay and underwater_overlay.material:
		underwater_overlay.material.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)

func _physics_process(delta: float) -> void:
	# Running toggle
	if Input.is_action_pressed("run"):
		SPEED = running_speed
		running = true
	else:
		SPEED = walking_speed
		running = false
	
	if is_in_flood:
		SPEED *= flood_speed_multiplier

	# Crouch toggle (only allowed if grounded or on ladder)
	if can_accept_input() and not is_healing and not is_dying and Input.is_action_just_pressed("crouch"):
		is_crouching = !is_crouching
		vertical_camera_offset = -0.5 if is_crouching else 0.0
	
	# Gravity
	if not is_on_floor() and not on_ladder:
		velocity += get_gravity() * delta
	elif is_on_floor():
		if is_jumping:
			is_jumping = false

	# Ladder climbing
	if on_ladder:
		var input_y := 0.0
		if Input.is_action_pressed("move_up"):
			input_y += 1.0
		if Input.is_action_pressed("move_down"):
			input_y -= 1.0

		if input_y != 0:
			if animation_player.current_animation != "ClimbingLadder0":
				animation_player.play("ClimbingLadder0")
			animation_player.set_speed_scale(1.0 if input_y > 0 else -1.0)
		else:
			if animation_player.current_animation == "ClimbingLadder0":
				animation_player.set_speed_scale(0.0)

		velocity = Vector3.ZERO
		velocity.y = input_y * climb_speed
		move_and_slide()
		return

	# Jump (only from floor)
	if not is_healing and not is_dying and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		var tutorial = get_tree().get_root().find_child("SchoolScene", true, false)
		if tutorial:
			tutorial.notify_jump()
		is_jumping = true
		animation_player.play("Jump0")

	# --- Movement & animation blocked if mid-air ---
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if not can_accept_input():
		move_and_slide()
	else:
		if not is_locked and not is_healing:
			if direction and not is_jumping:
				visuals.look_at(position + direction)
				if is_crouching:
					if animation_player.current_animation != "CrouchingIdle0":
						animation_player.play("CrouchingIdle0")
				elif running:
					if animation_player.current_animation != "Running0":
						animation_player.play("Running0")
				else:
					if animation_player.current_animation != "Walking0":
						animation_player.play("Walking0")
				velocity.x = direction.x * SPEED
				velocity.z = direction.z * SPEED
			elif not is_jumping:
				if is_crouching:
					if animation_player.current_animation != "CrouchingIdle0":
						animation_player.play("CrouchingIdle0")
				else:
					if animation_player.current_animation != "Idle0":
						animation_player.play("Idle0")
				velocity.x = move_toward(velocity.x, 0, SPEED)
				velocity.z = move_toward(velocity.z, 0, SPEED)

			if is_crouching:
				velocity.x = 0
				velocity.z = 0

			if is_on_floor():
				floor_snap_length = step_height
			else:
				floor_snap_length = 0.0

			move_and_slide()

	# Earthquake shake
	var shake_x = 0.0
	var shake_y = 0.0
	if is_earthquake:
		earthquake_timer += delta
		shake_x = deg_to_rad(randf_range(-1.0, 1.0) * earthquake_intensity)
		shake_y = deg_to_rad(randf_range(-1.0, 1.0) * earthquake_intensity)

		if earthquake_timer >= earthquake_duration:
			is_earthquake = false

	camera_mount.rotation.x = base_camera_rotation_x + shake_x
	camera_mount.rotation.y = shake_y
	camera_mount.position.y = lerp(camera_mount.position.y, 1.5 + vertical_camera_offset, 10 * delta)

	update_camera_position(delta)

	# Interaction raycast (only when grounded)
	if can_accept_input() and ray_cast_3d.is_colliding():
		var collider = ray_cast_3d.get_collider()
		if collider and collider.name == "door_area":
			if label:
				label.text = "Press E to Go outside"
			if Input.is_action_just_pressed("Interact"):
				load_new_scene("res://scenes/maingame.tscn")
		elif label:
			label.text = ""
	elif label:
		label.text = ""

	if is_healing:
		return  # Skip movement animation while healing

	# 🎮 Controller look input (ALWAYS allowed)
	var look_x = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var look_y = Input.get_action_strength("look_down") - Input.get_action_strength("look_up")

	look_x *= sens_horizontal * 150 * delta
	look_y *= sens_vertical * 150 * delta

	if abs(look_x) > 0.01:
		rotate_y(deg_to_rad(-look_x))
		visuals.rotate_y(deg_to_rad(look_x))

	if abs(look_y) > 0.01:
		base_camera_rotation_x += deg_to_rad(-look_y)
		base_camera_rotation_x = clamp(base_camera_rotation_x, deg_to_rad(-40), deg_to_rad(40))

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			get_tree().paused = false
			$"../PauseMenu".hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			get_tree().paused = true
			$"../PauseMenu".show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func update_camera_position(delta: float) -> void:
	var from = camera_mount.global_transform.origin
	var to = from + camera_mount.global_transform.basis * camera_offset

	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = from
	ray_params.to = to
	ray_params.exclude = [self]
	ray_params.collision_mask = 1

	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(ray_params)

	var target_position: Vector3
	if result:
		target_position = result["position"] + result["normal"] * 0.1
	else:
		target_position = to

	var current_pos = camera.global_transform.origin
	var new_pos = current_pos.lerp(target_position, camera_smooth_speed * delta)

	var cam_transform = camera.global_transform
	cam_transform.origin = new_pos
	camera.global_transform = cam_transform

func start_earthquake(duration: float, intensity: float) -> void:
	is_earthquake = true
	earthquake_timer = 0.0
	earthquake_duration = duration
	earthquake_intensity = intensity

func start_climbing(direction: Vector3):
	print("🧗 Starting climbing mode")
	on_ladder = true
	velocity = Vector3.ZERO
	ladder_direction = direction.normalized()
	animation_player.play("ClimbingLadder0")
	animation_player.set_speed_scale(0.0)

func stop_climbing():
	print("🧗‍♂️ Stopped climbing")
	on_ladder = false
	animation_player.play("Idle0")

func _on_player_slow_body_entered(body: Node3D) -> void:
	if body == self:
		is_in_flood = true
		print("🏞️ Player entered flood area")

func _on_player_slow_body_exited(body: Node3D) -> void:
	if body == self:
		is_in_flood = false
		print("🏃‍♂️ Player exited flood area")
