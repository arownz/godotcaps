extends Control

signal stats_updated

# Stat values
var enemy_health = 100
var enemy_damage = 10
var player_health = 100
var player_damage = 15
var battle_speed = 1.5
var show_skill_label = false  # New variable for skill label visibility

func _ready():
	# Initialize the UI with current values
	_update_labels()

func _update_labels():
	# Update enemy stat labels
	$Panel/MarginContainer/VBoxContainer/EnemySection/EnemyHealthLabel.text = "Health: " + str(enemy_health)
	$Panel/MarginContainer/VBoxContainer/EnemySection/EnemyDamageLabel.text = "Damage: " + str(enemy_damage)
	
	# Update player stat labels
	$Panel/MarginContainer/VBoxContainer/PlayerSection/PlayerHealthLabel.text = "Health: " + str(player_health)
	$Panel/MarginContainer/VBoxContainer/PlayerSection/PlayerDamageLabel.text = "Damage: " + str(player_damage)
	
	# Update speed label
	$Panel/MarginContainer/VBoxContainer/AutoBattleSection/SpeedLabel.text = "Speed: " + str(battle_speed) + "s"
	
	# Update skill label toggle
	$Panel/MarginContainer/VBoxContainer/SkillLabelSection/SkillLabelToggle.button_pressed = show_skill_label

# Getters for the battlescene script
func get_enemy_health():
	return enemy_health

func get_enemy_damage():
	return enemy_damage

func get_player_health():
	return player_health

func get_player_damage():
	return player_damage

func get_battle_speed():
	return battle_speed

func get_show_skill_label():
	return show_skill_label

# Slider value change handlers
func _on_enemy_health_slider_value_changed(value):
	enemy_health = int(value)
	_update_labels()

func _on_enemy_damage_slider_value_changed(value):
	enemy_damage = int(value)
	_update_labels()

func _on_player_health_slider_value_changed(value):
	player_health = int(value)
	_update_labels()

func _on_player_damage_slider_value_changed(value):
	player_damage = int(value)
	_update_labels()

func _on_speed_slider_value_changed(value):
	battle_speed = value
	_update_labels()

func _on_skill_label_toggle_toggled(button_pressed):
	show_skill_label = button_pressed
	_update_labels()

func _on_apply_button_pressed():
	# Emit signal to notify battlescene
	stats_updated.emit()
	
	# Access the parent (BattleScene) and update its auto_battle_speed
	if get_parent() is Node:
		var parent = get_parent()
		
		# Call the stats update method if it exists
		if parent.has_method("_on_stats_updated"):
			parent._on_stats_updated()
			
		# Update the battle speed specifically if the property exists
		if "auto_battle_timer" in parent and parent.auto_battle_timer is Timer:
			parent.auto_battle_speed = battle_speed
			parent.auto_battle_timer.wait_time = battle_speed
			
		# Update skill label visibility
		if "BattleContainer" in parent and parent.has_node("BattleContainer/EnemyContainer/EnemySkillLabel"):
			parent.get_node("BattleContainer/EnemyContainer/EnemySkillLabel").visible = show_skill_label
