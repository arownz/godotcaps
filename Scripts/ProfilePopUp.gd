extends Control

signal closed

# Simplify to just the essential data we need to track
var user_data = {}
var current_profile_picture = "default"
var fetch_retry_count = 0
var max_retries = 3

func _ready():
	# Check signal connections
	if !$ProfileContainer/CloseButton.is_connected("pressed", Callable(self, "_on_close_button_pressed")):
		$ProfileContainer/CloseButton.connect("pressed", Callable(self, "_on_close_button_pressed"))
	
	if !$ProfileContainer/LogoutButton.is_connected("pressed", Callable(self, "_on_logout_button_pressed")):
		$ProfileContainer/LogoutButton.connect("pressed", Callable(self, "_on_logout_button_pressed"))
	
	# Load user data from Firestore
	load_user_data()

func load_user_data():
	print("ProfilePopUp: Loading user data")
	
	# Check if user is authenticated
	if Firebase.Auth.auth == null:
		print("ProfilePopUp: No authenticated user")
		return
	
	var user_id = Firebase.Auth.auth.localid
	print("ProfilePopUp: Loading data for user ID: ", user_id)
	
	# Check if Firestore is initialized
	if Firebase.Firestore == null:
		print("ProfilePopUp: ERROR - Firestore is null")
		await _init_firebase()
		
		# If still null, use fallback
		if Firebase.Firestore == null:
			print("ProfilePopUp: Firestore still null after init")
			return
	
	# CRITICAL FIX: Check if Auth is busy before proceeding
	if is_auth_busy():
		print("ProfilePopUp: Firebase Auth is busy, waiting before proceeding...")
		# Wait for Firebase Auth to be available
		await get_tree().create_timer(2.0).timeout
		
		if is_auth_busy():
			print("ProfilePopUp: Firebase Auth still busy, skipping token refresh")
		else:
			# Only refresh if not busy
			print("ProfilePopUp: Refreshing auth token to ensure validity")
			# Use a timer to allow any pending HTTP requests to complete
			await get_tree().create_timer(0.5).timeout
			# Pass a delay parameter for auto-retry if still busy
			var refresh_result = await Firebase.Auth.manual_token_refresh(Firebase.Auth.auth, 1.0)
			print("ProfilePopUp: Token refresh result: ", refresh_result)
	else:
		# Not busy, can refresh safely
		print("ProfilePopUp: Refreshing auth token to ensure validity")
		var refresh_result = await Firebase.Auth.manual_token_refresh(Firebase.Auth.auth)
		print("ProfilePopUp: Token refresh result: ", refresh_result)
	
	# Wait a moment to ensure all initialization is complete
	await get_tree().create_timer(1.0).timeout
	
	# Try fetching from Firestore with retry logic
	await _fetch_user_document(user_id)

# Helper function to check if Auth is busy (to avoid direct property access if not available)
func is_auth_busy():
	# Method 1: Try has_method first (this is valid)
	if Firebase.Auth.has_method("is_busy"):
		return Firebase.Auth.is_busy
	
	# Method 2: Try direct property access using get() with a default
	# This handles the case without using has_property() which doesn't exist
	var busy_status = false
	
	# Using a simple check - if the property exists, this will work
	# If it doesn't, it will just return our default value (false)
	if "is_busy" in Firebase.Auth:
		busy_status = Firebase.Auth.is_busy
	
	return busy_status

# New function to handle fetching with retries
func _fetch_user_document(user_id):
	fetch_retry_count = 0
	var fetched = false
	
	while !fetched and fetch_retry_count < max_retries:
		# Enhanced Firestore fetch with retry
		print("ProfilePopUp: Creating Firestore collection reference (attempt %d)" % (fetch_retry_count + 1))
		
		if Firebase.Firestore == null:
			print("ProfilePopUp: Firestore is null on attempt %d" % (fetch_retry_count + 1))
			await _init_firebase()
			await get_tree().create_timer(1.0).timeout
			fetch_retry_count += 1
			continue
		
		var collection = null
		if Firebase.Firestore:
			collection = Firebase.Firestore.collection("dyslexia_users")
			if not collection:
				print("ProfilePopUp: Failed to create collection reference")
				await get_tree().create_timer(1.0).timeout
				fetch_retry_count += 1
				continue
		else:
			print("ProfilePopUp: Firestore is null, cannot create collection reference")
			await get_tree().create_timer(1.0).timeout
			fetch_retry_count += 1
			continue
		
		# Use the correct method: get_doc instead of get
		print("ProfilePopUp: Attempting to fetch document with ID: ", user_id)
		
		# Get the document
		var task = collection.get_doc(user_id)
		
		if task:
			print("ProfilePopUp: Task created, waiting for result")
			
			# Use a custom signal to communicate back from the lambda
			var temp_signal = Signal()
			var document_result = null
			
			# Connect to the task_finished signal
			task.task_finished.connect(func(doc_snapshot): 
				document_result = doc_snapshot
				# Signal that we have received the result
				temp_signal.emit()
			)
			
			# Wait for a reasonable time for the task to complete
			var timeout = 0
			var result_received = false
			
			while !result_received and timeout < 30:  # 3 second timeout
				# Try to receive the signal
				if temp_signal.connect(func(): result_received = true):
					break
				await get_tree().create_timer(0.1).timeout
				timeout += 1
			
			# If we have a result, process it
			if document_result != null:
				var user_doc = document_result
				print("ProfilePopUp: Document received")
				
				# Print full raw document for debugging
				print("ProfilePopUp: DOCUMENT RECEIVED:")
				_print_document_structure(user_doc)
				
				# Check for errors using proper error detection
				var has_error = false
				var error_data = null
				
				# According to the docs, we need to check keys() for fields
				var doc_keys = user_doc.keys()
				
				# Check if there is an error in the document
				if "error" in doc_keys:
					error_data = user_doc.get_value("error")
					if error_data:
						has_error = true
				
				if has_error:
					print("ProfilePopUp: Error in document: ", error_data)
					# Handle specific errors - check if error_data is a dictionary
					if typeof(error_data) == TYPE_DICTIONARY and error_data.has("status"):
						print("ProfilePopUp: Error status: ", error_data.status)
						
						if error_data.status == "NOT_FOUND":
							print("ProfilePopUp: Document not found - will try to create it")
							# Try to create the user document
							var create_success = await _create_user_document(user_id)
							if create_success:
								# Try fetching again
								continue
						elif error_data.status == "PERMISSION_DENIED":
							print("ProfilePopUp: Permission denied. Check that document ID matches user UID exactly")
							# This is likely due to Firestore rules - the document ID must match user ID
							print("ProfilePopUp: User ID: ", user_id)
							print("ProfilePopUp: Auth UID: ", Firebase.Auth.auth.localid if Firebase.Auth.auth else "None")
					
					fetch_retry_count += 1
					await get_tree().create_timer(1.0).timeout
				else:
					# Success path - document found with no errors
					user_data = {}
					
					# Use the correct field access pattern
					for field in doc_keys:
						if field != "error": # Skip the error field if it exists
							user_data[field] = user_doc.get_value(field)
					
					print("ProfilePopUp: Successfully loaded user data with keys: ", user_data.keys())
					update_ui()
					fetched = true
					break
			else:
				print("ProfilePopUp: Task timed out")
				fetch_retry_count += 1
				await get_tree().create_timer(1.0).timeout
		else:
			print("ProfilePopUp: Failed to create task")
			fetch_retry_count += 1
			await get_tree().create_timer(1.0).timeout
	
	# If we couldn't fetch after all retries, use default values
	if !fetched:
		print("ProfilePopUp: Could not fetch data after %d attempts, using defaults" % max_retries)
		# Create default document with minimal information
		user_data = {
			"username": "User " + user_id.substr(0, 5),
			"user_level": 1,
			"energy": 20,
			"max_energy": 20,
			"coin": 100,
			"power_scale": 115,
			"rank": "Bronze",
			"current_dungeon": 1,
			"current_stage": 1,
			"profile_picture": "default",
			"email": Firebase.Auth.auth.email if Firebase.Auth.auth and Firebase.Auth.auth.has("email") else "no-email@example.com"
		}
		update_ui()
		
		# Try to create the document since it might not exist
		_create_user_document(user_id)

# Function to create a user document if it doesn't exist
func _create_user_document(user_id):
	print("ProfilePopUp: Attempting to create user document with ID: ", user_id)
	
	if Firebase.Firestore == null:
		print("ProfilePopUp: Firestore is null, cannot create document")
		return false
	
	# Make sure we're using the correct user ID that matches Firebase Auth
	if user_id != Firebase.Auth.auth.localid:
		print("ProfilePopUp: Warning - user_id mismatch with auth.localid")
		user_id = Firebase.Auth.auth.localid
	
	var collection = Firebase.Firestore.collection("dyslexia_users")
	if collection == null:
		print("ProfilePopUp: Cannot get collection reference")
		return false
	
	# Create basic user document with fields matching the expected structure
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
	
	# Use the correct method to add a document
	var task = collection.add(user_id, user_doc)
	
	if task:
		var success = false
		var create_result = null
		
		# Connect to the signal
		task.task_finished.connect(func(result):
			create_result = result
		)
		
		# Wait for the result
		var timeout = 0
		while create_result == null and timeout < 30:  # 3 second timeout
			await get_tree().create_timer(0.1).timeout
			timeout += 1
		
		if create_result != null and !create_result.error:
			print("ProfilePopUp: Successfully created user document")
			return true
		else:
			print("ProfilePopUp: Error creating document: ", create_result.error if create_result else "Unknown error")
			return false
	else:
		print("ProfilePopUp: Failed to create task")
		return false

# Helper function to print the document structure for debugging
func _print_document_structure(doc):
	if doc == null:
		print("  Document is null")
		return
		
	print("  Document keys: ", doc.keys())
	
	# Use the correct way to access document fields - using get_value()
	for key in doc.keys():
		var value = doc.get_value(key)
		if typeof(value) == TYPE_DICTIONARY:
			print("    ", key, " (dict): ", value)
		else:
			print("    ", key, ": ", value)

# Initialize Firebase (useful when retrying connections)
func _init_firebase():
	print("ProfilePopUp: Reinitializing Firebase connection")
	
	# Check if Firebase is properly initialized
	if Firebase.Auth == null:
		print("ProfilePopUp: CRITICAL ERROR - Firebase.Auth is null, plugin might be incorrectly initialized")
		return false
		
	if Firebase.Firestore == null:
		print("ProfilePopUp: CRITICAL ERROR - Firebase.Firestore is null, plugin might be incorrectly initialized")
		return false
	
	# Debug the auth object
	if Firebase.Auth.auth:
		print("ProfilePopUp: Auth keys available: ", Firebase.Auth.auth.keys())
		
		# Ensure we have a valid token
		if Firebase.Auth.auth.has("idtoken"):
			print("ProfilePopUp: Token exists")
			return true
			
		# Only if we don't have a token, try to refresh auth
		print("ProfilePopUp: No token found, attempting to refresh")
		
		# Make sure auth isn't busy before refreshing
		if is_auth_busy():
			print("ProfilePopUp: Auth is busy, waiting...")
			await get_tree().create_timer(1.0).timeout
			
			if is_auth_busy():
				print("ProfilePopUp: Auth still busy, cannot refresh token")
				return false
				
		var token_result = await Firebase.Auth.manual_token_refresh(Firebase.Auth.auth)
		print("ProfilePopUp: Token refresh result: ", token_result)
		
		# Check if we now have a token
		if Firebase.Auth.auth.has("idtoken"):
			print("ProfilePopUp: Token obtained after refresh")
			return true
		else:
			print("ProfilePopUp: Failed to obtain token after refresh")
			return false
	else:
		print("ProfilePopUp: Auth is null or missing")
		return false

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
	if has_node("ProfileContainer/CharacterArea/Level2"):
		var level = user_data.get("user_level", 1)
		$ProfileContainer/CharacterArea/Level2.text = str(level)
	
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
	var dungeon_names = user_data.get("dungeon_names", {"1": "The Plains", "2": "The Mountain", "3": "The Demon"})
	
	# Display current dungeon and stage
	if has_node("ProfileContainer/StatsArea/DungeonValue"):
		var dungeon_name = dungeon_names.get(str(current_dungeon), "Unknown")
		var dungeon_text = str(current_dungeon) + ": " + dungeon_name
		$ProfileContainer/StatsArea/DungeonValue.text = dungeon_text
	
	if has_node("ProfileContainer/StatsArea/StageValue"):
		var stage_text = str(current_stage) + "/5"
		$ProfileContainer/StatsArea/StageValue.text = stage_text
	
	# Update profile picture
	if user_data.has("profile_picture"):
		current_profile_picture = user_data.profile_picture
		update_profile_picture()
	
	print("ProfilePopUp: UI update complete")

# Update profile picture function
func update_profile_picture():
	# Get reference to the profile picture texture rect
	if has_node("ProfileContainer/ProfilePictureButton"):
		var profile_button = $ProfileContainer/ProfilePictureButton
		# Try to load the profile picture
		var texture_path = "res://gui/ProfileScene/Profile/portrait 14.png" + current_profile_picture + ".png"
		# Default fallback
		if current_profile_picture == "default":
			texture_path = "res://gui/ProfileScene/Profile/portrait 14.png"
			
		var texture = load(texture_path)
		if texture:
			profile_button.texture_normal = texture
			print("ProfilePopUp: Profile picture updated successfully")

func _on_close_button_pressed():
	# Emit closed signal
	emit_signal("closed")
	queue_free()

func _on_profile_picture_button_pressed():
	print("ProfilePopUp: Profile picture button pressed")
	var profile_pics_popup = load("res://Scenes/ProfilePicturesPopup.tscn").instantiate()
	add_child(profile_pics_popup)
	profile_pics_popup.connect("picture_selected", Callable(self, "_on_profile_picture_selected"))

func _on_profile_picture_selected(picture_id):
	print("ProfilePopUp: Picture selected: ", picture_id)
	current_profile_picture = picture_id
	update_profile_picture()
	
	# Update in Firestore
	if Firebase.Auth.auth:
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		var task = collection.update(user_id, {"profile_picture": picture_id})
		
		if task:
			# Connect to the signal
			task.task_finished.connect(func(result):
				if result.error:
					print("Error updating profile picture: ", result.error)
				else:
					print("Profile picture updated successfully")
			)
		else:
			print("Failed to create task for updating profile picture")

func _on_logout_button_pressed():
	# Logout from Firebase
	Firebase.Auth.logout()
	
	# Close profile and navigate to the login scene
	var scene = load("res://Scenes/Authentication.tscn")
	get_tree().change_scene_to_packed(scene)
