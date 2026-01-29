extends Node3D

var is_panicking := false
const RUN_SPEED := 6.0  # Vendors don't walk, only run

var player_in_range := false
var talking := false
var should_move := false  # Vendors stay still until panic
var dialogue_index := 0
var last_line_index := -1

# Dialogue pools
var normal_dialogue := [
	"Hi there!",
	"Our products is the best in the area, try some!",
	"Buy One Take One Promo ongoing!",
	"Good morning!",
	"Please try our product, you won't regret it!",
	"How's it going?? Want to try our product?"
]

var panic_dialogue := [
	"Wait, what's that noise?!",
	"We need to get out of here!",
	"What is happening?!",
	"This isn't just a drill—run!",
	"I can't believe this is happening...",
	"Please be safe!"
]

var dialogue_lines = []

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var path_follow := get_parent()
@onready var label_3d := $Label3D
@onready var area := $Area3D

func _ready():
	randomize()
	label_3d.visible = false
	dialogue_lines = normal_dialogue

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	var game_managers = get_tree().get_nodes_in_group("GameManager")
	if game_managers.size() > 0:
		var main_game = game_managers[0]
		if main_game.has_signal("disaster_started"):
			main_game.connect("disaster_started", Callable(self, "_on_disaster_started"))
	else:
		print("⚠️ No node in 'GameManager' group found")

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		label_3d.visible = true
		label_3d.text = "Press [E] to talk"
		should_move = false  # Still, don't move yet (vendor)

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		label_3d.visible = false
		talking = false
		dialogue_index = 0

		if is_panicking:
			should_move = true  # Resume panic running when player leaves

func _on_disaster_started(disaster_type: String):
	print("Vendor is panicking due to:", disaster_type)
	is_panicking = true
	dialogue_lines = panic_dialogue
	dialogue_index = 0
	last_line_index = -1
	should_move = true  # Start moving now (panic run!)

func _physics_process(delta: float) -> void:
	if should_move and not talking:
		# PANIC RUN only
		var speed = RUN_SPEED
		path_follow.progress += speed * delta

		if animation_player.current_animation != "Run":
			animation_player.play("Run")
	else:
		# Vendor is idle before disaster, or during talk
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle")

	# Dialogue input
	if player_in_range and Input.is_action_just_pressed("Interact"):
		_show_dialogue()

func _show_dialogue():
	talking = true

	if dialogue_lines.size() == 0:
		label_3d.text = "..."
		return

	var random_index = randi() % dialogue_lines.size()

	if dialogue_lines.size() > 1:
		while random_index == last_line_index:
			random_index = randi() % dialogue_lines.size()

	last_line_index = random_index
	label_3d.text = dialogue_lines[random_index]
