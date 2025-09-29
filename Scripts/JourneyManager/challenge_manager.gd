class_name ChallengeManager
extends Node

signal challenge_completed(bonus_damage)
signal challenge_failed
signal challenge_cancelled

var battle_scene
var challenge_type = ""
var current_word_challenge = null
var enemy_defeated_during_challenge = false # Track if enemy was defeated during challenge
var challenge_processing = false # NEW: Flag to prevent double skill attacks
var successful_counter_completed = false # NEW: Track if counter was successful

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
	
	print("ChallengeManager: Processing successful challenge completion")
	
	# Create damage callback that will be called at the exact moment of impact
	var apply_counter_damage = func():
		# Calculate total damage (base + bonus)
		var player_base_damage = player_manager.player_damage
		var total_damage = player_base_damage + bonus_damage
		
		# Deal total damage to enemy at the moment of impact
		enemy_manager.take_damage(total_damage)
		
		# Show counter damage indicator (different color for counters)
		battle_scene._show_counter_damage_indicator(total_damage, "enemy", bonus_damage)
		
		# Add battle log messages with detailed damage breakdown using character's counter name
		var counter_name = battle_log_manager._get_current_character_counter_name()
		battle_log_manager.add_message("[color=#006400]" + counter_name + " successful! You countered " + enemy_manager.enemy_name + "'s attack![/color]")
		battle_log_manager.add_message("[color=#000000]" + counter_name + ": " + str(player_base_damage) + " base + " + str(bonus_damage) + " bonus = " + str(total_damage) + " total damage![/color]")
		
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
				move_tween.tween_callback(func(): player_manager.perform_counter_attack(apply_counter_damage))
				
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
				player_manager.perform_counter_attack(apply_counter_damage)
				await player_sprite.animation_finished
				player_sprite.play("battle_idle")
	
	# CRITICAL: Mark this as a successful counter before resuming
	# Set a flag to indicate this was a successful counter (not a failed challenge)
	# This will be used in _resume_battle() to determine turn order
	print("ChallengeManager: Counter attack completed, resuming battle with enemy turn next")
	
	# Resume battle - but enemy should attack next since player just countered
	_resume_battle_after_successful_counter()

# Resume battle specifically after successful counter (enemy should attack next)
func _resume_battle_after_successful_counter():
	print("ChallengeManager: Resuming battle after successful counter - enemy attacks next")
    
	# If the enemy was defeated during the counter, do not resume
	if enemy_defeated_during_challenge or (battle_scene.enemy_manager and battle_scene.enemy_manager.enemy_health <= 0):
		print("ChallengeManager: Enemy defeated during counter - skipping resume")
		return
	
	# Set battle active
	battle_scene.battle_active = true
	
	# IMPORTANT: Don't reuse the shared auto_battle_timer here, it already has a handler
	# wired to BattleScene._on_auto_battle_timer_timeout (player turn). Using it would
	# cause both the enemy and player turns to fire in sync. Instead, stop any pending
	# auto-battle timer and use a dedicated one-shot timer for the enemy response.
	if battle_scene.auto_battle_timer:
		battle_scene.auto_battle_timer.stop()
    
	# Use a one-shot timer to schedule the enemy's immediate response
	await battle_scene.get_tree().create_timer(1.2).timeout
	await _trigger_enemy_attack_after_counter()

# Helper function to trigger enemy attack after successful counter
func _trigger_enemy_attack_after_counter():
	print("ChallengeManager: Triggering enemy attack after successful counter")
	
	if battle_scene.battle_active and battle_scene.enemy_manager.enemy_health > 0:
		# Enemy attacks in response to the counter
		battle_scene.battle_manager.enemy_attack()
		
		# After enemy attack, wait and continue normal battle flow
		await battle_scene.get_tree().create_timer(1.0).timeout
		
		if battle_scene.battle_active:
			# Continue normal auto battle sequence (player attacks next)
			battle_scene.auto_battle_timer.wait_time = 1.0
			battle_scene.auto_battle_timer.start()

func handle_challenge_failed():
	# Prevent double processing
	if challenge_processing:
		print("ChallengeManager: Challenge failure already being processed, ignoring duplicate")
		return
	challenge_processing = true
	
	# Player failed to counter - enemy deals full skill damage with animation
	var enemy_manager = battle_scene.enemy_manager
	var player_manager = battle_scene.player_manager
	var battle_log_manager = battle_scene.battle_log_manager
	var ui_manager = battle_scene.ui_manager
	
	var skill_damage = int(enemy_manager.enemy_damage * enemy_manager.enemy_skill_damage_multiplier)
	
	print("ChallengeManager: Processing challenge failure - enemy will perform skill attack")
	var counter_name = battle_log_manager._get_current_character_counter_name()
	battle_log_manager.add_message("[color=#8B0000]" + counter_name + " failed! " + enemy_manager.enemy_name + " attacks with full power![/color]")
	
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
	
	# Reset challenge processing flag
	challenge_processing = false
	
	# Resume battle
	_resume_battle()

func handle_challenge_cancelled():
	# Prevent double processing
	if challenge_processing:
		print("ChallengeManager: Challenge cancellation already being processed, ignoring duplicate")
		return
	challenge_processing = true
	
	# Player cancelled the challenge - enemy deals reduced damage as skill
	var enemy_manager = battle_scene.enemy_manager
	var player_manager = battle_scene.player_manager
	var battle_log_manager = battle_scene.battle_log_manager
	var ui_manager = battle_scene.ui_manager
	
	# Reduced damage for cancellation (less than full skill damage)
	var cancellation_damage = int(enemy_manager.enemy_damage * 1.5) # 50% more than normal attack
	
	print("ChallengeManager: Processing challenge cancellation - enemy will perform skill attack")
	
	# Add cancellation message to battle log
	var counter_name = battle_log_manager._get_current_character_counter_name()
	battle_log_manager.add_message("[color=#FFA500]You cancelled " + counter_name + ". Enemy attacks![/color]")
	
	# ENEMY SKILL ATTACK WITH ANIMATION
	if enemy_manager and enemy_manager.enemy_animation:
		var enemy_node = enemy_manager.enemy_animation
		var original_position = enemy_node.position
		
		# Move enemy LEFT toward player for skill attack
		var attack_position = original_position - Vector2(60, 0) # Same distance as skill attack
		
		# Create smooth movement tween to player
		var move_tween = battle_scene.create_tween()
		move_tween.tween_property(enemy_node, "position", attack_position, 0.3)
		
		# Wait for movement to complete
		await move_tween.finished
		
		# Play SKILL animation and apply damage (align with failed challenge visuals)
		var enemy_sprite = enemy_node.get_node_or_null("AnimatedSprite2D")
		if enemy_sprite and enemy_sprite.sprite_frames and enemy_sprite.sprite_frames.has_animation("skill"):
			enemy_sprite.play("skill")
			# Wait slightly longer to align with skill impact
			await battle_scene.get_tree().create_timer(0.5).timeout
			# Apply skill damage
			player_manager.take_damage(cancellation_damage)
			battle_log_manager.add_message("[color=#000000]The " + enemy_manager.enemy_name + " dealt " + str(cancellation_damage) + " critical damage![/color]")
			# Show skill damage indicator for consistency
			battle_scene._show_skill_damage_indicator(cancellation_damage, "player")
		elif enemy_sprite and enemy_sprite.sprite_frames and enemy_sprite.sprite_frames.has_animation("auto_attack"):
			# Fallback: if no 'skill' animation, try auto_attack
			enemy_sprite.play("auto_attack")
			await battle_scene.get_tree().create_timer(0.4).timeout
			player_manager.take_damage(cancellation_damage)
			battle_log_manager.add_message("[color=#000000]The " + enemy_manager.enemy_name + " dealt " + str(cancellation_damage) + " critical damage![/color]")
			# Use standard indicator as fallback
			battle_scene._show_damage_indicator(cancellation_damage, "player")
		else:
			# Fallback: apply damage without animation
			await battle_scene.get_tree().create_timer(0.4).timeout
			player_manager.take_damage(cancellation_damage)
			battle_log_manager.add_message("[color=#000000]The " + enemy_manager.enemy_name + " dealt " + str(cancellation_damage) + " critical damage![/color]")
			# Show damage indicator
			battle_scene._show_damage_indicator(cancellation_damage, "player")
		
		# Move enemy back to original position
		var return_tween = battle_scene.create_tween()
		return_tween.tween_property(enemy_node, "position", original_position, 0.2)
		return_tween.tween_callback(func(): if enemy_sprite: enemy_sprite.play("idle"))
		
		# Wait for return movement to complete
		await return_tween.finished
	else:
		# Fallback if no enemy animation
		await battle_scene.get_tree().create_timer(0.5).timeout
		player_manager.take_damage(cancellation_damage)
		battle_log_manager.add_message("[color=#000000]The " + enemy_manager.enemy_name + " dealt " + str(cancellation_damage) + " critical damage![/color]")

		# Show damage indicator
		battle_scene._show_damage_indicator(cancellation_damage, "player")

	# Reset enemy skill meter after skill attack
	enemy_manager.enemy_skill_meter = 0
	ui_manager.update_enemy_skill_meter()
	
	# Reset challenge processing flag
	challenge_processing = false
	
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
	print("ChallengeManager: Resuming battle after challenge")
	
	# After failed/cancelled challenge: Continue normal turn sequence
	print("ChallengeManager: Resuming normal battle flow after failed/cancelled challenge")
	
	# Set battle active first
	battle_scene.battle_active = true
	
	# After enemy skill attack due to failed/cancelled challenge,
	# the enemy has already had their "turn". Resume the normal auto-battle cycle
	# without manually forcing a player attack to avoid double-attacks.
	battle_scene.auto_battle_timer.wait_time = 1.5
	battle_scene.auto_battle_timer.start()
    
	print("ChallengeManager: Battle resumed - auto battle will handle turn order")

## Removed _trigger_player_turn_after_failed_challenge to avoid manual player attack
## The auto-battle timer will invoke the standard _auto_battle_turn(), ensuring
## exactly one player attack followed by one enemy attack in the next cycle.