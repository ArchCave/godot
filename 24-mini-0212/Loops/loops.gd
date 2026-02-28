extends Node2D

var star_scene : PackedScene = preload("res://Loops/star.tscn")

func _ready ():
	var star = star_scene.instantiate()
	add_child(star)
	
	star.position.x = randf_range(-180,180)
	star.position.y = randf_range(-100,100)
	
