extends Area2D
## Researcher의 공격: 작은 폭발이 날아가다가 적에게 맞는 순간 큰 폭발로 전환.
##
## 시트 구성 (explosion_bullet.tscn의 SpriteFrames):
##   - frame 0 = 작은 폭발 (비행 중)
##   - frame 1 = 큰 폭발 (impact)
## SpriteFrames의 "fire" 애니메이션은 외부 트리거를 받기 전까지 frame 0에서 정지.

@export var speed : float = 100.0
@export var damage : int = 1
@export var max_range : float = 56.0
## spawn 시 캐릭터 중앙에서 진행 방향으로 옮길 픽셀 수. 오른쪽 향할 땐 +,
## 왼쪽 향할 땐 자동으로 - (direction과 곱해짐).
@export var spawn_offset_x : float = 5.0
## 적중(impact) 시 큰 폭발 frame을 보여줄 시간 (초).
@export var impact_hold : float = 0.18

var direction : float = 1.0
var traveled : float = 0.0
var _exploded : bool = false

@onready var anim_sprite : AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# 방향 앞쪽으로 spawn 위치 보정 — 캐릭터보다 약간 앞에서 시작하게.
	position.x += spawn_offset_x * direction
	anim_sprite.flip_h = direction < 0
	# 비행 중에는 작은 폭발 frame 0 정지.
	anim_sprite.stop()
	anim_sprite.frame = 0

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	var move : float = speed * direction * delta
	position.x += move
	traveled += absf(move)
	if traveled >= max_range:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _exploded:
		return
	if not area.is_in_group("Enemy"):
		return
	if area.has_method("take_bullet_damage"):
		area.take_bullet_damage(damage)
	_explode()

## 적중 순간: 큰 폭발 frame으로 전환 + 잠시 정지 표시 → 사라짐.
func _explode() -> void:
	_exploded = true
	anim_sprite.frame = 1
	set_deferred("monitoring", false)  # 추가 hit 방지
	await get_tree().create_timer(impact_hold).timeout
	queue_free()
