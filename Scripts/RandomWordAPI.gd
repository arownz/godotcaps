extends Node
class_name RandomWordAPI

signal word_fetched

# API URLs to try in order of preference
var API_URLS = [
    "https://api.datamuse.com/words?sp=????&max=10", # 4-letter words specifically
    "https://random-word-api.herokuapp.com/word"	
]

# State variables
var http_request = null
var random_word = ""
var current_api_index = 0
var current_retry = 0
var last_error = ""

# Constants
const MAX_RETRIES = 3
const RETRY_DELAY = 1.0

func _init():
	# Create HTTP request node
	http_request = HTTPRequest.new()
	http_request.request_completed.connect(_on_request_completed)

# Public function to fetch a random word
func fetch_random_word():
	# Reset word
	random_word = ""
	
	# Reset error
	last_error = ""
	
	# Try primary API first
	current_api_index = 0
	current_retry = 0
	_make_request()

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
	
	# For 4-letter words from the API, ensure it's actually a clean 4-letter word
	# This helps eliminate potential junk or longer strings that might come through
	if API_URLS[current_api_index].contains("sp=????"):
		# Ensure it's actually close to 4 letters (allowing for minor variations)
		if random_word.length() < 3 or random_word.length() > 6:
			print("RandomWordAPI: Word length not in range 3-6: " + random_word)
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

# Improve fallback word selection with categories and ensure we have 4-letter words
func _get_fallback_word() -> String:
	# Add more word categories for better variety - ensure we have enough 4-letter words
	var word_categories = {
		"animals": ["wolf", "frog", "bear", "lion", "duck", "bird", "fish", "deer", "goat", "seal"],
		"objects": ["book", "lamp", "desk", "fork", "door", "bowl", "mug", "ring", "coat", "pipe"],
		"nature": ["tree", "rock", "fire", "lake", "hill", "moon", "star", "rain", "snow", "leaf"],
		"food": ["cake", "fish", "meat", "rice", "soup", "pear", "plum", "milk", "corn", "beef"],
		"colors": ["blue", "pink", "teal", "grey", "gold", "ruby", "mint", "aqua", "lime", "navy"],
		"verbs": ["walk", "talk", "make", "read", "swim", "sing", "play", "ride", "push", "pull"]
	}
	
	# Select a random category
	var categories = word_categories.keys()
	var category = categories[randi() % categories.size()]
	
	# Select a random word from that category
	var words = word_categories[category]
	return words[randi() % words.size()]

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