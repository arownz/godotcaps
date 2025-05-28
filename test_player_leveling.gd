extends Node

# Test script to verify player leveling and Firebase updates
# This can be attached to a simple scene for testing

var player_manager

func _ready():
	print("=== TESTING PLAYER LEVELING AND FIREBASE UPDATES ===")
	
	# Wait a bit for Firebase to initialize
	await get_tree().create_timer(2.0).timeout
	
	# Get the player manager
	player_manager = get_node("/root/PlayerManager")
	if not player_manager:
		print("❌ PlayerManager not found!")
		return
	
	print("✓ PlayerManager found")
	
	# Print current player stats
	print("Current Player Stats:")
	print("  Level: ", player_manager.player_level)
	print("  Exp: ", player_manager.player_exp, "/", player_manager.get_max_exp())
	print("  Health: ", player_manager.player_max_health)
	print("  Damage: ", player_manager.player_damage)
	print("  Durability: ", player_manager.player_durability)
	
	# Wait a bit
	await get_tree().create_timer(1.0).timeout
	
	# Test 1: Add small experience (should not level up)
	print("\n=== TEST 1: Adding 5 experience (should not level up) ===")
	player_manager.add_experience(5)
	
	await get_tree().create_timer(2.0).timeout
	
	# Test 2: Force level up using debug function
	print("\n=== TEST 2: Forcing level up using debug function ===")
	player_manager.debug_force_level_up()
	
	await get_tree().create_timer(3.0).timeout
	
	# Print final stats
	print("\nFinal Player Stats:")
	print("  Level: ", player_manager.player_level)
	print("  Exp: ", player_manager.player_exp, "/", player_manager.get_max_exp())
	print("  Health: ", player_manager.player_max_health)
	print("  Damage: ", player_manager.player_damage)
	print("  Durability: ", player_manager.player_durability)
	
	print("\n=== TEST COMPLETE ===")
	print("Check the logs above for Firebase update status messages with ✓ or ✗ symbols")
