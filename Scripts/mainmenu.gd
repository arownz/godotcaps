extends Control

# User data variables
var user_data = {
	"username": "Player",
	"level": 1,
	"energy": 20,
	"max_energy": 20,
	"character": "default",
	"coin": 100,
	"power_scale": 120,
	"rank": "bronze"
}

# UI References
@onready var name_label = $InfoContainer/NameLabel
@onready var level_label = $InfoContainer/LevelContainer/LevelLabel
@onready var energy_label = $EnergyDisplay/EnergyLabel
@onready var avatar_label = $ProfileButton/AvatarBackground/AvatarLabel

# Buttons with hover labels
var hover_buttons = []

func _ready():
	# Add a debug label to show messages
	var debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(10, 10)
	debug_label.size = Vector2(500, 100)
	debug_label.text = "Main Menu loaded successfully"
	add_child(debug_label)
	debug_label.text = "Main Menu loaded successfully"

	# Set up hover buttons
	hover_buttons = [
		{
			"button": $BottomButtonsContainer/ModulesButton,
			"label": $BottomButtonsContainer/ModulesButton/ModulesLabel
		},
		{
			"button": $BottomButtonsContainer/CharacterButton,
			"label": $BottomButtonsContainer/CharacterButton/CharacterLabel
		},
		{
			"button": $BottomButtonsContainer/LeaderboardButton,
			"label": $BottomButtonsContainer/LeaderboardButton/LeaderboardLabel
		},
		# Added hover for Journey button
		{
			"button": $BottomButtonsContainer/JourneyButton,
			"label": $BottomButtonsContainer/JourneyButton/JourneyLabel
		},
		# Added hover for Settings button
		{
			"button": $BottomButtonsContainer/SettingsButton,
			"label": $BottomButtonsContainer/SettingsButton/SettingsLabel
		},
		# Added hover for Profile button
		{
			"button": $ProfileButton,
			"label": $ProfileButton/ProfileLabel
		},
		# Added hover for Energy display
		{
			"button": $EnergyDisplay,
			"label": $EnergyDisplay/EnergyTooltip
		}
	]
	
	# Connect button signals
	$BottomButtonsContainer/JourneyButton.pressed.connect(_on_journey_mode_button_pressed)
	$BottomButtonsContainer/ModulesButton.pressed.connect(_on_modules_button_pressed)
	$BottomButtonsContainer/CharacterButton.pressed.connect(_on_character_button_pressed)
	$BottomButtonsContainer/LeaderboardButton.pressed.connect(_on_leaderboard_button_pressed)
	$BottomButtonsContainer/SettingsButton.pressed.connect(_on_settings_button_pressed)
	$ProfileButton.pressed.connect(_on_profile_button_pressed)
	
	# Connect mouse hover signals for hover buttons
	for button_data in hover_buttons:
		if button_data.button and button_data.label:
			button_data.button.mouse_entered.connect(func(): _on_button_mouse_entered(button_data.label))
			button_data.button.mouse_exited.connect(func(): _on_button_mouse_exited(button_data.label))
	
	# Load user data
	load_user_data()

func _process(_delta):
	pass

func _on_button_mouse_entered(label):
	# Show label when hovering
	if label:
		label.visible = true

func _on_button_mouse_exited(label):
	# Hide label when not hovering
	if label:
		label.visible = false

func load_user_data():
	# Check if user is authenticated
	if !Firebase.Auth.auth:
		print("No user authenticated, redirecting to login")
		get_tree().change_scene_to_file("res://Scenes/Authentication.tscn")
		return
	
	var user_id = Firebase.Auth.auth.localid
	print("Loading user data for ID: ", user_id)
	
	# Set loading state UI
	name_label.text = "Loading..."
	avatar_label.text = "..."
	
	# Fetch user data from Firestore - explicitly use dyslexia_users collection
	var collection = Firebase.Firestore.collection("dyslexia_users")
	print("Attempting to fetch from collection: dyslexia_users")
	
	var task = collection.get(user_id)
	
	if task:
		print("Fetch task created successfully")
		var document = await task.task_finished
		
		if document and !document.error:
			print("User data loaded successfully")
			print("Document fields: ", document.doc_fields)
			
			# Update user data
			user_data.username = document.doc_fields.get("username", "Player")
			user_data.level = document.doc_fields.get("user_level", 1)
			user_data.energy = document.doc_fields.get("energy", 20)
			user_data.max_energy = 99  # Hard-coded max value
			user_data.role = document.doc_fields.get("user_type", "dyslexia")
			user_data.character = document.doc_fields.get("profile_picture", "default")
			user_data.coin = document.doc_fields.get("coin", 100)
			user_data.power_scale = document.doc_fields.get("power_scale", 120)
			user_data.rank = document.doc_fields.get("rank", "bronze")
			
			 # Add dungeon and stage data
			user_data.current_dungeon = document.doc_fields.get("current_dungeon", 1)
			user_data.current_stage = document.doc_fields.get("current_stage", 1)
			user_data.dungeons_completed = document.doc_fields.get("dungeons_completed", {
				"1": {"completed": false, "stages_completed": 0},
				"2": {"completed": false, "stages_completed": 0},
				"3": {"completed": false, "stages_completed": 0}
			})
			user_data.dungeon_names = document.doc_fields.get("dungeon_names", {
				"1": "The Plains",
				"2": "The Mountain", 
				"3": "The Demon"
			})
			
			# Also update GameSettings for global access
			GameSettings.current_dungeon = user_data.current_dungeon
			GameSettings.current_stage = user_data.current_stage
			
			# Update UI
			update_user_interface()
			
			# Log last login
			update_last_login()
		else:
			print("Error loading user data:", document.error if document else "No document")
			# Fall back to default values if document can't be loaded
			update_user_interface()
	else:
		print("Failed to create Firestore task")
		# Fall back to default values if task creation fails
		update_user_interface()

func update_user_interface():
	# Update UI elements with user data
	name_label.text = user_data.username
	level_label.text = str(user_data.level)
	energy_label.text = str(user_data.energy) + "/" + str(user_data.max_energy)
	
	# Set avatar label with first letter of username
	if user_data.username.length() > 0:
		avatar_label.text = user_data.username.substr(0, 1).to_upper()
	else:
		avatar_label.text = "U"

func update_last_login():
	# Update last login time in Firestore
	if Firebase.Auth.auth:
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		var current_time = Time.get_datetime_string_from_system(false, true)
		var update_data = {"last_login": current_time}
		
		print("Updating last login for user: ", user_id)
		var update_task = collection.update(user_id, update_data)
		
		if update_task:
			var result = await update_task.task_finished
			if result and result.error:
				print("Error updating last login:", result.error)
		else:
			print("Failed to create update task")

# Button handlers
func _on_journey_mode_button_pressed():
	print("Starting Journey Mode")
	get_tree().change_scene_to_file("res://Scenes/BattleScene.tscn")

func _on_modules_button_pressed():
	print("Opening Learning Modules")
	# Placeholder for learning modules screen
	# get_tree().change_scene_to_file("res://Scenes/LearningModules.tscn")

func _on_character_button_pressed():
	print("Opening Character Selection")
	# Placeholder for character selection screen
	# get_tree().change_scene_to_file("res://Scenes/CharacterSelection.tscn")

func _on_leaderboard_button_pressed():
	print("Opening Leaderboard")
	# Placeholder for leaderboard screen
	# get_tree().change_scene_to_file("res://Scenes/Leaderboard.tscn")

func _on_settings_button_pressed():
	print("Opening Settings")
	# Placeholder for settings screen
	# get_tree().change_scene_to_file("res://Scenes/Settings.tscn")

func _on_profile_button_pressed():
	print("Profile button pressed - attempting to show profile popup")
	
	# Create and show the profile popup
	var profile_popup_scene = load("res://Scenes/ProfilePopUp.tscn")
	
	if profile_popup_scene == null:
		print("ERROR: Failed to load ProfilePopUp.tscn")
		return
		
	print("Successfully loaded ProfilePopUp scene")
	
	var profile_popup = profile_popup_scene.instantiate()
	if profile_popup == null:
		print("ERROR: Failed to instantiate ProfilePopUp")
		return
		
	print("Successfully instantiated ProfilePopUp")
	
	# Add to the scene tree with this node as parent to ensure proper layering
	add_child(profile_popup)
	print("Added ProfilePopUp to scene tree")
	
	# Make sure the popup is visible and centered
	profile_popup.visible = true
	
	# Center the popup if needed
	var viewport_size = get_viewport_rect().size
	profile_popup.position = Vector2(
		viewport_size.x / 2 - profile_popup.size.x / 2,
		viewport_size.y / 2 - profile_popup.size.y / 2
	)
	print("Positioned popup at center of screen")
	
	# Connect the closed signal to remove the popup properly
	if profile_popup.has_signal("closed"):
		profile_popup.connect("closed", Callable(self, "_on_profile_popup_closed"))
		print("Connected 'closed' signal from ProfilePopUp")
	else:
		print("WARNING: ProfilePopUp does not have 'closed' signal")

func _on_profile_popup_closed():
	# Optional function to handle any cleanup after popup closes
	print("Profile popup closed")
	
	# You might want to refresh player info here if it changed in the profile
	load_user_data()

func _on_logout_button_pressed():
	print("Logging out")
	Firebase.Auth.logout()
	# Add a short delay before changing scene
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://Scenes/Authentication.tscn")
