extends Node
class_name EnemyManager

# Signals - Using the exact same signals as previous implementation
signal enemy_health_changed(current_health, max_health)
signal enemy_defeated(exp_reward)
signal enemy_skill_meter_changed(value)
signal enemy_set_up(enemy_name, enemy_type)

# References
var battle_scene
var enemy_animation

# Resource for enemy stats
var enemy_stats_resource = null

# Enemy properties
var enemy_name = "Enemy"
var enemy_health = 80
var enemy_max_health = 80
var enemy_damage = 5
var enemy_durability = 2
var enemy_exp_reward = 20
var enemy_animation_path = "res://Sprites/Animation/Slime_Animation.tscn"
var enemy_skill_meter = 0
var enemy_skill_threshold = 100
var enemy_special_skill_damage = 0
var enemy_is_boss = false
var enemy_type = "normal" # Can be "normal", "boss"

# Add missing variable declarations at the top of the script
var enemy_level = 1
var enemy_skill_damage_multiplier = 2.0 # Multiplier for skill damage
var exp_reward = 0 # Experience points awarded for defeating this enemy

# Battle state tracking - CRITICAL for preventing post-game skill activations
var is_battle_active = true # Track if battle is still ongoing

# Enemy resources - load all enemy types
var enemy_resources = {
	"dungeon1_normal": preload("res://Resources/Enemies/dungeon1_normal.tres"),
	"dungeon1_boss": preload("res://Resources/Enemies/dungeon1_boss.tres"),
	"dungeon2_normal": preload("res://Resources/Enemies/dungeon2_normal.tres"),
	"dungeon2_boss": preload("res://Resources/Enemies/dungeon2_boss.tres"),
	"dungeon3_normal": preload("res://Resources/Enemies/dungeon3_normal.tres"),
	"dungeon3_boss": preload("res://Resources/Enemies/dungeon3_boss.tres")
}

# Constructor
func _init(scene = null):
    if scene != null:
        battle_scene = scene

# Initialize with battle scene reference
func initialize(scene = null):
    if scene != null:
        battle_scene = scene
        
    print("EnemyManager initialized")
    return self

# ADD MISSING VARIABLES AND FUNCTIONS
var enemy_animation_scene = null

# Helper: find the AnimatedSprite2D anywhere under the enemy animation root
func _find_animated_sprite(root: Node) -> AnimatedSprite2D:
    if root == null:
        return null
    var direct := root.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
    if direct:
        return direct
    # Search immediate children first
    for child in root.get_children():
        var aspr := child as AnimatedSprite2D
        if aspr:
            return aspr
    # Recursive search as fallback
    for child in root.get_children():
        var found := _find_animated_sprite(child)
        if found:
            return found
    return null

# Helper: play animation name using AnimatedSprite2D if available, else AnimationPlayer
func _play_enemy_anim(anim_name: String) -> void:
    if enemy_animation == null:
        return
    var spr := _find_animated_sprite(enemy_animation)
    if spr and spr.sprite_frames and spr.sprite_frames.has_animation(anim_name):
        spr.play(anim_name)
        return
    var ap := enemy_animation.get_node_or_null("AnimationPlayer") as AnimationPlayer
    if ap and ap.has_animation(anim_name):
        ap.play(anim_name)
        return
    print("EnemyManager: animation not found -> ", anim_name)

# Helper: find an AudioStreamPlayer whose name matches the action (e.g., slime_autoattack, snake_skill, boar_hurt)
func _find_audio_player_for_action(action: String) -> AudioStreamPlayer:
    if enemy_animation == null:
        return null
    var action_l := action.to_lower()
    var action_compact := action_l.replace("_", "") # handle auto_attack vs autoattack
    
    # breadth-first search for AudioStreamPlayer nodes
    var queue: Array = [enemy_animation]
    var exact_matches: Array[AudioStreamPlayer] = []
    var partial_matches: Array[AudioStreamPlayer] = []
    
    while queue.size() > 0:
        var node: Node = queue.pop_front()
        for child in node.get_children():
            queue.push_back(child)
            var asp := child as AudioStreamPlayer
            if asp:
                var nm := asp.name.to_lower()
                
                # Check for exact matches first
                if nm.ends_with("_" + action_l) or nm.ends_with("_" + action_compact) or nm == action_l or nm == action_compact:
                    exact_matches.append(asp)
                # Check for partial matches (contains the action)
                elif nm.find(action_compact) != -1 or nm.find(action_l) != -1:
                    partial_matches.append(asp)
    
    # Prioritize exact matches
    if exact_matches.size() > 0:
        print("EnemyManager: Found exact match for '" + action + "': " + exact_matches[0].name)
        return exact_matches[0]
    elif partial_matches.size() > 0:
        print("EnemyManager: Found partial match for '" + action + "': " + partial_matches[0].name)
        return partial_matches[0]
    
    return null

# Helper: play enemy SFX for a given action if an AudioStreamPlayer exists under the animation tree
func _play_enemy_sfx(action: String) -> void:
    var player := _find_audio_player_for_action(action)
    if player and player.has_method("play"):
        player.play()
        print("EnemyManager: playing sfx -> ", player.name)
    else:
        # Try alternative patterns if first search fails
        if action == "enemy_autoattack":
            player = _find_audio_player_for_action("autoattack")
        elif action == "enemy_hurt":
            player = _find_audio_player_for_action("hurt")
        elif action == "enemy_skill":
            player = _find_audio_player_for_action("skill")
        elif action == "enemy_dead":
            player = _find_audio_player_for_action("dead")
        
        if player and player.has_method("play"):
            player.play()
            print("EnemyManager: playing sfx (alt pattern) -> ", player.name)
        else:
            print("EnemyManager: sfx not found -> ", action)

func setup_enemy_sprite():
    print("EnemyManager: Setting up enemy sprite")
    
    # Load and instantiate the enemy animation if available
    if enemy_animation_scene != null:
        var enemy_sprite = enemy_animation_scene.instantiate()
        
        # Add to enemy position node
        var enemy_position = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyPosition")
        
        # Clear any existing enemy sprite
        for child in enemy_position.get_children():
            child.queue_free()
        
        # Add new enemy sprite
        enemy_position.add_child(enemy_sprite)
        enemy_animation = enemy_sprite # Set the animation reference
        
        # Set enemy name if the sprite has that property
        if enemy_sprite.has_method("set_enemy_name"):
            enemy_sprite.set_enemy_name(enemy_name)
		
        # Start the idle animation (use generic helper)
        _play_enemy_anim("idle")
        
        print("EnemyManager: Enemy sprite loaded successfully: ", enemy_animation_scene.resource_path)
    else:
        print("EnemyManager: No animation scene available for enemy")
        _load_default_enemy_animation()

func _load_default_enemy_animation():
    print("EnemyManager: Loading default enemy animation")
    # Try to load a default animation based on enemy type
    var default_path = "res://Sprites/Animation/Slime_Animation.tscn"
    var default_scene = load(default_path)
    if default_scene != null:
        var enemy_sprite = default_scene.instantiate()
        var enemy_position = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyPosition")
        
        # Clear any existing enemy sprite
        for child in enemy_position.get_children():
            child.queue_free()
        
        # Add default enemy sprite
        enemy_position.add_child(enemy_sprite)
        enemy_animation = enemy_sprite # Set the animation reference
        
        # Start the idle animation
        _play_enemy_anim("idle")
        
        print("EnemyManager: Default enemy animation loaded")
    else:
        print("EnemyManager: Could not load default enemy animation")

func get_exp_reward():
    # Calculate experience based on enemy stats and scaling to match new player leveling system
    var dungeon_num = battle_scene.dungeon_manager.dungeon_num
    var stage_num = battle_scene.dungeon_manager.stage_num
    
    # Base exp scales with dungeon and stage to match player leveling curve
    var base_exp = 15 + (dungeon_num - 1) * 10 + (stage_num - 1) * 3 # 15-45 range
    
    # Stage multiplier for within-dungeon progression
    var stage_multiplier = 1.0 + (stage_num - 1) * 0.15 # 1.0 to 1.6x
    
    # Enemy type multiplier
    var type_multiplier = 1.0
    match enemy_type:
        "normal":
            type_multiplier = 1.0
        "boss":
            type_multiplier = 2.5 # Bosses give significant exp but not overwhelming
        _:
            type_multiplier = 1.0
    
    # Calculate final exp reward
    var total_exp = int(base_exp * stage_multiplier * type_multiplier)
    
    print("EnemyManager: Exp calculation - Base: ", base_exp, ", Stage mult: ", stage_multiplier, ", Type mult: ", type_multiplier, ", Total: ", total_exp)
    
    return max(total_exp, 8) # Minimum 8 exp to ensure progress

# Get enemy level
func get_enemy_level():
    return enemy_level

# Set up the enemy
func setup_enemy():
    print("EnemyManager: Setting up enemy")
    
    # Get enemy data based on current dungeon and stage
    var enemy_data = get_enemy_data()
    if enemy_data == null:
        print("ERROR: Could not load enemy data")
        return
    
    # Calculate level based on current stage (1-5 for each dungeon)
    enemy_level = battle_scene.dungeon_manager.stage_num

    # Determine enemy type based on stage (stage 5 = boss, others = normal)
    if battle_scene.dungeon_manager.stage_num == 5:
        enemy_type = "boss"
        enemy_skill_damage_multiplier = 3.0
    else:
        enemy_type = "normal"
        enemy_skill_damage_multiplier = 2.0
    
    # Extract base data from resource
    enemy_name = enemy_data.get_enemy_name()
    var base_health = enemy_data.get_health()
    var base_damage = enemy_data.get_damage()
    var base_durability = enemy_data.get_durability()
    var base_exp_reward = enemy_data.get_exp_reward()
    
    # Apply stage-based scaling to stats
    var stage_multiplier = _get_stage_multiplier()
    enemy_max_health = int(base_health * stage_multiplier)
    enemy_damage = int(base_damage * stage_multiplier)
    enemy_durability = int(base_durability * stage_multiplier)
    exp_reward = int(base_exp_reward * stage_multiplier)
    
    # Update enemy name based on stage progression
    enemy_name = _get_stage_specific_name(enemy_name)
    
    # Get animation scene
    enemy_animation_scene = enemy_data.get_animation_scene()
    
    # Set current health to max health
    enemy_health = enemy_max_health
    
    # Reset skill meter and battle state
    enemy_skill_meter = 0
    enemy_skill_threshold = 100
    is_battle_active = true # Reset battle state for new battle
    
    print("Enemy setup complete:")
    print("- Name: ", enemy_name)
    print("- Type: ", enemy_type)
    print("- Level: ", enemy_level)
    print("- Health: ", enemy_health, "/", enemy_max_health)
    print("- Damage: ", enemy_damage)
    print("- Durability: ", enemy_durability)
    print("- Exp Reward: ", exp_reward)
    
    # Load and setup enemy sprite
    setup_enemy_sprite()

# Get stage-based multiplier for enemy stats - BALANCED FOR DYSLEXIC CHILDREN (matching dungeon maps)
func _get_stage_multiplier() -> float:
    var stage_num = battle_scene.dungeon_manager.stage_num
    var dungeon_num = battle_scene.dungeon_manager.dungeon_num
    
    # Balanced progression for dyslexic children - matches dungeon maps
    var stage_multiplier = 1.0 + (stage_num - 1) * 0.12 # 1.0, 1.12, 1.24, 1.36, 1.48
    
    # Gentle dungeon scaling to maintain accessibility while providing progression
    var dungeon_multiplier = 1.0 + (dungeon_num - 1) * 0.20 # 1.0, 1.20, 1.40
    
    return stage_multiplier * dungeon_multiplier

# Get stage-specific enemy name variations
func _get_stage_specific_name(base_name: String) -> String:
    var stage_num = battle_scene.dungeon_manager.stage_num
    var dungeon_num = battle_scene.dungeon_manager.dungeon_num
    
    # Stage-specific prefixes
    var stage_prefixes = ["Young", "Regular", "Elder", "Giant", "Boss"]
    var prefix = stage_prefixes[min(stage_num - 1, stage_prefixes.size() - 1)]
    
    # For boss stages, use specific boss names
    if stage_num == 5:
        match dungeon_num:
            1: return "Plain Guardian"
            2: return "Forest Guardian"
            3: return "Mountain Guardian"
            _: return "Boss " + base_name
    
    # For regular stages, add prefix
    return prefix + " " + base_name

func get_enemy_data():
    var dungeon_num = battle_scene.dungeon_manager.dungeon_num
    var stage_num = battle_scene.dungeon_manager.stage_num
    
    # Determine if this is a boss stage
    var is_boss = (stage_num == 5)
    
    var resource_path = ""
    if is_boss:
        resource_path = "res://Resources/Enemies/dungeon" + str(dungeon_num) + "_boss.tres"
    else:
        resource_path = "res://Resources/Enemies/dungeon" + str(dungeon_num) + "_normal.tres"
    
    print("Loading enemy resource: ", resource_path)
    
    var enemy_resource = load(resource_path)
    if enemy_resource == null:
        print("ERROR: Could not load enemy resource from ", resource_path)
        return null
    
    return enemy_resource

# Configure enemy based on dungeon and stage
func _configure_enemy_for_stage(dungeon_id, stage_id):
    _determine_enemy_type(stage_id)
    _setup_enemy_fallback(dungeon_id, stage_id)
    
    # Emit signal that enemy is set up
    emit_signal("enemy_set_up", enemy_name, enemy_type)
    
    # Update UI elements with new enemy values
    update_ui_elements()

func _determine_enemy_type(stage_number):
    # Determine enemy type based on stage number
    if stage_number == 5:
        return "boss"
    else:
        return "normal"

# Setup enemy with fallback values
func _setup_enemy_fallback(dungeon_id, stage_id):
    # Set fallback stats based on dungeon and stage
    enemy_name = "Enemy D" + str(dungeon_id) + "-S" + str(stage_id)
    enemy_health = 80 * dungeon_id * (1 + stage_id * 0.2)
    enemy_max_health = enemy_health
    enemy_damage = 5 * dungeon_id * (1 + stage_id * 0.1)
    enemy_durability = 2 * dungeon_id
    enemy_exp_reward = 20 * dungeon_id * stage_id
    enemy_is_boss = (stage_id % 5 == 0)
    
    # Set default animation based on dungeon
    match dungeon_id:
        1: enemy_animation_path = "res://Sprites/Animation/Slime_Animation.tscn"
        2: enemy_animation_path = "res://Sprites/Animation/Snake_Animation.tscn"
        3: enemy_animation_path = "res://Sprites/Animation/Boar_Animation.tscn"
        _: enemy_animation_path = "res://Sprites/Animation/Slime_Animation.tscn"
    
    if enemy_is_boss:
        enemy_animation_path = "res://Sprites/Animation/Treant_Animation.tscn"
        enemy_skill_threshold = 150
        enemy_special_skill_damage = enemy_damage * 3
    else:
        enemy_special_skill_damage = enemy_damage * 2

# Load enemy stats from resource
func load_stats_from_resource(resource):
    enemy_stats_resource = resource
    
    # Apply resource stats to enemy
    enemy_name = resource.enemy_name if "enemy_name" in resource else resource.name if "name" in resource else enemy_name
    enemy_health = resource.base_health if "base_health" in resource else resource.health if "health" in resource else enemy_health
    enemy_max_health = enemy_health
    enemy_damage = resource.base_damage if "base_damage" in resource else resource.damage if "damage" in resource else enemy_damage
    enemy_durability = resource.base_durability if "base_durability" in resource else resource.durability if "durability" in resource else enemy_durability
    enemy_exp_reward = resource.exp_reward if "exp_reward" in resource else enemy_exp_reward
    enemy_is_boss = resource.enemy_type == "boss" if "enemy_type" in resource else resource.is_boss if "is_boss" in resource else enemy_is_boss
    
    # Set animation path from resource if available
    var animation_key = "animation_scene"
    if "animation_path" in resource:
        animation_key = "animation_path"
    
    if animation_key in resource and resource.get(animation_key):
        enemy_animation_path = resource.get(animation_key)
    
    # Setup special skill based on enemy type
    if "special_skill_damage" in resource:
        enemy_special_skill_damage = resource.special_skill_damage
    else:
        enemy_special_skill_damage = enemy_damage * 2
    
    # Bosses have higher skill threshold
    if enemy_is_boss:
        enemy_skill_threshold = 150
        if !("special_skill_damage" in resource):
            enemy_special_skill_damage = enemy_damage * 3
    
    print("EnemyManager: Loaded stats from resource: " + enemy_name)

# Load enemy animation (fixed implementation)
func load_enemy_animation():
    print("Loading enemy animation: " + enemy_animation_path)
    
    # Clear any existing animation
    if enemy_animation:
        enemy_animation.queue_free()
        enemy_animation = null
    
    # Find the enemy position node
    var enemy_position = battle_scene.get_node_or_null("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyPosition")
    if !enemy_position:
        print("ERROR: Enemy position node not found")
        return
    
    # Load the enemy animation scene
    if ResourceLoader.exists(enemy_animation_path):
        var scene = load(enemy_animation_path)
        if scene:
            enemy_animation = scene.instantiate()
            enemy_position.add_child(enemy_animation)
            
            # Ensure the enemy plays idle on load
            _play_enemy_anim("idle")
            print("Loaded enemy animation: " + enemy_animation_path)
        else:
            print("ERROR: Failed to load scene: " + enemy_animation_path)
    else:
        print("ERROR: Animation path does not exist: " + enemy_animation_path)
        
        # Fallback - create a placeholder
        enemy_animation = Node2D.new()
        enemy_animation.name = "PlaceholderEnemyAnimation"
        
        var label = Label.new()
        label.text = enemy_name
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        enemy_animation.add_child(label)
        
        enemy_position.add_child(enemy_animation)
        print("Created placeholder for enemy: " + enemy_name)

# Update UI elements
func update_ui_elements():
    if battle_scene:
        # Update enemy name
        var enemy_name_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyName")
        if enemy_name_label:
            enemy_name_label.text = enemy_name
            
        # Update health bar
        update_health_bar()
        
        # Update skill meter
        update_skill_meter()

# Update health bar UI
func update_health_bar():
    var health_bar = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyHealthBar")
    var health_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyHealthBar/HealthLabel")
    
    if health_bar:
        # Update this to handle case where enemy_stats_resource might be null
        var max_health = enemy_max_health
        if enemy_stats_resource and "health" in enemy_stats_resource:
            max_health = enemy_stats_resource.health
        
        health_bar.value = (float(enemy_health) / max_health) * 100.0
        
    if health_label:
        health_label.text = str(enemy_health)

# Update skill meter UI
func update_skill_meter():
    var skill_bar = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemySkillBar")
    
    if skill_bar:
        skill_bar.value = (float(enemy_skill_meter) / enemy_skill_threshold) * 100.0

# Handle enemy taking damage
func take_damage(damage_amount):
    # Apply damage reduction based on durability
    var reduced_damage = max(1, damage_amount - enemy_durability)
    enemy_health = max(0, enemy_health - reduced_damage)
    
    # Emit signal
    emit_signal("enemy_health_changed", enemy_health, enemy_max_health)
    
    # Check if enemy is defeated
    if enemy_health <= 0:
        is_battle_active = false # CRITICAL: Stop battle state immediately when defeated
        emit_signal("enemy_defeated", exp_reward)
        
        # Play death animation
        _play_enemy_anim("dead")
        # Also play hurt SFX on lethal hit (requested), then dead SFX if present
        _play_enemy_sfx("enemy_hurt")
        _play_enemy_sfx("enemy_dead")
    else:
        # CRITICAL FIX: Only increase skill meter if battle is still active
        if is_battle_active:
            enemy_skill_meter = min(enemy_skill_threshold, enemy_skill_meter + reduced_damage)
            emit_signal("enemy_skill_meter_changed", enemy_skill_meter)
        else:
            print("EnemyManager: Skill meter increase blocked - battle ended")
        
        # Play hurt animation
        _play_enemy_anim("hurt")
        _play_enemy_sfx("enemy_hurt")
    
    return reduced_damage

# This method will be called when enemy uses abilities
func increase_skill_meter(amount):
    # CRITICAL FIX: Prevent skill meter increases after battle ends
    if not is_battle_active:
        print("EnemyManager: Skill meter increase blocked - battle has ended")
        return false
    
    enemy_skill_meter += amount
    enemy_skill_meter = min(enemy_skill_meter, enemy_skill_threshold)
    
    # Emit signal that skill meter changed
    emit_signal("enemy_skill_meter_changed", enemy_skill_meter)
    
    return enemy_skill_meter >= enemy_skill_threshold # Return true if skill is ready

# Reset skill meter to zero
func reset_skill_meter():
    enemy_skill_meter = 0
    emit_signal("enemy_skill_meter_changed", enemy_skill_meter)

# CRITICAL: End battle state to prevent further skill activations
func end_battle():
    print("EnemyManager: Battle ended - disabling all skill meter activities")
    is_battle_active = false
    # Reset skill meter to prevent any pending skill activations
    enemy_skill_meter = 0
    emit_signal("enemy_skill_meter_changed", enemy_skill_meter)

# Check if battle is still active (for external verification)
func is_battle_still_active() -> bool:
    return is_battle_active

# Perform enemy attack on player
func attack(player_manager):
    # CRITICAL: Prevent attacks after battle ends
    if not is_battle_active:
        print("EnemyManager: Attack blocked - battle has ended")
        return 0
    
    # Check for special skill trigger
    if enemy_skill_meter >= enemy_skill_threshold:
        return use_special_skill(player_manager)
    
    # Play attack animation and SFX
    _play_enemy_anim("auto_attack")
    _play_enemy_sfx("enemy_autoattack") # Use consistent enemy naming convention
    
    print("Enemy " + enemy_name + " attacking with damage: " + str(enemy_damage))
    
    # Apply damage to player
    var damage_dealt = player_manager.take_damage(enemy_damage)
    
    # Return damage for battle log
    return damage_dealt

# Use enemy's special skill
func use_special_skill(player_manager):
    # CRITICAL: Prevent special skills after battle ends
    if not is_battle_active:
        print("EnemyManager: Special skill blocked - battle has ended")
        return 0
    # Play skill animation
    _play_enemy_anim("skill")
    _play_enemy_sfx("enemy_skill")
    
    # Reset skill meter
    enemy_skill_meter = 0
    
    print("Enemy " + enemy_name + " using special skill with damage: " + str(enemy_special_skill_damage))
    
    # Apply damage to player
    var damage_dealt = player_manager.take_damage(enemy_special_skill_damage)
    
    # Return damage for battle log
    return damage_dealt

# Reset animation to idle
func reset_animation():
    _play_enemy_anim("idle")

# Public wrapper so other managers can trigger SFX without relying on a private helper name
func play_enemy_sfx(action: String) -> void:
    _play_enemy_sfx(action)

# Get reward data
func get_rewards():
    return {
        "exp": enemy_exp_reward,
        "is_boss": enemy_is_boss
    }
