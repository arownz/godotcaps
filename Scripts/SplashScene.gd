extends Control

@onready var logo_rect = $CenterContainer/LogoContainer/LogoRect
@onready var loading_label = $LoadingLabel
@onready var loading_dots = $LoadingDots

var dots_animation_timer = 0.0
var dots_state = 0
var animation_completed = false

func _ready():
	# Start the splash animation sequence
	start_splash_animation()

func start_splash_animation():
	print("SplashScene: Starting splash animation")
	# Initially hide the logo and loading elements
	logo_rect.modulate = Color(1, 1, 1, 0)
	logo_rect.scale = Vector2(0.5, 0.5)
	loading_label.modulate = Color(1, 1, 1, 0)
	loading_dots.modulate = Color(1, 1, 1, 0)
	
	# Create the main animation sequence
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple animations to run simultaneously
		# Logo fade-in and scale animation (dyslexia-friendly: smooth, predictable movement)
	tween.tween_property(logo_rect, "modulate", Color(1, 1, 1, 1), 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(logo_rect, "scale", Vector2(1.0, 1.0), 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	
	# Loading text fade-in (delayed, smooth transitions)
	tween.tween_property(loading_label, "modulate", Color(1, 1, 1, 1), 0.8).set_delay(1.2)
	tween.tween_property(loading_dots, "modulate", Color(1, 1, 1, 1), 0.6).set_delay(1.6)
	
	# Add a subtle glow effect by scaling up and down slightly
	await tween.finished
	print("SplashScene: Initial animation finished")
	
	# Start the breathing/glow effect
	start_breathing_effect()
	
	# Start loading dots animation
	start_loading_dots_animation()
		# Wait for 4 seconds then transition to the next scene (longer for readability)
	print("SplashScene: Waiting 4 seconds before transition")
	await get_tree().create_timer(4.0).timeout
	
	print("SplashScene: Timer finished, checking if animation completed")
	if not animation_completed:
		print("SplashScene: Animation not completed, transitioning to next scene")
		animation_completed = true
		transition_to_next_scene()
	else:
		print("SplashScene: Animation already completed, skipping transition")

func start_breathing_effect():
	# Create a gentle, slow pulsing effect (dyslexia-friendly: subtle, non-distracting)
	var breath_tween = create_tween()
	breath_tween.set_loops()
	breath_tween.tween_property(logo_rect, "scale", Vector2(1.02, 1.02), 2.0).set_ease(Tween.EASE_IN_OUT)
	breath_tween.tween_property(logo_rect, "scale", Vector2(1.0, 1.0), 2.0).set_ease(Tween.EASE_IN_OUT)

func start_loading_dots_animation():
	# Animate loading dots with consistent timing (dyslexia-friendly)
	var dots_tween = create_tween()
	dots_tween.set_loops()
	dots_tween.tween_callback(update_loading_dots)
	dots_tween.tween_interval(0.8)  # Slower, more predictable timing

func update_loading_dots():
	dots_state = (dots_state + 1) % 4
	match dots_state:
		0:
			loading_dots.text = ""
		1:
			loading_dots.text = "."
		2:
			loading_dots.text = ".."
		3:
			loading_dots.text = "..."

func transition_to_next_scene():
	# Set animation completed to prevent multiple calls
	animation_completed = true
	
	# Fade out animation (smooth and predictable)
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	fade_tween.tween_property(logo_rect, "modulate", Color(1, 1, 1, 0), 0.8)
	fade_tween.tween_property(loading_label, "modulate", Color(1, 1, 1, 0), 0.8)
	fade_tween.tween_property(loading_dots, "modulate", Color(1, 1, 1, 0), 0.8)
	fade_tween.tween_property(logo_rect, "scale", Vector2(1.1, 1.1), 0.8).set_ease(Tween.EASE_IN)
	
	await fade_tween.finished
	
	# Change to the authentication scene
	get_tree().change_scene_to_file("res://Scenes/Authentication.tscn")

func _process(_delta):
	# Optional: Add any continuous effects here if needed
	pass
