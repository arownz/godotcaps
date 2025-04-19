extends Node

# Debug log levels
const LOG_LEVEL_DEBUG = 0
const LOG_LEVEL_INFO = 1
const LOG_LEVEL_WARNING = 2
const LOG_LEVEL_ERROR = 3

# Current log level (only logs of this level or higher will be displayed)
var current_log_level = LOG_LEVEL_INFO

# Debug log function
func debug_log(message, level = LOG_LEVEL_INFO):
	if level >= current_log_level:
		var level_prefix = ""
		match level:
			LOG_LEVEL_DEBUG:
				level_prefix = "[DEBUG] "
			LOG_LEVEL_INFO:
				level_prefix = "[INFO] "
			LOG_LEVEL_WARNING:
				level_prefix = "[WARNING] "
			LOG_LEVEL_ERROR:
				level_prefix = "[ERROR] "
		
		print(level_prefix + message)
		
		# If we have a debug label in the scene, also update it
		if has_node("DebugLabel"):
			get_node("DebugLabel").text = level_prefix + message
			# Auto-clear debug messages after 5 seconds
			_auto_clear_debug_label()

func _auto_clear_debug_label():
	await get_tree().create_timer(5.0).timeout
	if has_node("DebugLabel"):
		get_node("DebugLabel").text = ""

# Log Firebase Auth object details
func log_auth(auth):
	if auth == null:
		debug_log("Auth object is null", LOG_LEVEL_ERROR)
		return
		
	debug_log("Auth object keys: " + str(auth.keys()), LOG_LEVEL_DEBUG)
	
	if auth.has("localid"):
		debug_log("User ID: " + auth.localid, LOG_LEVEL_DEBUG)
	
	if auth.has("email"):
		debug_log("User email: " + auth.email, LOG_LEVEL_DEBUG)
		
	if auth.has("expiresin"):
		debug_log("Token expires in: " + auth.expiresin + " seconds", LOG_LEVEL_DEBUG)

# Log Firestore error details
func log_firestore_error(error):
	if error == null:
		debug_log("Firestore error is null", LOG_LEVEL_ERROR)
		return
		
	if typeof(error) == TYPE_DICTIONARY:
		debug_log("Firestore error code: " + str(error.get("code", "unknown")), LOG_LEVEL_ERROR)
		debug_log("Firestore error status: " + str(error.get("status", "unknown")), LOG_LEVEL_ERROR)
		debug_log("Firestore error message: " + str(error.get("message", "unknown")), LOG_LEVEL_ERROR)
	else:
		debug_log("Firestore error (raw): " + str(error), LOG_LEVEL_ERROR)

# Debug a Firestore document in detail
func debug_firestore_document(doc, doc_name="Document"):
	if doc == null:
		debug_log(doc_name + " is NULL", LOG_LEVEL_ERROR)
		return
	
	debug_log(doc_name + " keys: " + str(doc.keys()), LOG_LEVEL_DEBUG)
	
	if doc.has("error") and doc.error:
		debug_log(doc_name + " has error:", LOG_LEVEL_ERROR)
		log_firestore_error(doc.error)
	
	if doc.has("doc_name"):
		debug_log(doc_name + " name: " + str(doc.doc_name), LOG_LEVEL_DEBUG)
	
	if doc.has("doc_fields"):
		if doc.doc_fields == null:
			debug_log(doc_name + ".doc_fields is NULL", LOG_LEVEL_ERROR)
		elif typeof(doc.doc_fields) == TYPE_DICTIONARY:
			debug_log(doc_name + ".doc_fields keys: " + str(doc.doc_fields.keys()), LOG_LEVEL_DEBUG)
			for key in doc.doc_fields.keys():
				var value = doc.doc_fields[key]
				if typeof(value) == TYPE_DICTIONARY:
					debug_log(doc_name + "." + key + " (dict): " + str(value), LOG_LEVEL_DEBUG)
				else:
					debug_log(doc_name + "." + key + ": " + str(value), LOG_LEVEL_DEBUG)
		else:
			debug_log(doc_name + ".doc_fields is not a dictionary: " + str(typeof(doc.doc_fields)), LOG_LEVEL_ERROR)

# Test Firebase rules and report results
func test_firebase_rules():
	debug_log("Testing Firebase rules...", LOG_LEVEL_INFO)
	
	if Firebase.Firestore == null:
		debug_log("Cannot test rules - Firestore is null", LOG_LEVEL_ERROR)
		return
		
	var user_id = ""
	if Firebase.Auth && Firebase.Auth.auth && Firebase.Auth.auth.has("localid"):
		user_id = Firebase.Auth.auth.localid
	else:
		debug_log("User not authenticated", LOG_LEVEL_ERROR)
		return
	
	# Log complete auth object for debugging
	if Firebase.Auth && Firebase.Auth.auth:
		debug_log("Auth object: " + str(Firebase.Auth.auth.keys()), LOG_LEVEL_DEBUG)
		if Firebase.Auth.auth.has("idtoken"):
			debug_log("ID token exists (length: " + str(Firebase.Auth.auth.idtoken.length()) + ")", LOG_LEVEL_DEBUG)
	
	# If token might be expired, check and refresh it
	if Firebase.Auth && Firebase.Auth.auth:
		debug_log("Refreshing token before testing rules", LOG_LEVEL_INFO)
		var token_refresh = await Firebase.Auth.manual_token_refresh(Firebase.Auth.auth)
		debug_log("Token refresh result: " + str(token_refresh), LOG_LEVEL_INFO)
	
	# FIXED: Make sure we don't try to execute multiple Firestore operations in parallel
	# Wait between requests to avoid HTTPRequest conflicts
	
	# Test read operation
	debug_log("Testing read operation for user ID: " + user_id, LOG_LEVEL_INFO)
	var read_task = Firebase.Firestore.collection("dyslexia_users").get(user_id)
	if read_task:
		var read_result = await read_task.task_finished
		if read_result && !read_result.error:
			debug_log("✓ Read access is allowed", LOG_LEVEL_INFO)
		else:
			debug_log("✗ Read access is denied", LOG_LEVEL_ERROR)
			if read_result && read_result.error:
				log_firestore_error(read_result.error)
	else:
		debug_log("✗ Could not create read test task", LOG_LEVEL_ERROR)
	
	# Add a small delay before the next request to prevent HTTP request conflict
	await get_tree().create_timer(0.5).timeout
	
	# Test write operation
	debug_log("Testing write operation...", LOG_LEVEL_INFO)
	var test_data = {"test_field": "test_value_" + str(randi())}
	var write_task = Firebase.Firestore.collection("dyslexia_users").update(user_id, test_data)
	if write_task:
		var write_result = await write_task.task_finished
		if write_result && !write_result.error:
			debug_log("✓ Write access is allowed", LOG_LEVEL_INFO)
		else:
			debug_log("✗ Write access is denied", LOG_LEVEL_ERROR)
			if write_result && write_result.error:
				log_firestore_error(write_result.error)
	else:
		debug_log("✗ Could not create write test task", LOG_LEVEL_ERROR)
