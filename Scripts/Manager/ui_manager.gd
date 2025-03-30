class_name UIManager
extends Node

var battle_scene  # Reference to the main battle scene

func _init(scene):
	battle_scene = scene

func initialize_ui():
	# Set initial UI state
	initialize_player_ui()
	initialize_enemy_ui()
	update_stage_info()

func initialize_player_ui():
	# Set player name
	var player_name_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerName")
	player_name_label.text = battle_scene.player_manager.player_name
	
	# Update player health bar
	update_player_health()
	
	# Set initial player exp
	update_player_exp()

func initialize_enemy_ui():
	# Set enemy name
	var enemy_name_label = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyName")
	enemy_name_label.text = battle_scene.enemy_manager.enemy_name
	
	# Update enemy health bar
	update_enemy_health()
	
	# Set initial enemy skill meter
	update_enemy_skill_meter()

func update_player_health():
	# Update player health bar dynamically
	var health_bar = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/PlayerHealthBar")
	var player_health = battle_scene.player_manager.player_health
	var player_max_health = battle_scene.player_manager.player_max_health
	
	# Update progress bar value
	health_bar.value = (player_health / player_max_health) * 100 if player_max_health > 0 else 0

func update_enemy_health():
	# Update enemy health bar dynamically
	var health_bar = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemyHealthBar")
	var enemy_health = battle_scene.enemy_manager.enemy_health
	var enemy_max_health = battle_scene.enemy_manager.enemy_max_health
	
	# Update progress bar value
	health_bar.value = (enemy_health / enemy_max_health) * 100 if enemy_max_health > 0 else 0

func update_enemy_skill_meter():
	var skill_bar = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemySkillBar")
	var enemy_skill_meter = battle_scene.enemy_manager.enemy_skill_meter
	
	# Update skill bar value directly
	skill_bar.value = enemy_skill_meter

func update_player_exp():
	var exp_bar = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/StatsContainer/EXPContainer/PlayerEXP")
	var exp_label = exp_bar.get_node("EXPValue")
	
	var player_exp = battle_scene.player_manager.player_exp
	var player_max_exp = battle_scene.player_manager.player_max_exp
	
	# Update exp bar value
	exp_bar.value = (player_exp / player_max_exp) * 100
	
	# Update exp label
	exp_label.text = str(player_exp) + "/" + str(player_max_exp)

func update_stage_info():
	var stage_info_label = battle_scene.get_node("MainContainer/BattleAreaContainer/StageInfoLabel")
	var dungeon_num = battle_scene.dungeon_manager.dungeon_num
	var stage_num = battle_scene.dungeon_manager.stage_num
	
	var dungeon_names = {
		1: "The Plains",
		2: "The Forest",
		3: "The Mountain"
	}
	
	var dungeon_name = dungeon_names.get(dungeon_num, "Dungeon " + str(dungeon_num))
	stage_info_label.text = dungeon_name + " - Stage " + str(stage_num)
	
	# Update background based on dungeon
	update_background(dungeon_num)

func update_background(dungeon_num: int):
	# Get the background texture node
	var background = battle_scene.get_node("Background")
	
	# Try to load the appropriate background texture
	var background_path = "res://gui/Backgrounds/Dungeon" + str(dungeon_num) + "_background.png"
	if ResourceLoader.exists(background_path):
		background.texture = load(background_path)
	else:
		# Fallback to default background
		background.texture = load("res://gui/Backgrounds/Dungeon1_background.png")

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
