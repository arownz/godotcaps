extends CanvasLayer

# Signals
signal terms_accepted

# Called when the node enters the scene tree
func _ready():
	# Make background block all clicks
	$Background.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Fade in animation - matching ProfilePopUp pattern
	var bg = get_node_or_null("Background")
	var popup = get_node_or_null("PopupContainer")
	
	if bg:
		bg.modulate.a = 0.0
	if popup:
		popup.modulate.a = 0.0
		popup.scale = Vector2(0.8, 0.8)
		var tween = create_tween()
		tween.set_parallel(true)
		# Fade in background
		if bg:
			tween.tween_property(bg, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
		# Fade in and scale popup
		tween.tween_property(popup, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
		tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

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
	
	# Fade out animation before closing
	await _fade_out_and_close()

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


# Helper function to fade out before closing - matching ProfilePopUp pattern
func _fade_out_and_close():
	var bg = get_node_or_null("Background")
	var popup = get_node_or_null("PopupContainer")
	var tween = create_tween()
	tween.set_parallel(true)
	# Fade out background
	if bg:
		tween.tween_property(bg, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	# Fade out and scale popup
	if popup:
		tween.tween_property(popup, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
		tween.tween_property(popup, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()

func _on_agree_button_mouse_entered():
	$ButtonHover.play()
