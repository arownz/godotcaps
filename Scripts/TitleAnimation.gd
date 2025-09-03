extends Control

@onready var title_label = $TitleLabel
var full_text = "LEXIA"
var current_text = ""
var typing_speed = 0.30 # Time between each character
var pause_duration = 3.0 # Pause before restarting animation
var char_index = 0
var is_typing = true

func _ready():
	if title_label:
		title_label.text = ""
		start_typing_animation()

func start_typing_animation():
	char_index = 0
	current_text = ""
	is_typing = true
	type_next_character()

func type_next_character():
	if char_index < full_text.length():
		current_text += full_text[char_index]
		title_label.text = current_text
		char_index += 1
		
		# Add a slight random variation to typing speed for more natural feel
		var random_delay = typing_speed + randf_range(-0.05, 0.1)
		await get_tree().create_timer(random_delay).timeout
		type_next_character()
	else:
		# Finished typing, wait then restart
		await get_tree().create_timer(pause_duration).timeout
		start_typing_animation()
