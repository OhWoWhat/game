extends Control

@export var next_scene_path: String

var loader
var load_progress := [0.0]
var is_done := false

func _ready():
	loader = ResourceLoader.load_threaded_request(next_scene_path)
	$Label.text = "Loading..."
	set_process(true)

func _process(delta):
	if is_done:
		return

	var status = ResourceLoader.load_threaded_get_status(next_scene_path, load_progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			$ProgressBar.value = load_progress[0] * 100

		ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene = ResourceLoader.load_threaded_get(next_scene_path)
			get_tree().change_scene_to_packed(packed_scene)
			is_done = true
			queue_free()  # ✅ Clean up the loading screen

		ResourceLoader.THREAD_LOAD_FAILED:
			$Label.text = "Failed to load: " + next_scene_path
