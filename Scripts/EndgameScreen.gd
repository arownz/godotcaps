extends Control

signal restart_battle
signal quit_to_menu

func _ready():
	# Center the panel
	$ResultPanel.position = Vector2(
		(get_viewport_rect().size.x - $ResultPanel.size.x) / 2,
		(get_viewport_rect().size.y - $ResultPanel.size.y) / 2
	)
	
	# Animate the panel appearing
	$ResultPanel.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property($ResultPanel, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func set_result(result):
	if result == "Victory":
		$ResultPanel/VBoxContainer/ResultLabel.text = "Victory!"
		$ResultPanel/VBoxContainer/MessageLabel.text = "You defeated the enemy!"
		$ResultPanel/VBoxContainer/ResultLabel.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	else:
		$ResultPanel/VBoxContainer/ResultLabel.text = "Defeat"
		$ResultPanel/VBoxContainer/MessageLabel.text = "You were defeated by the enemy..."
		$ResultPanel/VBoxContainer/ResultLabel.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))

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
