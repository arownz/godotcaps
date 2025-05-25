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
	show_endgame_screen("Victory")

# Direct Firebase update after victory
func _update_firebase_after_victory(exp_gained: int):
	if !Firebase.Auth.auth:
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current user document to update it
	var task = collection.get_doc(user_id)
	if task:
		var document = await task
		if document:
			var current_data = document.doc_fields if document.has_method("doc_fields") else {}
			
			# Update enemies defeated count
			if current_data.has("dungeons") and current_data.dungeons.has("progress"):
				current_data.dungeons.progress.enemies_defeated = current_data.dungeons.progress.get("enemies_defeated", 0) + 1
			
			# Update player stats (experience and level)
			if current_data.has("stats") and current_data.stats.has("player"):
				var current_exp = current_data.stats.player.get("exp", 0)
				var current_level = current_data.stats.player.get("level", 1)
				var new_exp = current_exp + exp_gained
				
				# Handle level ups (100 exp per level)
				var exp_per_level = 100
				while new_exp >= exp_per_level:
					new_exp -= exp_per_level
					current_level += 1
					
					# Increase stats on level up
					current_data.stats.player.health = current_data.stats.player.get("health", 100) + 10
					current_data.stats.player.damage = current_data.stats.player.get("damage", 10) + 2
					current_data.stats.player.durability = current_data.stats.player.get("durability", 5) + 1
				
				# Update experience and level
				current_data.stats.player.exp = new_exp
				current_data.stats.player.level = current_level
			
			# Save updated data back to Firebase
			collection.add(user_id, current_data)

func handle_defeat():
	print("BattleManager: Handling defeat")
	
	# Add defeat message
	battle_scene.battle_log_manager.add_message("[color=#FF0000]Defeat! You have been defeated by the enemy.[/color]")
	
	# Wait a moment for the message to be seen
	await battle_scene.get_tree().create_timer(1.0).timeout
	
	# Show defeat screen
	show_endgame_screen("Defeat")

func show_endgame_screen(result_type: String):
	var endgame_scene = load("res://Scenes/EndgameScreen.tscn").instantiate()
	battle_scene.add_child(endgame_scene)
	endgame_scene.setup_endgame(result_type)

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