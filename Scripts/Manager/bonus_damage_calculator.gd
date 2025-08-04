class_name BonusDamageCalculator
extends RefCounted

# Centralized bonus damage calculation for challenges
# This eliminates duplication between STT and Whiteboard panels

# Calculate bonus damage based on player stats and challenge type
static func calculate_bonus_damage(challenge_type: String, battle_scene = null) -> int:
	if not battle_scene:
		battle_scene = Engine.get_main_loop().current_scene
	
	if battle_scene and battle_scene.has_method("get") and battle_scene.player_manager:
		var player_base_damage = battle_scene.player_manager.player_damage
		
		# Different bonus ranges for different challenge types (for balance)
		var bonus_percent = 0.0
		match challenge_type:
			"stt":
				# STT (speech-to-text) - slightly higher reward for speaking challenges
				bonus_percent = randf_range(0.35, 0.65)
			"whiteboard":
				# Whiteboard - consistent with STT for balance
				bonus_percent = randf_range(0.30, 0.60)
			_:
				# Default fallback
				bonus_percent = randf_range(0.30, 0.60)
		
		var bonus_amount = int(player_base_damage * bonus_percent)
		
		# Ensure minimum bonus of 3 and reasonable maximum (not overpowered)
		bonus_amount = max(3, min(bonus_amount, int(player_base_damage * 0.75)))
		
		print("BonusDamageCalculator: %s Challenge - Base damage: %d, Bonus: %d, Total: %d" % [
			challenge_type.capitalize(), player_base_damage, bonus_amount, player_base_damage + bonus_amount
		])
		
		return bonus_amount
	else:
		# Fallback to fixed value if battle scene not accessible
		print("BonusDamageCalculator: Using fallback bonus damage")
		return 8

# Alternative static method for backward compatibility
static func get_challenge_bonus(player_damage: int, _challenge_type: String = "default") -> int:
	var bonus_percent = randf_range(0.30, 0.60)
	var bonus_amount = int(player_damage * bonus_percent)
	return max(3, min(bonus_amount, int(player_damage * 0.75)))
