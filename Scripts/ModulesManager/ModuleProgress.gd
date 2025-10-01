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
			modules["phonics"] = {"completed": false, "progress": 0, "letters_completed": [], "sight_words_completed": [], "current_letter_index": 0, "current_sight_word_index": 0}
		
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

func set_phonics_current_letter_index(index: int) -> bool:
	"""Store the current letter index for resuming progress"""
	if not is_authenticated():
		return false
	
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("phonics"):
			modules["phonics"] = {"completed": false, "progress": 0, "letters_completed": [], "sight_words_completed": [], "current_letter_index": 0, "current_sight_word_index": 0}
		
		modules["phonics"]["current_letter_index"] = index
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

func set_phonics_current_sight_word_index(index: int) -> bool:
	"""Store the current sight word index for resuming progress"""
	if not is_authenticated():
		return false
	
	var user_id = Firebase.Auth.auth.localid
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("phonics"):
			modules["phonics"] = {"completed": false, "progress": 0, "letters_completed": [], "sight_words_completed": [], "current_letter_index": 0, "current_sight_word_index": 0}
		
		modules["phonics"]["current_sight_word_index"] = index
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
			modules["phonics"] = {"completed": false, "progress": 0, "letters_completed": [], "sight_words_completed": [], "current_letter_index": 0, "current_sight_word_index": 0}
		
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
				"animals": {"sets_completed": [], "current_index": 0},
				"vehicles": {"sets_completed": [], "current_index": 0}
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

func set_flip_quiz_current_index(category: String, index: int) -> bool:
	"""Store current position for FlipQuiz category (animals/vehicles)"""
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
				"animals": {"sets_completed": [], "current_index": 0},
				"vehicles": {"sets_completed": [], "current_index": 0}
			}
		
		var flip_quiz = modules["flip_quiz"]
		if not flip_quiz.has(category):
			flip_quiz[category] = {"sets_completed": [], "current_index": 0}
		
		flip_quiz[category]["current_index"] = index
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
	"""Complete a read aloud activity for guided_reading category only"""
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
				"guided_reading": {"activities_completed": [], "current_index": 0}
			}
		
		var read_aloud = modules["read_aloud"]
		# Ensure category exists (only guided_reading supported)
		if category != "guided_reading":
			print("ModuleProgress: Only guided_reading category is supported")
			return false
			
		if not read_aloud.has(category):
			read_aloud[category] = {"activities_completed": [], "current_index": 0}
		
		var category_data = read_aloud[category]
		if not activity_id in category_data["activities_completed"]:
			category_data["activities_completed"].append(activity_id)
			print("ModuleProgress: Read aloud activity completed: ", category, " - ", activity_id)
			
			# Update overall read aloud progress (average of both categories)
			var guided_count = read_aloud.get("guided_reading", {}).get("activities_completed", []).size()
			var syllable_count = read_aloud.get("syllable_workshop", {}).get("activities_completed", []).size()
			var guided_progress = (float(guided_count) / 4.0) * 100.0 # 4 guided reading activities
			var syllable_progress = (float(syllable_count) / 9.0) * 100.0 # 9 syllable words (corrected)
			var overall_progress = (guided_progress + syllable_progress) / 2.0
			read_aloud["progress"] = int(overall_progress)
			read_aloud["completed"] = (guided_progress >= 100.0 and syllable_progress >= 100.0)
			
			print("ModuleProgress: Guided reading progress - ", guided_count, "/4 = ", int(guided_progress), "%")
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

func set_read_aloud_current_index(category: String, index: int) -> bool:
	"""Store current position for ReadAloud guided_reading category only"""
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
				"guided_reading": {"activities_completed": [], "current_index": 0}
			}
		
		var read_aloud = modules["read_aloud"]
		# Only support guided_reading category
		if category != "guided_reading":
			print("ModuleProgress: Only guided_reading category is supported")
			return false
			
		if not read_aloud.has(category):
			read_aloud[category] = {"activities_completed": [], "current_index": 0}
		
		read_aloud[category]["current_index"] = index
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

# Syllable Workshop Methods (part of Read Aloud module)
func complete_syllable_workshop_activity(activity_id: String) -> bool:
	"""Complete a syllable workshop activity"""
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
				"guided_reading": {"activities_completed": [], "current_index": 0},
				"syllable_workshop": {"activities_completed": [], "current_word_index": 0}
			}
		
		var read_aloud = modules["read_aloud"]
		if not read_aloud.has("syllable_workshop"):
			read_aloud["syllable_workshop"] = {"activities_completed": [], "current_word_index": 0}
		
		var syllable_data = read_aloud["syllable_workshop"]
		if not activity_id in syllable_data["activities_completed"]:
			syllable_data["activities_completed"].append(activity_id)
			print("ModuleProgress: Syllable workshop activity completed: ", activity_id)
		
		# Update syllable workshop progress only (don't combine with guided reading)
		var syllable_activities = syllable_data["activities_completed"].size()
		var total_syllable_activities = 9 # 9 syllable words in SyllableBuildingModule (matches actual array size)
		var syllable_progress = (float(syllable_activities) / float(total_syllable_activities)) * 100.0
		
		# Update overall read aloud progress (this is mainly for overall tracking, specific categories use their own calculations)
		var total_guided_activities = read_aloud.get("guided_reading", {}).get("activities_completed", []).size()
		var guided_progress = (float(total_guided_activities) / 4.0) * 100.0 # 4 guided reading activities
		var overall_progress = (guided_progress + syllable_progress) / 2.0 # Average of both categories
		read_aloud["progress"] = int(overall_progress)
		read_aloud["completed"] = (guided_progress >= 100.0 and syllable_progress >= 100.0)
		
		print("ModuleProgress: Syllable workshop progress - ", syllable_activities, "/", total_syllable_activities, " = ", int(syllable_progress), "%")
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

func set_syllable_workshop_current_index(index: int) -> bool:
	"""Store current position for syllable workshop"""
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
				"guided_reading": {"activities_completed": [], "current_index": 0},
				"syllable_workshop": {"activities_completed": [], "current_word_index": 0}
			}
		
		var read_aloud = modules["read_aloud"]
		if not read_aloud.has("syllable_workshop"):
			read_aloud["syllable_workshop"] = {"activities_completed": [], "current_word_index": 0}
		
		read_aloud["syllable_workshop"]["current_word_index"] = index
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false
