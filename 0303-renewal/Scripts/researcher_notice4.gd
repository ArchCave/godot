extends Area2D
## 캐릭터 안내 노티스. Player가 영역에 들어오면 sprite를 잠시 표시.
##
## allowed_character_id가 PlayerStats의 선택 캐릭터와 일치할 때만 표시.
## 빈 값(&"")이면 모든 캐릭터에 반응 (구버전 호환 / 폴백).
## 인스펙터에서 bird/researcher/planner 중 골라 설정.

@export var show_duration : float = 3.0
@export var allowed_character_id : StringName = &""

@onready var notice_sprite : Sprite2D = $notice

var _timer : SceneTreeTimer = null
var _was_inside : bool = false

func _ready() -> void:
	notice_sprite.visible = false

# signal(body_entered/exited)에 의존하지 않고 매 프레임 overlap을 직접 체크.
# Area2D가 scene tree 추가 직후 신호가 누락되는 경우를 방지하기 위함.
func _physics_process(_delta: float) -> void:
	var is_inside := false
	for b in get_overlapping_bodies():
		if b.is_in_group("Player"):
			is_inside = true
			break
	if is_inside and not _was_inside:
		if _is_allowed_character():
			_show_notice()
	_was_inside = is_inside

func _show_notice() -> void:
	notice_sprite.visible = true
	_timer = get_tree().create_timer(show_duration)
	var current_timer := _timer
	await current_timer.timeout
	if current_timer != _timer:
		return
	notice_sprite.visible = false

func _is_allowed_character() -> bool:
	if allowed_character_id == &"":
		return true
	return PlayerStats.selected_character_id == allowed_character_id
