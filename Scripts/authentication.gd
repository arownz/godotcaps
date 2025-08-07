extends Control

# Password visibility states
var login_password_visible = false
var reg_password_visible = false
var confirm_password_visible = false

# Store registration data for document creation
var registration_username = ""
var registration_email = ""
var registration_birth_date = ""
var registration_age = 0

# Notification popup for user feedback
var notification_popup

# Called when the node enters the scene tree for the first time.
func _ready():
	# Add fade-in animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Load and setup notification popup
	var notification_scene = preload("res://Scenes/NotificationPopUp.tscn")
	notification_popup = notification_scene.instantiate()
	add_child(notification_popup)
	
	Firebase.Auth.login_succeeded.connect(on_login_succeeded)
	Firebase.Auth.signup_succeeded.connect(on_signup_succeeded)
	Firebase.Auth.login_failed.connect(on_login_failed)
	Firebase.Auth.signup_failed.connect(on_signup_failed)
	
	# Initialize Firebase auth persistence for web builds
	if OS.has_feature('web'):
		_initialize_firebase_persistence()
	
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

# Initialize Firebase auth persistence for web builds (simplified approach)
func _initialize_firebase_persistence():
	JavaScriptBridge.eval("""
		(function() {
			console.log('Setting Firebase auth persistence to LOCAL for web builds');
			
			// Simple persistence setup - just ensure it's set to LOCAL like standalone
			function setFirebasePersistence() {
				try {
					if (window.firebase && window.firebase.auth) {
						window.firebase.auth().setPersistence(window.firebase.auth.Auth.Persistence.LOCAL)
							.then(function() {
								console.log('Firebase auth persistence set to LOCAL');
							})
							.catch(function(error) {
								console.error('Error setting Firebase persistence:', error);
							});
					} else {
						// Retry if Firebase isn't ready yet
						setTimeout(setFirebasePersistence, 100);
					}
				} catch(e) {
					console.error('Error initializing Firebase auth:', e);
				}
			}
			
			setFirebasePersistence();
		})();
	""")

# Consolidate auth checking to avoid duplicate code
func check_existing_auth():
	# If logout just occurred, skip auto-login and clear the flag
	if DungeonGlobals.logout_just_occurred:
		print("DEBUG: Logout just occurred, skipping auto-login")
		DungeonGlobals.logout_just_occurred = false
		return
		
	# Add a small delay to allow logout operations to complete
	await get_tree().create_timer(0.1).timeout
	
	# Use Firebase's built-in auth persistence mechanism for both web and standalone
	if Firebase.Auth.check_auth_file():
		print("DEBUG: Firebase auth file found, loading existing authentication")
		Firebase.Auth.load_auth()
		
		# Verify that the loaded auth is valid
		if Firebase.Auth.auth != null and Firebase.Auth.auth.has("localid"):
			print("DEBUG: Valid auth loaded, user already logged in")
			show_message("You are already logged in", true)
			await get_tree().create_timer(0.5).timeout
			_fade_out_and_change_scene("res://Scenes/MainMenu.tscn")
			return
		else:
			print("DEBUG: Auth file exists but no valid auth object, proceeding with login screen")
	
	# For web builds, check for OAuth redirect tokens following Firebase Godot extension pattern
	if OS.has_feature('web'):
		print("DEBUG: Web platform detected, checking for OAuth redirect")
		var provider = Firebase.Auth.get_GoogleProvider()
		var redirect_uri = get_web_redirect_uri()
		print("DEBUG: Setting redirect URI: " + redirect_uri)
		Firebase.Auth.set_redirect_uri(redirect_uri)
		
		# Check for OAuth token in URL (following documentation pattern)
		var token = Firebase.Auth.get_token_from_url(provider)
		if token:
			print("DEBUG: OAuth token found on page load, completing sign-in")
			show_message("Completing Google Sign-In...", true)
			# Use a deferred call to ensure the GUI is ready
			await get_tree().process_frame
			Firebase.Auth.login_with_oauth(token, provider)
			return
		
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
			return

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

# Helper function to show messages using notification popup with dyslexia-friendly feedback
func show_message(text: String, is_success: bool = true):
	if notification_popup:
		# Use different titles based on message type
		var title = "Success" if is_success else "Error"
		# Use standard "OK" button text
		var button_text = "OK"
		
		# Show the notification popup with appropriate title and message
		notification_popup.show_notification(title, text, button_text)
	else:
		# Fallback in case notification popup isn't available
		print("AUTH MESSAGE: ", text)

# ===== Password Visibility Functions =====
func _on_show_password_button_pressed():
	$ButtonClick.play()
	login_password_visible = !login_password_visible
	var password_field = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordContainer/PasswordLineEdit
	var button = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordContainer/ShowPasswordButton
	
	password_field.secret = !login_password_visible
	button.text = "Hide" if login_password_visible else "Show"

func _on_show_reg_password_button_pressed():
	$ButtonClick.play()
	reg_password_visible = !reg_password_visible
	var password_field = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordContainer/RegPasswordLineEdit
	var button = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordContainer/ShowRegPasswordButton
	
	password_field.secret = !reg_password_visible
	button.text = "Hide" if reg_password_visible else "Show"

func _on_show_confirm_password_button_pressed():
	$ButtonClick.play()
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
	$ButtonClick.play()
	# Don't clear storage for regular login - we want persistence
	# Only clear storage if there are authentication conflicts
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
	$ButtonClick.play()
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
	
	# Store registration data for use in document creation
	registration_username = username.strip_edges()
	registration_email = email.strip_edges()
	
	# Calculate age and birth date
	if day_option.selected > -1 and month_option.selected > -1 and year_option.selected > -1:
		var year = int(year_option.get_item_text(year_option.selected))
		var month = month_option.selected + 1
		var day = int(day_option.get_item_text(day_option.selected))
		
		registration_birth_date = "%04d-%02d-%02d" % [year, month, day]
		
		# Calculate age
		var current_date = Time.get_date_dict_from_system()
		registration_age = current_date["year"] - year
		if current_date["month"] < month or (current_date["month"] == month and current_date["day"] < day):
			registration_age -= 1
	
	# Create user with email and password
	show_message("Creating account...")
	Firebase.Auth.signup_with_email_and_password(email, password)

# ===== Google Sign-In =====
func _on_sign_in_google_button_pressed():
	$ButtonClick.play()
	var provider = Firebase.Auth.get_GoogleProvider()
	
	show_message("Redirecting to Google...", true)
	
	if OS.has_feature('web'):
		# For web builds - ensure same-tab behavior with account selection forced
		var redirect_uri = get_web_redirect_uri()
		print("DEBUG: Using redirect URI: " + redirect_uri)
		Firebase.Auth.set_redirect_uri(redirect_uri)
		
		# Override popup behavior to force same-tab redirect
		JavaScriptBridge.eval("""
			// Override window.open to prevent popups
			var originalOpen = window.open;
			window.open = function(url, target, features) {
				if (url && url.includes('accounts.google.com')) {
					// Force same-tab navigation for Google OAuth
					window.location.href = url;
					return null;
				}
				return originalOpen.call(this, url, target, features);
			};
		""")
		
		# Save flag that we're starting Google auth (for debugging only)
		print("DEBUG: Starting Google OAuth with redirect")
		
		print("DEBUG: Redirecting to Google OAuth in same tab with forced account selection")
		
		# Use Firebase's built-in same-tab redirect functionality
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
	$ButtonClick.play()
	# Switch to the forgot password tab
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer.current_tab = 2
	$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailLineEdit.grab_focus()
	
	# Copy email address from login tab if available
	var login_email = $MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailLineEdit.text
	if not login_email.strip_edges().is_empty():
		$MarginContainer/ContentContainer/RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailLineEdit.text = login_email

func _on_back_to_login_button_pressed():
	$ButtonClick.play()
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
	print("DEBUG: Login successful with auth data: " + str(auth.keys()))
	
	# Use Firebase's built-in auth persistence (works for both web and standalone)
	var save_result = Firebase.Auth.save_auth(auth)
	print("DEBUG: Firebase auth save result: " + str(save_result))
	
	# For web builds, set Firebase persistence to LOCAL to match standalone behavior
	if OS.has_feature('web'):
		JavaScriptBridge.eval("""
			(function() {
				try {
					if (window.firebase && window.firebase.auth) {
						// Set persistence to LOCAL so auth survives browser restarts (like standalone)
						window.firebase.auth().setPersistence(window.firebase.auth.Auth.Persistence.LOCAL)
							.then(function() {
								console.log('Firebase auth persistence set to LOCAL for web build');
							})
							.catch(function(error) {
								console.error('Error setting Firebase persistence:', error);
							});
					}
				} catch(e) {
					console.error('Error configuring Firebase persistence:', e);
				}
			})();
		""")
	
	# For new users, create a default user document in Firestore
	var collection = Firebase.Firestore.collection("dyslexia_users")
	var user_id = auth.localid
	
	# Check if user document already exists
	var existing_doc = await collection.get_doc(user_id)
	if existing_doc == null or (existing_doc.has_method("keys") and "error" in existing_doc.keys()):
		# User document doesn't exist, create a new one
		print("DEBUG: Creating new user document for: " + user_id)
		_create_user_document(collection, user_id, auth)
	else:
		print("DEBUG: User document already exists, skipping creation")
	
	# Navigate to main menu
	navigate_to_main_menu()

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
		call_deferred("_fade_out_and_change_scene", "res://Scenes/MainMenu.tscn")
	else:
		# For regular login, add a slight delay for UX
		await get_tree().create_timer(0.5).timeout
		# Check if still in tree before changing scene
		if is_inside_tree():
			_fade_out_and_change_scene("res://Scenes/MainMenu.tscn")
		else:
			call_deferred("_fade_out_and_change_scene", "res://Scenes/MainMenu.tscn")

# Helper function to fade out before changing scenes
func _fade_out_and_change_scene(scene_path: String):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

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
	
	# Save auth
	Firebase.Auth.save_auth(auth)
	
	# Create user document for new registrations
	var collection = Firebase.Firestore.collection("dyslexia_users")
	var user_id = auth.localid
	print("DEBUG: Creating user document for new registration: " + user_id)
	_create_user_document(collection, user_id, auth)
	
	# Show success message and redirect
	show_message("Registration Successful! Redirecting...", true)
	
	# Change scene after a short delay
	await get_tree().create_timer(0.5).timeout
	_fade_out_and_change_scene("res://Scenes/MainMenu.tscn")

# Create user document in Firestore for new users
func _create_user_document(collection, user_id: String, auth):
	# Use stored registration data if available (for email registration), otherwise use auth data (for Google)
	var display_name = ""
	var email = ""
	var birth_date = ""
	var age = 0
	
	if registration_username != "" and registration_email != "":
		# Use stored registration data for email registration
		display_name = registration_username
		email = registration_email
		birth_date = registration_birth_date
		age = registration_age
		print("DEBUG: Using stored registration data - username: " + display_name)
	else:
		# Use auth data for Google sign-in
		display_name = auth.get("displayname", "Player")
		email = auth.get("email", "")
		print("DEBUG: Using auth data - username: " + display_name)
	
	var current_time = Time.get_datetime_string_from_system(false, true)
	
	var user_doc = {
		"profile": {
			"username": display_name,
			"email": email,
			"birth_date": birth_date,
			"age": age,
			"profile_picture": "default",
			"rank": "bronze",
			"created_at": current_time,
			"usage_time": 0,
			"session": 1,
			"last_session_date": Time.get_date_string_from_system()
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
				"current_dungeon": 1
			}
		},
		"modules": {
			"phonics": {
				"completed": false,
				"progress": 0
			},
			"flip_quiz": {
				"completed": false,
				"progress": 0
			},
			"read_aloud": {
				"completed": false,
				"progress": 0
			},
			"chunked_reading": {
				"completed": false,
				"progress": 0
			},
			"syllable_building": {
				"completed": false,
				"progress": 0
			}
		},
		"stage_times": {
			"dungeon_1": {},
			"dungeon_2": {},
			"dungeon_3": {}
		}
	}
	
	# Create the document using add method (which creates if not exists)
	var task = await collection.add(user_id, user_doc)
	if task:
		print("DEBUG: User document creation task initiated")
	else:
		print("ERROR: Failed to create user document task")
	
	# Clear stored registration data after use
	registration_username = ""
	registration_email = ""
	registration_birth_date = ""
	registration_age = 0

# Add these missing functions
func on_login_failed(error_code, message):
	print("DEBUG: Login failed: ", error_code, " - ", message)
	
	# Provide user-friendly error messages
	var user_message = ""
	
	# Common Firebase error codes
	match error_code:
		"auth/user-not-found":
			user_message = "Account does not exist."
		"auth/wrong-password":
			user_message = "Incorrect password."
		"auth/invalid-email":
			user_message = "Invalid email address."
		"auth/user-disabled":
			user_message = "This account has been disabled."
		"auth/too-many-requests":
			user_message = "Too many failed login attempts."
		"auth/invalid-credential":
			user_message = "Invalid email or password."
		"INVALID_LOGIN_CREDENTIALS":
			user_message = "Invalid email or password."
		_:
			# Handle specific technical messages that might appear
			if message.contains("INVALID_LOGIN_CREDENTIALS") or message.contains("invalid-credential"):
				user_message = "Invalid email or password. Please check and try again."
			elif message.contains("USER_NOT_FOUND") or message.contains("user-not-found"):
				user_message = "Account does not exist."
			elif message.contains("WEAK_PASSWORD") or message.contains("weak-password"):
				user_message = "Please use at least 6 characters."
			elif message.contains("network") or message.contains("connection"):
				user_message = "Connection problem."
			elif message.contains("database") or message.contains("firestore"):
				user_message = "Service temporarily unavailable."
			else:
				# Last resort - still make it friendly
				user_message = "Sign-in failed. Please check your email and password."
	
	# Show the error message
	show_message(user_message, false)
	
	# If this was a Google auth failure, show more helpful message
	if message.contains("TOKEN_EXPIRED") or message.contains("INVALID_IDP_RESPONSE"):
		show_message("Google login failed. Please try again or use email login.", false)
	
func on_signup_failed(error_code, message):
	print("Signup failed: ", error_code, " - ", message)
	
	# Provide user-friendly error messages for registration
	var user_message = ""
	
	# Common Firebase registration error codes
	match error_code:
		"auth/email-already-in-use":
			user_message = "This email is already registered. Please try logging in instead."
		"auth/invalid-email":
			user_message = "Please enter a valid email address."
		"auth/weak-password":
			user_message = "Password is too weak. Please use at least 6 characters."
		"auth/operation-not-allowed":
			user_message = "Registration is currently disabled. Please contact support."
		"auth/too-many-requests":
			user_message = "Too many registration attempts. Please try again later."
		_:
			# Handle specific technical messages that might appear
			if message.contains("email-already-in-use") or message.contains("EMAIL_EXISTS"):
				user_message = "This email is already registered. Please try logging in instead."
			elif message.contains("weak-password") or message.contains("WEAK_PASSWORD"):
				user_message = "Password is too weak. Please use at least 6 characters."
			elif message.contains("invalid-email") or message.contains("INVALID_EMAIL"):
				user_message = "Please enter a valid email address."
			elif message.contains("network") or message.contains("connection"):
				user_message = "Connection problem. Please check your internet and try again."
			elif message.contains("database") or message.contains("firestore"):
				user_message = "Service temporarily unavailable. Please try again in a moment."
			else:
				# Last resort - still make it friendly
				user_message = "Registration failed. Please check your information and try again."
	
	show_message(user_message, false)

# Helper function to get auth headers for requests
func _get_auth_headers():
	var headers = []
	if Firebase.Auth.auth != null and Firebase.Auth.auth.has("idtoken"):
		headers.append("Authorization: Bearer " + Firebase.Auth.auth.idtoken)
	return headers

# Logout function that clears persistent auto-login
func logout_user():
	print("DEBUG: Logging out user and clearing persistent data")
	
	# Clear the status message first to prevent confusion
	show_message("Signing out...", true)
	
	# Clear Firebase auth
	Firebase.Auth.logout()
	
	# For web builds, use Firebase's built-in logout
	if OS.has_feature('web'):
		JavaScriptBridge.eval("""
			// Clear any custom storage we may have used
			localStorage.removeItem('google_auth_started');
			sessionStorage.removeItem('processing_signin');
			sessionStorage.removeItem('google_auth_in_progress');
		""")
		JavaScriptBridge.eval("""
			// Clear all authentication-related localStorage and sessionStorage data
			localStorage.removeItem('last_successful_auth');
			localStorage.removeItem('firebase_user_id');
			localStorage.removeItem('firebase_id_token');
			localStorage.removeItem('firebase_user_email');
			localStorage.removeItem('firebase_current_user_id');
			localStorage.removeItem('firebase_current_user_email');
			localStorage.removeItem('google_oauth_user_confirmed');
			localStorage.removeItem('google_provider_confirmed');
			localStorage.removeItem('firebase_auth_method');
			
			// Clear session storage as well
			sessionStorage.removeItem('processing_signin');
			sessionStorage.removeItem('google_auth_in_progress');
			sessionStorage.removeItem('google_auth_started');
			
			// Clear any Firebase auth storage patterns
			for (var i = localStorage.length - 1; i >= 0; i--) {
				var key = localStorage.key(i);
				if (key && (key.includes('firebase:auth') || key.includes('google_'))) {
					localStorage.removeItem(key);
				}
			}
			
			// Clear any Firebase auth session storage patterns
			for (var i = sessionStorage.length - 1; i >= 0; i--) {
				var key = sessionStorage.key(i);
				if (key && (key.includes('firebase:auth') || key.includes('google_') || key.includes('processing_'))) {
					sessionStorage.removeItem(key);
				}
			}
			
			console.log('All auth storage cleared for logout');
		""")
		
		# Sign out from Firebase as well
		JavaScriptBridge.eval("""
			(function() {
				try {
					if (window.firebase && window.firebase.auth) {
						window.firebase.auth().signOut().then(function() {
							console.log('Firebase signOut completed');
						}).catch(function(error) {
							console.error('Error during Firebase signOut: ' + error.message);
						});
					}
				} catch(e) {
					console.error('Error calling Firebase signOut: ' + e.message);
				}
			})();
		""")
		
		print("DEBUG: Cleared all persistent auth data and signed out from Firebase")
	
	# Clear the status message before returning to auth scene
	show_message("Signed out successfully", true)
	
	# Wait a moment to show the success message
	await get_tree().create_timer(0.5).timeout
	
	# Return to authentication scene
	_fade_out_and_change_scene("res://Scenes/Authentication.tscn")

# Add this function to clear web storage if issues are detected
func clear_web_storage():
	if OS.has_feature('web'):
		var js_code = """
		(function() {
			try {
				// Clear specific Firebase auth keys to avoid clearing everything
				for (var i = localStorage.length - 1; i >= 0; i--) {
					var key = localStorage.key(i);
					if (key && (key.includes('firebase:auth') || key.includes('processing_signin') || key.includes('google_auth'))) {
						localStorage.removeItem(key);
					}
				}
				
				console.log('Web storage cleared completely');
				return true;
			} catch(e) {
				console.error('Error clearing web storage: ' + e.message);
				return false;
			}
		})();
		"""
		return JavaScriptBridge.eval(js_code)
	return false

# Helper function to clear Google auth data specifically
func clear_google_auth_data():
	print("DEBUG: Clearing Google auth data")
	if OS.has_feature('web'):
		var js_code = """
		(function() {
			try {
				// Clear Google-specific auth data
				localStorage.removeItem('google_oauth_user_confirmed');
				localStorage.removeItem('last_successful_auth');
				localStorage.setItem('auto_login_enabled', 'false');
				localStorage.removeItem('firebase_auth_method');
				localStorage.removeItem('google_provider_confirmed');
				localStorage.removeItem('firebase_current_user_id');
				localStorage.removeItem('firebase_current_user_email');
				localStorage.removeItem('firebase_user_id');
				localStorage.removeItem('firebase_id_token');
				localStorage.removeItem('firebase_user_email');
				
				// Clear session storage for Google auth
				sessionStorage.removeItem('processing_signin');
				sessionStorage.removeItem('google_auth_in_progress');
				sessionStorage.removeItem('google_auth_started');
				
				// Clear Firebase auth data for Google users
				for (var i = localStorage.length - 1; i >= 0; i--) {
					var key = localStorage.key(i);
					if (key && (key.includes('firebase:authUser') || key.includes('google_'))) {
						localStorage.removeItem(key);
					}
				}
				
				// Clear any remaining session storage auth patterns
				for (var i = sessionStorage.length - 1; i >= 0; i--) {
					var key = sessionStorage.key(i);
					if (key && (key.includes('firebase:auth') || key.includes('google_') || key.includes('processing_'))) {
						sessionStorage.removeItem(key);
					}
				}
				
				// Sign out from Firebase to ensure clean state
				if (window.firebase && window.firebase.auth) {
					window.firebase.auth().signOut().then(function() {
						console.log('Firebase signOut completed during Google auth clear');
					}).catch(function(error) {
						console.error('Error during Firebase signOut in clear: ' + error.message);
					});
				}
				
				console.log('Google auth data cleared completely');
				return true;
			} catch(e) {
				console.error('Error clearing Google auth data: ' + e.message);
				return false;
			}
		})();
		"""
		return JavaScriptBridge.eval(js_code)
	return false # Function to handle Super Admin button press
func _on_admin_button_pressed():
	$ButtonClick.play()
	print("DEBUG: Super Admin button pressed")
	var admin_url = "https://admin-teamlexia.web.app/login"
	
	if OS.has_feature('web'):
		# Open in new tab for web builds
		JavaScriptBridge.eval("window.open('" + admin_url + "', '_blank');")
	else:
		# Open with system default browser for desktop builds
		OS.shell_open(admin_url)

# Function to properly wait for Firebase auth restoration using Firebase's own mechanisms
func _wait_for_firebase_auth_restoration() -> bool:
	print("DEBUG: Starting Firebase auth restoration wait")
	
	# Wait for Firebase to be properly loaded with multiple attempts
	var firebase_ready = false
	var max_firebase_wait = 10.0 # Wait up to 10 seconds for Firebase
	var firebase_wait_time = 0.0
	var firebase_check_interval = 0.5
	
	while firebase_wait_time < max_firebase_wait and not firebase_ready:
		await get_tree().create_timer(firebase_check_interval).timeout
		firebase_wait_time += firebase_check_interval
		
		firebase_ready = JavaScriptBridge.eval("""
			(function() {
				try {
					return !!(window.firebase && window.firebase.auth && typeof window.firebase.auth === 'function');
				} catch(e) {
					return false;
				}
			})();
		""")
		
		if firebase_ready:
			print("DEBUG: Firebase is ready after " + str(firebase_wait_time) + " seconds")
			break
		else:
			print("DEBUG: Still waiting for Firebase... (" + str(firebase_wait_time) + "s)")
	
	if not firebase_ready:
		print("DEBUG: Firebase failed to load after " + str(max_firebase_wait) + " seconds")
		return false
	
	# Use Firebase's own auth state restoration mechanism with a Promise-based approach
	JavaScriptBridge.eval("""
		(function() {
			console.log('Starting Firebase auth restoration check...');
			
			if (!window.firebase || !window.firebase.auth) {
				console.log('Firebase not available during restoration');
				window.authRestorationResult = false;
				return;
			}
			
			var auth = window.firebase.auth();
			var timeoutId;
			var resolved = false;
			
			function resolveAuth(result) {
				if (!resolved) {
					resolved = true;
					clearTimeout(timeoutId);
					window.authRestorationResult = result;
					console.log('Auth restoration resolved with:', result);
				}
			}
			
			// Set a timeout to prevent hanging forever
			timeoutId = setTimeout(function() {
				console.log('Firebase auth restoration timed out');
				resolveAuth(false);
			}, 6000); // Reduced timeout to 6 seconds
			
			// First check if we already have a current user
			var currentUser = auth.currentUser;
			if (currentUser) {
				console.log('Current user already available:', currentUser.uid);
				
				// Verify this is a Google user if we expect it to be
				var isGoogleUser = false;
				if (currentUser.providerData && currentUser.providerData.length > 0) {
					for (var i = 0; i < currentUser.providerData.length; i++) {
						if (currentUser.providerData[i].providerId === 'google.com') {
							isGoogleUser = true;
							break;
						}
					}
				}
				
				// If we expect Google auth, verify it
				var expectedGoogle = localStorage.getItem('firebase_auth_method') === 'google';
				if (expectedGoogle && !isGoogleUser) {
					console.log('Expected Google user but provider mismatch');
					resolveAuth(false);
				} else {
					// Update storage with confirmed auth
					localStorage.setItem('firebase_current_user_id', currentUser.uid);
					localStorage.setItem('firebase_current_user_email', currentUser.email || '');
					if (isGoogleUser) {
						localStorage.setItem('google_oauth_user_confirmed', currentUser.uid);
						localStorage.setItem('last_successful_auth', 'google');
					}
					resolveAuth(true);
				}
				return;
			}
			
			console.log('No current user found immediately, waiting for auth state change...');
			
			// Use Firebase's auth state observer to detect restoration
			var unsubscribe = auth.onAuthStateChanged(function(user) {
				if (!resolved) {
					unsubscribe(); // Clean up the observer
					
					if (user) {
						console.log('Firebase auth restored via state change for user:', user.uid);
						
						// Verify this is a Google user if we expect it to be
						var isGoogleUser = false;
						if (user.providerData && user.providerData.length > 0) {
							for (var i = 0; i < user.providerData.length; i++) {
								if (user.providerData[i].providerId === 'google.com') {
									isGoogleUser = true;
									break;
								}
							}
						}
						
						// If we expect Google auth, verify it
						var expectedGoogle = localStorage.getItem('firebase_auth_method') === 'google';
						if (expectedGoogle && !isGoogleUser) {
							console.log('Expected Google user but provider mismatch');
							resolveAuth(false);
						} else {
							// Update storage with confirmed auth
							localStorage.setItem('firebase_current_user_id', user.uid);
							localStorage.setItem('firebase_current_user_email', user.email || '');
							if (isGoogleUser) {
								localStorage.setItem('google_oauth_user_confirmed', user.uid);
								localStorage.setItem('last_successful_auth', 'google');
							}
							resolveAuth(true);
						}
					} else {
						console.log('No authenticated user found during restoration');
						resolveAuth(false);
					}
				}
			});
			
			// Also check for auth restoration after a brief delay
			setTimeout(function() {
				if (!resolved) {
					var delayedUser = auth.currentUser;
					if (delayedUser) {
						unsubscribe();
						console.log('Found current user after delay:', delayedUser.uid);
						
						// Same verification logic as above
						var isGoogleUser = false;
						if (delayedUser.providerData && delayedUser.providerData.length > 0) {
							for (var i = 0; i < delayedUser.providerData.length; i++) {
								if (delayedUser.providerData[i].providerId === 'google.com') {
									isGoogleUser = true;
									break;
								}
							}
						}
						
						var expectedGoogle = localStorage.getItem('firebase_auth_method') === 'google';
						if (expectedGoogle && !isGoogleUser) {
							console.log('Expected Google user but provider mismatch (delayed check)');
							resolveAuth(false);
						} else {
							localStorage.setItem('firebase_current_user_id', delayedUser.uid);
							localStorage.setItem('firebase_current_user_email', delayedUser.email || '');
							if (isGoogleUser) {
								localStorage.setItem('google_oauth_user_confirmed', delayedUser.uid);
								localStorage.setItem('last_successful_auth', 'google');
							}
							resolveAuth(true);
						}
					} else {
						console.log('Still no user found after delay');
					}
				}
			}, 1000); // Check again after 1 second
		})();
	""")
	
	# Wait for the JavaScript to resolve with polling
	var max_wait_time = 8.0 # Maximum 8 seconds total
	var poll_interval = 0.2 # Check every 200ms (less frequent)
	var waited_time = 0.0
	
	while waited_time < max_wait_time:
		await get_tree().create_timer(poll_interval).timeout
		waited_time += poll_interval
		
		# Check if the result has been set
		var result = JavaScriptBridge.eval("""
			(function() {
				// This will be true/false if resolved, or undefined if still pending
				if (window.authRestorationResult !== undefined) {
					var result = window.authRestorationResult;
					delete window.authRestorationResult; // Clean up
					return result;
				}
				return null;
			})();
		""")
		
		if result != null:
			print("DEBUG: Firebase auth restoration completed with result: " + str(result))
			return result
	
	print("DEBUG: Firebase auth restoration timed out after " + str(max_wait_time) + " seconds")
	# Clean up in case of timeout
	JavaScriptBridge.eval("delete window.authRestorationResult;")
	return false

func _on_tab_container_tab_clicked(tab: int) -> void:
	$ButtonClick.play()


func _on_tab_container_tab_hovered(tab: int) -> void:
	$ButtonHover.play()


func _on_show_password_button_mouse_entered() -> void:
	$ButtonHover.play()

func _on_show_reg_password_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_forgot_password_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_sign_in_google_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_admin_button_mouse_entered() -> void:
	$ButtonHover.play()

func _on_day_option_button_pressed() -> void:
	$ButtonClick.play()


func _on_day_option_button_mouse_entered() -> void:
	$ButtonHover.play()

func _on_month_option_button_pressed() -> void:
	$ButtonClick.play()

func _on_month_option_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_year_option_button_pressed() -> void:
	$ButtonClick.play()


func _on_year_option_button_mouse_entered() -> void:
	$ButtonHover.play()

func _on_show_confirm_password_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_back_to_login_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_register_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_login_button_mouse_entered() -> void:
	$ButtonHover.play()