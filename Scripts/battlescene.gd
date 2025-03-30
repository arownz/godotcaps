extends Node2D

# Preload all manager scripts to ensure they're defined before use
const BattleManagerScript = preload("res://Scripts/Manager/battle_manager.gd")
const EnemyManagerScript = preload("res://Scripts/Manager/enemy_manager.gd")
const PlayerManagerScript = preload("res://Scripts/Manager/player_manager.gd")
const LogManagerScript = preload("res://Scripts/Manager/battle_log_manager.gd")
const UIManagerScript = preload("res://Scripts/Manager/ui_manager.gd")
const ChallengeManagerScript = preload("res://Scripts/Manager/challenge_manager.gd")
const DungeonManagerScript = preload("res://Scripts/Manager/dungeon_manager.gd")

# Managers - references to specialized classes that handle different aspects of the game
var battle_manager
var enemy_manager
var player_manager
var log_manager
var ui_manager
var challenge_manager
var dungeon_manager

# Auto battle settings
var auto_battle_timer = null
var auto_battle_speed = 3.0  # SLOWER battle speed (increased from 1.5 to 3.0 seconds)

# Flags
var battle_active = false
var fresh_start = true

# Settings handle to load configurables
var settings

func _ready():
	# Initialize settings from GameSettings singleton if it exists
	if Engine.has_singleton("GameSettings"):
		settings = Engine.get_singleton("GameSettings")
		auto_battle_speed = settings.default_battle_speed
	
	# Initialize managers
	_initialize_managers()
	
	# Connect to signals
	_connect_signals()
	
	# Initialize UI
	ui_manager.initialize_ui()
	
	# Display introduction messages
	if fresh_start:
		log_manager.display_introduction_messages()
	
	# Create auto battle timer
	_setup_auto_battle_timer()
	
	# Initialize stats from testing panel (if available)
	if has_node("StatsTester"):
		_update_stats_from_tester()
	
	# Hide the StatsTester panel
	$StatsTester.visible = false

func _initialize_managers():
	# Create all managers with reference to this scene
	battle_manager = BattleManagerScript.new(self)
	enemy_manager = EnemyManagerScript.new(self)
	player_manager = PlayerManagerScript.new(self)
	log_manager = LogManagerScript.new(self)
	ui_manager = UIManagerScript.new(self)
	challenge_manager = ChallengeManagerScript.new(self)
	dungeon_manager = DungeonManagerScript.new(self)
	
	# Add managers as children
	add_child(battle_manager)
	add_child(enemy_manager)
	add_child(player_manager)
	add_child(log_manager)
	add_child(ui_manager)
	add_child(challenge_manager)
	add_child(dungeon_manager)
	
	# Set up the enemy based on current stage and dungeon
	enemy_manager.setup_enemy()
	
	# Let the dungeon manager initialize
	dungeon_manager.initialize()

func _connect_signals():
	# Connect UI elements - add checks to prevent duplicate connections
	var engage_button = $MainContainer/RightContainer/MarginContainer/VBoxContainer/ButtonContainer/EngageButton
	if !engage_button.is_connected("pressed", _on_engage_button_pressed):
		engage_button.pressed.connect(_on_engage_button_pressed)
	
	var stats_toggle_button = $MainContainer/BattleAreaContainer/StatsToggleButton
	if !stats_toggle_button.is_connected("pressed", _on_stats_toggle_button_pressed):
		stats_toggle_button.pressed.connect(_on_stats_toggle_button_pressed)
	
	# Connect scroll container to detect user scrolling
	var scroll_container = $MainContainer/RightContainer/MarginContainer/VBoxContainer/BattleLogContainer/ScrollContainer
	var scroll_bar = scroll_container.get_v_scroll_bar()
	if !scroll_bar.is_connected("value_changed", log_manager._on_scroll_value_changed):
		scroll_bar.value_changed.connect(log_manager._on_scroll_value_changed)
	
	# Connect manager signals
	_connect_manager_signals()

func _connect_manager_signals():
	# BattleManager signals
	battle_manager.player_attack_performed.connect(_on_player_attack_performed)
	battle_manager.enemy_attack_performed.connect(_on_enemy_attack_performed)
	battle_manager.victory_achieved.connect(_on_victory_achieved)
	battle_manager.enemy_skill_triggered.connect(_on_enemy_skill_triggered)
	battle_manager.challenge_started.connect(_on_challenge_started)
	
	# EnemyManager signals
	enemy_manager.enemy_health_changed.connect(_on_enemy_health_changed)
	enemy_manager.enemy_defeated.connect(_on_enemy_defeated)
	enemy_manager.enemy_skill_meter_changed.connect(_on_enemy_skill_meter_changed)
	enemy_manager.enemy_set_up.connect(_on_enemy_set_up)
	
	# PlayerManager signals
	player_manager.player_health_changed.connect(_on_player_health_changed)
	player_manager.player_defeated.connect(_on_player_defeated)
	player_manager.player_experience_changed.connect(_on_player_experience_changed)
	player_manager.player_level_up.connect(_on_player_level_up)
	
	# DungeonManager signals
	dungeon_manager.stage_advanced.connect(_on_stage_advanced)
	dungeon_manager.dungeon_advanced.connect(_on_dungeon_advanced)

# Signal callbacks
func _on_player_attack_performed(damage):
	enemy_manager.take_damage(damage)

func _on_enemy_attack_performed(damage):
	player_manager.take_damage(damage)
	enemy_manager.increase_skill_meter(25)

func _on_enemy_health_changed(_current_health, _max_health):
	ui_manager.update_enemy_health()

func _on_player_health_changed(_current_health, _max_health):
	ui_manager.update_player_health()

func _on_enemy_defeated(_exp_reward):
	battle_active = false
	battle_manager.handle_victory()

func _on_victory_achieved(exp_reward):
	battle_active = false
	log_manager.add_message("[color=#4CAF50]Victory! You defeated the enemy and gained " + str(exp_reward) + " experience.[/color]")

func _on_player_defeated():
	battle_active = false
	battle_manager.show_endgame_screen("Defeat")

func _on_player_experience_changed(_current_exp, _max_exp):
	ui_manager.update_player_exp()

func _on_player_level_up(new_level):
	log_manager.add_message("[color=#4CAF50]Congratulations! You reached level " + str(new_level) + "![/color]")

func _on_enemy_skill_meter_changed(_value):
	ui_manager.update_enemy_skill_meter()

func _on_enemy_skill_triggered():
	# Remove references to challenge buttons container
	# Nothing to do here now as we don't need to show buttons
	pass

func _on_challenge_started(challenge_type):
	# Handle challenge start
	challenge_manager.challenge_type = challenge_type

func _on_stage_advanced(_dungeon_num, _stage_num):
	ui_manager.update_stage_info()

func _on_dungeon_advanced(dungeon_num):
	ui_manager.update_background(dungeon_num)
	log_manager.add_message("[color=#4CAF50]You've entered a new dungeon! Prepare for stronger enemies.[/color]")

func _on_enemy_set_up(_enemy_name, _enemy_type):
	ui_manager.initialize_enemy_ui()

func _setup_auto_battle_timer():
	auto_battle_timer = Timer.new()
	auto_battle_timer.one_shot = true
	auto_battle_timer.wait_time = auto_battle_speed
	auto_battle_timer.timeout.connect(_auto_battle_turn)
	add_child(auto_battle_timer)

func _on_engage_button_pressed():
	if battle_active:
		return
		
	battle_active = true
	
	# Get the engage button and make it transparent/disabled looking
	var engage_button = $MainContainer/RightContainer/MarginContainer/VBoxContainer/ButtonContainer/EngageButton
	engage_button.disabled = true
	engage_button.modulate = Color(1, 1, 1, 0.5) # 50% transparency
	
	# Also update the label
	var engage_label = engage_button.get_node("EngageLabel")
	if engage_label:
		engage_label.modulate = Color(1, 1, 1, 0.5)
	
	# Add battle log message
	log_manager.add_message("Battle started! You engage the " + enemy_manager.enemy_name + ".")
	
	# Show FIGHT! label with animation
	ui_manager.show_fight_animation(_start_auto_battle)

func _start_auto_battle():
	$MainContainer/BattleAreaContainer/FightLabel.visible = false
	$MainContainer/BattleAreaContainer/FightLabel.modulate = Color(1, 1, 1, 1)
	
	# Add battle log message
	log_manager.add_message("The turn-based battle begins!")
	
	# Start the automatic battle sequence after a short delay
	await get_tree().create_timer(0.2).timeout
	_auto_battle_turn()

func _auto_battle_turn():
	if !battle_active:
		return
		
	# Player attacks first
	battle_manager.player_attack()
	
	# Check if enemy is defeated
	if enemy_manager.enemy_health <= 0:
		battle_active = false
		battle_manager.handle_victory()
		return
	
	# After a small delay, enemy attacks
	await get_tree().create_timer(0.8).timeout
	battle_manager.enemy_attack()
	
	# Check if player is defeated
	if player_manager.player_health <= 0:
		battle_active = false
		battle_manager.show_endgame_screen("Defeat")
		return
		
	# Check if enemy skill is ready
	if enemy_manager.enemy_skill_meter >= 100:
		await get_tree().create_timer(0.3).timeout
		battle_manager.trigger_enemy_skill()
		return
	
	# Continue battle after delay
	auto_battle_timer.start()

func _update_stats_from_tester():
	var tester = $StatsTester
	
	# Update using the managers
	enemy_manager.update_from_tester(tester)
	player_manager.update_from_tester(tester)
	
	# Update battle speed
	auto_battle_speed = tester.get_battle_speed()
	auto_battle_timer.wait_time = auto_battle_speed

func _on_stats_updated():
	_update_stats_from_tester()

func _on_stats_toggle_button_pressed():
	$StatsTester.visible = !$StatsTester.visible

func _on_word_challenge_completed(_bonus_damage):
	# Show engage button again with normal appearance
	var engage_button = $MainContainer/RightContainer/MarginContainer/VBoxContainer/ButtonContainer/EngageButton
	engage_button.visible = true
	engage_button.disabled = false
	engage_button.modulate = Color(1, 1, 1, 1) # 100% opacity
	
	# Also update the label
	var engage_label = engage_button.get_node("EngageLabel")
	if engage_label:
		engage_label.modulate = Color(1, 1, 1, 1)

func _on_word_challenge_failed():
	# Show engage button again with normal appearance
	var engage_button = $MainContainer/RightContainer/MarginContainer/VBoxContainer/ButtonContainer/EngageButton
	engage_button.visible = true
	engage_button.disabled = false
	engage_button.modulate = Color(1, 1, 1, 1) # 100% opacity
	
	# Also update the label
	var engage_label = engage_button.get_node("EngageLabel")
	if engage_label:
		engage_label.modulate = Color(1, 1, 1, 1)

# Used from inspector to change player skin
func change_player_appearance(skin_name: String) -> bool:
	return player_manager.change_player_skin(skin_name)
