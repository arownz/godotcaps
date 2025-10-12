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
var energy_recovery_rate = 180 # 3 minutes = 180 seconds (changed from 5 mins)
var energy_recovery_amount = 4 # Amount of energy recovered per interval
var last_energy_update_time = 0
var energy_recovery_timer = null

# Add real-time listener for Firestore document changes
var firestore_listener = null

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
    
    # Add energy processing timer (check every 10 seconds for recovery)
    var energy_process_timer = Timer.new()
    energy_process_timer.wait_time = 10.0 # Check every 10 seconds for better responsiveness
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
    
    # Add small delay to allow Firebase operations to complete if returning from another scene
    await get_tree().create_timer(0.1).timeout
    
    # Load user data first - with await
    await load_user_data()
    
    # Setup real-time listener for user document changes
    _setup_firestore_listener()
    
    # Wait one frame to ensure UI is fully loaded before updating character animation - with null check
    if is_inside_tree() and get_tree():
        await get_tree().process_frame
    
    # Update character animation AFTER data is loaded and UI is ready
    update_character_animation(user_data)

# Setup default character animation to play idle - IMPROVED for stability
func _setup_default_character_animation():
    # Ensure the node is still in the tree and valid
    if not is_inside_tree() or not get_tree():
        print("MainMenu: Node not in tree, skipping default character animation setup")
        return
        
    var character_area = $CharacterArea
    if character_area:
        var default_animation = character_area.get_node_or_null("DefaultPlayerAnimation")
        if default_animation:
            # Find the AnimatedSprite2D and play idle animation
            var sprite = default_animation.get_node_or_null("AnimatedSprite2D")
            if sprite and sprite.sprite_frames:
                if sprite.sprite_frames.has_animation("idle"):
                    sprite.play("idle")
                    print("MainMenu: Default character playing 'idle' animation")
                elif sprite.sprite_frames.has_animation("battle_idle"):
                    sprite.play("battle_idle")
                    print("MainMenu: Default character playing 'battle_idle' animation")
                else:
                    print("MainMenu: No idle animations found for default character")
            else:
                print("MainMenu: Default character AnimatedSprite2D not found")
        else:
            print("MainMenu: DefaultPlayerAnimation not found in CharacterArea")
    else:
        print("MainMenu: CharacterArea not found")

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
        }
    ]
    
    # Connect hover events
    for button_data in hover_buttons:
        if button_data.button and button_data.label:
            button_data.button.mouse_entered.connect(func(): _on_button_mouse_entered(button_data.label))
            button_data.button.mouse_exited.connect(func(): _on_button_mouse_exited(button_data.label))

# Connect button signals to their respective handler functions
func _connect_button_signals():
    var journey_btn = $BottomButtonsContainer/JourneyButton
    if journey_btn and !journey_btn.is_connected("pressed", _on_journey_mode_button_pressed):
        journey_btn.pressed.connect(_on_journey_mode_button_pressed)
    var modules_btn = $BottomButtonsContainer/ModulesButton
    if modules_btn and !modules_btn.is_connected("pressed", _on_modules_button_pressed):
        modules_btn.pressed.connect(_on_modules_button_pressed)
    var character_btn = $BottomButtonsContainer/CharacterButton
    if character_btn and !character_btn.is_connected("pressed", _on_character_button_pressed):
        character_btn.pressed.connect(_on_character_button_pressed)
    var leaderboard_btn = $BottomButtonsContainer/LeaderboardButton
    if leaderboard_btn and !leaderboard_btn.is_connected("pressed", _on_leaderboard_button_pressed):
        leaderboard_btn.pressed.connect(_on_leaderboard_button_pressed)
    var settings_btn = $BottomButtonsContainer/SettingsButton
    if settings_btn and !settings_btn.is_connected("pressed", _on_settings_button_pressed):
        settings_btn.pressed.connect(_on_settings_button_pressed)
    var profile_btn = $ProfileButton
    if profile_btn and !profile_btn.is_connected("pressed", _on_profile_button_pressed):
        profile_btn.pressed.connect(_on_profile_button_pressed)

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
                else:
                    user_data["username"] = "Player"
                    user_data["profile_picture"] = "default"
                
                # Get stats data
                var stats = document.get_value("stats")
                if stats != null and typeof(stats) == TYPE_DICTIONARY:
                    var player_stats = stats.get("player", {})
                    user_data["level"] = player_stats.get("level", 1)
                    user_data["energy"] = player_stats.get("energy", 20)
                    user_data["last_energy_update"] = player_stats.get("last_energy_update", 0)
                    
                    # Store full stats structure for character animation
                    user_data["stats"] = stats
                else:
                    user_data["level"] = 1
                    user_data["energy"] = 20
                    user_data["last_energy_update"] = 0
                    
                    # Create default stats structure for character animation
                    user_data["stats"] = {
                        "player": {
                            "current_character": "lexia"
                        }
                    }
                
                # Process energy recovery based on time passed
                _process_energy_recovery()
                
                # Handle session tracking and usage_time for returning users
                _update_session_tracking()
                
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
			"profile_picture": "default",
			"rank": "bronze",
			"created_at": current_time,
			"usage_time": 0,
			"session": 1,
			"last_session_date": Time.get_date_string_from_system()
		},
		"stats": {
			"player": {
				"level": 1,
				"exp": 0,
				"health": 100,
				"damage": 10,
				"durability": 5,
				"base_health": 100,
				"base_damage": 10,
				"base_durability": 5,
				"energy": 20,
				"last_energy_update": 0,
				"current_character": "lexia"
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
				"current_stage": 1
			}
		},
		"modules": {
			"phonics": {
				"completed": false,
				"progress": 0,
				"letters_completed": [],
				"sight_words_completed": [],
				"current_letter_index": 0,
				"current_sight_word_index": 0
			},
			"flip_quiz": {
				"completed": false,
				"progress": 0,
				"animals": {"sets_completed": [], "current_index": 0},
				"vehicles": {"sets_completed": [], "current_index": 0}
			},
			"read_aloud": {
				"completed": false,
				"progress": 0,
				"guided_reading": {"activities_completed": [], "current_index": 0},
				"syllable_workshop": {"activities_completed": [], "current_word_index": 0}
			}
		},
		"stage_times": {
			"dungeon_1": {},
			"dungeon_2": {},
			"dungeon_3": {}
		},
		"characters": {
			"unlocked_count": 1,
			"selected_character": 0,
			"unlock_notifications_shown": []
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
    
    print("Processing energy recovery - Current: " + str(current_energy) + ", Last update: " + str(last_update))
    
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
    
    print("Time passed: " + str(time_passed) + " seconds, Recovery intervals: " + str(recovery_intervals))
    
    if recovery_intervals > 0:
        var energy_to_recover = recovery_intervals * energy_recovery_amount
        var new_energy = min(current_energy + energy_to_recover, max_energy)
        var new_last_update = last_update + (recovery_intervals * energy_recovery_rate)
        
        # If energy reached max, set timestamp to current time
        if new_energy >= max_energy:
            new_last_update = current_time
        
        if new_energy != current_energy:
            print("Recovering energy: " + str(current_energy) + " -> " + str(new_energy))
            # Update energy in Firebase
            _update_energy_in_firebase(new_energy, new_last_update)
            user_data["energy"] = new_energy
            user_data["last_energy_update"] = new_last_update
            
            # Update UI immediately
            energy_label.text = str(new_energy) + "/" + str(max_energy)
            _update_energy_recovery_display()
            
            print("Energy recovered and UI updated: " + str(current_energy) + " -> " + str(new_energy))
            print("MainMenu: Energy label now shows: " + energy_label.text)

# Setup polling-based Firestore listener for user document changes
func _setup_firestore_listener():
    # Note: This godot-firebase extension doesn't support real-time listeners
    # Instead, we'll rely on the energy processing timer to check for updates
    print("Firestore polling-based updates enabled via energy processing timer")
    
    # The energy processing timer will check for updates every 10 seconds
    # which should be sufficient for energy recovery updates

# Clean up when leaving scene
func _cleanup_firestore_listener():
    # No real-time listener to clean up, just a placeholder for consistency
    print("Energy polling system will stop when scene changes") # Handle session and usage_time tracking for returning users
    
func _update_session_tracking():
    var user_id = Firebase.Auth.auth.localid
    if not user_id:
        return
        
    var collection = Firebase.Firestore.collection("dyslexia_users")
    var today_date = Time.get_date_string_from_system() # Format: YYYY-MM-DD
    
    # Get the document to update session tracking
    var document = await collection.get_doc(user_id)
    if document and document.has_method("get_value"):
        var profile = document.get_value("profile")
        if profile != null and typeof(profile) == TYPE_DICTIONARY:
            # Initialize usage_time if it doesn't exist (migration from old last_login to last_session_date)
            if not profile.has("usage_time"):
                profile["usage_time"] = 0
            
            # Handle daily session tracking
            if not profile.has("session"):
                profile["session"] = 1
                profile["last_session_date"] = today_date
            elif not profile.has("last_session_date") or profile.get("last_session_date", "") != today_date:
                # Increment session count only if user hasn't played today
                profile["session"] = profile.get("session", 0) + 1
                profile["last_session_date"] = today_date
                print("DEBUG: Session incremented to " + str(profile["session"]) + " for new day: " + today_date)
            else:
                print("DEBUG: User already played today (" + today_date + "), session count remains: " + str(profile.get("session", 0)))
            
            # Update the document
            document.add_or_update_field("profile", profile)
            await collection.update(document)

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
    
    # Check if energy should be recovered (every second check)
    if time_since_last_recovery >= energy_recovery_rate:
        print("Energy recovery triggered by display update")
        _process_energy_recovery()
        return # Return early to let the next call show updated values
    
    var minutes = int(time_until_next_energy / 60)
    var seconds = int(time_until_next_energy) % 60
    
    energy_timer_label.text = "Next energy in: %d:%02d" % [minutes, seconds]
    energy_timer_label.visible = true

# Update UI with user data - UPDATED for energy recovery and stable character loading
func update_user_interface():
    # Access data using dictionary syntax since we're storing it that way
    name_label.text = user_data.get("username", "Player")
    level_label.text = str(user_data.get("level", 1))
    
    var current_energy = user_data.get("energy", 0)
    energy_label.text = str(current_energy) + "/" + str(max_energy)
    
    print("MainMenu: Updated UI - Energy: " + str(current_energy) + "/" + str(max_energy))
    
    # Update energy recovery display
    _update_energy_recovery_display()
    
    # Update profile avatar
    update_profile_picture(user_data.get("profile_picture", "default"))
    
    # Character animation will be updated separately in _ready() after UI is fully loaded
    print("MainMenu: Basic UI updated, character animation will be handled separately")

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
    $ButtonClick.play()
    print("MainMenu: Navigating to journey mode scene")
    _cleanup_firestore_listener()
    get_tree().change_scene_to_file("res://Scenes/DungeonSelection.tscn")

func _on_modules_button_pressed():
    $ButtonClick.play()
    print("MainMenu: Navigating to modules scene")
    _cleanup_firestore_listener()
    get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

func _on_character_button_pressed():
    $ButtonClick.play()
    print("MainMenu: Navigating to character selection screen")
    _cleanup_firestore_listener()
    get_tree().change_scene_to_file("res://Scenes/ChangeCharacterScene.tscn")

func _on_leaderboard_button_pressed():
    $ButtonClick.play()
    print("MainMenu: Navigating to leaderboard screen")
    _cleanup_firestore_listener()
    get_tree().change_scene_to_file("res://Scenes/Leaderboard.tscn")

func _on_settings_button_pressed():
    $ButtonClick.play()
    print("MainMenu: Opening settings popup")
    _cleanup_firestore_listener()
    var settings_popup_scene = load("res://Scenes/SettingScene.tscn")
    if settings_popup_scene:
        var popup = settings_popup_scene.instantiate()
        add_child(popup)
        if popup.has_method("set_context"):
            popup.set_context(false) # normal settings; hide battle buttons

func _on_profile_button_pressed():
    $ButtonClick.play()
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

func _on_profile_button_mouse_entered():
    $ButtonHover.play()

func _on_settings_button_mouse_entered():
    $ButtonHover.play()

func _on_leaderboard_button_mouse_entered():
    $ButtonHover.play()

func _on_character_button_mouse_entered():
    $ButtonHover.play()

func _on_modules_button_mouse_entered():
    $ButtonHover.play()

func _on_journey_button_mouse_entered():
    $ButtonHover.play()
    

# Make sure we properly force reload user data after profile popup closes
func _on_profile_popup_closed():
    # Refresh player info when profile popup closes
    print("Profile popup closed, refreshing user data")
    
    # Force reload user data from Firestore
    await load_user_data()
    
    # Wait one frame to ensure UI is stable before updating animations - with null check
    if is_inside_tree() and get_tree():
        await get_tree().process_frame
    
    # Update character animation after data reload (in case character was changed)
    update_character_animation(user_data)
    
    # Additional debug to verify the update
    if "profile_picture" in user_data:
        print("MainMenu: After popup closed - profile picture is now: " + user_data.get("profile_picture", "default"))
        # Force explicit refresh of the profile picture
        update_profile_picture(user_data.get("profile_picture", "default"))

func _on_logout_button_pressed():
    print("Logging out")
    # Stop usage time tracking before logout
    _stop_usage_time_tracking()
    # Clean up Firestore listener
    _cleanup_firestore_listener()
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
        _cleanup_firestore_listener()
    elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
        # Refresh user data when window gets focus (e.g., returning from battle or character selection)
        if is_inside_tree() and get_tree():
            print("MainMenu: Window focused, refreshing user data and character animation")
            await load_user_data()
    elif what == NOTIFICATION_VISIBILITY_CHANGED:
        # Refresh user data when scene becomes visible (including character animation)
        if visible and is_inside_tree() and get_tree():
            print("MainMenu: Scene became visible, refreshing user data and character animation")
            await load_user_data()

# Public method to force refresh user data - can be called when returning from other scenes
func refresh_user_data():
    if is_inside_tree() and get_tree():
        print("MainMenu: Force refreshing user data")
        await load_user_data()
    else:
        print("MainMenu: Cannot refresh user data - node not in tree")

# Helper function to get character animation path from character name
func _get_character_animation_path(character_name: String) -> String:
    match character_name.to_lower():
        "lexia":
            return "res://Sprites/Animation/Lexia_Animation.tscn"
        "ragna":
            return "res://Sprites/Animation/Ragna_Animation.tscn"
        _:
            return "res://Sprites/Animation/Lexia_Animation.tscn"

# Override _exit_tree to ensure cleanup
func _exit_tree():
    _cleanup_firestore_listener()
    _stop_usage_time_tracking()

# Update character animation based on selected character - FIXED to prevent loading corruption
func update_character_animation(data):
    # Ensure the node is still in the tree and valid
    if not is_inside_tree() or not get_tree():
        print("MainMenu: Node not in tree, skipping character animation update")
        return
        
    # Ensure we have valid data before proceeding
    if not data or data.is_empty():
        print("MainMenu: No data available for character animation, using default")
        _setup_default_character_animation()
        return
    
    var stats = data.get("stats", {})
    if stats.has("player"):
        var player_data = stats["player"]
        var current_character = player_data.get("current_character", "lexia")
        var character_skin = _get_character_animation_path(current_character)
        
        print("MainMenu: Loading character animation - Character: " + current_character + ", Animation: " + character_skin)
        
        # Get the CharacterArea node
        var character_area = $CharacterArea
        if character_area:
            # Check if we already have the correct animation loaded to avoid unnecessary reloading
            var existing_animation = character_area.get_node_or_null("DefaultPlayerAnimation")
            if existing_animation:
                # Check if this is already the correct character animation
                var current_scene_path = existing_animation.scene_file_path
                if current_scene_path == character_skin:
                    print("MainMenu: Character animation already loaded correctly, just ensuring idle plays")
                    var sprite = existing_animation.get_node_or_null("AnimatedSprite2D")
                    if sprite and sprite.sprite_frames:
                        if sprite.sprite_frames.has_animation("idle"):
                            sprite.play("idle")
                        elif sprite.sprite_frames.has_animation("battle_idle"):
                            sprite.play("battle_idle")
                    return
                
                # Different animation needed, remove the old one safely
                existing_animation.queue_free()
                if is_inside_tree() and get_tree():
                    await get_tree().process_frame # Wait for node to be freed
            
            # Load the new character animation with error handling
            if ResourceLoader.exists(character_skin):
                var animation_scene = load(character_skin)
                if animation_scene:
                    var new_animation = animation_scene.instantiate()
                    new_animation.name = "DefaultPlayerAnimation"
                    character_area.add_child(new_animation)
                    
                    # Wait one frame for the node to be fully added - with null check
                    if is_inside_tree() and get_tree():
                        await get_tree().process_frame
                    
                    # Play idle animation - check for idle first, then battle_idle
                    var sprite = new_animation.get_node_or_null("AnimatedSprite2D")
                    if sprite and sprite.sprite_frames:
                        if sprite.sprite_frames.has_animation("idle"):
                            sprite.play("idle")
                            print("MainMenu: Playing 'idle' animation")
                        elif sprite.sprite_frames.has_animation("battle_idle"):
                            sprite.play("battle_idle")
                            print("MainMenu: Playing 'battle_idle' animation")
                        else:
                            print("MainMenu: No idle animations found, available animations: " + str(sprite.sprite_frames.get_animation_names()))
                    else:
                        print("MainMenu: AnimatedSprite2D node or sprite_frames not found")
                    
                    print("MainMenu: Character animation updated successfully - " + current_character)
                else:
                    print("MainMenu: Failed to instantiate character animation scene: " + character_skin)
                    _setup_default_character_animation()
            else:
                print("MainMenu: Character animation file does not exist: " + character_skin)
                _setup_default_character_animation()
        else:
            print("MainMenu: CharacterArea not found")
    else:
        print("MainMenu: No player stats found, using default character animation")
        _setup_default_character_animation()