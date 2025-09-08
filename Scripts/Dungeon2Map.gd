extends Node2D

# References to UI elements
var stage_buttons = []
var mob_buttons = []
var current_stage = 1
var max_stage = 5
var dungeon_num = 2

# Enemy types for this dungeon - simplified to match .tres structure  
var enemy_types = {
	"normal": {
		"resource_path": "res://Resources/Enemies/dungeon2_normal.tres"
	},
	"boss": {
		"resource_path": "res://Resources/Enemies/dungeon2_boss.tres"
	}
}

# Loaded enemy resources cache
var loaded_enemy_resources = {}

# Player progress tracking
var completed_stages = []
var current_selected_stage = 0
var current_selected_enemy_type = "stage_1"

# Constants for popup styling
const POPUP_BG_COLOR = Color(0.113725, 0.329412, 0.458824, 0.9)
const POPUP_BORDER_COLOR = Color(1, 1, 1, 1)
const POPUP_TEXT_COLOR = Color(1, 0.92549, 0.756863, 1)

# Add popup for locked stages
var stage_lock_popup
var popup_message_label

# Notification popup reference
var notification_popup: CanvasLayer

func _ready():
	
	# Enhanced fade-in animation matching SettingScene style
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Initialize Firebase if available
	_initialize_firebase()
	
	# Load enemy resources
	_load_enemy_resources()
	
	# Set up stage buttons
	_initialize_stage_buttons()
	
	# Initialize monster icon buttons
	_initialize_mob_buttons()
		# Add signal connections
	_connect_signals()
	
	# Hide stage details panel initially
	$StageDetails.visible = false
	
	# Create notification popup
	notification_popup = load("res://Scenes/NotificationPopUp.tscn").instantiate()
	add_child(notification_popup)
	notification_popup.closed.connect(_on_notification_closed)
	
	# Refresh progression when scene loads (important for when returning from battle)
	await _refresh_progression_from_firebase()

# Add this new function to handle clicks outside StageDetails
func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if $StageDetails.visible:
			# Check if the click is outside of StageDetails
			var click_pos = event.position
			var rect = $StageDetails.get_global_rect()
			
			if not rect.has_point(click_pos):
				$StageDetails.visible = false
				$SelectLevel.visible = true # Show SelectLevel when StageDetails is closed
				get_viewport().set_input_as_handled()

func _on_close_button_pressed():
	$ButtonClick.play()
	# Close the StageDetails panel
	$StageDetails.visible = false
	
	# Show the SelectLevel panel again
	$SelectLevel.visible = true
	
	# Ensure input is handled to prevent further clicks
	get_viewport().set_input_as_handled()

func _initialize_firebase():
	if Engine.has_singleton("Firebase"):
		print("Firebase initialized for Dungeon 2")
		# Load user progress data
		_load_player_progress()
	else:
		print("Firebase not available, using default progression")
		# Set default progression (only stage 1 is unlocked)
		completed_stages = []

# Refresh progression data - useful when returning from battle
func _refresh_progression_from_firebase():
	print("Refreshing progression data for dungeon ", dungeon_num)
	if Firebase.Auth.auth:
		await _load_player_progress()
	else:
		print("User not authenticated, skipping progression refresh")
		print("Firebase not available, using default progression")
		# Set default progression (only stage 1 is unlocked)
		completed_stages = []

func _load_player_progress():
	# Only proceed if authenticated
	if not Firebase.Auth.auth:
		print("User not authenticated, using default progression")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("Loading progression data for user: " + user_id)
	
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		# Extract progression data using new structure
		var dungeons = document.get_value("dungeons")
		if dungeons != null and typeof(dungeons) == TYPE_DICTIONARY:
			var completed = dungeons.get("completed", {})
			
			# Check if dungeon 1 is completed to unlock dungeon 2
			var dungeon1_completed = false
			if completed.has("1"):
				var dungeon1_data = completed["1"]
				if dungeon1_data.get("completed", false) or dungeon1_data.get("stages_completed", 0) >= 5:
					dungeon1_completed = true
			
			if not dungeon1_completed:
				print("Dungeon 1 not completed yet, returning to dungeon selection")
				await get_tree().create_timer(0.5).timeout
				get_tree().change_scene_to_file("res://Scenes/DungeonSelection.tscn")
				return
			
			# Load progression data for dungeon 2
			if completed.has(str(dungeon_num)):
				var dungeon_data = completed[str(dungeon_num)]
				var stages_completed_count = dungeon_data.get("stages_completed", 0)
				
				# Build completed_stages array from stages_completed count
				completed_stages = []
				for i in range(1, stages_completed_count + 1):
					completed_stages.append(i)
				
				print("Loaded completed stages for dungeon " + str(dungeon_num) + ": ", completed_stages)
	else:
		print("Failed to load user document or document error")
		
	# Update stage button visuals based on progression
	_update_stage_buttons()
			
	# Update stage button visuals based on progression
	_update_stage_buttons()

func _initialize_stage_buttons():
	# Store references to all stage buttons
	stage_buttons = [
		$Stage1, $Stage2, $Stage3, $Stage4, $Stage5
	]
	
	# Initially, only stage 1 is unlocked
	_update_stage_buttons()

func _update_stage_buttons():
	for i in range(stage_buttons.size()):
		var stage_num = i + 1
		var button = stage_buttons[i]
		
		# Handle the different indicator node names for regular stages vs boss stage
		var indicator_node_name = "MobIndicator"
		if stage_num == max_stage: # Stage 5 is boss stage
			indicator_node_name = "BossIndicator"
		
		var indicator_node = button.get_node_or_null(indicator_node_name)
		if indicator_node == null:
			print("Warning: Could not find " + indicator_node_name + " for stage " + str(stage_num))
			continue
			
		# Completed stages show as completed (including stage 1)
		if completed_stages.has(stage_num):
			button.texture_normal = load("res://gui/Update/icons/player completed level.png")
			indicator_node.visible = true
		# Stage 1 is always unlocked and available (but check completion first)
		elif stage_num == 1:
			button.texture_normal = load("res://gui/Update/icons/next level select.png")
			indicator_node.visible = true
		# Next available stage (unlocked but not completed)
		elif completed_stages.has(stage_num - 1) or (stage_num == 2 and completed_stages.has(1)):
			button.texture_normal = load("res://gui/Update/icons/next level select.png")
			indicator_node.visible = true
		# Future stages that are locked
		else:
			button.texture_normal = load("res://gui/Update/icons/unlocked level.png")
			indicator_node.visible = false
			
	print("Updated stage buttons. Completed stages: ", completed_stages)

func _initialize_mob_buttons():
	# Get mob buttons from the stage details panel
	mob_buttons = [
		$StageDetails/MonsterIconButtonContainer/Mob1Button,
		$StageDetails/MonsterIconButtonContainer/Mob2Button,
		$StageDetails/MonsterIconButtonContainer/Mob3Button,
		$StageDetails/MonsterIconButtonContainer/Boss1Button
	]
	
	# Note: Don't play animation here - will be set when enemy is selected
	# The AnimatedSprite2D will be populated when _update_stage_details() is called

func _connect_signals():
	# Connect stage button signals
	for i in range(stage_buttons.size()):
		var btn = stage_buttons[i]
		if btn and !btn.is_connected("pressed", _on_stage_button_pressed):
			btn.pressed.connect(_on_stage_button_pressed.bind(i + 1))
		if btn and !btn.is_connected("mouse_entered", _on_button_hover):
			btn.mouse_entered.connect(_on_button_hover)
	
	# Connect mob button signals
	for i in range(mob_buttons.size()):
		if i < 3: # Regular mobs - pass stage info instead of "normal"
			if mob_buttons[i] and !mob_buttons[i].is_connected("pressed", _on_mob_button_pressed):
				mob_buttons[i].pressed.connect(_on_mob_button_pressed.bind("stage_" + str(i + 1), i))
		else: # Boss
			if mob_buttons[i] and !mob_buttons[i].is_connected("pressed", _on_mob_button_pressed):
				mob_buttons[i].pressed.connect(_on_mob_button_pressed.bind("boss", 0))
		if mob_buttons[i] and !mob_buttons[i].is_connected("mouse_entered", _on_button_hover):
			mob_buttons[i].mouse_entered.connect(_on_button_hover)
	
	# Connect back button
	if $BackButton and !$BackButton.is_connected("pressed", _on_back_button_pressed):
		$BackButton.pressed.connect(_on_back_button_pressed)
	if $BackButton and !$BackButton.is_connected("mouse_entered", _on_back_button_hover_entered):
		$BackButton.mouse_entered.connect(_on_back_button_hover_entered)
	if $BackButton and !$BackButton.is_connected("mouse_exited", _on_back_button_hover_exited):
		$BackButton.mouse_exited.connect(_on_back_button_hover_exited)

	# Connect fight button
	if $StageDetails/FightButton and !$StageDetails/FightButton.is_connected("pressed", _on_fight_button_pressed):
		$StageDetails/FightButton.pressed.connect(_on_fight_button_pressed)
	if $StageDetails/FightButton and !$StageDetails/FightButton.is_connected("mouse_entered", _on_button_hover):
		$StageDetails/FightButton.mouse_entered.connect(_on_button_hover)
	if $StageDetails/CloseButton and !$StageDetails/CloseButton.is_connected("pressed", _on_close_button_pressed):
		$StageDetails/CloseButton.pressed.connect(_on_close_button_pressed)
	if $StageDetails/CloseButton and !$StageDetails/CloseButton.is_connected("mouse_entered", _on_button_hover):
		$StageDetails/CloseButton.mouse_entered.connect(_on_button_hover)

func _on_stage_button_pressed(stage_num):
	$ButtonClick.play()
	$SelectLevel.visible = false
	print("Stage " + str(stage_num) + " selected")
	
	# Check if stage is unlocked
	# Stage 1 is always unlocked
	# Stage N is unlocked if Stage N-1 is completed
	if stage_num > 1 and not completed_stages.has(stage_num - 1):
		# Stage is locked - show notification
		notification_popup.show_notification("Stage Locked!", "Complete Stage " + str(stage_num - 1) + " first to unlock this stage.", "OK")
		print("Stage " + str(stage_num) + " is locked. Completed stages: ", completed_stages)
		return
		
	current_selected_stage = stage_num
	print("Stage " + str(stage_num) + " is unlocked and selected. Completed stages: ", completed_stages)
	
	# Update stage details panel (this handles all the enemy data display)
	_update_stage_details(stage_num)
	
	# Show the stage details panel
	$StageDetails.visible = true
	
	# Set the appropriate enemy type for this stage
	if stage_num == max_stage:
		current_selected_enemy_type = "boss"
		# Show the boss indicator for stage 5
		if stage_num == 5:
			$Stage5/BossIndicator.visible = true
	else:
		current_selected_enemy_type = "stage_" + str(stage_num)

func _update_stage_details(stage_num):
	# Update stage number
	$StageDetails/Label2.text = str(stage_num)
	
	# Get scaled enemy data for this stage
	var enemy_data = _get_scaled_enemy_data(stage_num)
	if enemy_data.is_empty():
		print("Error: Could not get enemy data for stage ", stage_num)
		return
	
	# Update enemy information using scaled data
	$StageDetails/LeftContainer/MonsterName.text = enemy_data["name"].to_upper()
	$StageDetails/RightContainer/Info.text = enemy_data["description"]
	$StageDetails/RightContainer/Health.text = str(enemy_data["health"])
	$StageDetails/RightContainer/Attack.text = str(enemy_data["attack"])
	$StageDetails/RightContainer/Durability.text = str(enemy_data["durability"])
	$StageDetails/RightContainer/SkillName.text = enemy_data["skill"]
	
	# Update experience reward if ExpRewardValue node exists
	var exp_reward_node = $StageDetails/RightContainer.get_node_or_null("ExpRewardValue")
	if exp_reward_node:
		exp_reward_node.text = str(enemy_data["exp_reward"]) + " EXP"
	
	# Set level based on calculated level
	$StageDetails/LeftContainer/LVLabel2.text = str(enemy_data["level"])
	
	# Load and set the correct AnimatedSprite based on stage type
	var is_boss = (stage_num == 5)
	var enemy_type = "boss" if is_boss else "normal"
	var enemy_resource = loaded_enemy_resources[enemy_type]
	
	# Get the AnimatedSprite node
	var animated_sprite = $StageDetails/LeftContainer/AnimatedSprite2D
	
	# Load the correct animation scene
	if enemy_resource and enemy_resource.animation_scene:
		# Remove existing children from AnimatedSprite2D if any
		for child in animated_sprite.get_children():
			child.queue_free()
		
		# Instance the new animation scene
		var animation_instance = enemy_resource.animation_scene.instantiate()
		animated_sprite.add_child(animation_instance)
		
		# Play auto_attack animation if available
		if animation_instance.has_method("play"):
			animation_instance.play("auto_attack")
	
	# Update mob button visibility - show only one button per stage
	for i in range(mob_buttons.size()):
		mob_buttons[i].visible = false # Hide all buttons first
	
	if stage_num == 5:
		# Show only boss button for stage 5
		mob_buttons[3].visible = true # Boss1Button (index 3)
	else:
		# Show only first mob button for stages 1-4
		mob_buttons[0].visible = true # Mob1Button (index 0)

func _on_mob_button_pressed(type, index):
	$ButtonClick.play()
	print("Selected enemy type: " + type + " index: " + str(index))
	
	# Update enemy display based on selected type
	current_selected_enemy_type = type
	
	# Get scaled enemy data for the current stage
	var enemy_data = _get_scaled_enemy_data(current_selected_stage)
	
	if enemy_data.is_empty():
		print("Error: Could not load enemy data for stage ", current_selected_stage)
		return
	
	# Update animation and info with scaled data
	# Only play animation if it exists and has been properly loaded
	var animated_sprite = $StageDetails/LeftContainer/AnimatedSprite2D
	if animated_sprite.get_child_count() > 0:
		var animation_instance = animated_sprite.get_child(0)
		if animation_instance.has_method("play") and animation_instance.sprite_frames and animation_instance.sprite_frames.has_animation("auto_attack"):
			animation_instance.play("auto_attack")
	
	$StageDetails/LeftContainer/MonsterName.text = enemy_data["name"].to_upper()
	$StageDetails/RightContainer/Info.text = enemy_data["description"]
	$StageDetails/RightContainer/Health.text = str(enemy_data["health"])
	$StageDetails/RightContainer/Attack.text = str(enemy_data["attack"])
	$StageDetails/RightContainer/Durability.text = str(enemy_data["durability"])
	$StageDetails/RightContainer/SkillName.text = enemy_data["skill"]

func _on_back_button_pressed():
	$ButtonClick.play()
	if $StageDetails.visible:
		# If details panel is open, close it first
		$StageDetails.visible = false
	else:
		# Return to dungeon selection
		_fade_out_and_change_scene("res://Scenes/DungeonSelection.tscn")

# Helper function to fade out before changing scenes
func _fade_out_and_change_scene(scene_path: String):
	# Enhanced fade-out animation matching SettingScene style
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _on_fight_button_pressed():
	$ButtonClick.play()
	print("Starting battle in Dungeon 2, Stage " + str(current_selected_stage))
	
	# Set battle progress in DungeonGlobals for immediate transfer to battle scene
	DungeonGlobals.set_battle_progress(dungeon_num, current_selected_stage)
	
	# Save current stage and dungeon directly to Firebase (for persistence)
	await _save_current_dungeon_stage()

	# Load the battle scene
	_fade_out_and_change_scene("res://Scenes/BattleScene.tscn")

func _save_current_dungeon_stage():
	# Only proceed if authenticated
	if not Firebase.Auth.auth:
		print("User not authenticated, cannot save progress")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document first to preserve other fields
	var get_task = await collection.get_doc(user_id)
	if get_task:
		var document = await get_task
		if document and document.has_method("doc_fields"):
			var update_data = document.doc_fields
			
			# Update dungeons progress
			if not update_data.has("dungeons"):
				update_data["dungeons"] = {}
			if not update_data.dungeons.has("progress"):
				update_data.dungeons["progress"] = {}
			
			# Update current dungeon and stage
			update_data.dungeons.progress.current_dungeon = dungeon_num
			update_data.dungeons.progress.current_stage = current_selected_stage
			
			# Save back to Firestore
			collection.add(user_id, update_data)
			print("Saved current dungeon/stage to Firebase")

# Button hover handlers
func _on_back_button_hover_entered():
	$ButtonHover.play()
	var back_label = $BackButton/BackLabel
	if back_label:
		back_label.visible = true

func _on_back_button_hover_exited():
	var back_label = $BackButton/BackLabel
	if back_label:
		back_label.visible = false

func _on_button_hover():
	$ButtonHover.play()

func _on_notification_closed():
	# Handle notification close if needed
	pass

# Load enemy resources from .tres files
func _load_enemy_resources():
	for enemy_type in enemy_types.keys():
		var resource_path = enemy_types[enemy_type]["resource_path"]
		var resource = load(resource_path)
		if resource:
			loaded_enemy_resources[enemy_type] = resource
			print("Loaded enemy resource: ", enemy_type, " from ", resource_path)
		else:
			print("Failed to load enemy resource: ", resource_path)

# Get stage-based multiplier for enemy stats - BALANCED FOR DYSLEXIC CHILDREN
func _get_stage_multiplier(stage_num: int) -> float:
	# MUCH GENTLER progression for dyslexic children (slow, steady growth)
	var stage_multiplier = 1.0 + (stage_num - 1) * 0.15 # 1.0, 1.15, 1.3, 1.45, 1.6
	
	# MINIMAL dungeon scaling to keep game accessible 
	var dungeon_multiplier = 1.0 + (dungeon_num - 1) * 0.25 # 1.0, 1.25, 1.5
	
	return stage_multiplier * dungeon_multiplier

# Get stage-specific enemy name variations for dungeon 2
func _get_stage_specific_name(base_name: String, stage_num: int) -> String:
	# Stage-specific prefixes for forest/snake theme
	var stage_prefixes = ["Young", "Forest", "Viper", "Ancient", "Boss"]
	var prefix = stage_prefixes[min(stage_num - 1, stage_prefixes.size() - 1)]
	
	# For boss stages, use specific boss names
	if stage_num == 5:
		return "Forest Guardian"
	
	# For regular stages, add prefix
	return prefix + " " + base_name

# Get scaled enemy data for a specific stage
func _get_scaled_enemy_data(stage_num: int) -> Dictionary:
	var is_boss = (stage_num == 5)
	var enemy_type = "boss" if is_boss else "normal"
	
	if !loaded_enemy_resources.has(enemy_type):
		print("Error: Enemy resource not loaded for type: ", enemy_type)
		return {}
	
	var enemy_resource = loaded_enemy_resources[enemy_type]
	var multiplier = _get_stage_multiplier(stage_num)
	
	return {
		"name": _get_stage_specific_name(enemy_resource.get_enemy_name(), stage_num),
		"description": enemy_resource.description,
		"health": int(enemy_resource.get_health() * multiplier),
		"attack": int(enemy_resource.get_damage() * multiplier),
		"durability": int(enemy_resource.get_durability() * multiplier),
		"skill": enemy_resource.skill_name,
		"exp_reward": int(enemy_resource.get_exp_reward() * multiplier),
		"level": stage_num * 1
	}
