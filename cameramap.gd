extends Camera3D

@export var player_path: NodePath
var player: Node3D

# Customize this height to match your map setup
const MAP_CAMERA_HEIGHT := 30.0

func _ready():
	player = get_node(player_path)
	# Lock the rotation to always look straight down (top-down view)
	rotation_degrees = Vector3(-90, 0, 0)

func _process(delta):
	if player:
		var player_pos = player.global_transform.origin
		global_transform.origin = Vector3(player_pos.x, MAP_CAMERA_HEIGHT, player_pos.z)
