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
	
	# Then initialize player with loaded data
	player_manager.initialize(self)
	
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
	
	# Set up the enemy based on current stage and dungeon
	enemy_manager.setup_enemy()
	
	# Let the dungeon manager initialize
	dungeon_manager.initialize()
	
	print("Managers initialized successfully")

func _setup_battle():
	print("Setting up battle")
	
	# Connect all signals
	_connect_signals()
	
	# Setup auto battle timer
	_setup_auto_battle_timer()
	
	# Initialize UI with current managers
	ui_manager.initialize_ui()
	
	# Display dungeon introduction messages
	battle_log_manager.display_introduction_messages()
	
	# Update stage info
	_update_stage_info()
	
	print("Battle setup complete")

func _connect_signals():
	# Connect UI elements - add checks to prevent duplicate connections
	if !engage_button.is_connected("pressed", _on_engage_button_pressed):
		engage_button.pressed.connect(_on_engage_button_pressed)
	
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
		enemy_manager.enemy_defeated.connect(_on_enemy_defeated)
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
	# Remove redundant call - let battle_manager handle everything
	battle_manager.handle_victory()

func _on_player_defeated():
	battle_active = false
	# Let battle_manager handle defeat
	battle_manager.handle_defeat()

func _on_player_experience_changed(_current_exp, _max_exp):
	ui_manager.update_player_exp()

func _on_player_level_up(new_level):
	battle_log_manager.add_message("[color=#4CAF50]Congratulations! You reached level " + str(new_level) + "![/color]")

func _on_enemy_skill_meter_changed(_value):
	ui_manager.update_enemy_skill_meter()

func _on_enemy_skill_triggered():
	# Remove references to challenge buttons container
	# Nothing to do here now as we don't need to show buttons
	pass

func _on_stage_advanced(_dungeon_num, _stage_num):
	ui_manager.update_stage_info()

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

# Engage button pressed
func _on_engage_button_pressed():
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
	
	# Check if player is defeated
	if player_manager.player_health <= 0:
		battle_active = false
		battle_manager.show_endgame_screen("Defeat")
		return
	
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
	if Firebase.Auth.auth:
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		# Get current document to extract dungeon and stage info
		document = await collection.get_doc(user_id)
		
		if document and !("error" in document.keys() and document.get_value("error")):
			# Extract current dungeon and stage from the new structure
			var dungeons = document.get_value("dungeons")
			if dungeons != null and typeof(dungeons) == TYPE_DICTIONARY:
				var progress = dungeons.get("progress", {})
				dungeon_id = progress.get("current_dungeon", 1)
				stage_id = progress.get("current_stage", 1)
			else:
				# Fallback values
				dungeon_id = 1
				stage_id = 1
		else:
			# Fallback values
			dungeon_id = 1
			stage_id = 1
	else:
		# Fallback values for non-authenticated users
		dungeon_id = 1
		stage_id = 1
	
	# Update the stage info label
	var dungeon_names = ["The Plain", "The Forest", "The Mountain"]
	var dungeon_name = dungeon_names[dungeon_id - 1] if dungeon_id >= 1 and dungeon_id <= 3 else "Unknown"
	
	if has_node("MainContainer/BattleAreaContainer/StageInfoLabel"):
		$MainContainer/BattleAreaContainer/StageInfoLabel.text = "D" + str(dungeon_id) + ": " + dungeon_name + " - Stage " + str(stage_id)

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
	
	# Get current document to preserve other fields - renamed to avoid shadowing
	var user_document = await collection.get_doc(user_id)
	if user_document and !("error" in user_document.keys() and user_document.get_value("error")):
		# Get all current document data
		var current_data = {}
		for key in user_document.keys():
			if key != "error":
				current_data[key] = user_document.get_value(key)
		
		# Update word challenge stats in the nested structure
		if !current_data.has("word_challenges"):
			current_data["word_challenges"] = {
				"completed": {"stt": 0, "whiteboard": 0},
				"failed": {"stt": 0, "whiteboard": 0}
			}
		
		var word_challenges = current_data.word_challenges
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
		
		# Save back to Firebase using add method (replaces document)
		var task = await collection.add(user_id, current_data)
		if task:
			var result = await task.task_finished
			if result and !result.error:
				print("Updated word challenge stats for " + challenge_type + " - success: " + str(success))
			else:
				print("Failed to update word challenge stats")

func get_current_dungeon() -> int:
	return dungeon_id

func get_current_stage() -> int:
	return stage_id
