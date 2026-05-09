extends Area2D

@export var follow_player: bool = true

@onready var bubble_sprite: Sprite2D = _find_bubble_sprite()
@onready var pause_background: Sprite2D = get_node_or_null("pause_background")

var player_in_area: Node2D = null
var bubble_origin_global_y: float = 0.0
var entry_player_y: float = 0.0

func _find_bubble_sprite() -> Sprite2D:
	for child in get_children():
		if child is Sprite2D and child.name != "pause_background":
			return child
	return null

func _ready() -> void:
	if bubble_sprite:
		bubble_origin_global_y = bubble_sprite.global_position.y
		bubble_sprite.visible = false
	if pause_background:
		pause_background.visible = false
	set_process(false)

func _process(_delta: float) -> void:
	if player_in_area == null or bubble_sprite == null:
		return
	bubble_sprite.global_position.x = player_in_area.global_position.x
	var dy: float = player_in_area.global_position.y - entry_player_y
	bubble_sprite.global_position.y = bubble_origin_global_y + dy

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	player_in_area = body
	entry_player_y = body.global_position.y
	if bubble_sprite:
		bubble_sprite.visible = true
	if pause_background:
		pause_background.visible = true
	if follow_player:
		set_process(true)

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	player_in_area = null
	if bubble_sprite:
		bubble_sprite.visible = false
	if pause_background:
		pause_background.visible = false
	set_process(false)
