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
}

# UI References
@onready var name_label = $InfoContainer/NameLabel
@onready var level_label = $InfoContainer/LevelContainer/LevelLabel
@onready var energy_label = $EnergyDisplay/EnergyLabel

# Buttons with hover labels
var hover_buttons = []

# Add reference to our debug helper
var firebase_debug = preload("res://Scripts/firebase_debug.gd").new()

func _ready():
	# Add a debug label to show messages
	var debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(10, 10)
	debug_label.size = Vector2(500, 100)
	debug_label.text = "Main Menu loaded successfully"
	add_child(debug_label)
	debug_label.text = "Main Menu loaded successfully"

	# Add debug helper
	add_child(firebase_debug)
	
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
	
	# Log full auth object with our helper
	firebase_debug.debug_log("Loading user data with auth:", firebase_debug.LOG_LEVEL_INFO)
	firebase_debug.log_auth(Firebase.Auth.auth)
	
	var user_id = Firebase.Auth.auth.localid
	firebase_debug.debug_log("Loading user data for ID: " + user_id, firebase_debug.LOG_LEVEL_INFO)
	
	# Set loading state UI
	name_label.text = "Loading..."
	
	# Check if Firestore is ready
	if Firebase.Firestore == null:
		firebase_debug.debug_log("Firebase Firestore is null, attempting to initialize", firebase_debug.LOG_LEVEL_ERROR)
		# Try to reinitialize Firebase
		_initialize_firebase()
		await get_tree().create_timer(1.0).timeout
		
		# If still null after waiting, use fallback
		if Firebase.Firestore == null:
			firebase_debug.debug_log("Firebase Firestore still null after initialization attempt", firebase_debug.LOG_LEVEL_ERROR)
			update_user_interface()
			return
	
	# FIXED: Don't test connection first - this causes parallel HTTP requests
	# Just directly fetch the user document
	firebase_debug.debug_log("Attempting to fetch from collection: dyslexia_users", firebase_debug.LOG_LEVEL_INFO)
	
	# First, explicitly verify the token is still valid
	if OS.has_feature('web'):
		firebase_debug.debug_log("Web platform detected, ensuring token is fresh", firebase_debug.LOG_LEVEL_INFO)
		# Check token expiration and refresh if needed
		var tokenCheck = await Firebase.Auth.check_token_expiry()
		firebase_debug.debug_log("Token check result: " + str(tokenCheck), firebase_debug.LOG_LEVEL_INFO)
	
	# Fetch user data from Firestore
	var collection = Firebase.Firestore.collection("dyslexia_users")
	var task = collection.get(user_id)
	
	if task:
		firebase_debug.debug_log("Fetch task created successfully", firebase_debug.LOG_LEVEL_DEBUG)
		var document = await task.task_finished
		
		if document:
			firebase_debug.debug_log("Document received: " + str(document.keys() if document is Dictionary else "Not a dictionary"), firebase_debug.LOG_LEVEL_DEBUG)
			if !document.error:
				firebase_debug.debug_log("User data loaded successfully", firebase_debug.LOG_LEVEL_INFO)
				firebase_debug.debug_log("Document fields: " + str(document.doc_fields.keys() if document.doc_fields is Dictionary else "No doc_fields"), firebase_debug.LOG_LEVEL_DEBUG)
				
				# Update user data
				user_data.username = document.doc_fields.get("username", "Player")
				user_data.level = document.doc_fields.get("user_level", 1)
				user_data.energy = document.doc_fields.get("energy", 20)
				user_data.max_energy = document.doc_fields.get("max_energy", 20)
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
				firebase_debug.debug_log("Document has error", firebase_debug.LOG_LEVEL_ERROR)
				firebase_debug.log_firestore_error(document.error)
				
				# More detailed error logging
				if typeof(document.error) == TYPE_DICTIONARY:
					for key in document.error:
						firebase_debug.debug_log("Error detail - " + key + ": " + str(document.error[key]), firebase_debug.LOG_LEVEL_ERROR)
				
				# Handle specific errors
				if document.error is Dictionary and document.error.has("status"):
					match document.error.status:
						"PERMISSION_DENIED":
							firebase_debug.debug_log("Permission denied. Checking Firestore rules.", firebase_debug.LOG_LEVEL_ERROR)
							# Run rules test to check permissions
							await firebase_debug.test_firebase_rules()
							
						"NOT_FOUND":
							firebase_debug.debug_log("Document not found. Creating a new one.", firebase_debug.LOG_LEVEL_WARNING)
							await _create_default_user_document(user_id)
							return
				
				# Fall back to default values
				update_user_interface()
		else:
			firebase_debug.debug_log("Document is null", firebase_debug.LOG_LEVEL_ERROR)
			update_user_interface()
	else:
		firebase_debug.debug_log("Failed to create Firestore task", firebase_debug.LOG_LEVEL_ERROR)
		
		# Try reinitializing Firebase and retry once
		_initialize_firebase()
		await get_tree().create_timer(1.0).timeout
		
		firebase_debug.debug_log("Retrying after Firebase reinitialization", firebase_debug.LOG_LEVEL_INFO)
		var retry_collection = Firebase.Firestore.collection("dyslexia_users")
		var retry_task = retry_collection.get(user_id)
		
		if retry_task:
			firebase_debug.debug_log("Retry task created successfully", firebase_debug.LOG_LEVEL_INFO)
			var retry_doc = await retry_task.task_finished
			
			if retry_doc and !retry_doc.error and retry_doc.doc_fields:
				firebase_debug.debug_log("Retry succeeded!", firebase_debug.LOG_LEVEL_INFO)
				
				# Update user data
				user_data.username = retry_doc.doc_fields.get("username", "Player")
				user_data.level = retry_doc.doc_fields.get("user_level", 1)
				user_data.energy = retry_doc.doc_fields.get("energy", 20)
				user_data.max_energy = retry_doc.doc_fields.get("max_energy", 20)
				
				update_user_interface()
				return
		
		# If we get here, the retry failed too
		firebase_debug.debug_log("Retry failed too, using default values", firebase_debug.LOG_LEVEL_ERROR)
		update_user_interface()

# Helper to reinitialize Firebase when needed
func _initialize_firebase():
	firebase_debug.debug_log("Reinitializing Firebase", firebase_debug.LOG_LEVEL_INFO)
	
	# Force a token refresh to ensure we have a valid token
	if Firebase.Auth and Firebase.Auth.auth:
		var refresh_result = await Firebase.Auth.refresh_auth()
		firebase_debug.debug_log("Auth token refresh result: " + str(refresh_result), firebase_debug.LOG_LEVEL_INFO)

# Helper function to create a default user document
func _create_default_user_document(user_id):
	var collection = Firebase.Firestore.collection("dyslexia_users")
	var current_time = Time.get_datetime_string_from_system(false, true)
	
	var display_name = Firebase.Auth.auth.get("displayname", "Player")
	var email = Firebase.Auth.auth.get("email", "")
	
	var user_doc = {
		"username": display_name if display_name else "Player",
		"email": email,
		"birth_date": "",
		"age": 0,
		"profile_picture": "default",
		"user_level": 1,
		"created_at": current_time,
		"last_login": current_time,
		"energy": 20,
	}
	
	print("Creating default user document for ID: ", user_id)
	var task = collection.add(user_id, user_doc)
	
	if task:
		var result = await task.task_finished
		if result and !result.error:
			print("Default user document created successfully")
			# Now try to fetch the newly created document
			load_user_data()
		else:
			print("Error creating default user document: ", result.error if result else "Unknown error")
			update_user_interface()
	else:
		print("Failed to create task for default user document")
		update_user_interface()

func update_user_interface():
	# Update UI elements with user data
	name_label.text = user_data.username
	level_label.text = str(user_data.level)
	energy_label.text = str(user_data.energy) + "/" + str(user_data.max_energy)

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
