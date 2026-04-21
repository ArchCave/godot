extends StaticBody2D

@export var target_shape_name : String = "CollisionShape2D_2"

func _ready() -> void:
	if PlayerStats.enemy_kills == 0:
		var shape := get_node_or_null(target_shape_name) as CollisionShape2D
		if shape:
			shape.set_deferred("disabled", true)
