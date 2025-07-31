extends Control

signal indicator_finished

# References to child nodes
@onready var enemy_name_label = $CenterContainer/IndicatorPanel/VBoxContainer/EnemyNameLabel
@onready var skill_name_label = $CenterContainer/IndicatorPanel/VBoxContainer/SkillNameLabel
@onready var instruction_label = $CenterContainer/IndicatorPanel/VBoxContainer/InstructionLabel
@onready var countdown_label = $CenterContainer/IndicatorPanel/VBoxContainer/CountdownContainer/CountdownLabel
@onready var countdown_text = $CenterContainer/IndicatorPanel/VBoxContainer/CountdownContainer/CountdownText
@onready var animation_player = $CenterContainer/IndicatorPanel/AnimationPlayer

# Indicator properties
var enemy_name = ""
var skill_name = ""
var challenge_type = ""
var display_duration = 5.0 # Total display time in seconds
var countdown_timer: Timer
var signal_emitted = false # Prevent duplicate signal emission

func _ready():
	# Create countdown timer
	countdown_timer = Timer.new()
	countdown_timer.wait_time = 1.0 # 1 second intervals
	countdown_timer.one_shot = false
	countdown_timer.timeout.connect(_on_countdown_tick)
	add_child(countdown_timer)
	
	# Set up the indicator
	_setup_indicator()

func setup(enemy_name_param: String, skill_name_param: String, challenge_type_param: String):
	enemy_name = enemy_name_param
	skill_name = skill_name_param
	challenge_type = challenge_type_param
	
	# If nodes are already ready, setup immediately
	if enemy_name_label:
		_setup_indicator()

func _setup_indicator():
	if not enemy_name_label:
		return
	
	# Set the enemy name
	enemy_name_label.text = enemy_name
	
	# Set the skill name with action verb
	skill_name_label.text = "uses " + skill_name + "!"
	
	# Set instruction based on challenge type
	var instruction_text = ""
	match challenge_type:
		"whiteboard":
			instruction_text = "Prepare to counter by WRITING the word!"
		"stt":
			instruction_text = "Prepare to counter by SPEAKING the word!"
		_:
			instruction_text = "Prepare to counter by writing or speaking the word!"
	
	instruction_label.text = instruction_text
	
	# Start the countdown and display
	_start_countdown()

func _start_countdown():
	var countdown_seconds = int(display_duration)
	countdown_label.text = str(countdown_seconds)
	
	# Start the countdown timer
	countdown_timer.start()
	
	# Set up a final timer to finish the indicator
	var finish_timer = Timer.new()
	finish_timer.wait_time = display_duration
	finish_timer.one_shot = true
	finish_timer.timeout.connect(_on_indicator_finished)
	add_child(finish_timer)
	finish_timer.start()

func _on_countdown_tick():
	# Update countdown display
	var current_count = int(countdown_label.text)
	current_count -= 1
	
	if current_count <= 0:
		countdown_text.text = ""
		countdown_label.text = "GET READY!"
		countdown_label.modulate = Color(1, 0.3, 0.3, 1) # Red color for urgency
		countdown_timer.stop()
	else:
		countdown_label.text = str(current_count)
		
		# Change color as countdown progresses for visual feedback
		match current_count:
			2:
				countdown_label.modulate = Color(1, 1, 0.3, 1) # Yellow
				countdown_text.modulate = Color(1, 1, 0.3, 1)
			1:
				countdown_label.modulate = Color(1, 0.6, 0.3, 1) # Orange
				countdown_text.modulate = Color(1, 0.6, 0.3, 1)

func _on_indicator_finished():
	# Prevent duplicate signal emission
	if signal_emitted:
		print("EnemySkillIndicator: Duplicate signal emission prevented")
		return
	
	signal_emitted = true
	
	# Stop animations
	animation_player.stop()
	
	# Emit signal to notify that we're done
	emit_signal("indicator_finished")
	
	# Clean up
	queue_free()

# Handle early dismissal (if user wants to skip)
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_skip_indicator()
	elif event is InputEventMouseButton and event.pressed:
		_skip_indicator()

func _skip_indicator():
	# Allow users to skip the indicator by clicking or pressing space/enter
	# IMPORTANT: Stop the timer to prevent duplicate signals
	countdown_timer.stop()
	
	# Find and stop the finish timer to prevent duplicate execution
	for child in get_children():
		if child is Timer and child != countdown_timer:
			child.stop()
			child.queue_free()
	
	_on_indicator_finished()
