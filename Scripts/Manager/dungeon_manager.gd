class_name DungeonManager
extends Node

# Add signals for better decoupling
signal stage_advanced(dungeon_num, stage_num)
signal dungeon_advanced(dungeon_num)
signal dungeon_reset

var battle_scene  # Reference to the main battle scene

# Dungeon and stage tracking
var dungeon_num = 1
var stage_num = 1
var max_dungeons = 3
var max_stages_per_dungeon = 5
var previous_dungeon = 1  # Used to track dungeon transitions

func _init(scene):
	battle_scene = scene

func initialize():
	# For testing, always start at dungeon 1, stage 1
	dungeon_num = 1
	stage_num = 1
	previous_dungeon = 1
	
	# Uncomment these for testing different scenarios later
	# dungeon_num = 2
	# stage_num = 3

func advance_stage():
	# Store previous values to check for transitions
	var old_dungeon = dungeon_num
	
	# Increment stage
	stage_num += 1
	
	# Check if we need to advance to the next dungeon
	if stage_num > max_stages_per_dungeon:
		stage_num = 1
		dungeon_num += 1
		
		# Check if we've completed all dungeons
		if dungeon_num > max_dungeons:
			# For now, loop back to dungeon 1
			dungeon_num = 1
	
	# Emit signals
	emit_signal("stage_advanced", dungeon_num, stage_num)
	
	# If dungeon changed, emit dungeon advanced signal
	if old_dungeon != dungeon_num:
		emit_signal("dungeon_advanced", dungeon_num)

func is_new_dungeon():
	# Check if we've just transitioned to a new dungeon
	if previous_dungeon != dungeon_num:
		previous_dungeon = dungeon_num
		return true
	return false

func reset():
	# Reset to first dungeon, first stage
	dungeon_num = 1
	stage_num = 1
	previous_dungeon = 1
	
	# Emit signal
	emit_signal("dungeon_reset")
