class_name UIManager
extends Node

var battle_scene # Reference to the main battle scene

# Cache the PlayerIcon's default position to restore on stage 1
var _player_icon_initial_pos: Vector2
var _player_icon_pos_captured := false

# Preloaded background textures for faster switching
var background_textures = {
	1: preload("res://gui/Update/Backgrounds/battlescene background.png"),
	2: preload("res://gui/Update/Backgrounds/battlescene background.png"),
	3: preload("res://gui/Update/Backgrounds/battlescene background.png")
}

# Background scales for different dungeons
var background_scales = {
	1: Vector2(4.57812, 4.5), # Original scale for 320x180
	2: Vector2(4.57812, 4.5), # Reduced scale for larger image (1536x1024)
	3: Vector2(4.57812, 4.5) # Reduced scale for larger image (1536x1024)
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
	var player_max_exp = battle_scene.player_manager.get_max_exp() # Use the calculated max exp
	
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

func update_power_bar(power_value, max_power = 1000):
	var power_bar = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/StatsContainer/PowerContainer/PowerBar")
	var power_label = power_bar.get_node("PowerValue")
	
	# Update power bar value (ensure it's between 0-1000)
	var percentage = (float(power_value) / float(max_power)) * 100.0
	power_bar.value = percentage
	
	# Update power label without max value - only show current power
	power_label.text = str(int(power_value))

func update_durability_bar(durability_value, max_durability = 1000):
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
    
	_update_stage_progress()

func _update_stage_progress():
	var progress_root = battle_scene.get_node_or_null("MainContainer/BattleAreaContainer/StageProgress")
	if progress_root == null:
		return
	# Ensure StageProgress sits globally behind overlay panels (Whiteboard/STT)
	(progress_root as Control).z_as_relative = false
	(progress_root as Control).z_index = -100
	var slots = progress_root.get_node_or_null("StageSlots")
	var player_icon := progress_root.get_node_or_null("PlayerIcon") as TextureRect
	var bar_bg = progress_root.get_node_or_null("BarBg")
	var bar_fill = progress_root.get_node_or_null("BarFill")
	if slots == null or player_icon == null:
		return

	# Capture the PlayerIcon's original position once
	if !_player_icon_pos_captured:
		_player_icon_initial_pos = (player_icon as Control).position
		_player_icon_pos_captured = true
    
	var dungeon_num = battle_scene.dungeon_manager.dungeon_num
	var stage_num = battle_scene.dungeon_manager.stage_num # 1..5
    
	# Set enemy icons per dungeon: 1-4 dungeon-specific, 5 is treant boss
	var enemy_tex: Texture2D = null
	match dungeon_num:
		1:
			enemy_tex = load("res://gui/Update/icons/slaym enemeh.png")
		2:
			enemy_tex = load("res://gui/Update/icons/snek enemeh.png")
		3:
			enemy_tex = load("res://gui/Update/icons/bourr enemeh.png")
		_:
			enemy_tex = load("res://gui/Update/icons/slaym enemeh.png")
	var boss_tex: Texture2D = load("res://gui/Update/icons/treant enemeh.png")
	var lock_tex: Texture2D = load("res://gui/Update/icons/lock icon.png")
    
	var slot_count = min(5, slots.get_child_count())
	var covered_index := -1
	if stage_num >= 2:
		covered_index = clamp(stage_num - 2, 0, slot_count - 1)
	for i in range(slot_count):
		var slot = slots.get_child(i)
		var icon = slot.get_node_or_null("EnemyIcon") as TextureRect
		if icon:
			var is_boss = (i == 4)
			var is_unlocked = (i < stage_num)
			# Assign icon: unlocked -> enemy/boss; locked -> lock icon
			icon.texture = (boss_tex if is_boss else enemy_tex) if is_unlocked else lock_tex
			icon.modulate = Color(1, 1, 1, 1)
			# Hide the icon currently covered by the player's head (previous stage)
			icon.visible = (i != covered_index)

	# Position PlayerIcon:
	# - Stage 1: keep original position (designer placement)
	# - Stage >= 2: move to cover the previous stage's enemy icon (Slot[stage-2])
	if stage_num <= 1:
		(player_icon as Control).position = _player_icon_initial_pos
	else:
		var target_index = clamp(stage_num - 2, 0, slot_count - 1)
		var target_slot = slots.get_child(target_index) as Control
		if target_slot:
			var root_rect = (progress_root as Control).get_global_rect()
			var enemy_icon_node = target_slot.get_node_or_null("EnemyIcon") as Control
			if enemy_icon_node:
				var icon_rect = enemy_icon_node.get_global_rect()
				# Match size to ensure perfect coverage, then align top-left exactly
				(player_icon as Control).size = (enemy_icon_node as Control).size
				(player_icon as Control).position = icon_rect.position - root_rect.position
			else:
				# Fallback to slot center if icon missing
				var slot_rect = target_slot.get_global_rect()
				var slot_center = slot_rect.position + slot_rect.size / 2.0
				var size = (player_icon as Control).size
				(player_icon as Control).position = slot_center - root_rect.position - size / 2.0
			# Draw PlayerIcon above bar/icons within StageProgress but globally below overlays
			(player_icon as Control).z_as_relative = false
			(player_icon as Control).z_index = -99

	# Update bar fill to reflect progress across 5 stages
	if bar_bg and bar_fill:
		var bg_rect = (bar_bg as Control).get_rect()
		# Percentage: 0 at stage 1 start, 1.0 at stage 5 start
		var stage_num_f = float(stage_num - 1) / 4.0
		var fill_width = max(0.0, bg_rect.size.x * stage_num_f)
		# Maintain left and vertical offsets, adjust right to left + width
		(bar_fill as Control).offset_left = (bar_bg as Control).offset_left
		(bar_fill as Control).offset_top = (bar_bg as Control).offset_top
		(bar_fill as Control).offset_bottom = (bar_bg as Control).offset_bottom
		(bar_fill as Control).offset_right = (bar_bg as Control).offset_left + fill_width

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
