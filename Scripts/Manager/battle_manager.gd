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
	enemy_attack_tween.tween_property(enemy_node, "position", original_position - Vector2(50, 0), 0.3) # Move left
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
	
	# Get current user document to update it
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		# Update enemies defeated count
		var dungeons = document.get_value("dungeons")
		if dungeons != null and typeof(dungeons) == TYPE_DICTIONARY:
			if dungeons.has("progress"):
				var progress = dungeons.progress
				progress.enemies_defeated = progress.get("enemies_defeated", 0) + 1
				# Update the document field
				document.add_or_update_field("dungeons", dungeons)
		
		# Update player stats (experience and level)
		var stats = document.get_value("stats")
		if stats != null and typeof(stats) == TYPE_DICTIONARY:
			if stats.has("player"):
				var player_stats = stats.player
				var current_exp = player_stats.get("exp", 0)
				var current_level = player_stats.get("level", 1)
				var new_exp = current_exp + exp_gained
				
				# Handle level ups (100 exp per level)
				var exp_per_level = 100
				while new_exp >= exp_per_level:
					new_exp -= exp_per_level
					current_level += 1
					
					# Increase stats on level up
					player_stats.health = player_stats.get("health", 100) + 15
					player_stats.damage = player_stats.get("damage", 10) + 8
					player_stats.durability = player_stats.get("durability", 5) + 5
				
				# Update experience and level
				player_stats.exp = new_exp
				player_stats.level = current_level
				
				# Update the document field
				document.add_or_update_field("stats", stats)
		
		# Save updated document back to Firebase using correct update method
		var updated_document = await collection.update(document)
		if updated_document:
			print("Firebase stats updated successfully")
		else:
			print("Failed to update Firebase stats")

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
	battle_scene.add_child(endgame_scene)
	var dungeon_num = battle_scene.dungeon_manager.dungeon_num
	var stage_num = battle_scene.dungeon_manager.stage_num
	endgame_scene.setup_endgame(result_type, dungeon_num, stage_num, exp_reward)

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

func _on_restart_battle():
	# Reset game state
	battle_scene.dungeon_manager.reset()
	
	# Emit signal that battle is restarted
	emit_signal("battle_restarted")
	
	# Reload the battle scene
	battle_scene.get_tree().reload_current_scene()