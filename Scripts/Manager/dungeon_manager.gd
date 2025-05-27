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

# Testing mode flag - set to false in production to enable Firebase operations
var testing_mode = false

func _init(scene):
	battle_scene = scene

func initialize():
	# First check if we have data from DungeonGlobals (immediate transfer from dungeon map)
	var globals_data = DungeonGlobals.get_battle_progress()
	if globals_data.dungeon > 0 and globals_data.stage > 0:
		dungeon_num = globals_data.dungeon
		stage_num = globals_data.stage
		print("DungeonManager: Using DungeonGlobals data - Dungeon: ", dungeon_num, ", Stage: ", stage_num)
		return
	
	# Fallback to loading from Firebase if no globals data
	await load_progress_from_firebase()

func load_progress_from_firebase():
	if testing_mode or !Firebase.Auth.auth:
		print("DungeonManager: Using default progression (testing mode or not authenticated)")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	var task = await collection.get_doc(user_id)
	if task:
		var document = await task
		if document and document.has_method("doc_fields"):
			var user_data = document.doc_fields
			
			# Extract dungeon progress
			if user_data.has("dungeons") and user_data.dungeons.has("progress"):
				var progress = user_data.dungeons.progress
				dungeon_num = progress.get("current_dungeon", 1)
				stage_num = progress.get("current_stage", 1)
				print("DungeonManager: Loaded progress - Dungeon: ", dungeon_num, ", Stage: ", stage_num)

# Advance to the next stage or dungeon
func advance_stage():
	stage_num += 1
	
	# Check if we completed all stages in current dungeon
	if stage_num > max_stages_per_dungeon:
		stage_num = 1
		dungeon_num += 1
		previous_dungeon = dungeon_num - 1
		
		# Check if we completed all dungeons
		if dungeon_num > max_dungeons:
			dungeon_num = 1  # Reset to first dungeon after completing all
		
		# Emit signal for dungeon advancement
		emit_signal("dungeon_advanced", dungeon_num)
	
	# Emit signal for stage advancement
	emit_signal("stage_advanced", dungeon_num, stage_num)
	
	# Save progress to Firebase
	save_progress_to_firebase()
	
	return true

func reset():
	# Reset to first stage and dungeon
	stage_num = 1
	dungeon_num = 1
	previous_dungeon = 1
	
	# Emit reset signal
	emit_signal("dungeon_reset")
	
	# Save progress to Firebase (resetting progress)
	save_progress_to_firebase()
	
	return true

func save_progress_to_firebase():
	if testing_mode or !Firebase.Auth.auth:
		print("DungeonManager: Progress not saved (testing mode or not authenticated)")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document first to preserve other fields
	var task = await collection.get_doc(user_id)
	if task:
		var document = await task
		if document and document.has_method("doc_fields"):
			var current_data = document.doc_fields
			
			# Ensure nested structure exists
			if !current_data.has("dungeons"):
				current_data["dungeons"] = {}
			if !current_data.dungeons.has("progress"):
				current_data.dungeons["progress"] = {}
				
			# Update progress
			current_data.dungeons.progress.current_dungeon = dungeon_num
			current_data.dungeons.progress.current_stage = stage_num
			
			# Track stage completion
			if !current_data.dungeons.has("completed"):
				current_data.dungeons["completed"] = {}
			
			var dungeon_key = str(previous_dungeon)
			if !current_data.dungeons.completed.has(dungeon_key):
				current_data.dungeons.completed[dungeon_key] = {"completed": false, "stages_completed": []}
			
			# Add completed stage to array if not already there
			var previous_stage = stage_num - 1
			if previous_stage > 0:  # Only track completed stages
				if !current_data.dungeons.completed[dungeon_key].stages_completed.has(previous_stage):
					current_data.dungeons.completed[dungeon_key].stages_completed.append(previous_stage)
			
			# Save back to Firestore
			collection.add(user_id, current_data)
			print("DungeonManager: Saved progress - Dungeon: ", dungeon_num, ", Stage: ", stage_num)

# Check if we just advanced to a new dungeon
func is_new_dungeon():
	return previous_dungeon != dungeon_num