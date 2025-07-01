extends Control

# Load dyslexia-friendly font
var dyslexia_font: FontFile

func _ready():
	print("FlipQuizModule: Flip Quiz module loaded")
	
	# Load and apply dyslexia-friendly font
	_load_dyslexia_font()
	_apply_dyslexia_font_to_node(self)

func _load_dyslexia_font():
	dyslexia_font = load("res://Fonts/dyslexiafont/OpenDyslexic-Regular.otf")
	if not dyslexia_font:
		print("Warning: Could not load OpenDyslexic font, falling back to default")

func _apply_dyslexia_font_to_node(node: Node):
	if node is Label:
		if dyslexia_font:
			node.add_theme_font_override("font", dyslexia_font)
	elif node is Button:
		if dyslexia_font:
			node.add_theme_font_override("font", dyslexia_font)
	elif node is RichTextLabel:
		if dyslexia_font:
			node.add_theme_font_override("normal_font", dyslexia_font)
	
	# Recursively apply to all children
	for child in node.get_children():
		_apply_dyslexia_font_to_node(child)

func _on_back_button_pressed():
	print("FlipQuizModule: Returning to module selection")
	get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")
