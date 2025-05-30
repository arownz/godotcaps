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
var player_max_health = 100  # Max health is calculated based on level
var player_damage = 10
var player_exp = 0
var player_max_exp = 100  # Max exp needed for leveling up
var player_level = 1
var player_durability = 5
var player_energy = 20
var player_skin = "res://Sprites/Animation/DefaultPlayer_Animation.tscn"
var player_animation_scene = "res://Sprites/Animation/DefaultPlayer_Animation.tscn"

# Available player skins
var available_skins = ["default", "magi", "ragnar"] 
var current_skin = "default"

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
            player_name = "Player"  # Default fallback
        
        if stats_data and stats_data.has("player"):
            var player_data = stats_data["player"]
            
            # Update player stats directly from Firebase data
            player_level = player_data.get("level", 1)
            player_exp = player_data.get("exp", 0)
            player_max_health = player_data.get("health", 100)
            player_health = player_max_health
            player_damage = player_data.get("damage", 10)
            player_durability = player_data.get("durability", 5)
            player_energy = player_data.get("energy", 20)
            player_animation_scene = player_data.get("skin", "res://Sprites/Animation/DefaultPlayer_Animation.tscn")
            
            # Also populate player_firebase_data for backward compatibility
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
    player_animation_scene = "res://Sprites/Animation/DefaultPlayer_Animation.tscn"

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
    # Simple exp calculation: level * 100
    return level * 100

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
    var default_scene = load("res://Sprites/Animation/DefaultPlayer_Animation.tscn")
    if default_scene:
        var player_sprite = default_scene.instantiate()
        var player_position = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerPosition")
        
        # Clear any existing sprites
        for child in player_position.get_children():
            child.queue_free()
        
        player_position.add_child(player_sprite)
        player_animation = player_sprite  # Set the animation reference
        
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
    
    # Check if player is defeated
    if player_health <= 0:
        # Handle defeat logic
        if player_animation and player_animation.get_node("AnimatedSprite2D"):
            player_animation.get_node("AnimatedSprite2D").play("dead")
        
        emit_signal("player_defeated")
    
    return reduced_damage

# Add experience and handle leveling up
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
        
        # Update stats on level up
        player_max_health = get_max_health()
        player_health = player_max_health  # Fully heal on level up
        player_damage += 11
        player_durability += 8
        
        # Recalculate max_exp for next level
        max_exp = get_max_exp()
        leveled_up = true
        
    print("PlayerManager: Current stats after exp gain - Level: ", player_level, ", Exp: ", player_exp, "/", get_max_exp())
    
    if leveled_up:
        # Emit level up signal
        emit_signal("player_level_up", player_level)
        
        print("PlayerManager: ✓ PLAYER LEVELED UP! New level: ", player_level)
        print("PlayerManager: ✓ New stats - Health: ", player_max_health, ", Damage: ", player_damage, ", Durability: ", player_durability)
        
        # Update all UI elements that depend on level up
        if battle_scene and battle_scene.ui_manager:
            battle_scene.ui_manager.update_player_health()  # Update health bar with new max health
            battle_scene.ui_manager.update_player_exp()     # Update exp bar with new values
            battle_scene.ui_manager.update_power_bar(player_damage)    # Update power bar
            battle_scene.ui_manager.update_durability_bar(player_durability)  # Update durability bar
            battle_scene.ui_manager.update_player_info()    # Update player level display
        
        # Update Firebase stats - using same pattern as _update_player_stats_in_firebase method
        print("PlayerManager: ✓ Updating Firebase after level up...")
        await _update_player_stats_in_firebase(true)
        print("PlayerManager: ✓ Firebase update completed")
    else:
        print("PlayerManager: Experience added, no level up. Current exp: ", player_exp, "/", get_max_exp())
        
        # Update Firebase even without level up to save current exp progress
        print("PlayerManager: ✓ Updating Firebase with current exp progress...")
        await _update_player_stats_in_firebase(false)
        print("PlayerManager: ✓ Firebase exp update completed")

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
            player_stats["health"] = player_max_health  # Store max health as health field
            player_stats["damage"] = player_damage
            player_stats["durability"] = player_durability
            # Preserve existing energy and last_energy_update fields
            if !player_stats.has("energy"):
                player_stats["energy"] = 20
            if !player_stats.has("skin"):
                player_stats["skin"] = "res://Sprites/Animation/DefaultPlayer_Animation.tscn"
                
            # Update the stats structure - exact same pattern as mainmenu.gd
            stats["player"] = player_stats
            
            print("PlayerManager: Final player stats to save: ", player_stats)
            
            # Update the document field - exact same pattern as energy update
            document.add_or_update_field("stats", stats)
            
            # Save the updated document - exact same pattern as energy update
            var updated_document = await collection.update(document)
            if updated_document:
                print("PlayerManager: ✓ Player stats updated in Firebase successfully!")
                if leveled_up:
                    print("PlayerManager: ✓ LEVEL UP SAVED! New level: " + str(player_level))
                    print("PlayerManager: ✓ New stats saved - Health: " + str(player_max_health) + ", Damage: " + str(player_damage) + ", Durability: " + str(player_durability))
            else:
                print("PlayerManager: ✗ Failed to update player stats in Firebase")
        else:
            print("PlayerManager: Stats structure not found in document")
    else:
        print("PlayerManager: Failed to get document for player stats update")

# Calculate max health based on level (100 + 10 per level)
func get_max_health():
    return 100 + (player_level - 1) * 20

# Calculate max experience needed for level up
func get_max_exp():
    # Simple 100 exp per level for easy leveling
    return 100

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
        if skin_name == "default":
            player_skin = "res://Sprites/Animation/DefaultPlayer_Animation.tscn"
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
    var exp_reward = 50  # Typical reward amount
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
                print("✓ SUCCESS: Local player stats match Firebase data!")
            else:
                print("✗ MISMATCH: Local and Firebase data don't match!")
        else:
            print("✗ ERROR: No player stats found in Firebase document")
    else:
        print("✗ ERROR: Could not retrieve document from Firebase")
    
    print("=== FIREBASE VERIFICATION COMPLETE ===")

# Temporary test function to verify Firebase level-up updates work
func test_firebase_level_up():
    print("=== TESTING FIREBASE LEVEL-UP UPDATE ===")
    print("Before: Level " + str(player_level) + ", Exp " + str(player_exp) + ", Health " + str(player_max_health) + ", Damage " + str(player_damage) + ", Durability " + str(player_durability))
    
    # Add enough experience to level up (simulate winning a battle)
    var exp_needed = get_max_exp() - player_exp + 1
    await add_experience(exp_needed)
    
    print("After: Level " + str(player_level) + ", Exp " + str(player_exp) + ", Health " + str(player_max_health) + ", Damage " + str(player_damage) + ", Durability " + str(player_durability))
    print("=== TEST COMPLETE ===")
