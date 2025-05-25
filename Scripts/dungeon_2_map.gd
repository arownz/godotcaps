extends Node2D

# References to UI elements
var stage_buttons = []
var mob_buttons = []
var current_stage = 1
var max_stage = 5
var dungeon_num = 2

# Enemy types for this dungeon
var enemy_types = {
	"normal": {
		"name": "Snake",
		"description": "A venomous snake that moves swiftly and strikes with precision.",
		"health": 110,
		"attack": 15,
		"durability": 10,
		"skill": "Venom Strike",
		"animation": "Mob2Idle"
	},

	"boss": {
		"name": "The Treant",
		"description": "An ancient tree guardian with powerful nature magic.",
		"health": 400,
		"attack": 30,
		"durability": 55,
		"skill": "Root Entangle",
		"animation": "BossIdle"
	}
}

# Player progress tracking
var completed_stages = []
var current_selected_stage = 0
var current_selected_enemy_type = "normal"

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
	# Initialize Firebase if available
	_initialize_firebase()
	
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

# Add this new function to handle clicks outside StageDetails
func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if $StageDetails.visible:
			# Check if the click is outside of StageDetails
			var click_pos = event.position
			var rect = $StageDetails.get_global_rect()
			
			if not rect.has_point(click_pos):
				$StageDetails.visible = false
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

func _load_player_progress():
	# Only proceed if authenticated
	if not Firebase.Auth.auth:
		print("User not authenticated, using default progression")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("Loading progression data for user: " + user_id)
	
	var task = collection.get(user_id)
	if task:
		var document = await task.task_finished
		if document and not document.error:
			# Check if dungeon 1 is completed to unlock dungeon 2
			var dungeon1_completed = false
			if document.doc_fields.has("dungeons_completed") and document.doc_fields.dungeons_completed.has("1"):
				var dungeon1_data = document.doc_fields.dungeons_completed["1"]
				if dungeon1_data.has("completed") and dungeon1_data.completed:
					dungeon1_completed = true
			
			if not dungeon1_completed:
				print("Dungeon 1 not completed yet, returning to dungeon selection")
				await get_tree().create_timer(0.5).timeout
				get_tree().change_scene_to_file("res://Scenes/DungeonSelection.tscn")
				return
				
			# Extract progression data for dungeon 2
			if document.doc_fields.has("dungeons_completed") and document.doc_fields.dungeons_completed.has(str(dungeon_num)):
				var dungeon_data = document.doc_fields.dungeons_completed[str(dungeon_num)]
				if dungeon_data.has("stages_completed"):
					completed_stages = dungeon_data.stages_completed
					print("Loaded completed stages: ", completed_stages)
			
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
		if stage_num == max_stage:  # Stage 5 is boss stage
			indicator_node_name = "BossIndicator"
		
		var indicator_node = button.get_node_or_null(indicator_node_name)
		if indicator_node == null:
			print("Warning: Could not find " + indicator_node_name + " for stage " + str(stage_num))
			continue
			
		# Stage 1 is always unlocked
		if stage_num == 1:
			button.texture_normal = load("res://gui/Update/icons/next level select.png")
			indicator_node.visible = true
		# Completed stages
		elif completed_stages.has(stage_num):
			button.texture_normal = load("res://gui/Update/icons/player completed level.png")
			indicator_node.visible = true
		# Current available stage
		elif completed_stages.has(stage_num - 1) || stage_num == 2 && completed_stages.has(1):
			button.texture_normal = load("res://gui/Update/icons/next level select.png")
			indicator_node.visible = true
		# Locked stages
		else:
			button.texture_normal = load("res://gui/Update/icons/unlocked level.png")
			indicator_node.visible = false

func _initialize_mob_buttons():
	# Get mob buttons from the stage details panel
	mob_buttons = [
		$StageDetails/MonsterIconButtonContainer/Mob1Button,
		$StageDetails/MonsterIconButtonContainer/Mob2Button,
		$StageDetails/MonsterIconButtonContainer/Mob3Button,
		$StageDetails/MonsterIconButtonContainer/Boss1Button
	]
	
	# Initial setup of animations
	var animated_sprite = $StageDetails/LeftContainer/AnimatedSprite2D
	animated_sprite.play("Mob3Idle") # Default to boar animation for dungeon 2

func _connect_signals():
	# Connect stage button signals
	for i in range(stage_buttons.size()):
		stage_buttons[i].pressed.connect(_on_stage_button_pressed.bind(i+1))
	
	# Connect mob button signals
	for i in range(mob_buttons.size()):
		if i < 3:  # Regular mobs
			mob_buttons[i].pressed.connect(_on_mob_button_pressed.bind("normal", i))
		else:  # Boss
			mob_buttons[i].pressed.connect(_on_mob_button_pressed.bind("boss", 0))
	
	# Connect back button
	$TextureRect/BackButton.pressed.connect(_on_back_button_pressed)
	
	# Connect fight button
	$StageDetails/FightButton.pressed.connect(_on_fight_button_pressed)

func _on_stage_button_pressed(stage_num):
	$SelectLevel.visible = false
	print("Stage " + str(stage_num) + " selected")
	
	# Check if stage is unlocked
	if stage_num > 1 and not (completed_stages.has(stage_num - 1) or completed_stages.has(stage_num)):
		# Stage is locked - show notification
		notification_popup.show_notification("Stage Locked!", "Complete Stage " + str(stage_num - 1) + " first to unlock this stage.", "OK")
		return
		
	current_selected_stage = stage_num
	
	# Update stage details panel
	_update_stage_details(stage_num)
	
	# Show the stage details panel
	$StageDetails.visible = true
	
	# Set the appropriate enemy type for this stage
	if stage_num == max_stage:
		current_selected_enemy_type = "boss"
		# Show boss in the last stage
		$StageDetails/LeftContainer/AnimatedSprite2D.play("BossIdle")
		$StageDetails/LeftContainer/MonsterName.text = enemy_types["boss"]["name"]
		
		# Show the boss indicator for stage 5
		if stage_num == 5:
			$Stage5/BossIndicator.visible = true
	else:
		current_selected_enemy_type = "normal"
		# Show regular mob for stages 1-4 (Boar for dungeon 2)
		$StageDetails/LeftContainer/AnimatedSprite2D.play("Mob3Idle")
		$StageDetails/LeftContainer/MonsterName.text = enemy_types["normal"]["name"]

func _update_stage_details(stage_num):
	# Update stage number
	$StageDetails/Label2.text = str(stage_num)
	
	# Set enemy info based on stage number
	var enemy_type = "boss" if stage_num == max_stage else "normal"
	var enemy_data = enemy_types[enemy_type]
	
	# Update enemy information
	$StageDetails/LeftContainer/MonsterName.text = enemy_data["name"].to_upper()
	$StageDetails/RightContainer/Info.text = enemy_data["description"]
	$StageDetails/RightContainer/Health.text = str(enemy_data["health"])
	$StageDetails/RightContainer/Attack.text = str(enemy_data["attack"])
	$StageDetails/RightContainer/Durability.text = str(enemy_data["durability"])
	$StageDetails/RightContainer/SkillName.text = enemy_data["skill"]
	
	# Set level based on stage number (higher level for dungeon 2)
	$StageDetails/LeftContainer/LVLabel2.text = str((dungeon_num-1) * 25 + stage_num * 5)
	
	# Update boss visibility for stage 5
	if stage_num == 5:
		# Show only boss button for stage 5
		for i in range(mob_buttons.size()):
			if i < 3:  # Regular mobs
				mob_buttons[i].visible = false
			else:  # Boss
				mob_buttons[i].visible = true
	else:
		# Show only regular mob buttons for stages 1-4
		for i in range(mob_buttons.size()):
			if i < 3:  # Regular mobs
				mob_buttons[i].visible = true
			else:  # Boss
				mob_buttons[i].visible = false

func _on_mob_button_pressed(type, index):
	print("Selected enemy type: " + type + " index: " + str(index))
	
	# Update enemy display based on selected type
	current_selected_enemy_type = type
	
	# Update animation and info
	if type == "boss":
		$StageDetails/LeftContainer/AnimatedSprite2D.play("BossIdle")
		$StageDetails/LeftContainer/MonsterName.text = enemy_types["boss"]["name"].to_upper()
		$StageDetails/RightContainer/Info.text = enemy_types["boss"]["description"]
		$StageDetails/RightContainer/Health.text = str(enemy_types["boss"]["health"])
		$StageDetails/RightContainer/Attack.text = str(enemy_types["boss"]["attack"])
		$StageDetails/RightContainer/Durability.text = str(enemy_types["boss"]["durability"])
		$StageDetails/RightContainer/SkillName.text = enemy_types["boss"]["skill"]
	else:
		# For normal enemies, we can have variants based on index
		$StageDetails/LeftContainer/AnimatedSprite2D.play("Mob3Idle") # Boar for dungeon 2
		$StageDetails/LeftContainer/MonsterName.text = enemy_types["normal"]["name"].to_upper()
		$StageDetails/RightContainer/Info.text = enemy_types["normal"]["description"]
		$StageDetails/RightContainer/Health.text = str(enemy_types["normal"]["health"])
		$StageDetails/RightContainer/Attack.text = str(enemy_types["normal"]["attack"])
		$StageDetails/RightContainer/Durability.text = str(enemy_types["normal"]["durability"])
		$StageDetails/RightContainer/SkillName.text = enemy_types["normal"]["skill"]

func _on_back_button_pressed():
	if $StageDetails.visible:
		# If details panel is open, close it first
		$StageDetails.visible = false
	else:
		# Return to dungeon selection
		get_tree().change_scene_to_file("res://Scenes/DungeonSelection.tscn")

func _on_fight_button_pressed():
	print("Starting battle in Dungeon 2, Stage " + str(current_selected_stage))
	
	# Save current stage and dungeon directly to Firebase
	await _save_current_dungeon_stage()

	# Load the battle scene
	get_tree().change_scene_to_file("res://Scenes/BattleScene.tscn")

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

func _on_notification_closed():
	# Handle notification close if needed
	pass
