class_name BattleManager
extends Node

# Add signals for better decoupling
signal player_attack_performed(damage)
signal enemy_attack_performed(damage)
signal victory_achieved(exp_reward)
signal enemy_skill_triggered
signal challenge_started(challenge_type)
signal battle_continued
signal battle_restarted
signal battle_quit

var battle_scene  # Reference to the main battle scene

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
	var player_sprite = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/Player")
	var original_position = player_sprite.position
	
	var player_attack_tween = create_tween()
	player_attack_tween.tween_property(player_sprite, "position", original_position + Vector2(50, 0), 0.3)  # Move right
	player_attack_tween.tween_property(player_sprite, "position", original_position, 0.2)  # Return to original position
	
	await player_attack_tween.finished
	emit_signal("player_attack_performed", battle_scene.player_manager.player_damage)

func enemy_attack():
	var enemy_sprite = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/Enemy")
	var original_position = enemy_sprite.position
	
	var enemy_attack_tween = create_tween()
	enemy_attack_tween.tween_property(enemy_sprite, "position", original_position - Vector2(50, 0), 0.3)  # Move left
	enemy_attack_tween.tween_property(enemy_sprite, "position", original_position, 0.2)  # Return to original position
	
	await enemy_attack_tween.finished
	emit_signal("enemy_attack_performed", battle_scene.enemy_manager.enemy_damage)

func trigger_enemy_skill():
	# Show the enemy skill label
	battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemySkillLabel").visible = true
	
	# Hide engage button 
	battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/ButtonContainer/EngageButton").visible = false
	
	# Add battle log message
	battle_scene.log_manager.add_message("[color=#EB5E4B]The " + battle_scene.enemy_manager.enemy_name + " is preparing a special attack![/color]")
	
	# Emit signal that skill is triggered
	emit_signal("enemy_skill_triggered")
	
	# Randomize between whiteboard and speech challenges
	if randf() < 0.5:
		emit_signal("challenge_started", "whiteboard")
		_show_whiteboard_challenge()
		battle_scene.log_manager.add_message("[color=#F09C2D]Counter by writing the word![/color]")
	else:
		emit_signal("challenge_started", "speech")
		_show_speech_to_text_challenge()
		battle_scene.log_manager.add_message("[color=#F09C2D]Counter by speaking the word![/color]")

func _show_whiteboard_challenge():
	# Show whiteboard challenge
	if word_challenge_whiteboard_scene:
		# Create a fullscreen overlay
		var overlay = ColorRect.new()
		overlay.name = "ChallengeOverlay"
		overlay.color = Color(0, 0, 0, 0.6) # Semi-transparent black
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		battle_scene.add_child(overlay)
		
		# Instantiate the challenge
		current_word_challenge = word_challenge_whiteboard_scene.instantiate()
		battle_scene.add_child(current_word_challenge)
		
		# Center the panel immediately
		_center_popup(current_word_challenge)
		
		# Connect signals
		current_word_challenge.connect("challenge_completed", _on_word_challenge_completed)
		current_word_challenge.connect("challenge_failed", _on_word_challenge_failed)
	else:
		# Fallback if scene couldn't be loaded
		print("ERROR: Could not load WordChallengePanel_Whiteboard.tscn")
		# Skip the skill challenge
		_on_word_challenge_failed()

func _show_speech_to_text_challenge():
	# Show speech-to-text challenge
	if word_challenge_stt_scene:
		# Create a fullscreen overlay
		var overlay = ColorRect.new()
		overlay.name = "ChallengeOverlay"
		overlay.color = Color(0, 0, 0, 0.6) # Semi-transparent black
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		battle_scene.add_child(overlay)
		
		# Instantiate the challenge
		current_word_challenge = word_challenge_stt_scene.instantiate()
		battle_scene.add_child(current_word_challenge)
		
		# Center the panel immediately
		_center_popup(current_word_challenge)
		
		# Connect signals
		current_word_challenge.connect("challenge_completed", _on_word_challenge_completed)
		current_word_challenge.connect("challenge_failed", _on_word_challenge_failed)
	else:
		# Fallback if scene couldn't be loaded
		print("ERROR: Could not load WordChallengePanel_STT.tscn")
		# Skip the skill challenge
		_on_word_challenge_failed()

func _center_popup(popup: Control):
	# Defer the centering logic to ensure the popup is fully initialized
	call_deferred("_center_popup_deferred", popup)

func _center_popup_deferred(popup: Control):
	# Ensure the popup is still in the tree
	if not is_instance_valid(self) or not is_instance_valid(popup):
		return
	
	# Get the viewport size
	var viewport_size = battle_scene.get_viewport_rect().size
	
	# Calculate the center position
	var popup_size = popup.size
	var center_position = (viewport_size - popup_size) / 2
	
	# Set the popup's position
	popup.position = center_position

func _on_word_challenge_completed(bonus_damage):
	# Player successfully countered the enemy skill
	battle_scene.enemy_manager.enemy_health -= bonus_damage
	battle_scene.enemy_manager.enemy_health = max(0, battle_scene.enemy_manager.enemy_health)
	
	# Update UI
	battle_scene.ui_manager.update_enemy_health()
	
	# Add battle log message
	battle_scene.log_manager.add_message("[color=#4CAF50]You successfully countered the " + battle_scene.enemy_manager.enemy_name + "'s special attack![/color]")
	battle_scene.log_manager.add_message("You dealt " + str(bonus_damage) + " bonus damage!")
	
	# Reset enemy skill meter
	battle_scene.enemy_manager.enemy_skill_meter = 0
	battle_scene.ui_manager.update_enemy_skill_meter()
	
	# Hide the enemy skill label
	battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemySkillLabel").visible = false
	
	# Remove the overlay
	var overlay = battle_scene.get_node_or_null("ChallengeOverlay")
	if overlay:
		overlay.queue_free()
	
	# Show engage button again
	var engage_button = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/ButtonContainer/EngageButton")
	engage_button.visible = true
	engage_button.disabled = false
	engage_button.modulate = Color(1, 1, 1, 1) # 100% opacity
	
	# Check if enemy is defeated after counterattack
	if battle_scene.enemy_manager.enemy_health <= 0:
		battle_scene.battle_active = false
		battle_scene.log_manager.add_message("[color=#4CAF50]You defeated the " + battle_scene.enemy_manager.enemy_name + " with your counter-attack![/color]")
		handle_victory()
		return
	
	# Continue battle
	battle_scene.auto_battle_timer.start()

func _on_word_challenge_failed():
	# Player failed to counter - enemy deals full skill damage
	var full_skill_damage = battle_scene.enemy_manager.enemy_damage * 2
	battle_scene.player_manager.player_health -= full_skill_damage
	battle_scene.player_manager.player_health = max(0, battle_scene.player_manager.player_health)
	
	# Update UI
	battle_scene.ui_manager.update_player_health()
	
	# Add battle log message
	battle_scene.log_manager.add_message("[color=#EB5E4B]You failed to counter the " + battle_scene.enemy_manager.enemy_name + "'s special attack![/color]")
	battle_scene.log_manager.add_message("The " + battle_scene.enemy_manager.enemy_name + " dealt " + str(full_skill_damage) + " critical damage!")
	
	# Reset enemy skill meter
	battle_scene.enemy_manager.enemy_skill_meter = 0
	battle_scene.ui_manager.update_enemy_skill_meter()
	
	# Hide the enemy skill label
	battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemySkillLabel").visible = false
	
	# Remove the overlay
	var overlay = battle_scene.get_node_or_null("ChallengeOverlay")
	if overlay:
		overlay.queue_free()
	
	# Show engage button again
	var engage_button = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/ButtonContainer/EngageButton")
	engage_button.visible = true
	engage_button.disabled = false
	engage_button.modulate = Color(1, 1, 1, 1) # 100% opacity
	
	# Check if player is defeated
	if battle_scene.player_manager.player_health <= 0:
		battle_scene.battle_active = false
		battle_scene.log_manager.add_message("[color=#EB5E4B]You have been defeated by the " + battle_scene.enemy_manager.enemy_name + "![/color]")
		show_endgame_screen("Defeat")
		return
	
	# Continue battle
	battle_scene.auto_battle_timer.start()

func handle_victory():
	# Award experience points based on enemy type
	var exp_gained = battle_scene.enemy_manager.get_exp_reward()
	
	# Emit victory signal with experience reward
	emit_signal("victory_achieved", exp_gained)
	
	# Add victory messages to the battle log
	battle_scene.log_manager.add_message("[color=#4CAF50]You defeated the " + battle_scene.enemy_manager.enemy_name + "![/color]")
	battle_scene.log_manager.add_message("[color=#F5A623]You gained " + str(exp_gained) + " experience points![/color]")
	
	# Advance to next stage
	battle_scene.dungeon_manager.advance_stage()
	
	# Update stage info
	battle_scene.ui_manager.update_stage_info()
	
	# Show victory screen
	show_endgame_screen("Victory")

func show_endgame_screen(result):
	if endgame_screen_scene:
		var endgame_screen = endgame_screen_scene.instantiate()
		battle_scene.add_child(endgame_screen)
		endgame_screen.set_result(result)
		
		# For victory, provide additional options
		if result == "Victory":
			endgame_screen.set_continue_enabled(true)
			endgame_screen.connect("continue_battle", _on_continue_battle)
		
		endgame_screen.connect("restart_battle", _on_restart_battle)
		endgame_screen.connect("quit_to_menu", _on_quit_to_menu)
	else:
		print("ERROR: Could not load EndgameScreen.tscn")
		# Fallback - return to menu
		battle_scene.get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_restart_battle():
	# Reset game state
	battle_scene.dungeon_manager.reset()
	
	# Emit signal that battle is restarted
	emit_signal("battle_restarted")
	
	# Reload the battle scene
	battle_scene.get_tree().reload_current_scene()

func _on_continue_battle():
	# Hide the endgame screen
	var endgame_screen = battle_scene.get_node_or_null("EndgameScreen")
	if endgame_screen:
		endgame_screen.queue_free()
	
	# Set up next enemy
	battle_scene.enemy_manager.setup_enemy()
	
	# Update UI for new enemy
	battle_scene.ui_manager.initialize_enemy_ui()
	
	# Add introduction message for the new enemy
	battle_scene.log_manager.add_message("[color=#F5A623]Stage " + str(battle_scene.dungeon_manager.stage_num) + " begins![/color]")
	battle_scene.log_manager.add_message("A new enemy appears: " + battle_scene.enemy_manager.enemy_name + "!")
	
	# Check for dungeon progression
	if battle_scene.dungeon_manager.is_new_dungeon():
		battle_scene.log_manager.add_message("[color=#4CAF50]You've reached Dungeon " + str(battle_scene.dungeon_manager.dungeon_num) + "![/color]")
		battle_scene.log_manager.add_message("[color=#4CAF50]The enemies will be stronger here, but the rewards greater![/color]")
	
	# Check for special enemy types
	match battle_scene.enemy_manager.enemy_type:
		"boss":
			battle_scene.log_manager.add_message("[color=#FF5252]WARNING: A powerful boss enemy has appeared![/color]")
		"elite":
			battle_scene.log_manager.add_message("[color=#5E9CF5]Caution: This is an elite enemy with enhanced abilities.[/color]")
	
	# Re-enable the engage button with normal appearance
	var engage_button = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/ButtonContainer/EngageButton")
	engage_button.visible = true
	engage_button.disabled = false
	engage_button.modulate = Color(1, 1, 1, 1) # 100% opacity
	
	# Emit signal that battle is continuing to next stage
	emit_signal("battle_continued")

func _on_quit_to_menu():
	# Emit signal that battle is quit
	emit_signal("battle_quit")
	
	# Return to main menu
	battle_scene.get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

# Add a debug method to test health updates
func debug_damage_test():
	# Deal a small amount of damage to both entities to test health bars
	print("DEBUG: Testing damage with small damage...")
	
	# Emit signals for player and enemy taking small damage
	emit_signal("player_attack_performed", 15)  # Player deals 15 damage
	emit_signal("enemy_attack_performed", 10)  # Enemy deals 10 damage
	
	# Wait a moment and then check health values
	await battle_scene.get_tree().create_timer(0.5).timeout
	
	print("Player health: ", battle_scene.player_manager.player_health, "/", 
		  battle_scene.player_manager.player_max_health)
	print("Enemy health: ", battle_scene.enemy_manager.enemy_health, "/", 
		  battle_scene.enemy_manager.enemy_max_health)
