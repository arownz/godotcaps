extends Node

# Global data management for the dyslexia learning game
# This singleton handles data sharing between scenes

# Current session data
var current_module = ""
var previous_scene = ""
var current_user_id = ""

# User progress tracking
var user_profile_data = {
	"display_name": "",
	"email": "",
	"total_exp": 0,
	"level": 1,
	"profile_picture": "default",
	"achievements": [],
	"last_login": ""
}

# Module progress data
var module_progress = {
	"phonics": {
		"current_lesson": 1,
		"completed_lessons": [],
		"total_lessons": 20
	},
	"flip_quiz": {
		"current_lesson": 1,
		"completed_lessons": [],
		"total_lessons": 20
	},
	"read_aloud": {
		"current_lesson": 1,
		"completed_lessons": [],
		"total_lessons": 20
	},
	"chunked_reading": {
		"current_lesson": 1,
		"completed_lessons": [],
		"total_lessons": 20
	},
	"syllable_building": {
		"current_lesson": 1,
		"completed_lessons": [],
		"total_lessons": 20
	}
}

# Game settings
var game_settings = {
	"master_volume": 1.0,
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"tts_enabled": true,
	"tts_voice": "default",
	"tts_speed": 1.0,
	"dyslexia_friendly_font": true,
	"high_contrast_mode": false,
	"text_size_multiplier": 1.0
}

# Constants
const SAVE_FILE_PATH = "user://save_data.json"
const SETTINGS_FILE_PATH = "user://settings.json"

func _ready():
	print("GlobalData: Initializing global data system")
	load_all_data()

# Save all data to files
func save_all_data():
	save_user_data()
	save_settings()

# Load all data from files
func load_all_data():
	load_user_data()
	load_settings()

# User data management
func save_user_data():
	var save_data = {
		"user_profile": user_profile_data,
		"module_progress": module_progress,
		"current_session": {
			"current_module": current_module,
			"current_user_id": current_user_id
		}
	}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
		print("GlobalData: User data saved successfully")
	else:
		print("GlobalData: Error saving user data")

func load_user_data():
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var save_data = json.data
				
				if save_data.has("user_profile"):
					user_profile_data = save_data.user_profile
				if save_data.has("module_progress"):
					module_progress = save_data.module_progress
				if save_data.has("current_session"):
					var session_data = save_data.current_session
					current_module = session_data.get("current_module", "")
					current_user_id = session_data.get("current_user_id", "")
				
				print("GlobalData: User data loaded successfully")
			else:
				print("GlobalData: Error parsing user data")

# Settings management
func save_settings():
	var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(game_settings)
		file.store_string(json_string)
		file.close()
		print("GlobalData: Settings saved successfully")

func load_settings():
	if FileAccess.file_exists(SETTINGS_FILE_PATH):
		var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				game_settings = json.data
				print("GlobalData: Settings loaded successfully")
			else:
				print("GlobalData: Error parsing settings")

# Module progress functions
func complete_lesson(module_name: String, lesson_number: int = -1):
	if module_progress.has(module_name):
		var module_data = module_progress[module_name]
		
		# If no lesson number provided, use current lesson
		if lesson_number == -1:
			lesson_number = module_data.current_lesson
		
		if not module_data.completed_lessons.has(lesson_number):
			module_data.completed_lessons.append(lesson_number)
			module_data.current_lesson = max(module_data.current_lesson, lesson_number + 1)
			
			# Award experience points
			add_experience(10) # 10 XP per completed lesson
			
			save_user_data()
			print("GlobalData: Completed lesson " + str(lesson_number) + " in " + module_name)

# Overloaded function for simple completion
func complete_current_lesson(module_name: String):
	complete_lesson(module_name)

func get_module_progress(module_name: String) -> Dictionary:
	if module_progress.has(module_name):
		var module_data = module_progress[module_name]
		var completed_count = module_data.completed_lessons.size()
		var total_lessons = module_data.total_lessons
		var progress_percent = (float(completed_count) / float(total_lessons)) * 100.0
		
		return {
			"completed_lessons": completed_count,
			"total_lessons": total_lessons,
			"progress_percent": progress_percent,
			"current_lesson": module_data.current_lesson
		}
	return {}

func get_overall_progress() -> Dictionary:
	var total_lessons = 0
	var completed_lessons = 0
	
	for module_name in module_progress.keys():
		var module_data = module_progress[module_name]
		total_lessons += module_data.total_lessons
		completed_lessons += module_data.completed_lessons.size()
	
	var overall_percent = 0.0
	if total_lessons > 0:
		overall_percent = (float(completed_lessons) / float(total_lessons)) * 100.0
	
	return {
		"completed_lessons": completed_lessons,
		"total_lessons": total_lessons,
		"progress_percent": overall_percent
	}

# Experience and leveling system
func add_experience(amount: int):
	user_profile_data.total_exp += amount
	check_level_up()

func check_level_up():
	var new_level = calculate_level(user_profile_data.total_exp)
	if new_level > user_profile_data.level:
		var old_level = user_profile_data.level
		user_profile_data.level = new_level
		print("GlobalData: Level up! " + str(old_level) + " -> " + str(new_level))
		# Emit a signal or call a function to show level up notification
		_show_level_up_notification(old_level, new_level)

func calculate_level(experience: int) -> int:
	# Simple leveling formula: every 100 XP = 1 level
	return max(1, int(float(experience) / 100.0) + 1)

func _show_level_up_notification(_old_level: int, new_level: int):
	# This could be improved to show a proper notification
	print("🎉 LEVEL UP! You are now level " + str(new_level) + "!")

# Scene management helpers
func change_scene_to(scene_path: String, store_previous: bool = true):
	if store_previous:
		previous_scene = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file(scene_path)

func return_to_previous_scene():
	if previous_scene != "":
		get_tree().change_scene_to_file(previous_scene)
		previous_scene = ""
	else:
		# Fallback to main menu
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

# Utility functions
func get_user_display_name() -> String:
	return user_profile_data.get("display_name", "Player")

func set_user_display_name(display_name: String):
	user_profile_data.display_name = display_name
	save_user_data()

func get_user_level() -> int:
	return user_profile_data.get("level", 1)

func get_user_exp() -> int:
	return user_profile_data.get("total_exp", 0)

# Clean up when the game closes
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_all_data()
