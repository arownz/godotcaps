class_name GoogleProvider
extends AuthProvider

func _init(client_id: String,client_secret: String):
	set_client_id(client_id)
	set_client_secret(client_secret)
	
	# Use different settings for web versus desktop
	if Utilities.is_web():
		self.should_exchange = false
		self.redirect_uri = "https://accounts.google.com/o/oauth2/v2/auth?"
		self.access_token_uri = "https://oauth2.googleapis.com/token"
		self.provider_id = "google.com"
		self.params.response_type = "token"  # Use token for web implicit flow
		self.params.scope = "email profile openid"
	else:
		self.should_exchange = true
		self.redirect_uri = "https://accounts.google.com/o/oauth2/v2/auth?"
		self.access_token_uri = "https://oauth2.googleapis.com/token"
		self.provider_id = "google.com"
		self.params.response_type = "code"
		self.params.scope = "email openid profile"
