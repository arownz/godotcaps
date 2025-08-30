extends Node
class_name ModuleProgress

var collection = null

func _init():
	if Engine.has_singleton("Firebase"):
		collection = Firebase.Firestore.collection("dyslexia_users")
		print("ModuleProgress: Firebase collection initialized")
	else:
		print("ModuleProgress: Firebase not available")

func is_authenticated() -> bool:
	return Firebase.Auth.auth != null

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

# Flip Quiz Module
func get_flip_quiz_progress():
	"""Get progress for the Flip Quiz module"""
	var modules = await fetch_modules()
	return modules.get("flip_quiz", {}) if modules else null

func complete_flip_quiz_set(set_id: String) -> bool:
	if not is_authenticated():
		return false
		
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("flip_quiz"):
			modules["flip_quiz"] = {"completed": false, "progress": 0, "sets_completed": []}
		
		var flip_quiz = modules["flip_quiz"]
		if not set_id in flip_quiz["sets_completed"]:
			flip_quiz["sets_completed"].append(set_id)
			# Update progress based on completed sets
			flip_quiz["progress"] = (flip_quiz["sets_completed"].size() / 10.0) * 100 # Assuming 10 total sets
			flip_quiz["completed"] = flip_quiz["progress"] >= 100
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

# Syllable Building Module
func get_syllable_building_progress():
	"""Get progress for the Syllable Building module"""
	var modules = await fetch_modules()
	return modules.get("syllable_building", {}) if modules else null

func set_syllable_word_completed(type: String, word: String) -> bool:
	"""Mark a word as completed for a specific syllable type"""
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
				"syllable_types": {
					"closed": {"completed": false, "words": []},
					"open": {"completed": false, "words": []},
					"magic_e": {"completed": false, "words": []},
					"r_controlled": {"completed": false, "words": []},
					"vowel_team": {"completed": false, "words": []},
					"consonant_le": {"completed": false, "words": []}
				}
			}
		
		var syllable_building = modules["syllable_building"]
		var type_data = syllable_building["syllable_types"][type]
		
		if not word in type_data["words"]:
			type_data["words"].append(word)
			# Check if this type is now complete (5 words per type)
			type_data["completed"] = type_data["words"].size() >= 5
			
			# Calculate overall progress
			var total_completed = 0
			var total_types = syllable_building["syllable_types"].keys().size()
			for t in syllable_building["syllable_types"]:
				if syllable_building["syllable_types"][t]["completed"]:
					total_completed += 1
			
			syllable_building["progress"] = (total_completed / float(total_types)) * 100
			syllable_building["completed"] = total_completed == total_types
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

# Read Aloud Module
func get_read_aloud_progress():
	"""Get progress for the Read Aloud module"""
	var modules = await fetch_modules()
	return modules.get("read_aloud", {}) if modules else null

func complete_read_aloud_story(story_id: String) -> bool:
	if not is_authenticated():
		return false
		
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("read_aloud"):
			modules["read_aloud"] = {"completed": false, "progress": 0, "stories_completed": []}
		
		var read_aloud = modules["read_aloud"]
		if not story_id in read_aloud["stories_completed"]:
			read_aloud["stories_completed"].append(story_id)
			# Update progress based on completed stories
			read_aloud["progress"] = (read_aloud["stories_completed"].size() / 10.0) * 100 # Assuming 10 total stories
			read_aloud["completed"] = read_aloud["progress"] >= 100
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

# Chunked Reading Module
func get_chunked_reading_progress():
	"""Get progress for the Chunked Reading module"""
	var modules = await fetch_modules()
	return modules.get("chunked_reading", {}) if modules else null

func complete_text_analysis(passage_id: String) -> bool:
	"""Mark a text analysis passage as completed"""
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
				"passages_completed": []
			}
		
		var chunked = modules["chunked_reading"]
		if not passage_id in chunked["passages_completed"]:
			chunked["passages_completed"].append(passage_id)
			# Update progress (assuming 10 total passages)
			chunked["progress"] = (chunked["passages_completed"].size() / 10.0) * 100
			chunked["completed"] = chunked["progress"] >= 100
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		
		return !("error" in updated.keys())
	return false
