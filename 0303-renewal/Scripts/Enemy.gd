extends Area2D

enum PatrolMode { HOVER, VERTICAL, HORIZONTAL }

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

@export var max_health : int = 8
@export var patrol_mode : PatrolMode = PatrolMode.HOVER
@export var patrol_distance : float = 30.0
@export var patrol_speed : float = 20.0
@export var hover_intensity : float = 2.0
@export var hover_tilt : float = 5.0
@export var fall_death_y : float = 260.0

## 이 적이 노릴 캐릭터. 빈 값(&"")이면 모든 캐릭터에게 적.
## 특정 id (예: &"bird") 설정 시 그 캐릭터에게만 데미지/총알 적용.
@export var enemy_to : StringName = &""

var health : int
var origin : Vector2
var patrol_direction : float = 1.0
var time_elapsed : float = 0.0

func _ready() -> void:
	health = max_health
	origin = position
	anim.play("drone")

func _process(delta: float) -> void:
	if global_position.y > fall_death_y:
		queue_free()
		return

	time_elapsed += delta

	match patrol_mode:
		PatrolMode.HOVER:
			_do_hover(delta)
		PatrolMode.VERTICAL:
			_do_vertical_patrol(delta)
		PatrolMode.HORIZONTAL:
			_do_horizontal_patrol(delta)

func _do_hover(_delta: float) -> void:
	# 제자리에서 약간 기울어서 덜덜거리며 떠있는 느낌
	position.y = origin.y + sin(time_elapsed * 6.0) * hover_intensity
	position.x = origin.x + sin(time_elapsed * 4.3) * (hover_intensity * 0.5)
	sprite.rotation_degrees = sin(time_elapsed * 8.0) * hover_tilt

func _do_vertical_patrol(delta: float) -> void:
	# 위아래로 순찰하며 드론처럼 약간 흔들림
	position.y += patrol_speed * patrol_direction * delta
	if abs(position.y - origin.y) >= patrol_distance:
		patrol_direction *= -1.0
		position.y = origin.y + patrol_distance * patrol_direction * -1.0

	position.x = origin.x

func _do_horizontal_patrol(delta: float) -> void:
	# 좌우로 순찰
	position.x += patrol_speed * patrol_direction * delta
	if abs(position.x - origin.x) >= patrol_distance:
		patrol_direction *= -1.0
		position.x = origin.x + patrol_distance * patrol_direction * -1.0

	sprite.flip_h = patrol_direction < 0
	position.y = origin.y

const PoopCoin = preload("res://Scenes/poop_coin.tscn")

func take_bullet_damage(amount: int) -> void:
	if not _is_enemy_to_selected():
		return
	health -= amount
	if health <= 0:
		PlayerStats.enemy_kills += 1
		_drop_coin()
		queue_free()
	else:
		_flash_hit()

func _drop_coin() -> void:
	var coin = PoopCoin.instantiate()
	coin.position = global_position
	coin.drop_ready = true
	get_parent().add_child(coin)

func _flash_hit() -> void:
	sprite.modulate = Color(1, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_interval(0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.0)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if not _is_enemy_to_selected():
		return
	body.take_damage(1)

func _is_enemy_to_selected() -> bool:
	if enemy_to == &"":
		return true
	return PlayerStats.selected_character_id == enemy_to
