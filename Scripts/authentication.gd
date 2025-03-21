extends Control

# Called when the node enters the scene tree for the first time.
func _ready():
    Firebase.Auth.login_succeeded.connect(on_login_succeeded)
    Firebase.Auth.signup_succeeded.connect(on_signup_succeeded)
    Firebase.Auth.login_failed.connect(on_login_failed)
    Firebase.Auth.signup_failed.connect(on_signup_failed)
    
    # Initialize date picker dropdown
    _initialize_date_pickers()
    
    if Firebase.Auth.check_auth_file():
        $MainContainer/VBoxContainer/StateLabel.text = "Logged in"
        get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
    elif OS.get_name() == "web":
        var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
        Firebase.Auth.set_redirect_uri("http://localhost:8060/")
        var token = Firebase.Auth.get_token_from_url(provider)
        if token:
            Firebase.Auth.login_with_oauth(token, provider)

func _initialize_date_pickers():
    # Days
    var day_option = $MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/DayOptionButton
    for day in range(1, 32):
        day_option.add_item(str(day))
    
    # Months
    var month_option = $MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/MonthOptionButton
    var months = ["January", "February", "March", "April", "May", "June", 
                 "July", "August", "September", "October", "November", "December"]
    for i in range(months.size()):
        month_option.add_item(months[i])
    
    # Years - Show last 100 years
    var year_option = $MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/YearOptionButton
    var current_year = Time.get_date_dict_from_system()["year"]
    for year in range(current_year, current_year - 100, -1):
        year_option.add_item(str(year))

func _on_tab_container_tab_changed(tab):
    var state_label = $MainContainer/VBoxContainer/StateLabel
    if tab == 0:  # Login tab
        state_label.text = "Welcome back to Lexia"
    else:  # Register tab
        state_label.text = "Create your Lexia account"
    
    # Clear any error messages when switching tabs
    if tab == 1:
        $MainContainer/VBoxContainer/TabContainer/Register/ErrorLabel.text = ""

func _on_login_button_pressed():
    var email = $MainContainer/VBoxContainer/TabContainer/Login/EmailLineEdit.text
    var password = $MainContainer/VBoxContainer/TabContainer/Login/PasswordLineEdit.text
    
    if email.strip_edges().is_empty() or password.strip_edges().is_empty():
        $MainContainer/VBoxContainer/StateLabel.text = "Please enter both email and password"
        return
    
    Firebase.Auth.login_with_email_and_password(email, password)
    $MainContainer/VBoxContainer/StateLabel.text = "Signing in..."

func _on_register_button_pressed():
    var username = $MainContainer/VBoxContainer/TabContainer/Register/UsernameLineEdit.text
    var email = $MainContainer/VBoxContainer/TabContainer/Register/RegEmailLineEdit.text
    var password = $MainContainer/VBoxContainer/TabContainer/Register/RegPasswordLineEdit.text
    var confirm_password = $MainContainer/VBoxContainer/TabContainer/Register/ConfirmPasswordLineEdit.text
    var error_label = $MainContainer/VBoxContainer/TabContainer/Register/ErrorLabel
    
    # Validate inputs
    if username.strip_edges().is_empty():
        error_label.text = "Please enter a username"
        return
    
    if email.strip_edges().is_empty():
        error_label.text = "Please enter an email address"
        return
        
    # Simple email validation
    if not "@" in email or not "." in email:
        error_label.text = "Please enter a valid email address"
        return
    
    if password.strip_edges().is_empty():
        error_label.text = "Please enter a password"
        return
        
    if password.length() < 6:
        error_label.text = "Password must be at least 6 characters"
        return
    
    if password != confirm_password:
        error_label.text = "Passwords do not match"
        return
    
    # Clear error message if all validations pass
    error_label.text = ""
    
    # Get birthdate data
    var day_option = $MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/DayOptionButton
    var month_option = $MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/MonthOptionButton
    var year_option = $MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/YearOptionButton
    
    # Store birth date and username in custom field for Firebase
    var birth_date = ""
    if day_option.selected > -1 and month_option.selected > -1 and year_option.selected > -1:
        birth_date = "%s-%s-%s" % [year_option.get_item_text(year_option.selected), 
                                month_option.selected + 1, 
                                day_option.get_item_text(day_option.selected)]
    
    # Create user with email and password
    Firebase.Auth.signup_with_email_and_password(email, password)
    $MainContainer/VBoxContainer/StateLabel.text = "Creating account..."

func _on_sign_in_google_button_pressed():
    var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
    
    if OS.get_name() == "web":
        # For web
        Firebase.Auth.set_redirect_uri("http://localhost:8060/")
        Firebase.Auth.get_auth_with_redirect(provider)
    else:
        # For desktop
        Firebase.Auth.get_auth_localhost(provider, 8060)

func _on_forgot_password_button_pressed():
    var email = $MainContainer/VBoxContainer/TabContainer/Login/EmailLineEdit.text
    
    if email.strip_edges().is_empty():
        $MainContainer/VBoxContainer/StateLabel.text = "Please enter your email address"
        return
    
    # Send password reset email
    Firebase.Auth.send_password_reset_email(email)
    $MainContainer/VBoxContainer/StateLabel.text = "Password reset email sent"

func on_login_succeeded(auth):
    print(auth)
    $MainContainer/VBoxContainer/StateLabel.text = "Login success!"
    Firebase.Auth.save_auth(auth)
    
    # Store additional user data in Firestore if needed
    # This would be a good place to store username and birthdate from registration
    
    get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
    
func on_signup_succeeded(auth):
    print(auth)
    $MainContainer/VBoxContainer/StateLabel.text = "Registration successful!"
    
    # Get username from registration form
    var username = $MainContainer/VBoxContainer/TabContainer/Register/UsernameLineEdit.text
    
    # Get birthdate components
    var day_option = $MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/DayOptionButton
    var month_option = $MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/MonthOptionButton
    var year_option = $MainContainer/VBoxContainer/TabContainer/Register/BirthDateContainer/YearOptionButton
    
    var birth_date = ""
    if day_option.selected > -1 and month_option.selected > -1 and year_option.selected > -1:
        birth_date = "%s-%s-%s" % [year_option.get_item_text(year_option.selected), 
                                month_option.selected + 1, 
                                day_option.get_item_text(day_option.selected)]
    
    # Here you would typically store the additional user data (username, birth_date)
    # in Firebase Firestore or Realtime Database linked to the user's UID
    # Example (if using Firestore):
    # var user_doc = {"username": username, "birth_date": birth_date}
    # Firebase.Firestore.collection("users").document(auth.localid).set(user_doc)
    
    Firebase.Auth.save_auth(auth)
    get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
    
func on_login_failed(error_code, message):
    print(error_code)
    print(message)
    $MainContainer/VBoxContainer/StateLabel.text = "Login failed: %s" % message
    
func on_signup_failed(error_code, message):
    print(error_code)
    print(message)
    var error_label = $MainContainer/VBoxContainer/TabContainer/Register/ErrorLabel
    error_label.text = "Registration failed: %s" % message
    $MainContainer/VBoxContainer/StateLabel.text = "Registration failed"
