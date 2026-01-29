extends Node3D

signal disaster_started(disaster_type: String)

var difficulty_level: String = "Normal"

@onready var sky_fade: ColorRect = $Transition/ColorRect
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var bgm: AudioStreamPlayer = $Sounds/BGM
@onready var disaster_bgm: AudioStreamPlayer = $Sounds/NaturalDisasterBGM
@onready var animation_player = $CutsceneCamera/Camera3D/AnimationPlayer
@onready var cutscene_camera = $CutsceneCamera/Camera3D
@onready var player_camera = $Player/camera_mount/Camera3D
@onready var rain_audio: AudioStreamPlayer = $Sounds/RainAudio
@onready var earthquake_audio: AudioStreamPlayer = $Sounds/EarthquakeAudio
@onready var rain_particles: GPUParticles3D = $RainParticles
@onready var minimap_ui: CanvasLayer = $Map
@export var current_map_name: String = "MoaScene"
@onready var looting_timer_bar: ProgressBar = $CanvasLayer/LootingTimerBar
@onready var survival_timer_label: Label = $CanvasLayer/SurvivalTimerLabel
@onready var player_spawn_point: Marker3D = $PlayerSpawnPoint
@onready var alarm_sound: AudioStreamPlayer = $Sounds/AlarmSound
@onready var health: CanvasLayer = $Health
@onready var input_outline_rectangle: Sprite2D = $CanvasLayer/InputOutlineRectangle

var player

var character_scenes := [
	preload("res://scenes/Timmy.tscn"),
	preload("res://scenes/Amy.tscn"),
	preload("res://scenes/Michelle.tscn")
]

var loot_defs := {
	"med_kit": preload("res://resources/Lootables/FinalLootables/med_kit.tscn"),
	"n_95_mask": preload("res://resources/Lootables/FinalLootables/n_95_mask.tscn"),
	"raincoat": preload("res://resources/Lootables/FinalLootables/raincoat.tscn")
}
var falling_debris_scene := preload("res://DisastersAssets/Final/FallingDebris.tscn")

var current_disaster: String = ""

var debris_scene := preload("res://DisastersAssets/Final/FlyingDebris.tscn")
var debris_gust_timer := Timer.new()

var min_loot_spawn := 3
var max_loot_spawn := 6
var looting_time_left: float = 60.0
var looting_timer: Timer
var looting_phase_active: bool = false

var survival_timer: Timer
var survival_time_left: float = 60.0
var survived: bool = false

var clear_sky := preload("res://resources/sky texture/clear_sky.tres")
var typhoon_sky := preload("res://resources/sky texture/typhoon_sky.tres")
var eruption_sky := preload("res://resources/sky texture/eruption_sky.tres")

func _ready():
	# Remove placeholder if it exists
	var old_player = get_node_or_null("Player")
	if old_player:
		old_player.queue_free()

	# Instantiate selected character
	var selected_scene = character_scenes[Global.selected_character_index]
	player = selected_scene.instantiate()
	player.name = "Player"
	add_child(player)

	if player_spawn_point:
		player.global_transform.origin = player_spawn_point.global_transform.origin
		
		player_camera = player.get_node("camera_mount/Camera3D")
		player_camera.current = true
		var minimap_camera = $Map/PanelContainer/SubViewportContainer/SubViewport/Camera3D
		if minimap_camera:
			minimap_camera.player = player
		player.add_to_group("player")
		for ladder in get_tree().get_nodes_in_group("ladders"):
			print("🪜 Total ladders detected:", get_tree().get_nodes_in_group("ladders").size())
			var area = ladder.get_node_or_null("Area3D")
			if area and player:
				if not area.is_connected("body_entered", Callable(player, "_on_ladder_area_body_entered")):
					area.body_entered.connect(Callable(player, "_on_ladder_area_body_entered"))
				if not area.is_connected("body_exited", Callable(player, "_on_ladder_area_body_exited")):
					area.body_exited.connect(Callable(player, "_on_ladder_area_body_exited"))
		AchievementManager.load_data()
	difficulty_level = Global.selected_difficulty
	apply_difficulty_settings()

	# Create the survival timer
	survival_timer = Timer.new()
	survival_timer.name = "survival_timer"
	survival_timer.wait_time = 1.0
	survival_timer.autostart = false
	survival_timer.one_shot = false
	input_outline_rectangle.visible = false
	survival_timer_label.visible = false
	survival_timer.timeout.connect(_on_survival_timer_tick)
	add_child(survival_timer)

	AudioManager.apply_volumes()
	randomize()
	minimap_ui.visible = false
	looting_timer_bar.visible = false
	health.visible = false
	
	player.set_process_input(false)
	player.set_physics_process(false)

	cutscene_camera.current = true
	animation_player.play("Cutscene")

	animation_player.animation_finished.connect(_on_cutscene_finished)
	
var flying_debris_spawn_min = 4.0
var flying_debris_spawn_max = 10.0

var falling_debris_spawn_min = 1.0
var falling_debris_spawn_max = 3.0

func apply_difficulty_settings():
	match difficulty_level:
		"Easy":
			survival_time_left = 45.0
			looting_time_left = 60.0
			min_loot_spawn = 6
			max_loot_spawn = 8
			player.damage_multiplier = 0.5

			flying_debris_spawn_min = 6.0
			flying_debris_spawn_max = 12.0

			falling_debris_spawn_min = 2.0
			falling_debris_spawn_max = 4.0

		"Normal":
			survival_time_left = 60.0
			looting_time_left = 45.0
			min_loot_spawn = 4
			max_loot_spawn = 6
			player.damage_multiplier = 1.0

			flying_debris_spawn_min = 4.0
			flying_debris_spawn_max = 10.0

			falling_debris_spawn_min = 1.0
			falling_debris_spawn_max = 3.0

		"Hard":
			survival_time_left = 75.0
			looting_time_left = 30.0
			min_loot_spawn = 2
			max_loot_spawn = 4
			player.damage_multiplier = 1.2

			flying_debris_spawn_min = 2.0
			flying_debris_spawn_max = 6.0

			falling_debris_spawn_min = 0.5
			falling_debris_spawn_max = 2.0

func _on_cutscene_finished(anim_name: StringName):
	minimap_ui.visible = true
	health.visible = true
	if anim_name == "Cutscene":
		player.set_process_input(true)
		player.set_physics_process(true)

		player_camera.current = true
		cutscene_camera.current = false

		start_looting_phase()

func start_disaster_sequence():
	print("⏳ Looting phase over. Preparing disaster...")

	await get_tree().create_timer(2.0).timeout  # Small break

	if current_disaster == "":
		var disasters = ["typhoon", "earthquake", "tsunami"]
		current_disaster = disasters[randi() % disasters.size()]

	print("Disaster chosen: ", current_disaster)

	match current_disaster:
		"typhoon":
			await show_alert("🌪️ Typhoon imminent! Watch out for flying debris!")
			start_typhoon()
		"earthquake":
			await show_alert("🌍 Earthquake approaching! Watch out for falling debris!")
			start_earthquake()
		"tsunami":
			await show_alert("🌊 Tsunami incoming! Move to higher ground!")
			start_tsunami()

func start_looting_phase():
	print("🛍️ Looting phase started!")
	looting_phase_active = true

	show_alert("Look around the map for Medkits, Raincoats and Face masks before the disaster!", 30.0)
	spawn_loot()

	# 🔁 Hide survival label, show looting bar
	survival_timer_label.visible = false
	looting_timer_bar.visible = true

	# Setup looting bar
	looting_timer_bar.max_value = looting_time_left
	looting_timer_bar.value = looting_time_left

	# Create and start looting timer
	looting_timer = Timer.new()
	looting_timer.name = "LootingTimer"
	looting_timer.wait_time = 1.0
	looting_timer.one_shot = false
	looting_timer.timeout.connect(_on_looting_timer_tick)
	add_child(looting_timer)
	looting_timer.start()

func _on_looting_timer_tick():
	if looting_time_left <= 0:
		looting_timer.stop()
		looting_phase_active = false
		looting_timer_bar.visible = false
		start_disaster_sequence()
		return

	looting_time_left -= 1
	looting_timer_bar.value = looting_time_left

func switch_to_disaster_bgm():
	if bgm and bgm.playing:
		var tween = create_tween()
		tween.tween_property(bgm, "volume_db", 0, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		bgm.stop()

	if disaster_bgm:
		disaster_bgm.volume_db = 0
		disaster_bgm.play()
		var fade_in = create_tween()
		fade_in.tween_property(disaster_bgm, "volume_db", 0, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func start_typhoon():
	print("Typhoon started!")
	emit_signal("disaster_started", "typhoon")
	switch_to_disaster_bgm()
	alarm_sound.play()
	# 🌌 Change the sky to typhoon version
	if world_environment and world_environment.environment:
		await transition_sky(typhoon_sky)

	# 🌧️ Start rain
	if rain_audio:
		rain_audio.volume_db = -80
		rain_audio.play()
		var tween = create_tween()
		tween.tween_property(rain_audio, "volume_db", 0, 8.0)

	if rain_particles:
		rain_particles.emitting = true
		rain_particles.amount = 1
		var particle_tween = create_tween()
		particle_tween.tween_property(rain_particles, "amount", 200000, 3)
	begin_survival_timer()
	spawn_loot()
	start_debris_gusts()
	var flood = $Flood
	if flood:
		flood.visible = true
		var anim = flood.get_node("FloodAnimation")
		if anim:
			anim.play("Flood")  # ⬅️ Replace with your animation name

func start_debris_gusts():
	# Avoid reconnecting the signal or re-adding the timer if it's already set up
	if not debris_gust_timer.is_connected("timeout", Callable(self, "_on_debris_gust_timer_timeout")):
		debris_gust_timer.timeout.connect(_on_debris_gust_timer_timeout)

	if debris_gust_timer.get_parent() == null:
		add_child(debris_gust_timer)

	debris_gust_timer.name = "DebrisGustTimer"
	debris_gust_timer.wait_time = randf_range(flying_debris_spawn_min, flying_debris_spawn_max)
	debris_gust_timer.one_shot = false
	debris_gust_timer.start()

func begin_survival_timer():
	survived = false
	survival_timer_label.text = "Survive the disaster for: " + str(round(survival_time_left)) + "!"
	survival_timer_label.visible = true
	survival_timer.start()

func spawn_flying_debris():
	var debris_instance = debris_scene.instantiate()
	add_child(debris_instance)

	# Spawn relative to player
	var offset = Vector3(randf_range(-30, 0), 0, randf_range(0, 0))
	debris_instance.global_transform.origin = player.global_transform.origin + offset

	# Damage check after 1 second
	await get_tree().create_timer(1.0).timeout

	if not player.is_crouching:
		if player.has_method("has_in_inventory") and player.has_in_inventory("raincoat"):
			print("🧥 Raincoat protected the player from debris! -1 raincoat")
			player.inventory["raincoat"] -= 1
			if player.inventory["raincoat"] < 0:
				player.inventory["raincoat"] = 0
			if player.has_method("update_inventory_ui"):
				player.update_inventory_ui()
		else:
			player.take_damage(20)

	var anim_player = debris_instance.get_node_or_null("Debris/AnimationPlayer")
	if anim_player:
		anim_player.play("flyingtwigs")
	else:
		print("❌ AnimationPlayer not found in FlyingDebris instance")

	await get_tree().create_timer(4.0).timeout
	debris_instance.queue_free()

func _on_debris_gust_timer_timeout():
	spawn_flying_debris()
	# Set a new random wait time and restart the timer
	debris_gust_timer.stop()
	debris_gust_timer.wait_time = randf_range(flying_debris_spawn_min, flying_debris_spawn_max)
	debris_gust_timer.start()

func start_earthquake():
	print("Earthquake started!")
	emit_signal("disaster_started", "earthquake")
	switch_to_disaster_bgm()
	alarm_sound.play()
	if earthquake_audio:
		earthquake_audio.volume_db = -80
		earthquake_audio.play()
		var tween = create_tween()
		tween.tween_property(earthquake_audio, "volume_db", 0, 8.0)

	if player.has_method("start_earthquake"):
		player.start_earthquake(60, 0.2)
	begin_survival_timer()
	spawn_loot()
	make_trees_fall()
	
	var poles = get_tree().get_nodes_in_group("light_poles")
	for pole in poles:
		if randi() % 100 < 80:
			pole.auto_trigger = true
			pole.explode_after = randf_range(10.0, 50.0)
			pole._ready()
	# Start falling debris loop
	var falling_debris_timer := Timer.new()
	falling_debris_timer.name = "FallingDebrisTimer"
	falling_debris_timer.wait_time = randf_range(falling_debris_spawn_min, falling_debris_spawn_max)
	falling_debris_timer.one_shot = false
	falling_debris_timer.timeout.connect(_on_falling_debris_timer_timeout)
	add_child(falling_debris_timer)
	falling_debris_timer.start()

func spawn_falling_debris():
	var debris_instance = falling_debris_scene.instantiate()
	add_child(debris_instance)

	# Spawn high above the player, or random area around
	var offset = Vector3(randf_range(-15, 15), 20, randf_range(-15, 15))
	debris_instance.global_transform.origin = player.global_transform.origin + offset

func _on_falling_debris_timer_timeout():
	spawn_falling_debris()

	# Reschedule the next debris fall
	var timer = get_node_or_null("FallingDebrisTimer")
	if timer:
		timer.wait_time = randf_range(falling_debris_spawn_min, falling_debris_spawn_max)
		timer.start()

func make_trees_fall():
	var tree_containers = get_tree().get_nodes_in_group("trees") # parent node(s)
	for container in tree_containers:
		for tree in container.get_children():
			# Only rotate if the child is a Node3D
			if tree is Node3D:
				# Random delay so they don't all fall at once
				await get_tree().create_timer(randf_range(0.0, 1.0)).timeout

				# Random fall direction
				var fall_axis = Vector3(1, 0, 0) if randf() > 0.5 else Vector3(0, 0, 1)

				# Rotate by 90 degrees
				var target_rotation = tree.rotation_degrees + fall_axis * 70.0

				# Tween it
				var tween = create_tween()
				tween.tween_property(tree, "rotation_degrees", target_rotation, 2.0)\
					.set_trans(Tween.TRANS_SINE)\
					.set_ease(Tween.EASE_IN_OUT)

func transition_sky(new_sky: Sky) -> void:
	if not world_environment or not world_environment.environment:
		return

	var tween = create_tween()

	# Fade in (to black)
	tween.tween_property(sky_fade, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	# Change sky
	world_environment.environment.set_sky(new_sky)

	# Fade back out (to transparent)
	tween = create_tween()
	tween.tween_property(sky_fade, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func start_tsunami():
	print("Tsunami started!")
	emit_signal("disaster_started", "tsunami")
	switch_to_disaster_bgm()
	
	minimap_ui.visible = false


	# 🎥 Switch to tsunami camera
	var tsunami_camera: Camera3D = $Nature/Sea/Camera3D
	if tsunami_camera:
		tsunami_camera.current = true
	player_camera.current = false

	# 🎬 Play tsunami wave animation
	var wave_animation: AnimationPlayer = $Nature/Sea/Camera3D/Wave/TsunamiWaveAnimation
	if wave_animation and not wave_animation.is_playing():
		wave_animation.play("Tsunami")

	# 🎬 Play tsunami camera animation
	var camera_animation: AnimationPlayer = $Nature/Sea/Camera3D/CutsceneCamera
	if camera_animation and not camera_animation.is_playing():
		camera_animation.play("TsunamiCamera") # 🔁 Replace with actual animation name
	
	# ⏳ Wait until wave animation finishes
	await wave_animation.animation_finished
	# 🎮 Restore player control
	player_camera.current = true
	tsunami_camera.current = false
	minimap_ui.visible = true
	
	print("Tsunami wave finished. Waiting 10 seconds...")
	await get_tree().create_timer(10.0).timeout

	# 🌊 Play sea level rise animation
	var sea_rising_anim: AnimationPlayer = $Nature/Sea/SeaRising
	if sea_rising_anim:
		sea_rising_anim.play("SeaRising") # 🔁 Replace with actual animation name
	begin_survival_timer()
	spawn_loot()
	alarm_sound.play()
	# 🌩 Randomly trigger streetlight explosions
	var poles = get_tree().get_nodes_in_group("light_poles")
	for pole in poles:
		if randi() % 100 < 50:
			pole.auto_trigger = true
			pole.explode_after = randf_range(20.0, 50.0)
			pole._ready()

func show_alert(message: String, duration: float = 5.0):
	var alert_label = $CanvasLayer/AlertLabel
	alert_label.text = message
	alert_label.visible = true
	input_outline_rectangle.visible = true

	var tween = create_tween()
	tween.tween_property(alert_label, "modulate:a", 1.0, 0.5)  # fade in
	await get_tree().create_timer(duration).timeout
	tween = create_tween()
	tween.tween_property(alert_label, "modulate:a", 0.0, 1.0)  # fade out
	await tween.finished
	alert_label.visible = false
	input_outline_rectangle.visible = false

func spawn_loot():
	clear_spawned_loot()
	var loot_ids = loot_defs.keys()
	var spawn_points = get_tree().get_nodes_in_group("loot_spawn")

	if spawn_points.is_empty():
		print("⚠️ No loot spawn points found!")
		return

	# Shuffle the spawn points
	spawn_points.shuffle()

	# Pick how many items to spawn based on difficulty
	var spawn_count = randi_range(min_loot_spawn, max_loot_spawn)
	spawn_count = clamp(spawn_count, 0, spawn_points.size())

	# Select only a portion of the spawn points
	var selected_points = spawn_points.slice(0, spawn_count)

	for spawn_point in selected_points:
		var item_id = loot_ids[randi() % loot_ids.size()]
		var loot_scene = loot_defs[item_id]
		var loot = loot_scene.instantiate()
		loot.item_id = item_id
		loot.connect("picked_up", self._on_loot_picked_up)
		loot.add_to_group("spawned_loot")

		# ✅ Apply the spawn point’s global transform before parenting
		loot.global_transform = spawn_point.global_transform

		add_child(loot)

func clear_spawned_loot():
	for loot in get_tree().get_nodes_in_group("spawned_loot"):
		loot.queue_free()

func _on_loot_picked_up(item_id: String):
	player.add_to_inventory(item_id)

func _physics_process(delta: float) -> void:
	pass
	
func _on_survival_timer_tick():
	if not player.is_alive:
		survival_timer.stop()
		return

	survival_time_left -= 1.0
	survival_timer_label.text = "Survive the disaster for: " + str(round(survival_time_left)) + "!"

	if survival_time_left <= 0.0:
		survival_timer.stop()
		handle_survival_success()

func handle_survival_success():
	survived = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var popup = $CanvasLayer/AchievementPopup
	popup.visible = true

	var message = "You survived the " + AchievementManager.get_disaster_display_name(current_disaster) + "!"
	popup.get_node("Label").text = message

	# 💯 Calculate score
	var score: int = player.current_health
	popup.get_node("ScoreLabel").text = "Score: " + str(score)

	# 🧠 Check for high score
	var is_new_high_score := ScoreManager.save_score(current_map_name, score)

	var high_score_label = popup.get_node("HighScoreLabel")
	if is_new_high_score:
		high_score_label.text = "🎉 New High Score!"
		high_score_label.visible = true
	else:
		high_score_label.visible = false

	# 🎯 Save the achievement
	AchievementManager.mark_survived(current_map_name, current_disaster)

func _on_retry_pressed() -> void:
	clear_spawned_loot()
	$CanvasLayer/AchievementPopup.visible = false
	$CanvasLayer/RetryScreen.visible = false

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# ✅ Reset player
	player.current_health = player.max_health
	player.is_alive = true
	player.is_locked = false
	player.health_bar.value = player.current_health

	# ✅ Reset position
	player.global_transform.origin = Vector3(-1249.36, 0.1, -80.543)

	# ✅ Reset audio and effects
	rain_particles.emitting = false
	rain_audio.stop()
	earthquake_audio.stop()
	disaster_bgm.stop()

	# ✅ Reset camera
	player_camera.current = true
	cutscene_camera.current = false
	
	survival_timer.stop()
	apply_difficulty_settings()  # Reapply difficulty-based settings

	var debris_timer = get_node_or_null("FallingDebrisTimer")

	if current_disaster == "tsunami":
		var sea_rising_anim: AnimationPlayer = $Nature/Sea/SeaRising
		if sea_rising_anim:
			sea_rising_anim.stop()
			sea_rising_anim.seek(0.0, true)
		start_tsunami()
		return

	# ✅ Restart current disaster
	match current_disaster:
		"typhoon":
			start_typhoon()
		"earthquake":
			start_earthquake()

func _on_return_to_menu_button_pressed() -> void:
	Global.play_count += 1
	print("📊 Total plays:", Global.play_count)

	# Only trigger rating popup on the 5th playthrough
	if Global.play_count == 5 and not Global.rating_shown:
		Global.show_rate_popup = true
		Global.rating_shown = true
		print("⭐ Rating popup will be shown in main menu")

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
