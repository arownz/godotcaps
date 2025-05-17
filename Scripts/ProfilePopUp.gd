extends Node2D

signal closed

# Only keep essential data tracking
var user_data = {}
var current_profile_picture = "default"

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
	
	# SIMPLIFIED: Create collection reference and fetch document directly
	var collection = Firebase.Firestore.collection("dyslexia_users")
	print("ProfilePopUp: Attempting to fetch document with ID: ", user_id)
	
	# Using the direct await approach that works correctly
	var document_result = await collection.get_doc(user_id)
	
	if document_result != null:
		print("ProfilePopUp: Document received")
		
		# Check for errors in the document
		var has_error = false
		var error_data = null
		var doc_keys = document_result.keys()
		
		if "error" in doc_keys:
			error_data = document_result.get_value("error")
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
			# Process the document data
			user_data = {}
			for field in doc_keys:
				if field != "error":
					user_data[field] = document_result.get_value(field)
			
			print("ProfilePopUp: Successfully loaded user data with keys: ", user_data.keys())
			update_ui()
	else:
		print("ProfilePopUp: Failed to fetch document")

# Simplified user document creation function
func _create_user_document(user_id):
	print("ProfilePopUp: Creating user document")
	
	var collection = Firebase.Firestore.collection("dyslexia_users")
	var user_doc = {
		"username": Firebase.Auth.auth.get("displayname", "User"),
		"email": Firebase.Auth.auth.get("email", ""),
		"user_level": 1,
		"energy": 20,
		"max_energy": 20,
		"coin": 100,
		"power_scale": 115,
		"rank": "bronze",
		"current_dungeon": 1,
		"current_stage": 1,
		"profile_picture": "default",
		"dungeons_completed": {
			"1": {"completed": false, "stages_completed": 0},
			"2": {"completed": false, "stages_completed": 0},
			"3": {"completed": false, "stages_completed": 0}
		}
	}
	
	# Add document and await result
	var task = await collection.add(user_id, user_doc)
	if task:
		var create_result = await task.task_finished
		return create_result != null and !create_result.error
	
	return false

# UI updating functions - keep as they were before
func update_ui():
	print("ProfilePopUp: Updating UI with user data")
	
	# Update only the essential UI elements - username, email, UID, rank, player stats, level, dungeon
	
	# Set username
	if has_node("ProfileContainer/UserInfoArea/NameValue"):
		var username = user_data.get("username", "Unknown User")
		$ProfileContainer/UserInfoArea/NameValue.text = username
		print("ProfilePopUp: Setting username to: ", username)
	
	# Set email
	if has_node("ProfileContainer/UserInfoArea/EmailValue"):
		var email = user_data.get("email", "No email available")
		$ProfileContainer/UserInfoArea/EmailValue.text = email
	
	# Set UID
	if has_node("ProfileContainer/UserInfoArea/UIDValue"):
		var uid = Firebase.Auth.auth.localid if Firebase.Auth.auth else "Unknown"
		$ProfileContainer/UserInfoArea/UIDValue.text = uid
	
	# Update level
	if has_node("ProfileContainer/Level2"):
		var level = user_data.get("user_level", 1)
		$ProfileContainer/Level2.text = str(level)
	
	# Update player stats
	if has_node("ProfileContainer/StatsArea/EnergyValue"):
		var energy = user_data.get("energy", 0)
		var max_energy = user_data.get("max_energy", 0)
		$ProfileContainer/StatsArea/EnergyValue.text = str(energy) + "/" + str(max_energy)
	
	if has_node("ProfileContainer/StatsArea/CoinsValue"):
		var coins = user_data.get("coin", 0)
		$ProfileContainer/StatsArea/CoinsValue.text = str(coins)
	
	if has_node("ProfileContainer/StatsArea/PowerValue"):
		var power = user_data.get("power_scale", 0)
		$ProfileContainer/StatsArea/PowerValue.text = str(power)
	
	# Update rank
	if has_node("ProfileContainer/UserInfoArea/RankValue"):
		var rank = user_data.get("rank", "")
		# Ensure proper capitalization for display
		if rank.length() > 0:
			rank = rank.substr(0, 1).to_upper() + rank.substr(1).to_lower()
		$ProfileContainer/UserInfoArea/RankValue.text = rank
	
	# Update dungeon progress
	var current_dungeon = user_data.get("current_dungeon", 1)
	var current_stage = user_data.get("current_stage", 1)
	var dungeon_names = user_data.get("dungeon_names", {"1": "The Plains", "2": "The Forest", "3": "The Mountain"})
	
	# Display current dungeon and stage
	if has_node("ProfileContainer/DungeonArea/DungeonValue"):
		var dungeon_name = dungeon_names.get(str(current_dungeon), "Unknown")
		var dungeon_text = str(current_dungeon) + ": " + dungeon_name
		$ProfileContainer/DungeonArea/DungeonValue.text = dungeon_text
	
	if has_node("ProfileContainer/DungeonArea/StageValue"):
		var stage_text = str(current_stage) + "/5"
		$ProfileContainer/DungeonArea/StageValue.text = stage_text
	
	# Update profile picture
	if user_data.has("profile_picture"):
		current_profile_picture = user_data.profile_picture
		update_profile_picture()
	
	print("ProfilePopUp: UI update complete")

func update_profile_picture():
	# Get reference to the profile picture texture rect
	if has_node("ProfileContainer/PictureContainer/ProfilePictureButton"):
		var profile_button = $ProfileContainer/PictureContainer/ProfilePictureButton
		# Try to load the profile picture
		var texture_path
		
		# Set texture path based on profile ID
		if current_profile_picture == "default":
			current_profile_picture = "13"  # Map default to portrait 13
		
		texture_path = "res://gui/ProfileScene/Profile/portrait" + current_profile_picture + ".png"
			
		var texture = load(texture_path)
		if texture:
			profile_button.texture_normal = texture
			print("ProfilePopUp: Profile picture updated successfully")
		else:
			print("ProfilePopUp: Failed to load texture from path: " + texture_path)

# Button handlers
func _on_close_button_pressed():
	emit_signal("closed")
	queue_free()


func _on_profile_picture_button_pressed():
	print("ProfilePopUp: Profile picture button pressed")
	var profile_pics_popup = load("res://Scenes/ProfilePicturesPopup.tscn").instantiate()
	
	# Add as a child of the root viewport to ensure proper positioning
	get_tree().root.add_child(profile_pics_popup)
	
	# Center the popup
	profile_pics_popup.position = get_viewport_rect().size / 2 - profile_pics_popup.size / 2
	
	# Connect signal before _ready finishes to ensure we don't miss events
	profile_pics_popup.connect("picture_selected", Callable(self, "_on_profile_picture_selected"))
	profile_pics_popup.connect("cancelled", Callable(self, "_on_profile_pics_popup_closed"))
	
	# We can still use await inside a regular function
	await get_tree().process_frame

# Add this function to handle popup closing
func _on_profile_pics_popup_closed():
	# This function will be called when the popup is closed
	print("Profile pictures popup closed")

func _on_profile_picture_selected(picture_id):
	print("ProfilePopUp: Picture selected: ", picture_id)
	current_profile_picture = picture_id
	update_profile_picture()
	
	# Update in Firestore - using proper await pattern
	if Firebase.Auth.auth:
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		print("DEBUG: Updating Firestore document for user: " + user_id)
		print("DEBUG: Setting profile_picture to: " + picture_id)
		
		# FIXED: Get the document first, then update fields, then submit the update
		var document_task = await collection.get_doc(user_id)
		
		if document_task and not ("error" in document_task.keys() and document_task.get_value("error")):
			# Add/update the profile_picture field
			document_task.add_or_update_field("profile_picture", picture_id)
			
			# Update the document in Firestore - FIXED to handle both return types
			print("DEBUG: Calling update on document")
			var updated_doc = await collection.update(document_task)
			
			print("DEBUG: Update returned: ", updated_doc)
			
			if updated_doc:
				print("Profile picture updated successfully in Firestore")
				# Update local user_data to maintain consistency
				if user_data.has("profile_picture"):
					user_data["profile_picture"] = picture_id
					
				# Add explicit debug to verify document after update
				debug_firestore_document()
			else:
				print("Failed to update profile picture - no document returned")
		else:
			print("Failed to get document for updating")

# Add debug function to check Firestore document
func debug_firestore_document():
	if Firebase.Auth.auth:
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		print("Verifying document update for user: " + user_id)
		var document = await collection.get_doc(user_id)
		
		if document:
			# Updated to correctly check document fields
			if document.has_method("keys") and "profile_picture" in document.keys():
				print("Current profile_picture value: " + str(document.get_value("profile_picture")))
			else:
				print("Document doesn't have profile_picture field or wrong format")
		else:
			print("Failed to fetch document for verification")

func _on_logout_button_pressed():
	Firebase.Auth.logout()
	var scene = load("res://Scenes/Authentication.tscn")
	get_tree().change_scene_to_packed(scene)

# Handle edit name button press
func _on_edit_name_button_pressed():
	# Create a simple dialog for name editing
	var dialog = AcceptDialog.new()
	dialog.title = "Edit Username"
	
	# Add a LineEdit for the name input
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	var label = Label.new()
	label.text = "Enter new username:"
	vbox.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.text = user_data.get("username", "")
	line_edit.placeholder_text = "Enter username"
	# Set up the line edit with appropriate size and styling
	line_edit.custom_minimum_size.y = 40
	vbox.add_child(line_edit)
	
	dialog.add_child(vbox)
	
	# Connect dialog signals
	dialog.confirmed.connect(func(): _update_username(line_edit.text))
	
	# Add dialog to scene and show it
	add_child(dialog)
	dialog.popup_centered(Vector2(400, 150))

# Update username in Firestore
func _update_username(new_username):
	if new_username.strip_edges().is_empty():
		print("Username cannot be empty")
		return
		
	if Firebase.Auth.auth:
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		print("Updating username for user: " + user_id)
		
		# Get the document first
		var document_task = await collection.get_doc(user_id)
		
		if document_task and not ("error" in document_task.keys() and document_task.get_value("error")):
			# Update the username field
			document_task.add_or_update_field("username", new_username)
			
			# Update the document in Firestore
			var updated_doc = await collection.update(document_task)
			
			if updated_doc:
				print("Username updated successfully")
				# Update local user_data
				user_data["username"] = new_username
				# Update UI
				$ProfileContainer/UserInfoArea/NameValue.text = new_username
			else:
				print("Failed to update username - no document returned")
		else:
			print("Failed to get document for updating username")

# Handle copy UID button press
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
		popup.position = $ProfileContainer/UserInfoArea/CopyUIDButton.position + Vector2(0, 30)
		popup.z_index = 100
		
		$ProfileContainer/UserInfoArea.add_child(popup)
		
		# Remove popup after a short delay
		var tween = create_tween()
		tween.tween_property(popup, "modulate", Color(1, 1, 1, 0), 1.0)
		tween.tween_callback(popup.queue_free)
