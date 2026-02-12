extends Sprite2D

var speed : float = 100

func _ready() -> void:
	position.x =900
	position.y =1200
	position=Vector2(500,900)



func _process(delta: float) -> void:
	var direction = Vector2(1,1)
	position += direction * delta * speed
