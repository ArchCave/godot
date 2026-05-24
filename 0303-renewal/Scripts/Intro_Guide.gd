extends Area2D
## 캐릭터 안내 트리거.
## allowed_character_id가 PlayerStats의 선택 캐릭터와 일치할 때만 안내 표시.
## 빈 값(&"")이면 모든 캐릭터에 반응 (구버전 호환 / 폴백).
##
## 사용법: 레벨에 intro_guide.tscn을 인스턴스화하고 인스펙터에서
## allowed_character_id를 bird/researcher/planner 중 골라 설정.
##
## IntroBackground는 선택사항 (없는 경우도 허용 — 배경 없이 안내만 띄울 때).
##
## follow_player_x = true 면 영역 안에 있는 동안 IntroGuide sprite의 x좌표가
## player를 일정 간격(follow_player_x_offset)을 두고 따라간다. y는 고정 유지.
##
## persistent_notice_paths: 영역에 한 번이라도 진입했을 때 visible=true가 되고,
## 그 뒤로는 영역을 벗어나도 visible 상태를 유지하는 자식 노드들의 경로 목록.
## (IntroGuide / IntroBackground는 기존 동작대로 진입/이탈에 맞춰 토글됨.)

@export var allowed_character_id: StringName = &""
## 영역 안에 있는 동안 IntroGuide의 x좌표를 player에게 잠금. y는 그대로.
@export var follow_player_x: bool = false
## player.x 기준으로 IntroGuide가 떨어져 따라올 간격(픽셀). 음수면 왼쪽, 양수면 오른쪽.
@export var follow_player_x_offset: float = 16.0
## 한 번 진입하면 영구 visible 유지할 자식 노드들 (예: notice1, notice2).
@export var persistent_notice_paths: Array[NodePath] = []

@onready var guide_sprite: Sprite2D = get_node_or_null("IntroGuide")
@onready var into_background: Sprite2D = get_node_or_null("IntroBackground")

var _player_in_area: Node2D = null
var _persistent_notices: Array[CanvasItem] = []

func _ready() -> void:
	if guide_sprite:
		guide_sprite.visible = false
	if into_background:
		into_background.visible = false
	# persistent notices도 초기엔 숨김 — 진입 전까지는 안 보여야 함.
	for p in persistent_notice_paths:
		var n := get_node_or_null(p)
		if n is CanvasItem:
			(n as CanvasItem).visible = false
			_persistent_notices.append(n)
	set_process(false)
	# 신호 누락 fallback: spawn 시점에 이미 영역 안에 있는 player가 있으면
	# body_entered 신호가 emit되지 않을 수 있다. 첫 프레임 후 overlap을 직접 체크해서
	# 그 경우에도 _on_body_entered를 한 번 호출해준다.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	for b in get_overlapping_bodies():
		if b.is_in_group("Player"):
			_on_body_entered(b)
			break

func _process(_delta: float) -> void:
	if _player_in_area == null or guide_sprite == null:
		return
	# y는 그대로, x만 player + offset 으로 잠금.
	guide_sprite.global_position.x = _player_in_area.global_position.x + follow_player_x_offset

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if not _is_allowed_character():
		return
	if guide_sprite:
		guide_sprite.visible = true
	if into_background:
		into_background.visible = true
	# persistent notices는 한 번 켜지면 다시 끄지 않음 (영구 표시).
	for n in _persistent_notices:
		n.visible = true
	if follow_player_x:
		_player_in_area = body
		set_process(true)

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if not _is_allowed_character():
		return
	if guide_sprite:
		guide_sprite.visible = false
	if into_background:
		into_background.visible = false
	# persistent notices는 이탈해도 건드리지 않음 → 계속 visible 유지.
	if follow_player_x and _player_in_area == body:
		_player_in_area = null
		set_process(false)

func _is_allowed_character() -> bool:
	if allowed_character_id == &"":
		return true
	return PlayerStats.selected_character_id == allowed_character_id
