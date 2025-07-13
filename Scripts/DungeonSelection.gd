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
        preload("res://gui/Update/icons/level selection.png"),
        preload("res://gui/Update/icons/highest level.png")
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
    
    # Setup hover functionality for navigation buttons
    _setup_hover_functionality()
    
    # Load user data and update UI
    _load_user_data()
    
    # Set initial carousel position
    dungeon_carousel.position.x = 0
    update_dungeon_display()

# Setup hover functionality for navigation buttons
func _setup_hover_functionality():
    # Connect hover events for back button
    $BackButton.mouse_entered.connect(_on_back_button_hover_entered)
    $BackButton.mouse_exited.connect(_on_back_button_hover_exited)
    
    # Connect hover events for next button
    $NextButton.mouse_entered.connect(_on_next_button_hover_entered)
    $NextButton.mouse_exited.connect(_on_next_button_hover_exited)
    
    # Connect hover events for previous button
    $PreviousButton.mouse_entered.connect(_on_previous_button_hover_entered)
    $PreviousButton.mouse_exited.connect(_on_previous_button_hover_exited)

# Load user data from Firebase
func _load_user_data():
    if Firebase.Auth.auth:
        var user_id = Firebase.Auth.auth.localid
        var collection = Firebase.Firestore.collection("dyslexia_users")
        
        var document = await collection.get_doc(user_id)
        if document and !("error" in document.keys() and document.get_value("error")):
            # Extract dungeon progress data using the new structure
            var dungeons = document.get_value("dungeons")
            if dungeons != null and typeof(dungeons) == TYPE_DICTIONARY:
                var completed = dungeons.get("completed", {})
                
                # Count unlocked dungeons based on completion
                unlocked_dungeons = 1 # Dungeon 1 always unlocked
                
                # Check if dungeon 1 is completed (all 5 stages)
                if completed.has("1"):
                    var dungeon1_data = completed["1"]
                    if dungeon1_data.get("completed", false) or dungeon1_data.get("stages_completed", 0) >= 5:
                        unlocked_dungeons = 2
                        
                        # Check if dungeon 2 is completed
                        if completed.has("2"):
                            var dungeon2_data = completed["2"]
                            if dungeon2_data.get("completed", false) or dungeon2_data.get("stages_completed", 0) >= 5:
                                unlocked_dungeons = 3
                
                # Get current dungeon from progress
                var progress = dungeons.get("progress", {})
                if progress.has("current_dungeon"):
                    current_dungeon = int(progress.current_dungeon) - 1 # Convert to 0-based index
                    # Ensure current_dungeon doesn't exceed unlocked dungeons
                    current_dungeon = min(current_dungeon, unlocked_dungeons - 1)
                
                print("Dungeons unlocked: ", unlocked_dungeons)
                print("Current dungeon: ", current_dungeon + 1)
                
                # Update UI with user data
                update_dungeon_display()
        else:
            print("Error loading user data or document not found")
            # Demo mode - just unlock dungeon 1
            unlocked_dungeons = 1
            current_dungeon = 0
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
func _animate_carousel(_direction):
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

# Button hover handlers
func _on_back_button_hover_entered():
    var back_label = $BackButton/BackLabel
    if back_label:
        back_label.visible = true

func _on_back_button_hover_exited():
    var back_label = $BackButton/BackLabel
    if back_label:
        back_label.visible = false

func _on_next_button_hover_entered():
    var next_label = $NextButton/NextLabel
    if next_label:
        next_label.visible = true

func _on_next_button_hover_exited():
    var next_label = $NextButton/NextLabel
    if next_label:
        next_label.visible = false

func _on_previous_button_hover_entered():
    var previous_label = $PreviousButton/PreviousLabel
    if previous_label:
        previous_label.visible = true

func _on_previous_button_hover_exited():
    var previous_label = $PreviousButton/PreviousLabel
    if previous_label:
        previous_label.visible = false

# Handle navigation and play buttons
func _on_back_button_pressed():
    get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_play_button_pressed():
    if current_dungeon >= unlocked_dungeons:
        return # Don't allow playing locked dungeons
    
    # Save to Firebase if authenticated
    if Firebase.Auth.auth:
        var user_id = Firebase.Auth.auth.localid
        var collection = Firebase.Firestore.collection("dyslexia_users")
        
        # First get the existing document
        var get_task = await collection.get_doc(user_id)
        if get_task:
            var document = await get_task
            
            if document and document.has_method("doc_fields"):
                # Update current dungeon and stage in Firebase
                var current_data = document.doc_fields
                
                # Update dungeons progress
                if not current_data.has("dungeons"):
                    current_data["dungeons"] = {}
                if not current_data.dungeons.has("progress"):
                    current_data.dungeons["progress"] = {}
                
                current_data.dungeons.progress.current_dungeon = current_dungeon + 1
                current_data.dungeons.progress.current_stage = 1  # Start at stage 1
                
                # Save back to Firebase
                collection.add(user_id, current_data)
    
    # Load the appropriate dungeon map based on selection
    var dungeon_map_scene = ""
    match current_dungeon:
        0: dungeon_map_scene = "res://Scenes/Dungeon1Map.tscn"
        1: dungeon_map_scene = "res://Scenes/Dungeon2Map.tscn"
        2: dungeon_map_scene = "res://Scenes/Dungeon3Map.tscn"
    
    # Change to the selected dungeon map scene
    get_tree().change_scene_to_file(dungeon_map_scene)
