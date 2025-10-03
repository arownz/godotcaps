class_name UIManager
extends Node

var battle_scene # Reference to the main battle scene

# Stage progress constraints for consistent UI design
const STAGE_ICON_SIZE = Vector2(44, 44)
const STAGE_BAR_HEIGHT = 68.0

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
		
		# Enhanced stage info for dyslexic children with word length hint
		var word_length = 3 + (dungeon_num - 1)
		var word_hint = "[color=e8883b]" + str(word_length) + " - letter words [/color]"
		
		stage_info_label.text = "Dungeon " + str(dungeon_num) + " - " + stage_type + " " + str(stage_num) + " | " + word_hint
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

	# Update player icon texture first
	_update_player_icon_texture(player_icon)
	
	var dungeon_num = battle_scene.dungeon_manager.dungeon_num
	var stage_num = battle_scene.dungeon_manager.stage_num # 1..5
	
	# CONSTRAINT: Standard icon size for all elements (44x44 pixels base, with scene scaling)
	const ICON_SIZE = Vector2(44, 44)
	
	# Note: Player positioning is now based on current enemy icon position
	# Player icon will be positioned directly below the current stage's enemy icon
	
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
	
	# REDESIGNED: Clean stage visualization with consistent sizing
	for i in range(slot_count):
		var slot = slots.get_child(i)
		var icon = slot.get_node_or_null("EnemyIcon") as TextureRect
		if icon:
			var is_boss = (i == 4)
			var is_completed = (i < (stage_num - 1)) # Stages before current are completed
			var is_current = (i == (stage_num - 1)) # Current stage player is on
			var is_locked = (i >= stage_num) # Stages after current are locked
			
			# CONSTRAINT: Force consistent icon sizing
			icon.size = ICON_SIZE
			icon.custom_minimum_size = ICON_SIZE
			
			# Set appropriate texture
			if is_locked:
				icon.texture = lock_tex
			elif is_boss:
				icon.texture = boss_tex
			else:
				icon.texture = enemy_tex
			
			# Set visual state with proper contrast
			if is_completed:
				icon.modulate = Color(0.5, 0.5, 0.5, 0.7) # Dimmed completed stages
			elif is_current:
				icon.modulate = Color(1.3, 1.3, 1.1, 1.0) # Highlighted current stage
			else:
				icon.modulate = Color(1.0, 1.0, 1.0, 1.0) # Normal upcoming stages
			
			icon.visible = true # Always show all enemy icons
	
	# REDESIGNED: Player icon positioning directly below current enemy head
	# Position player icon below the current stage enemy icon (not progress-based)
	var current_stage_index = stage_num - 1 # Convert to 0-based index
	var current_slot = slots.get_child(current_stage_index)
	var current_enemy_icon = current_slot.get_node_or_null("EnemyIcon") as TextureRect
	
	# Get the horizontal center position of the current enemy icon
	var player_x = 0.0
	if current_enemy_icon:
		# Calculate the center X position of the current enemy icon relative to StageProgress
		var slot_rect = (current_slot as Control).get_rect()
		var enemy_icon_center_x = slot_rect.position.x + (slot_rect.size.x / 2.0)
		player_x = enemy_icon_center_x
	else:
		# Fallback: use scene design position for stage 1
		player_x = 17.0 + (ICON_SIZE.x / 2.0) # Center of original PlayerIcon position
	
	# Position player icon directly below the current enemy icon
	# StageSlots: Y=11-58, so place PlayerIcon below at Y=64+ to avoid overlap  
	var player_y = 60.0 # Position below enemy icons (StageSlots bottom is at Y=58, add margin)
	
	# Use offset positioning to match scene design exactly (not position property)
	player_icon.offset_left = player_x - (ICON_SIZE.x / 2.0) # Center icon horizontally below enemy
	player_icon.offset_top = player_y
	player_icon.offset_right = player_icon.offset_left + ICON_SIZE.x
	player_icon.offset_bottom = player_icon.offset_top + ICON_SIZE.y
	
	# CONSTRAINT: Force consistent player icon sizing to match scene design
	player_icon.size = ICON_SIZE
	player_icon.custom_minimum_size = ICON_SIZE
	player_icon.visible = true
	player_icon.modulate = Color(1.0, 1.0, 1.0, 1.0) # Always fully visible
	
	# CONSTRAINT: Ensure player icon stays above other elements but below overlays
	(player_icon as Control).z_as_relative = false
	(player_icon as Control).z_index = -99
	
	print("UIManager: Stage progress updated - Stage: ", stage_num, "/", slot_count,
		  " Player icon positioned below current enemy at: (", player_icon.offset_left, ", ", player_icon.offset_top, ") Size: ", ICON_SIZE)
	
	# Update progress bar fill to reflect completion
	if bar_bg and bar_fill:
		var bg_rect = (bar_bg as Control).get_rect()
		var stage_progress = float(stage_num - 1) / 4.0 # 0.0 to 1.0 for stages 1-5
		var fill_width = max(0.0, bg_rect.size.x * stage_progress)
		
		# Maintain proper bar positioning
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
			else:
				current_character = "lexia"
	
	# Load the appropriate head texture based on character
	var head_texture: Texture2D = null
	match current_character.to_lower():
		"lexia":
			head_texture = load("res://gui/Update/icons/lexia_head.png")
		"ragna":
			head_texture = load("res://gui/Update/icons/ragna_head.png")
		_:
			# Default fallback for any unknown character
			head_texture = load("res://gui/Update/icons/lexia_head.png")
			print("UIManager: Unknown character '" + str(current_character) + "', using Lexia head as fallback")
	
	# Apply the texture with constraint-based sizing and character scaling
	if head_texture:
		player_icon.texture = head_texture
		
		# CHARACTER SCALING: Normalize different character head sizes
		# Based on scene design: PlayerIcon scale=1.1035504, but different textures need normalization
		var base_scale = 1.0
		match current_character.to_lower():
			"lexia":
				# Lexia head is larger, needs slight scaling down for consistency
				base_scale = 0.9
			"ragna":
				# Ragna head is smaller, use normal scale
				base_scale = 1.1
		
		# Apply character-specific scaling while maintaining scene design scale
		var scene_scale = 1.1035504 # From BattleScene.tscn PlayerIcon design
		player_icon.scale = Vector2(base_scale * scene_scale, base_scale * scene_scale)
		
		# CONSTRAINT: Ensure consistent sizing regardless of original texture size
		player_icon.size = STAGE_ICON_SIZE
		player_icon.custom_minimum_size = STAGE_ICON_SIZE
		player_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		player_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		print("UIManager: Updated player icon to " + current_character + " head with scale " + str(base_scale * scene_scale) + " and size: ", STAGE_ICON_SIZE)
	else:
		print("UIManager: ERROR - Failed to load head texture for character: " + current_character)