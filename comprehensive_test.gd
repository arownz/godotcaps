extends Node

# Comprehensive test for player leveling and Firebase updates
# This script tests the complete flow from experience gain to Firebase persistence

var player_manager
var test_results = []

func _ready():
	print("=== COMPREHENSIVE PLAYER LEVELING AND FIREBASE TEST ===")
	print("Testing the complete flow: Experience → Level Up → Firebase Update")
	
	# Wait for Firebase to initialize
	await get_tree().create_timer(3.0).timeout
	
	# Get player manager
	player_manager = get_node("/root/PlayerManager")
	if not player_manager:
		print("❌ CRITICAL: PlayerManager not found!")
		return
	
	print("✓ PlayerManager found")
	await run_comprehensive_tests()

func run_comprehensive_tests():
	print("\n" + "=".repeat(60))
	print("STARTING COMPREHENSIVE TESTS")
	print("=".repeat(60))
	
	# Test 1: Check Firebase connectivity
	await test_firebase_connectivity()
	
	# Test 2: Record initial stats
	await test_record_initial_stats()
	
	# Test 3: Test small experience gain (no level up)
	await test_small_experience_gain()
	
	# Test 4: Test level up scenario
	await test_level_up_scenario()
	
	# Test 5: Verify Firebase persistence
	await test_firebase_persistence()
	
	# Print final results
	print_test_results()

func test_firebase_connectivity():
	print("\n🔍 TEST 1: Firebase Connectivity")
	
	if not Engine.has_singleton("Firebase"):
		test_results.append("❌ Firebase singleton not found")
		return
	
	test_results.append("✓ Firebase singleton found")
	
	if not Firebase.Auth:
		test_results.append("❌ Firebase.Auth not available")
		return
	
	test_results.append("✓ Firebase.Auth available")
	
	if not Firebase.Auth.auth:
		test_results.append("⚠️ User not authenticated (this may cause Firebase updates to fail)")
		return
	
	test_results.append("✓ User authenticated: " + str(Firebase.Auth.auth.localid))

func test_record_initial_stats():
	print("\n📊 TEST 2: Recording Initial Stats")
	
	var initial_stats = {
		"level": player_manager.player_level,
		"exp": player_manager.player_exp,
		"max_exp": player_manager.get_max_exp(),
		"health": player_manager.player_max_health,
		"damage": player_manager.player_damage,
		"durability": player_manager.player_durability
	}
	
	print("Initial Player Stats:")
	for key in initial_stats:
		print("  ", key, ": ", initial_stats[key])
	
	test_results.append("✓ Initial stats recorded")

func test_small_experience_gain():
	print("\n🎯 TEST 3: Small Experience Gain (No Level Up)")
	
	var initial_exp = player_manager.player_exp
	var initial_level = player_manager.player_level
	
	print("Adding 10 experience points...")
	player_manager.add_experience(10)
	
	await get_tree().create_timer(2.0).timeout
	
	var exp_gained = player_manager.player_exp - initial_exp
	var level_changed = player_manager.player_level != initial_level
	
	if exp_gained == 10 and not level_changed:
		test_results.append("✓ Small experience gain working correctly")
	else:
		test_results.append("❌ Small experience gain failed - gained: " + str(exp_gained) + ", level changed: " + str(level_changed))

func test_level_up_scenario():
	print("\n🚀 TEST 4: Level Up Scenario")
	
	var initial_level = player_manager.player_level
	var initial_health = player_manager.player_max_health
	var initial_damage = player_manager.player_damage
	var initial_durability = player_manager.player_durability
	
	print("Current level: ", initial_level)
	print("Experience needed to level up: ", player_manager.get_max_exp() - player_manager.player_exp)
	
	print("Triggering debug force level up...")
	player_manager.debug_force_level_up()
	
	# Wait for Firebase operations to complete
	await get_tree().create_timer(5.0).timeout
	
	var level_increased = player_manager.player_level > initial_level
	var health_increased = player_manager.player_max_health > initial_health
	var damage_increased = player_manager.player_damage > initial_damage
	var durability_increased = player_manager.player_durability > initial_durability
	
	print("Level up results:")
	print("  Level: ", initial_level, " → ", player_manager.player_level, " (", "✓" if level_increased else "❌", ")")
	print("  Health: ", initial_health, " → ", player_manager.player_max_health, " (", "✓" if health_increased else "❌", ")")
	print("  Damage: ", initial_damage, " → ", player_manager.player_damage, " (", "✓" if damage_increased else "❌", ")")
	print("  Durability: ", initial_durability, " → ", player_manager.player_durability, " (", "✓" if durability_increased else "❌", ")")
	
	if level_increased and health_increased and damage_increased and durability_increased:
		test_results.append("✓ Level up mechanics working correctly")
	else:
		test_results.append("❌ Level up mechanics failed")

func test_firebase_persistence():
	print("\n💾 TEST 5: Firebase Persistence Verification")
	
	if not Firebase.Auth.auth:
		test_results.append("⚠️ Cannot test Firebase persistence - not authenticated")
		return
	
	print("Attempting to verify Firebase data...")
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		var stats = document.get_value("stats")
		if stats and typeof(stats) == TYPE_DICTIONARY:
			var player_stats = stats.get("player", {})
			
			print("Firebase player stats:")
			print("  Level: ", player_stats.get("level", "not found"))
			print("  Exp: ", player_stats.get("exp", "not found"))
			print("  Health: ", player_stats.get("health", "not found"))
			print("  Damage: ", player_stats.get("damage", "not found"))
			print("  Durability: ", player_stats.get("durability", "not found"))
			
			# Compare with local stats
			var stats_match = (
				player_stats.get("level") == player_manager.player_level and
				player_stats.get("exp") == player_manager.player_exp and
				player_stats.get("health") == player_manager.player_max_health and
				player_stats.get("damage") == player_manager.player_damage and
				player_stats.get("durability") == player_manager.player_durability
			)
			
			if stats_match:
				test_results.append("✓ Firebase stats match local stats - persistence working!")
			else:
				test_results.append("❌ Firebase stats don't match local stats - persistence may have failed")
		else:
			test_results.append("❌ Could not find player stats in Firebase document")
	else:
		test_results.append("❌ Failed to retrieve Firebase document")

func print_test_results():
	print("\n" + "=".repeat(60))
	print("TEST RESULTS SUMMARY")
	print("=".repeat(60))
	
	var passed = 0
	var failed = 0
	var warnings = 0
	
	for result in test_results:
		print(result)
		if result.begins_with("✓"):
			passed += 1
		elif result.begins_with("❌"):
			failed += 1
		elif result.begins_with("⚠️"):
			warnings += 1
	
	print("\nSUMMARY:")
	print("  ✓ Passed: ", passed)
	print("  ❌ Failed: ", failed) 
	print("  ⚠️ Warnings: ", warnings)
	
	if failed == 0:
		print("\n🎉 ALL TESTS PASSED! The Firebase update fix appears to be working.")
	else:
		print("\n⚠️ Some tests failed. Check the logs above for details.")
	
	print("\n💡 NEXT STEPS:")
	print("1. If Firebase persistence failed, check authentication status")
	print("2. Look for Firebase error messages in the console")
	print("3. Try defeating enemies in actual gameplay to test the real flow")
	print("4. Check Firebase console to verify data is being saved")
	
	print("\n" + "=".repeat(60))
