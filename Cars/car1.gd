extends VehicleBody3D


@onready var path_follow := get_parent()  # The PathFollow3D
const MOVE_SPEED := 5

func _physics_process(delta: float) -> void:
	# Move along the path
	path_follow.progress += MOVE_SPEED * delta
