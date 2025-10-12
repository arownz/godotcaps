extends Node2D

# Preload all manager scripts to ensure they're defined before use
const BattleManagerScript = preload("res://Scripts/JourneyManager/battle_manager.gd")
const EnemyManagerScript = preload("res://Scripts/JourneyManager/enemy_manager.gd")
const PlayerManagerScript = preload("res://Scripts/JourneyManager/player_manager.gd")
const BattleLogManagerScript = preload("res://Scripts/JourneyManager/battle_log_manager.gd")
const UIManagerScript = preload("res://Scripts/JourneyManager/ui_manager.gd")
const ChallengeManagerScript = preload("res://Scripts/JourneyManager/challenge_manager.gd")
const DungeonManagerScript = preload("res://Scripts/JourneyManager/dungeon_manager.gd")

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
var battle_session_started = false # Tracks if any battle has occurred in this session
var auto_battle = false
var auto_battle_timer = null
var auto_battle_speed = 4.0
var battle_result = ""
var fresh_start = true

func _speed_time(base: float) -> float:
	return base * (auto_battle_speed / 4.0)

func set_auto_battle_speed(new_speed: float):
	auto_battle_speed = clamp(new_speed, 1.0, 8.0)
	# Adjust pending timer if it exists
	if auto_battle_timer:
		auto_battle_timer.wait_time = _speed_time(1.0)
	print("BattleScene: auto_battle_speed set to", auto_battle_speed)

# Stage timer tracking
var stage_start_time: float = 0.0
var stage_timer_active: bool = false

# Challenge
var challenge_active = false

# References
@onready var engage_button = $MainContainer/RightContainer/MarginContainer/VBoxContainer/ButtonContainer/EngageButton
@onready var settings_button = $MainContainer/BattleAreaContainer/SettingButton
@onready var fight_label = $MainContainer/BattleAreaContainer/FightLabel
@onready var stage_info_label = $MainContainer/BattleAreaContainer/StageInfoLabel
@onready var timer_label = $MainContainer/BattleAreaContainer/StageTimer

# Add these missing variables at the top of the script
var document = null

# Energy recovery system variables (mirrored from MainMenu.gd)
var max_energy = 20
var energy_recovery_rate = 180 # 3 minutes = 180 seconds (changed from 5 mins)
var energy_recovery_amount = 4 # Amount of energy recovered per interval
var energy_recovery_timer = null

func _ready():
	print("BattleScene: Starting battle scene initialization")
	
	# Add fade-in animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Setup energy recovery timer (matches MainMenu.gd pattern)
	_setup_energy_recovery_timer()
	
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
	
	# Don't start timer here - start it when battle actually begins

# Clean up timer when scene exits
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_cleanup_stage_timer()
		_cleanup_battle_session()

func _cleanup_stage_timer():
	# Stop and clean up stage timer
	stage_timer_active = false
	var live_timer = get_node_or_null("StageTimer")
	if live_timer:
		live_timer.stop()
		live_timer.queue_free()

func _cleanup_battle_session():
	# Reset engage button session flag when leaving battle scene entirely
	if typeof(DungeonGlobals) != TYPE_NIL:
		DungeonGlobals.engage_button_hidden_session = false
		print("BattleScene: Cleaned up battle session - engage button available for new battles")
	
	# Clean up energy recovery timer
	if energy_recovery_timer:
		energy_recovery_timer.queue_free()
		energy_recovery_timer = null

# Setup energy recovery timer (matches MainMenu.gd pattern)
func _setup_energy_recovery_timer():
	print("BattleScene: Setting up energy recovery system")
	
	# Create energy processing timer (check every 10 seconds)
	energy_recovery_timer = Timer.new()
	energy_recovery_timer.wait_time = 10.0 # Check every 10 seconds for better responsiveness
	energy_recovery_timer.timeout.connect(_process_energy_recovery)
	energy_recovery_timer.autostart = true
	add_child(energy_recovery_timer)
	
	print("BattleScene: Energy recovery system initialized")

# Process energy recovery (matches MainMenu.gd logic)
func _process_energy_recovery():
	if !Firebase.Auth or !Firebase.Auth.auth:
		return
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document
	var user_doc = await collection.get_doc(user_id)
	if !user_doc or ("error" in user_doc.keys() and user_doc.get_value("error")):
		print("BattleScene: Failed to get user document for energy recovery")
		return
	
	var stats_data = user_doc.get_value("stats")
	if !stats_data or !stats_data.has("player"):
		print("BattleScene: No player stats found for energy recovery")
		return
	
	var player_data = stats_data["player"]
	var current_energy = player_data.get("energy", 20)
	var current_time = Time.get_unix_time_from_system()
	var last_update = player_data.get("last_energy_update", current_time)
	
	print("BattleScene: Processing energy recovery - Current: " + str(current_energy) + ", Last update: " + str(last_update))
	
	# If last_energy_update is 0 or invalid, set it to current time
	if last_update == 0:
		last_update = current_time
		_update_energy_timestamp_in_firebase(user_id, current_time)
		return
	
	# If already at max energy, update timestamp to current time to stop recovery attempts
	if current_energy >= max_energy:
		if last_update < current_time - energy_recovery_rate:
			_update_energy_timestamp_in_firebase(user_id, current_time)
		return
	
	var time_passed = current_time - last_update
	var recovery_intervals = int(time_passed / energy_recovery_rate)
	
	print("BattleScene: Time passed: " + str(time_passed) + " seconds, Recovery intervals: " + str(recovery_intervals))
	
	if recovery_intervals > 0:
		var energy_to_recover = recovery_intervals * energy_recovery_amount
		var new_energy = min(current_energy + energy_to_recover, max_energy)
		var new_last_update = last_update + (recovery_intervals * energy_recovery_rate)
		
		# If energy reached max, set timestamp to current time
		if new_energy >= max_energy:
			new_last_update = current_time
		
		if new_energy != current_energy:
			print("BattleScene: Recovering energy: " + str(current_energy) + " -> " + str(new_energy))
			
			# Update energy in Firebase
			player_data["energy"] = new_energy
			player_data["last_energy_update"] = new_last_update
			stats_data["player"] = player_data
			user_doc.add_or_update_field("stats", stats_data)
			
			var updated_doc = await collection.update(user_doc)
			if updated_doc:
				print("BattleScene: Energy recovered and saved to Firebase: " + str(current_energy) + " -> " + str(new_energy))
			else:
				print("BattleScene: Failed to save energy recovery to Firebase")

# Update energy timestamp in Firebase
func _update_energy_timestamp_in_firebase(user_id: String, timestamp: float):
	var collection = Firebase.Firestore.collection("dyslexia_users")
	var user_doc = await collection.get_doc(user_id)
	
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var stats_data = user_doc.get_value("stats")
		if stats_data and stats_data.has("player"):
			stats_data["player"]["last_energy_update"] = timestamp
			user_doc.add_or_update_field("stats", stats_data)
			await collection.update(user_doc)
			print("BattleScene: Updated energy timestamp: " + str(timestamp))

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
	
	# Create notification popup for dungeon completion notifications
	var notification_popup = load("res://Scenes/NotificationPopUp.tscn").instantiate()
	notification_popup.name = "NotificationPopUp"
	add_child(notification_popup)
	
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
	
	# Set the correct background for the current dungeon
	ui_manager.update_background(dungeon_manager.dungeon_num)
	
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
	
	# Connect settings button hover events
	if !settings_button.is_connected("mouse_entered", _on_settings_button_hover_enter):
		settings_button.mouse_entered.connect(_on_settings_button_hover_enter)
	if !settings_button.is_connected("mouse_exited", _on_settings_button_hover_exit):
		settings_button.mouse_exited.connect(_on_settings_button_hover_exit)
	
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
		if !battle_manager.is_connected("player_attack_performed", _on_player_attack_performed):
			battle_manager.player_attack_performed.connect(_on_player_attack_performed)
		if !battle_manager.is_connected("enemy_attack_performed", _on_enemy_attack_performed):
			battle_manager.enemy_attack_performed.connect(_on_enemy_attack_performed)
		if !battle_manager.is_connected("enemy_skill_triggered", _on_enemy_skill_triggered):
			battle_manager.enemy_skill_triggered.connect(_on_enemy_skill_triggered)
	
	# EnemyManager signals
	if enemy_manager and enemy_manager.has_signal("enemy_health_changed"):
		if !enemy_manager.is_connected("enemy_health_changed", _on_enemy_health_changed):
			enemy_manager.enemy_health_changed.connect(_on_enemy_health_changed)
		if !enemy_manager.is_connected("enemy_defeated", _on_enemy_defeated):
			enemy_manager.enemy_defeated.connect(_on_enemy_defeated)
		if !enemy_manager.is_connected("enemy_skill_meter_changed", _on_enemy_skill_meter_changed):
			enemy_manager.enemy_skill_meter_changed.connect(_on_enemy_skill_meter_changed)
		if !enemy_manager.is_connected("enemy_set_up", _on_enemy_set_up):
			enemy_manager.enemy_set_up.connect(_on_enemy_set_up)
	
	# PlayerManager signals
	if player_manager and player_manager.has_signal("player_health_changed"):
		if !player_manager.is_connected("player_health_changed", _on_player_health_changed):
			player_manager.player_health_changed.connect(_on_player_health_changed)
		if !player_manager.is_connected("player_defeated", _on_player_defeated):
			player_manager.player_defeated.connect(_on_player_defeated)
		if !player_manager.is_connected("player_experience_changed", _on_player_experience_changed):
			player_manager.player_experience_changed.connect(_on_player_experience_changed)
		if !player_manager.is_connected("player_level_up", _on_player_level_up):
			player_manager.player_level_up.connect(_on_player_level_up)
	
	# DungeonManager signals
	if dungeon_manager:
		if dungeon_manager.has_signal("stage_advanced"):
			if !dungeon_manager.is_connected("stage_advanced", _on_stage_advanced):
				dungeon_manager.stage_advanced.connect(_on_stage_advanced)
		if dungeon_manager.has_signal("dungeon_advanced"):
			if !dungeon_manager.is_connected("dungeon_advanced", _on_dungeon_advanced):
				dungeon_manager.dungeon_advanced.connect(_on_dungeon_advanced)

# Signal callbacks
func _on_player_attack_performed(damage):
	var reduced_damage = enemy_manager.take_damage(damage)
	# Show damage indicator with the ACTUAL reduced damage dealt
	_show_damage_indicator(reduced_damage, "enemy")

func _on_enemy_attack_performed(damage):
	var reduced_damage = player_manager.take_damage(damage)
	enemy_manager.increase_skill_meter(25)
	# Show damage indicator with the ACTUAL reduced damage dealt
	_show_damage_indicator(reduced_damage, "player")

func _on_enemy_health_changed(_current_health, _max_health):
	ui_manager.update_enemy_health()

func _on_player_health_changed(_current_health, _max_health):
	ui_manager.update_player_health()

func _on_enemy_defeated(_exp_reward):
	battle_active = false
	# CRITICAL: Stop enemy manager activities immediately
	enemy_manager.end_battle()
	# Stop the stage timer when enemy is defeated
	await _stop_stage_timer()
	# Engage button remains hidden per session design (no re-enable broadcast)
	print("BattleScene: Enemy defeated - engage button stays hidden (design)")
	# Call battle_manager to handle victory
	battle_manager.handle_victory()

func _on_player_defeated():
	battle_active = false
	# CRITICAL: Stop enemy manager activities immediately to prevent skill activations
	enemy_manager.end_battle()
	# Stop the stage timer when player is defeated (no time saving on defeat)
	stage_timer_active = false
	# Let battle_manager handle defeat
	battle_manager.handle_defeat()

func _on_player_experience_changed(_current_exp, _max_exp):
	ui_manager.update_player_exp()

func _on_player_level_up(new_level):
	# Play level up SFX
	var level_up_sfx = get_node_or_null("LevelUpSFX")
	if level_up_sfx:
		level_up_sfx.play()
	
	# Get the actual stat increases from player_manager (will be randomly low for dyslexic balance)
	var health_increase = player_manager.last_health_increase
	var damage_increase = player_manager.last_damage_increase
	var durability_increase = player_manager.last_durability_increase
	
	# Get current stats
	var new_health = player_manager.player_max_health
	var new_damage = player_manager.player_damage
	var new_durability = player_manager.player_durability
	
	# Use enhanced level-up message with high contrast colors (no emojis for dyslexia font compatibility)
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
	ui_manager.update_stage_info()
	battle_log_manager.add_message("[color=#006400]You've entered a new dungeon! Prepare for stronger enemies.[/color]")

func _on_enemy_set_up(_enemy_name, _enemy_type):
	ui_manager.initialize_enemy_ui()

func _setup_auto_battle_timer():
	auto_battle_timer = Timer.new()
	auto_battle_timer.one_shot = true
	# Base loop delay is 1.0s (legacy used 2.0 here). Scaled by speed helper.
	auto_battle_timer.wait_time = _speed_time(1.0)
	auto_battle_timer.timeout.connect(_on_auto_battle_timer_timeout)
	add_child(auto_battle_timer)

# Engage button pressed - directly start auto battle and consume energy
func _on_engage_button_pressed():
	$ButtonClick.play()
	if battle_active:
		return
	
	# Check energy first and show notification if insufficient
	if ! await _check_energy_and_show_notification():
		return # Not enough energy, notification shown
	
	# Consume energy before starting battle
	if ! await _consume_battle_energy():
		return # Energy consumption failed
	
	# Start the actual battle
	_start_battle()

func _show_battle_settings_popup():
	# Load settings popup as the new battle popup
	var settings_popup_scene = load("res://Scenes/SettingScene.tscn")
	if settings_popup_scene == null:
		print("Failed to load SettingScene popup, starting battle directly")
		await _consume_battle_energy()
		_start_battle()
		return
	var popup = settings_popup_scene.instantiate()
	# Configure as battle context - allow multiple battles unless explicitly hidden
	if popup.has_method("set_energy_cost"):
		popup.set_energy_cost(2)
	if popup.has_method("set_context"):
		# Don't pass battle_session_started - allow repeated battles unless permanently hidden
		popup.set_context(true, false, battle_active)
	elif popup.has_method("set_battle_session_state"):
		# Don't hide engage button based on session - allow repeated battles
		popup.set_battle_session_state(false, battle_active)
	# Connect signals if available
	if popup.has_signal("engage_confirmed"):
		popup.engage_confirmed.connect(_on_engage_confirmed)
	if popup.has_signal("quit_requested"):
		popup.quit_requested.connect(_on_battle_quit_requested)
	# If global flag indicates engage hidden (battle started previously), enforce it
	if typeof(DungeonGlobals) != TYPE_NIL and DungeonGlobals.engage_button_hidden_session:
		if popup.has_method("permanently_hide_engage_button"):
			popup.permanently_hide_engage_button()
	# Add to scene tree (CanvasLayer will center itself)
	get_tree().current_scene.add_child(popup)

func _on_engage_confirmed():
	# Check energy first and show notification if insufficient
	if ! await _check_energy_and_show_notification():
		return # Not enough energy, notification shown
	
	# Consume energy before starting battle
	if ! await _consume_battle_energy():
		return # Energy consumption failed
	
	# Start the actual battle
	_start_battle()

func _on_battle_quit_requested():
	# Player chose not to engage, return to dungeon map
	print("Player quit battle engagement, returning to dungeon")
	
	# Reset engage button session flag to allow future battles
	if typeof(DungeonGlobals) != TYPE_NIL:
		DungeonGlobals.engage_button_hidden_session = false
		print("BattleScene: Reset engage button session flag - user can engage in new battles")
	
	# Get the current dungeon from dungeon_manager instead of using hardcoded dungeon_id
	var current_dungeon = dungeon_manager.dungeon_num
	print("Returning to dungeon: ", current_dungeon)
	
	# Determine which dungeon to return to based on current dungeon from dungeon_manager
	var dungeon_scene_path = ""
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
	
	_fade_out_and_change_scene(dungeon_scene_path)

# Helper function to fade out before changing scenes
func _fade_out_and_change_scene(scene_path: String):
	# Enhanced fade-out animation matching SettingScene style
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _start_battle():
	if battle_active:
		return
	
	battle_active = true
	battle_session_started = true # Mark that a battle has occurred in this session

	# Permanently hide engage button in any open settings popup for this session
	for popup in get_tree().get_nodes_in_group("settings_popups"):
		if popup and popup.has_method("permanently_hide_engage_button"):
			popup.permanently_hide_engage_button()
	# Set global flag so future settings popups auto-hide engage
	if typeof(DungeonGlobals) != TYPE_NIL:
		DungeonGlobals.engage_button_hidden_session = true
	
	# Start the stage timer when battle actually begins
	_start_stage_timer()
	
	# Get the engage button and make it transparent/disabled looking
	engage_button.disabled = true
	engage_button.modulate = Color(1, 1, 1, 0.5) # 50% transparency
	engage_button.mouse_filter = Control.CURSOR_ARROW
	
	# Add battle log message
	battle_log_manager.add_message("[color=#000000]Battle started! You engage the " + enemy_manager.enemy_name + ".[/color]")

	# Show "FIGHT!" message
	fight_label.visible = true
	
	# Show fight animation
	ui_manager.show_fight_animation(_start_auto_battle)

func _start_auto_battle():
	fight_label.visible = false
	
	# Add battle log message
	battle_log_manager.add_message("[color=#000000]The turn-based battle begins![/color]")

	# Start the automatic battle sequence after a short (speed-scaled) delay
	await get_tree().create_timer(_speed_time(0.1)).timeout
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
	
	# Double-check battle is still active and player is alive before attacking
	if !battle_active or player_manager.player_health <= 0:
		print("BattleScene: Skipping player attack - battle not active or player defeated")
		return
	
	# AWAIT player attack to finish completely (movement + attack + return)
	await battle_manager.player_attack()
	
	# Small pause after player attack finishes - SPEED: Reduce from 0.5s to 0.2s
	await get_tree().create_timer(_speed_time(0.3)).timeout
	
	# Check if enemy is defeated - the enemy_defeated signal will handle victory automatically
	if enemy_manager.enemy_health <= 0:
		battle_active = false
		# Don't call handle_victory here - the enemy_defeated signal will handle it
		return
	
	# After a small delay, enemy attacks
	print("Enemy attacking with damage: " + str(enemy_manager.enemy_damage))
	
	# AWAIT enemy attack to finish completely (movement + attack + return)
	await battle_manager.enemy_attack()

	# Small pause after enemy attack finishes - SPEED: Reduce from 0.5s to 0.3s
	await get_tree().create_timer(_speed_time(0.3)).timeout

	# Check if enemy skill is ready and battle is still active
	if battle_active and enemy_manager.enemy_skill_meter >= enemy_manager.enemy_skill_threshold:
		await get_tree().create_timer(_speed_time(0.3)).timeout # SPEED: Reduce from 0.5s to 0.3s
		# Double-check battle is still active before triggering skill
		if battle_active:
			battle_manager.trigger_enemy_skill()
		return
	elif not battle_active:
		print("BattleScene: Skipping enemy skill - battle has ended")
		return
	
	# Continue battle after delay - SPEED: Reduce from 1.0s to 0.2s for faster turn transitions
	auto_battle_timer.wait_time = _speed_time(0.2)
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

# Update stage info label - delegated to UI manager to avoid redundancy
func _update_stage_info():
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
	return dungeon_manager.dungeon_num

func get_current_stage() -> int:
	return dungeon_manager.stage_num

func _on_settings_button_pressed():
	$ButtonClick.play()
	print("Settings button pressed - showing battle settings popup")
	_show_battle_settings_popup()

func _on_settings_button_hover_enter():
	$ButtonHover.play()
	var setting_label = $MainContainer/BattleAreaContainer/SettingButton/SettingLabel
	if setting_label:
		setting_label.visible = true

func _on_settings_button_hover_exit():
	var setting_label = $MainContainer/BattleAreaContainer/SettingButton/SettingLabel
	if setting_label:
		setting_label.visible = false

func _consume_battle_energy() -> bool:
	# Check if player has enough energy (2 energy required)
	if !Firebase.Auth.auth:
		return true # Allow battle if not authenticated
		
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
				_show_energy_notification(current_energy)
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
			_show_energy_notification(0)
			return false
	else:
		_show_energy_notification(0)
		return false

# NEW: Check energy and show notification if insufficient 
func _check_energy_and_show_notification() -> bool:
	print("BattleScene: Checking energy for battle engagement...")
	
	# Get current energy without consuming it
	if !Firebase.Auth.auth:
		print("BattleScene: Not authenticated, showing energy notification")
		_show_energy_notification(0)
		return false
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get user document
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var stats_data = user_doc.get_value("stats")
		if stats_data != null and "player" in stats_data:
			var player_data = stats_data["player"]
			var current_energy = player_data.get("energy", 0)
			
			print("BattleScene: Current energy: " + str(current_energy) + "/" + str(max_energy))
			
			# Check if player has enough energy
			if current_energy < 2:
				print("BattleScene: Insufficient energy, showing notification")
				_show_energy_notification(current_energy)
				return false
			
			print("BattleScene: Energy check passed")
			return true
		else:
			print("BattleScene: No player stats data found")
			_show_energy_notification(0)
			return false
	else:
		print("BattleScene: Failed to get user document")
		_show_energy_notification(0)
		return false

# NEW: Show energy notification popup
func _show_energy_notification(current_energy: int):
	print("Showing energy notification: " + str(current_energy) + "/" + str(max_energy))
	
	# Get the notification popup that was created in _initialize_managers()
	var notification_popup = get_node_or_null("NotificationPopUp")
	if notification_popup:
		var title = "Not Enough Energy"
		var base_message = ""
		
		if current_energy == 0:
			base_message = "You have no energy remaining (" + str(current_energy) + "/" + str(max_energy) + ").\n\nEnergy is required to engage in battles. Wait for energy to recover over time."
		else:
			base_message = "You need 2 energy to start a battle, but you only have " + str(current_energy) + " energy remaining.\n\nWait for battle energy to recover over time."
		
		var button_text = "OK"
		
		# Show notification with initial message
		notification_popup.show_notification(title, base_message + "\n\nNext energy in: Calculating...", button_text)
		
		# Start live countdown timer update
		_start_energy_countdown_for_battle_notification(notification_popup, current_energy, base_message)
	else:
		print("Error: NotificationPopUp not found in scene tree")

# NEW: Get energy recovery time information
func _get_energy_recovery_info() -> Dictionary:
	var result = {}
	
	if !Firebase.Auth.auth:
		return result
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get user document - FETCH FRESH DATA FROM FIRESTORE
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		# Get stats.player data (matching MainMenu.gd pattern)
		var stats_data = user_doc.get_value("stats")
		if stats_data != null and "player" in stats_data:
			var player_data = stats_data["player"]
			
			# Get current energy and last update from Firestore
			var current_energy = player_data.get("energy", 0)
			
			# If at max energy, no recovery needed
			if current_energy >= max_energy:
				result["current_energy"] = current_energy
				result["max_energy"] = max_energy
				result["at_max"] = true
				return result
			
			# Calculate time until next energy based on FRESH Firestore data
			var current_time = Time.get_unix_time_from_system()
			var last_update = player_data.get("last_energy_update", current_time)
			var time_since_last_recovery = current_time - last_update
			var time_until_next_energy = energy_recovery_rate - fmod(time_since_last_recovery, energy_recovery_rate)
			
			var minutes = int(time_until_next_energy / 60)
			var seconds = int(time_until_next_energy) % 60
			
			result["next_energy_time"] = "%d:%02d" % [minutes, seconds]
			result["current_energy"] = current_energy
			result["max_energy"] = max_energy
			result["time_until_next"] = time_until_next_energy
			result["last_update"] = last_update
			result["recovery_rate"] = energy_recovery_rate
			result["at_max"] = false
			
			print("BattleScene: Energy info from Firestore - Current: ", current_energy, " Time until next: ", result["next_energy_time"])
	
	return result

func _start_energy_countdown_for_battle_notification(notification_popup: CanvasLayer, _initial_energy: int, _initial_base_message: String):
	"""Start live countdown timer for battle energy notification popup"""
	if not notification_popup:
		return
	
	# Create countdown timer
	var countdown_timer = Timer.new()
	countdown_timer.wait_time = 1.0 # Update every second
	countdown_timer.autostart = true
	notification_popup.add_child(countdown_timer)
	
	# Update function that will run every second
	var update_countdown = func():
		if not is_instance_valid(notification_popup) or not notification_popup.visible:
			countdown_timer.queue_free()
			return
		
		# Fetch fresh energy data from Firestore every second
		var energy_info = await _get_energy_recovery_info()
		var recovery_text = "\n\nNext energy in: Calculating..."
		var base_message = ""
		var title_text = "Not Enough Energy"
		
		# Get CURRENT energy from fresh Firestore data
		var current_energy = energy_info.get("current_energy", 0)
		
		# Check if energy is sufficient now
		if current_energy >= 2:
			title_text = "Energy Recovered!"
			base_message = "You now have " + str(current_energy) + "/" + str(max_energy) + " energy.\n\nYou can now start a fight!"
			recovery_text = ""
		else:
			# Build message with CURRENT energy from Firestore
			if current_energy == 0:
				base_message = "You have no energy remaining (" + str(current_energy) + "/" + str(max_energy) + ").\n\nEnergy is required to engage in battles. Wait for energy to recover over time."
			else:
				base_message = "You need 2 energy to start a battle, but you only have " + str(current_energy) + " energy remaining.\n\nWait for battle energy to recover over time."
			
			# Calculate recovery time
			if energy_info.has("time_until_next"):
				var time_until_next = energy_info["time_until_next"]
				var minutes = int(time_until_next / 60)
				var seconds = int(time_until_next) % 60
				recovery_text = "\n\nNext energy in: %d:%02d" % [minutes, seconds]
		
		# Update notification TITLE with LIVE energy status
		var title_label = notification_popup.get_node_or_null("PopupContainer/CenterContainer/PopupBackground/VBoxContainer/TopContainer/TitleLabel")
		if title_label:
			title_label.text = title_text
		
		# Update notification message with LIVE energy data AND resize popup dynamically
		var updated_message = base_message + recovery_text
		
		# Use the notification popup's dynamic update method to resize properly
		if notification_popup.has_method("update_message_dynamic"):
			notification_popup.update_message_dynamic(updated_message)
		else:
			# Fallback to direct label update if method doesn't exist
			var message_label = notification_popup.get_node_or_null("PopupContainer/CenterContainer/PopupBackground/VBoxContainer/MessageLabel")
			if message_label:
				message_label.text = updated_message
	
	# Connect timer to update function
	countdown_timer.timeout.connect(update_countdown)
	
	# Clean up timer when notification is closed
	var cleanup_on_close = func():
		if is_instance_valid(countdown_timer):
			countdown_timer.queue_free()
	
	if notification_popup.has_signal("closed"):
		notification_popup.closed.connect(cleanup_on_close, CONNECT_ONE_SHOT) # ===== Stage Timer Functions (Live Timer System) =====
func _start_stage_timer():
	print("BattleScene: Starting stage timer for Dungeon ", dungeon_manager.dungeon_num, " Stage ", dungeon_manager.stage_num)
	
	# Ensure timer_label reference is valid
	if !timer_label:
		timer_label = $MainContainer/BattleAreaContainer/StageTimer
		if !timer_label:
			print("ERROR: Timer label not found!")
			return
	
	# Initialize timer variables
	stage_start_time = Time.get_unix_time_from_system()
	stage_timer_active = true
	timer_label.text = "00:00"
	timer_label.visible = true
	
	# Create and start the live timer (similar to energy recovery system)
	if has_node("StageTimer"):
		get_node("StageTimer").queue_free()
	
	var live_timer = Timer.new()
	live_timer.name = "StageTimer"
	live_timer.wait_time = 1.0 # Update every second
	live_timer.timeout.connect(_update_stage_timer_display)
	live_timer.autostart = false
	add_child(live_timer)
	live_timer.start()
	
	print("BattleScene: Live stage timer started at unix time: ", stage_start_time)

# Live timer update function (similar to energy recovery display)
func _update_stage_timer_display():
	if !stage_timer_active or !timer_label:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed_time = current_time - stage_start_time
	var time_text = _format_time(elapsed_time)
	timer_label.text = time_text

func _stop_stage_timer():
	if !stage_timer_active:
		return
		
	stage_timer_active = false
	
	# Stop the live timer
	var live_timer = get_node_or_null("StageTimer")
	if live_timer:
		live_timer.stop()
		live_timer.queue_free()
	
	# Calculate final elapsed time
	var current_time = Time.get_unix_time_from_system()
	var elapsed_time = current_time - stage_start_time
	print("BattleScene: Stage completed in ", elapsed_time, " seconds")
	
	# Save the best time to Firebase (only if it's better than existing)
	await _save_stage_time_to_firebase(elapsed_time)
	
	return elapsed_time

# Helper function to format time and avoid integer division warnings
func _format_time(time_seconds: float) -> String:
	var total_seconds = int(time_seconds)
	var minutes = int(total_seconds / 60.0)
	var seconds = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

# Save stage completion time to Firebase (only if it's a new best time)
func _save_stage_time_to_firebase(completion_time: float):
	if !Firebase.Auth.auth:
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		print("BattleScene: Document retrieved successfully for stage time update")
		
		# Get or create stage_times structure
		var stage_times = user_doc.get_value("stage_times")
		if stage_times == null or typeof(stage_times) != TYPE_DICTIONARY:
			stage_times = {}
		
		# Create dungeon structure if it doesn't exist
		var dungeon_key = "dungeon_" + str(dungeon_manager.dungeon_num)
		if !stage_times.has(dungeon_key):
			stage_times[dungeon_key] = {}
		
		# Check if this is a new best time for this stage
		var stage_key = "stage_" + str(dungeon_manager.stage_num)
		var current_best_time = stage_times[dungeon_key].get(stage_key, null)
		
		# Only save if it's a new best time (lower is better) or first completion
		if current_best_time == null or completion_time < current_best_time:
			stage_times[dungeon_key][stage_key] = completion_time
			
			# Update the document field
			user_doc.add_or_update_field("stage_times", stage_times)
			
			# Save to Firebase
			var updated_doc = await collection.update(user_doc)
			if updated_doc:
				var time_text = _format_time(completion_time)
				print("BattleScene: New best time saved for ", dungeon_key, " ", stage_key, ": ", time_text)
				
				# Show improvement message in battle log
				if current_best_time != null:
					var old_time_text = _format_time(current_best_time)
					battle_log_manager.add_message("[color=#00FF00]New best time! Previous: " + old_time_text + " → Now: " + time_text + "[/color]")
				else:
					battle_log_manager.add_message("[color=#00FF00]Stage completed in " + time_text + "![/color]")
			else:
				print("BattleScene: Failed to save stage time to Firebase")
		else:
			var current_time_text = _format_time(completion_time)
			var best_time_text = _format_time(current_best_time)
			print("BattleScene: Time ", current_time_text, " not better than current best ", best_time_text)
			battle_log_manager.add_message("[color=#FFD700]Stage completed in " + current_time_text + " (Best: " + best_time_text + ")[/color]")
	else:
		print("BattleScene: Failed to get user document for stage time update")

# ===== Damage Indicator System =====
func _show_damage_indicator(damage_amount: int, target: String):
	var target_position: Vector2
	var target_node: Node2D
	
	# Get the target position based on whether it's player or enemy
	if target == "player":
		if player_manager.player_animation:
			target_node = player_manager.player_animation
			target_position = target_node.global_position
		else:
			target_position = $MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerPosition.global_position
	elif target == "enemy":
		if enemy_manager.enemy_animation:
			target_node = enemy_manager.enemy_animation
			target_position = target_node.global_position
		else:
			target_position = $MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyPosition.global_position
	else:
		print("Invalid damage indicator target: ", target)
		return
	
	# Create damage label
	var damage_label = Label.new()
	damage_label.text = "-" + str(damage_amount)
	damage_label.add_theme_font_size_override("font_size", 24)
	damage_label.add_theme_color_override("font_color", Color.RED)
	damage_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	damage_label.add_theme_constant_override("shadow_offset_x", -1)
	damage_label.add_theme_constant_override("shadow_offset_y", 1)

	# Add dyslexic-friendly font
	var dyslexic_font = load("res://Fonts/dyslexiafont/OpenDyslexic-Italic.otf")
	if dyslexic_font:
		damage_label.add_theme_font_override("font", dyslexic_font)
	
	# Add to battle container for proper layering
	var battle_container = $MainContainer/BattleAreaContainer/BattleContainer
	battle_container.add_child(damage_label)
	
	# Position near target with random offset to avoid overlap
	var random_offset = Vector2(
		randf_range(-30, 30), # Random horizontal offset
		randf_range(-40, -10) # Random upward offset
	)
	damage_label.position = target_position + random_offset
	
	# Ensure label doesn't go off screen
	var viewport_size = get_viewport_rect().size
	damage_label.position.x = clamp(damage_label.position.x, 0, viewport_size.x - 50)
	damage_label.position.y = clamp(damage_label.position.y, 50, viewport_size.y - 50)
	
	# Animate the damage indicator
	_animate_damage_indicator(damage_label)

func _animate_damage_indicator(label: Label):
	# Initial setup for animation
	label.modulate.a = 1.0
	label.scale = Vector2(1.2, 1.2)
	
	# Create animation tween
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale animation: grow then shrink
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
	
	# Position animation: float upward
	tween.tween_property(label, "position", label.position + Vector2(0, -50), 1.5).set_ease(Tween.EASE_OUT)
	
	# Fade animation: visible for a moment, then fade out
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.7).set_ease(Tween.EASE_IN)
	
	# Clean up after animation
	tween.tween_callback(label.queue_free).set_delay(1.5)

# Show counter damage indicator with special styling
func _show_counter_damage_indicator(damage_amount: int, target: String, _bonus_damage: int):
	var target_position: Vector2
	var target_node: Node2D
	
	# Get the target position
	if target == "enemy":
		if enemy_manager.enemy_animation:
			target_node = enemy_manager.enemy_animation
			target_position = target_node.global_position
		else:
			target_position = $MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyPosition.global_position
	else:
		return
	
	# Create counter damage label with special styling
	var damage_label = Label.new()
	damage_label.text = "-" + str(damage_amount) + " COUNTER!"
	damage_label.add_theme_font_size_override("font_size", 28)
	damage_label.add_theme_color_override("font_color", Color.GOLD)
	damage_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	damage_label.add_theme_constant_override("shadow_offset_x", -2)
	damage_label.add_theme_constant_override("shadow_offset_y", 1)

	# Add dyslexic-friendly font
	var dyslexic_font = load("res://Fonts/dyslexiafont/OpenDyslexic-Bold-Italic.otf")
	if dyslexic_font:
		damage_label.add_theme_font_override("font", dyslexic_font)
	
	# Add to battle container
	var battle_container = $MainContainer/BattleAreaContainer/BattleContainer
	battle_container.add_child(damage_label)
	
	# Position with larger offset for counter attacks
	var random_offset = Vector2(
		randf_range(-40, 40),
		randf_range(-60, -20)
	)
	damage_label.position = target_position + random_offset
	
	# Animate with more dramatic effect for counters
	_animate_counter_damage_indicator(damage_label)

# Show skill damage indicator with special styling
func _show_skill_damage_indicator(damage_amount: int, target: String):
	var target_position: Vector2
	var target_node: Node2D
	
	# Get the target position
	if target == "player":
		if player_manager.player_animation:
			target_node = player_manager.player_animation
			target_position = target_node.global_position
		else:
			target_position = $MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerPosition.global_position
	else:
		return
	
	# Create skill damage label with special styling
	var damage_label = Label.new()
	damage_label.text = "-" + str(damage_amount) + " SKILL DAMAGE!"
	damage_label.add_theme_font_size_override("font_size", 26)
	damage_label.add_theme_color_override("font_color", Color.ORANGE_RED)
	damage_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	damage_label.add_theme_constant_override("shadow_offset_x", -3)
	damage_label.add_theme_constant_override("shadow_offset_y", 1)

	# Add dyslexic-friendly font
	var dyslexic_font = load("res://Fonts/dyslexiafont/OpenDyslexic-Bold-Italic.otf")
	if dyslexic_font:
		damage_label.add_theme_font_override("font", dyslexic_font)
	
	# Add to battle container
	var battle_container = $MainContainer/BattleAreaContainer/BattleContainer
	battle_container.add_child(damage_label)
	
	# Position with offset
	var random_offset = Vector2(
		randf_range(-35, 35),
		randf_range(-50, -15)
	)
	damage_label.position = target_position + random_offset
	
	# Animate with special effect for skill damage
	_animate_skill_damage_indicator(damage_label)

func _animate_counter_damage_indicator(label: Label):
	# Initial setup for dramatic counter animation
	label.modulate.a = 1.0
	label.scale = Vector2(1.5, 1.5)
	
	# Create animation tween
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Dramatic scale animation
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(0.9, 0.9), 0.3).set_delay(0.3).set_ease(Tween.EASE_IN)
	
	# Float upward
	tween.tween_property(label, "position", label.position + Vector2(0, -70), 2.0).set_ease(Tween.EASE_OUT)
	
	# Fade animation
	tween.tween_property(label, "modulate:a", 1.0, 0.4)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(1.0).set_ease(Tween.EASE_IN)
	
	# Clean up
	tween.tween_callback(label.queue_free).set_delay(2.0)

func _animate_skill_damage_indicator(label: Label):
	# Initial setup for skill damage animation
	label.modulate.a = 1.0
	label.scale = Vector2(1.3, 1.3)
	
	# Create animation tween
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Shake effect
	var original_pos = label.position
	tween.tween_method(_shake_label.bind(label, original_pos), 0.0, 1.0, 0.5)
	
	# Scale animation
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
	
	# Float upward
	tween.tween_property(label, "position", original_pos + Vector2(0, -60), 1.8).set_ease(Tween.EASE_OUT).set_delay(0.5)
	
	# Fade animation
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.9).set_ease(Tween.EASE_IN)
	
	# Clean up
	tween.tween_callback(label.queue_free).set_delay(1.8)

# Helper function for shake effect
## NOTE: tween_method passes the animated value as the FIRST argument.
## Original signature (label, original_pos, progress) caused a type mismatch:
## engine supplied a float where a Label was expected. We reorder so progress comes first.
func _shake_label(progress: float, label: Label, original_pos: Vector2):
	if progress < 0.5:
		var shake_intensity = 5.0 * (0.5 - progress) * 2.0
		label.position = original_pos + Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
	else:
		label.position = original_pos


func _on_engage_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_setting_button_pressed() -> void:
	pass # Replace with function body.
