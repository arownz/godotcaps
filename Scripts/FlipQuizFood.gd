extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null
var completion_celebration_scene = preload("res://Scenes/CompletionCelebration.tscn")

# Simple food list (images assumed to exist; replace with actual texture paths when added)
var foods = [
	{"name": "apple", "image": null},
	{"name": "banana", "image": null},
	{"name": "bread", "image": null},
	{"name": "milk", "image": null}
]

var selected_foods = []
var game_cards = []
var flipped_cards = []
var matched_pairs = 0
var attempts = 0
var is_checking_match = false

func _ready():
	print("FlipQuizFood: Food flip quiz loaded")
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.3)
	_init_tts()
	_init_module_progress()
	_initialize_game()

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)

func _init_module_progress():
	if Engine.has_singleton("Firebase"):
		module_progress = ModuleProgress.new()
		add_child(module_progress)

func _initialize_game():
	foods.shuffle()
	selected_foods = foods.duplicate() # all four
	matched_pairs = 0
	attempts = 0
	_create_flip_cards()
	_update_score_display()

func _create_flip_cards():
	var cards_container = $CardsContainer if has_node("CardsContainer") else null
	if not cards_container:
		return
	for c in cards_container.get_children():
		c.queue_free()
	game_cards.clear()
	flipped_cards.clear()
	var all_cards = []
	for food in selected_foods:
		all_cards.append({"type": "image", "food": food, "id": food.name})
	for food in selected_foods:
		all_cards.append({"type": "text", "food": food, "id": food.name})
	all_cards.shuffle()
	for i in range(all_cards.size()):
		var card_data = all_cards[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 120)
		var style = StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.border_color = Color.BLACK
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.text = "?"
		btn.add_theme_font_override("font", preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
		btn.add_theme_font_size_override("font_size", 48)
		btn.set_meta("data", card_data)
		btn.set_meta("is_flipped", false)
		btn.set_meta("is_matched", false)
		btn.pressed.connect(_on_card_pressed.bind(btn))
		cards_container.add_child(btn)
		game_cards.append(btn)

func _on_card_pressed(card: Button):
	if card.get_meta("is_flipped") or card.get_meta("is_matched") or is_checking_match:
		return
	if flipped_cards.size() >= 2:
		return
	var card_data = card.get_meta("data")
	card.set_meta("is_flipped", true)
	if card_data.type == "image":
		card.text = card_data.food.name.capitalize()[0] # placeholder visual initial
		card.add_theme_font_size_override("font_size", 48)
	else:
		card.text = card_data.food.name.capitalize()
		card.add_theme_font_size_override("font_size", 24)
	flipped_cards.append(card)
	if flipped_cards.size() == 2:
		is_checking_match = true
		await get_tree().create_timer(1.0).timeout
		_check_match()

func _check_match():
	if flipped_cards.size() != 2:
		is_checking_match = false
		return
	var c1 = flipped_cards[0]
	var c2 = flipped_cards[1]
	var d1 = c1.get_meta("data")
	var d2 = c2.get_meta("data")
	attempts += 1
	if d1.id == d2.id:
		c1.set_meta("is_matched", true)
		c2.set_meta("is_matched", true)
		var match_style = StyleBoxFlat.new()
		match_style.bg_color = Color(0.2, 0.8, 0.2)
		match_style.border_color = Color.BLACK
		match_style.border_width_left = 3
		match_style.border_width_right = 3
		match_style.border_width_top = 3
		match_style.border_width_bottom = 3
		match_style.corner_radius_top_left = 10
		match_style.corner_radius_top_right = 10
		match_style.corner_radius_bottom_left = 10
		match_style.corner_radius_bottom_right = 10
		c1.add_theme_stylebox_override("normal", match_style)
		c2.add_theme_stylebox_override("normal", match_style)
		matched_pairs += 1
		_show_feedback("Matched " + d1.food.name + "!")
		if matched_pairs >= selected_foods.size():
			await get_tree().create_timer(1.0).timeout
			_complete_game()
	else:
		await get_tree().create_timer(0.8).timeout
		for card in flipped_cards:
			card.text = "?"
			card.set_meta("is_flipped", false)
	flipped_cards.clear()
	is_checking_match = false
	_update_score_display()

func _show_feedback(msg: String):
	if has_node("ScoreLabel"):
		var lbl = $ScoreLabel
		lbl.text = msg
	if tts:
		tts.speak(msg)

func _complete_game():
	print("FlipQuizFood: Game completed")
	if module_progress:
		await module_progress.set_flip_quiz_set_completed("Food")
	_show_completion()

func _show_completion():
	var celebration = completion_celebration_scene.instantiate()
	add_child(celebration)
	var progress_data = {"current": matched_pairs, "total": selected_foods.size(), "percentage": 100.0}
	celebration.show_completion("flip_quiz", "Food Memory Game", progress_data, "food")

func _update_score_display():
	if has_node("MatchesLabel"):
		$MatchesLabel.text = "Matches: " + str(matched_pairs) + "/" + str(selected_foods.size())

func _exit_tree():
	if tts and tts.has_method("stop"):
		tts.stop()
