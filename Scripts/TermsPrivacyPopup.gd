extends CanvasLayer

# Signals
signal terms_accepted

# Called when the node enters the scene tree
func _ready():
	# Make background block all clicks
	$Background.mouse_filter = Control.MOUSE_FILTER_STOP

# Called when user clicks "I Agree"
func _on_agree_button_pressed():
	$ButtonClick.play()
	print("TermsPrivacyPopup: User accepted terms and privacy policy")
	
	# Play click sound if available in parent
	var parent = get_parent()
	if parent and parent.has_node("ButtonClick"):
		parent.get_node("ButtonClick").play()
	
	# Save acceptance to localStorage (web) or file (desktop)
	_save_acceptance()
	
	# Emit signal
	emit_signal("terms_accepted")
	
	# Remove this popup
	queue_free()

# Save acceptance to persistent storage
func _save_acceptance():
	if OS.has_feature('web'):
		# Save to localStorage for web builds
		JavaScriptBridge.eval("""
			(function() {
				try {
					localStorage.setItem('lexia_terms_accepted', 'true');
					console.log('Terms acceptance saved to localStorage');
				} catch(e) {
					console.error('Error saving terms acceptance:', e);
				}
			})();
		""")
	else:
		# Save to file for desktop builds
		var file = FileAccess.open("user://terms_accepted.dat", FileAccess.WRITE)
		if file:
			file.store_string("accepted")
			file.close()
			print("TermsPrivacyPopup: Terms acceptance saved to file")

# Check if terms have been accepted
static func has_accepted_terms() -> bool:
	if OS.has_feature('web'):
		# Check localStorage in web build
		var js_code = """
		(function() {
			try {
				var accepted = localStorage.getItem('lexia_terms_accepted');
				return accepted === 'true';
			} catch(e) {
				console.error('Error checking terms acceptance:', e);
				return false;
			}
		})();
		"""
		return JavaScriptBridge.eval(js_code)
	else:
		# For desktop, check file flag
		var file_path = "user://terms_accepted.dat"
		return FileAccess.file_exists(file_path)


func _on_agree_button_mouse_entered():
	$ButtonHover.play()
