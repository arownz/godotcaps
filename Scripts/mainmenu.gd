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

# Add reference to our debug helper
var firebase_debug = preload("res://Scripts/firebase_debug.gd").new()

func _ready():

    # Add debug helper
    add_child(firebase_debug)
    
    # Setup hover buttons for UI interaction
    _setup_hover_buttons()
    
    # Connect button signals
    _connect_button_signals()
    
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

# Process the Firestore document data
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
            # Extract essential fields using get_value
            if document.has_method("get_value"):
                user_data.username = document.get_value("username") if "username" in doc_keys else "Player"
                user_data.level = document.get_value("user_level") if "user_level" in doc_keys else 1
                user_data.energy = document.get_value("energy") if "energy" in doc_keys else 20
                user_data.max_energy = document.get_value("max_energy") if "max_energy" in doc_keys else 20
                user_data.profile_picture = document.get_value("profile_picture") if "profile_picture" in doc_keys else "default"
    
    update_user_interface()

# Create a default user document in Firestore
func _create_default_user_document(user_id):
    var collection = Firebase.Firestore.collection("dyslexia_users")
    
    # Get user info from Auth if available
    var display_name = Firebase.Auth.auth.get("displayname", "Player")
    
    # Create minimal document with essential fields
    var user_doc = {}
    
    # Add document to Firestore
    var task = collection.add(user_id, user_doc)
    if task:
        task.task_finished.connect(func(_result):
            # Use default values we just created
            user_data.username = display_name if display_name else "Player"
            user_data.level = 1
            user_data.energy = 20
            user_data.max_energy = 20
            update_user_interface()
        )

# Update UI with user data
func update_user_interface():
    name_label.text = user_data.username
    level_label.text = str(user_data.level)
    energy_label.text = str(user_data.energy) + "/" + str(user_data.max_energy)
    
    # Update profile avatar
    update_profile_picture(user_data.profile_picture)

# Update profile avatar with the given image ID
func update_profile_picture(profile_id):
    print("MainMenu: Updating profile picture to: " + str(profile_id))
    
    if has_node("ProfileButton/AvatarBackground"):
        var avatar_rect = $ProfileButton/AvatarBackground
        var texture_path
        
        # Set texture path based on profile ID
        if profile_id == "default":
            print("MainMenu: Converting 'default' to profile ID '13'")
            profile_id = "13"  # Map default to portrait 13
        
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
    get_tree().change_scene_to_file("res://Scenes/DungeonSelection.tscn")

func _on_modules_button_pressed():
    # Placeholder for modules screen
    pass

func _on_character_button_pressed():
    # Placeholder for character screen
    pass

func _on_leaderboard_button_pressed():
    # Placeholder for leaderboard screen
    pass

func _on_settings_button_pressed():
    # Placeholder for settings screen
    pass

func _on_profile_button_pressed():
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
    if user_data.has("profile_picture"):
        print("MainMenu: After popup closed - profile picture is now: " + user_data.profile_picture)
        # Force explicit refresh of the profile picture
        update_profile_picture(user_data.profile_picture)

func _on_logout_button_pressed():
    print("Logging out")
    Firebase.Auth.logout()
    # Add a short delay before changing scenes
    await get_tree().create_timer(0.2).timeout
    get_tree().change_scene_to_file("res://Scenes/Authentication.tscn")
