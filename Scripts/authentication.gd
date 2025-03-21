extends Control

# Called when the node enters the scene tree for the first time.
func _ready():
	Firebase.Auth.login_succeeded.connect(on_login_succeeded)
	Firebase.Auth.signup_succeeded.connect(on_signup_succeeded)
	Firebase.Auth.login_failed.connect(on_login_failed)
	Firebase.Auth.signup_failed.connect(on_signup_failed)
	
	if Firebase.Auth.check_auth_file():
		$VBoxContainer/StateLabel.text = "Logged in"
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	elif OS.get_name() == "web":
		var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
		Firebase.Auth.set_redirect_uri("http://localhost:8060/")
		var token = Firebase.Auth.get_token_from_url(provider)
		if token:
			Firebase.Auth.login_with_oauth(token, provider)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _on_login_button_pressed():
	var email = $VBoxContainer/EmailLineEdit.text
	var password = $VBoxContainer/PasswordLineEdit.text
	Firebase.Auth.login_with_email_and_password(email, password)
	$VBoxContainer/StateLabel.text = "Logging in"

func _on_signup_button_pressed():
	var email = $VBoxContainer/EmailLineEdit.text
	var password = $VBoxContainer/PasswordLineEdit.text
	Firebase.Auth.signup_with_email_and_password(email, password)
	$VBoxContainer/StateLabel.text = "Registering"

func on_login_succeeded(auth):
	print(auth)
	$VBoxContainer/StateLabel.text = "Login success!"
	Firebase.Auth.save_auth(auth)
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	
func on_signup_succeeded(auth):
	print(auth)
	$VBoxContainer/StateLabel.text = "Registered success!"
	Firebase.Auth.save_auth(auth)
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	
func on_login_failed(error_code, message):
	print(error_code)
	print(message)
	$VBoxContainer/StateLabel.text = "Login failed. Error: %s" % message
	
func on_signup_failed(error_code, message):
	print(error_code)
	print(message)
	$VBoxContainer/StateLabel.text = "Registered failed. Error: %s" % message


func _on_sign_in_google_button_pressed():
	var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
	
	if OS.get_name() == "web":
		# For web
		Firebase.Auth.set_redirect_uri("http://localhost:8060/")
		Firebase.Auth.get_auth_with_redirect(provider)
	else:
		# For desktop
		Firebase.Auth.get_auth_localhost(provider, 8060)
