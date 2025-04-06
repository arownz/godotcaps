extends Node
class_name RandomWordAPI

signal word_fetched

var current_word = ""
var last_error = ""
var http_request = null
var request_timeout = 10.0  # Increased timeout for slower connections
var timeout_timer = null
var retry_count = 0
var max_retries = 2

# A local fallback word list in case the API is not available
var local_word_list = [
	"dyslexia","apple", "banana", "cat", "dog", "elephant", 
	"fish", "giraffe", "house", "igloo", "jacket", 
	"kite", "lion", "monkey", "nest", "orange",
	"piano", "queen", "robot", "sun", "tree",
	"umbrella", "violin", "window", "xylophone", "yellow", "zebra"
]

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	# Add a timeout timer
	timeout_timer = Timer.new()
	timeout_timer.one_shot = true
	add_child(timeout_timer)
	timeout_timer.timeout.connect(_on_request_timeout)
	
	# Initialize with a random word from our local list
	randomize()
	current_word = local_word_list[randi() % local_word_list.size()]
	print("Initialized with fallback word: ", current_word)

func fetch_random_word():
	# Reset values
	last_error = ""
	retry_count = 0
	
	# Try the API request (but keep current_word as backup)
	var backup_word = current_word
	current_word = ""
	
	# Try the API request
	_try_api_request()
	
	# If we don't get a new word in 2 seconds, use the backup
	# This is now handled by the timeout in WordChallengePanel.gd
	
	# Return the backup word as a fallback
	if current_word == "":
		current_word = backup_word

func _try_api_request():
	# Different API endpoints to try
	var apis = [
		"https://api.datamuse.com/words?sp=?????&max=26"  # Try this API first (faster)
	]
	
	# Choose an API endpoint - use the first one initially (datamuse)
	var url = apis[0]
	if retry_count > 0:
		# Try the other API on retry
		url = apis[1]
	
	print("Attempting to fetch word from API: ", url)
	
	# Set timeout (reduced from 10s to 3s)
	timeout_timer.start(3.0)
	
	# Add custom headers to help with CORS issues
	var headers = [
		"User-Agent: GodotEngine/4.0",
		"Accept: application/json"
	]
	
	# Send the request
	var error = http_request.request(url, headers)
	if error != OK:
		print("HTTP Request failed with error: ", error)
		last_error = "HTTP Request Error: " + str(error)
		timeout_timer.stop()
		_use_fallback_word()
		word_fetched.emit()

func _on_request_timeout():
	print("Request timed out")
	# Handle timeout case
	http_request.cancel_request()
	last_error = "Request timed out. Check your internet connection."
	
	if retry_count < max_retries:
		retry_count += 1
		print("Retrying... Attempt #", retry_count)
		_try_api_request()
	else:
		# Use a fallback word after max retries
		_use_fallback_word()
		word_fetched.emit()

func _on_request_completed(result, response_code, _headers, body):
	# Stop the timeout timer
	timeout_timer.stop()
	
	print("API response received. Result: ", result, " Response code: ", response_code)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		last_error = "Request failed with error code: " + str(result)
		if retry_count < max_retries:
			retry_count += 1
			print("Retrying... Attempt #", retry_count)
			_try_api_request()
		else:
			_use_fallback_word()
			word_fetched.emit()
		return
		
	if response_code != 200:
		last_error = "API returned error code: " + str(response_code)
		if retry_count < max_retries:
			retry_count += 1
			print("Retrying... Attempt #", retry_count)
			_try_api_request()
		else:
			_use_fallback_word()
			word_fetched.emit()
		return
	
	# Try to parse the JSON response
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	
	if parse_error != OK:
		last_error = "JSON parse error: " + json.get_error_message()
		_use_fallback_word()
		word_fetched.emit()
		return
		
	var response = json.get_data()
	print("API response data: ", response)
	
	# Handle different API response formats
	if response is Array and response.size() > 0:
		if retry_count == 0:
			# For datamuse format
			if response[0] is Dictionary and response[0].has("word"):
				# First API (datamuse) returns an array of objects with "word" property
				randomize()
				var random_index = randi() % response.size()
				current_word = response[random_index]["word"]
			else:
				# Second API format (random-word-api)
				current_word = response[0]
		else:
			# Format for random-word-api
			current_word = response[0]
			
		print("Word fetched from API: ", current_word)
	elif response is Array and response.size() == 0:
		last_error = "API returned empty response"
		_use_fallback_word()
	elif response is Dictionary and response.has("word"):
		# Format for some other APIs
		current_word = response.word
	else:
		last_error = "Unexpected API response format"
		_use_fallback_word()
		
	# Make sure the word is of reasonable length for the challenge
	if current_word.length() > 10:
		current_word = current_word.substr(0, 10)
		
	# Make sure the word doesn't have weird characters
	var simplified_word = ""
	for ch in current_word:
		if (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z'):
			simplified_word += ch
	
	if simplified_word.length() > 0:
		current_word = simplified_word
	else:
		_use_fallback_word()
	
	word_fetched.emit()

func _use_fallback_word():
	# Choose a random word from our local fallback list
	randomize()
	var random_index = randi() % local_word_list.size()
	current_word = local_word_list[random_index]
	print("Using fallback word: ", current_word)

func get_random_word():
	# A convenience method that immediately returns a word
	# If we don't have one set yet, get a fallback word
	if current_word.strip_edges() == "":
		_use_fallback_word()
	return current_word
