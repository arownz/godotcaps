class_name BattleManager
extends Node

# Add signals for better decoupling
signal player_attack_performed(damage)
signal enemy_attack_performed(damage)
signal enemy_skill_triggered

var battle_scene # Reference to the main battle scene

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
	# Use the player animation from player_manager instead of direct node access
	if !battle_scene.player_manager.player_animation:
		print("ERROR: Player animation not found")
		emit_signal("player_attack_performed", battle_scene.player_manager.player_damage)
		return
		
	var player_node = battle_scene.player_manager.player_animation
	var original_position = player_node.position
	
	var player_attack_tween = create_tween()
	player_attack_tween.tween_property(player_node, "position", original_position + Vector2(50, 0), 0.3) # Move right
	player_attack_tween.tween_property(player_node, "position", original_position, 0.2) # Return to original position
	
	# Play attack animation
	var sprite = player_node.get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.play("auto_attack")
	
	await player_attack_tween.finished
	
	# Reset to idle animation after attack
	if sprite:
		sprite.play("battle_idle")
		
	emit_signal("player_attack_performed", battle_scene.player_manager.player_damage)

func enemy_attack():
	# Use the enemy animation from enemy_manager instead of direct node access
	if !battle_scene.enemy_manager.enemy_animation:
		print("ERROR: Enemy animation not found")
		emit_signal("enemy_attack_performed", battle_scene.enemy_manager.enemy_damage)
		return
		
	var enemy_node = battle_scene.enemy_manager.enemy_animation
	var original_position = enemy_node.position
	
	var enemy_attack_tween = create_tween()
	enemy_attack_tween.tween_property(enemy_node, "position", original_position - Vector2(80, 0), 0.3) # Move left
	enemy_attack_tween.tween_property(enemy_node, "position", original_position, 0.2) # Return to original position
	
	# Play attack animation
	var sprite = enemy_node.get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.play("auto_attack")
	
	await enemy_attack_tween.finished
	
	# Reset to idle animation after attack
	if sprite:
		sprite.play("idle")
		
	emit_signal("enemy_attack_performed", battle_scene.enemy_manager.enemy_damage)

# Centralize all endgame handling here
func handle_victory():
	print("BattleManager: Handling victory")
	
	# Calculate experience reward - fix the enemy_level access
	var exp_reward = 10  # Base experience
	if battle_scene.enemy_manager.has_method("get_enemy_level"):
		exp_reward = battle_scene.enemy_manager.get_enemy_level() * 10
	elif battle_scene.enemy_manager.get("enemy_level"):
		exp_reward = battle_scene.enemy_manager.enemy_level * 10
	
	# Award experience to player
	battle_scene.player_manager.add_experience(exp_reward)
	
	# Add victory message
	battle_scene.battle_log_manager.add_message("[color=#4CAF50]Victory! You defeated the enemy and gained " + str(exp_reward) + " experience.[/color]")
	
	# Update Firebase with victory data directly
	_update_firebase_after_victory(exp_reward)
	
	# Advance to next stage
	battle_scene.dungeon_manager.advance_stage()
	
	# Update stage info
	battle_scene.ui_manager.update_stage_info()
	
	# Wait a moment for the message to be seen
	await battle_scene.get_tree().create_timer(1.0).timeout
	
	# Show victory screen - only called once from here
	show_endgame_screen("Victory", exp_reward)

# Direct Firebase update after victory
func _update_firebase_after_victory(exp_gained: int):
	if !Firebase.Auth.auth:
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current user document to calculate updates
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		var current_data = {}
		for key in document.keys():
			if key != "error":
				current_data[key] = document.get_value(key)
		
		# Get current dungeon and stage info
		var dungeon_num = str(battle_scene.dungeon_manager.dungeon_num)
		var stage_num = battle_scene.dungeon_manager.stage_num
		
		# Get current player stats
		var stats = current_data.get("stats", {})
		var player_stats = stats.get("player", {})
		var current_exp = player_stats.get("exp", 0)
		var current_level = player_stats.get("level", 1)
		var current_health = player_stats.get("health", 100)
		var current_damage = player_stats.get("damage", 10)
		var current_durability = player_stats.get("durability", 5)
		
		# Calculate new experience and level
		var new_exp = current_exp + exp_gained
		var new_level = current_level
		
		# Handle level ups (100 exp per level)
		var exp_per_level = 100
		while new_exp >= exp_per_level:
			new_exp -= exp_per_level
			new_level += 1
			
			# Increase stats on level up
			current_health += 15
			current_damage += 8
			current_durability += 5
		
		# Get current stages completed for this dungeon
		var dungeons_data = current_data.get("dungeons", {})
		var completed_data = dungeons_data.get("completed", {})
		var dungeon_data = completed_data.get(dungeon_num, {"completed": false, "stages_completed": 0})
		var current_stages_completed = dungeon_data.get("stages_completed", 0)
		
		# Prepare update data
		var update_data = {
			"stats.player.exp": new_exp,
			"stats.player.level": new_level,
			"stats.player.health": current_health,
			"stats.player.damage": current_damage,
			"stats.player.durability": current_durability,
			"dungeons.progress.enemies_defeated": dungeons_data.get("progress", {}).get("enemies_defeated", 0) + 1
		}
		
		# Only update stage progression if this stage hasn't been completed before
		if stage_num > current_stages_completed:
			update_data["dungeons.completed." + dungeon_num + ".stages_completed"] = stage_num
			if stage_num >= 5:
				update_data["dungeons.completed." + dungeon_num + ".completed"] = true
			print("Updated stages_completed for dungeon " + dungeon_num + " to stage " + str(stage_num))
		
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
			else:
				print("Failed to update Firebase progression")
		else:
			print("Failed to get document for progression update")

func handle_defeat():
	print("BattleManager: Handling defeat")
	
	# Add defeat message
	battle_scene.battle_log_manager.add_message("[color=#FF0000]Defeat! You have been defeated by the enemy.[/color]")
	
	# Wait a moment for the message to be seen
	await battle_scene.get_tree().create_timer(1.0).timeout
	
	# Show defeat screen
	show_endgame_screen("Defeat")

func show_endgame_screen(result_type: String, exp_reward: int = 0):
	var endgame_scene = load("res://Scenes/EndgameScreen.tscn").instantiate()
	
	# Position in center of BattleContainer
	var battle_container = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer")
	battle_container.add_child(endgame_scene)
	
	# Center the endgame screen within the BattleContainer
	endgame_scene.anchors_preset = Control.PRESET_FULL_RECT
	endgame_scene.offset_left = 0
	endgame_scene.offset_top = 0
	endgame_scene.offset_right = 0
	endgame_scene.offset_bottom = 0
	
	var dungeon_num = battle_scene.dungeon_manager.dungeon_num
	var stage_num = battle_scene.dungeon_manager.stage_num
	endgame_scene.setup_endgame(result_type, dungeon_num, stage_num, exp_reward)
	
	# Connect EndgameScreen signals
	endgame_scene.restart_battle.connect(_on_restart_battle)
	endgame_scene.quit_to_menu.connect(_on_quit_to_menu)
	endgame_scene.continue_battle.connect(_on_continue_battle)

func _on_restart_battle():
	# Reset game state
	battle_scene.dungeon_manager.reset()
	
	# Reload the battle scene
	battle_scene.get_tree().reload_current_scene()

func _on_quit_to_menu():
	# Return to main menu
	battle_scene.get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_continue_battle():
	# Check if there are more stages in this dungeon
	var current_stage = battle_scene.dungeon_manager.stage_num
	var max_stages = 5
	
	if current_stage < max_stages:
		# Advance to next stage
		battle_scene.dungeon_manager.stage_num += 1
		
		# Update current stage in Firebase
		_update_current_stage_in_firebase(battle_scene.dungeon_manager.stage_num)
		
		# Reset battle state and setup new enemy
		battle_scene.battle_active = false
		
		# Setup enemy for new stage before reloading scene
		print("Setting up enemy for new stage: ", battle_scene.dungeon_manager.stage_num)
		
		# Reload battle scene with new stage
		battle_scene.get_tree().reload_current_scene()
	else:
		# Completed all stages, return to dungeon map
		var dungeon_num = battle_scene.dungeon_manager.dungeon_num
		var dungeon_map_scene = ""
		match dungeon_num:
			1: dungeon_map_scene = "res://Scenes/Dungeon1Map.tscn"
			2: dungeon_map_scene = "res://Scenes/Dungeon2Map.tscn"
			3: dungeon_map_scene = "res://Scenes/Dungeon3Map.tscn"
		
		battle_scene.get_tree().change_scene_to_file(dungeon_map_scene)

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
	
	# Show enemy skill label
	var enemy_skill_label = battle_scene.get_node_or_null("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemySkillLabel")
	if enemy_skill_label:
		enemy_skill_label.visible = true
	
	# Add battle log message
	battle_scene.battle_log_manager.add_message("[color=#EB5E4B]The " + battle_scene.enemy_manager.enemy_name + " is preparing a special attack![/color]")
	
	# Emit signal
	emit_signal("enemy_skill_triggered")
	
	# Start word challenge - FIXED: Use challenge_manager
	var challenge_type = "whiteboard" if randf() < 0.5 else "stt"
	battle_scene.battle_log_manager.add_message("[color=#F09C2D]Counter by " + ("writing" if challenge_type == "whiteboard" else "speaking") + " the word![/color]")
	
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

func _on_challenge_failed():
	battle_scene.challenge_manager.handle_challenge_failed()

func _on_challenge_cancelled():
	battle_scene.challenge_manager.handle_challenge_cancelled()