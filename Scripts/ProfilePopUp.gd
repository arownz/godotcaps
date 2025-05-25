extends Node2D

signal closed

# Only keep essential data tracking
var user_data = {}
var current_profile_picture = "default"
var rank_textures = {
    "bronze": preload("res://gui/Update/icons/bronze medal.png"),
    "silver": preload("res://gui/Update/icons/silver medal.png"),
    "gold": preload("res://gui/Update/icons/gold medal.png")
}
var dungeon_names = ["The Plain", "The Forest", "The Mountain"]

func _ready():
    # Check signal connections
    if !$ProfileContainer/CloseButton.is_connected("pressed", Callable(self, "_on_close_button_pressed")):
        $ProfileContainer/CloseButton.connect("pressed", Callable(self, "_on_close_button_pressed"))
    
    if !$ProfileContainer/LogoutButton.is_connected("pressed", Callable(self, "_on_logout_button_pressed")):
        $ProfileContainer/LogoutButton.connect("pressed", Callable(self, "_on_logout_button_pressed"))
    
    # Connect edit and copy UID buttons
    $ProfileContainer/UserInfoArea/EditNameButton.pressed.connect(_on_edit_name_button_pressed)
    $ProfileContainer/UserInfoArea/CopyUIDButton.pressed.connect(_on_copy_uid_button_pressed)
    
    # Load user data from Firestore
    await load_user_data()

func load_user_data():
    print("ProfilePopUp: Loading user data")
    
    # Check if user is authenticated
    if Firebase.Auth.auth == null:
        print("ProfilePopUp: No authenticated user")
        return
    
    var user_id = Firebase.Auth.auth.localid
    print("ProfilePopUp: Loading data for user ID: ", user_id)
    
    # Simple Firestore check
    if Firebase.Firestore == null:
        print("ProfilePopUp: ERROR - Firestore is null")
        return
    
    # Create collection reference and fetch document directly
    var collection = Firebase.Firestore.collection("dyslexia_users")
    print("ProfilePopUp: Attempting to fetch document with ID: ", user_id)
    
    # Using the direct await approach that works correctly
    var document = await collection.get_doc(user_id)
    
    if document != null:
        print("ProfilePopUp: Document received")
        
        # Check for errors in the document
        var has_error = false
        var error_data = null
        
        if document.has_method("keys"):
            var doc_keys = document.keys()
            
            if "error" in doc_keys:
                error_data = document.get_value("error")
                if error_data:
                    has_error = true
                    print("ProfilePopUp: Error in document: ", error_data)
                    
                    if typeof(error_data) == TYPE_DICTIONARY and error_data.has("status"):
                        if error_data.status == "NOT_FOUND":
                            # Create a new user document if it doesn't exist
                            var create_success = await _create_user_document(user_id)
                            if create_success:
                                await load_user_data() # Try loading again after creation
                                return
            
            if !has_error:
                # Process the document data using the new nested structure
                user_data = {}
                
                # Extract profile data
                if document.has_method("get_value"):
                    var profile = document.get_value("profile")
                    if profile != null and typeof(profile) == TYPE_DICTIONARY:
                        user_data["username"] = profile.get("username", "Unknown User")
                        user_data["email"] = profile.get("email", "No email available")
                        user_data["profile_picture"] = profile.get("profile_picture", "default")
                        user_data["rank"] = profile.get("rank", "bronze")
                        user_data["created_at"] = profile.get("created_at", "Unknown")
                    
                    # Extract player stats
                    var stats = document.get_value("stats")
                    if stats != null and typeof(stats) == TYPE_DICTIONARY:
                        var player_stats = stats.get("player", {})
                        user_data["level"] = player_stats.get("level", 1)
                        user_data["energy"] = player_stats.get("energy", 20)
                        user_data["max_energy"] = 20 # This is fixed at 20
                        user_data["health"] = player_stats.get("health", 100)
                        user_data["attack"] = player_stats.get("damage", 10)
                        user_data["durability"] = player_stats.get("durability", 5)
                    
                    # Extract dungeon progress
                    var dungeons = document.get_value("dungeons")
                    if dungeons != null and typeof(dungeons) == TYPE_DICTIONARY:
                        var completed = dungeons.get("completed", {})
                        var progress = dungeons.get("progress", {})
                        
                        user_data["current_dungeon"] = progress.get("current_dungeon", 1)
                        user_data["current_stage"] = progress.get("current_stage", 1)
                        
                        # Calculate highest unlocked dungeon
                        var unlocked_dungeons = 1 # Dungeon 1 always unlocked
                        if completed.has("1") and completed["1"].get("completed", false):
                            unlocked_dungeons = 2
                        if unlocked_dungeons >= 2 and completed.has("2") and completed["2"].get("completed", false):
                            unlocked_dungeons = 3
                        
                        # Update rank based on unlocked dungeons
                        if unlocked_dungeons == 3:
                            user_data["rank"] = "gold"
                        elif unlocked_dungeons == 2:
                            user_data["rank"] = "silver"
                        else:
                            user_data["rank"] = "bronze"
                
                print("ProfilePopUp: Successfully loaded user data: ", user_data)
                
                # Get a local reference for profile picture
                if user_data.has("profile_picture"):
                    current_profile_picture = user_data["profile_picture"]
                
                update_ui()
    else:
        print("ProfilePopUp: Failed to fetch document")

# Simplified user document creation function with new nested structure
func _create_user_document(user_id):
    print("ProfilePopUp: Creating user document")
    
    var collection = Firebase.Firestore.collection("dyslexia_users")
    var current_time = Time.get_datetime_string_from_system(false, true)
    var display_name = Firebase.Auth.auth.get("displayname", "User")
    var email = Firebase.Auth.auth.get("email", "")
    
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
                "current_stage": 1
            }
        }
    }
    
    # Add document and await result
    var task = collection.add(user_id, user_doc)
    if task:
        var create_result = await task.task_finished
        return create_result != null and !create_result.error
    
    return false

# UI updating functions for the new data structure
func update_ui():
    print("ProfilePopUp: Updating UI with user data")
    
    # Update username
    if has_node("ProfileContainer/UserInfoArea/NameValue"):
        var username = user_data.get("username", "Unknown User")
        $ProfileContainer/UserInfoArea/NameValue.text = username
    
    # Update email
    if has_node("ProfileContainer/UserInfoArea/EmailValue"):
        var email = user_data.get("email", "No email available")
        $ProfileContainer/UserInfoArea/EmailValue.text = email
    
    # Update UID
    if has_node("ProfileContainer/UserInfoArea/UIDValue") and Firebase.Auth.auth:
        $ProfileContainer/UserInfoArea/UIDValue.text = Firebase.Auth.auth.localid
    
    # Update level
    if has_node("ProfileContainer/StatsArea/Level2"):
        var level = user_data.get("level", 1)
        $ProfileContainer/StatsArea/Level2.text = str(level)
    
    # Update player stats
    if has_node("ProfileContainer/StatsArea/AttackValue"):
        var attack = user_data.get("attack", 10)
        $ProfileContainer/StatsArea/AttackValue.text = str(attack)
    
    if has_node("ProfileContainer/StatsArea/DurabilityValue"):
        var durability = user_data.get("durability", 5)
        $ProfileContainer/StatsArea/DurabilityValue.text = str(durability)
    
    if has_node("ProfileContainer/StatsArea/LevelValue"):
        var level = user_data.get("level", 1)
        $ProfileContainer/StatsArea/LevelValue.text = str(level)
    
    # Update energy - use the correct path from the new data structure
    if has_node("ProfileContainer/StatsArea/EnergyValue"):
        var energy = user_data.get("energy", 0)
        var max_energy = 20 # Energy cap is 20
        $ProfileContainer/StatsArea/EnergyValue.text = str(energy) + "/" + str(max_energy)
    
    # Update rank with the right medal icon
    if has_node("ProfileContainer/UserInfoArea/RankValue"):
        var rank = user_data.get("rank", "bronze")
        $ProfileContainer/UserInfoArea/RankValue.text = rank.capitalize()
        
        if has_node("ProfileContainer/UserInfoArea/RankIcon"):
            var rank_icon = $ProfileContainer/UserInfoArea/RankIcon
            if rank_textures.has(rank):
                rank_icon.texture = rank_textures[rank]
    
    # Update dungeon progress
    var current_dungeon = user_data.get("current_dungeon", 1)
    var current_stage = user_data.get("current_stage", 1)
    
    # Display current dungeon and stage
    if has_node("ProfileContainer/DungeonArea/DungeonValue"):
        var dungeon_name = dungeon_names[current_dungeon - 1] if current_dungeon >= 1 and current_dungeon <= 3 else "Unknown"
        var dungeon_text = str(current_dungeon) + ": " + dungeon_name
        $ProfileContainer/DungeonArea/DungeonValue.text = dungeon_text
    
    if has_node("ProfileContainer/DungeonArea/StageValue"):
        var stage_text = str(current_stage) + "/5"
        $ProfileContainer/DungeonArea/StageValue.text = stage_text
    
    # Update profile picture
    update_profile_picture()
    
    print("ProfilePopUp: UI update complete")

# Update the profile picture using the current_profile_picture value
func update_profile_picture():
    print("ProfilePopUp: Updating profile picture to: ", current_profile_picture)
    
    # Get reference to the profile picture texture rect
    if has_node("ProfileContainer/PictureContainer/ProfilePictureButton"):
        var profile_button = $ProfileContainer/PictureContainer/ProfilePictureButton
        # Try to load the profile picture
        var texture_path
        
        # Set texture path based on profile ID
        if current_profile_picture == "default":
            current_profile_picture = "13" # Map default to portrait 13
        
        texture_path = "res://gui/ProfileScene/Profile/portrait" + current_profile_picture + ".png"
            
        var texture = load(texture_path)
        if texture:
            profile_button.texture_normal = texture
            print("ProfilePopUp: Profile picture updated successfully")
        else:
            print("ProfilePopUp: Failed to load texture from path: " + texture_path)

# Button handlers - keeping just what we need
func _on_close_button_pressed():
    emit_signal("closed")
    queue_free()

func _on_logout_button_pressed():
    Firebase.Auth.logout()
    var scene = load("res://Scenes/Authentication.tscn")
    get_tree().change_scene_to_packed(scene)

func _on_profile_picture_button_pressed():
    print("ProfilePopUp: Profile picture button pressed")
    var profile_pics_popup = load("res://Scenes/ProfilePicturesPopup.tscn").instantiate()
    
    # Add as a child of the root viewport to ensure proper positioning
    get_tree().root.add_child(profile_pics_popup)
    
    # Center the popup
    profile_pics_popup.position = get_viewport_rect().size / 2 - profile_pics_popup.size / 2
    
    # Connect signals
    profile_pics_popup.connect("picture_selected", Callable(self, "_on_profile_picture_selected"))
    profile_pics_popup.connect("cancelled", Callable(self, "_on_profile_pics_popup_closed"))

func _on_profile_pics_popup_closed():
    print("Profile pictures popup closed")

func _on_profile_picture_selected(picture_id):
    print("ProfilePopUp: Picture selected: ", picture_id)
    current_profile_picture = picture_id
    update_profile_picture()
    
    # Update in Firestore - FIXED to use proper document update method like previous working code
    if Firebase.Auth.auth:
        var user_id = Firebase.Auth.auth.localid
        var collection = Firebase.Firestore.collection("dyslexia_users")
        
        print("DEBUG: Updating Firestore document for user: " + user_id)
        print("DEBUG: Setting profile_picture to: " + picture_id)
        
        # Get the document first using the working method
        var document = await collection.get_doc(user_id)
        
        if document and !("error" in document.keys() and document.get_value("error")):
            print("ProfilePopUp: Document retrieved successfully")
            
            # Check if we have nested profile structure
            var profile = document.get_value("profile")
            if profile != null and typeof(profile) == TYPE_DICTIONARY:
                # Update the nested profile structure
                profile.profile_picture = picture_id
                
                # Use document.add_or_update_field for nested update
                document.add_or_update_field("profile", profile)
                
                # Update the document using the update method (not add)
                var updated_document = await collection.update(document)
                if updated_document:
                    print("Profile picture updated successfully in Firestore (nested)")
                    # Update local user_data to maintain consistency
                    user_data["profile_picture"] = picture_id
                else:
                    print("Failed to update profile picture in Firestore")
            else:
                # Fallback to simple field update for old structure
                document.add_or_update_field("profile_picture", picture_id)
                
                # Update the document using the update method
                var updated_document = await collection.update(document)
                if updated_document:
                    print("Profile picture updated successfully in Firestore (flat)")
                    user_data["profile_picture"] = picture_id
                else:
                    print("Failed to update profile picture in Firestore")
        else:
            print("Failed to get document for updating (document error or not found)")

# FIXED: Update username using proper document update method
func _update_username(new_username):
    if new_username.strip_edges().is_empty():
        print("Username cannot be empty")
        return
        
    if Firebase.Auth.auth:
        var user_id = Firebase.Auth.auth.localid
        var collection = Firebase.Firestore.collection("dyslexia_users")
        
        print("Updating username for user: " + user_id)
        
        # Get the document first using the working method
        var document = await collection.get_doc(user_id)
        
        if document and !("error" in document.keys() and document.get_value("error")):
            print("ProfilePopUp: Document retrieved successfully for username update")
            
            # Check if we have nested profile structure
            var profile = document.get_value("profile")
            if profile != null and typeof(profile) == TYPE_DICTIONARY:
                # Update the nested profile structure
                profile.username = new_username
                
                # Use document.add_or_update_field for nested update
                document.add_or_update_field("profile", profile)
                
                # Update the document using the update method (not add)
                var updated_document = await collection.update(document)
                if updated_document:
                    print("Username updated successfully (nested)")
                    # Update local user_data
                    user_data["username"] = new_username
                    # Update UI
                    $ProfileContainer/UserInfoArea/NameValue.text = new_username
                else:
                    print("Failed to update username in Firestore")
            else:
                # Fallback to simple field update for old structure
                document.add_or_update_field("username", new_username)
                
                # Update the document using the update method
                var updated_document = await collection.update(document)
                if updated_document:
                    print("Username updated successfully (flat)")
                    user_data["username"] = new_username
                    $ProfileContainer/UserInfoArea/NameValue.text = new_username
                else:
                    print("Failed to update username in Firestore")
        else:
            print("Failed to get document for updating username")

func _on_edit_name_button_pressed():
    print("Edit name button pressed")
    
    # Show the edit username panel
    var edit_panel = $EditUsernamePanel
    var username_input = $EditUsernamePanel/EditContainer/ContentContainer/VBoxContainer/InputContainer/UsernameLineEdit
    var error_label = $EditUsernamePanel/EditContainer/ContentContainer/VBoxContainer/ErrorLabel
    
    # Set current username as default text
    username_input.text = user_data.get("username", "")
    
    # Hide error label
    error_label.visible = false
    
    # Show the panel
    edit_panel.visible = true
    
    # Focus and select all text in the input field
    username_input.grab_focus()
    username_input.select_all()

func _on_edit_username_cancel_pressed():
    print("Edit username cancelled")
    
    # Hide the edit panel
    $EditUsernamePanel.visible = false

func _on_edit_username_confirm_pressed():
    print("Edit username confirm pressed")
    
    var username_input = $EditUsernamePanel/EditContainer/ContentContainer/VBoxContainer/InputContainer/UsernameLineEdit
    var error_label = $EditUsernamePanel/EditContainer/ContentContainer/VBoxContainer/ErrorLabel
    var new_username = username_input.text.strip_edges()
    
    # Validate username
    if new_username.is_empty():
        error_label.text = "Username cannot be empty!"
        error_label.visible = true
        return
    
    # Hide error label
    error_label.visible = false
    
    # Hide the panel
    $EditUsernamePanel.visible = false
    
    # Update the username
    await _update_username(new_username)

func _on_username_text_submitted(new_text):
    # Handle Enter key press - same as confirm button
    var new_username = new_text.strip_edges()
    if !new_username.is_empty():
        var error_label = $EditUsernamePanel/EditContainer/ContentContainer/VBoxContainer/ErrorLabel
        error_label.visible = false
        $EditUsernamePanel.visible = false
        await _update_username(new_username)

func _on_copy_uid_button_pressed():
    if Firebase.Auth.auth and Firebase.Auth.auth.has("localid"):
        var uid = Firebase.Auth.auth.localid
        
        # Copy to clipboard
        DisplayServer.clipboard_set(uid)
        
        # Show feedback
        var popup = Label.new()
        popup.text = "UID Copied!"
        popup.add_theme_font_override("font", load("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
        popup.add_theme_font_size_override("font_size", 16)
        popup.add_theme_color_override("font_color", Color(0, 0.8, 0.2)) # Green color
        popup.position = $ProfileContainer/UserInfoArea/CopyUIDButton.position + Vector2(0, 10)
        popup.z_index = 100
        
        $ProfileContainer/UserInfoArea.add_child(popup)
        
        # Remove popup after a short delay
        var tween = create_tween()
        tween.tween_property(popup, "modulate", Color(1, 1, 1, 0), 1.0)
        tween.tween_callback(popup.queue_free)