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
	$RightPanel/MainContainer/VBoxContainer/TabContainer.tab_changed.connect(_on_tab_container_tab_changed)
	
	# Hide the ForgotPassword tab
	_hide_forgot_password_tab()
	
	# Initialize date picker dropdown
	_initialize_date_pickers()
	
	# Make layout responsive
	get_tree().root.size_changed.connect(_adjust_layout_for_screen_size)
	_adjust_layout_for_screen_size()
	
	if Firebase.Auth.check_auth_file():
		NotificationManager.show_notification("Authentication", "You are already logged in")
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	elif OS.get_name() == "web":
		var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
		Firebase.Auth.set_redirect_uri("http://localhost:8060/")
		var token = Firebase.Auth.get_token_from_url(provider)
		if token:
			Firebase.Auth.login_with_oauth(token, provider)

# Function to hide the ForgotPassword tab in the TabContainer
func _hide_forgot_password_tab():
	var tab_container = $RightPanel/MainContainer/VBoxContainer/TabContainer
	var tabs_count = tab_container.get_tab_count()
	
	# Find and hide the ForgotPassword tab
	for i in range(tabs_count):
		if tab_container.get_tab_title(i) == "ForgotPassword":
			tab_container.set_tab_hidden(i, true)
			break

# Track tab changes to handle UI updates
func _on_tab_container_tab_changed(tab):
	clear_all_error_labels()

func _initialize_date_pickers():
	# Days
	var day_option = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/DayOptionButton
	for day in range(1, 32):
		day_option.add_item(str(day))
	
	# Months
	var month_option = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/MonthOptionButton
	var months = ["January", "February", "March", "April", "May", "June",
				 "July", "August", "September", "October", "November", "December"]
	for i in range(months.size()):
		month_option.add_item(months[i])
	
	# Years - Show last 100 years
	var year_option = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/YearOptionButton
	var current_year = Time.get_date_dict_from_system()["year"]
	for year in range(current_year, current_year - 100, -1):
		year_option.add_item(str(year))

func _adjust_layout_for_screen_size():
	# Get the viewport size
	var viewport_size = get_viewport_rect().size
	
	# Adjust the layout based on screen size
	if viewport_size.x < 1200:
		# If screen is narrow, hide left panel and expand right panel
		$LeftPanel.visible = false
		$RightPanel.anchor_left = 0.0
		$RightPanel.offset_left = 0
		
		# Center the container
		$RightPanel/MainContainer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		$RightPanel/MainContainer.anchors_preset = Control.PRESET_CENTER
	else:
		# For wider screens, show the split layout
		$LeftPanel.visible = true
		$RightPanel.anchor_left = 0.4
		$RightPanel.offset_left = 0
	
	# Make sure the panel fits within the viewport height
	if viewport_size.y < 700:
		$RightPanel/MainContainer.custom_minimum_size.y = viewport_size.y * 0.8
	else:
		$RightPanel/MainContainer.custom_minimum_size.y = 0

# ===== Password Visibility Functions =====
func _on_show_password_button_pressed():
	login_password_visible = !login_password_visible
	var password_field = $RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordContainer/PasswordLineEdit
	var button = $RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordContainer/ShowPasswordButton
	
	password_field.secret = !login_password_visible
	button.text = "Hide" if login_password_visible else "Show"

func _on_show_reg_password_button_pressed():
	reg_password_visible = !reg_password_visible
	var password_field = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordContainer/RegPasswordLineEdit
	var button = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordContainer/ShowRegPasswordButton
	
	password_field.secret = !reg_password_visible
	button.text = "Hide" if reg_password_visible else "Show"

func _on_show_confirm_password_button_pressed():
	confirm_password_visible = !confirm_password_visible
	var password_field = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/ConfirmPasswordContainer/ConfirmPasswordLineEdit
	var button = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/ConfirmPasswordContainer/ShowConfirmPasswordButton
	
	password_field.secret = !confirm_password_visible
	button.text = "Hide" if confirm_password_visible else "Show"

# ===== Input Validation =====
func _on_login_email_text_changed(new_text):
	# Hide error label when user starts typing
	$RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailErrorLabel.visible = false

func _on_login_password_text_changed(new_text):
	# Hide error label when user starts typing
	$RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordErrorLabel.visible = false

func clear_all_error_labels():
	# Login tab
	$RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailErrorLabel.visible = false
	$RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordErrorLabel.visible = false
	
	# Register tab
	$RightPanel/MainContainer/VBoxContainer/TabContainer/Register/UsernameErrorLabel.visible = false
	$RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateErrorLabel.visible = false
	$RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegEmailErrorLabel.visible = false
	$RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordErrorLabel.visible = false
	$RightPanel/MainContainer/VBoxContainer/TabContainer/Register/ConfirmPasswordErrorLabel.visible = false
	
	# Forgot password tab
	$RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailErrorLabel.visible = false

# ===== Login Functions =====
func _on_login_button_pressed():
	var email = $RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailLineEdit.text
	var password = $RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordContainer/PasswordLineEdit.text
	var has_error = false
	
	# Validate email
	if email.strip_edges().is_empty() or not "@" in email or not "." in email:
		$RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailErrorLabel.visible = true
		has_error = true
	
	# Validate password
	if password.strip_edges().is_empty():
		$RightPanel/MainContainer/VBoxContainer/TabContainer/Login/PasswordErrorLabel.visible = true
		has_error = true
	
	if has_error:
		return
	
	# Proceed with login
	$RightPanel/MainContainer/VBoxContainer/NotificationLabel.text = "Signing in..."
	Firebase.Auth.login_with_email_and_password(email, password)

# ===== Registration Functions =====
func _on_register_button_pressed():
	var username = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/UsernameLineEdit.text
	var email = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegEmailLineEdit.text
	var password = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordContainer/RegPasswordLineEdit.text
	var confirm_password = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/ConfirmPasswordContainer/ConfirmPasswordLineEdit.text
	var has_error = false
	
	# Validate username
	if username.strip_edges().is_empty():
		$RightPanel/MainContainer/VBoxContainer/TabContainer/Register/UsernameErrorLabel.visible = true
		has_error = true
	
	# Validate birthdate
	var day_option = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/DayOptionButton
	var month_option = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/MonthOptionButton
	var year_option = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/YearOptionButton
	
	if day_option.selected == -1 or month_option.selected == -1 or year_option.selected == -1:
		$RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateErrorLabel.visible = true
		has_error = true
	
	# Validate email
	if email.strip_edges().is_empty() or not "@" in email or not "." in email:
		$RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegEmailErrorLabel.visible = true
		has_error = true
	
	# Validate password
	if password.strip_edges().is_empty() or password.length() < 6:
		$RightPanel/MainContainer/VBoxContainer/TabContainer/Register/RegPasswordErrorLabel.visible = true
		has_error = true
	
	# Validate confirm password
	if password != confirm_password:
		$RightPanel/MainContainer/VBoxContainer/TabContainer/Register/ConfirmPasswordErrorLabel.visible = true
		has_error = true
	
	if has_error:
		return
	
	# Create user with email and password
	$RightPanel/MainContainer/VBoxContainer/NotificationLabel.text = "Creating account..."
	Firebase.Auth.signup_with_email_and_password(email, password)

# ===== Google Sign-In =====
func _on_sign_in_google_button_pressed():
	var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
	
	$RightPanel/MainContainer/VBoxContainer/NotificationLabel.text = "Redirecting to Google..."
	
	if OS.get_name() == "web":
		# For web
		Firebase.Auth.set_redirect_uri("http://localhost:8060/")
		Firebase.Auth.get_auth_with_redirect(provider)
	else:
		# For desktop
		Firebase.Auth.get_auth_localhost(provider, 8060)

# ===== Forgot Password Functions =====
func _on_forgot_password_button_pressed():
	# Switch to the forgot password tab
	$RightPanel/MainContainer/VBoxContainer/TabContainer.current_tab = 2
	$RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailLineEdit.grab_focus()
	
	# Copy email address from login tab if available
	var login_email = $RightPanel/MainContainer/VBoxContainer/TabContainer/Login/EmailLineEdit.text
	if not login_email.strip_edges().is_empty():
		$RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailLineEdit.text = login_email

func _on_back_to_login_button_pressed():
	# Switch back to login tab
	$RightPanel/MainContainer/VBoxContainer/TabContainer.current_tab = 0

func _on_reset_password_button_pressed():
	var email = $RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailLineEdit.text
	
	# Validate email
	if email.strip_edges().is_empty() or not "@" in email or not "." in email:
		$RightPanel/MainContainer/VBoxContainer/TabContainer/ForgotPassword/ResetEmailErrorLabel.visible = true
		return
	
	# Send password reset email
	Firebase.Auth.send_password_reset_email(email)
	
	# Show success notification
	NotificationManager.show_notification("Password Reset", "A password reset link has been sent to your email address. Please check your inbox.")
	
	# Switch back to login tab
	$RightPanel/MainContainer/VBoxContainer/TabContainer.current_tab = 0

# ===== Firebase Authentication Callbacks =====
func on_login_succeeded(auth):
	print(auth)
	Firebase.Auth.save_auth(auth)
	
	NotificationManager.show_notification("Login Successful", "Welcome back to Lexia!", 1.0)
	
	# Change scene after notification is displayed
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	
func on_signup_succeeded(auth):
	print(auth)
	
	# Get user data from registration form
	var username = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/UsernameLineEdit.text
	
	# Get birthdate components
	var day_option = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/DayOptionButton
	var month_option = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/MonthOptionButton
	var year_option = $RightPanel/MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/YearOptionButton
	
	var birth_date = ""
	if day_option.selected > -1 and month_option.selected > -1 and year_option.selected > -1:
		birth_date = "%s-%s-%s" % [year_option.get_item_text(year_option.selected),
								month_option.selected + 1,
								day_option.get_item_text(day_option.selected)]
	
	# Store user data in Firestore
	var user_doc = {"username": username, "birth_date": birth_date, "created_at": Time.get_unix_time_from_system()}
	Firebase.Firestore.collection("users").document(auth.localid).set(user_doc)
	
	Firebase.Auth.save_auth(auth)
	
	NotificationManager.show_notification("Registration Successful", "Your account has been created! Welcome to Lexia!", 1.0)
	
	# Change scene after notification is displayed
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	
func on_login_failed(error_code, message):
	print(error_code)
	print(message)
	$RightPanel/MainContainer/VBoxContainer/NotificationLabel.text = ""
	
	# Show error notification
	NotificationManager.show_notification("Login Failed", "Error: " + message)
	
func on_signup_failed(error_code, message):
	print(error_code)
	print(message)
	$RightPanel/MainContainer/VBoxContainer/NotificationLabel.text = ""
	
	# Show error notification
	NotificationManager.show_notification("Registration Failed", "Error: " + message)
