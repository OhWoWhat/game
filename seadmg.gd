extends Area3D

@export var damage_interval := 1.0  # seconds between damage ticks
@export var damage_amount := 10.0   # damage per tick
var players_in_area := []

var damage_timer := 0.0

func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		players_in_area.append(body)
		body.underwater_overlay.visible = true  # Access directly

func _on_body_exited(body):
	if body.is_in_group("player"):
		players_in_area.erase(body)
		body.underwater_overlay.visible = false

func _physics_process(delta):
	if players_in_area.is_empty():
		damage_timer = 0.0
		return

	damage_timer += delta
	if damage_timer >= damage_interval:
		for player in players_in_area:
			if player.has_method("take_damage"):
				player.take_damage(damage_amount)
		damage_timer = 0.0
