extends Node

signal recognition_completed(text_result)
signal recognition_error(error_message)

var http_request
var base64_image
var default_url = "https://vision.googleapis.com/v1/images:annotate"

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

# Main function to recognize handwriting
func recognize_handwriting(image_data):
	print("Starting handwriting recognition")
	base64_image = image_data
	
	# Fix: Update platform detection to correctly identify web platform
	if OS.has_feature("web"):
		print("Web platform detected - using JavaScript bridge")
		_recognize_handwriting_web()
		return true
	else:
		print("ERROR: Handwriting recognition requires a web export")
		emit_signal("recognition_error", "Handwriting recognition only available in web builds")
		return false

# Web-specific implementation using JavaScript
func _recognize_handwriting_web():
	# Ensure we have the image data
	if base64_image.is_empty():
		emit_signal("recognition_error", "No image data provided")
		return
	
	# Use JavaScript to preprocess and call the Vision API
	print("Calling JavaScript Bridge for Cloud Vision API")
	var js_code = """
	(async function() {
		try {
			console.log('Processing image for recognition...');
			
			// First preprocess the image (resize, enhance contrast)
			const preprocessed = await window.preprocessHandwritingImage(%s, 800, 600);
			console.log('Image preprocessed, sending to Cloud Vision API');
			
			// Then send to Cloud Vision API
			const result = await window.callGoogleVisionApi(preprocessed);
			console.log('Recognition result:', result);
			return result;
		} catch (e) {
			console.error('Error in JavaScript recognition:', e);
			return 'error:' + e.toString();
		}
	})();
	""" % base64_image
	
	# Call JavaScript and handle response with better error handling
	var result
	if JavaScriptBridge.has_method("eval"):
		result = JavaScriptBridge.eval(js_code)
		print("JavaScript bridge returned: ", result if result is String and result.length() < 30 else "result too long to print")
		
		if result == null:
			emit_signal("recognition_error", "JavaScript returned null")
		elif typeof(result) != TYPE_STRING:
			emit_signal("recognition_error", "JavaScript returned non-string result")
		elif result.begins_with("error:"):
			emit_signal("recognition_error", "API error: " + result.substr(6))
		else:
			emit_signal("recognition_completed", result)
	else:
		emit_signal("recognition_error", "JavaScript bridge not available")

# HTTP request completed callback - Fix: Added underscore to the unused headers parameter
func _on_request_completed(result, response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("recognition_error", "HTTP Request failed with code: " + str(result))
		return
	
	if response_code != 200:
		emit_signal("recognition_error", "Server returned error code: " + str(response_code))
		return
	
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		emit_signal("recognition_error", "JSON Parse Error: " + json.get_error_message())
		return
	
	var response = json.get_data()
	var text_result = _extract_text_from_response(response)
	emit_signal("recognition_completed", text_result)

# Extract text from the API response
func _extract_text_from_response(response):
	if response.has("responses") and response.responses.size() > 0:
		var first_response = response.responses[0]
		
		# Try full text annotation first (better for handwritten text)
		if first_response.has("fullTextAnnotation"):
			return first_response.fullTextAnnotation.text.strip_edges()
			
		# Then try text annotations
		if first_response.has("textAnnotations") and first_response.textAnnotations.size() > 0:
			return first_response.textAnnotations[0].description.strip_edges()
	
	return "no_text_detected"
