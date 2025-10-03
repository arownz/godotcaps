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
		
		# Balanced bonus system for dyslexic children - challenges should feel rewarding but not overpowering
		var bonus_percent = 0.0
		match match_quality:
			"perfect":
				# Perfect match - meaningful but balanced bonus
				match challenge_type:
					"stt":
						bonus_percent = randf_range(0.50, 0.75) # Higher for perfect STT
					"whiteboard":
						bonus_percent = randf_range(0.50, 0.75) # Higher for perfect whiteboard
					_:
						bonus_percent = randf_range(0.50, 0.75)
			"close":
				# Close match - still rewarding to encourage effort
				match challenge_type:
					"stt":
						bonus_percent = randf_range(0.25, 0.35) # Small for close STT
					"whiteboard":
						bonus_percent = randf_range(0.25, 0.35) # Small for close whiteboard
					_:
						bonus_percent = randf_range(0.25, 0.35)
			_:
				# Default fallback - balanced
				bonus_percent = randf_range(0.15, 0.25)
		
		var bonus_amount = int(player_base_damage * bonus_percent)
		
		# Ensure reasonable bonus ranges that don't trivialize combat
		if match_quality == "perfect":
			bonus_amount = max(3, min(bonus_amount, int(player_base_damage * 0.50))) # Max 50% bonus
		else: # close match
			bonus_amount = max(2, min(bonus_amount, int(player_base_damage * 0.25))) # Max 25% bonus
		
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
