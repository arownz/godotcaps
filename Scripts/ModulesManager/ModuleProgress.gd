extends Node
class_name ModuleProgress

var collection = null

func _init():
	# Use same pattern as working PhonicsLetters.gd - no Engine.has_singleton check
	if Firebase and Firebase.Firestore:
		collection = Firebase.Firestore.collection("dyslexia_users")
		print("ModuleProgress: Firebase collection initialized")
	else:
		print("ModuleProgress: Firebase not available")

func is_authenticated() -> bool:
	return Firebase and Firebase.Auth and Firebase.Auth.auth != null and Firebase.Auth.auth.localid != null

# Generic module functions
func fetch_modules():
	"""Get all modules progress data"""
	if not is_authenticated():
		print("ModuleProgress: Not authenticated")
		return null
	
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		return document.get_value("modules")
	return null

# Phonics Module
func get_phonics_progress():
	"""Get progress for the Phonics module"""
	var modules = await fetch_modules()
	return modules.get("phonics", {}) if modules else null

func set_phonics_letter_completed(letter: String) -> bool:
	"""Mark a letter as completed in phonics"""
	if not is_authenticated():
		return false
	
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("phonics"):
			modules["phonics"] = {"completed": false, "progress": 0, "letters_completed": [], "sight_words_completed": []}
		
		var phonics = modules["phonics"]
		if not letter in phonics["letters_completed"]:
			phonics["letters_completed"].append(letter)
			# Calculate progress
			var total = phonics["letters_completed"].size() + phonics["sight_words_completed"].size()
			phonics["progress"] = (total / 46.0) * 100 # 26 letters + 20 sight words
			phonics["completed"] = total >= 46 # All letters and sight words completed
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

func set_sight_word_completed(word: String) -> bool:
	"""Mark a sight word as completed in phonics"""
	if not is_authenticated():
		return false
	
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("phonics"):
			modules["phonics"] = {"completed": false, "progress": 0, "letters_completed": [], "sight_words_completed": []}
		
		var phonics = modules["phonics"]
		if not word in phonics["sight_words_completed"]:
			phonics["sight_words_completed"].append(word)
			# Calculate progress
			var total = phonics["letters_completed"].size() + phonics["sight_words_completed"].size()
			phonics["progress"] = (total / 46.0) * 100 # 26 letters + 20 sight words
			phonics["completed"] = total >= 46 # All letters and sight words completed
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

# Flip Quiz Module - Enhanced with both Animals and Vehicles
func get_flip_quiz_progress():
	"""Get progress for the Flip Quiz module"""
	var modules = await fetch_modules()
	return modules.get("flip_quiz", {}) if modules else null

func complete_flip_quiz_set(category: String, set_id: String) -> bool:
	"""Complete a flip quiz set for a specific category (animals/vehicles)"""
	if not is_authenticated():
		return false
		
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("flip_quiz"):
			modules["flip_quiz"] = {
				"completed": false,
				"progress": 0,
				"animals": {"sets_completed": []},
				"vehicles": {"sets_completed": []}
			}
		
		var flip_quiz = modules["flip_quiz"]
		# Ensure category exists
		if not flip_quiz.has(category):
			flip_quiz[category] = {"sets_completed": []}
		
		var category_data = flip_quiz[category]
		if not set_id in category_data["sets_completed"]:
			category_data["sets_completed"].append(set_id)
			
			# Calculate overall progress (2 categories × 3 sets each = 6 total)
			var animals_count = flip_quiz.get("animals", {}).get("sets_completed", []).size()
			var vehicles_count = flip_quiz.get("vehicles", {}).get("sets_completed", []).size()
			var total_completed = animals_count + vehicles_count
			flip_quiz["progress"] = (total_completed / 6.0) * 100 # 6 total sets
			flip_quiz["completed"] = total_completed >= 6
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

# Read Aloud Module - Enhanced with Story Reading and Guided Reading
func get_read_aloud_progress():
	"""Get progress for the Read Aloud module"""
	var modules = await fetch_modules()
	return modules.get("read_aloud", {}) if modules else null

func complete_read_aloud_activity(category: String, activity_id: String) -> bool:
	"""Complete a read aloud activity for a specific category (story_reading/guided_reading)"""
	if not is_authenticated():
		return false
		
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("read_aloud"):
			modules["read_aloud"] = {
				"completed": false,
				"progress": 0,
				"story_reading": {"activities_completed": []},
				"guided_reading": {"activities_completed": []}
			}
		
		var read_aloud = modules["read_aloud"]
		# Ensure category exists
		if not read_aloud.has(category):
			read_aloud[category] = {"activities_completed": []}
		
		var category_data = read_aloud[category]
		if not activity_id in category_data["activities_completed"]:
			category_data["activities_completed"].append(activity_id)
			
			# Calculate overall progress (2 categories × 5 activities each = 10 total)
			var story_count = read_aloud.get("story_reading", {}).get("activities_completed", []).size()
			var guided_count = read_aloud.get("guided_reading", {}).get("activities_completed", []).size()
			var total_completed = story_count + guided_count
			read_aloud["progress"] = (total_completed / 10.0) * 100 # 10 total activities
			read_aloud["completed"] = total_completed >= 10
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false
