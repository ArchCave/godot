extends AnimatableBody2D

enum MovementMode { NONE, HORIZONTAL, VERTICAL }

@export var player : NodePath
@export var player_foot_offset : float = 9.0  # 캡슐 바닥 = position.y(1) + height/2(8) = 9
@export var drop_duration : float = 0.3

@export var movement_mode : MovementMode = MovementMode.NONE
@export var movement_distance : float = 0.0     # px, one-way distance from origin
@export var movement_direction : int = -1       # -1 = left/up first, 1 = right/down first
@export var movement_speed : float = 30.0       # px/s

var _player : CharacterBody2D
var _shapes : Array[CollisionShape2D] = []

var _move_origin : Vector2
var _move_offset : float = 0.0
var _move_phase : int = 1   # 1 = moving away from origin, -1 = returning


func _ready() -> void:
	_resolve_player()

	for c in _all_children(self):
		if c is CollisionShape2D:
			# Godot 내장 one-way 사용: 위에서 떨어지면 안착, 옆/아래는 자유 통과.
			# 수동 disable 관리 안 함 — drop-through(ui_down) 시에만 임시로 disable.
			c.one_way_collision = true
			_shapes.append(c)

	_move_origin = position


func _resolve_player() -> void:
	# 1) 인스펙터에서 지정한 NodePath
	if player != NodePath(""):
		_player = get_node_or_null(player) as CharacterBody2D
	# 2) 그룹 폴백: PlayerSpawner로 늦게 스폰되는 케이스 + 잘못된 NodePath 케이스 모두 처리.
	if _player == null:
		for group_name in ["Player", "player"]:
			var nodes := get_tree().get_nodes_in_group(group_name)
			if nodes.size() > 0:
				_player = nodes[0] as CharacterBody2D
				break


func _all_children(n: Node) -> Array:
	var out : Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_children(c))
	return out


func _physics_process(delta: float) -> void:
	_apply_patrol(delta)

	# 플레이어가 아직 안 잡혔으면(스포너로 늦게 스폰되는 케이스) 매 프레임 재시도.
	if _player == null:
		_resolve_player()
		if _player == null:
			return

	# 움직이는 플랫폼은 항상 솔리드.
	if movement_mode != MovementMode.NONE:
		for s in _shapes:
			s.disabled = false
		return

	# 평소엔 Godot 내장 one_way_collision이 알아서 처리하므로 수동 disable 안 함.
	# drop-through (ui_down) 시: 이 바디 위에 서 있을 때 모든 shape를 잠깐 disable.
	# 한 Jump 노드에 shape들이 16px 간격으로 빽빽이 쌓여있어, 하나만 disable하면
	# 바로 아래 shape에 다시 안착되므로 전부 disable해야 실제로 떨어짐.
	if Input.is_action_just_pressed("ui_down") and _player.is_on_floor() and _is_player_standing_on_self():
		for s in _shapes:
			s.disabled = true
		_player.global_position.y += 2.0
		await get_tree().create_timer(drop_duration).timeout
		for s in _shapes:
			s.disabled = false


func _is_player_standing_on_self() -> bool:
	for i in _player.get_slide_collision_count():
		var col : KinematicCollision2D = _player.get_slide_collision(i)
		if col.get_collider() == self:
			return true
	return false


func _half_h(s: CollisionShape2D) -> float:
	if s.shape is RectangleShape2D:
		return (s.shape as RectangleShape2D).size.y * 0.5
	return 0.0


func _apply_patrol(delta: float) -> void:
	if movement_mode == MovementMode.NONE or movement_distance <= 0.0:
		return

	_move_offset += movement_speed * float(_move_phase) * delta
	if _move_phase == 1 and _move_offset >= movement_distance:
		_move_offset = movement_distance
		_move_phase = -1
	elif _move_phase == -1 and _move_offset <= 0.0:
		_move_offset = 0.0
		_move_phase = 1

	var disp := Vector2.ZERO
	match movement_mode:
		MovementMode.HORIZONTAL:
			disp.x = float(movement_direction) * _move_offset
		MovementMode.VERTICAL:
			disp.y = float(movement_direction) * _move_offset
	position = _move_origin + disp
