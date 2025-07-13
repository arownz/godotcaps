extends Control

# User data variables - simplified to only essential fields
var user_data = {}

# UI References
@onready var name_label = $InfoContainer/NameLabel
@onready var level_label = $InfoContainer/LevelContainer/LevelLabel
@onready var energy_label = $EnergyDisplay/EnergyLabel
@onready var avatar_background = $ProfileButton/AvatarBackground # Reference to avatar background

# Buttons with hover labels
var hover_buttons = []

# Add energy recovery system variables
var max_energy = 20
var energy_recovery_rate = 240 # 4 minutes in seconds
var energy_recovery_amount = 4 # Amount of energy recovered per interval
var last_energy_update_time = 0
var energy_recovery_timer = null

# Add usage time tracking system variables
var usage_time_start = 0.0
var usage_time_timer = null
var usage_time_update_interval = 30.0 # Update every 30 seconds

func _ready():
    # Setup hover buttons for UI interaction
    _setup_hover_buttons()
    
    # Connect button signals
    _connect_button_signals()
    
    # Setup energy recovery timer
    energy_recovery_timer = Timer.new()
    energy_recovery_timer.wait_time = 1.0 # Update every second
    energy_recovery_timer.timeout.connect(_update_energy_recovery_display)
    energy_recovery_timer.autostart = true
    add_child(energy_recovery_timer)
    
    # Add energy processing timer (check every 30 seconds for recovery)
    var energy_process_timer = Timer.new()
    energy_process_timer.wait_time = 30.0 # Check every 30 seconds
    energy_process_timer.timeout.connect(_process_energy_recovery)
    energy_process_timer.autostart = true
    add_child(energy_process_timer)
    
    # Setup usage time tracking timer
    usage_time_timer = Timer.new()
    usage_time_timer.wait_time = usage_time_update_interval
    usage_time_timer.timeout.connect(_update_usage_time_in_firebase)
    usage_time_timer.autostart = false # Don't start automatically
    add_child(usage_time_timer)
    
    # Start usage time tracking when main menu loads
    _start_usage_time_tracking()
    
    # Load user data - with await
    await load_user_data()

# Setup hover buttons for improved UI interaction
func _setup_hover_buttons():
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
        {
            "button": $BottomButtonsContainer/JourneyButton,
            "label": $BottomButtonsContainer/JourneyButton/JourneyLabel
        },
        {
            "button": $BottomButtonsContainer/SettingsButton,
            "label": $BottomButtonsContainer/SettingsButton/SettingsLabel
        },
        {
            "button": $ProfileButton,
            "label": $ProfileButton/ProfileLabel
        },
        {
            "button": $EnergyDisplay,
            "label": $EnergyDisplay/EnergyTooltip
        }
    ]
    
    # Connect hover events
    for button_data in hover_buttons:
        if button_data.button and button_data.label:
            button_data.button.mouse_entered.connect(func(): _on_button_mouse_entered(button_data.label))
            button_data.button.mouse_exited.connect(func(): _on_button_mouse_exited(button_data.label))

# Connect button signals to their respective handler functions
func _connect_button_signals():
    $BottomButtonsContainer/JourneyButton.pressed.connect(_on_journey_mode_button_pressed)
    $BottomButtonsContainer/ModulesButton.pressed.connect(_on_modules_button_pressed)
    $BottomButtonsContainer/CharacterButton.pressed.connect(_on_character_button_pressed)
    $BottomButtonsContainer/LeaderboardButton.pressed.connect(_on_leaderboard_button_pressed)
    $BottomButtonsContainer/SettingsButton.pressed.connect(_on_settings_button_pressed)
    $ProfileButton.pressed.connect(_on_profile_button_pressed)

# Button hover handlers
func _on_button_mouse_entered(label):
    if label: label.visible = true

func _on_button_mouse_exited(label):
    if label: label.visible = false

# Core function to load user data from Firestore
func load_user_data():
    # Check if user is authenticated
    if !Firebase.Auth.auth:
        print("No user authenticated, redirecting to login")
        get_tree().change_scene_to_file("res://Scenes/Authentication.tscn")
        return
    
    print("Loading user data")
    var user_id = Firebase.Auth.auth.localid
    
    # Check if Firestore is ready
    if Firebase.Firestore == null:
        print("Firebase Firestore is null")
        update_user_interface()
        return
    
    # Simple direct Firestore fetch - using the pattern that works
    var collection = Firebase.Firestore.collection("dyslexia_users")
    print("Requesting document for user: " + user_id)
    
    # Use the direct await pattern for Firestore
    var document = await collection.get_doc(user_id)
    
    if document:
        print("Document fetched successfully")
        _process_document(document)
    else:
        print("Failed to fetch document")
        update_user_interface()

# Process the Firestore document data - UPDATED for energy recovery
func _process_document(document):
    if document == null:
        print("Document is null")
        update_user_interface()
        return
        
    # Check for errors
    var has_error = false
    var error_data = null
    
    if document.has_method("keys"):
        var doc_keys = document.keys()
        
        # Check for document error
        if "error" in doc_keys:
            error_data = document.get_value("error")
            if error_data:
                has_error = true
                
                # Handle document not found - create a new one
                if typeof(error_data) == TYPE_DICTIONARY and error_data.has("status") and error_data.status == "NOT_FOUND":
                    print("Document not found. Creating default.")
                    _create_default_user_document(Firebase.Auth.auth.localid)
                    return
        
        if !has_error:
            # Extract fields from new nested structure into our flat user_data dictionary
            user_data = {} # Reset user_data to avoid mixing old and new data
            
            if document.has_method("get_value"):
                # Get profile data
                var profile = document.get_value("profile")
                if profile != null and typeof(profile) == TYPE_DICTIONARY:
                    # Extract the profile data we need into our user_data dictionary
                    user_data["username"] = profile.get("username", "Player")
                    user_data["profile_picture"] = profile.get("profile_picture", "default")
                    user_data["last_login"] = profile.get("last_login", "")
                else:
                    user_data["username"] = "Player"
                    user_data["profile_picture"] = "default"
                    user_data["last_login"] = ""
                
                # Get stats data
                var stats = document.get_value("stats")
                if stats != null and typeof(stats) == TYPE_DICTIONARY:
                    var player_stats = stats.get("player", {})
                    user_data["level"] = player_stats.get("level", 1)
                    user_data["energy"] = player_stats.get("energy", 20)
                    user_data["last_energy_update"] = player_stats.get("last_energy_update", 0)
                else:
                    user_data["level"] = 1
                    user_data["energy"] = 20
                    user_data["last_energy_update"] = 0
                
                # Process energy recovery based on time passed
                _process_energy_recovery()
                
                print("Loaded user data from new structure: ", user_data)
    
    update_user_interface()

# Create a default user document in Firestore
func _create_default_user_document(user_id):
    var collection = Firebase.Firestore.collection("dyslexia_users")
    
    # Get user info from Auth if available
    var display_name = Firebase.Auth.auth.get("displayname", "Player")
    var email = Firebase.Auth.auth.get("email", "")
    var current_time = Time.get_datetime_string_from_system(false, true)
    
    # Create document with the new structure
    var user_doc = {
        "profile": {
            "username": display_name,
            "email": email,
            "birth_date": "",
            "age": 0,
            "profile_picture": "default",
            "rank": "bronze",
            "created_at": current_time,
            "last_login": current_time
        },
        "stats": {
            "player": {
                "level": 1,
                "exp": 0,
                "health": 100,
                "damage": 10,
                "durability": 5,
                "energy": 20,
                "skin": "res://Sprites/Animation/DefaultPlayer_Animation.tscn"
            }
        },
        "word_challenges": {
            "completed": {
                "stt": 0,
                "whiteboard": 0
            },
            "failed": {
                "stt": 0,
                "whiteboard": 0
            }
        },
        "dungeons": {
            "completed": {
                "1": {"completed": false, "stages_completed": 0},
                "2": {"completed": false, "stages_completed": 0},
                "3": {"completed": false, "stages_completed": 0}
            },
            "progress": {
                "enemies_defeated": 0,
                "current_dungeon": 1,
            }
        }
    }
    
    # Add document to Firestore
    var task = collection.add(user_id, user_doc)
    if task:
        task.task_finished.connect(func(_result):
            # Use default values we just created
            user_data.username = display_name if display_name else "Player"
            user_data.level = 1
            user_data.energy = 20
            user_data.profile_picture = "default"
            update_user_interface()
        )

# Add energy recovery processing
func _process_energy_recovery():
    var current_energy = user_data.get("energy", 20)
    var current_time = Time.get_unix_time_from_system()
    var last_update = user_data.get("last_energy_update", current_time)
    
    # If last_energy_update is 0 or invalid, set it to current time
    if last_update == 0:
        last_update = current_time
        _update_energy_timestamp(current_time)
        return
    
    # If already at max energy, update timestamp to current time to stop recovery attempts
    if current_energy >= max_energy:
        if last_update < current_time - energy_recovery_rate:
            _update_energy_timestamp(current_time)
        return
    
    var time_passed = current_time - last_update
    var recovery_intervals = int(time_passed / energy_recovery_rate)
    
    if recovery_intervals > 0:
        var energy_to_recover = recovery_intervals * energy_recovery_amount
        var new_energy = min(current_energy + energy_to_recover, max_energy)
        var new_last_update = last_update + (recovery_intervals * energy_recovery_rate)
        
        # If energy reached max, set timestamp to current time
        if new_energy >= max_energy:
            new_last_update = current_time
        
        if new_energy != current_energy:
            # Update energy in Firebase
            _update_energy_in_firebase(new_energy, new_last_update)
            user_data["energy"] = new_energy
            user_data["last_energy_update"] = new_last_update
            print("Energy recovered: " + str(current_energy) + " -> " + str(new_energy))

func _update_energy_in_firebase(new_energy: int, new_timestamp: float):
    if !Firebase.Auth.auth:
        return
        
    var user_id = Firebase.Auth.auth.localid
    var collection = Firebase.Firestore.collection("dyslexia_users")
    
    # Get the document first
    var document = await collection.get_doc(user_id)
    if document and !("error" in document.keys() and document.get_value("error")):
        # Get current stats structure
        var stats = document.get_value("stats")
        if stats != null and typeof(stats) == TYPE_DICTIONARY:
            var player_stats = stats.get("player", {})
            player_stats["energy"] = new_energy
            player_stats["last_energy_update"] = new_timestamp
            stats["player"] = player_stats
            
            # Update the document
            document.add_or_update_field("stats", stats)
            
            # Save the updated document
            var updated_document = await collection.update(document)
            if updated_document:
                print("Energy updated to: " + str(new_energy) + " at timestamp: " + str(new_timestamp))
            else:
                print("Failed to update energy in Firebase")
        else:
            print("Stats structure not found in document")
    else:
        print("Failed to get document for energy update")

func _update_energy_timestamp(timestamp: float):
    if !Firebase.Auth.auth:
        return
        
    var user_id = Firebase.Auth.auth.localid
    var collection = Firebase.Firestore.collection("dyslexia_users")
    
    # Get the document first
    var document = await collection.get_doc(user_id)
    if document and !("error" in document.keys() and document.get_value("error")):
        # Get current stats structure
        var stats = document.get_value("stats")
        if stats != null and typeof(stats) == TYPE_DICTIONARY:
            var player_stats = stats.get("player", {})
            player_stats["last_energy_update"] = timestamp
            stats["player"] = player_stats
            
            # Update the document field
            document.add_or_update_field("stats", stats)
            
            # Update the document using the correct method
            var updated_document = await collection.update(document)
            if updated_document:
                print("Energy timestamp updated to: " + str(timestamp))
            else:
                print("Failed to update energy timestamp")
        else:
            print("Stats structure not found in document")
    else:
        print("Failed to get document for timestamp update")

func _update_energy_recovery_display():
    var current_energy = user_data.get("energy", 20)
    var energy_timer_label = $EnergyDisplay/EnergyRecoveryTimer
    
    if current_energy >= max_energy:
        energy_timer_label.visible = false
        return
    
    var current_time = Time.get_unix_time_from_system()
    var last_update = user_data.get("last_energy_update", current_time)
    var time_since_last_recovery = current_time - last_update
    var time_until_next_energy = energy_recovery_rate - fmod(time_since_last_recovery, energy_recovery_rate)
    
    var minutes = int(time_until_next_energy / 60)
    var seconds = int(time_until_next_energy) % 60
    
    energy_timer_label.text = "Next energy in: %d:%02d" % [minutes, seconds]
    energy_timer_label.visible = true

# Update UI with user data - UPDATED for energy recovery
func update_user_interface():
    # Access data using dictionary syntax since we're storing it that way
    name_label.text = user_data.get("username", "Player")
    level_label.text = str(user_data.get("level", 1))
    
    var current_energy = user_data.get("energy", 0)
    energy_label.text = str(current_energy) + "/" + str(max_energy)
    
    # Update energy recovery display
    _update_energy_recovery_display()
    
    # Update profile avatar
    update_profile_picture(user_data.get("profile_picture", "default"))

# Update profile avatar with the given image ID
func update_profile_picture(profile_id):
    print("MainMenu: Updating profile picture to: " + str(profile_id))
    
    if has_node("ProfileButton/AvatarBackground"):
        var avatar_rect = $ProfileButton/AvatarBackground
        var texture_path
        
        # Set texture path based on profile ID
        if profile_id == "default":
            print("MainMenu: Converting 'default' to profile ID '13'")
            profile_id = "13" # Map default to portrait 13
        
        texture_path = "res://gui/ProfileScene/Profile/portrait" + profile_id + ".png"
        print("MainMenu: Loading texture from: " + texture_path)
        
        # Load and apply texture
        var texture = load(texture_path)
        if texture:
            # Create or get avatar image node
            var avatar_image
            if avatar_rect.get_child_count() == 0:
                avatar_image = TextureRect.new()
                avatar_image.name = "AvatarImage"
                avatar_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                avatar_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                avatar_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                avatar_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
                avatar_image.layout_mode = 1
                avatar_image.set_anchors_preset(Control.PRESET_FULL_RECT)
                avatar_rect.add_child(avatar_image)
            else:
                avatar_image = avatar_rect.get_node("AvatarImage")
                
            avatar_image.texture = texture
        else:
            print("Failed to load texture for profile ID: " + profile_id)
    else:
        print("Avatar background node not found")

# Button handlers
func _on_journey_mode_button_pressed():
    print("MainMenu: Navigating to journey mode scene")
    get_tree().change_scene_to_file("res://Scenes/DungeonSelection.tscn")

func _on_modules_button_pressed():
    print("MainMenu: Navigating to modules scene")
    get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

func _on_character_button_pressed():
    print("MainMenu: Navigating to character selection screen")
    get_tree().change_scene_to_file("res://Scenes/ChangeCharacterScene.tscn")

func _on_leaderboard_button_pressed():
    print("MainMenu: Navigating to leaderboard screen")
    get_tree().change_scene_to_file("res://Scenes/Leaderboard.tscn")

func _on_settings_button_pressed():
    print("MainMenu: Navigating to settings screen")
    get_tree().change_scene_to_file("res://Scenes/SettingScene.tscn")

func _on_profile_button_pressed():
    print("MainMenu: Navigating to profile popup")
    # Show profile popup
    var profile_popup_scene = load("res://Scenes/ProfilePopUp.tscn")
    if profile_popup_scene:
        var profile_popup = profile_popup_scene.instantiate()
        add_child(profile_popup)
        profile_popup.visible = true
        
        # Connect the closed signal
        if profile_popup.has_signal("closed"):
            profile_popup.connect("closed", Callable(self, "_on_profile_popup_closed"))

# Make sure we properly force reload user data after profile popup closes
func _on_profile_popup_closed():
    # Refresh player info when profile popup closes
    print("Profile popup closed, refreshing user data")
    
    # Force reload user data from Firestore
    await load_user_data()
    
    # Additional debug to verify the update
    if "profile_picture" in user_data:
        print("MainMenu: After popup closed - profile picture is now: " + user_data.get("profile_picture", "default"))
        # Force explicit refresh of the profile picture
        update_profile_picture(user_data.get("profile_picture", "default"))

func _on_logout_button_pressed():
    print("Logging out")
    # Stop usage time tracking before logout
    _stop_usage_time_tracking()
    Firebase.Auth.logout()
    # Add a short delay before changing scenes
    await get_tree().create_timer(0.2).timeout
    get_tree().change_scene_to_file("res://Scenes/Authentication.tscn")

# ===== Usage Time Tracking System =====
func _start_usage_time_tracking():
    # Start tracking usage time when user enters main menu
    usage_time_start = Time.get_unix_time_from_system()
    if usage_time_timer:
        usage_time_timer.start()
    print("DEBUG: Started usage time tracking at: " + str(usage_time_start))

func _stop_usage_time_tracking():
    # Stop tracking usage time when user logs out or leaves main menu
    if usage_time_timer:
        usage_time_timer.stop()
    
    # Update usage time one final time before stopping
    _update_usage_time_in_firebase()
    print("DEBUG: Stopped usage time tracking")

func _update_usage_time_in_firebase():
    # Update usage_time in Firebase following energy system pattern
    if !Firebase.Auth.auth or !Firebase.Auth.auth.has("localid"):
        print("DEBUG: No auth data, skipping usage time update")
        return
    
    if usage_time_start <= 0:
        print("DEBUG: Usage time tracking not started, skipping update")
        return
    
    var current_time = Time.get_unix_time_from_system()
    var session_time = current_time - usage_time_start
    
    # Reset start time for next interval
    usage_time_start = current_time
    
    print("DEBUG: Updating usage time with session time: " + str(session_time))
    
    var user_id = Firebase.Auth.auth.localid
    var collection = Firebase.Firestore.collection("dyslexia_users")
    
    # Get the document first - following exact energy system pattern
    var document = await collection.get_doc(user_id)
    if document and !("error" in document.keys() and document.get_value("error")):
        # Handle both profile structure and stats structure
        var profile_data = document.get_value("profile")
        if profile_data != null and typeof(profile_data) == TYPE_DICTIONARY:
            var current_usage_time = profile_data.get("usage_time", 0.0)
            var new_usage_time = current_usage_time + session_time
            profile_data["usage_time"] = new_usage_time
            
            # Update the document field
            document.add_or_update_field("profile", profile_data)
            print("DEBUG: Updated usage time in profile structure: " + str(current_usage_time) + " -> " + str(new_usage_time))
        else:
            # Fallback to root level for older accounts
            var current_usage_time = document.get_value("usage_time") if document.get_value("usage_time") != null else 0.0
            var new_usage_time = current_usage_time + session_time
            document.add_or_update_field("usage_time", new_usage_time)
            print("DEBUG: Updated usage time in root structure: " + str(current_usage_time) + " -> " + str(new_usage_time))
        
        # Update the document using the correct method
        var updated_document = await collection.update(document)
        if updated_document:
            print("DEBUG: Usage time successfully updated in Firebase")
        else:
            print("ERROR: Failed to update usage time in Firebase")
    else:
        print("ERROR: Failed to get document for usage time update")

# Override the scene exit to stop usage time tracking
func _notification(what):
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
        _stop_usage_time_tracking()