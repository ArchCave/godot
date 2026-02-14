extends Node2D

@export var spawn_count : int = 200
var star_scene : PackedScene = preload("res://Loops/star.tscn")

func _ready ():
	for i in spawn_count:
		var star = star_scene.instantiate()
		add_child(star)
		
		star.position.x = randf_range(-280, 280)
		star.position.y = randf_range(-150, 150)
		
		var star_scale = randf_range(0.5, 1.0)
		star.scale.x = star_scale
		star.scale.y = star_scale
