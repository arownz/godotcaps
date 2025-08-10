class_name BonusDamageCalculator
extends RefCounted

# Centralized bonus damage calculation for challenges
# This eliminates duplication between STT and Whiteboard panels

# Calculate bonus damage based on player stats and challenge type
static func calculate_bonus_damage(challenge_type: String, match_quality: String = "perfect", battle_scene = null) -> int:
	if not battle_scene:
		battle_scene = Engine.get_main_loop().current_scene
	
	if battle_scene and battle_scene.has_method("get") and battle_scene.player_manager:
		var player_base_damage = battle_scene.player_manager.player_damage
		
		# Tiered bonus system based on match quality
		var bonus_percent = 0.0
		match match_quality:
			"perfect":
				# Perfect match - full bonus range
				match challenge_type:
					"stt":
						bonus_percent = randf_range(0.50, 0.75) # Higher for perfect STT
					"whiteboard":
						bonus_percent = randf_range(0.45, 0.70) # Higher for perfect whiteboard
					_:
						bonus_percent = randf_range(0.45, 0.70)
			"close":
				# Close match - reduced but still meaningful bonus
				match challenge_type:
					"stt":
						bonus_percent = randf_range(0.25, 0.40) # Moderate for close STT
					"whiteboard":
						bonus_percent = randf_range(0.20, 0.35) # Moderate for close whiteboard
					_:
						bonus_percent = randf_range(0.20, 0.35)
			_:
				# Default fallback
				bonus_percent = randf_range(0.30, 0.60)
		
		var bonus_amount = int(player_base_damage * bonus_percent)
		
		# Ensure minimum bonus and reasonable maximum based on match quality
		if match_quality == "perfect":
			bonus_amount = max(5, min(bonus_amount, int(player_base_damage * 0.80)))
		else: # close match
			bonus_amount = max(3, min(bonus_amount, int(player_base_damage * 0.50)))
		
		print("BonusDamageCalculator: %s Challenge (%s match) - Base: %d, Bonus: %d, Total: %d" % [
			challenge_type.capitalize(), match_quality, player_base_damage, bonus_amount, player_base_damage + bonus_amount
		])
		
		return bonus_amount
	else:
		# Fallback values based on match quality
		if match_quality == "perfect":
			return 10
		else: # close match
			return 5

# Alternative static method for backward compatibility
static func get_challenge_bonus(player_damage: int, _challenge_type: String = "default") -> int:
	var bonus_percent = randf_range(0.30, 0.60)
	var bonus_amount = int(player_damage * bonus_percent)
	return max(3, min(bonus_amount, int(player_damage * 0.75)))
