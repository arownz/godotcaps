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
var available_skins = ["default", "wizard", "knight", "ranger"] 
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
        player_damage += 3
        player_durability += 4
        
        # Recalculate max_exp for next level
        max_exp = get_max_exp()
        leveled_up = true
    
    if leveled_up:
        # Emit level up signal
        emit_signal("player_level_up", player_level)
        
        # Update player stats in Firestore if available
        if Engine.has_singleton("Firebase") and Firebase.Auth and Firebase.Auth.auth:
            await _update_player_stats_in_firebase(leveled_up)

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

# Update player stats in Firebase after level up
func _update_player_stats_in_firebase(leveled_up: bool = false):
    if !Firebase.Auth.auth:
        return
        
    var user_id = Firebase.Auth.auth.localid
    var collection = Firebase.Firestore.collection("dyslexia_users")
    
    # Get current document first
    var document = await collection.get_doc(user_id)
    if document and !("error" in document.keys() and document.get_value("error")):
        # Update player stats using proper Firebase pattern
        document.add_or_update_field("stats.player.level", player_level)
        document.add_or_update_field("stats.player.exp", player_exp)
        document.add_or_update_field("stats.player.health", player_max_health)  # Store max health
        document.add_or_update_field("stats.player.damage", player_damage)
        document.add_or_update_field("stats.player.durability", player_durability)
        
        # Update the document using correct method
        var updated_document = await collection.update(document)
        if updated_document:
            print("Player stats updated in Firebase successfully")
            if leveled_up:
                print("LEVEL UP! New level: " + str(player_level))
                print("New stats - Health: " + str(player_max_health) + ", Damage: " + str(player_damage) + ", Durability: " + str(player_durability))
        else:
            print("Failed to update player stats in Firebase")
    else:
        print("Failed to get document for player stats update")

# Calculate max health based on level (100 + 10 per level)
func get_max_health():
    return 100 + (player_level - 1) * 20

# Calculate max experience needed for level up
func get_max_exp():
    # Calculate based on player level using a formula
    return int(100 * pow(1.2, player_level - 1))

# Update health bar UI
func update_health_bar():
    var health_bar = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerHealthBar")
    var health_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerHealthBar/HealthLabel")
    
    if health_bar:
        # Calculate percentage based on health
        health_bar.value = (float(player_health) / float(player_max_health)) * 100.0
        
    if health_label:
        health_label.text = str(player_health) + "/" + str(player_max_health)

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
        # Get all current document data
        var current_data = {}
        for key in document.keys():
            if key != "error":
                current_data[key] = document.get_value(key)
        
        # Update player stats in the nested structure
        if !current_data.has("stats"):
            current_data["stats"] = {"player": {}}
        
        var player_stats = current_data.stats.get("player", {})
        player_stats.level = player_level
        player_stats.exp = player_exp
        player_stats.health = player_max_health
        player_stats.damage = player_damage
        player_stats.durability = player_durability
        
        current_data.stats.player = player_stats
        
        # Save back to Firebase
        var task = collection.add(user_id, current_data)
        if task:
            var result = await task.task_finished
            if result and !result.error:
                print("PlayerManager: Successfully updated player stats in Firebase")
            else:
                print("PlayerManager: Failed to update player stats in Firebase")
        else:
            print("PlayerManager: Failed to get document for player stats update")
