extends Node
class_name RandomWordAPI

signal word_fetched

# API URLs to try in order of preference (will be dynamically updated based on word length)
var API_URLS = [
    "https://api.datamuse.com/words?sp=???&max=10", # Default 3-letter words and 10 words per request
]

# State variables
var http_request = null
var random_word = ""
var current_api_index = 0
var current_retry = 0
var last_error = ""
var current_word_length = 3  # Default word length for dungeon 1

# Constants
const MAX_RETRIES = 3
const RETRY_DELAY = 1.0

func _init():
	# Create HTTP request node
	http_request = HTTPRequest.new()
	http_request.request_completed.connect(_on_request_completed)

# Public function to fetch a random word with configurable length
func fetch_random_word(word_length: int = 3):
	# Set the word length for this request
	current_word_length = word_length
	
	# Update API URL based on word length
	_update_api_url_for_length(word_length)
	
	# Reset word
	random_word = ""
	
	# Reset error
	last_error = ""
	
	# Try primary API first
	current_api_index = 0
	current_retry = 0
	_make_request()

# Update API URL based on desired word length
func _update_api_url_for_length(word_length: int):
	var question_marks = ""
	for i in range(word_length):
		question_marks += "?"
	
	API_URLS[0] = "https://api.datamuse.com/words?sp=" + question_marks + "&max=10"
	print("RandomWordAPI: Updated URL for " + str(word_length) + "-letter words: " + API_URLS[0])

# Make an HTTP request to the current API endpoint
func _make_request():
	var error = http_request.request(API_URLS[current_api_index])
	
	if error != OK:
		print("RandomWordAPI: Error making request: " + str(error))
		last_error = "Request error: " + str(error)
		_try_fallback()
		return

# Handle HTTP response
func _on_request_completed(result, response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("RandomWordAPI: Request failed: " + str(result))
		last_error = "Request failed: " + str(result)
		_try_fallback()
		return
	
	if response_code != 200:
		print("RandomWordAPI: Invalid response code: " + str(response_code))
		last_error = "HTTP error: " + str(response_code)
		_try_fallback()
		return
	
	# Process response based on API format
	if current_api_index == 0:
		_process_primary_api_response(body)
	else:
		_process_secondary_api_response(body)

func _process_primary_api_response(body):
	# Parse JSON response
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	
	if error != OK:
		print("RandomWordAPI: JSON parse error: " + str(error))
		last_error = "JSON parse error"
		_try_fallback()
		return
	
	var data = json.get_data()
	
	# Select a random word from the array instead of always taking the first one
	if typeof(data) == TYPE_ARRAY and data.size() > 0:
		# Choose a random index from the response array
		var random_index = randi() % data.size()
		var selected_item = data[random_index]
		
		match typeof(selected_item):
			TYPE_STRING:
				# Simple string format
				random_word = selected_item
				
			TYPE_DICTIONARY:
				# If it's a dictionary, try to find a word field
				if selected_item.has("word"):
					random_word = str(selected_item.word)
				elif selected_item.has("name"):
					random_word = str(selected_item.name)
				elif selected_item.has("value"):
					random_word = str(selected_item.value)
				else:
					# Just use the first key as fallback
					for key in selected_item:
						if typeof(selected_item[key]) == TYPE_STRING:
							random_word = str(selected_item[key])
							break
			
			_:
				# For any other type, convert to string
				random_word = str(selected_item)
	
	if random_word.is_empty():
		print("RandomWordAPI: Could not extract word from response")
		print("RandomWordAPI: Response data: ", data)
		last_error = "Invalid response format"
		_try_fallback()
		return
	
	# For word length validation, ensure it matches our target length (with small tolerance)
	if API_URLS[current_api_index].contains("sp="):
		# Ensure it's actually the target length (allowing for minor variations)
		if random_word.length() < current_word_length or random_word.length() > current_word_length + 2:
			print("RandomWordAPI: Word length not matching target " + str(current_word_length) + ": " + random_word)
			_try_fallback()
			return
		
		# Check if it has any special characters we don't want
		var regex = RegEx.new()
		regex.compile("[^a-zA-Z0-9]")
		if regex.search(random_word):
			print("RandomWordAPI: Word contains special characters: " + random_word)
			_try_fallback()
			return
	
	print("RandomWordAPI: Word fetched: " + str(random_word))
	emit_signal("word_fetched")

# Process response from secondary API
func _process_secondary_api_response(body):
	# Parse JSON response
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	
	if error != OK:
		print("RandomWordAPI: JSON parse error: " + str(error))
		last_error = "JSON parse error"
		_try_fallback()
		return
	
	var data = json.get_data()
	
	if typeof(data) == TYPE_ARRAY and data.size() > 0:
		if typeof(data[0]) == TYPE_DICTIONARY and data[0].has("word"):
			random_word = data[0].word
			print("RandomWordAPI: Word fetched: " + str(random_word))
			emit_signal("word_fetched")
		else:
			print("RandomWordAPI: Invalid response format from secondary API")
			last_error = "Invalid secondary API format"
			_try_fallback()
	else:
		print("RandomWordAPI: Invalid response format from secondary API")
		last_error = "Invalid secondary API format"
		_try_fallback()

# Try fallback API or retry current one
func _try_fallback():
	current_retry += 1
	
	if current_retry <= MAX_RETRIES:
		# Retry current API
		print("RandomWordAPI: Retrying API attempt " + str(current_retry) + " of " + str(MAX_RETRIES))
		await get_tree().create_timer(RETRY_DELAY).timeout
		_make_request()
	elif current_api_index < API_URLS.size() - 1:
		# Try next API
		current_api_index += 1
		current_retry = 0
		print("RandomWordAPI: Trying fallback API: " + API_URLS[current_api_index])
		_make_request()
	else:
		# All APIs failed, use fallback word
		print("RandomWordAPI: All APIs failed, using fallback word")
		random_word = _get_fallback_word()
		emit_signal("word_fetched")

# Improve fallback word selection with categories for different word lengths
func _get_fallback_word() -> String:
	# Word categories organized by length
	var word_categories_by_length = {
		3: {
			"animals": ["cat", "dog", "fox", "bee", "owl", "pig", "cow", "bat", "rat", "elk"],
			"objects": ["cup", "pan", "box", "key", "pen", "hat", "bag", "car", "bed", "toy"],
			"nature": ["sun", "sky", "sea", "ice", "mud", "dew", "fog", "air", "oil", "gas"],
			"food": ["pie", "tea", "egg", "jam", "nut", "ham", "gum", "oat", "fig", "yam"],
			"colors": ["red", "tan", "bay", "ash", "jet", "sky", "sea", "ice", "mud", "dew"],
			"verbs": ["run", "sit", "eat", "see", "get", "put", "cut", "dig", "fly", "try"]
		},
		4: {
			"animals": ["wolf", "frog", "bear", "lion", "duck", "bird", "fish", "deer", "goat", "seal"],
			"objects": ["book", "lamp", "desk", "fork", "door", "bowl", "mug", "ring", "coat", "pipe"],
			"nature": ["tree", "rock", "fire", "lake", "hill", "moon", "star", "rain", "snow", "leaf"],
			"food": ["cake", "fish", "meat", "rice", "soup", "pear", "plum", "milk", "corn", "beef"],
			"colors": ["blue", "pink", "teal", "grey", "gold", "ruby", "mint", "aqua", "lime", "navy"],
			"verbs": ["walk", "talk", "make", "read", "swim", "sing", "play", "ride", "push", "pull"]
		},
		5: {
			"animals": ["horse", "shark", "eagle", "tiger", "mouse", "whale", "sheep", "snake", "zebra", "llama"],
			"objects": ["table", "chair", "phone", "watch", "glass", "knife", "spoon", "plate", "tower", "wheel"],
			"nature": ["ocean", "river", "beach", "field", "grass", "plant", "stone", "cloud", "storm", "light"],
			"food": ["bread", "apple", "honey", "grape", "lemon", "pasta", "salad", "pizza", "cream", "sugar"],
			"colors": ["green", "black", "white", "brown", "coral", "peach", "ivory", "amber", "olive", "beige"],
			"verbs": ["dance", "smile", "laugh", "write", "think", "learn", "teach", "build", "climb", "throw"]
		}
	}
	
	# Get the word categories for the current word length
	var categories_for_length = word_categories_by_length.get(current_word_length, word_categories_by_length[3])
	
	# Select a random category
	var categories = categories_for_length.keys()
	var category = categories[randi() % categories.size()]
	
	# Select a random word from that category
	var words = categories_for_length[category]
	var selected_word = words[randi() % words.size()]
	
	print("RandomWordAPI: Using fallback " + str(current_word_length) + "-letter word: " + selected_word)
	return selected_word

# Public function to get the fetched word - enhance for better error handling
func get_random_word() -> String:
	# Make sure we have a word - if not, provide a fallback
	if random_word.is_empty():
		print("WARNING: Random word is empty, using fallback")
		return _get_fallback_word()
	return random_word

# Add child node override
func _notification(what):
	if what == NOTIFICATION_PARENTED:
		if get_parent() and not http_request.is_inside_tree():
			get_parent().add_child(http_request)