class_name DungeonManager
extends Node

# Add signals for better decoupling
signal stage_advanced(dungeon_num, stage_num)
signal dungeon_advanced(dungeon_num)
signal dungeon_reset

var battle_scene  # Reference to the main battle scene

# Dungeon and stage tracking
var dungeon_num = 1
var stage_num = 1
var max_dungeons = 3
var max_stages_per_dungeon = 5
var previous_dungeon = 1  # Used to track dungeon transitions

func _init(scene):
	battle_scene = scene

func initialize():
	# Get values from GameSettings if available
	if GameSettings.has_method("get_current_dungeon") and GameSettings.has_method("get_current_stage"):
		dungeon_num = GameSettings.get_current_dungeon()
		stage_num = GameSettings.get_current_stage()
	else:
		# Directly access properties if they exist
		if "current_dungeon" in GameSettings:
			dungeon_num = GameSettings.current_dungeon
		if "current_stage" in GameSettings: 
			stage_num = GameSettings.current_stage
	
	# Ensure valid values
	dungeon_num = clamp(dungeon_num, 1, max_dungeons)
	stage_num = clamp(stage_num, 1, max_stages_per_dungeon)
	previous_dungeon = dungeon_num
	
	print("DungeonManager initialized with dungeon: %d, stage: %d" % [dungeon_num, stage_num])

func advance_stage():
	# Store previous values to check for transitions
	var old_dungeon = dungeon_num
	
	# Increment stage
	stage_num += 1
	
	# Check if we need to advance to the next dungeon
	if stage_num > max_stages_per_dungeon:
		stage_num = 1
		dungeon_num += 1
		
		# Check if we've completed all dungeons
		if dungeon_num > max_dungeons:
			# For now, loop back to dungeon 1
			dungeon_num = 1
	
	# Emit signals
	emit_signal("stage_advanced", dungeon_num, stage_num)
	
	# If dungeon changed, emit dungeon advanced signal
	if old_dungeon != dungeon_num:
		emit_signal("dungeon_advanced", dungeon_num)
	
	# Save progress to Firebase
	save_progress_to_firebase()

func is_new_dungeon():
	# Check if we've just transitioned to a new dungeon
	if previous_dungeon != dungeon_num:
		previous_dungeon = dungeon_num
		return true
	return false

func reset():
	# Reset to first dungeon, first stage
	dungeon_num = 1
	stage_num = 1
	previous_dungeon = 1
	
	# Save the reset to Firebase
	save_progress_to_firebase()
	
	# Emit signal
	emit_signal("dungeon_reset")

# Save progress to Firebase
func save_progress_to_firebase():
	# If Authentication script is available, use its method
	if "update_dungeon_progress" in get_node("/root/Authentication"):
		get_node("/root/Authentication").update_dungeon_progress(dungeon_num, stage_num)
	elif Firebase and Firebase.Auth.auth:
		# Update progress directly
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		var update_data = {
			"current_dungeon": dungeon_num,
			"current_stage": stage_num
		}
		
		var update_task = collection.update(user_id, update_data)
		if update_task:
			var result = await update_task.task_finished
			if result.error:
				print("Error updating dungeon progress: ", result.error)
			else:
				print("Dungeon progress updated successfully")
		
		# Also update GameSettings
		if "current_dungeon" in GameSettings:
			GameSettings.current_dungeon = dungeon_num
		if "current_stage" in GameSettings:
			GameSettings.current_stage = stage_num
