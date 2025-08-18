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
			"flip_quiz": {
				"completed": false,
				"progress": 0,
				"sets_completed": []
			},
			"read_aloud": {
				"completed": false,
				"progress": 0,
				"passages_completed": [],
				"total_comprehension": 0
			},
			"chunked_reading": {
				"completed": false,
				"progress": 0,
				"lessons_completed": [],
				"avg_accuracy": 0.0
			},
			"syllable_building": {
				"completed": false,
				"progress": 0,
				"activities_completed": [],
				"syllable_types_mastered": []
			}
		}
	
	# Ensure all modules have proper detailed tracking structure
	var module_defaults = {
		"phonics": {
			"letters_completed": [],
			"sight_words_completed": []
		},
		"flip_quiz": {
			"sets_completed": []
		},
		"read_aloud": {
			"passages_completed": [],
			"total_comprehension": 0
		},
		"chunked_reading": {
			"lessons_completed": [],
			"avg_accuracy": 0.0
		},
		"syllable_building": {
			"activities_completed": [],
			"syllable_types_mastered": []
		}
	}
	
	# Add missing detailed fields to existing modules
	for module_key in module_defaults.keys():
		if modules.has(module_key) and typeof(modules[module_key]) == TYPE_DICTIONARY:
			for field_key in module_defaults[module_key].keys():
				if not modules[module_key].has(field_key):
					modules[module_key][field_key] = module_defaults[module_key][field_key]
		elif not modules.has(module_key):
			modules[module_key] = {"completed": false, "progress": 0}
			for field_key in module_defaults[module_key].keys():
				modules[module_key][field_key] = module_defaults[module_key][field_key]
	
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

# Flip Quiz Module Functions (dyslexia-friendly word-picture matching)
func set_flip_quiz_set_completed(quiz_set_name: String) -> bool:
	"""Mark a specific flip quiz set as completed"""
	if !is_authenticated():
		print("ModuleProgress: Not authenticated; skip flip quiz update")
		return false
	
	var user_id = _get_user_id()
	var collection = _get_collection()
	var user_doc = await collection.get_doc(user_id)
	
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var modules = _safe_get_modules_dict(user_doc)
		
		# Ensure flip_quiz module structure exists
		if !modules.has("flip_quiz"):
			modules["flip_quiz"] = {"completed": false, "progress": 0, "sets_completed": []}
		elif !modules["flip_quiz"].has("sets_completed"):
			modules["flip_quiz"]["sets_completed"] = []
		
		# Add set to completed list if not already there
		var sets_completed = modules["flip_quiz"]["sets_completed"]
		if not sets_completed.has(quiz_set_name):
			sets_completed.append(quiz_set_name)
			modules["flip_quiz"]["sets_completed"] = sets_completed
			
			# Calculate progress (assuming 10 total sets for dyslexia-friendly progression)
			var progress_percent = (float(sets_completed.size()) / 10.0) * 100.0
			
			modules["flip_quiz"]["progress"] = int(progress_percent)
			modules["flip_quiz"]["completed"] = progress_percent >= 100.0
			
			user_doc.add_or_update_field("modules", modules)
			var updated = await collection.update(user_doc)
			
			if updated:
				print("ModuleProgress: Flip Quiz set '", quiz_set_name, "' completed. Progress: ", int(progress_percent), "%")
				return true
			else:
				print("ModuleProgress: Failed to update flip quiz progress")
				return false
		else:
			print("ModuleProgress: Flip Quiz set '", quiz_set_name, "' already completed")
			return true
	
	print("ModuleProgress: Could not get user document for flip quiz update")
	return false

# Read-Aloud Module Functions (dyslexia-friendly guided reading)
func set_read_aloud_passage_completed(passage_id: String, comprehension_score: int = 0) -> bool:
	"""Mark a read-aloud passage as completed with comprehension score"""
	if !is_authenticated():
		print("ModuleProgress: Not authenticated; skip read-aloud update")
		return false
	
	var user_id = _get_user_id()
	var collection = _get_collection()
	var user_doc = await collection.get_doc(user_id)
	
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var modules = _safe_get_modules_dict(user_doc)
		
		# Ensure read_aloud module structure exists
		if !modules.has("read_aloud"):
			modules["read_aloud"] = {"completed": false, "progress": 0, "passages_completed": [], "total_comprehension": 0}
		elif !modules["read_aloud"].has("passages_completed"):
			modules["read_aloud"]["passages_completed"] = []
			modules["read_aloud"]["total_comprehension"] = 0
		
		# Add passage to completed list if not already there
		var passages_completed = modules["read_aloud"]["passages_completed"]
		if not passages_completed.has(passage_id):
			passages_completed.append(passage_id)
			modules["read_aloud"]["passages_completed"] = passages_completed
			
			# Update comprehension tracking
			var current_comprehension = modules["read_aloud"].get("total_comprehension", 0)
			modules["read_aloud"]["total_comprehension"] = current_comprehension + comprehension_score
			
			# Calculate progress (assuming 15 total passages)
			var progress_percent = (float(passages_completed.size()) / 15.0) * 100.0
			
			modules["read_aloud"]["progress"] = int(progress_percent)
			modules["read_aloud"]["completed"] = progress_percent >= 100.0
			
			user_doc.add_or_update_field("modules", modules)
			var updated = await collection.update(user_doc)
			
			if updated:
				print("ModuleProgress: Read-Aloud passage '", passage_id, "' completed. Progress: ", int(progress_percent), "%")
				return true
			else:
				print("ModuleProgress: Failed to update read-aloud progress")
				return false
		else:
			print("ModuleProgress: Read-Aloud passage '", passage_id, "' already completed")
			return true
	
	print("ModuleProgress: Could not get user document for read-aloud update")
	return false

# Chunked Reading Module Functions (dyslexia-friendly text comprehension)
func set_chunked_reading_lesson_completed(lesson_id: String, comprehension_accuracy: float = 0.0) -> bool:
	"""Mark a chunked reading lesson as completed with comprehension accuracy"""
	if !is_authenticated():
		print("ModuleProgress: Not authenticated; skip chunked reading update")
		return false
	
	var user_id = _get_user_id()
	var collection = _get_collection()
	var user_doc = await collection.get_doc(user_id)
	
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var modules = _safe_get_modules_dict(user_doc)
		
		# Ensure chunked_reading module structure exists
		if !modules.has("chunked_reading"):
			modules["chunked_reading"] = {"completed": false, "progress": 0, "lessons_completed": [], "avg_accuracy": 0.0}
		elif !modules["chunked_reading"].has("lessons_completed"):
			modules["chunked_reading"]["lessons_completed"] = []
			modules["chunked_reading"]["avg_accuracy"] = 0.0
		
		# Add lesson to completed list if not already there
		var lessons_completed = modules["chunked_reading"]["lessons_completed"]
		if not lessons_completed.has(lesson_id):
			lessons_completed.append(lesson_id)
			modules["chunked_reading"]["lessons_completed"] = lessons_completed
			
			# Update accuracy tracking
			var current_avg = modules["chunked_reading"].get("avg_accuracy", 0.0)
			var lesson_count = lessons_completed.size()
			var new_avg = ((current_avg * (lesson_count - 1)) + comprehension_accuracy) / lesson_count
			modules["chunked_reading"]["avg_accuracy"] = new_avg
			
			# Calculate progress (assuming 12 total lessons)
			var progress_percent = (float(lessons_completed.size()) / 12.0) * 100.0
			
			modules["chunked_reading"]["progress"] = int(progress_percent)
			modules["chunked_reading"]["completed"] = progress_percent >= 100.0
			
			user_doc.add_or_update_field("modules", modules)
			var updated = await collection.update(user_doc)
			
			if updated:
				print("ModuleProgress: Chunked Reading lesson '", lesson_id, "' completed. Progress: ", int(progress_percent), "%")
				return true
			else:
				print("ModuleProgress: Failed to update chunked reading progress")
				return false
		else:
			print("ModuleProgress: Chunked Reading lesson '", lesson_id, "' already completed")
			return true
	
	print("ModuleProgress: Could not get user document for chunked reading update")
	return false

# Syllable Building Module Functions (dyslexia-friendly phonemic awareness)
func set_syllable_activity_completed(activity_id: String, syllable_type: String = "") -> bool:
	"""Mark a syllable building activity as completed"""
	if !is_authenticated():
		print("ModuleProgress: Not authenticated; skip syllable building update")
		return false
	
	var user_id = _get_user_id()
	var collection = _get_collection()
	var user_doc = await collection.get_doc(user_id)
	
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var modules = _safe_get_modules_dict(user_doc)
		
		# Ensure syllable_building module structure exists
		if !modules.has("syllable_building"):
			modules["syllable_building"] = {"completed": false, "progress": 0, "activities_completed": [], "syllable_types_mastered": []}
		elif !modules["syllable_building"].has("activities_completed"):
			modules["syllable_building"]["activities_completed"] = []
			modules["syllable_building"]["syllable_types_mastered"] = []
		
		# Add activity to completed list if not already there
		var activities_completed = modules["syllable_building"]["activities_completed"]
		if not activities_completed.has(activity_id):
			activities_completed.append(activity_id)
			modules["syllable_building"]["activities_completed"] = activities_completed
			
			# Track syllable type mastery
			if syllable_type != "" and not modules["syllable_building"]["syllable_types_mastered"].has(syllable_type):
				modules["syllable_building"]["syllable_types_mastered"].append(syllable_type)
			
			# Calculate progress (assuming 25 total activities across different syllable types)
			var progress_percent = (float(activities_completed.size()) / 25.0) * 100.0
			
			modules["syllable_building"]["progress"] = int(progress_percent)
			modules["syllable_building"]["completed"] = progress_percent >= 100.0
			
			user_doc.add_or_update_field("modules", modules)
			var updated = await collection.update(user_doc)
			
			if updated:
				print("ModuleProgress: Syllable Building activity '", activity_id, "' completed. Progress: ", int(progress_percent), "%")
				return true
			else:
				print("ModuleProgress: Failed to update syllable building progress")
				return false
		else:
			print("ModuleProgress: Syllable Building activity '", activity_id, "' already completed")
			return true
	
	print("ModuleProgress: Could not get user document for syllable building update")
	return false
