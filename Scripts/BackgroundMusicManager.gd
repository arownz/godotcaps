extends Node

# BackgroundMusicManager - Global background music handler
# This singleton manages background music playback across all scenes

var music_player: AudioStreamPlayer
var current_music: AudioStream = null
var is_music_playing: bool = false
var last_scene_name: String = ""

# Scenes where background music should NOT play
var music_excluded_scenes: Array[String] = [
	"BattleScene",
	"ModuleScene",
	"FlipQuizAnimals",
	"FlipQuizVehicle",
	"FlipQuizModule",
	"PhonicsLetters",
	"PhonicsSightWords",
	"PhonicsModule",
	"ReadAloudGuided",
	"ReadAloudStories",
	"ReadAloudModule",
	"SyllableBuildingModule",
	"WhiteboardInterface",
	"ChallengeResultPanels",
	"CompletionCelebration",
	"WordChallengePanel_Whiteboard",
	"WordChallengePanel_STT",
]

func _ready():
	print("BackgroundMusicManager: Initializing global background music manager")
	
	# Create the music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusicPlayer"
	music_player.bus = "Music"
	music_player.autoplay = false
	music_player.stream_paused = false
	add_child(music_player)
	
	# Load the main background music
	var music_stream = load("res://audio/Lexia Soundtrack.mp3")
	if music_stream:
		current_music = music_stream
		music_player.stream = current_music
		# Connect finished signal for looping with delay
		if not music_player.finished.is_connected(_on_music_finished):
			music_player.finished.connect(_on_music_finished)
		print("BackgroundMusicManager: Loaded Lexia Soundtrack with looping")
	else:
		print("BackgroundMusicManager: Failed to load Lexia Soundtrack")
		return
	
	# Apply current music volume from SettingsManager
	if SettingsManager:
		var saved_volume = SettingsManager.get_setting("audio", "music_volume")
		if saved_volume != null:
			set_music_volume(saved_volume / 100.0)
			print("BackgroundMusicManager: Applied saved music volume: ", saved_volume, "%")
	
	# Connect to scene changes
	get_tree().node_added.connect(_on_node_added)
	
	# Start music if we're not in an excluded scene
	_check_current_scene_and_play()

func _process(_delta):
	# Periodically check if the scene has changed
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_name = current_scene.name
		if scene_name != last_scene_name:
			last_scene_name = scene_name
			_check_scene_for_music_rules(scene_name)

func _on_node_added(node):
	# Check if the added node is a new scene root (becomes the current scene)
	if node.get_parent() == get_tree().root and node != self:
		# Use call_deferred to ensure the scene tree is fully updated
		call_deferred("_check_scene_for_music_rules", node.name)

func _on_scene_changed():
	# This function is kept for potential future use or manual calls
	_check_current_scene_and_play()

func _check_current_scene_and_play():
	var current_scene = get_tree().current_scene
	if current_scene:
		last_scene_name = current_scene.name
		_check_scene_for_music_rules(current_scene.name)

func _check_scene_for_music_rules(scene_name: String):
	print("BackgroundMusicManager: Checking music rules for scene: ", scene_name)
	
	if scene_name in music_excluded_scenes:
		print("BackgroundMusicManager: Scene is excluded, stopping music")
		stop_music()
	else:
		print("BackgroundMusicManager: Scene allows music, starting playback")
		play_music()

func play_music():
	"""Start or resume background music"""
	if not music_player or not current_music:
		print("BackgroundMusicManager: Cannot play music - player or stream not available")
		return
	
	if not is_music_playing:
		print("BackgroundMusicManager: Starting background music")
		music_player.play()
		is_music_playing = true
	elif music_player.stream_paused:
		print("BackgroundMusicManager: Resuming paused background music")
		music_player.stream_paused = false

func stop_music():
	"""Stop background music"""
	if music_player and is_music_playing:
		print("BackgroundMusicManager: Stopping background music")
		music_player.stop()
		is_music_playing = false

func pause_music():
	"""Pause background music without stopping"""
	if music_player and is_music_playing:
		print("BackgroundMusicManager: Pausing background music")
		music_player.stream_paused = true

func resume_music():
	"""Resume paused background music"""
	if music_player and is_music_playing and music_player.stream_paused:
		print("BackgroundMusicManager: Resuming background music")
		music_player.stream_paused = false

func set_music_volume(volume: float):
	"""Set the music volume (0.0 to 1.0) with master volume consideration"""
	if music_player:
		# Get master volume from SettingsManager for proper scaling
		var master_volume = 1.0
		if SettingsManager:
			var master_setting = SettingsManager.get_setting("audio", "master_volume")
			if master_setting != null:
				master_volume = master_setting / 100.0
		
		# Apply both music volume and master volume
		var final_volume = volume * master_volume
		music_player.volume_db = linear_to_db(final_volume)
		print("BackgroundMusicManager: Set music volume to: ", volume, " * master: ", master_volume, " = ", final_volume)

func is_excluded_scene(scene_name: String) -> bool:
	"""Check if a scene is excluded from background music"""
	return scene_name in music_excluded_scenes

func get_music_position() -> float:
	"""Get current playback position in seconds"""
	if music_player:
		return music_player.get_playback_position()
	return 0.0

func set_music_position(position: float):
	"""Set playback position in seconds"""
	if music_player and current_music:
		music_player.seek(position)
		print("BackgroundMusicManager: Set music position to: ", position, " seconds")

func _on_music_finished():
	"""Handle music finished signal for looping with delay"""
	print("BackgroundMusicManager: Music finished, will restart after delay")
	
	# Only restart if we're still supposed to be playing music
	if is_music_playing:
		# Create a timer for the delay before restarting
		var timer = Timer.new()
		timer.wait_time = 3.0 # 3 seconds delay before restart
		timer.one_shot = true
		add_child(timer)
		
		timer.timeout.connect(func():
			if is_music_playing: # Double-check we still want music
				print("BackgroundMusicManager: Restarting music after delay")
				music_player.play()
			timer.queue_free()
		)
		
		timer.start()