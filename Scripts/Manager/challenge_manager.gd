class_name ChallengeManager
extends Node

var battle_scene  # Reference to the main battle scene

# Challenge-related properties
var current_challenge = null
var challenge_type = "none"  # "none", "whiteboard", "stt"

func _init(scene):
	battle_scene = scene
	
	# Hide the challenge buttons container since we're using automatic selection
	var buttons_container = battle_scene.get_node_or_null("MainContainer/RightContainer/MarginContainer/VBoxContainer/ButtonContainer/ChallengeButtonsContainer")
	if buttons_container:
		buttons_container.visible = false

func start_whiteboard_challenge():
	# Set the challenge type
	challenge_type = "whiteboard"

func start_speech_challenge():
	# Set the challenge type
	challenge_type = "stt"

func handle_challenge_cancelled():
	# Reset challenge state
	challenge_type = "none"
	
	# Resume auto battle
	battle_scene._resume_auto_battle()

func end_challenge():
	# Reset challenge type
	challenge_type = "none"
