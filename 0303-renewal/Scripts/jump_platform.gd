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
	if player != NodePath(""):
		_player = get_node_or_null(player) as CharacterBody2D
	if _player == null:
		# 그룹 폴백: Player 노드는 "Player" 그룹에 속해있음. 안전을 위해 두 케이스 모두 확인.
		for group_name in ["Player", "player"]:
			var nodes := get_tree().get_nodes_in_group(group_name)
			if nodes.size() > 0:
				_player = nodes[0] as CharacterBody2D
				break

	for c in _all_children(self):
		if c is CollisionShape2D:
			c.one_way_collision = false  # 끔. 우리가 직접 제어.
			_shapes.append(c)

	_move_origin = position


func _all_children(n: Node) -> Array:
	var out : Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_children(c))
	return out


func _physics_process(delta: float) -> void:
	_apply_patrol(delta)

	if _player == null:
		return

	var foot_y : float = _player.global_position.y + player_foot_offset

	# 움직이는 플랫폼은 항상 솔리드 — 위로 올라갈 때 shape top이 플레이어를
	# 추월해 disable로 빠지는 걸 막기 위함.
	if movement_mode != MovementMode.NONE:
		for s in _shapes:
			s.disabled = false
		return

	# 발이 shape 윗면보다 위에 있으면 enabled (안착 가능)
	# 발이 shape 윗면보다 아래에 있으면 disabled (옆/아래에서 통과)
	for s in _shapes:
		var top_y : float = s.global_position.y - _half_h(s)
		s.disabled = foot_y > top_y

	if Input.is_action_just_pressed("ui_down") and _player.is_on_floor():
		var shape : CollisionShape2D = _shape_under_player()
		if shape != null:
			shape.disabled = true
			_player.global_position.y += 2.0
			await get_tree().create_timer(drop_duration).timeout


func _shape_under_player() -> CollisionShape2D:
	for i in _player.get_slide_collision_count():
		var col : KinematicCollision2D = _player.get_slide_collision(i)
		if col.get_collider() == self:
			return col.get_collider_shape() as CollisionShape2D
	return null


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
