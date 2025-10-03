class_name BattleManager
extends Node

# Add signals for better decoupling
signal player_attack_performed(damage)
signal enemy_attack_performed(damage)
signal enemy_skill_triggered

var battle_scene # Reference to the main battle scene

# Add flag to prevent multiple endgame screens
var endgame_screen_active: bool = false
var victory_processing: bool = false # Add flag to prevent duplicate victory processing
var defeat_processing: bool = false # Add flag to prevent duplicate defeat processing

# External resources
var word_challenge_whiteboard_scene = preload("res://Scenes/WordChallengePanel_Whiteboard.tscn")
var word_challenge_stt_scene = preload("res://Scenes/WordChallengePanel_STT.tscn")
var endgame_screen_scene = preload("res://Scenes/EndgameScreen.tscn")
var current_word_challenge = null

func _init(scene):
	battle_scene = scene

func _ready():
	# The battle_scene reference is already set in the _init method
	# Now we can get references to other managers through the battle_scene
	# No need to directly type-hint them, which was causing errors
	pass

func player_attack():
	# Safety check: Don't attack if battle is not active or player is defeated
	if !battle_scene.battle_active:
		print("BattleManager: Skipping player attack - battle not active")
		return
		
	if battle_scene.player_manager.player_health <= 0:
		print("BattleManager: Skipping player attack - player is defeated")
		return
	
	# Use the player animation from player_manager instead of direct node access
	if !battle_scene.player_manager.player_animation:
		print("ERROR: Player animation not found")
		emit_signal("player_attack_performed", battle_scene.player_manager.player_damage)
		return
		
	var player_node = battle_scene.player_manager.player_animation
	var original_position = player_node.position
	
	# Move player toward enemy
	var player_attack_tween = create_tween()
	player_attack_tween.tween_property(player_node, "position", original_position + Vector2(50, 0), 0.3) # Move right
	
	# Start attack animation and sound effect using player_manager
	battle_scene.player_manager.perform_auto_attack()
	
	# Wait for movement to finish, then return to position
	await player_attack_tween.finished
	
	# Return to original position
	var return_tween = create_tween()
	return_tween.tween_property(player_node, "position", original_position, 0.4)
	await return_tween.finished
		
	emit_signal("player_attack_performed", battle_scene.player_manager.player_damage)

func enemy_attack():
	# Safety check: Don't attack if battle is not active or enemy is defeated
	if !battle_scene.battle_active:
		print("BattleManager: Skipping enemy attack - battle not active")
		return
		
	if battle_scene.enemy_manager.enemy_health <= 0:
		print("BattleManager: Skipping enemy attack - enemy is defeated")
		return
	
	# Use the enemy animation from enemy_manager instead of direct node access
	if !battle_scene.enemy_manager.enemy_animation:
		print("ERROR: Enemy animation not found")
		emit_signal("enemy_attack_performed", battle_scene.enemy_manager.enemy_damage)
		return
		
	var enemy_node = battle_scene.enemy_manager.enemy_animation
	var original_position = enemy_node.position
	
	var enemy_attack_tween = create_tween()
	enemy_attack_tween.tween_property(enemy_node, "position", original_position - Vector2(64, 0), 0.3) # Move left - reduced to prevent overlap
	enemy_attack_tween.tween_property(enemy_node, "position", original_position, 0.4) # Return to original position
	
	# Play attack animation
	var sprite = enemy_node.get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.play("auto_attack")
		# Play enemy auto-attack SFX using EnemyManager's flexible lookup (supports enemy_autoattack)
		if battle_scene.enemy_manager and battle_scene.enemy_manager.has_method("play_enemy_sfx"):
			battle_scene.enemy_manager.play_enemy_sfx("enemy_autoattack") # Use consistent enemy naming convention
	else:
		# Even if no sprite is found, still try to play the auto-attack SFX
		if battle_scene.enemy_manager and battle_scene.enemy_manager.has_method("play_enemy_sfx"):
			battle_scene.enemy_manager.play_enemy_sfx("enemy_autoattack") # Use consistent enemy naming convention
	
	await enemy_attack_tween.finished
	
	# Reset to idle animation after attack
	if sprite:
		sprite.play("idle")
		
	emit_signal("enemy_attack_performed", battle_scene.enemy_manager.enemy_damage)

# Centralize all endgame handling here
func handle_victory():
	# Prevent multiple victory processing
	if victory_processing:
		print("BattleManager: Victory already being processed, preventing duplicate")
		return
	
	victory_processing = true
	print("BattleManager: Handling victory")
	
	# Get CURRENT stage info BEFORE any advancement
	var completed_dungeon = battle_scene.dungeon_manager.dungeon_num
	var completed_stage = battle_scene.dungeon_manager.stage_num
	
	# Calculate experience reward - use the actual exp_reward from enemy resource
	var exp_reward = battle_scene.enemy_manager.exp_reward
	if exp_reward <= 0:
		# Fallback calculation if exp_reward not set properly
		exp_reward = battle_scene.enemy_manager.enemy_level * 2 # Reduced from 10 to 2 for balance
	
	# Award experience to player
	print("BattleManager: Awarding ", exp_reward, " experience to player")
	print("BattleManager: Player stats before exp gain - Level: ", battle_scene.player_manager.player_level, ", Exp: ", battle_scene.player_manager.player_exp, "/", battle_scene.player_manager.get_max_exp())
	await battle_scene.player_manager.add_experience(exp_reward)
	print("BattleManager: Player stats after exp gain - Level: ", battle_scene.player_manager.player_level, ", Exp: ", battle_scene.player_manager.player_exp, "/", battle_scene.player_manager.get_max_exp())
	
	# Get enemy name for endgame screen
	var enemy_name = battle_scene.enemy_manager.enemy_name
	
	# Add victory message
	battle_scene.battle_log_manager.add_message("[color=#006400]Victory! You defeated the enemy and gained " + str(exp_reward) + " experience.[/color]")
	
	# Show victory screen immediately - don't wait for Firebase
	show_endgame_screen("Victory", exp_reward, completed_dungeon, completed_stage, enemy_name)
	
	# FIXED: Update Firebase synchronously to prevent race conditions
	# Note: Player stats (exp, level, health, damage, durability) are updated by player_manager.gd
	# We only update progression and enemy count here
	await _update_firebase_after_victory(exp_reward, completed_dungeon, completed_stage)
	
	# Show notification if dungeon was completed (boss defeated) - check later
	await get_tree().create_timer(0.5).timeout
	if completed_stage >= 5:
		_show_dungeon_completion_notification(completed_dungeon)

# Direct Firebase update after victory - only updates progression, not player stats
# Returns true if a dungeon was completed (boss defeated)
func _update_firebase_after_victory(_exp_gained: int, completed_dungeon_num: int, completed_stage_num: int) -> bool:
	if !Firebase.Auth.auth:
		return false
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current user document to calculate updates
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		var current_data = {}
		for key in document.keys():
			if key != "error":
				current_data[key] = document.get_value(key)
		
		# Get current stages completed for this dungeon using completed stage numbers
		var dungeons_data = current_data.get("dungeons", {})
		var completed_data = dungeons_data.get("completed", {})
		var dungeon_key = str(completed_dungeon_num)
		var dungeon_data = completed_data.get(dungeon_key, {"completed": false, "stages_completed": 0})
		var current_stages_completed = dungeon_data.get("stages_completed", 0)
		
		# Prepare update data - ONLY update progression, not player stats
		# Player stats (exp, level, health, damage, durability) are handled by player_manager.gd
		var update_data = {
			"dungeons.progress.enemies_defeated": dungeons_data.get("progress", {}).get("enemies_defeated", 0) + 1
		}
		
		# Only update stage progression if this stage hasn't been completed before
		# Use the COMPLETED stage number, not the incremented one
		var dungeon_was_completed = false
		if completed_stage_num > current_stages_completed:
			update_data["dungeons.completed." + dungeon_key + ".stages_completed"] = completed_stage_num
			if completed_stage_num >= 5:
				update_data["dungeons.completed." + dungeon_key + ".completed"] = true
				dungeon_was_completed = true
				# When completing a dungeon (boss defeated), unlock the next dungeon
				var next_dungeon = completed_dungeon_num + 1
				if next_dungeon <= 3: # Max 3 dungeons
					update_data["dungeons.progress.current_dungeon"] = next_dungeon
					print("Dungeon " + str(completed_dungeon_num) + " completed! Unlocked dungeon " + str(next_dungeon))
			print("Updated stages_completed for dungeon " + dungeon_key + " to stage " + str(completed_stage_num))
		else:
			print("Stage " + str(completed_stage_num) + " already completed for dungeon " + dungeon_key)
		
		# Get the document for Firebase update
		var firebase_doc = await collection.get_doc(user_id)
		if firebase_doc and !("error" in firebase_doc.keys() and firebase_doc.get_value("error")):
			print("BattleManager: Document retrieved successfully for progression update")
			
			# Apply updates to the document
			for field_path in update_data.keys():
				var field_value = update_data[field_path]
				# Handle nested field updates (e.g., "dungeons.completed.1.stages_completed")
				var field_parts = field_path.split(".")
				if field_parts.size() > 1:
					# Get the root field
					var root_field = field_parts[0]
					var root_data = firebase_doc.get_value(root_field)
					if root_data == null:
						root_data = {}
					
					# Navigate to the nested location and set the value
					var data_ref = root_data
					for i in range(1, field_parts.size() - 1):
						var part = field_parts[i]
						if data_ref.get(part) == null:
							data_ref[part] = {}
						data_ref = data_ref[part]
					
					# Set the final value
					data_ref[field_parts[-1]] = field_value
					
					# Update the root field in the document
					firebase_doc.add_or_update_field(root_field, root_data)
				else:
					# Simple field update
					firebase_doc.add_or_update_field(field_path, field_value)
			
			# Update the document using the correct method
			var updated_document = await collection.update(firebase_doc)
			if updated_document:
				print("Firebase progression updated successfully")
				return dungeon_was_completed
			else:
				print("Failed to update Firebase progression")
				return false
		else:
			print("Failed to get document for progression update")
			return false
	else:
		print("Failed to load user document or document error")
		return false

# Async version that doesn't block the UI
func _update_firebase_after_victory_async(exp_gained: int, completed_dungeon_num: int, completed_stage_num: int):
	# Run Firebase update in background without blocking UI
	var firebase_task = func():
		await _update_firebase_after_victory(exp_gained, completed_dungeon_num, completed_stage_num)
		print("BattleManager: Background Firebase update completed")
	
	# Start the task but don't await it
	firebase_task.call()

func handle_defeat():
	# Prevent multiple defeat processing
	if defeat_processing:
		print("BattleManager: Defeat already being processed, preventing duplicate")
		return
	
	defeat_processing = true
	print("BattleManager: Handling defeat")
	
	# Get enemy name for the defeat message
	var enemy_name = battle_scene.enemy_manager.enemy_name
	
	# Add defeat message with enemy name
	battle_scene.battle_log_manager.add_message("[color=#8B0000]You have been defeated by the " + enemy_name + "![/color]")
	
	# Wait a moment for the message to be seen
	await battle_scene.get_tree().create_timer(1.0).timeout
	
	# Show defeat screen
	show_endgame_screen("Defeat", 0, 0, 0, enemy_name)

func show_endgame_screen(result_type: String, exp_reward: int = 0, completed_dungeon: int = 0, completed_stage: int = 0, enemy_name: String = ""):
	# Prevent multiple endgame screens
	if endgame_screen_active:
		print("BattleManager: Endgame screen already active, preventing duplicate")
		return
	
	# Check for existing endgame screen in BattleContainer
	var battle_container = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer")
	var existing_endgame = battle_container.get_node_or_null("EndgameScreen")
	if existing_endgame:
		print("BattleManager: Endgame screen already exists, removing old one")
		existing_endgame.queue_free()
		await battle_scene.get_tree().process_frame
	
	endgame_screen_active = true
	
	var endgame_scene = load("res://Scenes/EndgameScreen.tscn").instantiate()
	endgame_scene.name = "EndgameScreen" # Set a consistent name for easy detection
	
	# Position in center of BattleContainer
	battle_container.add_child(endgame_scene)
	
	# Center the endgame screen within the BattleContainer
	endgame_scene.anchors_preset = Control.PRESET_FULL_RECT
	endgame_scene.offset_left = 0
	endgame_scene.offset_top = 0
	endgame_scene.offset_right = 0
	endgame_scene.offset_bottom = 0
	
	# Use completed stage info if provided, otherwise current dungeon manager values
	var dungeon_num = completed_dungeon if completed_dungeon > 0 else battle_scene.dungeon_manager.dungeon_num
	var stage_num = completed_stage if completed_stage > 0 else battle_scene.dungeon_manager.stage_num
	endgame_scene.setup_endgame(result_type, dungeon_num, stage_num, exp_reward, enemy_name)
	
	# Connect EndgameScreen signals
	endgame_scene.restart_battle.connect(_on_restart_battle)
	endgame_scene.quit_to_menu.connect(_on_quit_to_menu)
	endgame_scene.continue_battle.connect(_on_continue_battle)

func _on_restart_battle():
	# Reset endgame screen flag
	endgame_screen_active = false
	victory_processing = false # Reset victory processing flag
	defeat_processing = false # Reset defeat processing flag
	
	# Heal player to full health on restart
	if battle_scene and battle_scene.player_manager:
		battle_scene.player_manager.heal_to_full()
	
	# Reset game state
	battle_scene.dungeon_manager.reset()
	
	# Reload the battle scene
	battle_scene.get_tree().reload_current_scene()

func _on_quit_to_menu():
	# Called when leaving from EndgameScreen - returns to current dungeon map
	# Note: This is different from _on_battle_quit_requested() in battlescene.gd 
	# which handles quitting from the battle settings popup
	# Reset endgame screen flag
	endgame_screen_active = false
	victory_processing = false # Reset victory processing flag
	
	# Return to current dungeon map based on dungeon_num
	var dungeon_scene_path = ""
	var current_dungeon = battle_scene.dungeon_manager.dungeon_num
	
	match current_dungeon:
		1:
			dungeon_scene_path = "res://Scenes/Dungeon1Map.tscn"
		2:
			dungeon_scene_path = "res://Scenes/Dungeon2Map.tscn"
		3:
			dungeon_scene_path = "res://Scenes/Dungeon3Map.tscn"
		_:
			# Default to dungeon selection if unknown
			dungeon_scene_path = "res://Scenes/DungeonSelection.tscn"
	
	battle_scene.get_tree().change_scene_to_file(dungeon_scene_path)

func _on_continue_battle():
	# Reset endgame screen flag
	endgame_screen_active = false
	victory_processing = false # Reset victory processing flag
	defeat_processing = false # Reset defeat processing flag
	
	# Heal player to full health on stage progression
	if battle_scene and battle_scene.player_manager:
		battle_scene.player_manager.heal_to_full()
	
	# Check if there are more stages in this dungeon
	var current_stage = battle_scene.dungeon_manager.stage_num
	var max_stages = 5
	
	if current_stage < max_stages:
		# CRITICAL FIX: Advance stage and save to Firebase SYNCHRONOUSLY
		print("BattleManager: Starting stage advancement process...")
		await battle_scene.dungeon_manager.advance_stage()
		print("BattleManager: Stage advancement completed - Now at stage ", battle_scene.dungeon_manager.stage_num)
		
		# IMPORTANT: Update DungeonGlobals with the new stage info before reloading
		DungeonGlobals.set_battle_progress(battle_scene.dungeon_manager.dungeon_num, battle_scene.dungeon_manager.stage_num)
		print("BattleManager: DungeonGlobals updated - Dungeon: ", battle_scene.dungeon_manager.dungeon_num, ", Stage: ", battle_scene.dungeon_manager.stage_num)
		
		# Add extra delay to ensure Firebase operations complete
		await get_tree().create_timer(0.5).timeout
		print("BattleManager: Firebase sync delay completed")
		
		# Reset battle state
		battle_scene.battle_active = false
		
		print("BattleManager: Returning to dungeon map for dungeon ", battle_scene.dungeon_manager.dungeon_num)
		
		# Go back to dungeon map to show updated progression
		var dungeon_scene_path = ""
		match battle_scene.dungeon_manager.dungeon_num:
			1:
				dungeon_scene_path = "res://Scenes/Dungeon1Map.tscn"
			2:
				dungeon_scene_path = "res://Scenes/Dungeon2Map.tscn"
			3:
				dungeon_scene_path = "res://Scenes/Dungeon3Map.tscn"
			_:
				dungeon_scene_path = "res://Scenes/DungeonSelection.tscn"
		
		battle_scene.get_tree().change_scene_to_file(dungeon_scene_path)
	else:
		# Completed all stages (defeated boss), go to dungeon selection to show unlocked dungeons
		print("BattleManager: Dungeon " + str(battle_scene.dungeon_manager.dungeon_num) + " completed! Going to DungeonSelection")
		battle_scene.get_tree().change_scene_to_file("res://Scenes/DungeonSelection.tscn")

func _update_current_stage_in_firebase(new_stage: int):
	if !Firebase.Auth.auth:
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get the document first
	var stage_document = await collection.get_doc(user_id)
	if stage_document and !("error" in stage_document.keys() and stage_document.get_value("error")):
		# Get current dungeons data
		var dungeons_data = stage_document.get_value("dungeons")
		if dungeons_data == null:
			dungeons_data = {}
		
		# Ensure progress structure exists
		if dungeons_data.get("progress") == null:
			dungeons_data["progress"] = {}
		
		# Update current stage
		dungeons_data["progress"]["current_stage"] = new_stage
		
		# Update the document field
		stage_document.add_or_update_field("dungeons", dungeons_data)
		
		# Update the document using the correct method
		var updated_document = await collection.update(stage_document)
		if updated_document:
			print("Current stage updated to: " + str(new_stage))
		else:
			print("Failed to update current stage")
	else:
		print("Failed to get document for stage update")

func trigger_enemy_skill():
	print("BattleManager: Enemy skill triggered!")
	
	# Add battle log message
	battle_scene.battle_log_manager.add_message("[color=#8B0000]The " + battle_scene.enemy_manager.enemy_name + " is preparing a special attack![/color]")
	
	# Emit signal
	emit_signal("enemy_skill_triggered")
	
	# Show Enemy Skill Indicator first - enemy stays in original position
	_show_enemy_skill_indicator()

# Remove the enemy movement animation for skills - enemy should stay put during indicator/challenge
# Enemy will only move if player fails the challenge (handled in challenge_manager.gd)

func _show_enemy_skill_indicator():
	print("BattleManager: Showing enemy skill indicator")
	
	# Determine challenge type
	var challenge_type = "whiteboard" if randf() < 0.5 else "stt"
	
	# Load and instantiate the enemy skill indicator
	var indicator_scene = load("res://Scenes/EnemySkillIndicator.tscn")
	if indicator_scene:
		var indicator = indicator_scene.instantiate()
		
		# Add to the BattleContainer for proper centering
		var battle_container = battle_scene.get_node_or_null("MainContainer/BattleAreaContainer/BattleContainer")
		if battle_container:
			battle_container.add_child(indicator)
			# Set proper anchoring for center positioning
			indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
		else:
			# Fallback to scene root if BattleContainer not found
			battle_scene.add_child(indicator)
		
		# Add fade-in animation
		indicator.modulate.a = 0.0
		indicator.scale = Vector2(0.8, 0.8)
		var tween = battle_scene.create_tween()
		tween.set_parallel(true)
		tween.tween_property(indicator, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
		tween.tween_property(indicator, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		# Setup the indicator with enemy info
		var enemy_name = battle_scene.enemy_manager.enemy_name
		var skill_name = "Ultimate Attack" if battle_scene.enemy_manager.enemy_type == "boss" else "Special Strike"
		indicator.setup(enemy_name, skill_name, challenge_type)
		
		# Connect the finished signal
		if indicator.has_signal("indicator_finished"):
			indicator.connect("indicator_finished", _on_skill_indicator_finished.bind(challenge_type))
		
		print("BattleManager: Enemy skill indicator shown for " + challenge_type + " challenge")
	else:
		print("BattleManager: ERROR - Could not load EnemySkillIndicator scene, starting challenge directly")
		_start_word_challenge(challenge_type)

func _on_skill_indicator_finished(challenge_type: String):
	print("BattleManager: Skill indicator finished, starting " + challenge_type + " challenge")
	_start_word_challenge(challenge_type)

func _start_word_challenge(challenge_type: String):
	print("BattleManager: Starting " + challenge_type + " challenge")
	
	# Add battle log message about the challenge
	battle_scene.battle_log_manager.add_message("[color=#B8860B]Counter by " + ("writing" if challenge_type == "whiteboard" else "speaking") + " the word![/color]")
	
	# Connect challenge manager signals if not already connected
	if !battle_scene.challenge_manager.is_connected("challenge_completed", _on_challenge_completed):
		battle_scene.challenge_manager.connect("challenge_completed", _on_challenge_completed)
	if !battle_scene.challenge_manager.is_connected("challenge_failed", _on_challenge_failed):
		battle_scene.challenge_manager.connect("challenge_failed", _on_challenge_failed)
	if !battle_scene.challenge_manager.is_connected("challenge_cancelled", _on_challenge_cancelled):
		battle_scene.challenge_manager.connect("challenge_cancelled", _on_challenge_cancelled)
	
	# Start the challenge
	battle_scene.challenge_manager.start_word_challenge(challenge_type)

func _on_challenge_completed(bonus_damage):
	battle_scene.challenge_manager.handle_challenge_completed(bonus_damage)
	# No need to return enemy to position - enemy never moved during successful challenge

func _on_challenge_failed():
	battle_scene.challenge_manager.handle_challenge_failed()
	# Enemy movement and return is handled in challenge_manager

func _on_challenge_cancelled():
	battle_scene.challenge_manager.handle_challenge_cancelled()
	# Enemy movement and return is handled in challenge_manager

# Show unified dungeon completion and character unlock notification
func _show_dungeon_completion_notification(completed_dungeon_num: int):
	var next_dungeon = completed_dungeon_num + 1
	var next_word_length = ""
	
	# Determine the word length message for the next dungeon
	match next_dungeon:
		2: next_word_length = "4-letter"
		3: next_word_length = "5-letter"
		_: next_word_length = "advanced"
	
	# Check for character unlock first
	var character_unlock_info = await _check_character_unlock(completed_dungeon_num)
	
	var title = "Dungeon " + str(completed_dungeon_num) + " Completed!"
	var message = ""
	
	# Create unified message
	if next_dungeon <= 3:
		message = "Dungeon " + str(next_dungeon) + " unlocked with " + next_word_length + " words!"
		
		# Add character unlock message if applicable
		if character_unlock_info.unlocked:
			message += "\n\n" + character_unlock_info.message
	else:
		message = "All dungeons completed! You are now a master reader!"
	
	# Get notification popup from battle scene (should exist)
	var notification_popup = battle_scene.get_node_or_null("NotificationPopUp")
	if notification_popup:
		print("BattleManager: Showing unified dungeon completion notification")
		var button_text = "Ok" if character_unlock_info.unlocked else "Continue"
		notification_popup.show_notification(title, message, button_text)
	else:
		print("BattleManager: Warning - notification popup not found")

# Check for character unlocks after dungeon completion - returns unlock info
func _check_character_unlock(completed_dungeon_num: int) -> Dictionary:
	var unlock_info = {"unlocked": false, "character_name": "", "message": ""}
	
	if !Firebase.Auth.auth:
		return unlock_info
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		var characters = document.get_value("characters")
		if not characters:
			characters = {
				"unlocked_count": 1,
				"selected_character": 0,
				"unlock_notifications_shown": []
			}
		
		var unlock_notifications_shown = characters.get("unlock_notifications_shown", [])
		var current_unlocked = characters.get("unlocked_count", 1)
		
		# Ragna unlocks after completing dungeon 1 (when Dungeon 2 becomes available)
		if completed_dungeon_num == 1 and current_unlocked < 2:
			if not unlock_notifications_shown.has("ragna"):
				unlock_info.unlocked = true
				unlock_info.character_name = "Ragna"
				unlock_info.message = "New Character Unlocked: Ragna!\nA swift duelist with high damage but lower defenses."
				
				# Update character data
				characters["unlocked_count"] = 2
				unlock_notifications_shown.append("ragna")
				
				# Update Firebase with new character data
				document.add_or_update_field("characters", characters)
				var updated_doc = await collection.update(document)
				
				if updated_doc:
					print("BattleManager: Character Ragna unlocked!")
				else:
					print("BattleManager: Failed to update character unlock in Firebase")
	
	return unlock_info