extends RigidBody3D

@export var damage := 20
var has_hit_ground := false

func _ready():
	if $DamageArea:
		$DamageArea.body_entered.connect(_on_body_entered)
	# Optional: add small random rotation
	apply_impulse(Vector3.ZERO, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 2)

func _on_body_entered(body):
	if has_hit_ground:
		return  # Already landed, don't damage

	if body.is_in_group("player") and body.has_method("take_damage"):
		print("☠️ Player hit by falling debris!")
		body.take_damage(damage)
		# Optional: prevent hitting multiple times
		$DamageArea.set_deferred("monitoring", false)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if has_hit_ground:
		return

	# If vertical speed is very small and it's near the ground, it's landed
	if abs(linear_velocity.y) < 0.5 and state.get_contact_count() > 0:
		has_hit_ground = true
		print("🧱 Debris landed.")

		# Make it harmless
		$DamageArea.set_deferred("monitoring", false)

		# ✅ Freeze the debris in place so it stops rolling or sliding
		freeze = true
