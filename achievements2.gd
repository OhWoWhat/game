extends Control

# This dictionary maps badge keys to display names (for clarity/logging)
var special_badge_names := {
	"10x_survived": "10x Survived",
	"20x_survived": "20x Survived",
	"30x_survived": "30x Survived",
	"survivor": "Survivor"
}

func _ready():
	if not AchievementManager.achievements_loaded.is_connected(update_special_achievements):
		AchievementManager.achievements_loaded.connect(update_special_achievements)
	AchievementManager.load_data()

func update_special_achievements():
	# ✅ Update the total survival count label
	var survive_label = get_node("TotalSurviveLabel")
	survive_label.text = "Total Times Survived: %d" % AchievementManager.total_survivals

	for badge_key in special_badge_names.keys():
		var node_path = "%sBadge" % badge_key  # Node should be named like "10x_survivedBadge"
		if not has_node(node_path):
			print("⚠️ Missing node for badge:", badge_key)
			continue

		var badge_node: TextureRect = get_node(node_path)
		var is_unlocked: bool = AchievementManager.special_achievements.get(badge_key, false)

		var image_path = "res://images/badges/%s_%s.png" % [
			badge_key,
			"unlocked" if is_unlocked else "locked"
		]

		if ResourceLoader.exists(image_path):
			badge_node.texture = load(image_path)
		else:
			print("❌ Badge image not found:", image_path)

		# Optional: tooltip or label
		badge_node.tooltip_text = "%s Achievement" % special_badge_names[badge_key]

func _on_previous_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/achievements.tscn")
