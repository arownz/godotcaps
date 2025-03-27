extends Node2D

var player_health = 100
var enemy_health = 100
var enemy_skill_meter = 0
var battle_active = false
var dungeon_num = 1
var stage_num = 1
var enemy_damage = 10
var player_damage = 15
var player_name = "Hero"
var enemy_name = "Slime"

# New variables for automatic combat
var auto_battle_timer = null
var auto_battle_speed = 1.5  # Time between attacks in seconds

# References to the scenes we'll instance
var word_challenge_scene = null  # Will be loaded in _ready
var endgame_screen_scene = null  # Will be loaded in _ready
var current_word_challenge = null

func _ready():
	# Load the scenes to avoid preload errors
	word_challenge_scene = load("res://Scenes/WordChallengePanel.tscn")
	endgame_screen_scene = load("res://Scenes/EndgameScreen.tscn")
	
	# Initialize UI
	$BattleContainer/PlayerContainer/PlayerName.text = player_name
	$BattleContainer/EnemyContainer/EnemyName.text = enemy_name
	
	$BattleContainer/PlayerContainer/PlayerHealth.value = player_health
	$BattleContainer/EnemyContainer/EnemyHealth.value = enemy_health
	$BattleContainer/EnemyContainer/EnemySkillMeter.value = enemy_skill_meter
	$StageInfoLabel.text = "Dungeon " + str(dungeon_num) + " - Stage " + str(stage_num)
	
	# Set max values for health bars
	$BattleContainer/PlayerContainer/PlayerHealth.max_value = player_health
	$BattleContainer/EnemyContainer/EnemyHealth.max_value = enemy_health
	
	# Make sure the enemy skill label is hidden initially
	$BattleContainer/EnemyContainer/EnemySkillLabel.visible = false
	
	# Initialize battle state
	battle_active = false
	
	# Reset positions
	$BattleContainer/PlayerContainer/Player.position.y = -200
	$BattleContainer/EnemyContainer/Enemy.position.y = -200
	
	# Create auto battle timer
	auto_battle_timer = Timer.new()
	auto_battle_timer.one_shot = true
	auto_battle_timer.wait_time = auto_battle_speed
	auto_battle_timer.connect("timeout", _auto_battle_turn)
	add_child(auto_battle_timer)
	
	# Initialize stats from testing panel (if available)
	if has_node("StatsTester"):
		_update_stats_from_tester()
	
	# Initially hide the StatsTester panel
	$StatsTester.visible = false

func _on_engage_button_pressed():
	if battle_active:
		return
		
	battle_active = true
	$BattleControls/EngageButton.disabled = true
	
	# Show FIGHT! label with animation
	$FightLabel.visible = true
	$FightLabel.scale = Vector2(1.0, 1.0)
	var tween = create_tween()
	tween.tween_property($FightLabel, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property($FightLabel, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_interval(0.5)
	tween.tween_property($FightLabel, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(_start_auto_battle)

func _start_auto_battle():
	$FightLabel.visible = false
	$FightLabel.modulate = Color(1, 1, 1, 1)
	
	# Start the automatic battle sequence
	_auto_battle_turn()

func _auto_battle_turn():
	if !battle_active:
		return
		
	# Player attacks first
	_player_attack()
	
	# Check if enemy is defeated
	if enemy_health <= 0:
		battle_active = false
		_show_endgame_screen("Victory")
		return
	
	# After a small delay, enemy attacks
	await get_tree().create_timer(0.8).timeout
	_enemy_attack()
	
	# Check if player is defeated
	if player_health <= 0:
		battle_active = false
		_show_endgame_screen("Defeat")
		return
		
	# Check if enemy skill is ready
	if enemy_skill_meter >= 100:
		await get_tree().create_timer(0.3).timeout
		_trigger_enemy_skill()
		return
	
	# Continue battle after delay
	auto_battle_timer.start()

func _player_attack():
	var player_attack_tween = create_tween()
	
	# Move player toward enemy
	player_attack_tween.tween_property($BattleContainer/PlayerContainer/Player, "position", 
		Vector2(300, -200), 0.3) # Move right
	player_attack_tween.tween_property($BattleContainer/PlayerContainer/Player, "position", 
		Vector2(0, -200), 0.2)    # Return to original position
	
	await player_attack_tween.finished
	
	enemy_health -= player_damage
	enemy_health = max(0, enemy_health)  # Ensure it doesn't go below 0
	$BattleContainer/EnemyContainer/EnemyHealth.value = enemy_health

func _enemy_attack():
	var enemy_attack_tween = create_tween()
	
	# Move enemy toward player
	enemy_attack_tween.tween_property($BattleContainer/EnemyContainer/Enemy, "position", 
		Vector2(-300, -200), 0.3) # Move left
	enemy_attack_tween.tween_property($BattleContainer/EnemyContainer/Enemy, "position", 
		Vector2(0, -200), 0.2)    # Return to original position
	
	await enemy_attack_tween.finished
	
	player_health -= enemy_damage
	player_health = max(0, player_health)  # Ensure it doesn't go below 0
	$BattleContainer/PlayerContainer/PlayerHealth.value = player_health
	
	# Increase enemy skill meter
	enemy_skill_meter += 25
	$BattleContainer/EnemyContainer/EnemySkillMeter.value = enemy_skill_meter

func _trigger_enemy_skill():
	# Show the enemy skill label when skill is triggered
	$BattleContainer/EnemyContainer/EnemySkillLabel.visible = true
	
	# Pause gameplay and show random word panel
	if word_challenge_scene:
		current_word_challenge = word_challenge_scene.instantiate()
		add_child(current_word_challenge)
		
		# Center the challenge panel on screen
		current_word_challenge.connect("ready", func(): 
			var panel = current_word_challenge.get_node("ChallengePanel")
			panel.position = Vector2(
				(get_viewport_rect().size.x - panel.size.x) / 2,
				(get_viewport_rect().size.y - panel.size.y) / 2
			)
		)
		
		current_word_challenge.connect("challenge_completed", _on_word_challenge_completed)
		current_word_challenge.connect("challenge_failed", _on_word_challenge_failed)
	else:
		# Fallback if scene couldn't be loaded
		print("ERROR: Could not load WordChallengePanel.tscn")
		# Skip the skill challenge
		_on_word_challenge_failed()

func _on_word_challenge_completed(bonus_damage):
	# Player successfully countered the enemy skill
	enemy_health -= bonus_damage
	enemy_health = max(0, enemy_health)
	$BattleContainer/EnemyContainer/EnemyHealth.value = enemy_health
	
	# Reset enemy skill meter
	enemy_skill_meter = 0
	$BattleContainer/EnemyContainer/EnemySkillMeter.value = enemy_skill_meter
	
	# Hide the enemy skill label
	$BattleContainer/EnemyContainer/EnemySkillLabel.visible = false
	
	# Check if enemy is defeated after counterattack
	if enemy_health <= 0:
		battle_active = false
		_show_endgame_screen("Victory")
		return
	
	# Continue battle
	auto_battle_timer.start()

func _on_word_challenge_failed():
	# Player failed to counter - enemy deals full skill damage
	player_health -= enemy_damage * 2
	player_health = max(0, player_health)
	$BattleContainer/PlayerContainer/PlayerHealth.value = player_health
	
	# Reset enemy skill meter
	enemy_skill_meter = 0
	$BattleContainer/EnemyContainer/EnemySkillMeter.value = enemy_skill_meter
	
	# Hide the enemy skill label
	$BattleContainer/EnemyContainer/EnemySkillLabel.visible = false
	
	# Check if player is defeated
	if player_health <= 0:
		battle_active = false
		_show_endgame_screen("Defeat")
		return
	
	# Continue battle
	auto_battle_timer.start()

func _show_endgame_screen(result):
	if endgame_screen_scene:
		var endgame_screen = endgame_screen_scene.instantiate()
		add_child(endgame_screen)
		endgame_screen.set_result(result)
		endgame_screen.connect("restart_battle", _on_restart_battle)
		endgame_screen.connect("quit_to_menu", _on_quit_to_menu)
	else:
		print("ERROR: Could not load EndgameScreen.tscn")
		# Fallback - return to menu
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_restart_battle():
	# Reload the battle scene
	get_tree().reload_current_scene()

func _on_quit_to_menu():
	# Return to main menu
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

# Update stats from the testing panel
func _update_stats_from_tester():
	var tester = $StatsTester
	
	# Update enemy stats
	enemy_health = tester.get_enemy_health()
	enemy_damage = tester.get_enemy_damage()
	
	# Update player stats
	player_health = tester.get_player_health()
	player_damage = tester.get_player_damage()
	
	# Update UI
	$BattleContainer/PlayerContainer/PlayerHealth.max_value = player_health
	$BattleContainer/PlayerContainer/PlayerHealth.value = player_health
	$BattleContainer/EnemyContainer/EnemyHealth.max_value = enemy_health
	$BattleContainer/EnemyContainer/EnemyHealth.value = enemy_health
	
	# Update skill label visibility if the function exists
	if tester.has_method("get_show_skill_label"):
		$BattleContainer/EnemyContainer/EnemySkillLabel.visible = tester.get_show_skill_label()

# Called when stats are changed in the testing panel
func _on_stats_updated():
	_update_stats_from_tester()

# New function to toggle the StatsTester panel visibility
func _on_stats_toggle_button_pressed():
	$StatsTester.visible = !$StatsTester.visible
