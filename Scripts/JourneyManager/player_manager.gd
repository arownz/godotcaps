extends Node
class_name PlayerManager

# Signals
signal player_health_changed(current_health, max_health)
signal player_defeated
signal player_experience_changed(current_exp, max_exp)
signal player_level_up(new_level)
signal player_skin_changed(skin_name)

# References
var battle_scene
var player_animation

# Player properties
var player_name = "Player"
var player_health = 100
var player_max_health = 100 # Max health is calculated based on level
var player_damage = 10
var player_exp = 0
var player_max_exp = 100 # Max exp needed for leveling up
var player_level = 1
var player_durability = 5
var player_energy = 20
var player_skin = "res://Sprites/Animation/Lexia_Animation.tscn"
var player_animation_scene = "res://Sprites/Animation/Lexia_Animation.tscn"

# Available player skins
var available_skins = ["lexia", "ragna"]
var current_skin = "lexia"

# Character bonuses (applied on top of base stats)
var character_bonuses = {
	"health": 0,
	"damage": 0,
	"durability": 0
}

# Base stats (without character bonuses)
var base_health = 100
var base_damage = 10
var base_durability = 5

# Track last level up stat increases for UI display (dyslexia-friendly progression)
var last_health_increase = 0
var last_damage_increase = 0
var last_durability_increase = 0

# Player data loaded from Firebase
var player_firebase_data = {}

# Default constructor
func _init(scene = null):
	if scene != null:
		battle_scene = scene

# Initialize with battle scene reference
func initialize(scene_ref):
	battle_scene = scene_ref
	
	print("PlayerManager: Initializing player manager")
	
	# Data should already be loaded from battlescene._ready(), so just load animation
	load_player_animation()
	
	print("PlayerManager: Player initialization complete - Level " + str(player_level) + " with " + str(player_damage) + " damage")

# Helper function to get character animation path from character name
func _get_character_animation_path(character_name: String) -> String:
	match character_name.to_lower():
		"lexia":
			return "res://Sprites/Animation/Lexia_Animation.tscn"
		"ragna":
			return "res://Sprites/Animation/Ragna_Animation.tscn"
		_:
			return "res://Sprites/Animation/Lexia_Animation.tscn"

func load_player_data_from_firebase():
	if not Firebase.Auth.auth:
		print("User not authenticated, cannot load player data")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("Loading player data for user: " + user_id)
	
	var document = await collection.get_doc(user_id)
	if document:
		# Get username from root level
		player_name = document.get_value("username") if document.get_value("username") else "Player"
		
		# Extract player stats from Firebase document
		var stats_data = document.get_value("stats")
		var profile_data = document.get_value("profile")
		
		# Get username from profile data
		if profile_data and profile_data.has("username"):
			player_name = profile_data["username"]
		else:
			player_name = "Player" # Default fallback
		
		if stats_data and stats_data.has("player"):
			var player_data = stats_data["player"]
			
			# Get current character first to determine bonuses
			current_skin = player_data.get("current_character", "lexia")
			player_animation_scene = _get_character_animation_path(current_skin)
			
			# Get character bonuses from character data
			var character_stat_bonuses = _get_character_bonuses(current_skin)
			
			# Load base stats first - these are the stats that increase with leveling up
			base_health = player_data.get("base_health", 100)
			base_damage = player_data.get("base_damage", 10)
			base_durability = player_data.get("base_durability", 5)
			
			# Check if base stats exist in Firebase
			var base_stats_exist = player_data.has("base_health") and player_data.has("base_damage") and player_data.has("base_durability")
			
			if not base_stats_exist:
				# For NEW accounts or OLD saves without base stats
				print("PlayerManager: Base stats not found in Firebase - initializing with character bonuses")
				
				# Get current health/damage/durability from Firebase (may or may not have bonuses)
				var current_health = player_data.get("health", 100)
				var current_damage = player_data.get("damage", 10)
				var current_durability = player_data.get("durability", 5)
				
				# CRITICAL FIX: For new accounts, stats are stored WITHOUT bonuses
				# So we need to ADD the character bonuses now
				base_health = current_health
				base_damage = current_damage
				base_durability = current_durability
				
				# Apply character bonuses on top of base stats
				player_max_health = base_health + character_stat_bonuses["health"]
				player_damage = base_damage + character_stat_bonuses["damage"]
				player_durability = base_durability + character_stat_bonuses["durability"]
				
				print("PlayerManager: Applying ", current_skin, " bonuses (+", character_stat_bonuses["health"], " HP, +", character_stat_bonuses["damage"], " DMG, +", character_stat_bonuses["durability"], " DUR)")
				
				# Save base stats to Firebase for future loads
				await _save_base_stats_to_firebase(base_health, base_damage, base_durability)
			else:
				# Base stats exist - use them and apply bonuses correctly
				print("PlayerManager: Loading with base stats and character bonuses")
				player_max_health = base_health + character_stat_bonuses["health"]
				player_damage = base_damage + character_stat_bonuses["damage"]
				player_durability = base_durability + character_stat_bonuses["durability"]
			
			# Update player stats
			player_level = player_data.get("level", 1)
			player_exp = player_data.get("exp", 0)
			player_health = player_max_health
			player_energy = player_data.get("energy", 20)
			
			# Store current character bonuses
			character_bonuses["health"] = character_stat_bonuses["health"]
			character_bonuses["damage"] = character_stat_bonuses["damage"]
			character_bonuses["durability"] = character_stat_bonuses["durability"]
			
			player_firebase_data = {
				"username": player_name,
				"level": player_level,
				"exp": player_exp,
				"health": player_max_health,
				"damage": player_damage,
				"durability": player_durability,
				"energy": player_energy
			}
			
			print("Player data loaded successfully:")
			print("- Username: ", player_name)
			print("- Level: ", player_level)
			print("- Health: ", player_health, "/", player_max_health)
			print("- Damage: ", player_damage)
			print("- Durability: ", player_durability)
			print("- Character: ", current_skin, " (Bonuses: ", character_bonuses, ")")
			print("- Energy: ", player_energy)
			print("- Skin: ", player_animation_scene)
			print("- Damage: ", player_damage)
			print("- Durability: ", player_durability)
			print("- Energy: ", player_energy)
			print("- Skin: ", player_animation_scene)
		else:
			print("No player stats found in Firebase, using defaults")
			_set_default_stats()
	else:
		print("Could not load player document from Firebase")
		_set_default_stats()

func _set_default_player_data():
	player_firebase_data = {
		"username": "Player",
		"level": 1,
		"exp": 0,
		"health": 100,
		"damage": 10,
		"durability": 5,
		"energy": 20
	}

func _set_default_stats():
	# Set default values if Firebase data is not available
	player_level = 1
	player_exp = 0
	player_max_health = 100
	player_health = player_max_health
	player_damage = 10
	player_durability = 5
	player_energy = 20
	player_animation_scene = "res://Sprites/Animation/Lexia_Animation.tscn"

func _load_player_stats():
	# This function is kept for backward compatibility
	# Firebase data should already be loaded directly in load_player_data_from_firebase()
	# Only use this if player_firebase_data is populated
	if player_firebase_data.size() > 0:
		player_name = player_firebase_data.get("username", "Player")
		player_level = player_firebase_data.get("level", 1)
		player_exp = player_firebase_data.get("exp", 0)
		player_max_health = player_firebase_data.get("health", 100)
		player_health = player_max_health
		player_damage = player_firebase_data.get("damage", 10)
		player_durability = player_firebase_data.get("durability", 5)
		
		# Calculate exp needed for next level
		player_max_exp = _calculate_exp_for_level(player_level + 1)
		
		print("PlayerManager: Loaded player stats from cache - " + player_name + " Level " + str(player_level))
	else:
		print("PlayerManager: No cached data available, stats should be loaded from Firebase directly")

func _calculate_exp_for_level(level: int) -> int:
	# Flat 100 exp per level for dyslexic learners - consistent and predictable
	# This creates steady progression that's easy to understand and track
	# Since stat bonuses are now low, consistent exp requirements help motivation
	if level == 1:
		return 0 # Level 1 requires 0 exp
	else:
		# Flat 100 exp needed for every level up - simple and dyslexia-friendly
		return 100

# Load player animation (fixed implementation)
func load_player_animation():
	print("PlayerManager: Loading player animation from: " + str(player_animation_scene))
	
	if player_animation_scene and player_animation_scene != "":
		var scene_resource = load(player_animation_scene)
		if scene_resource:
			var player_sprite = scene_resource.instantiate()
			
			# Add to player position node
			var player_position = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerPosition")
			
			# Clear any existing player sprite
			for child in player_position.get_children():
				child.queue_free()
			
			# Add new player sprite
			player_position.add_child(player_sprite)
			
			# Set the player_animation reference
			player_animation = player_sprite
			
			# Set player name if the sprite has that property
			if player_sprite.has_method("set_player_name"):
				player_sprite.set_player_name(player_name)
			
			# Start idle animation
			var sprite = player_animation.get_node_or_null("AnimatedSprite2D")
			if sprite:
				sprite.play("battle_idle")
			
			print("PlayerManager: Player animation loaded successfully")
		else:
			print("PlayerManager: Could not load animation scene: " + str(player_animation_scene))
			_load_default_animation()
	else:
		print("PlayerManager: No animation scene specified, using default")
		_load_default_animation()

func _load_default_animation():
	# Load default player animation as fallback
	var default_scene = load("res://Sprites/Animation/Lexia_Animation.tscn")
	if default_scene:
		var player_sprite = default_scene.instantiate()
		var player_position = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerPosition")
		
		# Clear any existing sprites
		for child in player_position.get_children():
			child.queue_free()
		
		player_position.add_child(player_sprite)
		player_animation = player_sprite # Set the animation reference
		
		# Start idle animation
		var sprite = player_animation.get_node_or_null("AnimatedSprite2D")
		if sprite:
			sprite.play("battle_idle")
		
		print("PlayerManager: Default animation loaded")
	else:
		print("PlayerManager: Could not load default animation")

# Regular battle methods
func take_damage(damage_amount):
	print("Player taking damage: " + str(damage_amount))
	
	# Apply damage reduction based on durability (percentage-based reduction)
	# Each point of durability reduces damage by 5% (capped at 75% reduction)
	var damage_reduction_percent = min(0.75, player_durability * 0.05)
	var reduced_damage = max(1, int(damage_amount * (1.0 - damage_reduction_percent)))
	
	player_health = max(0, player_health - reduced_damage)
	
	print("After durability reduction: " + str(reduced_damage) + " damage applied")
	print("Player health now: " + str(player_health) + "/" + str(player_max_health))
	
	# Update UI
	update_health_bar()
	
	# Emit signal
	emit_signal("player_health_changed", player_health, player_max_health)
	
	# Play hit animation
	if player_animation and player_animation.get_node("AnimatedSprite2D"):
		player_animation.get_node("AnimatedSprite2D").play("hurt")
		# Play player hurt sound effect if available
		_play_attack_sound("player_hurt")
	
	# Check if player is defeated
	if player_health <= 0:
		# Handle defeat logic
		if player_animation and player_animation.get_node("AnimatedSprite2D"):
			player_animation.get_node("AnimatedSprite2D").play("dead")
		
		emit_signal("player_defeated")
	
	return reduced_damage

# Play auto attack animation and sound effect - with damage timing callback
func perform_auto_attack(damage_callback = null):
	print("PlayerManager: Performing auto attack")
	
	# Play auto attack animation
	if player_animation and player_animation.get_node("AnimatedSprite2D"):
		var sprite = player_animation.get_node("AnimatedSprite2D")
		sprite.play("auto_attack")
		
		# Create timer to sync damage with impact moment (adjusted for 12 FPS)
		var delay_timer = Timer.new()
		add_child(delay_timer)
		delay_timer.wait_time = 0.25 # Impact at ~3rd frame of 6-frame animation at 12 FPS
		delay_timer.one_shot = true
		delay_timer.start()
		
		# Wait for the strike moment, then play sound and trigger damage
		await delay_timer.timeout
		_play_attack_sound("player_autoattack")
		
		# Call damage callback at the exact moment of impact
		if damage_callback:
			damage_callback.call()
		
		delay_timer.queue_free()
		
		# Wait for animation to finish, then return to idle
		await sprite.animation_finished
		sprite.play("battle_idle")

# Play counter attack animation and sound effect - with damage timing callback
func perform_counter_attack(damage_callback = null):
	print("PlayerManager: Performing counter attack")
	
	# Play counter attack animation
	if player_animation and player_animation.get_node("AnimatedSprite2D"):
		var sprite = player_animation.get_node("AnimatedSprite2D")
		sprite.play("counter")
		
		var delay_timer = Timer.new()
		add_child(delay_timer)
		delay_timer.wait_time = 0.9
		delay_timer.one_shot = true
		delay_timer.start()
		
		# Wait for the strike moment, then play sound and trigger damage
		await delay_timer.timeout
		_play_attack_sound("player_counter")
		
		# Call damage callback at the exact moment of impact
		if damage_callback:
			damage_callback.call()
		
		delay_timer.queue_free()
		
		# Wait for animation to finish, then return to idle
		await sprite.animation_finished
		sprite.play("battle_idle") # Helper function to play attack sound effects
func _play_attack_sound(sound_node_name: String):
	if player_animation:
		var sound_player = player_animation.get_node_or_null(sound_node_name)
		if sound_player and sound_player.has_method("play"):
			sound_player.play()
			print("PlayerManager: Playing sound effect: " + sound_node_name)
		else:
			print("PlayerManager: Sound node not found: " + sound_node_name) # Add experience and handle leveling up
func add_experience(exp_amount):
	print("PlayerManager: add_experience called with ", exp_amount, " exp")
	print("PlayerManager: Current stats before exp gain - Level: ", player_level, ", Exp: ", player_exp, "/", get_max_exp())
	
	# Add experience
	player_exp += exp_amount
	
	# Get calculated max exp
	var max_exp = get_max_exp()
	
	# Emit signal with current and max exp
	emit_signal("player_experience_changed", player_exp, max_exp)
	
	# Check for level up
	var leveled_up = false
	while player_exp >= max_exp:
		player_exp -= max_exp
		player_level += 1
		
		# Balanced stat growth for dyslexic children with STAT CAPS for balance
		# Randomized increases with maximum limits to prevent overpowered progression
		var health_increase = 0
		var damage_increase = 0
		var durability_increase = 0
		
		# Define maximum base stats (before character bonuses are applied)
		var max_base_health = 115 # From starting 100 + max 15
		var max_base_damage = 18 # From starting 10 + max 8
		var max_base_durability = 11 # From starting 5 + max 6
		
		# Calculate potential increases with stat caps
		var health_room = max(0, max_base_health - base_health)
		var damage_room = max(0, max_base_damage - base_damage)
		var durability_room = max(0, max_base_durability - base_durability)
		
		# Determine actual increases based on available room and level ranges
		if player_level <= 10:
			# Early-mid game - moderate growth with caps
			health_increase = min(health_room, randi_range(2, 4)) # 2-4 health (capped)
			damage_increase = min(damage_room, randi_range(0, 1)) # 0-1 damage (capped)
			durability_increase = min(durability_room, randi_range(0, 1)) # 0-1 durability (capped)
		elif player_level <= 20:
			# Mid-late game - minimal growth with caps
			health_increase = min(health_room, randi_range(1, 3)) # 1-3 health (capped)
			damage_increase = min(damage_room, randi_range(0, 1)) # 0-1 damage (capped)
			durability_increase = min(durability_room, randi_range(0, 1)) # 0-1 durability (capped)
		else:
			# Late game - barely any growth with caps
			health_increase = min(health_room, randi_range(1, 2)) # 1-2 health (capped)
			damage_increase = min(damage_room, randi_range(0, 1)) # 0-1 damage (capped)
			durability_increase = min(durability_room, randi_range(0, 1)) # 0-1 durability (capped)
		
		# Store stat increases for UI display
		last_health_increase = health_increase
		last_damage_increase = damage_increase
		last_durability_increase = durability_increase
		
		# Apply stat increases to BASE stats (these are what level up affects)
		base_health += health_increase
		base_damage += damage_increase
		base_durability += durability_increase
		
		# Apply increases to current stats (base + character bonuses)
		player_max_health = base_health + character_bonuses["health"]
		player_health = player_max_health # Fully heal on level up
		player_damage = base_damage + character_bonuses["damage"]
		player_durability = base_durability + character_bonuses["durability"]
		
		# Log stat increases with cap information
		print("PlayerManager: Level up stat increases - Health: +", health_increase, ", Damage: +", damage_increase, ", Durability: +", durability_increase)
		print("PlayerManager: Current base stats - Health: ", base_health, "/", max_base_health, ", Damage: ", base_damage, "/", max_base_damage, ", Durability: ", base_durability, "/", max_base_durability)
		print("PlayerManager: Final stats (with character bonuses) - Health: ", player_max_health, ", Damage: ", player_damage, ", Durability: ", player_durability)
		
		# Recalculate max_exp for next level
		max_exp = get_max_exp()
		leveled_up = true
		
	print("PlayerManager: Current stats after exp gain - Level: ", player_level, ", Exp: ", player_exp, "/", get_max_exp())
	
	if leveled_up:
		# Emit level up signal
		emit_signal("player_level_up", player_level)
		
		print("PlayerManager: PLAYER LEVELED UP! New level: ", player_level)
		print("PlayerManager: New stats - Health: ", player_max_health, ", Damage: ", player_damage, ", Durability: ", player_durability)
		
		# Update all UI elements that depend on level up
		if battle_scene and battle_scene.ui_manager:
			battle_scene.ui_manager.update_player_health() # Update health bar with new max health
			battle_scene.ui_manager.update_player_exp() # Update exp bar with new values
			battle_scene.ui_manager.update_power_bar(player_damage) # Update power bar
			battle_scene.ui_manager.update_durability_bar(player_durability) # Update durability bar
			battle_scene.ui_manager.update_player_info() # Update player level display
		
		# Update Firebase stats - using same pattern as _update_player_stats_in_firebase method
		print("PlayerManager: Updating Firebase after level up...")
		await _update_player_stats_in_firebase(true)
		print("PlayerManager: Firebase update completed")
	else:
		print("PlayerManager: Experience added, no level up. Current exp: ", player_exp, "/", get_max_exp())
		
		# Update Firebase even without level up to save current exp progress
		print("PlayerManager: Updating Firebase with current exp progress...")
		await _update_player_stats_in_firebase(false)
		print("PlayerManager: Firebase exp update completed")

# Heal player to full health
func heal_to_full():
	print("PlayerManager: Healing player to full health")
	player_health = player_max_health
	
	# Update UI
	if battle_scene and battle_scene.ui_manager:
		battle_scene.ui_manager.update_player_health()
	
	# Emit signal
	emit_signal("player_health_changed", player_health, player_max_health)
	
	print("PlayerManager: Player healed - Health: " + str(player_health) + "/" + str(player_max_health))

# Update player stats in Firebase after level up - FIXED to follow exact working pattern from mainmenu.gd
func _update_player_stats_in_firebase(leveled_up: bool = false):
	print("PlayerManager: _update_player_stats_in_firebase called with leveled_up=", leveled_up)
	print("PlayerManager: Firebase.Auth: ", Firebase.Auth)
	print("PlayerManager: Firebase.Auth.auth: ", Firebase.Auth.auth if Firebase.Auth else "N/A")
	
	if !Firebase.Auth.auth:
		print("PlayerManager: No Firebase auth, returning")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("PlayerManager: Getting document for user: ", user_id)
	print("PlayerManager: Collection object: ", collection)
	
	# Get the document first using exact same pattern as working energy update
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		print("PlayerManager: Document retrieved successfully")
		
		# Get current stats structure - exact same pattern as mainmenu.gd energy update
		var stats = document.get_value("stats")
		if stats != null and typeof(stats) == TYPE_DICTIONARY:
			print("PlayerManager: Stats structure found")
			var player_stats = stats.get("player", {})
			
			print("PlayerManager: Current Firebase player stats: ", player_stats)
			print("PlayerManager: Updating with local stats - Level: ", player_level, ", Exp: ", player_exp, ", Health: ", player_max_health, ", Damage: ", player_damage, ", Durability: ", player_durability)
			
			# Update player stats using exact same pattern as energy update
			player_stats["level"] = player_level
			player_stats["exp"] = player_exp
			player_stats["health"] = player_max_health # Store max health as health field
			player_stats["damage"] = player_damage
			player_stats["durability"] = player_durability
			# Store base stats separately for character bonus calculations
			player_stats["base_health"] = base_health
			player_stats["base_damage"] = base_damage
			player_stats["base_durability"] = base_durability
			# Preserve existing energy and character fields
			if !player_stats.has("energy"):
				player_stats["energy"] = 20
			if !player_stats.has("current_character"):
				player_stats["current_character"] = "lexia"
				
			# Update the stats structure - exact same pattern as mainmenu.gd
			stats["player"] = player_stats
			
			print("PlayerManager: Final player stats to save: ", player_stats)
			
			# Update the document field - exact same pattern as energy update
			document.add_or_update_field("stats", stats)
			
			# Save the updated document - exact same pattern as energy update
			var updated_document = await collection.update(document)
			if updated_document:
				print("PlayerManager: Player stats updated in Firebase successfully!")
				if leveled_up:
					print("PlayerManager: LEVEL UP SAVED! New level: " + str(player_level))
					print("PlayerManager: New stats saved - Health: " + str(player_max_health) + ", Damage: " + str(player_damage) + ", Durability: " + str(player_durability))
			else:
				print("PlayerManager: Failed to update player stats in Firebase")
		else:
			print("PlayerManager: Stats structure not found in document")
	else:
		print("PlayerManager: Failed to get document for player stats update")

# Calculate max health based on level (100 + 10 per level)
func get_max_health():
	return 100 + (player_level - 1) * 20

# Calculate max experience needed for level up
func get_max_exp():
	# Use Pokemon-like scaling system
	return _calculate_exp_for_level(player_level + 1)

# Update health bar UI
func update_health_bar():
	# Use the UI manager to update both health bars (battle area and stats panel)
	if battle_scene and battle_scene.ui_manager:
		battle_scene.ui_manager.update_player_health()

# Update UI elements
func update_ui_elements():
	if battle_scene:
		# Update player name
		var player_name_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerName")
		if player_name_label:
			player_name_label.text = player_name
			
		# Update health bar
		update_health_bar()

# Change player skin
func change_player_skin(skin_name):
	if available_skins.has(skin_name):
		current_skin = skin_name
		
		# Update skin path based on the skin name
		if skin_name == "lexia":
			player_skin = "res://Sprites/Animation/Lexia_Animation.tscn"
		else:
			# Try to load animation scene first, fall back to texture
			var animation_path = "res://Sprites/Animation/" + skin_name + "_Animation.tscn"
			if ResourceLoader.exists(animation_path):
				player_skin = animation_path
		
		# Reload player animation
		load_player_animation()
		
		# Emit signal that skin changed
		emit_signal("player_skin_changed", skin_name)
		return true
	
	return false

# Reset animation to idle
func reset_animation():
	if player_animation and player_animation.get_node("AnimatedSprite2D"):
		player_animation.get_node("AnimatedSprite2D").play("battle_idle")

func update_firebase_stats():
	"""Update player stats in Firebase after battles"""
	if !Firebase.Auth.auth:
		return
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document to preserve other fields
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		# Get current stats structure (following mainmenu.gd pattern)
		var stats = document.get_value("stats")
		if stats != null and typeof(stats) == TYPE_DICTIONARY:
			var player_stats = stats.get("player", {})
			
			# Update player stats in the nested structure
			player_stats["level"] = player_level
			player_stats["exp"] = player_exp
			player_stats["health"] = player_max_health
			player_stats["damage"] = player_damage
			player_stats["durability"] = player_durability
			
			# Update the stats structure
			stats["player"] = player_stats
			
			# Update the document with the modified stats structure
			document.add_or_update_field("stats", stats)
			
			# Save the updated document
			var updated_document = await collection.update(document)
			if updated_document:
				print("Player stats updated in Firebase after battle")
			else:
				print("Failed to update player stats in Firebase after battle")
		else:
			print("Stats structure not found in document for battle update")
	else:
		print("Failed to get document for battle stats update")

# Test function to verify Firebase updates work correctly after battles
func test_battle_exp_gain():
	print("=== TESTING BATTLE EXP GAIN AND FIREBASE UPDATE ===")
	print("Before battle: Level " + str(player_level) + ", Exp " + str(player_exp) + ", Health " + str(player_max_health) + ", Damage " + str(player_damage) + ", Durability " + str(player_durability))
	
	# Simulate gaining exp from defeating an enemy (like in battle_manager.gd)
	var exp_reward = 50 # Typical reward amount
	print("Simulating exp gain of " + str(exp_reward) + " exp from defeating enemy...")
	
	# Call add_experience just like battle_manager does
	await add_experience(exp_reward)
	
	print("After exp gain: Level " + str(player_level) + ", Exp " + str(player_exp) + ", Health " + str(player_max_health) + ", Damage " + str(player_damage) + ", Durability " + str(player_durability))
	print("=== BATTLE EXP TEST COMPLETE ===")
	
	# Verify Firebase was updated by checking if we can load the data back
	print("=== VERIFYING FIREBASE UPDATE ===")
	await _verify_firebase_update()
	
func _verify_firebase_update():
	if !Firebase.Auth.auth:
		print("No Firebase auth for verification")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get fresh document from Firebase
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		var stats = document.get_value("stats")
		if stats and stats.has("player"):
			var firebase_player_stats = stats["player"]
			print("Firebase verification - Level: " + str(firebase_player_stats.get("level", "ERROR")) +
				", Exp: " + str(firebase_player_stats.get("exp", "ERROR")) +
				", Health: " + str(firebase_player_stats.get("health", "ERROR")) +
				", Damage: " + str(firebase_player_stats.get("damage", "ERROR")) +
				", Durability: " + str(firebase_player_stats.get("durability", "ERROR")))
			
			# Compare with local values
			var local_matches_firebase = (
				firebase_player_stats.get("level") == player_level and
				firebase_player_stats.get("exp") == player_exp and
				firebase_player_stats.get("health") == player_max_health and
				firebase_player_stats.get("damage") == player_damage and
				firebase_player_stats.get("durability") == player_durability
			)
			
			if local_matches_firebase:
				print("SUCCESS: Local player stats match Firebase data!")
			else:
				print("MISMATCH: Local and Firebase data don't match!")
		else:
			print("ERROR: No player stats found in Firebase document")
	else:
		print("ERROR: Could not retrieve document from Firebase")
	
	print("=== FIREBASE VERIFICATION COMPLETE ===")

# Temporary test function to verify Firebase level-up updates work

# Helper function to get character bonuses from character name
func _get_character_bonuses(character_name: String) -> Dictionary:
	"""Get stat bonuses for a specific character"""
	var character_data = {
		"lexia": {
			"health": 5,
			"damage": 3,
			"durability": 2
		},
		"ragna": {
			"health": - 10,
			"damage": 15,
			"durability": - 2
		}
	}
	
	var char_key = character_name.to_lower()
	if character_data.has(char_key):
		return character_data[char_key]
	else:
		# Return default bonuses (none) for unknown characters
		return {"health": 0, "damage": 0, "durability": 0}

# Helper function to save base stats to Firebase
func _save_base_stats_to_firebase(health: int, damage: int, durability: int):
	"""Save base stats to Firebase for persistence"""
	if not Firebase.Auth.auth:
		print("PlayerManager: Cannot save base stats - no authentication")
		return
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document
	var document = await collection.get_doc(user_id)
	if document and not ("error" in document.keys() and document.get_value("error")):
		var stats = document.get_value("stats")
		if stats and typeof(stats) == TYPE_DICTIONARY:
			var player_stats = stats.get("player", {})
			
			# Add base stats
			player_stats["base_health"] = health
			player_stats["base_damage"] = damage
			player_stats["base_durability"] = durability
			
			# Update current stats with bonuses applied
			player_stats["health"] = player_max_health
			player_stats["damage"] = player_damage
			player_stats["durability"] = player_durability
			
			# Save back
			stats["player"] = player_stats
			document.add_or_update_field("stats", stats)
			
			var updated_doc = await collection.update(document)
			if updated_doc:
				print("PlayerManager: Base stats saved to Firebase")
			else:
				print("PlayerManager: Failed to save base stats to Firebase")

func test_firebase_level_up():
	print("=== TESTING FIREBASE LEVEL-UP UPDATE ===")
	print("Before: Level " + str(player_level) + ", Exp " + str(player_exp) + ", Health " + str(player_max_health) + ", Damage " + str(player_damage) + ", Durability " + str(player_durability))
	
	# Add enough experience to level up (simulate winning a battle)
	var exp_needed = get_max_exp() - player_exp + 1
	await add_experience(exp_needed)
	
	print("After: Level " + str(player_level) + ", Exp " + str(player_exp) + ", Health " + str(player_max_health) + ", Damage " + str(player_damage) + ", Durability " + str(player_durability))
	print("=== TEST COMPLETE ===")
