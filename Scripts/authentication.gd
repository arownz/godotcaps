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
	
	# Handle authentication check on startup
	check_existing_auth()

# Consolidate auth checking to avoid duplicate code
func check_existing_auth():
	if Firebase.Auth.check_auth_file():
		show_message("You are already logged in", true)
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	elif OS.has_feature('web'):
		 # Check for OAuth tokens in URL
		print("DEBUG: Web platform detected, checking for auth token")
		var provider = Firebase.Auth.get_GoogleProvider()
		var redirect_uri = get_web_redirect_uri()
		print("DEBUG: Setting redirect URI: " + redirect_uri)
		Firebase.Auth.set_redirect_uri(redirect_uri)
		
		var token = Firebase.Auth.get_token_from_url(provider)
		if token:
			print("DEBUG: Token found on page load: " + str(token).substr(0, 10) + "...")
			show_message("Completing Google Sign-In...", true)
			# Use a deferred call to ensure the GUI is ready
			await get_tree().process_frame
			# Store a flag to indicate we're processing a sign-in
			save_web_data("processing_signin", "true")
			save_web_data("google_auth_in_progress", "true")
			Firebase.Auth.login_with_oauth(token, provider)
		else:
			# Check if we were in the middle of a Google auth that might have failed
			if JavaScriptBridge.eval("window.location.href.indexOf('#state=google_auth') !== -1"):
				print("DEBUG: Google auth state found but no token - possible auth error")
				show_message("Google Sign-In failed. Please try again.", false)
				# Clean up URL
				JavaScriptBridge.eval("""
					if (window.history && window.history.replaceState) {
						window.history.replaceState({}, document.title, window.location.pathname);
					}
				""")

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
	# If we're on web, try clearing storage first to ensure fresh state
	if is_web_platform():
		clear_web_storage()
		
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
		$MarginContainer/ContentContainer/RightPanel/MainContainer	/VBoxContainer/TabContainer/Register/RegPasswordErrorLabel.visible = true
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
	
	show_message("Redirecting to Google...", true)
	
	if OS.has_feature('web'):
		# For web builds - enhanced web auth
		var redirect_uri = get_web_redirect_uri()
		print("DEBUG: Using redirect URI: " + redirect_uri)
		Firebase.Auth.set_redirect_uri(redirect_uri)
		
		# Save flag that we're starting Google auth
		save_web_data("google_auth_started", "true")
		
		# Set client ID from .env config
		provider.params.client_id = "746497205021-j5102kn8f9cjeobvnr696ruuifclpokl.apps.googleusercontent.com"
		
		# Set explicit parameters for Google auth
		provider.params.response_type = "token"
		provider.params.redirect_type = "redirect_uri"
		provider.params.prompt = "select_account" # Force account selection
		provider.params.scope = "email profile openid"
		provider.params.state = "google_auth" # For verifying the response
		provider.params.display = "page" # Force display in the same page/tab
		
		# Include login_hint if we have an email from a previous login attempt
		var email_field = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailLineEdit
		if !email_field.text.strip_edges().is_empty():
			provider.params.login_hint = email_field.text
		
		print("DEBUG: Redirecting to Google OAuth")
		Firebase.Auth.get_auth_with_redirect(provider)
	else:
		# For desktop build
		Firebase.Auth.get_auth_localhost(provider, 8060)

# Enhanced redirect URI detection for web
func get_web_redirect_uri():
	if OS.has_feature('web'):
		# Try to detect actual URL in web builds using JavaScript
		if JavaScriptBridge.eval("typeof window !== 'undefined'"):
			var current_url = JavaScriptBridge.eval("""
				// Get the base URL without any query parameters or hash
				window.location.origin + window.location.pathname
			""")
			print("DEBUG: Detected web URL: " + str(current_url))
			return current_url
	
	# Fallback for local testing
	return "http://localhost:5000/"

# ===== Forgot Password Functions =====
func _on_forgot_password_button_pressed():
	# Switch to the forgot password tab
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer.current_tab = 2
	$MarginContainer/ContentContainer/RightPanel/MainContainer/	VBoxContainer/TabContainer/ForgotPassword/ResetEmailLineEdit.grab_focus()
	
	# Copy email address from login tab if available
	var login_email = $MarginContainer/ContentContainer/RightPanel/MainContainer/	VBoxContainer/TabContainer/Login/EmailLineEdit.text
	if not login_email.strip_edges().is_empty():
		$MarginContainer/ContentContainer/RightPanel/MainContainer/	VBoxContainer/TabContainer/ForgotPassword/ResetEmailLineEdit.text = login_email

func _on_back_to_login_button_pressed():
	# Switch back to login tab
	$MarginContainer/ContentContainer/RightPanel/MainContainer/	VBoxContainer/TabContainer.current_tab = 0

func _on_reset_password_button_pressed():
	var email = $MarginContainer/ContentContainer/RightPanel/MainContainer	/VBoxContainer/TabContainer/ForgotPassword/ResetEmailLineEdit.text
	
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
	$MarginContainer/ContentContainer/RightPanel/MainContainer	/VBoxContainer/TabContainer.current_tab = 0

# ===== Firebase Authentication Callbacks =====
func on_login_succeeded(auth):
	print("DEBUG: Login successful with auth data: " + str(auth.keys()))
	
	# Make sure we save the auth data properly
	var save_result = Firebase.Auth.save_auth(auth)
	print("DEBUG: Auth save result: " + str(save_result))
	
	# Check if this is a returning web user from Google auth
	var is_returning_from_google = false
	if OS.has_feature('web'):
		if JavaScriptBridge.eval("sessionStorage.getItem('processing_signin') === 'true' || sessionStorage.getItem('google_auth_in_progress') === 'true'"):
			is_returning_from_google = true
			JavaScriptBridge.eval("sessionStorage.removeItem('processing_signin'); sessionStorage.removeItem('google_auth_in_progress');")
			print("DEBUG: User returning from Google auth")
		
		# Also check URL for Google auth state
		if JavaScriptBridge.eval("window.location.href.indexOf('#state=google_auth') !== -1"):
			is_returning_from_google = true
			print("DEBUG: Google auth state found in URL")
	
	# Check if we need to store/update user data in Firestore
	var collection = Firebase.Firestore.collection("dyslexia_users")
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
				}
			}
		}

		# Save the user data
		collection.add(user_id, user_doc)
		
		# Navigate to main menu
		navigate_to_main_menu(is_returning_from_google)
	else:
		# Add proper error handling
		var result = await task.task_finished
		
		if result == null or result.error:
			print("Error handling Firestore task")
			# Fallback - create a new user anyway
			var display_name = auth.get("displayname", "")
			var email = auth.get("email", "")
			
			# Create new user document with default values
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
						"current_dungeon": 1, }
				}
			}
			
			collection.add(user_id, user_doc)
			
			# Navigate to main menu
			navigate_to_main_menu(is_returning_from_google)
		else:
			# Existing user - do a complete update
			if result.doc_fields != null:
				var current_data = result.doc_fields
				current_data["last_login"] = current_time

				# Make sure dungeons exist
				if not current_data.has("dungeons"):
					current_data["dungeons"] = {
						"1": {"completed": false, "stages_completed": 0},
						"2": {"completed": false, "stages_completed": 0},
						"3": {"completed": false, "stages_completed": 0}
					}
				
				# Make sure dungeon progress exists
				if not current_data.has("current_dungeon"):
					current_data["current_dungeon"] = 1
				
				# Complete document update instead of just updating one field
				collection.add(user_id, current_data)
				
				# Navigate to main menu
				navigate_to_main_menu(is_returning_from_google)
	
	# Navigate to main menu
	navigate_to_main_menu(is_returning_from_google)

# Helper function to navigate to main menu
func navigate_to_main_menu(is_google_auth := false):
	# Show success message and redirect to main menu
	show_message("Login Successful! Redirecting...", true)
	
	# For Google auth that just completed, go immediately to avoid delays
	if is_google_auth:
		print("DEBUG: Immediately navigating to main menu after Google auth")
		# Make sure the URL is clean
		if OS.has_feature('web'):
			JavaScriptBridge.eval("""
				if (window.history && window.history.replaceState) {
					window.history.replaceState({}, document.title, window.location.pathname);
				}
			""")
		# Use a CallDeferred approach to avoid scene tree issues during transition
		call_deferred("_safe_change_scene", "res://Scenes/MainMenu.tscn")
	else:
		# For regular login, add a slight delay for UX
		await get_tree().create_timer(0.5).timeout
		# Check if still in tree before changing scene
		if is_inside_tree():
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
		else:
			call_deferred("_safe_change_scene", "res://Scenes/MainMenu.tscn")

# Add a helper function to safely change scenes, even if node is being freed
func _safe_change_scene(target_scene):
	# Always run from a context with valid scene tree access
	if Engine.get_main_loop():
		print("DEBUG: Using safe scene change to: " + target_scene)
		Engine.get_main_loop().call_deferred("change_scene_to_file", target_scene)
	else:
		print("ERROR: Could not access main loop for scene change")
		# Last resort - try to get SceneTree through global scope
		var tree = Engine.get_singleton("SceneTree")
		if tree:
			tree.change_scene_to_file(target_scene)
		else:
			printerr("CRITICAL: Cannot change scene - no access to SceneTree")

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

	# Store user data in Firestore with new structure
	var user_doc = {
		"profile": {
			"username": username,
			"email": email,
			"birth_date": birth_date,
			"age": age,
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
			}
		}
	}
	
	# Save to Firestore
	var collection = Firebase.Firestore.collection("dyslexia_users")
	collection.add(auth.localid, user_doc)
	
	Firebase.Auth.save_auth(auth)
	
	# Show success message and redirect
	show_message("Registration Successful! Redirecting...", true)
	
	# Change scene after a short delay
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

# Add this to your authentication.gd
func is_web_platform():
	return OS.has_feature('web')

# Replace any file storage with web storage when in browser
func save_web_data(key, data):
	if is_web_platform():
		var js_code = """
		(function() {
			try {
				sessionStorage.setItem('""" + key + """', '""" + str(data) + """');
				console.log('Saved data for key: """ + key + """');
				return true;
			} catch(e) {
				console.error('Error saving sessionStorage data: ' + e.message);
				return false;
			}
		})();
		"""
		return JavaScriptBridge.eval(js_code)
	return false


# Add these missing functions
func on_login_failed(error_code, message):
	print("DEBUG: Login failed: ", error_code, " - ", message)
	
	# Provide user-friendly error messages
	var user_message = ""
	
	# Common Firebase error codes
	match error_code:
		"auth/user-not-found":
			user_message = "Account does not exist. Please check your email or sign up."
		"auth/wrong-password":
			user_message = "Incorrect password. Please try again."
		"auth/invalid-email":
			user_message = "Invalid email format."
		"auth/user-disabled":
			user_message = "This account has been disabled."
		"auth/too-many-requests":
			user_message = "Too many failed login attempts. Please try again later."
		_:
			# Default error message
			user_message = "Login failed: " + message
	
	# Show the error message
	show_message(user_message, false)
	
	# If this was a Google auth failure, show more helpful message
	if message.contains("TOKEN_EXPIRED") or message.contains("INVALID_IDP_RESPONSE"):
		show_message("Google login failed. Please try again or use email login.", false)
	
func on_signup_failed(error_code, message):
	print("Signup failed: ", error_code, " - ", message)
	show_message("Registration Failed: " + message, false)

# Helper function to get auth headers for requests
func _get_auth_headers():
	var headers = []
	if Firebase.Auth.auth != null and Firebase.Auth.auth.has("idtoken"):
		headers.append("Authorization: Bearer " + Firebase.Auth.auth.idtoken)
	return headers

# Add this function to clear web storage if issues are detected
func clear_web_storage():
	if is_web_platform():
		var js_code = """
		(function() {
			try {
				// Clear session storage
				sessionStorage.clear();
				// Clear local storage
				localStorage.clear();
				console.log('Web storage cleared');
				return true;
			} catch(e) {
				console.error('Error clearing web storage: ' + e.message);
				return false;
			}
		})();
		"""
		return JavaScriptBridge.eval(js_code)
	return false