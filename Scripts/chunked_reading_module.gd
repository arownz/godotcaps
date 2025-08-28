extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_back_button_pressed():
    $ButtonClick.play()
    print("PhonicsModule: Returning to module selection")
    _fade_out_and_change_scene("res://Scenes/ModuleScene.tscn")


func _fade_out_and_change_scene(scene_path: String):
    # Stop any playing TTS before changing scenes
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
    await tween.finished
    get_tree().change_scene_to_file(scene_path)