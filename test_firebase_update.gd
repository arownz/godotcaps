extends Node

# Simple test script to verify Firebase player stat updates
func _ready():
	print("Firebase Test: Starting test...")
	
	# Wait a bit for Firebase to initialize
	await get_tree().create_timer(2.0).timeout
	
	if Firebase.Auth and Firebase.Auth.auth:
		test_player_stats_update()
	else:
		print("Firebase Test: Not authenticated, cannot test")

func test_player_stats_update():
	print("Firebase Test: Testing player stats update...")
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		print("Firebase Test: Document retrieved successfully")
		
		# Get current stats
		var stats = document.get_value("stats")
		if stats != null and typeof(stats) == TYPE_DICTIONARY:
			var player_stats = stats.get("player", {})
			print("Firebase Test: Current player stats: ", player_stats)
			
			# Update test values
			var current_level = player_stats.get("level", 1)
			player_stats["level"] = current_level + 1
			player_stats["exp"] = 50
			player_stats["health"] = 120
			player_stats["damage"] = 25
			player_stats["durability"] = 15
			
			print("Firebase Test: Updating to: ", player_stats)
			
			# Update stats structure
			stats["player"] = player_stats
			
			# Update document
			document.add_or_update_field("stats", stats)
			
			# Save to Firebase
			var updated_document = await collection.update(document)
			if updated_document:
				print("Firebase Test: ✓ SUCCESS! Player stats updated successfully")
				print("Firebase Test: ✓ New level should be: ", current_level + 1)
			else:
				print("Firebase Test: ✗ FAILED to update player stats")
		else:
			print("Firebase Test: Stats structure not found")
	else:
		print("Firebase Test: Failed to get document")
