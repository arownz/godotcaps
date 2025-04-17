extends Node

signal user_data_updated

# User profile data
var username = "Player"
var level = 1
var energy = 20
var max_energy = 99
var character = "default"
var coin = 100
var power_scale = 120
var rank = "bronze"

# Dungeon progress
var current_dungeon = 1
var current_stage = 1
var dungeons_completed = {
	"1": {"completed": false, "stages_completed": 0},
	"2": {"completed": false, "stages_completed": 0},
	"3": {"completed": false, "stages_completed": 0}
}
var dungeon_names = {
	"1": "The Plains",
	"2": "The Mountain", 
	"3": "The Demon"
}

func _ready():
	# Initialize with default values
	pass

# Load data from Firestore
func load_from_firestore():
	if !Firebase.Auth.auth:
		print("Cannot load user data: No authenticated user")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	var task = collection.get(user_id)
	if task:
		var document = await task.task_finished
		if document and !document.error:
			# Update user data
			username = document.doc_fields.get("username", "Player")
			level = document.doc_fields.get("user_level", 1)
			energy = document.doc_fields.get("energy", 20)
			character = document.doc_fields.get("profile_picture", "default")
			coin = document.doc_fields.get("coin", 100)
			power_scale = document.doc_fields.get("power_scale", 120)
			rank = document.doc_fields.get("rank", "bronze")
			
			# Update dungeon progress
			current_dungeon = document.doc_fields.get("current_dungeon", 1)
			current_stage = document.doc_fields.get("current_stage", 1)
			dungeons_completed = document.doc_fields.get("dungeons_completed", {
				"1": {"completed": false, "stages_completed": 0},
				"2": {"completed": false, "stages_completed": 0},
				"3": {"completed": false, "stages_completed": 0}
			})
			
			# Emit update signal
			emit_signal("user_data_updated")
			
			return true
		else:
			print("Error loading user data:", document.error if document else "No document")
			return false
	else:
		print("Failed to create Firestore task")
		return false

# Save data to Firestore
func save_to_firestore():
	if !Firebase.Auth.auth:
		print("Cannot save user data: No authenticated user")
		return false
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	var user_data = {
		"username": username,
		"user_level": level,
		"energy": energy,
		"profile_picture": character,
		"coin": coin,
		"power_scale": power_scale,
		"rank": rank,
		"current_dungeon": current_dungeon,
		"current_stage": current_stage,
		"dungeons_completed": dungeons_completed
	}
	
	var task = collection.update(user_id, user_data)
	if task:
		var result = await task.task_finished
		if result.error:
			print("Error saving user data:", result.error)
			return false
		else:
			print("User data saved successfully")
			return true
	else:
		print("Failed to create Firestore task")
		return false

# Update dungeon progress
func update_dungeon_progress(dungeon_id, stage_id, completed=false):
	# Convert dungeon_id to string for dictionary key
	var dungeon_key = str(dungeon_id)
	
	# Ensure the structure exists
	if not dungeons_completed.has(dungeon_key):
		dungeons_completed[dungeon_key] = {"completed": false, "stages_completed": 0}
	
	# Update the progress
	var dungeon_data = dungeons_completed[dungeon_key]
	dungeon_data["stages_completed"] = max(dungeon_data["stages_completed"], stage_id)
	
	# Check if all stages of this dungeon are completed
	if stage_id >= 5:  # Assuming 5 stages per dungeon
		dungeon_data["completed"] = true
		
		# Advance to next dungeon if current one is completed
		if dungeon_id == current_dungeon:
			current_dungeon = min(current_dungeon + 1, 3)
			current_stage = 1
	elif dungeon_id == current_dungeon:
		# Just advance to next stage in current dungeon
		current_stage = min(stage_id + 1, 5)
	
	# Save changes
	save_to_firestore()
	
	# Emit update signal
	emit_signal("user_data_updated")
