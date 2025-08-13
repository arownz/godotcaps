extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null

# Categories: Only Letters and Sight Words
var categories = {
	"letters": {
		"name": "Letters",
		"firestore_key": "phonics_letters",
		"description": "Trace A-Z and hear sounds",
		"scene_path": "res://Scenes/PhonicsLetters.tscn"
	},
	"sight_words": {
		"name": "Sight Words",
		"firestore_key": "phonics_sight_words",
		"description": "Common words like 'the', 'and'",
		"scene_path": "res://Scenes/PhonicsSightWords.tscn"
	}
}

func _ready():
	print("PhonicsModule: Initializing phonics categories interface")
	
	# Enhanced fade-in animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Initialize helpers
	_init_tts()
	_init_module_progress()
	
	# Connect hover events
	_connect_hover_events()
	
	# Style cards with rounded corners and IconContainer backgrounds
	_style_category_cards()
	
	# Load progress from Firestore
	await _load_category_progress()

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	# Welcome message
	var intro = "Welcome to Phonics! Choose Letters to trace A-Z, or Sight Words to practice common words."
	var _ok = tts.speak(intro)

func _init_module_progress():
	if Engine.has_singleton("Firebase"):
		module_progress = ModuleProgress.new()
		add_child(module_progress)
	else:
		print("PhonicsModule: Firebase not available; progress won't sync")

func _connect_hover_events():
	# Connect back button hover
	var back_btn = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton
	if back_btn:
		back_btn.mouse_entered.connect(_on_button_hover)

func _style_category_cards():
	# Apply rounded corner styling to category cards - force same style as HeaderPanel
	var cards = [
		$MainContainer/ScrollContainer/CategoriesGrid/LettersCard,
		$MainContainer/ScrollContainer/CategoriesGrid/SightWordsCard
	]
	
	for card in cards:
		if card:
			# Force the card to use the same style as HeaderPanel
			var style_box = StyleBoxFlat.new()
			style_box.corner_radius_top_left = 15
			style_box.corner_radius_top_right = 15
			style_box.corner_radius_bottom_left = 15
			style_box.corner_radius_bottom_right = 15
			style_box.bg_color = Color(0.2, 0.6, 0.9, 1) # 3399E6 color
			style_box.border_width_left = 5
			style_box.border_width_right = 5
			style_box.border_width_top = 5
			style_box.border_width_bottom = 5
			style_box.border_color = Color(0, 0, 0, 1) # Black border
			style_box.shadow_color = Color(0, 0, 0, 0.1)
			style_box.shadow_size = 8
			style_box.shadow_offset = Vector2(0, 4)
			card.add_theme_stylebox_override("panel", style_box)
	
	# Style icon containers with #FEB79A background and black borders
	var icon_containers = [
		$MainContainer/ScrollContainer/CategoriesGrid/LettersCard/LettersContent/IconContainer,
		$MainContainer/ScrollContainer/CategoriesGrid/SightWordsCard/SightWordsContent/IconContainer
	]
	
	for icon_container in icon_containers:
		if icon_container:
			var icon_style = StyleBoxFlat.new()
			icon_style.corner_radius_top_left = 10
			icon_style.corner_radius_top_right = 10
			icon_style.corner_radius_bottom_left = 10
			icon_style.corner_radius_bottom_right = 10
			icon_style.bg_color = Color(1, 1, 1, 1) # white color
			icon_style.border_width_left = 2
			icon_style.border_width_right = 2
			icon_style.border_width_top = 2
			icon_style.border_width_bottom = 2
			icon_style.border_color = Color(0, 0, 0, 1) # Black border outline
			icon_container.add_theme_stylebox_override("panel", icon_style)

func _load_category_progress():
	if not module_progress:
		return
		
	var firebase_modules = await module_progress.fetch_modules()
	if firebase_modules.size() > 0:
		_update_progress_displays(firebase_modules)

func _update_progress_displays(firebase_modules: Dictionary):
	var total_progress = 0.0
	var category_count = 0
	
	for category_key in categories.keys():
		var firestore_key = categories[category_key]["firestore_key"]
		var progress_percent = 0.0
		
		if firebase_modules.has(firestore_key):
			var fm = firebase_modules[firestore_key]
			if typeof(fm) == TYPE_DICTIONARY:
				progress_percent = float(fm.get("progress", 0))
		
		# Update card progress label
		var card_path = "MainContainer/ScrollContainer/ContentContainer/CategoriesGrid/" + category_key.capitalize() + "Card"
		var progress_label = get_node_or_null(card_path + "/" + category_key.capitalize() + "Content/ProgressContainer/ProgressLabel")
		var progress_bar = get_node_or_null(card_path + "/" + category_key.capitalize() + "Content/ProgressContainer/ProgressBar")
		
		if progress_label:
			progress_label.text = str(int(progress_percent)) + "% Complete"
		if progress_bar:
			progress_bar.value = progress_percent
		
		total_progress += progress_percent
		category_count += 1
	
	# Update overall progress
	var overall_percent = total_progress / max(category_count, 1)
	var overall_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	var overall_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	
	if overall_label:
		overall_label.text = "Overall Progress: " + str(int(overall_percent)) + "%"
	if overall_bar:
		overall_bar.value = overall_percent

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	print("PhonicsModule: Returning to module selection")
	_fade_out_and_change_scene("res://Scenes/ModuleScene.tscn")

func _fade_out_and_change_scene(scene_path: String):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _on_letters_button_pressed():
	$ButtonClick.play()
	print("PhonicsModule: Starting Letters category")
	_launch_category("letters")

func _on_sight_words_button_pressed():
	$ButtonClick.play()
	print("PhonicsModule: Starting Sight Words category")
	_launch_category("sight_words")

func _launch_category(category_key: String):
	# Navigate to category scene
	var scene_path = categories[category_key]["scene_path"]
	_fade_out_and_change_scene(scene_path)
