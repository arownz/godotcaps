class_name UIManager
extends Node

var battle_scene  # Reference to the main battle scene

# Preloaded background textures for faster switching
var background_textures = {
	1: preload("res://gui/Update/Backgrounds/battlescene background.png"),
	2: preload("res://gui/Update/Backgrounds/battlescene background.png"),
	3: preload("res://gui/Update/Backgrounds/battlescene background.png")
}

# Background scales for different dungeons
var background_scales = {
	1: Vector2(4.57812, 4.5),  # Original scale for 320x180
	2: Vector2(4.57812, 4.5),     # Reduced scale for larger image (1536x1024)
	3: Vector2(4.57812, 4.5)      # Reduced scale for larger image (1536x1024)
}

func _init(scene):
	battle_scene = scene

func initialize_ui():
	# Set initial UI state
	initialize_player_ui()
	initialize_enemy_ui()
	
	# Initialize PLAYER power and durability bars with actual player data
	update_power_bar(battle_scene.player_manager.player_damage)
	update_durability_bar(battle_scene.player_manager.player_durability)

func initialize_player_ui():
	# Set player name
	var player_name_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerName")
	player_name_label.text = battle_scene.player_manager.player_name
	
	# Set player level
	var player_level_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerLevelValue")
	player_level_label.text = str(battle_scene.player_manager.player_level)
	
	# Update player health bars
	update_player_health()
	
	# Set initial player exp
	update_player_exp()

func initialize_enemy_ui():
	# Set enemy name
	var enemy_name_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyName")
	enemy_name_label.text = battle_scene.enemy_manager.enemy_name
	
	# Update enemy health bar
	update_enemy_health()
	update_enemy_skill_meter()

func update_player_health():
	# Get current health values
	var player_health = battle_scene.player_manager.player_health
	var player_max_health = battle_scene.player_manager.player_max_health
	var percentage = (float(player_health) / float(player_max_health)) * 100.0
	var health_text = str(int(player_health)) + "/" + str(int(player_max_health))
	
	# Update battle area health bar
	var battle_health_bar = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerHealthBar")
	battle_health_bar.value = percentage
	var battle_health_label = battle_health_bar.get_node("HealthLabel")
	battle_health_label.text = health_text
	
	# Update stats panel health bar
	var stats_health_bar = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/StatsContainer/HPContainer/PlayerHealth")
	stats_health_bar.value = percentage
	var stats_health_label = stats_health_bar.get_node("HPValue")
	stats_health_label.text = health_text
	
	# Debug output
	print("Player Health Update: ", health_text, " (", int(percentage), "%)")

func update_enemy_health():
	# Get current health values
	var enemy_health = battle_scene.enemy_manager.enemy_health
	var enemy_max_health = battle_scene.enemy_manager.enemy_max_health
	var percentage = (float(enemy_health) / float(enemy_max_health)) * 100.0
	var health_text = str(int(enemy_health)) + "/" + str(int(enemy_max_health))
	
	# Update enemy health bar
	var health_bar = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyHealthBar")
	health_bar.value = percentage
	var health_label = health_bar.get_node("HealthLabel")
	health_label.text = health_text
	
	# Debug output
	print("Enemy Health Update: ", health_text, " (", int(percentage), "%)")

func update_enemy_skill_meter():
	var skill_bar = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemySkillBar")
	var enemy_skill_meter = battle_scene.enemy_manager.enemy_skill_meter
	skill_bar.value = int(enemy_skill_meter)

func update_player_exp():
	var exp_bar = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/StatsContainer/EXPContainer/PlayerEXP")
	var exp_label = exp_bar.get_node("EXPValue")
	
	var player_exp = battle_scene.player_manager.player_exp
	var player_max_exp = battle_scene.player_manager.get_max_exp()  # Use the calculated max exp
	
	# Calculate current level progress (0-100 within current level)
	var percentage = (float(player_exp) / float(player_max_exp)) * 100.0
	exp_bar.value = percentage
	
	# Update exp label to show current level progress
	exp_label.text = str(int(player_exp)) + "/" + str(int(player_max_exp))

func update_player_info():
	# Update player name in BattleScene UI
	var player_name_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerName")
	if player_name_label:
		player_name_label.text = battle_scene.player_manager.player_name
	
	# Update player level in BattleScene UI
	var player_level_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerLevelValue")
	if player_level_label:
		player_level_label.text = str(battle_scene.player_manager.player_level)
	
	# Update enemy level in BattleScene UI
	var enemy_level_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyLevelValue")
	if enemy_level_label:
		enemy_level_label.text = str(battle_scene.enemy_manager.enemy_level)

func update_power_bar(power_value, max_power=1000):
	var power_bar = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/StatsContainer/PowerContainer/PowerBar")
	var power_label = power_bar.get_node("PowerValue")
	
	# Update power bar value (ensure it's between 0-1000)
	var percentage = (float(power_value) / float(max_power)) * 100.0
	power_bar.value = percentage
	
	# Update power label without max value - only show current power
	power_label.text = str(int(power_value))

func update_durability_bar(durability_value, max_durability=1000):
	var durability_bar = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/StatsContainer/DurabilityContainer/DurabilityBar")
	var durability_label = durability_bar.get_node("DurabilityValue")
	
	# Update durability bar value (ensure it's between 0-1000)
	var percentage = (float(durability_value) / float(max_durability)) * 100.0
	durability_bar.value = percentage
	
	# Update durability label without max value - only show current durability
	durability_label.text = str(int(durability_value))

func show_fight_animation(callback = null):
	var fight_label = battle_scene.get_node("MainContainer/BattleAreaContainer/FightLabel")
	fight_label.visible = true
	
	# Create animation sequence
	var fight_tween = create_tween()
	fight_tween.tween_property(fight_label, "scale", Vector2(1.5, 1.5), 0.3)
	fight_tween.tween_property(fight_label, "scale", Vector2(1, 1), 0.2)
	fight_tween.tween_property(fight_label, "modulate", Color(1, 1, 1, 0), 0.5)
	
	# Call the callback after animation
	if callback:
		fight_tween.tween_callback(callback)

func update_stage_info():
	if !battle_scene:
		return
		
	var stage_info_label = battle_scene.get_node_or_null("MainContainer/BattleAreaContainer/StageInfoLabel")
	if stage_info_label:
		var dungeon_num = battle_scene.dungeon_manager.dungeon_num
		var stage_num = battle_scene.dungeon_manager.stage_num
		var stage_type = "Boss" if stage_num == 5 else "Stage"
		
		# Use the actual stage number (1-5) for each dungeon
		stage_info_label.text = "Dungeon " + str(dungeon_num) + " - " + stage_type + " " + str(stage_num)
		print("UIManager: Updated stage info to: ", stage_info_label.text)

func update_background(dungeon_num: int):
	# Update background based on dungeon number
	print("UIManager: Attempting to update background for dungeon ", dungeon_num)
	
	var background_sprite = battle_scene.get_node_or_null("Background/ParallaxLayer/Sprite2D")
	if !background_sprite:
		print("UIManager: Background sprite not found at path: Background/ParallaxLayer/Sprite2D")
		return
	
	print("UIManager: Background sprite found successfully")
	
	# Get preloaded texture and scale
	var texture = background_textures.get(dungeon_num, background_textures[1])
	var target_scale = background_scales.get(dungeon_num, background_scales[1])
	
	print("UIManager: Setting background for dungeon ", dungeon_num, " with scale: ", target_scale)
	
	# Set the new background texture and scale immediately (no loading delay)
	background_sprite.texture = texture
	background_sprite.scale = target_scale
	
	print("UIManager: Background updated successfully to dungeon ", dungeon_num)
