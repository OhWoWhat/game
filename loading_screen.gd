extends Control

@export var next_scene_path: String

var loader
var load_progress := [0.0]
var is_done := false
var waiting_for_input := false

# Tips
var tips = [
	"The Philippines is part of the Pacific Ring of Fire, making it highly earthquake-prone.",
	"On average, the Philippines experiences 20 to 25 earthquakes per day, though most are too weak to be felt.",
	"1990 Luzon Earthquake (Magnitude 7.7): Caused massive destruction in Baguio, Cabanatuan, and Dagupan, Over 1,600 deaths",
	"2013 Bohol Earthquake (Magnitude 7.2): Damaged historical churches and killed over 200 people, Triggered landslides and ground ruptures",
	"The country is hit by an average of 20 typhoons annually, with around 5–8 being destructive.",
	"The Philippine Atmospheric, Geophysical and Astronomical Services Administration (PAGASA) monitors storms within the PAR (Philippine Area of Responsibility)",
	"Typhoon Yolanda (Haiyan) – 2013: One of the strongest typhoons in recorded history, Winds over 300 km/h, Over 6,000 fatalities and massive storm surge in Tacloban",
	"Typhoon Ondoy (Ketsana) – 2009: Caused record-breaking floods in Metro Manila, Over 80% of the city submerged in some areas",
	"There are 24 active volcanoes in the Philippines, The country is known for explosive eruptions due to highly viscous magma.",
	"Mount Pinatubo – 1991: One of the largest eruptions of the 20th century, Ash cloud reached the stratosphere, Caused global temperature drop of ~0.5°C",
	"Mayon Volcano – Active with frequent eruptions, Famous for its perfect cone shape, Last major eruption: 2018",
	"Tsunamis in the Philippines are typically triggered by underwater earthquakes or volcanic activity.",
	"Coastal provinces are particularly at risk due to many offshore trenches and subduction zones.",
	"1976 Moro Gulf Tsunami: Caused by a magnitude 8.1 earthquake, Tsunami waves reached up to 9 meters high, Over 8,000 deaths – one of the deadliest natural disasters in Philippine history",
	"Raincoat: used to negate damage from flying debris for each raincoat obtained.",
	"N-95 Facemask: used to prevent damage from ashfall.",
	"Med-Kit: used to recover 20 health.",
]

var tip_index := 0
var tip_timer := 0.0
const TIP_INTERVAL := 6.0

func _ready():
	randomize()
	loader = ResourceLoader.load_threaded_request(next_scene_path)
	$Label.text = "Loading..."
	$TipLabel.text = tips[tip_index]
	$ContinueLabel.visible = false
	set_process(true)

func _process(delta):
	# Always update tip
	tip_timer += delta
	if tip_timer >= TIP_INTERVAL:
		tip_timer = 0
		var new_index = randi() % tips.size()
		# Make sure it's not the same as the last tip
		while new_index == tip_index and tips.size() > 1:
			new_index = randi() % tips.size()

		tip_index = new_index
		$TipLabel.text = tips[tip_index]

	# Skip loading logic if already done
	if is_done:
		return

	# Handle loading progress
	var status = ResourceLoader.load_threaded_get_status(next_scene_path, load_progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			$ProgressBar.value = load_progress[0] * 100

		ResourceLoader.THREAD_LOAD_LOADED:
			is_done = true
			waiting_for_input = true
			$ProgressBar.value = 100
			$Label.text = "Loading complete!"
			$ContinueLabel.visible = true
			set_process_input(true)

		ResourceLoader.THREAD_LOAD_FAILED:
			$Label.text = "Failed to load: " + next_scene_path

func _input(event):
	if waiting_for_input and (
		event is InputEventKey or
		event is InputEventMouseButton or
		event is InputEventJoypadButton
	):
		continue_to_game()

func continue_to_game():
	var packed_scene = ResourceLoader.load_threaded_get(next_scene_path)
	get_tree().change_scene_to_packed(packed_scene)
	queue_free()
