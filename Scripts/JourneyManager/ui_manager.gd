class_name UIManager
extends Node

var battle_scene # Reference to the main battle scene

# Cache the PlayerIcon's default position to restore on stage 1
var _player_icon_initial_pos: Vector2
var _player_icon_pos_captured := false

func _init(scene):
	battle_scene = scene

func initialize_ui():
	# Set initial UI state
	initialize_player_ui()
	initialize_enemy_ui()
	
	# Initialize PLAYER power and durability bars with actual player data
	update_power_bar(battle_scene.player_manager.player_damage)
	update_durability_bar(battle_scene.player_manager.player_durability)
	
	# Initialize player icon in stage progress with correct character
	var progress_root = battle_scene.get_node_or_null("MainContainer/BattleAreaContainer/StageProgress")
	if progress_root:
		var player_icon = progress_root.get_node_or_null("PlayerIcon") as TextureRect
		if player_icon:
			_update_player_icon_texture(player_icon)

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
	
	# Set enemy head icons per dungeon: 1-4 dungeon-specific, 5 is treant boss
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
			# Make already-completed stages semi-transparent for clarity
			# Completed stages are strictly before the current stage index (stage_num - 1)
			# Example: at Stage 3 (stage_num=3), indices 0..1 are completed; index 1 is hidden by PlayerIcon
			var alpha := 1.0
			if i < (stage_num - 1):
				alpha = 0.35
			icon.modulate = Color(1, 1, 1, alpha)
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
	# Update background based on dungeon number using separate sprite nodes
	print("UIManager: Switching to background for dungeon ", dungeon_num)
	
	# Get all background sprites
	var bg_sprite1 = battle_scene.get_node_or_null("Background/ParallaxLayer/Sprite2D") # Dungeon 1 (default)
	var bg_sprite2 = battle_scene.get_node_or_null("Background/ParallaxLayer/Sprite2D2") # Dungeon 2 (forest)
	var bg_sprite3 = battle_scene.get_node_or_null("Background/ParallaxLayer/Sprite2D3") # Dungeon 3 (mountain)
	
	if !bg_sprite1 or !bg_sprite2 or !bg_sprite3:
		print("UIManager: Warning - One or more background sprites not found")
		print("  Sprite2D (dungeon 1): ", bg_sprite1 != null)
		print("  Sprite2D2 (dungeon 2): ", bg_sprite2 != null)
		print("  Sprite2D3 (dungeon 3): ", bg_sprite3 != null)
		return
	
	# Hide all backgrounds first
	bg_sprite1.visible = false
	bg_sprite2.visible = false
	bg_sprite3.visible = false
	
	# Show the appropriate background for the current dungeon
	match dungeon_num:
		1:
			bg_sprite1.visible = true
			print("UIManager: Showing dungeon 1 background (default)")
		2:
			bg_sprite2.visible = true
			print("UIManager: Showing dungeon 2 background (forest)")
		3:
			bg_sprite3.visible = true
			print("UIManager: Showing dungeon 3 background (mountain)")
		_:
			# Default to dungeon 1 background for unknown dungeon numbers
			bg_sprite1.visible = true
			print("UIManager: Unknown dungeon ", dungeon_num, ", defaulting to dungeon 1 background")
	
	print("UIManager: Background switch completed for dungeon ", dungeon_num)

# Update the player icon texture based on currently selected character
func _update_player_icon_texture(player_icon: TextureRect):
	if !player_icon:
		return
		
	# Get the current character from player manager
	var current_character = "lexia" # Default fallback
	if battle_scene and battle_scene.player_manager:
		# Get current character from current_skin variable (populated from Firebase current_character field)
		if battle_scene.player_manager.current_skin != null and battle_scene.player_manager.current_skin != "":
			current_character = battle_scene.player_manager.current_skin
		# Fallback: check player animation scene path for character detection
		elif battle_scene.player_manager.player_animation_scene != null:
			var animation_path = battle_scene.player_manager.player_animation_scene
			if "Ragna" in animation_path:
				current_character = "ragna"
			elif "Magi" in animation_path:
				current_character = "magi"
			else:
				current_character = "lexia"
	
	# Load the appropriate head texture based on character
	var head_texture: Texture2D = null
	match current_character.to_lower():
		"lexia":
			head_texture = load("res://gui/Update/icons/lexia_head.png")
		"ragna":
			head_texture = load("res://gui/Update/icons/ragna_head.png")
		"magi":
			# TODO: Add magi_head.png when Magi character is fully implemented
			# For now, fallback to lexia head
			head_texture = load("res://gui/Update/icons/lexia_head.png")
			print("UIManager: Magi head icon not yet available, using Lexia head as fallback")
		_:
			# Default fallback for any unknown character
			head_texture = load("res://gui/Update/icons/lexia_head.png")
			print("UIManager: Unknown character '" + str(current_character) + "', using Lexia head as fallback")
	
	# Apply the texture to the player icon
	if head_texture:
		player_icon.texture = head_texture
		print("UIManager: Updated player icon to " + current_character + " head")
	else:
		print("UIManager: Failed to load head texture for character: " + current_character) # Apply the texture to the player icon
	print("UIManager: Selected character: ", current_character)
	print("UIManager: Head texture loaded: ", head_texture != null)
	print("UIManager: Current player_icon.texture before setting: ", player_icon.texture)
	
	if head_texture:
		# Force set the texture
		player_icon.texture = head_texture
		
		# Force update the UI
		player_icon.queue_redraw()
		
		print("UIManager: Successfully applied texture to player icon")
		print("UIManager: Player icon properties after texture set:")
		print("  - visible: ", player_icon.visible)
		print("  - modulate: ", player_icon.modulate)
		print("  - size: ", player_icon.size)
		print("  - position: ", player_icon.position)
		print("  - texture: ", player_icon.texture != null)
		print("  - texture path (if available): ", player_icon.texture.resource_path if player_icon.texture else "null")
		
		# Wait a frame and check again to see if something is overriding it
		await get_tree().process_frame
		print("UIManager: After one frame - texture still set: ", player_icon.texture != null)
		if player_icon.texture:
			print("UIManager: After one frame - texture path: ", player_icon.texture.resource_path)
	else:
		print("UIManager: ERROR - Failed to load head texture for character: " + current_character)