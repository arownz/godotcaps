extends Control

signal continue_pressed

# Challenge result data
var recognized_text: String = ""
var challenge_word: String = ""
var is_successful: bool = false
var bonus_damage: int = 0
var input_type: String = "" # "wrote" or "said" based on input method
var display_time: float = 2.0 # Default display time, will be auto-adjusted based on success/failure

# Dyslexia-friendly features
var timer_paused: bool = false
var allow_manual_continue: bool = true

# Colors - using high contrast versions for dyslexia accessibility
var success_color = Color("#006400") # Dark green (high contrast)
var failure_color = Color("#8B0000") # Dark red (high contrast)

# References to UI elements
@onready var title_label = $ResultPanel/ContentContainer/TitleLabel
@onready var input_label = $ResultPanel/ContentContainer/ResultContainer/InputLabel
@onready var word_label = $ResultPanel/ContentContainer/ResultContainer/WordLabel
@onready var expected_label = $ResultPanel/ContentContainer/ResultContainer/ExpectedLabel
@onready var target_word_label = $ResultPanel/ContentContainer/ResultContainer/TargetWordLabel
@onready var status_label = $ResultPanel/ContentContainer/StatusContainer/StatusLabel
@onready var bonus_damage_label = $ResultPanel/ContentContainer/StatusContainer/BonusDamageLabel
@onready var animation_player = $AnimationPlayer
@onready var display_timer = $DisplayTimer

# Called when the node enters the scene tree
func _ready():
	# This is crucial for popup visibility
	set_as_top_level(true)
	
	# Enhanced fade-in animation with scale effect
	modulate.a = 0
	$ResultPanel.scale = Vector2(0.8, 0.8)
	
	# Initialize with empty data
	update_ui()
	
	# Connect timer signal
	display_timer.timeout.connect(_on_display_timer_timeout)
	
	# Ensure display timer uses our preferred wait time
	display_timer.wait_time = display_time
	
	# Enhanced entrance animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property($ResultPanel, "scale", Vector2(1, 1), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Start timer for auto-close (only if display_time > 0)
	if display_time > 0:
		display_timer.start()
	else:
		print("ChallengeResultPanel: Manual continue only mode - no auto-timer")
	
	# Add dyslexia-friendly input handling
	_setup_dyslexia_friendly_input()
	
	# Debug output
	print("ChallengeResultPanel initialized with display time: " + str(display_time) + " seconds")

# Set the challenge result data and update UI
func set_result(recognized: String, target: String, success: bool, damage: int = 0, type: String = "", custom_display_time: float = 0.0):
	recognized_text = recognized
	challenge_word = target
	is_successful = success
	bonus_damage = damage
	input_type = type
	
	# Auto-adjust display time based on success/failure if no custom time specified
	if custom_display_time > 0:
		display_time = custom_display_time
	elif custom_display_time == -1:
		# Special value -1 means no auto-timer, manual continue only
		display_time = -1
		allow_manual_continue = true
	else:
		# Dyslexia-friendly timing: Longer durations to allow proper processing
		# Success: 3 seconds (allows celebration and understanding)
		# Failure: 4 seconds (more time to process what went wrong and learn)
		display_time = 3.0 if success else 4.0
	
	# Update timer if it exists and timer is enabled
	if display_timer != null and display_time > 0:
		display_timer.wait_time = display_time
	
	update_ui()
	log_result()

# Update the UI with current data
func update_ui():
	# Set input type text
	input_label.text = "You " + input_type + ":"
	
	# Set the recognized text with proper capitalization for better readability
	word_label.text = recognized_text.capitalize() if recognized_text != "" else "..."
	
	# Set the target word with proper capitalization
	target_word_label.text = challenge_word.capitalize() if challenge_word != "" else "..."
	
	# Update status message and color
	if is_successful:
		status_label.text = "COUNTER SUCCESSFUL!"
		status_label.add_theme_color_override("font_color", success_color)
		bonus_damage_label.visible = true
		# Enhanced bonus damage display
		if bonus_damage > 0:
			bonus_damage_label.text = "Bonus Damage: +" + str(bonus_damage)
		else:
			bonus_damage_label.text = "Perfect Counter!"
	else:
		status_label.text = "CHALLENGE FAILED!"
		status_label.add_theme_color_override("font_color", failure_color)
		bonus_damage_label.visible = true
		bonus_damage_label.text = "Failed Counter..."

# Log the result to the battle log system
func log_result():
	# UNIFIED: Use consistent battle scene access pattern
	var battle_log = get_tree().current_scene.get_node_or_null("BattleLogManager")
	if battle_log and battle_log.has_method("add_log_entry"):
		var log_message = ""
		if is_successful:
			log_message = "[color=#000000]Challenge successful! You " + input_type + ": \"" + recognized_text + "\"[/color]"
			if bonus_damage > 0:
				log_message += "[color=#000000] (Bonus damage: +" + str(bonus_damage) + ")[/color]"
		else:
			log_message = "[color=#000000]Challenge failed. You " + input_type + ": \"" + recognized_text + "\". The word was: \"" + challenge_word + "\"[/color]"
		
		battle_log.add_log_entry(log_message, "challenge")

# Timer handler for auto-closing the panel
func _on_display_timer_timeout():
	# Enhanced fade-out animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property($ResultPanel, "scale", Vector2(0.8, 0.8), 0.3).set_ease(Tween.EASE_IN)
	
	# Wait for animation to complete, then emit signal and free
	await tween.finished
	emit_signal("continue_pressed")
	queue_free()

# Setup automatic timing only (manual controls removed for automatic flow)
func _setup_dyslexia_friendly_input():
	# Only automatic timing - no manual input handling
	pass
