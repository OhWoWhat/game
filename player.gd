extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var camera: Camera3D = $camera_mount/Camera3D
@onready var animation_player: AnimationPlayer = $visuals/mixamo_base/AnimationPlayer
@onready var visuals: Node3D = $visuals

@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var label: Label = get_node_or_null("../door_label/Label")

var door_is_close:=false
var collider

# Movement
var SPEED = 2.0
const JUMP_VELOCITY = 4.5
var walking_speed = 2.0
var running_speed = 5.0
var running = false
var is_locked = false

# Camera look sensitivity
@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5

# Camera zoom/collision
var camera_default_distance := 4.0
var camera_min_distance := 1.5
var camera_smooth_speed := 10.0
var camera_offset: Vector3

func load_new_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_offset = camera.transform.origin

	var pause_menu = get_node_or_null("../PauseMenu")
	if pause_menu:
		pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))
		camera_mount.rotate_x(deg_to_rad(-event.relative.y * sens_vertical))
		camera_mount.rotation_degrees.x = clamp(camera_mount.rotation_degrees.x, -40, 40)

func _physics_process(delta: float) -> void:
	
	if !animation_player.is_playing():
		is_locked = false

	if Input.is_action_pressed("kick"):
		if animation_player.current_animation != "kick":
			animation_player.play("kick")
			is_locked = true

	if Input.is_action_pressed("run"):
		SPEED = running_speed
		running = true
	else:
		SPEED = walking_speed
		running = false

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		if !is_locked:
			if running:
				if animation_player.current_animation != "run":
					animation_player.play("running")
			else:
				if animation_player.current_animation != "walking":
					animation_player.play("walking")
			visuals.look_at(position + direction)

		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		if !is_locked:
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if !is_locked:
		move_and_slide()

	# Update camera zoom/collision
	update_camera_position(delta)
	
	if ray_cast_3d.is_colliding():
		collider = ray_cast_3d.get_collider()
		if collider and collider.name == "door_area":
			if label:
				label.text = "Press E to interact"
			if Input.is_action_just_pressed("Interact"):
				load_new_scene("res://scenes/maingame.tscn")
		else:
			if label:
				label.text = ""
	else:
		if label:
			label.text = ""
			
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):  # Escape key
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
