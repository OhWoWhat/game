extends HSlider

@export var audio_bus_name: String
var audio_bus_id: int

func _ready():
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	value = db_to_linear(AudioServer.get_bus_volume_db(audio_bus_id))  # sync slider value

func _on_value_changed(value: float):
	var volume_db = linear_to_db(value)
	AudioServer.set_bus_volume_db(audio_bus_id, volume_db)

	if audio_bus_name == "Music":
		AudioManager.music_volume_db = volume_db
	elif audio_bus_name == "SFX":
		AudioManager.sfx_volume_db = volume_db
