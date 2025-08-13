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
			"phonics": {"completed": false, "progress": 0},
			"flip_quiz": {"completed": false, "progress": 0},
			"read_aloud": {"completed": false, "progress": 0},
			"chunked_reading": {"completed": false, "progress": 0},
			"syllable_building": {"completed": false, "progress": 0}
		}
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
