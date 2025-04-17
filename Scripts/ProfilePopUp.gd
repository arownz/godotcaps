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
		
		# Fetch user data from Firestore - explicitly use dyslexia_users collection
		var collection = Firebase.Firestore.collection("dyslexia_users")
		print("ProfilePopUp: Fetching from collection: dyslexia_users")
		
		var task = collection.get(user_id)
		
		if task:
			print("ProfilePopUp: Fetch task created successfully")
			var user_doc = await task.task_finished
			
			if user_doc and !user_doc.error:
				print("ProfilePopUp: User data loaded successfully")
				print("ProfilePopUp: Document fields: ", user_doc.doc_fields)
				user_data = user_doc.doc_fields
				update_ui()
			else:
				print("ProfilePopUp: Failed to load user data - ", user_doc.error if user_doc else "No document")
				# Try to recover using auth data at minimum
				if Firebase.Auth.auth:
					user_data = {
						"username": Firebase.Auth.auth.get("displayname", "Unknown User"),
						"email": Firebase.Auth.auth.get("email", ""),
						"user_level": 1,
						"energy": 20,
						"coin": 100,
						"power_scale": 120,
						"rank": "Bronze",
						"current_dungeon": 1,
						"current_stage": 1
					}
					update_ui()
		else:
			print("ProfilePopUp: Failed to create Firestore task")
	else:
		print("ProfilePopUp: No authenticated user")

func update_ui():
	print("ProfilePopUp: Updating UI with user data")
	
	# Set username and UID
	if has_node("ProfileContainer/UserInfoArea/NameValue"):
		$ProfileContainer/UserInfoArea/NameValue.text = user_data.get("username", "Unknown User")
	
	# Set email
	if has_node("ProfileContainer/UserInfoArea/EmailValue"):
		$ProfileContainer/UserInfoArea/EmailValue.text = user_data.get("email", "No email available")
	
	if has_node("ProfileContainer/UserInfoArea/UIDValue"):
		$ProfileContainer/UserInfoArea/UIDValue.text = Firebase.Auth.auth.localid if Firebase.Auth.auth else "Unknown"
	
	# Update level
	if has_node("ProfileContainer/CharacterArea/Level2"):
		$ProfileContainer/CharacterArea/Level2.text = str(user_data.get("user_level", 1))
	
	# Update additional stats with error checking
	if has_node("ProfileContainer/StatsArea/EnergyValue"):
		var energy = user_data.get("energy", 20)
		$ProfileContainer/StatsArea/EnergyValue.text = str(energy) + "/99"
	
	if has_node("ProfileContainer/StatsArea/CoinsValue"):
		$ProfileContainer/StatsArea/CoinsValue.text = str(user_data.get("coin", 100))
	
	if has_node("ProfileContainer/StatsArea/PowerValue"):
		$ProfileContainer/StatsArea/PowerValue.text = str(user_data.get("power_scale", 120))
	
	if has_node("ProfileContainer/StatsArea/RankValue"):
		$ProfileContainer/StatsArea/RankValue.text = user_data.get("rank", "Bronze")
		
	# Update dungeon progress
	var current_dungeon = user_data.get("current_dungeon", 1)
	var current_stage = user_data.get("current_stage", 1)
	var dungeon_names = user_data.get("dungeon_names", {"1": "The Plains", "2": "The Mountain", "3": "The Demon"})
	
	# Display current dungeon and stage
	if has_node("ProfileContainer/StatsArea/DungeonValue"):
		var dungeon_name = dungeon_names.get(str(current_dungeon), "Unknown Dungeon")
		$ProfileContainer/StatsArea/DungeonValue.text = str(current_dungeon) + ": " + dungeon_name
	
	if has_node("ProfileContainer/StatsArea/StageValue"):
		$ProfileContainer/StatsArea/StageValue.text = str(current_stage) + "/5"
	
	# Update profile picture if available
	if user_data.has("profile_picture"):
		current_profile_picture = user_data.profile_picture
		update_profile_picture()
	
	print("ProfilePopUp: UI update complete")

func update_profile_picture():
	# This is a placeholder for updating the profile picture
	# In a real implementation, you would load the correct texture based on the profile_picture value
	pass

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
