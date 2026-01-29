extends ColorRect

func _process(delta):
	if material:
		material.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
