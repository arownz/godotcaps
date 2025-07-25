class_name GoogleProvider
extends AuthProvider

func _init(client_id: String, client_secret: String):
	set_client_id(client_id)
	set_client_secret(client_secret)
	
	# Different settings for web vs desktop to ensure proper OAuth flow
	if Utilities.is_web():
		# Web builds should use implicit flow (no token exchange)
		self.should_exchange = false
		self.redirect_uri = "https://accounts.google.com/o/oauth2/v2/auth?"
		self.access_token_uri = "https://oauth2.googleapis.com/token"
		self.provider_id = "google.com"
		self.params.response_type = "token"  # Implicit flow for web
		self.params.scope = "email openid profile"
		# Force account selection even if only one account exists
		self.params.prompt = "select_account"
		# Ensure same-tab behavior (no new window/tab)
		self.params.include_granted_scopes = "true"
	else:
		# Desktop builds use authorization code flow (with token exchange)
		self.should_exchange = true
		self.redirect_uri = "https://accounts.google.com/o/oauth2/v2/auth?"
		self.access_token_uri = "https://oauth2.googleapis.com/token"
		self.provider_id = "google.com"
		self.params.response_type = "code"  # Authorization code flow for desktop
		self.params.scope = "email openid profile"
