extends Area2D
## 캐릭터별 종료지점.
## character_id가 PlayerStats에서 선택된 캐릭터와 일치할 때만 보이고 활성화되며,
## 일치하지 않는 EndFlag는 visible=false + 감지/충돌 OFF 상태가 된다.
## (queue_free 안 함 — 트리에는 남아있고 단지 비활성/숨김.)
##
## 한 레벨에 캐릭터 수만큼(보통 3개) 인스턴스를 떨어뜨려서 사용한다.
## character_id를 비워두면 모든 캐릭터에 대해 활성화 (구버전 호환 / 폴백).

## scene_to_load: PackedScene (인스펙터 드래그). 순환 참조(level_A ↔ level_B)를
## 만들면 ext_resource 파싱 에러 → 양쪽 씬 다 로드 실패한다. 그런 경우엔 이걸 비우고
## scene_to_load_path에 "res://Scenes/level_X.tscn" 경로를 직접 입력하면 런타임에
## load_scene_file로 우회한다.
@export var scene_to_load : PackedScene
@export_file("*.tscn") var scene_to_load_path : String = ""
@export var character_id: StringName = &""
## AnimatedSprite2D가 없는 EndFlag(static Sprite2D만 가진 케이스)에서
## body_entered → 씬 전환 사이의 대기 시간. 이 동안 캐릭터는 이미 set_physics_process(false)
## 상태라 조작 불가. 예: PlannerEndFlag는 5.0초로 설정해 sprite 보이는 연출을 길게.
@export var static_hold_duration : float = 0.4
## (선택) 이 EndFlag가 작동하려면 먼저 player가 이 Area2D 안에 한 번 들어가야 함.
## 비워두면 선행 조건 없음 (즉시 작동). 같은 씬 안의 Area2D만 가능.
@export var prerequisite_area: NodePath
## body_entered 시 visible=true 로 켤 자식 노드들. _ready에선 visible=false로 초기화.
## 예: PlannerEndFlag의 IntroBackground/Sprite2D/Enemy3Bird 등 안내용 sprite.
@export var extra_visible_on_trigger : Array[NodePath] = []
## body_entered 시 자기 AnimatedSprite2D 를 visible=false 로 끌지 여부.
## 예: 깃발 sprite는 사라지고 다른 안내 비주얼로 대체할 때.
@export var hide_animated_sprite_on_trigger : bool = false
## 0보다 크면 AnimatedSprite2D 의 animation_finished 신호를 무시하고
## 이 시간 동안 무조건 대기한 뒤 씬 전환. 예: PlannerEndFlag 10초 강제 대기.
@export var trigger_delay : float = 0.0
## 0보다 크면 body_entered 직후 곧바로 freeze 하지 않고 이 시간 동안 player가
## 자유롭게 움직이도록 둔다. 시간이 끝나면 idle로 전환 + physics 정지 +
## 이어서 trigger_delay / animation_finished / static_hold_duration 흐름 진입.
## 예: planner 엔딩 — 3초 자유 이동 → 3초 정지 → 씬 전환 (총 6초).
@export var free_movement_duration : float = 0.0
## 0보다 크면 free_movement_duration 종료 후 곧바로 freeze 하지 않고, 이 시간 동안
## player.move_speed 를 현재값 → 0 으로 부드럽게 tween 한다 (선형). 0에 도달하면
## 정상 흐름(idle + physics 정지 → 씬 전환)으로 이어진다.
## 예: planner 엔딩 — 5초 자유 → 4초 감속 → 정지 → 씬 전환.
@export var deceleration_duration : float = 0.0
## 0보다 크면 free_movement_duration(자유) 종료 후 이 시간 동안 player를 정지(홀드)했다가
## free_movement_after_hold 만큼 다시 자유 이동시킨다. 그 뒤 정상 흐름(정지 → 씬 전환)으로 진입.
## 예: bird 엔딩 — 2초 자유 → 2초 홀드 → 3초 자유 → 씬 전환.
@export var hold_duration : float = 0.0
## hold_duration 종료 후 다시 자유롭게 움직이는 시간. hold_duration > 0 일 때만 의미 있음.
@export var free_movement_after_hold : float = 0.0

## 비주얼 노드는 AnimatedSprite2D(있으면) 또는 정적 Sprite2D(fallback).
## - AnimatedSprite2D: 시작 visible=true, body_entered 시 "end" 애니메이션 재생 → animation_finished 콜백으로 씬 전환
## - Sprite2D만: 시작 visible=false, body_entered 시 visible=true + 짧은 딜레이 → 씬 전환
##   (PlannerEndFlag(center)/PlannerEndFlag2(lower) 같이 정적 sprite만 가진 EndFlag용)
@onready var anim_sprite : AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var static_sprite : Sprite2D = get_node_or_null("Sprite2D")
@onready var collision = $CollisionShape2D

var triggered : bool = false
var _prerequisite_met : bool = true  # prerequisite_area 비어있으면 처음부터 true

func _ready():
	# autoload 직접 참조 — 절대 경로(/root/PlayerStats)는 씬 전환 도중
	# 트리에서 분리된 상태에서 호출되면 "absolute paths from outside the
	# active scene tree" 에러를 뱉는다.
	var selected_id: StringName = &""
	if PlayerStats.has_method("get_selected"):
		var data = PlayerStats.get_selected()
		if data != null:
			selected_id = data.id

	if character_id != &"" and character_id != selected_id:
		# 비매칭 캐릭터의 EndFlag: 숨기고 감지/충돌 OFF
		visible = false
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		collision.set_deferred("disabled", true)
		return

	# 매칭: 보이게 + 활성화
	visible = true
	if anim_sprite != null:
		anim_sprite.visible = true
		anim_sprite.animation_finished.connect(_on_animation_finished)
		# 모든 EndFlag는 닿기 전 정지 상태에서 0번 프레임을 기본으로 표시한다.
		# 씬에 frame 오버라이드가 저장돼 있어도 런타임에 0으로 통일.
		anim_sprite.frame = 0
	if static_sprite != null:
		# 정적 Sprite2D는 body_entered 전엔 숨김 (visual cue: "닿는 순간 나타남")
		static_sprite.visible = false
	# extra_visible_on_trigger에 지정된 노드들은 시작 시점에 모두 숨김.
	for p in extra_visible_on_trigger:
		var n := get_node_or_null(p)
		if n is CanvasItem:
			(n as CanvasItem).visible = false

	# 선행 조건: 지정된 Area2D에 player가 한 번이라도 진입해야만 _on_body_entered가 통과함.
	if not prerequisite_area.is_empty():
		_prerequisite_met = false
		var area := get_node_or_null(prerequisite_area)
		if area != null and area.has_signal("body_entered"):
			area.body_entered.connect(_on_prerequisite_entered)
		else:
			push_warning("[EndFlag] prerequisite_area not found or no body_entered signal: %s" % prerequisite_area)
			_prerequisite_met = true  # 잘못 설정된 경우 기본 동작 유지

func _on_prerequisite_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_prerequisite_met = true

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
	if not body.is_in_group("Player"):
		return
	if not _prerequisite_met:
		return  # 선행 조건 미충족 — 그냥 통과 (다음 맵 전환 안 함)
	triggered = true
	Sfx.play("checkpoint_actived")   # endflag 작동
	collision.set_deferred("disabled", true)
	# 정적 Sprite2D는 닿는 순간 visible=true.
	if static_sprite != null:
		static_sprite.visible = true
	# extra_visible_on_trigger 노드들도 닿는 순간 visible=true.
	for p in extra_visible_on_trigger:
		var n := get_node_or_null(p)
		if n is CanvasItem:
			(n as CanvasItem).visible = true
	# body_entered 시 AnimatedSprite2D 끄기 옵션 (깃발 → 안내 비주얼 전환용).
	if hide_animated_sprite_on_trigger and anim_sprite != null:
		anim_sprite.visible = false
	# free_movement_duration > 0 이면 그동안 freeze 보류 — player가 자유롭게 움직임.
	if free_movement_duration > 0.0:
		await get_tree().create_timer(free_movement_duration).timeout
		if not is_instance_valid(body):
			return
	# hold_duration > 0 이면 잠깐 정지(홀드)한 뒤 free_movement_after_hold 만큼 다시 자유 이동.
	# 예: bird 엔딩 — (위) 자유 → 홀드 → 자유 → (아래) 정지/씬 전환.
	if hold_duration > 0.0:
		body.velocity = Vector2.ZERO
		if body.has_method("play_anim"):
			body.play_anim("Idle")
		Sfx.stop_footsteps()
		body.set_physics_process(false)
		await get_tree().create_timer(hold_duration).timeout
		if not is_instance_valid(body):
			return
		if free_movement_after_hold > 0.0:
			body.set_physics_process(true)
			await get_tree().create_timer(free_movement_after_hold).timeout
			if not is_instance_valid(body):
				return
	# deceleration_duration > 0 이면 move_speed 를 0 으로 부드럽게 줄임.
	# physics 는 살려둔 채로 속도만 줄어드니까 입력은 들어오지만 점점 안 움직이게 됨.
	if deceleration_duration > 0.0 and "move_speed" in body:
		var dec_tween := create_tween()
		dec_tween.tween_property(body, "move_speed", 0.0, deceleration_duration)
		await dec_tween.finished
		if not is_instance_valid(body):
			return
	# physics 멈추기 전에 idle 애니메이션으로 전환 — 그냥 멈추면 walk/jump 그대로 굳음.
	if body.has_method("play_anim"):
		body.play_anim("Idle")
	Sfx.stop_footsteps()   # 멈출 때 걷기 소리도 정지
	body.set_physics_process(false)
	# 씬 전환 트리거:
	#   - trigger_delay > 0: 무조건 그 시간만큼 대기 (10초 강제 대기 같은 케이스)
	#   - 그 외 AnimatedSprite2D 있으면 "end" 재생 → animation_finished → 씬 전환
	#   - 둘 다 아니면 static_hold_duration 만큼 대기 후 전환
	if trigger_delay > 0.0:
		await get_tree().create_timer(trigger_delay).timeout
		_on_animation_finished()
	elif anim_sprite != null and not hide_animated_sprite_on_trigger:
		anim_sprite.play("end")
	else:
		await get_tree().create_timer(static_hold_duration).timeout
		_on_animation_finished()

func _on_animation_finished() -> void:
	if not triggered:
		return
	if scene_to_load != null:
		get_tree().change_scene_to_packed(scene_to_load)
	elif scene_to_load_path != "":
		get_tree().change_scene_to_file(scene_to_load_path)
	else:
		push_error("[EndFlag] No scene_to_load or scene_to_load_path set on %s" % name)
