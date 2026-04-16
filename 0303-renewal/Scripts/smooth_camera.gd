extends Camera2D

@export var follow_speed : float = 3.0
@export var look_ahead_distance : float = 10.0
@export var look_ahead_speed : float = 1.0

var target_look_ahead : float = 0.0
var current_look_ahead : float = 0.0

func _ready():
	position_smoothing_enabled = true
	position_smoothing_speed = follow_speed

func _process(delta: float) -> void:
	var player = get_parent()
	if not player:
		return

	# 이동 방향으로 카메라를 살짝 앞서 보게 함
	if player.velocity.x > 1.0:
		target_look_ahead = look_ahead_distance
	elif player.velocity.x < -1.0:
		target_look_ahead = -look_ahead_distance
	else:
		target_look_ahead = 0.0

	current_look_ahead = lerp(current_look_ahead, target_look_ahead, look_ahead_speed * delta)
	offset = Vector2(current_look_ahead, 0)
