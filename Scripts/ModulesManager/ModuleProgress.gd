extends Node
class_name ModuleProgress

# Firebase-backed module progress helper for Module Mode

func _get_collection():
	return Firebase.Firestore.collection("dyslexia_users")

func _get_user_id() -> String:
	if Firebase.Auth.auth:
		return Firebase.Auth.auth.localid
	return ""

func is_authenticated() -> bool:
	return Firebase.Auth.auth != null and _get_user_id() != ""

func _safe_get_modules_dict(doc) -> Dictionary:
	var modules = doc.get_value("modules") if doc else null
	if modules == null or typeof(modules) != TYPE_DICTIONARY:
		modules = {
			"phonics": {
				"completed": false,
				"progress": 0,
				"letters_completed": [],
				"sight_words_completed": []
			},
			"flip_quiz": {"completed": false, "progress": 0},
			"read_aloud": {"completed": false, "progress": 0},
			"chunked_reading": {"completed": false, "progress": 0},
			"syllable_building": {"completed": false, "progress": 0}
		}
	# Ensure phonics has detailed tracking structure
	elif modules.has("phonics") and typeof(modules["phonics"]) == TYPE_DICTIONARY:
		if not modules["phonics"].has("letters_completed"):
			modules["phonics"]["letters_completed"] = []
		if not modules["phonics"].has("sight_words_completed"):
			modules["phonics"]["sight_words_completed"] = []
	return modules

func fetch_modules() -> Dictionary:
	if !is_authenticated():
		print("ModuleProgress: Not authenticated; returning empty modules")
		return {}
	var user_id = _get_user_id()
	var collection = _get_collection()
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		return _safe_get_modules_dict(user_doc)
	print("ModuleProgress: Failed to fetch modules")
	return {}

func set_module_progress(module_key: String, progress: int, completed: bool = false) -> bool:
	if !is_authenticated():
		print("ModuleProgress: Not authenticated; skip update")
		return false
	var user_id = _get_user_id()
	var collection = _get_collection()
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var modules = _safe_get_modules_dict(user_doc)
		if !modules.has(module_key):
			modules[module_key] = {"completed": false, "progress": 0}
		modules[module_key]["progress"] = clamp(progress, 0, 100)
		modules[module_key]["completed"] = completed or modules[module_key]["progress"] >= 100
		user_doc.add_or_update_field("modules", modules)
		var updated = await collection.update(user_doc)
		if updated:
			print("ModuleProgress: Updated ", module_key, " -> ", modules[module_key])
			return true
		print("ModuleProgress: Update failed for ", module_key)
		return false
	print("ModuleProgress: Could not get user document for update")
	return false

func increment_module_progress(module_key: String, delta: int) -> Dictionary:
	if !is_authenticated():
		return {}
	var user_id = _get_user_id()
	var collection = _get_collection()
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var modules = _safe_get_modules_dict(user_doc)
		if !modules.has(module_key):
			modules[module_key] = {"completed": false, "progress": 0}
		var new_progress = clamp(int(modules[module_key]["progress"]) + delta, 0, 100)
		var new_completed = new_progress >= 100
		modules[module_key]["progress"] = new_progress
		modules[module_key]["completed"] = new_completed
		user_doc.add_or_update_field("modules", modules)
		var updated = await collection.update(user_doc)
		if updated:
			print("ModuleProgress: Incremented ", module_key, " -> ", modules[module_key])
			return modules[module_key]
		print("ModuleProgress: Increment failed for ", module_key)
		return {}
	return {}

# Enhanced phonics tracking functions
func set_phonics_letter_completed(letter: String) -> bool:
	"""Mark a specific letter as completed in phonics module"""
	if !is_authenticated():
		print("ModuleProgress: Not authenticated; skip phonics letter update")
		return false
	
	var user_id = _get_user_id()
	var collection = _get_collection()
	var user_doc = await collection.get_doc(user_id)
	
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var modules = _safe_get_modules_dict(user_doc)
		
		# Ensure phonics module structure exists
		if !modules.has("phonics"):
			modules["phonics"] = {"completed": false, "progress": 0, "letters_completed": [], "sight_words_completed": []}
		elif !modules["phonics"].has("letters_completed"):
			modules["phonics"]["letters_completed"] = []
		elif !modules["phonics"].has("sight_words_completed"):
			modules["phonics"]["sight_words_completed"] = []
		
		# Add letter to completed list if not already there
		var letters_completed = modules["phonics"]["letters_completed"]
		if not letters_completed.has(letter.to_upper()):
			letters_completed.append(letter.to_upper())
			modules["phonics"]["letters_completed"] = letters_completed
			
			# Calculate overall phonics progress (26 letters + 20 sight words = 46 total tasks)
			var total_letters = letters_completed.size()
			var total_sight_words = modules["phonics"].get("sight_words_completed", []).size()
			var total_completed = total_letters + total_sight_words
			var progress_percent = (float(total_completed) / 46.0) * 100.0
			
			modules["phonics"]["progress"] = int(progress_percent)
			modules["phonics"]["completed"] = progress_percent >= 100.0
			
			user_doc.add_or_update_field("modules", modules)
			var updated = await collection.update(user_doc)
			
			if updated:
				print("ModuleProgress: Letter ", letter, " completed. Phonics progress: ", int(progress_percent), "%")
				return true
			else:
				print("ModuleProgress: Failed to update phonics letter progress")
				return false
		else:
			print("ModuleProgress: Letter ", letter, " already completed")
			return true
	
	print("ModuleProgress: Could not get user document for phonics letter update")
	return false

func set_phonics_sight_word_completed(word: String) -> bool:
	"""Mark a specific sight word as completed in phonics module"""
	if !is_authenticated():
		print("ModuleProgress: Not authenticated; skip sight word update")
		return false
	
	var user_id = _get_user_id()
	var collection = _get_collection()
	var user_doc = await collection.get_doc(user_id)
	
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var modules = _safe_get_modules_dict(user_doc)
		
		# Ensure phonics module structure exists
		if !modules.has("phonics"):
			modules["phonics"] = {"completed": false, "progress": 0, "letters_completed": [], "sight_words_completed": []}
		elif !modules["phonics"].has("sight_words_completed"):
			modules["phonics"]["sight_words_completed"] = []
		elif !modules["phonics"].has("letters_completed"):
			modules["phonics"]["letters_completed"] = []
		
		# Add sight word to completed list if not already there
		var sight_words_completed = modules["phonics"]["sight_words_completed"]
		if not sight_words_completed.has(word.to_lower()):
			sight_words_completed.append(word.to_lower())
			modules["phonics"]["sight_words_completed"] = sight_words_completed
			
			# Calculate overall phonics progress (26 letters + 20 sight words = 46 total tasks)
			var total_letters = modules["phonics"].get("letters_completed", []).size()
			var total_sight_words = sight_words_completed.size()
			var total_completed = total_letters + total_sight_words
			var progress_percent = (float(total_completed) / 46.0) * 100.0
			
			modules["phonics"]["progress"] = int(progress_percent)
			modules["phonics"]["completed"] = progress_percent >= 100.0
			
			user_doc.add_or_update_field("modules", modules)
			var updated = await collection.update(user_doc)
			
			if updated:
				print("ModuleProgress: Sight word '", word, "' completed. Phonics progress: ", int(progress_percent), "%")
				return true
			else:
				print("ModuleProgress: Failed to update sight word progress")
				return false
		else:
			print("ModuleProgress: Sight word '", word, "' already completed")
			return true
	
	print("ModuleProgress: Could not get user document for sight word update")
	return false

func get_phonics_progress() -> Dictionary:
	"""Get detailed phonics progress including completed letters and sight words"""
	if !is_authenticated():
		return {"letters_completed": [], "sight_words_completed": [], "progress": 0, "completed": false}
	
	var user_id = _get_user_id()
	var collection = _get_collection()
	var user_doc = await collection.get_doc(user_id)
	
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var modules = _safe_get_modules_dict(user_doc)
		if modules.has("phonics"):
			var phonics = modules["phonics"]
			return {
				"letters_completed": phonics.get("letters_completed", []),
				"sight_words_completed": phonics.get("sight_words_completed", []),
				"progress": phonics.get("progress", 0),
				"completed": phonics.get("completed", false)
			}
	
	return {"letters_completed": [], "sight_words_completed": [], "progress": 0, "completed": false}
