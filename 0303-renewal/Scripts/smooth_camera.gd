extends Camera2D

@export var follow_speed : float = 3.0
@export var look_ahead_distance : float = 10.0
@export var look_ahead_speed : float = 1.0

var target_look_ahead : float = 0.0
var current_look_ahead : float = 0.0
var _target : Node2D = null
var _follow_via_parent : bool = false

func _ready():
	position_smoothing_enabled = false
	await get_tree().process_frame
	_resolve_target()
	if _target:
		global_position = _target.global_position
	position_smoothing_enabled = true
	position_smoothing_speed = follow_speed

func _resolve_target() -> void:
	# 1) 자식 형태(레거시): get_parent()가 CharacterBody2D면 그대로 따라간다.
	var p := get_parent()
	if p is CharacterBody2D:
		_target = p
		_follow_via_parent = true
		return
	# 2) 분리 형태: "Player" 그룹의 첫 노드를 찾는다.
	_follow_via_parent = false
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0 and players[0] is Node2D:
		_target = players[0]

func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_resolve_target()
		if _target == null:
			return

	if not _follow_via_parent:
		global_position = _target.global_position

	var velocity_x : float = 0.0
	if "velocity" in _target:
		velocity_x = _target.velocity.x

	if velocity_x > 1.0:
		target_look_ahead = look_ahead_distance
	elif velocity_x < -1.0:
		target_look_ahead = -look_ahead_distance
	else:
		target_look_ahead = 0.0

	current_look_ahead = lerp(current_look_ahead, target_look_ahead, look_ahead_speed * delta)
	offset = Vector2(current_look_ahead, 0)
