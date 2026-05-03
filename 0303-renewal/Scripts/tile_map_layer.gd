extends TileMapLayer
@onready var intro_tile: TileMapLayer = $"."
@export var scroll_speed : float = 96.0
@export var scroll_height : float = 64.0
var scrolling : bool = true
var tile_origin_y : float = 0.0
# Called when the node enters the scene tree for the first time.

func _ready():
	
	tile_origin_y = intro_tile.position.y

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if scrolling:
		intro_tile.position.y -= scroll_speed * delta
		if intro_tile.position.y <= tile_origin_y - scroll_height:
			intro_tile.position.y += scroll_height
