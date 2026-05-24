extends Area2D

enum PatrolMode { HOVER, VERTICAL, HORIZONTAL }

#@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
# 위/아래로 흔들리는 진폭(픽셀). 약 반 블럭 정도면 8 전후가 자연스러움.
@export var amplitude: float = 8.0
# 한 사이클(위→아래→위) 도는 데 걸리는 시간(초). 값이 클수록 더 천천히 살랑거림.
@export var period: float = 4.0
# 스프라이트 투명도. 0.0(투명) ~ 1.0(불투명). 0.7 = 70%.
@export_range(0.0, 1.0) var alpha: float = 1
@export var max_health : int = 8
@export var patrol_mode : PatrolMode = PatrolMode.HOVER
@export var patrol_distance : float = 30.0
@export var patrol_speed : float = 20.0
@export var hover_intensity : float = 2.0
@export var hover_tilt : float = 5.0
@export var fall_death_y : float = 260.0

## 이 드론이 노릴 캐릭터. 빈 값(&"")이면 모든 캐릭터에게 적.
## 특정 id (예: &"bird") 설정 시 그 캐릭터에게만 데미지/총알 적용.
@export var enemy_to : StringName = &""

var health : int
var origin : Vector2
var patrol_direction : float = 1.0
var time_elapsed : float = 0.0

func _ready() -> void:
	health = max_health
	origin = position

## 게임 디자인: planner가 level_6에 있을 때만 드론 택시가 정지한다 (탑승 컨셉).
## 그 외 (다른 캐릭터 / 다른 레벨)는 정상 patrol.
func _is_frozen_for_planner_in_level_6() -> bool:
	if PlayerStats.selected_character_id != &"planner":
		return false
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	return tree.current_scene.scene_file_path == "res://Scenes/level_6.tscn"

func _process(delta: float) -> void:
	# fall_death_y <= 0 이면 "이 드론은 추락사 비활성화" 의미로 간주.
	# (0으로 두면 132 같은 정상 위치도 즉시 queue_free 되어 안 보이는 사고가 남)
	if fall_death_y > 0.0 and global_position.y > fall_death_y:
		queue_free()
		return

	# planner가 level_6에 있을 땐 드론 택시 정지 (게임 디자인: planner가 탑승 중).
	# patrol/hover 계산 건너뜀 → 그 자리에 멈춰 있음.
	if _is_frozen_for_planner_in_level_6():
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

	sprite.flip_h = patrol_direction > 0
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
	if PlayerStats.is_selected_immune_in_current_level():
		return
	body.take_damage(1)

func _is_enemy_to_selected() -> bool:
	if enemy_to == &"":
		return true
	return PlayerStats.selected_character_id == enemy_to
