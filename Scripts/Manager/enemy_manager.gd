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
var enemy_skill_damage_multiplier = 2.0  # Multiplier for skill damage
var exp_reward = 0  # Experience points awarded for defeating this enemy

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
        enemy_animation = enemy_sprite  # Set the animation reference
        
        # Set enemy name if the sprite has that property
        if enemy_sprite.has_method("set_enemy_name"):
            enemy_sprite.set_enemy_name(enemy_name)
        
        # Start the idle animation if available
        if enemy_animation.has_method("play"):
            enemy_animation.play("battle_idle")
        elif enemy_animation.has_node("AnimationPlayer"):
            var anim_player = enemy_animation.get_node("AnimationPlayer")
            if anim_player.has_animation("battle_idle"):
                anim_player.play("battle_idle")
        
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
        enemy_animation = enemy_sprite  # Set the animation reference
        
        # Start the idle animation if available
        if enemy_animation.has_method("play"):
            enemy_animation.play("battle_idle")
        elif enemy_animation.has_node("AnimationPlayer"):
            var anim_player = enemy_animation.get_node("AnimationPlayer")
            if anim_player.has_animation("battle_idle"):
                anim_player.play("battle_idle")
        
        print("EnemyManager: Default enemy animation loaded")
    else:
        print("EnemyManager: Could not load default enemy animation")

func get_exp_reward():
    # Calculate experience based on enemy type and stats
    var base_exp = 10
    var level_multiplier = (enemy_level / 5.0) + 1.0
    var type_multiplier = 1.0
    
    match enemy_type:
        "normal":
            type_multiplier = 1.0
        "boss":
            type_multiplier = 3.0
        _:
            type_multiplier = 1.0
    
    var total_exp = int(base_exp * level_multiplier * type_multiplier)
    return max(total_exp, 5) # Minimum 5 exp

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
    
    # Calculate level based on current dungeon and stage
    enemy_level = ((battle_scene.dungeon_manager.dungeon_num - 1) * 25) + (battle_scene.dungeon_manager.stage_num * 5)
    
    # Determine enemy type based on stage (stage 5 = boss, others = normal)
    if battle_scene.dungeon_manager.stage_num == 5:
        enemy_type = "boss"
        enemy_skill_damage_multiplier = 3.0
    else:
        enemy_type = "normal"
        enemy_skill_damage_multiplier = 2.0
    
    # Extract data from resource - FIXED: use correct getter methods
    enemy_name = enemy_data.get_enemy_name()
    enemy_max_health = enemy_data.get_health()
    enemy_damage = enemy_data.get_damage()
    enemy_durability = enemy_data.get_durability()
    
    # Get experience reward from resource file
    exp_reward = enemy_data.get_exp_reward()
    enemy_animation_scene = enemy_data.get_animation_scene()
    
    # Set current health to max health
    enemy_health = enemy_max_health
    
    # Reset skill meter
    enemy_skill_meter = 0
    enemy_skill_threshold = 100
    
    print("Enemy setup complete:")
    print("- Name: ", enemy_name)
    print("- Type: ", enemy_type)
    print("- Level: ", enemy_level)
    print("- Health: ", enemy_health, "/", enemy_max_health)
    print("- Damage: ", enemy_damage)
    print("- Durability: ", enemy_durability)
    
    # Load and setup enemy sprite
    setup_enemy_sprite()

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
            
            # Make sure the enemy's AnimatedSprite2D plays "idle" animation
            var sprite = enemy_animation.get_node_or_null("AnimatedSprite2D")
            if sprite:
                sprite.play("idle")
                print("Loaded enemy animation: " + enemy_animation_path)
            else:
                print("AnimatedSprite2D not found in enemy animation")
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
        emit_signal("enemy_defeated", exp_reward)
        
        # Play death animation
        if enemy_animation and enemy_animation.get_node("AnimatedSprite2D"):
            enemy_animation.get_node("AnimatedSprite2D").play("dead")
    else:
        # Increase skill meter when taking damage (if not defeated)
        enemy_skill_meter = min(enemy_skill_threshold, enemy_skill_meter + reduced_damage)
        emit_signal("enemy_skill_meter_changed", enemy_skill_meter)
        
        # Play hurt animation
        if enemy_animation and enemy_animation.get_node("AnimatedSprite2D"):
            enemy_animation.get_node("AnimatedSprite2D").play("hurt")
    
    return reduced_damage

# This method will be called when enemy uses abilities
func increase_skill_meter(amount):
    enemy_skill_meter += amount
    enemy_skill_meter = min(enemy_skill_meter, enemy_skill_threshold)
    
    # Emit signal that skill meter changed
    emit_signal("enemy_skill_meter_changed", enemy_skill_meter)
    
    return enemy_skill_meter >= enemy_skill_threshold  # Return true if skill is ready

# Reset skill meter to zero
func reset_skill_meter():
    enemy_skill_meter = 0
    emit_signal("enemy_skill_meter_changed", enemy_skill_meter)

# Perform enemy attack on player
func attack(player_manager):
    # Check for special skill trigger
    if enemy_skill_meter >= enemy_skill_threshold:
        return use_special_skill(player_manager)
    
    # Play attack animation
    if enemy_animation and enemy_animation.get_node("AnimatedSprite2D"):
        enemy_animation.get_node("AnimatedSprite2D").play("auto_attack")
    
    print("Enemy " + enemy_name + " attacking with damage: " + str(enemy_damage))
    
    # Apply damage to player
    var damage_dealt = player_manager.take_damage(enemy_damage)
    
    # Return damage for battle log
    return damage_dealt

# Use enemy's special skill
func use_special_skill(player_manager):
    # Play skill animation
    if enemy_animation and enemy_animation.get_node("AnimatedSprite2D"):
        enemy_animation.get_node("AnimatedSprite2D").play("skill")
    
    # Reset skill meter
    enemy_skill_meter = 0
    
    print("Enemy " + enemy_name + " using special skill with damage: " + str(enemy_special_skill_damage))
    
    # Apply damage to player
    var damage_dealt = player_manager.take_damage(enemy_special_skill_damage)
    
    # Return damage for battle log
    return damage_dealt

# Reset animation to idle
func reset_animation():
    if enemy_animation and enemy_animation.get_node("AnimatedSprite2D"):
        enemy_animation.get_node("AnimatedSprite2D").play("idle")

# Get reward data
func get_rewards():
    return {
        "exp": enemy_exp_reward,
        "is_boss": enemy_is_boss
    }
