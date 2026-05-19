extends Node2D

@export var parallax : float = 0.3
# 배경이 플레이어를 따라잡는 시간(초). 0이면 즉시 따라옴(기본). 값이 클수록 더 느릿하게 따라옴.
@export var smoothing : float = 0.0

var _origin : Vector2
var _player_origin : Vector2
var player : Node2D

func _ready():
	# Player 노드는 "Player" 그룹으로 찾음. 깊이 상관없이 동작.
	player = get_tree().get_first_node_in_group("Player")
	_origin = global_position
	if player != null:
		_player_origin = player.global_position

func _process(delta):
	if player == null:
		return
	var target : Vector2 = _origin + (player.global_position - _player_origin) * parallax
	if smoothing <= 0.0:
		global_position = target
	else:
		var t : float = 1.0 - exp(-delta / smoothing)
		global_position = global_position.lerp(target, t)
