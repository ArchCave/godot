extends Camera2D

@export var viewport_width: float = 1100

func _ready():
	limit_right = int(viewport_width)
