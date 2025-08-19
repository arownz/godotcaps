extends CanvasLayer

signal try_again_pressed
signal next_item_pressed
signal closed

enum CompletionType {
	LETTER,
	SIGHT_WORD,
	CATEGORY_COMPLETE
}

var completion_type: CompletionType = CompletionType.LETTER
var completed_item: String = ""
var progress_data: Dictionary = {}

# Module theme colors
var module_colors = {
	"phonics": Color(0.2, 0.6, 0.2, 1), # Green for phonics
	"flip_quiz": Color(0.8, 0.4, 0.1, 1), # Orange for flip quiz
	"read_aloud": Color(0.1, 0.4, 0.8, 1), # Blue for read aloud
	"chunked_reading": Color(0.6, 0.2, 0.8, 1), # Purple for chunked reading
	"syllable_building": Color(0.8, 0.2, 0.4, 1), # Pink for syllable building
}

func _ready():
	# Hide popup by default
	hide()
	
	# Set up initial animation state
	var popup_container = $PopupContainer
	if popup_container:
		popup_container.modulate = Color(1, 1, 1, 0)
		popup_container.scale = Vector2(0.8, 0.8)

func show_completion(type: CompletionType, item: String, progress: Dictionary = {}, module_key: String = "phonics"):
	"""Show completion celebration with dyslexia-friendly design"""
	completion_type = type
	completed_item = item
	progress_data = progress
	
	# Update content based on completion type
	_update_content(module_key)
	
	# Show the popup
	show()
	
	# Play success sound safely
	_play_sound($SuccessSound, "success")
	
	# Animated entrance with celebration
	var popup_container = $PopupContainer
	if popup_container:
		popup_container.modulate = Color(1, 1, 1, 0)
		popup_container.scale = Vector2(0.5, 0.5)
		
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Fade in
		tween.tween_property(popup_container, "modulate", Color(1, 1, 1, 1), 0.4).set_ease(Tween.EASE_OUT)
		
		# Bouncy scale animation for celebration feel
		tween.tween_property(popup_container, "scale", Vector2(1.1, 1.1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(popup_container, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)
		
		# Add a little extra celebration bounce
		tween.tween_property(popup_container, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT).set_delay(0.5)
		tween.tween_property(popup_container, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN).set_delay(0.6)
	
	# Play celebration sound after a brief delay
	if $CelebrationSound and $CelebrationSound.stream:
		await get_tree().create_timer(0.3).timeout
		_play_sound($CelebrationSound, "celebration")

func _play_sound(player: Node, label: String):
	if player and player is AudioStreamPlayer and player.stream:
		player.play()
	else:
		print("CompletionCelebration: Missing/invalid " + label + " sound stream (skipping play)")

func _update_content(module_key: String = "phonics"):
	"""Update popup content based on completion type with dyslexia-friendly messaging"""
	var title_label = $PopupContainer/CenterContainer/PopupBackground/MainContainer/TitleLabel
	var message_label = $PopupContainer/CenterContainer/PopupBackground/MainContainer/MessageLabel
	var progress_label = $PopupContainer/CenterContainer/PopupBackground/MainContainer/ProgressContainer/ProgressLabel
	var progress_bar = $PopupContainer/CenterContainer/PopupBackground/MainContainer/ProgressContainer/ProgressBar
	var try_again_btn = $PopupContainer/CenterContainer/PopupBackground/MainContainer/ButtonContainer/TryAgainButton
	var next_btn = $PopupContainer/CenterContainer/PopupBackground/MainContainer/ButtonContainer/NextButton
	
	# Set progress bar color based on module theme
	if progress_bar and module_colors.has(module_key):
		var theme_color = module_colors[module_key]
		# Create a custom theme for the progress bar
		var progress_theme = Theme.new()
		var progress_style = StyleBoxFlat.new()
		progress_style.bg_color = theme_color
		progress_style.corner_radius_top_left = 4
		progress_style.corner_radius_top_right = 4
		progress_style.corner_radius_bottom_left = 4
		progress_style.corner_radius_bottom_right = 4
		progress_theme.set_stylebox("fill", "ProgressBar", progress_style)
		progress_bar.theme = progress_theme
	
	match completion_type:
		CompletionType.LETTER:
			if title_label:
				title_label.text = "Nice tracing!"
			if message_label:
				message_label.text = "You traced '" + completed_item.to_upper() + "'."
			
			# Update progress for letters (26 total)
			var letters_completed = progress_data.get("letters_completed", []).size()
			var total_letters = 26
			var letter_progress = (float(letters_completed) / float(total_letters)) * 100.0
			
			if progress_label:
				progress_label.text = "Letters Progress: " + str(letters_completed) + "/" + str(total_letters)
			if progress_bar:
				progress_bar.value = letter_progress
			
			# Show appropriate buttons
			if try_again_btn:
				try_again_btn.text = "Again"
				try_again_btn.visible = true
			if next_btn:
				next_btn.text = "Next"
				# Hide next button if all letters are complete
				if letters_completed >= total_letters:
					next_btn.visible = false
				else:
					next_btn.visible = true
		
		CompletionType.SIGHT_WORD:
			if title_label:
				title_label.text = "Well done!"
			if message_label:
				message_label.text = "You wrote '" + completed_item.to_lower() + "'."
			
			# Update progress for sight words (20 total)
			var words_completed = progress_data.get("sight_words_completed", []).size()
			var total_words = 20
			var word_progress = (float(words_completed) / float(total_words)) * 100.0
			
			if progress_label:
				progress_label.text = "Sight Words Progress: " + str(words_completed) + "/" + str(total_words)
			if progress_bar:
				progress_bar.value = word_progress
			
			# Show appropriate buttons
			if try_again_btn:
				try_again_btn.text = "Again"
				try_again_btn.visible = true
			if next_btn:
				next_btn.text = "Next Word"
				# Hide next button if all words are complete
				if words_completed >= total_words:
					next_btn.visible = false
				else:
					next_btn.visible = true
		
		CompletionType.CATEGORY_COMPLETE:
			if title_label:
				title_label.text = "All done!"
			if message_label:
				message_label.text = "You finished all " + completed_item + "."
			
			# Show overall phonics progress
			var overall_progress = progress_data.get("progress", 0)
			if progress_label:
				progress_label.text = "Overall Phonics Progress: " + str(overall_progress) + "%"
			if progress_bar:
				progress_bar.value = overall_progress
			
			# Only show try again button for category completion
			if try_again_btn:
				try_again_btn.text = "Practice More"
				try_again_btn.visible = true
			if next_btn:
				next_btn.visible = false

func close_celebration():
	"""Close celebration with animation"""
	var popup_container = $PopupContainer
	if popup_container:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(popup_container, "modulate", Color(1, 1, 1, 0), 0.25).set_ease(Tween.EASE_IN)
		tween.tween_property(popup_container, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
		
		await tween.finished
	
	hide()
	emit_signal("closed")

func _on_close_button_pressed():
	$ButtonClick.play()
	close_celebration()

func _on_try_again_button_pressed():
	$ButtonClick.play()
	emit_signal("try_again_pressed")
	close_celebration()

func _on_next_button_pressed():
	$ButtonClick.play()
	emit_signal("next_item_pressed")
	close_celebration()

func _on_button_hover():
	$ButtonHover.play()
