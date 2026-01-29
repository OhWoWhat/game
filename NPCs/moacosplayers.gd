extends Node3D

var is_panicking := false
const WALK_SPEED := 2.0
const RUN_SPEED := 6.0

var player_in_range := false
var talking := false
var should_move := true
var dialogue_index := 0

#NEW: Separate dialogue pools
var normal_dialogue := [
	"Hi there!",
	"How's my Costume?",
	"It's been a tiring day, but it is fun!",
	"Cosplaying is such a fun hobby!",
	"Good morning!",
	"How's it going?",
	"Enjoy your visit here!"
]

var panic_dialogue := [
	"Wait, what's that noise?!",
	"We need to get out of here!",
	"What is happening?!",
	"This isn't just a drill—run!",
	"I can't believe this is happening...",
	"Please be safe!"
]

var dialogue_lines = []  # Will point to normal or panic dialogue

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var path_follow := get_parent()
@onready var label_3d := $Label3D
@onready var area := $Area3D

func _ready():
	randomize()  # 🔁 Initialize RNG for randi()

	label_3d.visible = false
	dialogue_lines = normal_dialogue  # Start with normal lines

	# Connect proximity detection
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	# Connect to disaster signal
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
		should_move = false  # NPC stops moving when player enters

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		label_3d.visible = false
		talking = false
		dialogue_index = 0
		should_move = true  # Resume movement when player leaves

func _on_disaster_started(disaster_type: String):
	print("NPC heard about the disaster:", disaster_type)
	is_panicking = true
	dialogue_lines = panic_dialogue
	dialogue_index = 0  # Reset just in case
	last_line_index = -1  # Optional: reset randomness

func _physics_process(delta: float) -> void:
	if should_move and not talking:
		var speed = RUN_SPEED if is_panicking else WALK_SPEED
		path_follow.progress += speed * delta

		var anim = "Run" if is_panicking else "Walk"
		if animation_player.current_animation != anim:
			animation_player.play(anim)
	else:
		# NPC is not moving or is talking — play Idle animation
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle")

	# Dialogue input
	if player_in_range and Input.is_action_just_pressed("Interact"):
		_show_dialogue()

var last_line_index := -1  # Add this near your other variables at the top

func _show_dialogue():
	talking = true

	if dialogue_lines.size() == 0:
		label_3d.text = "..."
		return

	var random_index = randi() % dialogue_lines.size()

	# Avoid showing the same line twice in a row
	if dialogue_lines.size() > 1:
		while random_index == last_line_index:
			random_index = randi() % dialogue_lines.size()

	last_line_index = random_index
	label_3d.text = dialogue_lines[random_index]
