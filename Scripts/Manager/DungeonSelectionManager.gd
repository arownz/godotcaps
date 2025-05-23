extends Control

# Constants
const DUNGEON_COUNT = 3
const ANIMATION_DURATION = 0.5
const ANIMATION_EASE = Tween.EASE_OUT_IN

# Dungeon Properties
var current_dungeon = 0  # 0-based index (0 = Dungeon 1)
var unlocked_dungeons = 1  # How many dungeons are unlocked (at least 1)
var dungeon_names = ["The Plain", "The Forest", "The Mountain"]
var dungeon_textures = {
    "unlocked": [],
    "locked": []
}

# References to UI elements
@onready var dungeon_carousel = $DungeonContainer/DungeonCarousel
@onready var next_button = $NextButton
@onready var previous_button = $PreviousButton
@onready var play_button = $PlayButton

# Firebase references
var user_data = {}
# Selection indicator reference
var selection_indicators = []

# Add notification popup reference
var notification_popup: CanvasLayer

func _ready():
    # Preload dungeon textures
    dungeon_textures.unlocked = [
        preload("res://gui/Update/icons/level selection.png"),
        preload("res://gui/Update/icons/highest level.png"), # You'll need to create this
        preload("res://gui/Update/icons/level selection.png")  # You'll need to create this
    ]
    dungeon_textures.locked = [
        null, # Dungeon 1 is always unlocked
        preload("res://gui/dungeonselection/dungeon2_lock.png"),
        preload("res://gui/dungeonselection/dungeon3_lock.png")
    ]
    
    # Setup selection indicators for each dungeon
    for i in range(DUNGEON_COUNT):
        var dungeon_node = dungeon_carousel.get_child(i)
        
        # Create selection indicator (colorful border outline)
        var selection_indicator = ColorRect.new()
        selection_indicator.color = Color(1, 0.8, 0.2, 0.8)  # Golden outline
        selection_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
        selection_indicator.visible = false
        
        # Position the indicator as a border around the texture button
        dungeon_node.add_child(selection_indicator)
        selection_indicator.show_behind_parent = true
        selection_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        selection_indicator.offset_left = -5
        selection_indicator.offset_top = -5
        selection_indicator.offset_right = 5
        selection_indicator.offset_bottom = 5
        
        selection_indicators.append(selection_indicator)
    
    # Create notification popup
    notification_popup = load("res://Scenes/NotificationPopUp.tscn").instantiate()
    add_child(notification_popup)
    notification_popup.closed.connect(_on_notification_closed)
    
    # Load user data and update UI
    _load_user_data()
    
    # Set initial carousel position
    dungeon_carousel.position.x = 0
    update_dungeon_display()

# Load user data from Firebase
func _load_user_data():
    if Firebase.Auth.auth:
        var user_id = Firebase.Auth.auth.localid
        var collection = Firebase.Firestore.collection("dyslexia_users")
        
        var task = collection.get(user_id)
        if task:
            # Show loading indicator
            # ...
            
            await task.task_finished
            
            if task.error:
                print("Error loading user data: ", task.error)
            else:
                user_data = task.doc_fields
                
                # Extract dungeon progress data
                if user_data.has("dungeons_completed"):
                    # Count unlocked dungeons
                    unlocked_dungeons = 1 # Dungeon 1 always unlocked
                    
                    var dungeons = user_data.dungeons_completed
                    
                    # Check if dungeon 1 is completed
                    if dungeons.has("1") and dungeons["1"].has("completed") and dungeons["1"].completed:
                        unlocked_dungeons = 2
                        
                    # Check if dungeon 2 is completed
                    if unlocked_dungeons >= 2 and dungeons.has("2") and dungeons["2"].has("completed") and dungeons["2"].completed:
                        unlocked_dungeons = 3
                        
                # Set current dungeon based on user data
                if user_data.has("current_dungeon"):
                    current_dungeon = int(user_data.current_dungeon) - 1 # Convert to 0-based index
                
                print("Dungeons unlocked: ", unlocked_dungeons)
                print("Current dungeon: ", current_dungeon + 1)
                
                # Update UI with user data
                update_dungeon_display()
    else:
        # Demo mode - just unlock dungeon 1
        unlocked_dungeons = 1
        current_dungeon = 0
        update_dungeon_display()

# Update the dungeon display based on current selection and unlock status
func update_dungeon_display():
    for i in range(DUNGEON_COUNT):
        var dungeon_node = dungeon_carousel.get_child(i)
        var texture_button = dungeon_node.get_node("TextureButton")
        var status_label = dungeon_node.get_node("StatusLabel")
        
        # Check if dungeon is unlocked
        var is_unlocked = i < unlocked_dungeons
        
        # Set the appropriate texture
        if is_unlocked:
            texture_button.texture_normal = dungeon_textures.unlocked[i]
            status_label.text = "Unlocked"
            status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5)) # Green
        else:
            texture_button.texture_normal = dungeon_textures.locked[i]
            status_label.text = "Locked"
            status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)) # Red
            
        # Show selection indicator only on the current dungeon
        if i < selection_indicators.size():
            selection_indicators[i].visible = (i == current_dungeon)
    
    # Update button visibility
    next_button.visible = current_dungeon < DUNGEON_COUNT - 1
    previous_button.visible = current_dungeon > 0
    
    # Enable/disable play button based on selected dungeon's unlock status
    play_button.disabled = current_dungeon >= unlocked_dungeons

# Handle navigation buttons
func _on_next_button_pressed():
    if current_dungeon < DUNGEON_COUNT - 1:
        current_dungeon += 1
        _animate_carousel(-1) # Move left
        update_dungeon_display()

func _on_previous_button_pressed():
    if current_dungeon > 0:
        current_dungeon -= 1
        _animate_carousel(1) # Move right
        update_dungeon_display()

# Handle dungeon selection
func _on_dungeon1_pressed():
    if current_dungeon != 0:
        current_dungeon = 0
        _animate_carousel_to_position(0)
        update_dungeon_display()
    # Removed direct play button call

func _on_dungeon2_pressed():
    if unlocked_dungeons >= 2:
        if current_dungeon != 1:
            current_dungeon = 1
            _animate_carousel_to_position(1)
            update_dungeon_display()
        # Removed direct play button call
    else:
        # Use the new notification system instead
        notification_popup.show_notification("Dungeon Locked!", "Please complete 'The Plain' first to unlock this dungeon.", "OK")

func _on_dungeon3_pressed():
    if unlocked_dungeons >= 3:
        if current_dungeon != 2:
            current_dungeon = 2
            _animate_carousel_to_position(2)
            update_dungeon_display()
        # Removed direct play button call
    else:
        # Use the new notification system instead
        notification_popup.show_notification("Dungeon Locked!", "Please complete 'The Plain' and 'The Forest' first to unlock this dungeon.", "OK")

# Animation functions
func _animate_carousel(direction):
    var tween = create_tween()
    tween.set_ease(ANIMATION_EASE)
    tween.set_trans(Tween.TRANS_CUBIC)
    
    # Calculate the target position based on carousel width and selected dungeon
    var target_x = -current_dungeon * 700 # 700px per dungeon including spacing
    
    tween.tween_property(dungeon_carousel, "position:x", target_x, ANIMATION_DURATION)

func _animate_carousel_to_position(dungeon_index):
    var tween = create_tween()
    tween.set_ease(ANIMATION_EASE)
    tween.set_trans(Tween.TRANS_CUBIC)
    
    # Calculate the target position based on carousel width and selected dungeon
    var target_x = -dungeon_index * 700 # 700px per dungeon including spacing
    
    tween.tween_property(dungeon_carousel, "position:x", target_x, ANIMATION_DURATION)

# Add handler for notification closed
func _on_notification_closed():
    # Handle notification close if needed
    pass

# Handle navigation and play buttons
func _on_back_button_pressed():
    get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_play_button_pressed():
    if current_dungeon >= unlocked_dungeons:
        return # Don't allow playing locked dungeons
    
    # Set the current dungeon in GameSettings
    GameSettings.current_dungeon = current_dungeon + 1 # Convert to 1-based index
    GameSettings.current_stage = 1 # Start at stage 1
    
    # Save to Firebase if authenticated
    if Firebase.Auth.auth:
        var user_id = Firebase.Auth.auth.localid
        var collection = Firebase.Firestore.collection("dyslexia_users")
        
        # First get the existing document
        var get_task = collection.get(user_id)
        if get_task:
            var result = await get_task.task_finished
            
            if result.error:
                print("Error getting user data: ", result.error)
            else:
                # Update only the fields we want to change
                var current_data = result.doc_fields
                current_data["current_dungeon"] = current_dungeon + 1
                current_data["current_stage"] = 1
                
                # Use add() instead of update() to update the document
                var task = collection.add(user_id, current_data)
                if task:
                    await task.task_finished
    
    # Load the appropriate dungeon map based on selection
    var dungeon_map_scene = ""
    match current_dungeon:
        0: dungeon_map_scene = "res://Scenes/Dungeon1Map.tscn"
        1: dungeon_map_scene = "res://Scenes/Dungeon2Map.tscn"
        2: dungeon_map_scene = "res://Scenes/Dungeon3Map.tscn"
    
    # Change to the selected dungeon map scene
    get_tree().change_scene_to_file(dungeon_map_scene)
