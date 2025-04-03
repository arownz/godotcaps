class_name HandwritingRecognition
extends Node

signal recognition_completed(text, score)
signal recognition_failed(error)

var is_available = false

func _ready():
    # Check if we're running in a browser environment
    if OS.get_name() == "Web":
        # Wait a bit to make sure the JavaScript has run its check
        await get_tree().create_timer(1.5).timeout
        # Check if the Handwriting Recognition API is available
        is_available = await _check_api_available()
        if is_available:
            print("Handwriting Recognition API is available")
        else:
            print("Handwriting Recognition API is not available in this browser")
            print("This feature requires Chrome 98+ with the Handwriting Recognition API enabled")
    else:
        print("Handwriting Recognition only works in web builds")

func _check_api_available():
    if not JavaScriptBridge.eval("typeof window !== 'undefined'"):
        return false
    
    # Run our JavaScript check and get its stored result
    JavaScriptBridge.eval("if (typeof window.checkHandwritingAPI === 'function') window.checkHandwritingAPI();")
    
    # Check the stored result after a brief delay
    await get_tree().create_timer(0.5).timeout
    
    var is_api_available = JavaScriptBridge.eval("window.handwritingAPIAvailable === true")
    print("Handwriting API available (from JavaScript): ", is_api_available)
    
    return is_api_available

func recognize_strokes(strokes_data):
    if not is_available:
        print("Handwriting Recognition API not available, using fallback")
        emit_signal("recognition_failed", "Handwriting Recognition API not available")
        return
    
    # Format the strokes data for the API
    var js_strokes = _format_strokes_for_js(strokes_data)
    
    # Create callable references that JavaScript can call back
    JavaScriptBridge.create_callback(Callable(self, "_js_success_callback"))
    JavaScriptBridge.create_callback(Callable(self, "_js_error_callback"))
    
    # Use our enhanced JavaScript function
    JavaScriptBridge.eval("""
        (function() {
            const strokeGroups = """ + js_strokes + """;
            console.log("Sending strokes to recognizer:", strokeGroups);
            
            window.recognizeStrokes(strokeGroups)
                .then(function(result) {
                    console.log("Recognition successful:", result);
                    window.godot._js_success_callback(result.text, result.score || 0);
                })
                .catch(function(error) {
                    console.error("Recognition error:", error);
                    window.godot._js_error_callback(error.error || error.toString());
                });
        })();
    """)

func _format_strokes_for_js(godot_strokes):
    # Convert Godot stroke format to JavaScript format expected by the API
    var js_strokes = []
    
    for stroke in godot_strokes:
        var points = stroke["points"]
        var js_points = []
        
        for point in points:
            js_points.append({
                "x": point.x,
                "y": point.y,
                "t": 0 # Time doesn't matter for basic recognition
            })
        
        if js_points.size() > 1: # Only include strokes with at least 2 points
            js_strokes.append(js_points)
    
    # Convert to JSON
    return JSON.stringify(js_strokes)

# JavaScript callback handlers
func _js_success_callback(text, score):
    emit_signal("recognition_completed", text, score)

func _js_error_callback(error):
    print("Recognition error: ", error)
    emit_signal("recognition_failed", error)

# Fallback function for non-web or browsers without the API
func simulate_recognition(expected_word):
    # This will be used as fallback
    # For testing, return a correct result 80% of the time
    if randf() < 0.8:
        emit_signal("recognition_completed", expected_word, 0.9)
    else:
        var incorrect_words = [
            "cat", "dog", "house", "tree", "book", 
            "pen", "lake", "sun", "moon", "dyslexia"
        ]
        var random_word = incorrect_words[randi() % incorrect_words.size()]
        emit_signal("recognition_completed", random_word, 0.5)
