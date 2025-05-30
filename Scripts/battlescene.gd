extends Node2D

# Preload all manager scripts to ensure they're defined before use
const BattleManagerScript = preload("res://Scripts/Manager/battle_manager.gd")
const EnemyManagerScript = preload("res://Scripts/Manager/enemy_manager.gd")
const PlayerManagerScript = preload("res://Scripts/Manager/player_manager.gd")
const BattleLogManagerScript = preload("res://Scripts/Manager/battle_log_manager.gd")
const UIManagerScript = preload("res://Scripts/Manager/ui_manager.gd")
const ChallengeManagerScript = preload("res://Scripts/Manager/challenge_manager.gd")
const DungeonManagerScript = preload("res://Scripts/Manager/dungeon_manager.gd")

# Managers
var battle_manager  
var enemy_manager
var player_manager
var battle_log_manager
var challenge_manager
var ui_manager
var dungeon_manager

# Battle state
var battle_active = false
var auto_battle = false
var auto_battle_timer = null
var auto_battle_speed = 5.0
var battle_result = ""
var fresh_start = true

# Challengef
var challenge_active = false

# References
@onready var engage_button = $MainContainer/RightContainer/MarginContainer/VBoxContainer/ButtonContainer/EngageButton
@onready var settings_button = $MainContainer/BattleAreaContainer/SettingButton
@onready var fight_label = $MainContainer/BattleAreaContainer/FightLabel
@onready var stage_info_label = $MainContainer/BattleAreaContainer/StageInfoLabel

# Add these missing variables at the top of the script
var dungeon_id = 1
var stage_id = 1
var document = null

func _ready():
	print("BattleScene: Starting battle scene initialization")
	
	# Initialize managers
	_initialize_managers()
	
	# Load player data from Firebase first
	await player_manager.load_player_data_from_firebase()
	
	# Debug: Print player stats after Firebase load
	print("BattleScene: After Firebase load - Player Level: ", player_manager.player_level, " Damage: ", player_manager.player_damage, " Health: ", player_manager.player_max_health)
	
	# Then initialize player with loaded data
	player_manager.initialize(self)
	
	# Debug: Print player stats after initialization
	print("BattleScene: After initialization - Player Level: ", player_manager.player_level, " Damage: ", player_manager.player_damage, " Health: ", player_manager.player_max_health)
	
	# Set up the battle
	_setup_battle()

func _initialize_managers():
	print("Initializing battle scene managers")
	
	# Create all managers with reference to this scene
	battle_manager = BattleManagerScript.new(self)
	enemy_manager = EnemyManagerScript.new(self)
	player_manager = PlayerManagerScript.new(self) # Pass the scene reference
	battle_log_manager = BattleLogManagerScript.new(self)
	ui_manager = UIManagerScript.new(self)
	challenge_manager = ChallengeManagerScript.new(self)
	dungeon_manager = DungeonManagerScript.new(self)
	
	# Add managers as children
	add_child(battle_manager)
	add_child(enemy_manager)
	add_child(player_manager)
	add_child(battle_log_manager)
	add_child(ui_manager)
	add_child(challenge_manager)
	add_child(dungeon_manager)
	
	# Initialize dungeon manager first to load current progression
	await dungeon_manager.initialize()
	
	# Set up the enemy based on current stage and dungeon
	enemy_manager.setup_enemy()
	
	print("Managers initialized successfully")

func _setup_battle():
	print("Setting up battle")
	
	# Connect all signals
	_connect_signals()
	
	# Setup auto battle timer
	_setup_auto_battle_timer()
	
	# Initialize UI with current managers
	ui_manager.initialize_ui()
	
	# Update player info in UI (username and level)
	ui_manager.update_player_info()
	
	# Display dungeon introduction messages
	battle_log_manager.display_introduction_messages()
	
	# Update stage info
	_update_stage_info()
	
	print("Battle setup complete")

func _connect_signals():
	# Connect UI elements - add checks to prevent duplicate connections
	if !engage_button.is_connected("pressed", _on_engage_button_pressed):
		engage_button.pressed.connect(_on_engage_button_pressed)
	
	# Connect settings button
	if !settings_button.is_connected("pressed", _on_settings_button_pressed):
		settings_button.pressed.connect(_on_settings_button_pressed)
	
	# Connect scroll container to detect user scrolling
	var scroll_container = $MainContainer/RightContainer/MarginContainer/VBoxContainer/BattleLogContainer/ScrollContainer
	if scroll_container:
		var scroll_bar = scroll_container.get_v_scroll_bar()
		if scroll_bar and battle_log_manager.has_method("_on_scroll_value_changed"):
			if !scroll_bar.is_connected("value_changed", battle_log_manager._on_scroll_value_changed):
				scroll_bar.value_changed.connect(battle_log_manager._on_scroll_value_changed)
	
	# Connect manager signals
	_connect_manager_signals()

func _connect_manager_signals():
	# BattleManager signals
	if battle_manager and battle_manager.has_signal("player_attack_performed"):
		battle_manager.player_attack_performed.connect(_on_player_attack_performed)
		battle_manager.enemy_attack_performed.connect(_on_enemy_attack_performed)
		battle_manager.enemy_skill_triggered.connect(_on_enemy_skill_triggered)
	
	# EnemyManager signals
	if enemy_manager and enemy_manager.has_signal("enemy_health_changed"):
		enemy_manager.enemy_health_changed.connect(_on_enemy_health_changed)
		enemy_manager.enemy_defeated.connect(battle_manager.handle_victory)
		enemy_manager.enemy_skill_meter_changed.connect(_on_enemy_skill_meter_changed)
		enemy_manager.enemy_set_up.connect(_on_enemy_set_up)
	
	# PlayerManager signals
	if player_manager and player_manager.has_signal("player_health_changed"):
		player_manager.player_health_changed.connect(_on_player_health_changed)
		player_manager.player_defeated.connect(_on_player_defeated)
		player_manager.player_experience_changed.connect(_on_player_experience_changed)
		player_manager.player_level_up.connect(_on_player_level_up)
	
	# DungeonManager signals
	if dungeon_manager:
		if dungeon_manager.has_signal("stage_advanced"):
			dungeon_manager.stage_advanced.connect(_on_stage_advanced)
		if dungeon_manager.has_signal("dungeon_advanced"):
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
	# Let battle_manager handle victory only - removed duplicate call
	# battle_manager.handle_victory() is called from enemy_manager signal

func _on_player_defeated():
	battle_active = false
	# Let battle_manager handle defeat
	battle_manager.handle_defeat()

func _on_player_experience_changed(_current_exp, _max_exp):
	ui_manager.update_player_exp()

func _on_player_level_up(new_level):
	# Get the stat increases from player_manager
	var health_increase = 20  # Based on get_max_health() calculation
	var damage_increase = 11  # Based on player_manager level up logic
	var durability_increase = 8  # Based on player_manager level up logic
	
	# Get current stats
	var new_health = player_manager.player_max_health
	var new_damage = player_manager.player_damage
	var new_durability = player_manager.player_durability
	
	# Use enhanced level-up message with emojis and colors
	battle_log_manager.add_level_up_message(new_level, health_increase, damage_increase, durability_increase, new_health, new_damage, new_durability)
	
	# Update power and durability bars when player levels up
	ui_manager.update_power_bar(player_manager.player_damage)
	ui_manager.update_durability_bar(player_manager.player_durability)

func _on_enemy_skill_meter_changed(_value):
	ui_manager.update_enemy_skill_meter()

func _on_enemy_skill_triggered():
	# Remove references to challenge buttons container
	# Nothing to do here now as we don't need to show buttons
	pass

func _on_stage_advanced(_dungeon_num, _stage_num):
	_update_stage_info()

func _on_dungeon_advanced(dungeon_num):
	ui_manager.update_background(dungeon_num)
	battle_log_manager.add_message("[color=#4CAF50]You've entered a new dungeon! Prepare for stronger enemies.[/color]")

func _on_enemy_set_up(_enemy_name, _enemy_type):
	ui_manager.initialize_enemy_ui()

func _setup_auto_battle_timer():
	auto_battle_timer = Timer.new()
	auto_battle_timer.one_shot = true
	auto_battle_timer.wait_time = 2.0 # Default to a faster battle speed
	auto_battle_timer.timeout.connect(_on_auto_battle_timer_timeout)
	add_child(auto_battle_timer)

# Engage button pressed - directly start auto battle and consume energy
func _on_engage_button_pressed():
	if battle_active:
		return
	
	# Consume energy before starting battle
	if !await _consume_battle_energy():
		return  # Not enough energy, don't start battle
	
	# Start the actual battle
	_start_battle()

func _show_battle_settings_popup():
	# Load the popup scene dynamically
	var battle_settings_popup_scene = load("res://Scenes/BattleSettingsPopup.tscn")
	if battle_settings_popup_scene == null:
		print("Failed to load BattleSettingsPopup scene, starting battle directly")
		await _consume_battle_energy()
		_start_battle()
		return
		
	var popup = battle_settings_popup_scene.instantiate()
	
	# Set energy cost (2 energy per battle)
	popup.set_energy_cost(2)
	
	# Connect signals
	popup.engage_confirmed.connect(_on_engage_confirmed)
	popup.quit_requested.connect(_on_battle_quit_requested)
	
	# Add to scene tree
	get_tree().current_scene.add_child(popup)

func _on_engage_confirmed():
	# Consume energy before starting battle
	if !await _consume_battle_energy():
		return  # Not enough energy, don't start battle
	
	# Start the actual battle
	_start_battle()

func _on_battle_quit_requested():
	# Player chose not to engage, return to dungeon map
	print("Player quit battle engagement, returning to dungeon")
	
	# Determine which dungeon to return to based on current dungeon_id
	var dungeon_scene_path = ""
	match dungeon_id:
		1:
			dungeon_scene_path = "res://Scenes/Dungeon1Map.tscn"
		2:
			dungeon_scene_path = "res://Scenes/Dungeon2Map.tscn"
		3:
			dungeon_scene_path = "res://Scenes/Dungeon3Map.tscn"
		_:
			# Default to dungeon selection if unknown
			dungeon_scene_path = "res://Scenes/DungeonSelection.tscn"
	
	get_tree().change_scene_to_file(dungeon_scene_path)

func _start_battle():
	if battle_active:
		return
	
	battle_active = true
	
	# Get the engage button and make it transparent/disabled looking
	engage_button.disabled = true
	engage_button.modulate = Color(1, 1, 1, 0.5) # 50% transparency
	
	# Add battle log message
	battle_log_manager.add_message("[color=#000000]Battle started! You engage the " + enemy_manager.enemy_name + ".[/color]")

	# Show "FIGHT!" message
	fight_label.visible = true
	
	# Show fight animation
	ui_manager.show_fight_animation(_start_auto_battle)

func _start_auto_battle():
	fight_label.visible = false
	fight_label.modulate = Color(1, 1, 1, 1)
	
	# Add battle log message
	battle_log_manager.add_message("[color=#000000]The turn-based battle begins![/color]")

	# Start the automatic battle sequence after a short delay
	await get_tree().create_timer(0.1).timeout
	_auto_battle_turn()

func _auto_battle_turn():
	if !battle_active:
		return
	# Make sure player and enemy animations exist before proceeding
	if !player_manager.player_animation or !enemy_manager.enemy_animation:
		print("ERROR: Missing player or enemy animation, re-initializing...")
		
		# Try to reload animations
		if !player_manager.player_animation:
			player_manager.load_player_animation()
			
		if !enemy_manager.enemy_animation:
			enemy_manager.load_enemy_animation()
			
		# If still missing, show error and stop battle
		if !player_manager.player_animation or !enemy_manager.enemy_animation:
			battle_log_manager.add_message("[color=#FF0000]Error: Could not load animations. Please restart the battle.[/color]")
			battle_active = false
			return
	
	# Player attacks first
	print("Player attacking with damage: " + str(player_manager.player_damage))
	battle_manager.player_attack()
	
	# Give a brief pause for animation
	await get_tree().create_timer(0.8).timeout
	
	# Check if enemy is defeated
	if enemy_manager.enemy_health <= 0:
		battle_active = false
		battle_manager.handle_victory()
		return
	
	# After a small delay, enemy attacks
	print("Enemy attacking with damage: " + str(enemy_manager.enemy_damage))
	battle_manager.enemy_attack()
	
	# Give a brief pause for animation
	await get_tree().create_timer(0.8).timeout
	
	# Check if enemy skill is ready
	if enemy_manager.enemy_skill_meter >= enemy_manager.enemy_skill_threshold:
		await get_tree().create_timer(0.5).timeout
		battle_manager.trigger_enemy_skill()
		return
	
	# Continue battle after delay - make it a shorter delay for faster battles
	auto_battle_timer.wait_time = 1.0
	auto_battle_timer.start()

# Auto battle timer timeout (replaced from original code)
func _on_auto_battle_timer_timeout():
	if battle_active:
		_auto_battle_turn()

# Toggle auto battle
func _toggle_auto_battle():
	auto_battle = !auto_battle

	if auto_battle and battle_active:
		auto_battle_timer.start()
		battle_log_manager.add_message("[color=#000000]Auto battle activated![/color]")
	else:
		battle_log_manager.add_message("[color=#000000]Auto battle deactivated![/color]")

# Update stage info label
func _update_stage_info():
	# Use dungeon manager's current values directly
	var dungeon_num = dungeon_manager.dungeon_num
	var stage_num = dungeon_manager.stage_num
	
	# Update the stage info label using the existing @onready reference
	if stage_info_label:
		var stage_type = "Boss" if stage_num == 5 else "Stage"
		stage_info_label.text = "Dungeon " + str(dungeon_num) + " - " + stage_type + " " + str(stage_num)
		print("BattleScene: Updated stage info to: ", stage_info_label.text)
	
	# Also update the UI manager
	ui_manager.update_stage_info()

func _on_word_challenge_completed(_bonus_damage):
	print("Word challenge completed with bonus damage: " + str(_bonus_damage))

func _on_word_challenge_failed():
	print("Word challenge failed")


# Direct Firebase challenge stats update - FIXED shadowed variable warning
func _update_firebase_challenge_stats(challenge_type: String, success: bool):
	if !Firebase.Auth.auth:
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document to preserve other fields - using the same approach as ProfilePopUp.gd
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		print("BattleScene: Document retrieved successfully for challenge stats update")
		
		# Get current word_challenges structure or create default
		var word_challenges = user_doc.get_value("word_challenges")
		if word_challenges == null or typeof(word_challenges) != TYPE_DICTIONARY:
			word_challenges = {
				"completed": {"stt": 0, "whiteboard": 0},
				"failed": {"stt": 0, "whiteboard": 0}
			}
		
		# Ensure nested structure exists
		if !word_challenges.has("completed"):
			word_challenges["completed"] = {"stt": 0, "whiteboard": 0}
		if !word_challenges.has("failed"):
			word_challenges["failed"] = {"stt": 0, "whiteboard": 0}
		
		# Update the specific challenge type and success/failure count
		if success:
			if challenge_type == "stt":
				word_challenges.completed.stt += 1
			elif challenge_type == "whiteboard":
				word_challenges.completed.whiteboard += 1
		else:
			if challenge_type == "stt":
				word_challenges.failed.stt += 1
			elif challenge_type == "whiteboard":
				word_challenges.failed.whiteboard += 1
		
		# Update the document field using the correct method (same as ProfilePopUp.gd)
		user_doc.add_or_update_field("word_challenges", word_challenges)
		
		# Save back to Firebase using update method (NOT add)
		var updated_document = await collection.update(user_doc)
		if updated_document:
			print("BattleScene: Successfully updated word challenge stats for " + challenge_type + " - success: " + str(success))
		else:
			print("BattleScene: Failed to update word challenge stats")
	else:
		print("BattleScene: Failed to get user document for challenge stats update")

func get_current_dungeon() -> int:
	return dungeon_id

func get_current_stage() -> int:
	return stage_id

func _on_settings_button_pressed():
	print("Settings button pressed - showing battle settings popup")
	_show_battle_settings_popup()

func _consume_battle_energy() -> bool:
	# Check if player has enough energy (2 energy required)
	if !Firebase.Auth.auth:
		return true  # Allow battle if not authenticated
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var stats_data = user_doc.get_value("stats")
		if stats_data != null and typeof(stats_data) == TYPE_DICTIONARY and stats_data.has("player"):
			var player_data = stats_data["player"]
			var current_energy = player_data.get("energy", 0)
			
			# Check if player has enough energy
			if current_energy < 2:
				print("Not enough energy: " + str(current_energy) + "/2 required")
				return false
			
			# Consume 2 energy
			player_data["energy"] = current_energy - 2
			stats_data["player"] = player_data
			user_doc.add_or_update_field("stats", stats_data)
			
			# Update document in Firebase
			var updated_doc = await collection.update(user_doc)
			if updated_doc:
				print("Energy consumed: 2 energy. Remaining: " + str(current_energy - 2))
				return true
			else:
				print("Failed to update energy in Firebase")
				return false
		else:
			print("No player stats found in Firebase")
			return false
	else:
		print("Failed to get user document")
		return false

func _input(event):
	# Handle input for different functions
	if event.is_action_pressed("ui_cancel"):  # ESC key
		_show_battle_settings_popup()
	
	# Temporary test for Firebase level-up updates
	if event.is_action_pressed("ui_accept"):  # Enter key
		print("Testing Firebase level-up updates...")
		await player_manager.test_firebase_level_up()
		
	# Test battle exp gain and Firebase update (F1 key)
	if event.is_action_pressed("ui_home"):  # F1 key
		print("Testing battle exp gain and Firebase update...")
		await player_manager.test_battle_exp_gain()
