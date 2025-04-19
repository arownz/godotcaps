extends Control

# User data variables - simplified to only essential fields
var user_data = {
	"username": "Player",
	"level": 1,
	"energy": 20,
	"max_energy": 20,
	"profile_picture": "default" # Added profile_picture field
}

# UI References
@onready var name_label = $InfoContainer/NameLabel
@onready var level_label = $InfoContainer/LevelContainer/LevelLabel
@onready var energy_label = $EnergyDisplay/EnergyLabel
@onready var avatar_background = $ProfileButton/AvatarBackground # Reference to avatar background

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
	await load_user_data()

func _on_button_mouse_entered(label):
	# Show label when hovering
	if label:
		label.visible = true

func _on_button_mouse_exited(label):
	# Hide label when not hovering
	if label:
		label.visible = false

# Simplified load_user_data function that only fetches essential fields
func load_user_data():
	# Check if user is authenticated
	if !Firebase.Auth.auth:
		print("No user authenticated, redirecting to login")
		get_tree().change_scene_to_file("res://Scenes/Authentication.tscn")
		return
	
	# Log auth status
	firebase_debug.debug_log("Loading user data", firebase_debug.LOG_LEVEL_INFO)
	
	var user_id = Firebase.Auth.auth.localid
	firebase_debug.debug_log("User ID: " + user_id, firebase_debug.LOG_LEVEL_INFO)
	
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
	
	# First, explicitly verify the token is still valid with better error handling
	var _token_valid = await _ensure_valid_token()
	# If the function returns false, it already logs the error

	# Fetch user data from Firestore - using similar pattern as ProfilePopUp.gd
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Use the proper way to handle Firestore tasks
	var task = await collection.get_doc(user_id)
	
	if task:
		firebase_debug.debug_log("Fetch task created successfully", firebase_debug.LOG_LEVEL_DEBUG)
		
		# Connect to the task_finished signal and wait for it
		task.task_finished.connect(func(doc_snapshot): 
			_process_user_data(doc_snapshot, user_id)
			)
	else:
		firebase_debug.debug_log("Failed to create Firestore task", firebase_debug.LOG_LEVEL_ERROR)
		update_user_interface()

# New function to process user data after task completion
func _process_user_data(user_doc, user_id):
	if user_doc:
		# Check for errors using proper error detection
		var has_error = false
		var error_data = null
		
		# According to the docs, we need to check keys() for fields
		var doc_keys = user_doc.keys()
		
		# Check if there is an error in the document
		if "error" in doc_keys:
			# Get error value using get_value instead of direct property access
			error_data = user_doc.get_value("error")
			if error_data:
				has_error = true
		
		if has_error:
			firebase_debug.debug_log("Error in document: " + str(error_data), firebase_debug.LOG_LEVEL_ERROR)
			
			# Handle document not found error
			if typeof(error_data) == TYPE_DICTIONARY and error_data.has("status") and error_data.status == "NOT_FOUND":
				firebase_debug.debug_log("Document not found. Creating a new one.", firebase_debug.LOG_LEVEL_WARNING)
				_create_default_user_document(user_id)
			
			# Fall back to default values
			update_user_interface()
		else:
			# Success path - document found with no errors
			# Extract only the fields we need using the proper API
			user_data.username = user_doc.get_value("username") if "username" in doc_keys else "Player"
			user_data.level = user_doc.get_value("user_level") if "user_level" in doc_keys else 1
			user_data.energy = user_doc.get_value("energy") if "energy" in doc_keys else 20
			user_data.max_energy = user_doc.get_value("max_energy") if "max_energy" in doc_keys else 20
			user_data.profile_picture = user_doc.get_value("profile_picture") if "profile_picture" in doc_keys else "default"
			
			firebase_debug.debug_log("User data loaded: " + str(user_data), firebase_debug.LOG_LEVEL_INFO)
			update_user_interface()
			
			# Log last login as a background task
			update_last_login()
	else:
		firebase_debug.debug_log("Document is null", firebase_debug.LOG_LEVEL_ERROR)
		update_user_interface()

# Ensure we have a valid token before making Firestore requests
func _ensure_valid_token() -> bool:
	if Firebase.Auth and Firebase.Auth.auth:
		# Check if token exists or is about to expire
		if not Firebase.Auth.auth.has("idtoken"):
			firebase_debug.debug_log("No token found, attempting refresh", firebase_debug.LOG_LEVEL_INFO)
			
			# Additional safety check to avoid errors if auth is busy
			if Firebase.Auth.is_busy:
				firebase_debug.debug_log("Auth is busy, waiting before refresh attempt", firebase_debug.LOG_LEVEL_WARNING)
				await get_tree().create_timer(1.0).timeout
				
				if Firebase.Auth.is_busy:
					firebase_debug.debug_log("Auth still busy, skipping refresh", firebase_debug.LOG_LEVEL_WARNING)
					return false
			
			# Safe to refresh now - remove try/except and use simple error handling
			firebase_debug.debug_log("Attempting token refresh", firebase_debug.LOG_LEVEL_INFO)
			# Prefix with underscore since it's unused
			var _refresh_result = await Firebase.Auth.manual_token_refresh(Firebase.Auth.auth)
			
			# Check if we have a token after refresh
			if Firebase.Auth.auth.has("idtoken"):
				firebase_debug.debug_log("Token refresh completed successfully", firebase_debug.LOG_LEVEL_INFO)
				return true
			else:
				firebase_debug.debug_log("Token refresh failed - no token available", firebase_debug.LOG_LEVEL_ERROR)
				return false
		else:
			return true
	return false

# Helper to reinitialize Firebase when needed
func _initialize_firebase():
	firebase_debug.debug_log("Reinitializing Firebase", firebase_debug.LOG_LEVEL_INFO)
	
	# Force a token refresh to ensure we have a valid token
	if Firebase.Auth and Firebase.Auth.auth:
		# Log auth object for debugging
		firebase_debug.debug_log("Auth object before refresh: " + str(Firebase.Auth.auth.keys()), firebase_debug.LOG_LEVEL_DEBUG)
		
		# Check if auth is busy before refreshing token
		if not Firebase.Auth.is_busy:
			firebase_debug.debug_log("Attempting token refresh", firebase_debug.LOG_LEVEL_INFO)
			var refresh_result = await Firebase.Auth.manual_token_refresh(Firebase.Auth.auth, 1.0) # Added delay retry
			firebase_debug.debug_log("Token refresh result: " + str(refresh_result), firebase_debug.LOG_LEVEL_INFO)
		else:
			firebase_debug.debug_log("Auth is busy, skipping refresh", firebase_debug.LOG_LEVEL_WARNING)
			# Wait a moment for possible auth operations to complete
			await get_tree().create_timer(1.0).timeout
		
		# Final check to see if we have a valid token
		if Firebase.Auth.auth.has("idtoken"):
			firebase_debug.debug_log("Token exists after refresh attempt", firebase_debug.LOG_LEVEL_INFO)
			return true
		else:
			firebase_debug.debug_log("No token after refresh attempts", firebase_debug.LOG_LEVEL_ERROR)
			return false
	else:
		firebase_debug.debug_log("Auth is null, cannot refresh", firebase_debug.LOG_LEVEL_ERROR)
		return false

# Helper function to create a default user document
func _create_default_user_document(user_id):
	# Simplified to just create essential fields
	var collection = Firebase.Firestore.collection("dyslexia_users")
	var current_time = Time.get_datetime_string_from_system(false, true)
	
	var display_name = Firebase.Auth.auth.get("displayname", "Player")
	var email = Firebase.Auth.auth.get("email", "")
	
	var user_doc = {
		"username": display_name if display_name else "Player",
		"email": email,
		"user_level": 1,
		"energy": 20,
		"max_energy": 20,
		"created_at": current_time,
		"last_login": current_time
	}
	
	print("Creating default user document for ID: ", user_id)
	var task = collection.add(user_id, user_doc)
	
	if task:
		# Connect to the signal
		task.task_finished.connect(func(result):
			if result and !result.error:
				print("Default user document created successfully")
				# Use the data we just created
				user_data.username = display_name if display_name else "Player"
				user_data.level = 1
				user_data.energy = 20
				user_data.max_energy = 20
				update_user_interface()
			else:
				print("Error creating default user document")
				update_user_interface()
			)
	else:
		print("Failed to create task for default user document")
		update_user_interface()

# Update both UI and user's avatar
func update_user_interface():
	name_label.text = user_data.username
	level_label.text = str(user_data.level)
	energy_label.text = str(user_data.energy) + "/" + str(user_data.max_energy)
	
	# Update avatar
	update_profile_avatar(user_data.profile_picture)

# Function to update the avatar in the profile button
func update_profile_avatar(profile_id):
	if has_node("ProfileButton/AvatarBackground"):
		var avatar_rect = $ProfileButton/AvatarBackground
		var texture_path
		
		if profile_id == "default" or profile_id == "":
			texture_path = "res://gui/ProfileScene/Profile/portrait 14.png"
		else:
			texture_path = "res://gui/ProfileScene/Profile/portrait " + profile_id + ".png"
		
		var texture = load(texture_path)
		if texture:
			# Create TextureRect if one doesn't exist
			var avatar_image
			if avatar_rect.get_child_count() == 0:
				avatar_image = TextureRect.new()
				avatar_image.name = "AvatarImage"
				avatar_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				avatar_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				avatar_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				avatar_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
				# Fix: Use the correct layout mode constant
				avatar_image.layout_mode = 1 # Use 1 instead of non-existent LAYOUT_MODE_ANCHORS_AND_OFFSETS
				avatar_image.set_anchors_preset(Control.PRESET_FULL_RECT)
				avatar_rect.add_child(avatar_image)
			else:
				avatar_image = avatar_rect.get_node("AvatarImage")
				
			avatar_image.texture = texture
			firebase_debug.debug_log("Profile avatar updated to: " + str(profile_id), firebase_debug.LOG_LEVEL_INFO)

func update_last_login():
	# Update last login time in Firestore (background task)
	if Firebase.Auth.auth:
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		var current_time = Time.get_datetime_string_from_system(false, true)
		var update_data = {"last_login": current_time}
		
		var update_task = collection.update(user_id, update_data)
		if update_task:
			# Connect to the signal but don't await it
			update_task.task_finished.connect(func(_result): 
				# Optionally handle result
				pass
			)

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
	
	# Ensure Firebase is properly initialized BEFORE showing profile
	if Firebase.Firestore == null or Firebase.Auth == null:
		firebase_debug.debug_log("Firebase needs initialization before showing profile", firebase_debug.LOG_LEVEL_WARNING)
		var init_result = await _initialize_firebase()
		firebase_debug.debug_log("Firebase initialization result: " + str(init_result), firebase_debug.LOG_LEVEL_INFO)
		await get_tree().create_timer(0.5).timeout
	
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
	# Refresh player info when profile popup closes as it might have changed
	print("Profile popup closed")
	load_user_data()

func _on_logout_button_pressed():
	print("Logging out")
	Firebase.Auth.logout()
	# Add a short delay before changing scene
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://Scenes/Authentication.tscn")
