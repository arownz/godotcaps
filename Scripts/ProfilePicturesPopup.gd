extends Control

signal picture_selected(picture_id)
signal cancelled

var selected_picture_id = ""
var selected_button = null
var current_equipped_id = ""
var checkmark_icons = {}

func _ready():
	# Enhanced fade-in animation matching SettingScene.gd pattern
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Initialize UI
	$PictureContainer/ConfirmButton.disabled = true
	
	# Connect background click to close popup - matching SettingScene.gd pattern
	var bg = get_node_or_null("Background")
	if bg and not bg.gui_input.is_connected(_on_background_clicked):
		bg.gui_input.connect(_on_background_clicked)
	
		# Create checkmark icons for all portrait buttons but make them invisible
	for child in $PictureContainer/ScrollContainer/GridContainer.get_children():
		if child is TextureButton:
			var portrait_id = child.name.replace("Portrait", "")
			
			# Create checkmark icon as a child of the button
			var checkmark = TextureRect.new()
			checkmark.texture = load("res://gui/ProfileScene/Profile/Done 1.png")
			checkmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			checkmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			checkmark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			checkmark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			checkmark.set_anchors_preset(Control.PRESET_CENTER)
			checkmark.position = Vector2((child.size.x - 30) / 2, (child.size.y - 30) / 2)
			checkmark.visible = false
			checkmark.custom_minimum_size = Vector2(30, 30)
			checkmark.z_index = 10 # Ensure it appears above the button
			child.add_child(checkmark)
			
			# Store reference to the checkmark
			checkmark_icons[portrait_id] = checkmark
	
	# Show checkmark for currently equipped profile
	update_checkmarks()
	
	# Load current profile from Firebase
	await load_current_profile()

func load_current_profile():
	# Get current user ID
	if Firebase.Auth.auth and Firebase.Auth.auth.has("localid"):
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		print("ProfilePicturesPopup: Fetching user document to get profile picture")
		var document = await collection.get_doc(user_id)
		
		if document and !("error" in document.keys() and document.get_value("error")):
			# Try to get profile data from new structure first
			var profile = document.get_value("profile")
			if profile != null and typeof(profile) == TYPE_DICTIONARY:
				var profile_id = profile.get("profile_picture", "default")
				print("ProfilePicturesPopup: Current profile picture is: ", profile_id)
				# Handle "default" profile mapping to "13"
				if profile_id == "default":
					current_equipped_id = "13"
				else:
					current_equipped_id = profile_id
				update_checkmarks()
			else:
				# Fallback to old flat structure
				var doc_keys = document.keys()
				if "profile_picture" in doc_keys:
					var profile_id = document.get_value("profile_picture")
					print("ProfilePicturesPopup: Current profile picture is: ", profile_id)
					# Handle "default" profile mapping to "13"
					if profile_id == "default":
						current_equipped_id = "13"
					else:
						current_equipped_id = profile_id
					update_checkmarks()

func set_current_profile(profile_id):
	current_equipped_id = profile_id
	update_checkmarks()

func update_checkmarks():
	# Hide all checkmarks and reset highlight for all portrait buttons
	for child in $PictureContainer/ScrollContainer/GridContainer.get_children():
		if child is TextureButton:
			child.modulate = Color(1, 1, 1, 1)
			var child_portrait_id = child.name.replace("Portrait", "")
			if child_portrait_id in checkmark_icons:
				checkmark_icons[child_portrait_id].visible = false

	# Show checkmark and highlight for currently equipped profile
	if current_equipped_id in checkmark_icons:
		var icon = checkmark_icons[current_equipped_id]
		if icon:
			icon.visible = true
		var button_name = "Portrait" + current_equipped_id
		var equipped_button = $PictureContainer/ScrollContainer/GridContainer.get_node_or_null(button_name)
		if equipped_button and equipped_button is TextureButton:
			equipped_button.modulate = Color(0.5, 0.8, 1.0, 1.0)

func _on_portrait_button_pressed(picture_id):
	$ButtonClick.play()
	print("ProfilePicturesPopup: Portrait " + picture_id + " selected")
	
	# Find the button that was pressed
	selected_picture_id = picture_id
	
	# Reset styling for all portrait buttons and hide all checkmarks
	for child in $PictureContainer/ScrollContainer/GridContainer.get_children():
		if child is TextureButton:
			child.modulate = Color(1, 1, 1, 1)
			# Hide checkmark for this button
			var child_portrait_id = child.name.replace("Portrait", "")
			if child_portrait_id in checkmark_icons:
				checkmark_icons[child_portrait_id].visible = false
	
	# Highlight the selected button - find it by name
	var button_name = "Portrait" + picture_id
	var selected_portrait = $PictureContainer/ScrollContainer/GridContainer.get_node_or_null(button_name)
	if selected_portrait and selected_portrait is TextureButton:
		selected_portrait.modulate = Color(0.5, 0.8, 1.0, 1.0)
		selected_button = selected_portrait
		
		# Show checkmark for the selected portrait
		if picture_id in checkmark_icons:
			checkmark_icons[picture_id].visible = true
	
	# Enable confirm button
	$PictureContainer/ConfirmButton.disabled = false

func _on_confirm_button_pressed():
	print("ProfilePicturesPopup: Confirming selection " + selected_picture_id)
	
	# Update Firebase with the new profile picture - FIXED
	var success = await _update_profile_picture_in_firebase(selected_picture_id)
	
	if success:
		# Emit the selected portrait ID
		emit_signal("picture_selected", selected_picture_id)
	
	# Self-destruct
	queue_free()

# FIXED: Update profile picture in Firebase using working method
func _update_profile_picture_in_firebase(picture_id):
	if !Firebase.Auth.auth:
		print("ProfilePicturesPopup: No authenticated user")
		return false
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("ProfilePicturesPopup: Updating profile picture to: " + picture_id)
	
	# Get current document
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		print("ProfilePicturesPopup: Document retrieved successfully")
		
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
				print("ProfilePicturesPopup: Successfully updated profile picture to " + picture_id + " in Firebase (nested)")
				return true
			else:
				print("ProfilePicturesPopup: Failed to update document with nested structure")
				return false
		else:
			# Fallback to simple field update for old structure
			document.add_or_update_field("profile_picture", picture_id)
			
			# Update the document using the update method
			var updated_document = await collection.update(document)
			if updated_document:
				print("ProfilePicturesPopup: Successfully updated profile picture to " + picture_id + " in Firebase (flat)")
				return true
			else:
				print("ProfilePicturesPopup: Failed to update document with flat structure")
				return false
	else:
		print("ProfilePicturesPopup: Failed to get user document for update")
		return false

func _on_close_button_pressed():
	$ButtonClick.play()
	print("ProfilePicturesPopup: Closing without selection")
	_fade_out_and_close()

# Helper function to fade out before closing - matching SettingScene.gd pattern
func _fade_out_and_close():
	var tween = create_tween()
	tween.set_parallel(true)
	# Fade out background
	var bg = get_node_or_null("Background")
	if bg:
		tween.tween_property(bg, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	# Panel fade and scale
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	
	# Emit cancelled signal
	emit_signal("cancelled")
	
	# Self-destruct
	queue_free()

# Handle background click to close popup - matching SettingScene.gd pattern
func _on_background_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fade_out_and_close()


func _on_close_button_mouse_entered():
	$ButtonHover.play()
