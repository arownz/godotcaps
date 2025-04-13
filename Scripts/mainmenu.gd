extends Control

# User data variables
var user_data = {
	"username": "Player",
	"level": 1,
	"energy": 99,
	"max_energy": 99,
	"role": "dyslexia",  # Default role (dyslexia, parent, teacher)
	"character": "default"
}

# UI References
@onready var name_label = $ProfileButton/HBoxContainer/VBoxContainer/NameLabel
@onready var level_label = $ProfileButton/HBoxContainer/VBoxContainer/LevelLabel
@onready var energy_label = $EnergyDisplay/HBoxContainer/EnergyLabel
@onready var avatar_label = $ProfileButton/HBoxContainer/AvatarBackground/AvatarLabel

# Buttons with hover labels
var hover_buttons = []

func _ready():
	# Add a debug label to show messages
	var debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(10, 10)
	debug_label.size = Vector2(500, 100)
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
		button_data.button.mouse_entered.connect(func(): _on_button_mouse_entered(button_data.label))
		button_data.button.mouse_exited.connect(func(): _on_button_mouse_exited(button_data.label))
	
	# Load user data
	load_user_data()

func _process(_delta):
	pass

func _on_button_mouse_entered(label):
	# Show label when hovering
	label.visible = true

func _on_button_mouse_exited(label):
	# Hide label when not hovering
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
	
	# Fetch user data from Firestore
	var collection = Firebase.Firestore.collection("users")
	var task = collection.get(user_id)
	
	if task:
		# Wait for task to complete
		var document = await task.task_finished
		
		if document and document.doc_fields:
			print("User data loaded successfully")
			
			# Update user data
			user_data.username = document.doc_fields.get("username", "Player")
			user_data.level = document.doc_fields.get("user_level", 1)
			user_data.energy = document.doc_fields.get("energy", 99)
			user_data.max_energy = document.doc_fields.get("max_energy", 99)
			user_data.role = document.doc_fields.get("role", "dyslexia")
			user_data.character = document.doc_fields.get("profile_picture", "default")
			
			# Update UI
			update_user_interface()
			
			# Log last login
			update_last_login()
		else:
			print("Error loading user data:", document.error if document else "No document")
	else:
		print("Failed to create Firestore task")

func update_user_interface():
	# Update UI elements with user data
	name_label.text = user_data.username
	level_label.text = "LV: " + str(user_data.level)
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
		var collection = Firebase.Firestore.collection("users")
		
		var current_time = Time.get_datetime_string_from_system(false, true)
		var update_data = {"last_login": current_time}
		
		collection.update(user_id, update_data)

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
	print("Opening Profile")
	# Placeholder for profile screen
	# get_tree().change_scene_to_file("res://Scenes/Profile.tscn")

func _on_logout_button_pressed():
	print("Logging out")
	Firebase.Auth.logout()
	# Add a short delay before changing scene
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://Scenes/Authentication.tscn")
