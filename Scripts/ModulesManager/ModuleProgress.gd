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

# Syllable Building Module - Enhanced with explicit syllable types
func get_syllable_building_progress():
	"""Get progress for the Syllable Building module"""
	var modules = await fetch_modules()
	return modules.get("syllable_building", {}) if modules else null

func save_syllable_basic_word_progress(completed_words: Array) -> bool:
	"""Save progress for basic syllables word completion"""
	if not is_authenticated():
		return false
	
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("syllable_building"):
			modules["syllable_building"] = {
				"completed": false,
				"progress": 0,
				"basic_syllables": {"activities_completed": [], "basic_completed_words": []},
				"advanced_syllables": {"activities_completed": []}
			}
		
		var syllable_building = modules["syllable_building"]
		if not syllable_building.has("basic_syllables"):
			syllable_building["basic_syllables"] = {"activities_completed": [], "basic_completed_words": []}
		
		syllable_building["basic_syllables"]["basic_completed_words"] = completed_words
		
		# Calculate progress based on words completed + advanced activities
		var basic_progress = float(completed_words.size()) / 12.0 # 12 basic words
		var advanced_count = syllable_building.get("advanced_syllables", {}).get("activities_completed", []).size()
		var advanced_progress = float(advanced_count) / 6.0 # 6 advanced syllable types
		syllable_building["progress"] = ((basic_progress + advanced_progress) / 2.0) * 100
		syllable_building["completed"] = syllable_building["progress"] >= 100
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

func set_syllable_building_basic_completed(completed: bool) -> bool:
	"""Mark basic syllables as completed"""
	if not is_authenticated():
		return false
	
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("syllable_building"):
			modules["syllable_building"] = {
				"completed": false,
				"progress": 0,
				"basic_syllables": {"activities_completed": [], "basic_completed_words": []},
				"advanced_syllables": {"activities_completed": []}
			}
		
		var syllable_building = modules["syllable_building"]
		if not syllable_building.has("basic_syllables"):
			syllable_building["basic_syllables"] = {"activities_completed": [], "basic_completed_words": []}
		
		syllable_building["basic_syllables"]["completed"] = completed
		
		# Recalculate progress
		var basic_words = syllable_building["basic_syllables"].get("basic_completed_words", []).size()
		var basic_progress = float(basic_words) / 12.0
		var advanced_count = syllable_building.get("advanced_syllables", {}).get("activities_completed", []).size()
		var advanced_progress = float(advanced_count) / 6.0
		syllable_building["progress"] = ((basic_progress + advanced_progress) / 2.0) * 100
		syllable_building["completed"] = syllable_building["progress"] >= 100
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

func complete_syllable_activity(category: String, activity_id: String) -> bool:
	"""Complete a syllable building activity for a specific category (basic_syllables/advanced_syllables)"""
	if not is_authenticated():
		return false
	
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("syllable_building"):
			modules["syllable_building"] = {
				"completed": false,
				"progress": 0,
				"basic_syllables": {"activities_completed": []},
				"advanced_syllables": {"activities_completed": []}
			}
		
		var syllable_building = modules["syllable_building"]
		# Ensure category exists
		if not syllable_building.has(category):
			syllable_building[category] = {"activities_completed": []}
		
		var category_data = syllable_building[category]
		if not activity_id in category_data["activities_completed"]:
			category_data["activities_completed"].append(activity_id)
			
			# Calculate overall progress (2 categories × 6 syllable types each = 12 total)
			var basic_count = syllable_building.get("basic_syllables", {}).get("activities_completed", []).size()
			var advanced_count = syllable_building.get("advanced_syllables", {}).get("activities_completed", []).size()
			var total_completed = basic_count + advanced_count
			syllable_building["progress"] = (total_completed / 12.0) * 100 # 12 total syllable types
			syllable_building["completed"] = total_completed >= 12
		
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

# Chunked Reading Module - Enhanced with Vocabulary Building and Question Analysis
func get_chunked_reading_progress():
	"""Get progress for the Chunked Reading module"""
	var modules = await fetch_modules()
	return modules.get("chunked_reading", {}) if modules else null

func save_chunked_vocabulary_progress(completed_words: Array) -> bool:
	"""Save progress for chunked vocabulary word completion"""
	if not is_authenticated():
		return false
	
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("chunked_reading"):
			modules["chunked_reading"] = {
				"completed": false,
				"progress": 0,
				"vocabulary_building": {"activities_completed": [], "vocabulary_words_completed": []},
				"chunked_question": {"activities_completed": []}
			}
		
		var chunked = modules["chunked_reading"]
		if not chunked.has("vocabulary_building"):
			chunked["vocabulary_building"] = {"activities_completed": [], "vocabulary_words_completed": []}
		
		chunked["vocabulary_building"]["vocabulary_words_completed"] = completed_words
		
		# Calculate progress based on vocabulary words + other activities  
		var vocab_progress = float(completed_words.size()) / 10.0 # 10 vocabulary words
		var other_activities = chunked.get("chunked_question", {}).get("activities_completed", []).size()
		var other_progress = float(other_activities) / 5.0 # Assume 5 other activities
		chunked["progress"] = ((vocab_progress + other_progress) / 2.0) * 100
		chunked["completed"] = chunked["progress"] >= 100
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

func complete_chunked_reading_activity(category: String, activity_id: String) -> bool:
	"""Complete a chunked reading activity for a specific category (vocabulary_building/chunked_question)"""
	if not is_authenticated():
		return false
	
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("chunked_reading"):
			modules["chunked_reading"] = {
				"completed": false,
				"progress": 0,
				"vocabulary_building": {"activities_completed": []},
				"chunked_question": {"activities_completed": []}
			}
		
		var chunked = modules["chunked_reading"]
		# Ensure category exists
		if not chunked.has(category):
			chunked[category] = {"activities_completed": []}
		
		var category_data = chunked[category]
		if not activity_id in category_data["activities_completed"]:
			category_data["activities_completed"].append(activity_id)
			
			# Calculate overall progress (2 categories × 5 activities each = 10 total)
			var vocab_count = chunked.get("vocabulary_building", {}).get("activities_completed", []).size()
			var question_count = chunked.get("chunked_question", {}).get("activities_completed", []).size()
			var total_completed = vocab_count + question_count
			chunked["progress"] = (total_completed / 10.0) * 100 # 10 total activities
			chunked["completed"] = total_completed >= 10
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false
