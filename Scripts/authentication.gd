extends Control

# Password visibility states
var login_password_visible = false
var reg_password_visible = false
var confirm_password_visible = false

# Called when the node enters the scene tree for the first time.
func _ready():
	Firebase.Auth.login_succeeded.connect(on_login_succeeded)
	Firebase.Auth.signup_succeeded.connect(on_signup_succeeded)
	Firebase.Auth.login_failed.connect(on_login_failed)
	Firebase.Auth.signup_failed.connect(on_signup_failed)
	
	# Connect to tab container changes
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer.tab_changed.connect(_on_tab_container_tab_changed)
	
	# Hide the ForgotPassword tab
	_hide_forgot_password_tab()
	
	# Initialize date picker dropdown
	_initialize_date_pickers()
	
	# Make layout responsive
	get_tree().root.size_changed.connect(_adjust_layout_for_screen_size)
	_adjust_layout_for_screen_size()
	
	if Firebase.Auth.check_auth_file():
		show_message("You are already logged in", true)
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	elif OS.get_name() == "Web":
		var provider = Firebase.Auth.get_GoogleProvider()
		Firebase.Auth.set_redirect_uri("http://localhost:5000/")
		var token = Firebase.Auth.get_token_from_url(provider)
		if token:
			Firebase.Auth.login_with_oauth(token, provider)

# Function to hide the ForgotPassword tab in the TabContainer
func _hide_forgot_password_tab():
	var tab_container = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer
	var tabs_count = tab_container.get_tab_count()
	
	# Find and hide the ForgotPassword tab
	for i in range(tabs_count):
		if tab_container.get_tab_title(i) == "ForgotPassword":
			tab_container.set_tab_hidden(i, true)
			break

# Track tab changes to handle UI updates
func _on_tab_container_tab_changed(_tab):
	clear_all_error_labels()

func _initialize_date_pickers():
	# Days
	var day_option = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/DayOptionButton
	for day in range(1, 32):
		day_option.add_item(str(day))
	
	# Months
	var month_option = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/MonthOptionButton
	var months = ["January", "February", "March", "April", "May", "June",
				 "July", "August", "September", "October", "November", "December"]
	for i in range(months.size()):
		month_option.add_item(months[i])
	
	# Years - Show last 100 years
	var year_option = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/YearOptionButton
	var current_year = Time.get_date_dict_from_system()["year"]
	for year in range(current_year, current_year - 100, -1):
		year_option.add_item(str(year))

func _adjust_layout_for_screen_size():
	# Get the viewport size
	var viewport_size = get_viewport_rect().size
	
	# Adjust the layout based on screen size
	if viewport_size.x < 1000:
		# If screen is narrow, hide left panel and expand right panel
		$MarginContainer/ContentContainer/LeftPanel.visible = false
		$MarginContainer/ContentContainer/RightPanel.size_flags_stretch_ratio = 1.0
	else:
		# For wider screens, show the split layout
		$MarginContainer/ContentContainer/LeftPanel.visible = true
		$MarginContainer/ContentContainer/RightPanel.size_flags_stretch_ratio = 1.0
		$MarginContainer/ContentContainer/LeftPanel.size_flags_stretch_ratio = 0.8
	
	# Make sure the panel fits within the viewport height
	if viewport_size.y < 700:
		$MarginContainer/ContentContainer/RightPanel/MainContainer.custom_minimum_size.y = min(viewport_size.y * 0.9, 650)
	else:
		$MarginContainer/ContentContainer/RightPanel/MainContainer.custom_minimum_size.y = 0

# Helper function to show messages
func show_message(text: String, is_success: bool = true):
	var label = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/StatusLabel
	label.text = text
	if is_success:
		label.add_theme_color_override("font_color", Color(0, 0.6, 0.3))
	else:
		label.add_theme_color_override("font_color", Color(0.85, 0.137, 0.137))

# ===== Password Visibility Functions =====
func _on_show_password_button_pressed():
	login_password_visible = !login_password_visible
	var password_field = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordContainer/PasswordLineEdit
	var button = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordContainer/ShowPasswordButton
	
	password_field.secret = !login_password_visible
	button.text = "Hide" if login_password_visible else "Show"

func _on_show_reg_password_button_pressed():
	reg_password_visible = !reg_password_visible
	var password_field = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordContainer/RegPasswordLineEdit
	var button = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordContainer/ShowRegPasswordButton
	
	password_field.secret = !reg_password_visible
	button.text = "Hide" if reg_password_visible else "Show"

func _on_show_confirm_password_button_pressed():
	confirm_password_visible = !confirm_password_visible
	var password_field = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/ConfirmPasswordContainer/ConfirmPasswordLineEdit
	var button = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/ConfirmPasswordContainer/ShowConfirmPasswordButton
	
	password_field.secret = !confirm_password_visible
	button.text = "Hide" if confirm_password_visible else "Show"

# ===== Input Validation =====
func _on_login_email_text_changed(_new_text):
	# Hide error label when user starts typing
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailErrorLabel.visible = false

func _on_login_password_text_changed(_new_text):
	# Hide error label when user starts typing
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordErrorLabel.visible = false

func clear_all_error_labels():
	# Login tab
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailErrorLabel.visible = false
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordErrorLabel.visible = false
	
	# Register tab
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/UsernameErrorLabel.visible = false
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateErrorLabel.visible = false
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegEmailErrorLabel.visible = false
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordErrorLabel.visible = false
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/ConfirmPasswordErrorLabel.visible = false
	
	# Forgot password tab
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailErrorLabel.visible = false

# ===== Login Functions =====
func _on_login_button_pressed():
	var email = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailLineEdit.text
	var password = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordContainer/PasswordLineEdit.text
	var has_error = false
	
	# Validate email
	if email.strip_edges().is_empty() or not "@" in email or not "." in email:
		$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailErrorLabel.visible = true
		has_error = true
	
	# Validate password
	if password.strip_edges().is_empty():
		$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordErrorLabel.visible = true
		has_error = true
	
	if has_error:
		return
	
	# Proceed with login
	show_message("Signing in...")
	Firebase.Auth.login_with_email_and_password(email, password)

# ===== Registration Functions =====
func _on_register_button_pressed():
	var username = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/UsernameLineEdit.text
	var email = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegEmailLineEdit.text
	var password = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordContainer/RegPasswordLineEdit.text
	var confirm_password = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/ConfirmPasswordContainer/ConfirmPasswordLineEdit.text
	var has_error = false
	
	# Validate username
	if username.strip_edges().is_empty():
		$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/UsernameErrorLabel.visible = true
		has_error = true
	
	# Validate birthdate
	var day_option = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/DayOptionButton
	var month_option = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/MonthOptionButton
	var year_option = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/YearOptionButton
	
	if day_option.selected == -1 or month_option.selected == -1 or year_option.selected == -1:
		$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateErrorLabel.visible = true
		has_error = true
	
	# Validate email
	if email.strip_edges().is_empty() or not "@" in email or not "." in email:
		$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegEmailErrorLabel.visible = true
		has_error = true
	
	# Validate password
	if password.strip_edges().is_empty() or password.length() < 6:
		$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordErrorLabel.visible = true
		has_error = true
	
	# Validate confirm password
	if password != confirm_password:
		$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/ConfirmPasswordErrorLabel.visible = true
		has_error = true
	
	if has_error:
		return
	
	# Create user with email and password
	show_message("Creating account...")
	Firebase.Auth.signup_with_email_and_password(email, password)

# ===== Google Sign-In =====
func _on_sign_in_google_button_pressed():
	var provider = Firebase.Auth.get_GoogleProvider()
	
	show_message("Redirecting to Google...")
	
	if OS.get_name() == "Web":
		# For web builds - critical changes for web authentication
		Firebase.Auth.set_redirect_uri(get_web_redirect_uri())
		provider.params.client_id = "746497205021-j5102kn8f9cjeobvnr696ruuifclpokl.apps.googleusercontent.com"
		# Set these parameters explicitly for web
		provider.params.response_type = "token"  
		provider.params.redirect_type = "redirect_uri"
		Firebase.Auth.get_auth_with_redirect(provider)
	else:
		# For desktop build
		Firebase.Auth.get_auth_localhost(provider, 8060)

# Helper function to determine the correct redirect URI based on the current URL
func get_web_redirect_uri():
	if OS.get_name() == "Web":
		# Try to detect actual URL in web builds using JavaScript
		if JavaScriptBridge.eval("typeof window !== 'undefined'"):
			var location = JavaScriptBridge.eval("window.location.origin + window.location.pathname")
			return location
	
	# Fallback for local testing
	return "http://localhost:5000/"

# ===== Forgot Password Functions =====
func _on_forgot_password_button_pressed():
	# Switch to the forgot password tab
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer.current_tab = 2
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailLineEdit.grab_focus()
	
	# Copy email address from login tab if available
	var login_email = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailLineEdit.text
	if not login_email.strip_edges().is_empty():
		$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailLineEdit.text = login_email

func _on_back_to_login_button_pressed():
	# Switch back to login tab
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer.current_tab = 0

func _on_reset_password_button_pressed():
	var email = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailLineEdit.text
	
	# Validate email
	if email.strip_edges().is_empty() or not "@" in email or not "." in email:
		$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailErrorLabel.visible = true
		return
	
	# Send password reset email
	Firebase.Auth.send_password_reset_email(email)
	
	# Show success message
	show_message("Password reset link sent to your email", true)
	
	# Switch back to login tab after a short delay
	await get_tree().create_timer(1.0).timeout
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer.current_tab = 0

# ===== Firebase Authentication Callbacks =====
func on_login_succeeded(auth):
	print("Login successful")
	Firebase.Auth.save_auth(auth)
	
	# Check if we need to store/update user data in Firestore
	var collection = Firebase.Firestore.collection("users")
	var user_id = auth.localid
	
	var current_time = Time.get_datetime_string_from_system(false, true)
	
	# First check if this user already exists in the database
	var task = collection.get(user_id)
	if task == null:
		# Handle task creation failure
		print("Failed to create task for user check")
		# Create a new user anyway
		var display_name = auth.get("displayname", "")
		var email = auth.get("email", "")
		
		# Create new user document with default values
		var user_doc = {
			"username": display_name,
			"email": email,
			"birth_date": "", # Empty for Google users
			"age": 0, # Will be calculated if birth date is provided later
			"profile_picture": "default", # Use default for all new users
			"user_level": 1, # Default level for new users
			"created_at": current_time,
			"last_login": current_time
		}
		
		# Save the user data
		collection.add(user_id, user_doc)
	else:
		# Add proper error handling
		var result = await task.task_finished
		
		if result == null or result.error:
			print("Error handling Firestore task")
			# Fallback - create a new user anyway
			var display_name = auth.get("displayname", "")
			var email = auth.get("email", "")
			
			var user_doc = {
				"username": display_name,
				"email": email,
				"birth_date": "",
				"age": 0,
				"profile_picture": "default",
				"user_level": 1,
				"created_at": current_time,
				"last_login": current_time
			}
			
			collection.add(user_id, user_doc)
		else:
			# Existing user - do a complete update
			if result.doc_fields != null:
				var current_data = result.doc_fields
				current_data["last_login"] = current_time
				# Complete document update instead of just updating one field
				collection.add(user_id, current_data)
			else:
				# If we can't retrieve the fields, create new
				var display_name = auth.get("displayname", "")
				var email = auth.get("email", "")
				
				var user_doc = {
					"username": display_name,
					"email": email,
					"birth_date": "",
					"age": 0,
					"profile_picture": "default",
					"user_level": 1,
					"created_at": current_time,
					"last_login": current_time
				}
				
				collection.add(user_id, user_doc)
	
	# Show success message and redirect to main menu
	show_message("Login Successful! Redirecting...", true)
	
	# Change scene after a short delay
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	
func on_signup_succeeded(auth):
	print("Signup successful")
	
	# Get user data from registration form
	var username = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/UsernameLineEdit.text
	var email = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegEmailLineEdit.text
	
	# Get birthdate components
	var day_option = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/DayOptionButton
	var month_option = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/MonthOptionButton
	var year_option = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/YearOptionButton

	var birth_date = ""
	var age = 0
	if day_option.selected > -1 and month_option.selected > -1 and year_option.selected > -1:
		var year = int(year_option.get_item_text(year_option.selected))
		var month = month_option.selected + 1
		var day = int(day_option.get_item_text(day_option.selected))
		
		birth_date = "%04d-%02d-%02d" % [year, month, day]
		
		# Calculate age
		var current_date = Time.get_date_dict_from_system()
		age = current_date["year"] - year
		if current_date["month"] < month or (current_date["month"] == month and current_date["day"] < day):
			age -= 1
	
	var current_time = Time.get_datetime_string_from_system(false, true)
	
	# Store user data in Firestore
	var user_doc = {
		"username": username,
		"email": email,
		"birth_date": birth_date,
		"age": age,
		"profile_picture": "default", # Default profile picture for everyone
		"user_level": 1, # Default level for new users
		"created_at": current_time,
		"last_login": current_time
	}
	
	# Save to Firestore
	var collection = Firebase.Firestore.collection("users")
	collection.add(auth.localid, user_doc)
	
	Firebase.Auth.save_auth(auth)
	
	# Show success message and redirect
	show_message("Registration Successful! Redirecting...", true)
	
	# Change scene after a short delay
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	
func on_login_failed(error_code, message):
	print("Login failed: ", error_code, " - ", message)
	show_message("Login Failed: " + message, false)
	
func on_signup_failed(error_code, message):
	print("Signup failed: ", error_code, " - ", message)
	show_message("Registration Failed: " + message, false)

# Then in your profile loading code (when you implement it):
func load_profile_image(image_identifier):
	if image_identifier == "default":
		return preload("res://gui/default.png")
	else:
		# Handle loading from Firebase Storage or web URLs if needed
		pass

# Helper function to get auth headers for requests
func _get_auth_headers():
	var headers = []
	if Firebase.Auth.auth != null and Firebase.Auth.auth.has("idtoken"):
		headers.append("Authorization: Bearer " + Firebase.Auth.auth.idtoken)
	return headers

# Add this to your authentication.gd
func is_web_platform():
	return OS.get_name() == "Web"

# Replace any file storage with web storage when in browser
func save_web_data(key, data):
	if is_web_platform():
		var js_code = "sessionStorage.setItem('%s', '%s');" % [key, JSON.stringify(data)]
		JavaScriptBridge.eval(js_code)