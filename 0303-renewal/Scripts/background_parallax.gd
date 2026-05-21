extends Node2D

@export var parallax : float = 0.3
# 배경이 플레이어를 따라잡는 시간(초). 0이면 즉시 따라옴(기본). 값이 클수록 더 느릿하게 따라옴.
@export var smoothing : float = 0.0

# 둥둥 떠다니는 효과. 0이면 비활성.
@export var float_amplitude : float = 0.0   # 위/아래 진폭(픽셀)
@export var float_period : float = 4.0      # 한 사이클에 걸리는 시간(초)
@export var float_phase : float = 0.0       # 0~1 사이. 같은 period의 다른 스프라이트끼리 어긋나게 하려고 씀

# 자신 대신 외부 Node2D를 움직이고 싶을 때 지정. 비워두면 자신을 움직임.
# 자체 스크립트가 이미 있는 노드(EndFlag 같은 Area2D)를 둥둥 떠다니게 하려고 쓸 때 유용.
@export var target_path : NodePath

var _target : Node2D
var _origin : Vector2
var _player_origin : Vector2
var _time : float = 0.0
var player : Node2D

func _ready():
	# Player 노드는 "Player" 그룹으로 찾음. 깊이 상관없이 동작.
	player = get_tree().get_first_node_in_group("Player")
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		_target = self
	_origin = _target.global_position
	if player != null:
		_player_origin = player.global_position

func _process(delta):
	if player == null:
		return
	_time += delta
	var target : Vector2 = _origin + (player.global_position - _player_origin) * parallax
	if float_amplitude != 0.0 and float_period > 0.0:
		var phase_rad : float = (_time / float_period + float_phase) * TAU
		target.y += sin(phase_rad) * float_amplitude
	if smoothing <= 0.0:
		_target.global_position = target
	else:
		var t : float = 1.0 - exp(-delta / smoothing)
		_target.global_position = _target.global_position.lerp(target, t)
