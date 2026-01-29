extends StaticBody3D

@export var explosion_damage: int = 20
@export var explode_after: float = 10.0
@export var auto_trigger: bool = false

@onready var explosion_area: Area3D = $ExplosionArea
@onready var explosion_sound: AudioStreamPlayer3D = $ExplosionSound
@onready var sparks: GPUParticles3D = $Sparks
@onready var timer: Timer = $ExplosionTimer

func _ready():
	if auto_trigger:
		if not timer.timeout.is_connected(_on_explode):
			timer.timeout.connect(_on_explode)
		timer.wait_time = explode_after
		timer.start()

func _on_explode():
	print("⚡ Boom! Streetlight exploded.")

	# 🔊 Play explosion sound
	if explosion_sound:
		explosion_sound.play()

	# ✨ Emit sparks
	if sparks:
		sparks.emitting = true

	# ☠️ Damage nearby players/objects
	if explosion_area:
		# Force update to avoid stale overlaps (Godot quirk)
		explosion_area.force_update_transform()
		await get_tree().process_frame  # Wait one frame to ensure overlaps update

		for body in explosion_area.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				print("🔥 Damaging:", body.name)
				body.take_damage(explosion_damage)
