class_name ChallengeManager
extends Node

signal challenge_completed(bonus_damage)
signal challenge_failed
signal challenge_cancelled

var battle_scene
var challenge_type = ""
var current_word_challenge = null
var enemy_defeated_during_challenge = false # Track if enemy was defeated during challenge

# Preload challenge scenes
var word_challenge_whiteboard_scene = preload("res://Scenes/WordChallengePanel_Whiteboard.tscn")
var word_challenge_stt_scene = preload("res://Scenes/WordChallengePanel_STT.tscn")

func _init(scene):
	battle_scene = scene

func _ready():
	print("ChallengeManager: Initialized")

func start_word_challenge(challenge_type_param: String):
	challenge_type = challenge_type_param
	enemy_defeated_during_challenge = false # Reset flag
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
	
	# If enemy was already defeated, don't process completion again
	if enemy_defeated_during_challenge:
		print("ChallengeManager: Enemy already defeated, skipping completion processing")
		return
	
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
			# Store original position
			var original_position = player_manager.player_animation.position
			
			# Move player closer to enemy for counter attack
			if enemy_manager and enemy_manager.enemy_animation:
				# Move player to the RIGHT toward enemy (player is on left, enemy on right)
				var counter_position = Vector2(original_position.x + 43, original_position.y)
				
				# Create smooth movement tween to enemy
				var move_tween = battle_scene.create_tween()
				move_tween.tween_property(player_manager.player_animation, "position", counter_position, 0.3)
				move_tween.tween_callback(func(): player_sprite.play("counter"))
				
				# Wait for movement to complete, then play counter animation
				await move_tween.finished
				
				# Wait for counter animation to finish
				await player_sprite.animation_finished
				
				# Move player back to original position and play idle
				var return_tween = battle_scene.create_tween()
				return_tween.tween_property(player_manager.player_animation, "position", original_position, 0.3)
				return_tween.tween_callback(func(): player_sprite.play("battle_idle"))
				
				# Wait for return movement to complete
				await return_tween.finished
			else:
				# Fallback: just play animation in place if enemy not found
				player_sprite.play("counter")
				await player_sprite.animation_finished
				player_sprite.play("battle_idle")
	
	# Calculate total damage (base + bonus)
	var player_base_damage = player_manager.player_damage
	var total_damage = player_base_damage + bonus_damage
	
	# Deal total damage to enemy
	enemy_manager.take_damage(total_damage)
	
	# Show counter damage indicator (different color for counters)
	battle_scene._show_counter_damage_indicator(total_damage, "enemy", bonus_damage)
	
	# Add battle log messages with detailed damage breakdown
	battle_log_manager.add_message("[color=#006400]You successfully countered the " + enemy_manager.enemy_name + "'s special attack![/color]")
	battle_log_manager.add_message("[color=#000000]Counter Attack: " + str(player_base_damage) + " base damage + " + str(bonus_damage) + " bonus = " + str(total_damage) + " total damage![/color]")
	
	# Reset enemy skill meter
	enemy_manager.enemy_skill_meter = 0
	ui_manager.update_enemy_skill_meter()
	
	# Check if enemy is defeated
	if enemy_manager.enemy_health <= 0:
		enemy_defeated_during_challenge = true # Set flag
		battle_scene.battle_active = false
		battle_log_manager.add_message("[color=#006400]You defeated the " + enemy_manager.enemy_name + " with your counter-attack![/color]")
		# Clean up challenge UI immediately when enemy is defeated
		_cleanup_challenge()
		# Don't call handle_victory here - let the normal enemy_defeated signal handle it
		return
	
	# Resume battle
	_resume_battle()

func handle_challenge_failed():
	# Player failed to counter - enemy deals full skill damage with animation
	var enemy_manager = battle_scene.enemy_manager
	var player_manager = battle_scene.player_manager
	var battle_log_manager = battle_scene.battle_log_manager
	var ui_manager = battle_scene.ui_manager
	
	var skill_damage = int(enemy_manager.enemy_damage * enemy_manager.enemy_skill_damage_multiplier)
	
	print("ChallengeManager: Processing challenge failure - enemy will perform skill attack")
	battle_log_manager.add_message("[color=#8B0000]You failed to counter the " + enemy_manager.enemy_name + "'s special attack![/color]")
	
	# ENEMY SKILL ANIMATION WITH PROPER TIMING
	if enemy_manager and enemy_manager.enemy_animation:
		var enemy_node = enemy_manager.enemy_animation
		var original_position = enemy_node.position
		
		# Move enemy LEFT toward player - reduced distance to prevent overlap
		var attack_position = original_position - Vector2(60, 0) # Reduced from 80px to 60px to prevent overlap
		
		# Create smooth movement tween to player
		var move_tween = battle_scene.create_tween()
		move_tween.tween_property(enemy_node, "position", attack_position, 0.3) # Faster movement like auto attack
		
		# Wait for movement to complete
		await move_tween.finished
		
		# Play skill animation and apply damage at the RIGHT moment
		var enemy_sprite = enemy_node.get_node_or_null("AnimatedSprite2D")
		if enemy_sprite and enemy_sprite.sprite_frames and enemy_sprite.sprite_frames.has_animation("skill"):
			enemy_sprite.play("skill")
			
			# Wait for animation to progress before applying damage
			await battle_scene.get_tree().create_timer(0.5).timeout
			
			# NOW apply damage at the peak of the skill animation
			player_manager.take_damage(skill_damage)
			battle_log_manager.add_message("[color=#000000]The " + enemy_manager.enemy_name + " dealt " + str(skill_damage) + " critical damage![/color]")
			
			# Show skill damage indicator (different color for skill attacks)
			battle_scene._show_skill_damage_indicator(skill_damage, "player")
		else:
			# Fallback: apply damage after pause even without skill animation
			await battle_scene.get_tree().create_timer(0.5).timeout
			player_manager.take_damage(skill_damage)
			battle_log_manager.add_message("[color=#000000]The " + enemy_manager.enemy_name + " dealt " + str(skill_damage) + " critical damage![/color]")
			
			# Show skill damage indicator (fallback)
			battle_scene._show_skill_damage_indicator(skill_damage, "player")
		
		# Move enemy back to original position
		var return_tween = battle_scene.create_tween()
		return_tween.tween_property(enemy_node, "position", original_position, 0.2) # Faster return like auto attack
		return_tween.tween_callback(func(): if enemy_sprite: enemy_sprite.play("idle"))
		
		# Wait for return movement to complete
		await return_tween.finished
	else:
		# Fallback if no enemy animation
		await battle_scene.get_tree().create_timer(0.5).timeout
		player_manager.take_damage(skill_damage)
		battle_log_manager.add_message("[color=#000000]The " + enemy_manager.enemy_name + " dealt " + str(skill_damage) + " critical damage![/color]")
	
	# Reset enemy skill meter
	enemy_manager.enemy_skill_meter = 0
	ui_manager.update_enemy_skill_meter()
	
	# Resume battle
	_resume_battle()

func handle_challenge_cancelled():
	# Player cancelled - enemy performs skill attack with animation
	var enemy_manager = battle_scene.enemy_manager
	var player_manager = battle_scene.player_manager
	var battle_log_manager = battle_scene.battle_log_manager
	var ui_manager = battle_scene.ui_manager
	
	var cancellation_damage = int(enemy_manager.enemy_damage * 1.5)
	
	print("ChallengeManager: Processing challenge cancellation - enemy will perform skill attack")
	battle_log_manager.add_message("[color=#EB5E4B]You cancelled your counter! The " + enemy_manager.enemy_name + " takes advantage![/color]")
	
	# ENEMY SKILL ANIMATION WITH PROPER TIMING
	if enemy_manager and enemy_manager.enemy_animation:
		var enemy_node = enemy_manager.enemy_animation
		var original_position = enemy_node.position
		
		# Move enemy LEFT toward player - reduced distance to prevent overlap
		var attack_position = original_position - Vector2(60, 0) # Reduced from 80px to 60px to prevent overlap
		
		# Create smooth movement tween to player
		var move_tween = battle_scene.create_tween()
		move_tween.tween_property(enemy_node, "position", attack_position, 0.3) # Faster movement like auto attack
		
		# Wait for movement to complete
		await move_tween.finished
		
		# Play skill animation and apply damage at the RIGHT moment
		var enemy_sprite = enemy_node.get_node_or_null("AnimatedSprite2D")
		if enemy_sprite and enemy_sprite.sprite_frames and enemy_sprite.sprite_frames.has_animation("skill"):
			enemy_sprite.play("skill")
			
			# Wait for animation to progress before applying damage
			await battle_scene.get_tree().create_timer(0.5).timeout
			
			# NOW apply damage at the peak of the skill animation
			player_manager.take_damage(cancellation_damage)
			battle_log_manager.add_message("[color=#000000]The " + enemy_manager.enemy_name + " dealt " + str(cancellation_damage) + " damage![/color]")
			
			# Show skill damage indicator for cancellation
			battle_scene._show_skill_damage_indicator(cancellation_damage, "player")
		else:
			# Fallback: apply damage after pause even without skill animation
			await battle_scene.get_tree().create_timer(0.5).timeout
			player_manager.take_damage(cancellation_damage)
			battle_log_manager.add_message("[color=#000000]The " + enemy_manager.enemy_name + " dealt " + str(cancellation_damage) + " damage![/color]")
			
			# Show skill damage indicator (fallback)
			battle_scene._show_skill_damage_indicator(cancellation_damage, "player")
		
		# Move enemy back to original position
		var return_tween = battle_scene.create_tween()
		return_tween.tween_property(enemy_node, "position", original_position, 0.2) # Faster return like auto attack
		return_tween.tween_callback(func(): if enemy_sprite: enemy_sprite.play("idle"))
		
		# Wait for return movement to complete
		await return_tween.finished
	else:
		# Fallback if no enemy animation
		await battle_scene.get_tree().create_timer(0.5).timeout
		player_manager.take_damage(cancellation_damage)
		battle_log_manager.add_message("[color=#000000]The " + enemy_manager.enemy_name + " dealt " + str(cancellation_damage) + " damage![/color]")
	
	# Reset enemy skill meter
	enemy_manager.enemy_skill_meter = 0
	ui_manager.update_enemy_skill_meter()
	
	# Check if player is defeated
	if player_manager.player_health <= 0:
		battle_scene.battle_active = false
		battle_log_manager.add_message("[color=#EB5E4B]You have been defeated by the " + enemy_manager.enemy_name + "![/color]")
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
	
	# Clean up any active result panels that might be blocking the EndgameScreen
	var root = battle_scene.get_tree().root
	for child in root.get_children():
		if child.name == "ChallengeResultPanel" or child.get_script() != null:
			var script_path = child.get_script().resource_path if child.get_script() else ""
			if "ChallengeResultPanel" in script_path:
				print("ChallengeManager: Cleaning up active result panel")
				child.queue_free()

func _resume_battle():
	# Show engage button again
	print("ChallengeManager: Resuming battle")
	
	# Resume auto battle - IMPORTANT: Set battle_active to true first!
	battle_scene.battle_active = true
	battle_scene.auto_battle_timer.start()
	
	print("ChallengeManager: Battle resumed - battle_active set to true and timer started")