extends Control

signal restart_battle
signal quit_to_menu
signal continue_battle

func _ready():
	# Ensure Background fills the entire screen
	$Background.anchors_preset = Control.PRESET_FULL_RECT
	$Background.offset_left = 0
	$Background.offset_top = 0
	$Background.offset_right = 0
	$Background.offset_bottom = 0
	
	# Animate the ResultPanel appearing
	$ResultPanel.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property($ResultPanel, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Hide continue button by default
	$ResultPanel/VBoxContainer/ButtonContainer/ContinueButton.visible = false

func set_result(result, _dungeon_num: int = 1, _stage_num: int = 1, exp_reward: int = 0, enemy_name: String = ""):
	if result == "Victory":
		$ResultPanel/VBoxContainer/ResultLabel.text = "Victory!"
		var message = ""
		if enemy_name != "":
			message = "You defeated " + enemy_name + "!"
		else:
			message = "You defeated the enemy!"
		
		if exp_reward > 0:
			message += " You gained " + str(exp_reward) + " EXP!"
		$ResultPanel/VBoxContainer/MessageLabel.text = message
		$ResultPanel/VBoxContainer/ResultLabel.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	else:
		$ResultPanel/VBoxContainer/ResultLabel.text = "Defeat"
		var message = ""
		if enemy_name != "":
			message = "You were defeated by " + enemy_name + ". You did not gain a reward."
		else:
			message = "You were defeated by the enemy. You did not gain a reward."
		$ResultPanel/VBoxContainer/MessageLabel.text = message
		$ResultPanel/VBoxContainer/ResultLabel.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))

# Missing function that was causing the crash - now implemented
func setup_endgame(result_type: String, dungeon_num: int = 1, stage_num: int = 1, exp_reward: int = 0, enemy_name: String = ""):
	print("EndgameScreen: Setting up endgame with result: " + result_type)
	set_result(result_type, dungeon_num, stage_num, exp_reward, enemy_name)
	
	# For victory, enable continue button if there are more stages
	if result_type == "Victory":
		# Check if this is the last stage (stage 5) or if there are more stages
		# For now, always show continue button for victory - the battle manager can handle logic
		set_continue_enabled(true)
	else:
		# For defeat, hide continue button
		set_continue_enabled(false)

# New function to enable/disable the continue button
func set_continue_enabled(enabled):
	$ResultPanel/VBoxContainer/ButtonContainer/ContinueButton.visible = enabled
	if enabled:
		# The message is already set by set_result, just show continue question
		var current_text = $ResultPanel/VBoxContainer/MessageLabel.text
		$ResultPanel/VBoxContainer/MessageLabel.text = current_text + " Continue to the next stage?"

func _on_restart_button_pressed():
	var tween = create_tween()
	tween.tween_property($ResultPanel, "scale", Vector2(0.5, 0.5), 0.2)
	tween.tween_property($ResultPanel, "modulate", Color(1, 1, 1, 0), 0.1)
	await tween.finished
	restart_battle.emit()
	queue_free()

func _on_quit_button_pressed():
	var tween = create_tween()
	tween.tween_property($ResultPanel, "scale", Vector2(0.5, 0.5), 0.2)
	tween.tween_property($ResultPanel, "modulate", Color(1, 1, 1, 0), 0.1)
	await tween.finished
	quit_to_menu.emit()
	queue_free()

func _on_continue_button_pressed():
	var tween = create_tween()
	tween.tween_property($ResultPanel, "scale", Vector2(0.5, 0.5), 0.2)
	tween.tween_property($ResultPanel, "modulate", Color(1, 1, 1, 0), 0.1)
	await tween.finished
	continue_battle.emit()
	queue_free()
