extends Node

func _ready():
	# This is only needed if you don't have the font yet
	# Create a DynamicFont resource
	var font = FontFile.new()
	font.font_path = "res://Fonts/OpenDyslexic-Regular.otf"
	font.size = 16
	
	# Save the resource
	ResourceSaver.save(font, "res://Fonts/OpenDyslexic-Regular.tres")
