extends VehicleBody3D

@onready var path_follow := get_parent()  # The PathFollow3D
const MOVE_SPEED := 5

var stopped := false

func _ready():
	# Connect to disaster signal
	var game_managers = get_tree().get_nodes_in_group("GameManager")
	if game_managers.size() > 0:
		var main_game = game_managers[0]
		if main_game.has_signal("disaster_started"):
			main_game.connect("disaster_started", Callable(self, "_on_disaster_started"))
	else:
		print("⚠️ No node in 'GameManager' group found for car")

func _physics_process(delta: float) -> void:
	if not stopped:
		path_follow.progress += MOVE_SPEED * delta

func _on_disaster_started(disaster_type: String) -> void:
	print("🚗 Car stopped due to disaster:", disaster_type)
	stopped = true
