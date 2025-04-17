extends Control

signal closed

var user_data = {}
var current_profile_picture = "default"

func _ready():
	# Do not connect signals that are already connected in the scene
	# Check if signals are already connected before connecting them
	if !$ProfileContainer/CloseButton.is_connected("pressed", Callable(self, "_on_close_button_pressed")):
		$ProfileContainer/CloseButton.connect("pressed", Callable(self, "_on_close_button_pressed"))
	
	if !$ProfileContainer/LogoutButton.is_connected("pressed", Callable(self, "_on_logout_button_pressed")):
		$ProfileContainer/LogoutButton.connect("pressed", Callable(self, "_on_logout_button_pressed"))
	
	# Load user data from Firestore
	load_user_data()

func load_user_data():
	print("ProfilePopUp: Loading user data")
	# Get authenticated user ID
	if Firebase.Auth.auth:
		var user_id = Firebase.Auth.auth.localid
		print("ProfilePopUp: Loading data for user ", user_id)
		print("ProfilePopUp: Full auth object: ", Firebase.Auth.auth)
		
		# Add debug info about Firestore readiness
		if Firebase.Firestore == null:
			print("ProfilePopUp: ERROR - Firestore is null")
			_recover_with_auth_data()
			return
			
		# Fetch user data from Firestore - explicitly use dyslexia_users collection
		var collection = Firebase.Firestore.collection("dyslexia_users")
		print("ProfilePopUp: Fetching from collection: dyslexia_users")
		
		# FIXED: Remove problematic connection test that causes HTTP request collision
		# Just try to get the user document directly
		
		# Now try to get the user document
		var task = collection.get(user_id)
		
		if task:
			print("ProfilePopUp: Fetch task created successfully")
			var user_doc = await task.task_finished
			
			if user_doc:
				print("ProfilePopUp: Document received: ", user_doc)
				if !user_doc.error:
					print("ProfilePopUp: User data loaded successfully")
					if user_doc.doc_fields:
						print("ProfilePopUp: Document fields: ", user_doc.doc_fields.keys())
						print("ProfilePopUp: Username found: ", user_doc.doc_fields.has("username"))
						print("ProfilePopUp: Email found: ", user_doc.doc_fields.has("email"))
						print("ProfilePopUp: Power found: ", user_doc.doc_fields.has("power_scale"))
						print("ProfilePopUp: Coin found: ", user_doc.doc_fields.has("coin"))
						user_data = user_doc.doc_fields
					else:
						print("ProfilePopUp: ERROR - doc_fields is null or not a dictionary")
						_recover_with_auth_data()
						return
					update_ui()
				else:
					print("ProfilePopUp: Error loading document - ", user_doc.error)
					# More detailed error reporting
					if typeof(user_doc.error) == TYPE_DICTIONARY:
						for key in user_doc.error:
							print("ProfilePopUp: Error detail - ", key, ": ", user_doc.error[key])
					
					# Try to handle specific error types
					if typeof(user_doc.error) == TYPE_DICTIONARY and user_doc.error.has("status"):
						print("ProfilePopUp: HTTP Status: ", user_doc.error.status)
						if user_doc.error.status == "PERMISSION_DENIED":
							print("ProfilePopUp: Firestore permission denied. Check Firestore rules.")
						elif user_doc.error.status == "NOT_FOUND":
							print("ProfilePopUp: Document not found. Creating a new one.")
							# Try to create a new document for this user
							_create_default_user_document(user_id)
							return
					
					# Recovery with default values from auth
					_recover_with_auth_data()
			else:
				print("ProfilePopUp: Document is null")
				_recover_with_auth_data()
		else:
			print("ProfilePopUp: Failed to create Firestore task")
			
			# Try to initialize Firebase again
			print("ProfilePopUp: Attempting to reinitialize Firebase...")
			_init_firebase()
			await get_tree().create_timer(1.0).timeout
			
			# Try one more time after reinitialization
			print("ProfilePopUp: Retrying Firestore fetch after reinitialization...")
			var retry_collection = Firebase.Firestore.collection("dyslexia_users")
			var retry_task = retry_collection.get(user_id)
			
			if retry_task:
				print("ProfilePopUp: Retry fetch task created successfully")
				var retry_user_doc = await retry_task.task_finished
				
				if retry_user_doc and !retry_user_doc.error and retry_user_doc.doc_fields:
					print("ProfilePopUp: Retry succeeded, user data loaded")
					user_data = retry_user_doc.doc_fields
					update_ui()
					return
			
			# If we got here, the retry failed too
			print("ProfilePopUp: Retry failed, using fallback data")
			_recover_with_auth_data()
	else:
		print("ProfilePopUp: No authenticated user")
		# Just show default/empty data

# Initialize Firebase (useful when retrying connections)
func _init_firebase():
	print("ProfilePopUp: Reinitializing Firebase connection")
	# Make sure Firebase components are properly initialized
	if Firebase.Auth and Firebase.Auth.auth:
		# Force a token refresh to ensure we have a valid token
		var token_result = await Firebase.Auth.refresh_auth()
		print("ProfilePopUp: Auth token refresh result: ", token_result)

# Helper function to recover with auth data
func _recover_with_auth_data():
	if Firebase.Auth.auth:
		user_data = {
			"username": Firebase.Auth.auth.get("displayname", "Unknown User"),
			"email": Firebase.Auth.auth.get("email", ""),
			"user_level": 1,
			"energy": 20,
			"max_energy": 20,  # Changed from 99 to 20
			"coin": 100,
			"power_scale": 120,
			"rank": "Bronze",
			"current_dungeon": 1,
			"current_stage": 1
		}
		update_ui()

# Helper function to create a default user document
func _create_default_user_document(user_id):
	var collection = Firebase.Firestore.collection("dyslexia_users")
	var current_time = Time.get_datetime_string_from_system(false, true)
	
	var display_name = Firebase.Auth.auth.get("displayname", "Unknown User")
	var email = Firebase.Auth.auth.get("email", "")
	
	var default_data = {
		"username": display_name,
		"email": email,
		"birth_date": "",
		"age": 0,
		"profile_picture": "default",
		"user_level": 1,
		"created_at": current_time,
		"last_login": current_time,
		"energy": 20,
		"max_energy": 20,  # Changed from 99 to 20
		"coin": 100,
		"power_scale": 120,
		"rank": "Bronze",
		"current_dungeon": 1,
		"current_stage": 1,
		"dungeons_completed": {
			"1": {"completed": false, "stages_completed": 0},
			"2": {"completed": false, "stages_completed": 0},
			"3": {"completed": false, "stages_completed": 0}
		}
	}
	
	print("ProfilePopUp: Creating default user document")
	var task = collection.add(user_id, default_data)
	
	if task:
		var result = await task.task_finished
		if result and !result.error:
			print("ProfilePopUp: Default user document created successfully")
			# Now try to fetch the newly created document
			load_user_data()
		else:
			print("ProfilePopUp: Error creating default user document: ", result.error if result else "Unknown error")
			_recover_with_auth_data()
	else:
		print("ProfilePopUp: Failed to create task for default user document")
		_recover_with_auth_data()

func update_ui():
	print("ProfilePopUp: Updating UI with user data")
	
	# Set username and UID
	if has_node("ProfileContainer/UserInfoArea/NameValue"):
		var username = user_data.get("username", "Unknown User")
		$ProfileContainer/UserInfoArea/NameValue.text = username
		print("ProfilePopUp: Setting username to: ", username)
	
	# Set email
	if has_node("ProfileContainer/UserInfoArea/EmailValue"):
		var email = user_data.get("email", "No email available")
		$ProfileContainer/UserInfoArea/EmailValue.text = email
		print("ProfilePopUp: Setting email to: ", email)
	
	if has_node("ProfileContainer/UserInfoArea/UIDValue"):
		var uid = Firebase.Auth.auth.localid if Firebase.Auth.auth else "Unknown"
		$ProfileContainer/UserInfoArea/UIDValue.text = uid
		print("ProfilePopUp: Setting UID to: ", uid)
	
	# Update level
	if has_node("ProfileContainer/CharacterArea/Level2"):
		var level = user_data.get("user_level", 1)
		$ProfileContainer/CharacterArea/Level2.text = str(level)
		print("ProfilePopUp: Setting level to: ", level)
	
	# Update additional stats with error checking
	if has_node("ProfileContainer/StatsArea/EnergyValue"):
		var energy = user_data.get("energy", 20)
		var max_energy = user_data.get("max_energy", 99)
		$ProfileContainer/StatsArea/EnergyValue.text = str(energy) + "/" + str(max_energy)
		print("ProfilePopUp: Setting energy to: ", str(energy) + "/" + str(max_energy))
	
	if has_node("ProfileContainer/StatsArea/CoinsValue"):
		var coins = user_data.get("coin", 100)
		$ProfileContainer/StatsArea/CoinsValue.text = str(coins)
		print("ProfilePopUp: Setting coins to: ", coins)
	
	if has_node("ProfileContainer/StatsArea/PowerValue"):
		var power = user_data.get("power_scale", 120)
		$ProfileContainer/StatsArea/PowerValue.text = str(power)
		print("ProfilePopUp: Setting power to: ", power)
	
	if has_node("ProfileContainer/StatsArea/RankValue"):
		var rank = user_data.get("rank", "Bronze")
		$ProfileContainer/StatsArea/RankValue.text = rank
		print("ProfilePopUp: Setting rank to: ", rank)
		
	# Update dungeon progress
	var current_dungeon = user_data.get("current_dungeon", 1)
	var current_stage = user_data.get("current_stage", 1)
	var dungeon_names = user_data.get("dungeon_names", {"1": "The Plains", "2": "The Mountain", "3": "The Demon"})
	
	# Display current dungeon and stage
	if has_node("ProfileContainer/StatsArea/DungeonValue"):
		var dungeon_name = dungeon_names.get(str(current_dungeon), "Unknown Dungeon")
		var dungeon_text = str(current_dungeon) + ": " + dungeon_name
		$ProfileContainer/StatsArea/DungeonValue.text = dungeon_text
		print("ProfilePopUp: Setting dungeon to: ", dungeon_text)
	
	if has_node("ProfileContainer/StatsArea/StageValue"):
		var stage_text = str(current_stage) + "/5"
		$ProfileContainer/StatsArea/StageValue.text = stage_text
		print("ProfilePopUp: Setting stage to: ", stage_text)
	
	# Update profile picture if available
	if user_data.has("profile_picture"):
		current_profile_picture = user_data.profile_picture
		update_profile_picture()
	
	print("ProfilePopUp: UI update complete")

# Update profile picture function
func update_profile_picture():
	print("ProfilePopUp: Updating profile picture to: ", current_profile_picture)
	# Get reference to the profile picture texture rect
	if has_node("ProfileContainer/ProfilePictureButton"):
		var profile_button = $ProfileContainer/ProfilePictureButton
		# Try to load the profile picture
		var texture_path = "res://gui/ProfileScene/Profile/portrait " + current_profile_picture + ".png"
		# Default fallback
		if current_profile_picture == "default":
			texture_path = "res://gui/ProfileScene/Profile/portrait 14.png"
			
		print("ProfilePopUp: Loading texture from: ", texture_path)
		var texture = load(texture_path)
		if texture:
			profile_button.texture_normal = texture
			print("ProfilePopUp: Profile picture updated successfully")
		else:
			print("ProfilePopUp: Failed to load texture from: ", texture_path)

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
		var update_task = collection.update(user_id, {"profile_picture": picture_id})
		var update_result = await update_task.task_finished
		if update_result.error:
			print("Error updating profile picture: ", update_result.error)

func _on_logout_button_pressed():
	# Logout from Firebase
	Firebase.Auth.logout()
	
	# Close profile and navigate to the login scene
	var scene = load("res://Scenes/Authentication.tscn")
	get_tree().change_scene_to_packed(scene)
