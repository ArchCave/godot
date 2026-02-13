extends Area3D

@export var clicks_to_pop :int = 5
@export var size_increase : float = 0.2
@export var score_to_give : int = 1

var manager 
# Called when the node enters the scene tree for the first time.
func _ready():
	manager = $".."


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is not InputEventMouseButton:
		return
		
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
	
	if not event.pressed:
		return
	
	
	scale += Vector3.ONE * size_increase
	clicks_to_pop -= 1
	
	if clicks_to_pop == 0:
		manager.increase_score(score_to_give)
		queue_free()
	
