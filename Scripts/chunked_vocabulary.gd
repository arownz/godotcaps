extends Control

var tts: TextToSpeech = null
var module_progress = null
var current_set = null

# Vocabulary set state
var context_visible = false
var definition_visible = false
var examples_visible = false

func _ready():
	print("ChunkedVocabulary: Initializing")
	
	# Setup fade-in animation
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	
	# Initialize components
	_init_tts()
	_init_module_progress()
	
	# Connect hover events for audio feedback
	_connect_hover_events()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when window regains focus
		call_deferred("_refresh_progress")

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	
	# Load TTS settings
	var voice_id = SettingsManager.get_setting("accessibility", "tts_voice_id")
	var rate = SettingsManager.get_setting("accessibility", "tts_rate")
	
	if voice_id != null and voice_id != "":
		tts.set_voice(voice_id)	
	if rate != null:
		tts.set_rate(rate)

func _init_module_progress():
	if Engine.has_singleton("Firebase"):
		module_progress = ModuleProgress.new()
		add_child(module_progress)
		print("ChunkedVocabulary: ModuleProgress initialized")
		_load_progress()
	else:
		print("ChunkedVocabulary: Firebase not available")

func _load_progress():
	if not module_progress or not module_progress.is_authenticated():
		print("ChunkedVocabulary: Not authenticated")
		return
	
	print("ChunkedVocabulary: Loading progress")
	var progress = await module_progress.get_chunked_reading_progress()
	if progress:
		var completed_vocab = progress.get("completed_vocabulary", []).size()
		var percent = float(completed_vocab) / 10.0
		_update_progress_bar(percent)

func _update_progress_bar(percent: float):
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	if progress_bar:
		progress_bar.value = percent

func _connect_hover_events():
	# Connect all buttons to hover sound
	var buttons = get_tree().get_nodes_in_group("buttons")
	for button in buttons:
		if not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover)

func _on_button_hover():
	$ButtonHover.play()

func _on_tts_setting_button_pressed():
	$ButtonClick.play()
	var tts_popup = get_node_or_null("TTSSettingsPopup")
	if not tts_popup:
		var popup_scene = load("res://Scenes/TTSSettingsPopup.tscn")
		if popup_scene:
			tts_popup = popup_scene.instantiate()
			add_child(tts_popup)
			
			# Setup popup
			var current_voice = SettingsManager.get_setting("accessibility", "tts_voice_id")
			var current_rate = SettingsManager.get_setting("accessibility", "tts_rate")
			
			if current_voice == null or current_voice == "":
				current_voice = "default"
			if current_rate == null:
				current_rate = 1.0
			
			if tts_popup.has_method("setup"):
				tts_popup.setup(tts, current_voice, current_rate, "Testing Text to Speech")
			
			# Connect settings saved signal
			if not tts_popup.settings_saved.is_connected(_on_tts_settings_saved):
				tts_popup.settings_saved.connect(_on_tts_settings_saved)
	
	if tts_popup:
		tts_popup.visible = true

func _on_tts_settings_saved(voice_id: String, rate: float):
	if tts:
		if voice_id != null and voice_id != "":
			tts.set_voice(voice_id)
		if rate != null:
			tts.set_rate(rate)
	
	SettingsManager.set_setting("accessibility", "tts_voice_id", voice_id)
	SettingsManager.set_setting("accessibility", "tts_rate", rate)

func _on_back_button_pressed():
	$ButtonClick.play()
	_stop_tts()
	_fade_out_and_return()

func _fade_out_and_return():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween.finished
	get_tree().change_scene_to_file("res://Scenes/ChunkedReadingModule.tscn")

func _stop_tts():
	if tts and tts.has_method("stop"):
		tts.stop()

func _exit_tree():
	_stop_tts()

func _on_play_button_pressed():
	$ButtonClick.play()
	if current_set and tts:
		var text_to_speak = current_set["text"]
		if current_set.has("target_words"):
			for word in current_set["target_words"]:
				text_to_speak = text_to_speak.replace(word["word"], "*" + word["word"] + "*")
		tts.speak(text_to_speak)

func _on_start_new_button_pressed():
	$ButtonClick.play()
	_load_new_set()

func _load_new_set():
	# TODO: Load from vocabulary database
	current_set = {
		"text": "The enthusiastic scientist conducted an experiment in the laboratory. She used special equipment to analyze the mysterious substance. Her discovery was groundbreaking!",
		"target_words": [
			{
				"word": "enthusiastic",
				"definition": "showing intense and eager enjoyment, interest, or approval",
				"context": "The scientist loved her work so much that she was always enthusiastic about new experiments.",
				"examples": [
					"The enthusiastic crowd cheered loudly.",
					"She was enthusiastic about learning to play guitar.",
					"The puppy gave an enthusiastic welcome to its owner."
				]
			},
			{
				"word": "analyze",
				"definition": "examine methodically and in detail",
				"context": "Scientists analyze data to understand their experiments better.",
				"examples": [
					"Students learn to analyze poems in literature class.",
					"The doctor will analyze your test results.",
					"We need to analyze the problem before finding a solution."
				]
			},
			{
				"word": "mysterious",
				"definition": "difficult or impossible to understand, explain, or identify",
				"context": "The substance was mysterious because no one knew what it was made of.",
				"examples": [
					"They heard mysterious noises in the attic.",
					"The detective solved the mysterious case.",
					"The cave held many mysterious secrets."
				]
			}
		]
	}
	
	# Enable vocabulary tools
	_enable_vocab_tools()
	
	# Update passage display
	var passage_text = $MainContainer/ScrollContainer/ContentContainer/TextPanel/TextContainer/PassageText
	if passage_text:
		var formatted_text = current_set["text"]
		for word in current_set["target_words"]:
			formatted_text = formatted_text.replace(word["word"], "[color=#4a90e2]" + word["word"] + "[/color]")
		passage_text.text = formatted_text
	
	# Enable play button
	var play_button = $MainContainer/ScrollContainer/ContentContainer/TextPanel/TextContainer/ButtonContainer/PlayButton
	if play_button:
		play_button.disabled = false

func _enable_vocab_tools():
	var tools = [
		"ContextButton",
		"DefinitionButton",
		"ExampleButton",
		"PracticeButton"
	]
	
	for tool_name in tools:
		var button = $MainContainer/ScrollContainer/ContentContainer/VocabPanel/VocabContainer/ToolsGrid.get_node(tool_name)
		if button:
			button.disabled = false

func _on_context_button_pressed():
	$ButtonClick.play()
	if not current_set:
		return
	
	context_visible = not context_visible
	var passage_text = $MainContainer/ScrollContainer/ContentContainer/TextPanel/TextContainer/PassageText
	if passage_text:
		if context_visible:
			var text = "[center][b]Words in Context[/b][/center]\n\n"
			for word in current_set["target_words"]:
				text += "[color=#4a90e2]" + word["word"] + "[/color]: " + word["context"] + "\n\n"
			passage_text.text = text
		else:
			var formatted_text = current_set["text"]
			for word in current_set["target_words"]:
				formatted_text = formatted_text.replace(word["word"], "[color=#4a90e2]" + word["word"] + "[/color]")
			passage_text.text = formatted_text

func _on_definition_button_pressed():
	$ButtonClick.play()
	if not current_set:
		return
	
	definition_visible = not definition_visible
	var passage_text = $MainContainer/ScrollContainer/ContentContainer/TextPanel/TextContainer/PassageText
	if passage_text:
		if definition_visible:
			var text = "[center][b]Word Definitions[/b][/center]\n\n"
			for word in current_set["target_words"]:
				text += "[color=#4a90e2]" + word["word"] + "[/color]: " + word["definition"] + "\n\n"
			passage_text.text = text
		else:
			var formatted_text = current_set["text"]
			for word in current_set["target_words"]:
				formatted_text = formatted_text.replace(word["word"], "[color=#4a90e2]" + word["word"] + "[/color]")
			passage_text.text = formatted_text

func _on_example_button_pressed():
	$ButtonClick.play()
	if not current_set:
		return
	
	examples_visible = not examples_visible
	var passage_text = $MainContainer/ScrollContainer/ContentContainer/TextPanel/TextContainer/PassageText
	if passage_text:
		if examples_visible:
			var text = "[center][b]Example Sentences[/b][/center]\n\n"
			for word in current_set["target_words"]:
				text += "[color=#4a90e2]" + word["word"] + "[/color]:\n"
				for example in word["examples"]:
					text += "• " + example + "\n"
				text += "\n"
			passage_text.text = text
		else:
			var formatted_text = current_set["text"]
			for word in current_set["target_words"]:
				formatted_text = formatted_text.replace(word["word"], "[color=#4a90e2]" + word["word"] + "[/color]")
			passage_text.text = formatted_text

func _on_practice_button_pressed():
	$ButtonClick.play()
	if not current_set:
		return
	
	# TODO: Show practice popup with fill-in-the-blank or matching exercises
	print("ChunkedVocabulary: Practice exercises not implemented yet")
