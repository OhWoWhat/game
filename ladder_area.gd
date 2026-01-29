extends Area3D

func _ready():
	print("👀 Ladder Area ready:", name)
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body):
	if body.is_in_group("player"):  # safer check
		print("✅ Ladder body entered:", body.name)
		if body.has_method("start_climbing"):
			body.start_climbing(global_transform.basis.y)  # ladder's up direction
		else:
			print("❌ Player missing start_climbing method")

func _on_body_exited(body):
	if body.is_in_group("player"):
		print("⬅️ Ladder body exited:", body.name)
		if body.has_method("stop_climbing"):
			body.stop_climbing()
		else:
			print("❌ Player missing stop_climbing method")
