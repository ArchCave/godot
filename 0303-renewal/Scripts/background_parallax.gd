extends Node2D

@export var parallax : float = 0.3
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
	global_position = _origin + (player.global_position - _player_origin) * parallax
