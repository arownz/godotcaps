class_name ChallengeResource
extends Resource

@export var challenge_id: String = "whiteboard"
@export var challenge_name: String = "Whiteboard Challenge"
@export var challenge_description: String = "Write the word to counter the attack!"
@export var scene_path: String = "res://Scenes/WordChallengePanel_Whiteboard.tscn"
@export var success_bonus_damage: int = 20
@export var failure_damage_multiplier: float = 2.0
