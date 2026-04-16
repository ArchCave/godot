extends Control

@onready var start_label: Label = $StartLabel
var blink_tween: Tween

func _ready():
	PlayerStats.reset()
	_start_blink()

func _start_blink() -> void:
	blink_tween = create_tween().set_loops()
	blink_tween.tween_property(start_label, "modulate:a", 0.2, 0.6)
	blink_tween.tween_property(start_label, "modulate:a", 1.0, 0.6)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		get_tree().change_scene_to_file("res://Scenes/level_2.tscn")
