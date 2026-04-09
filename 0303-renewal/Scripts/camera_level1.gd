extends Camera2D

@export var map_width: float = 320  # 320 기본 가로 길이
@export var map_height: float = 180  # 180 기본 세로 길이

func _ready():
	var screen = get_viewport().get_visible_rect().size  # 320 x 180
	var zoom_x = map_width / screen.x   # 1100 / 320 = 3.44
	var zoom_y = map_height / screen.y  # 180 / 180 = 1.0
	zoom = Vector2(max(zoom_x, zoom_y), max(zoom_x, zoom_y))  # zoom = 3.44
