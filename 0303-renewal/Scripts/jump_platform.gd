extends StaticBody2D

@export var player : NodePath
@export var player_foot_offset : float = 9.0  # 캡슐 바닥 = position.y(1) + height/2(8) = 9
@export var drop_duration : float = 0.3

var _player : CharacterBody2D
var _shapes : Array[CollisionShape2D] = []


func _ready() -> void:
	if player != NodePath(""):
		_player = get_node_or_null(player) as CharacterBody2D
	if _player == null:
		var nodes := get_tree().get_nodes_in_group("player")
		if nodes.size() > 0:
			_player = nodes[0] as CharacterBody2D

	for c in _all_children(self):
		if c is CollisionShape2D:
			c.one_way_collision = false  # 끔. 우리가 직접 제어.
			_shapes.append(c)


func _all_children(n: Node) -> Array:
	var out : Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_children(c))
	return out


func _physics_process(_delta: float) -> void:
	if _player == null:
		return

	var foot_y : float = _player.global_position.y + player_foot_offset

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
