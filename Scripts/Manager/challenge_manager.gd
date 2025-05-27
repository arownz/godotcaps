class_name ChallengeManager
extends Node

signal challenge_completed(bonus_damage)
signal challenge_failed
signal challenge_cancelled

var battle_scene
var challenge_type = ""
var current_word_challenge = null

# Preload challenge scenes
var word_challenge_whiteboard_scene = preload("res://Scenes/WordChallengePanel_Whiteboard.tscn")
var word_challenge_stt_scene = preload("res://Scenes/WordChallengePanel_STT.tscn")

func _init(scene):
	battle_scene = scene

func _ready():
	print("ChallengeManager: Initialized")

func start_word_challenge(challenge_type_param: String):
	challenge_type = challenge_type_param
	print("ChallengeManager: Starting " + challenge_type + " challenge")
	
	# Stop battle and show challenge
	battle_scene.battle_active = false
	
	if challenge_type == "whiteboard":
		_show_whiteboard_challenge()
	elif challenge_type == "stt":
		_show_speech_to_text_challenge()
	else:
		print("ChallengeManager: Unknown challenge type: " + challenge_type)
		handle_challenge_failed()

func _show_whiteboard_challenge():
	print("ChallengeManager: Showing whiteboard challenge")
	
	if word_challenge_whiteboard_scene:
		# Create fullscreen overlay
		var overlay = ColorRect.new()
		overlay.name = "ChallengeOverlay"
		overlay.color = Color(0, 0, 0, 0.6)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		battle_scene.add_child(overlay)
		
		# Instantiate challenge
		current_word_challenge = word_challenge_whiteboard_scene.instantiate()
		battle_scene.add_child(current_word_challenge)
		
		# Center the panel
		_center_popup(current_word_challenge)
		
		# Connect signals
		if current_word_challenge.has_signal("challenge_completed"):
			current_word_challenge.connect("challenge_completed", _on_word_challenge_completed)
		if current_word_challenge.has_signal("challenge_failed"):
			current_word_challenge.connect("challenge_failed", _on_word_challenge_failed)
		if current_word_challenge.has_signal("challenge_cancelled"):
			current_word_challenge.connect("challenge_cancelled", _on_challenge_cancelled)
		
		print("ChallengeManager: Whiteboard challenge shown and connected")
	else:
		print("ChallengeManager: ERROR - Could not load whiteboard challenge scene")
		handle_challenge_failed()

func _show_speech_to_text_challenge():
	print("ChallengeManager: Showing STT challenge")
	
	if word_challenge_stt_scene:
		# Create fullscreen overlay
		var overlay = ColorRect.new()
		overlay.name = "ChallengeOverlay"
		overlay.color = Color(0, 0, 0, 0.6)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		battle_scene.add_child(overlay)
		
		# Instantiate challenge
		current_word_challenge = word_challenge_stt_scene.instantiate()
		battle_scene.add_child(current_word_challenge)
		
		# Center the panel
		_center_popup(current_word_challenge)
		
		# Connect signals
		if current_word_challenge.has_signal("challenge_completed"):
			current_word_challenge.connect("challenge_completed", _on_word_challenge_completed)
		if current_word_challenge.has_signal("challenge_failed"):
			current_word_challenge.connect("challenge_failed", _on_word_challenge_failed)
		if current_word_challenge.has_signal("challenge_cancelled"):
			current_word_challenge.connect("challenge_cancelled", _on_challenge_cancelled)
		
		print("ChallengeManager: STT challenge shown and connected")
	else:
		print("ChallengeManager: ERROR - Could not load STT challenge scene")
		handle_challenge_failed()

func _center_popup(popup: Control):
	call_deferred("_center_popup_deferred", popup)

func _center_popup_deferred(popup: Control):
	if not is_instance_valid(popup) or not is_instance_valid(battle_scene):
		return
	
	var viewport_size = battle_scene.get_viewport_rect().size
	var popup_size = popup.size
	var center_position = (viewport_size - popup_size) / 2
	popup.position = center_position

func _on_word_challenge_completed(bonus_damage):
	print("ChallengeManager: Challenge completed with bonus: " + str(bonus_damage))
	
	# Update Firebase challenge stats
	battle_scene._update_firebase_challenge_stats(challenge_type, true)
	
	# Clean up challenge
	_cleanup_challenge()
	
	# Emit signal
	emit_signal("challenge_completed", bonus_damage)

func _on_word_challenge_failed():
	print("ChallengeManager: Challenge failed")
	
	# Update Firebase challenge stats
	battle_scene._update_firebase_challenge_stats(challenge_type, false)
	
	# Clean up challenge
	_cleanup_challenge()
	
	# Emit signal
	emit_signal("challenge_failed")

func _on_challenge_cancelled():
	print("ChallengeManager: Challenge cancelled")
	
	# Update Firebase challenge stats as failed
	battle_scene._update_firebase_challenge_stats(challenge_type, false)
	
	# Clean up challenge
	_cleanup_challenge()
	
	# Emit signal
	emit_signal("challenge_cancelled")

func handle_challenge_completed(bonus_damage):
	# Player successfully countered the enemy skill
	var enemy_manager = battle_scene.enemy_manager
	var player_manager = battle_scene.player_manager
	var battle_log_manager = battle_scene.battle_log_manager
	var ui_manager = battle_scene.ui_manager
	
	# Play counter animation for player
	if player_manager.player_animation:
		var player_sprite = player_manager.player_animation.get_node_or_null("AnimatedSprite2D")
		if player_sprite:
			player_sprite.play("counter")
			# Wait for animation to finish, then return to idle
			await player_sprite.animation_finished
			player_sprite.play("battle_idle")
	
	# Deal bonus damage to enemy
	enemy_manager.take_damage(bonus_damage)
	
	# Add battle log messages
	battle_log_manager.add_message("[color=#4CAF50]You successfully countered the " + enemy_manager.enemy_name + "'s special attack![/color]")
	battle_log_manager.add_message("You dealt " + str(bonus_damage) + " bonus damage!")
	
	# Reset enemy skill meter
	enemy_manager.enemy_skill_meter = 0
	ui_manager.update_enemy_skill_meter()
	
	# Hide enemy skill label
	var enemy_skill_label = battle_scene.get_node_or_null("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemySkillLabel")
	if enemy_skill_label:
		enemy_skill_label.visible = false
	
	# Check if enemy is defeated
	if enemy_manager.enemy_health <= 0:
		battle_scene.battle_active = false
		battle_log_manager.add_message("[color=#4CAF50]You defeated the " + enemy_manager.enemy_name + " with your counter-attack![/color]")
		# Don't call handle_victory here - let the normal enemy_defeated signal handle it
		return
	
	# Resume battle
	_resume_battle()

func handle_challenge_failed():
	# Player failed to counter - enemy deals full skill damage
	var enemy_manager = battle_scene.enemy_manager
	var player_manager = battle_scene.player_manager
	var battle_log_manager = battle_scene.battle_log_manager
	var ui_manager = battle_scene.ui_manager
	
	var skill_damage = int(enemy_manager.enemy_damage * enemy_manager.enemy_skill_damage_multiplier)
	
	# Deal damage to player
	player_manager.take_damage(skill_damage)
	
	# Add battle log messages
	battle_log_manager.add_message("[color=#EB5E4B]You failed to counter the " + enemy_manager.enemy_name + "'s special attack![/color]")
	battle_log_manager.add_message("The " + enemy_manager.enemy_name + " dealt " + str(skill_damage) + " critical damage!")
	
	# Reset enemy skill meter
	enemy_manager.enemy_skill_meter = 0
	ui_manager.update_enemy_skill_meter()
	
	# Hide enemy skill label
	var enemy_skill_label = battle_scene.get_node_or_null("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemySkillLabel")
	if enemy_skill_label:
		enemy_skill_label.visible = false
	
	# Check if player is defeated
	if player_manager.player_health <= 0:
		battle_scene.battle_active = false
		battle_log_manager.add_message("[color=#EB5E4B]You have been defeated by the " + enemy_manager.enemy_name + "![/color]")
		# Check if endgame screen is not already active
		if not battle_scene.battle_manager.endgame_screen_active:
			battle_scene.battle_manager.show_endgame_screen("Defeat")
		return
	
	# Resume battle
	_resume_battle()

func handle_challenge_cancelled():
	# Player cancelled - take reduced damage
	var enemy_manager = battle_scene.enemy_manager
	var player_manager = battle_scene.player_manager
	var battle_log_manager = battle_scene.battle_log_manager
	var ui_manager = battle_scene.ui_manager
	
	var cancellation_damage = int(enemy_manager.enemy_damage * 1.5)
	
	# Deal damage to player
	player_manager.take_damage(cancellation_damage)
	
	# Add battle log messages
	battle_log_manager.add_message("[color=#EB5E4B]You cancelled your counter! The " + enemy_manager.enemy_name + " takes advantage![/color]")
	battle_log_manager.add_message("The " + enemy_manager.enemy_name + " dealt " + str(cancellation_damage) + " damage!")
	
	# Reset enemy skill meter
	enemy_manager.enemy_skill_meter = 0
	ui_manager.update_enemy_skill_meter()
	
	# Hide enemy skill label
	var enemy_skill_label = battle_scene.get_node_or_null("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemySkillLabel")
	if enemy_skill_label:
		enemy_skill_label.visible = false
	
	# Check if player is defeated
	if player_manager.player_health <= 0:
		battle_scene.battle_active = false
		battle_log_manager.add_message("[color=#EB5E4B]You have been defeated by the " + enemy_manager.enemy_name + "![/color]")
		# Check if endgame screen is not already active
		if not battle_scene.battle_manager.endgame_screen_active:
			battle_scene.battle_manager.show_endgame_screen("Defeat")
		return
	
	# Resume battle
	_resume_battle()

func _cleanup_challenge():
	# Remove overlay
	var overlay = battle_scene.get_node_or_null("ChallengeOverlay")
	if overlay:
		overlay.queue_free()
	
	# Remove challenge panel
	if current_word_challenge and is_instance_valid(current_word_challenge):
		current_word_challenge.queue_free()
		current_word_challenge = null

func _resume_battle():
	# Show engage button again
	print("ChallengeManager: Resuming battle")
	
	# Resume auto battle - IMPORTANT: Set battle_active to true first!
	battle_scene.battle_active = true
	battle_scene.auto_battle_timer.start()
	
	print("ChallengeManager: Battle resumed - battle_active set to true and timer started")