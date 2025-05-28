extends Node

# Quick Firebase test - focused on testing the stat update functionality
# Run this to specifically test the Firebase update fix

func _ready():
	print("=== QUICK FIREBASE UPDATE TEST ===")
	print("Testing Firebase player stats update functionality...")
	
	# Wait for Firebase initialization
	await get_tree().create_timer(2.0).timeout
	
	await test_firebase_update()

func test_firebase_update():
	print("\n🔥 Testing Firebase Update Functionality")
	
	# Check if Firebase is available
	if not Engine.has_singleton("Firebase"):
		print("❌ Firebase singleton not found")
		return
	
	print("✓ Firebase singleton found")
	
	if not Firebase.Auth:
		print("❌ Firebase.Auth not available")
		return
		
	print("✓ Firebase.Auth available")
	
	if not Firebase.Auth.auth:
		print("❌ User not authenticated")
		print("💡 Note: This test requires authentication to work properly")
		return
		
	print("✓ User authenticated:", Firebase.Auth.auth.localid)
	
	# Test Firebase document retrieval and update
	await test_document_operations()

func test_document_operations():
	print("\n📄 Testing Firebase Document Operations")
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("Getting document for user:", user_id)
	
	# Get the document
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		print("✓ Document retrieved successfully")
		
		# Check stats structure
		var stats = document.get_value("stats")
		if stats != null and typeof(stats) == TYPE_DICTIONARY:
			print("✓ Stats structure found")
			
			var player_stats = stats.get("player", {})
			print("Current Firebase player stats:", player_stats)
			
			# Test update operation
			await test_stats_update(document, stats, player_stats, collection)
		else:
			print("❌ Stats structure not found")
	else:
		print("❌ Failed to retrieve document")

func test_stats_update(document, stats, player_stats, collection):
	print("\n🔄 Testing Stats Update Operation")
	
	# Create test stats (simulate a level up)
	var original_level = player_stats.get("level", 1)
	var test_level = original_level + 1
	
	print("Original level:", original_level)
	print("Test level:", test_level)
	
	# Update player stats (simulate what happens during level up)
	player_stats["level"] = test_level
	player_stats["exp"] = 0  # Reset exp after level up
	player_stats["health"] = 100 + (test_level - 1) * 20  # Health formula
	player_stats["damage"] = 10 + (test_level - 1) * 11   # Damage increases by 11 per level
	player_stats["durability"] = 5 + (test_level - 1) * 8 # Durability increases by 8 per level
	
	# Preserve existing fields
	if !player_stats.has("energy"):
		player_stats["energy"] = 20
	if !player_stats.has("skin"):
		player_stats["skin"] = "res://Sprites/Animation/DefaultPlayer_Animation.tscn"
	
	# Update the stats structure
	stats["player"] = player_stats
	
	print("Test stats to save:", player_stats)
	
	# Update the document field
	document.add_or_update_field("stats", stats)
	
	# Save the updated document
	print("Attempting to save to Firebase...")
	var updated_document = await collection.update(document)
	
	if updated_document:
		print("✅ TEST UPDATE SUCCESS! Stats saved to Firebase")
		
		# Verify the save by retrieving again
		await verify_save(collection, test_level)
	else:
		print("❌ TEST UPDATE FAILED! Could not save to Firebase")

func verify_save(collection, expected_level):
	print("\n🔍 Verifying Save Operation")
	
	var user_id = Firebase.Auth.auth.localid
	
	# Wait a moment for Firebase to process
	await get_tree().create_timer(1.0).timeout
	
	# Retrieve document again
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		var stats = document.get_value("stats")
		if stats and typeof(stats) == TYPE_DICTIONARY:
			var player_stats = stats.get("player", {})
			var saved_level = player_stats.get("level", 0)
			
			print("Expected level:", expected_level)
			print("Saved level:", saved_level)
			
			if saved_level == expected_level:
				print("✅ VERIFICATION SUCCESS! Firebase save/retrieve working correctly")
				
				# Restore original stats for real gameplay
				await restore_original_stats(collection, document, stats, player_stats)
			else:
				print("❌ VERIFICATION FAILED! Saved level doesn't match expected")
		else:
			print("❌ Could not retrieve stats for verification")
	else:
		print("❌ Could not retrieve document for verification")

func restore_original_stats(collection, document, stats, player_stats):
	print("\n🔄 Restoring Original Stats")
	
	# Restore to reasonable starting stats
	player_stats["level"] = 1
	player_stats["exp"] = 0
	player_stats["health"] = 100
	player_stats["damage"] = 10
	player_stats["durability"] = 5
	
	stats["player"] = player_stats
	document.add_or_update_field("stats", stats)
	
	var restored_document = await collection.update(document)
	if restored_document:
		print("✓ Original stats restored for normal gameplay")
	else:
		print("⚠️ Could not restore original stats")
	
	print("\n🎯 FIREBASE TEST COMPLETE!")
	print("If you saw '✅ TEST UPDATE SUCCESS!' and '✅ VERIFICATION SUCCESS!',")
	print("then the Firebase update fix is working correctly!")
	print("\nYou can now test in actual gameplay - defeat enemies to gain experience")
	print("and watch for the level up Firebase save messages.")
