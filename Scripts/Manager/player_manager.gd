class_name PlayerManager
extends Node

# Add signals for better decoupling
signal player_health_changed(current_health, max_health)
signal player_defeated
signal player_experience_changed(current_exp, max_exp)
signal player_level_up(new_level)
signal player_skin_changed(skin_name)

var battle_scene  # Reference to the main battle scene

# Player base stats
var player_health = 100
var player_max_health = 100
var player_exp = 0
var player_max_exp = 100
var player_level = 1
var player_damage = 15
var player_name = "Player Name"

# Available player skins
var available_skins = ["default", "wizard", "knight", "ranger"] 
var current_skin = "default"

func _init(scene):
	battle_scene = scene

# This method will be called when enemy attacks
func take_damage(damage: int):
	player_health -= damage
	player_health = max(player_health, 0)  # Ensure health doesn't go below 0
	
	# Emit signal for health change
	emit_signal("player_health_changed", player_health, player_max_health)
	
	# Check if defeated
	if player_health <= 0:
		emit_signal("player_defeated")
		return true
	return false

# Add a heal method if needed
func heal(heal_amount):
	player_health += heal_amount
	player_health = min(player_health, player_max_health)  # Ensure it doesn't go above max
	
	# Emit signal for health change
	emit_signal("player_health_changed", player_health, player_max_health)

func add_experience(exp_amount):
	# Add experience points
	player_exp += exp_amount
	
	# Emit signal that experience changed
	emit_signal("player_experience_changed", player_exp, player_max_exp)
	
	# Check for level up
	if player_exp >= player_max_exp:
		level_up()

func level_up():
	# Calculate overflow experience
	var overflow_exp = player_exp - player_max_exp
	
	# Increase level
	player_level += 1
	
	# Reset experience but keep overflow
	player_exp = overflow_exp
	
	# Increase max experience for next level
	player_max_exp = int(player_max_exp * 1.5)
	
	# Increase player stats
	player_max_health += 20
	player_health = player_max_health  # Fully heal on level up
	player_damage += 5
	
	# Update UI (will be done by the caller)
	
	# Add level up messages
	battle_scene.log_manager.add_message("[color=#4CAF50]LEVEL UP![/color] You are now level " + str(player_level) + "!")
	battle_scene.log_manager.add_message("[color=#4CAF50]Your maximum health increased to " + str(player_max_health) + "![/color]")
	battle_scene.log_manager.add_message("[color=#4CAF50]Your damage increased to " + str(player_damage) + "![/color]")
	
	# Show level up animation
	var player_sprite = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/Player")
	var level_up_tween = create_tween()
	level_up_tween.tween_property(player_sprite, "modulate", Color(1, 1, 0.3), 0.5)
	level_up_tween.tween_property(player_sprite, "modulate", Color(1, 1, 1), 0.5)
	
	# Emit signal that player leveled up
	emit_signal("player_level_up", player_level)

func update_from_tester(tester):
	# Update player stats
	player_health = tester.get_player_health()
	player_max_health = player_health
	player_damage = tester.get_player_damage()

func change_player_skin(skin_name):
	if available_skins.has(skin_name):
		current_skin = skin_name
		
		# Update the player sprite
		var player_sprite = battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/PlayerContainer/Player")
		var texture_path = "res://Sprites/Player/" + skin_name + ".png"
		var texture = load(texture_path)
		
		if texture:
			player_sprite.texture = texture
			
			# Apply appropriate scale based on skin
			match skin_name:
				"wizard":
					player_sprite.scale = Vector2(4.2, 4.2)
				"knight":
					player_sprite.scale = Vector2(4.5, 4.5)
				"ranger":
					player_sprite.scale = Vector2(4.3, 4.3)
				_:  # default
					player_sprite.scale = Vector2(4.57, 4.51)
					
			# Emit signal that skin changed
			emit_signal("player_skin_changed", skin_name)
			return true
	
	return false

# Returns list of available skins for UI display
func get_available_skins():
	return available_skins
