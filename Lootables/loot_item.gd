extends Area3D

@export var item_id: String = ""
@export var rotation_speed: float = 60.0   # degrees per second
@export var bobbing_height: float = 0.3    # how high it moves up and down
@export var bobbing_speed: float = 2.0     # how fast it bobs

signal picked_up(item_id: String)

var can_pickup := false
var base_y: float

func _ready():
	# Save starting GLOBAL Y position (respects spawn point)
	base_y = global_transform.origin.y

	# Delay enabling pickup to avoid triggering instantly
	await get_tree().create_timer(0.5).timeout
	can_pickup = true
	connect("body_entered", _on_body_entered)

func _process(delta: float) -> void:
	# 🔁 Rotate smoothly
	rotation_degrees.y += rotation_speed * delta

	# ⬆⬇ Bobbing relative to global spawn height
	var bob_offset = sin(Time.get_ticks_msec() / 1000.0 * bobbing_speed) * bobbing_height
	var pos = global_transform.origin
	pos.y = base_y + bob_offset
	global_transform.origin = pos

func _on_body_entered(body):
	if not can_pickup:
		return
	if body.is_in_group("player"):
		emit_signal("picked_up", item_id)
		queue_free()
