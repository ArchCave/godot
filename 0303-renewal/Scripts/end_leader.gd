extends Area2D

const NEGOTIATING_THRESHOLD : int = 30
const ENDING_THRESHOLD : int = 31
const ENDING_DELAY : float = 10.0
const FADE_DURATION : float = 0.3

## 비어있으면 모든 캐릭터에 반응 (구버전 호환). bird/researcher 등으로 설정 시 해당 캐릭터에만 반응.
@export var allowed_character_id : StringName = &""
## 시퀀스 완료 시 전환할 씬 경로.
@export var ending_scene_path : String = "res://Scenes/ending_scene.tscn"
## 협상중 메시지 Sprite2D 경로 (Bird 버전은 negotiating_bird_message, Researcher 버전은 negotiating_researcher_message 등).
@export var negotiating_message_path : NodePath = NodePath("negotiating_bird_message")

@onready var ending_message : Sprite2D = $ending_message
@onready var negotiating_bird_message : Sprite2D = get_node(negotiating_message_path)
@onready var leader_sprite : Sprite2D = $Sprite2D

var player : Node2D = null
var player_inside : bool = false
var poop_count : int = 0
var ending_started : bool = false
var negotiating_y : float = 0.0

func _ready() -> void:
	# 캐릭터 매칭 체크 — 비매칭(예: planner가 선택된 상태에서 end_leader(Bird))이면
	# 자기 자신과 자식 비주얼/감지 모두 비활성. 즉 planner 선택 시 end_leader(Bird)와
	# end_leader(Researcher) 둘 다 자동으로 숨겨진다.
	if allowed_character_id != &"" and PlayerStats.selected_character_id != allowed_character_id:
		visible = false
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		set_process(false)
		return
	# 매칭 캐릭터: 보이게 + 정상 진입.
	visible = true

	ending_message.visible = false
	negotiating_bird_message.visible = false
	negotiating_y = negotiating_bird_message.global_position.y
	player = get_tree().get_first_node_in_group("Player")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
		if player == null:
			return
	leader_sprite.flip_h = player.global_position.x < leader_sprite.global_position.x

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if not _is_allowed_character():
		return
	player = body
	player_inside = true
	_connect_player_signals(body)


func _is_allowed_character() -> bool:
	if allowed_character_id == &"":
		return true
	return PlayerStats.selected_character_id == allowed_character_id

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	player_inside = false
	if not ending_started:
		_reset_messages()

func _connect_player_signals(p: Node2D) -> void:
	if p.has_signal("OnPoopSpawned") and not p.is_connected("OnPoopSpawned", _on_player_poop):
		p.OnPoopSpawned.connect(_on_player_poop)
	if p.has_signal("OnAttackFired") and not p.is_connected("OnAttackFired", _on_player_attack):
		p.OnAttackFired.connect(_on_player_attack)

func _on_player_poop() -> void:
	if ending_started or not player_inside or player == null:
		return
	poop_count += 1
	if poop_count <= NEGOTIATING_THRESHOLD:
		negotiating_bird_message.visible = true
		negotiating_bird_message.global_position = Vector2(player.global_position.x, negotiating_y)
	elif poop_count >= ENDING_THRESHOLD:
		negotiating_bird_message.visible = false
		ending_message.visible = true
		_start_ending_sequence()

func _on_player_attack() -> void:
	if ending_started:
		return
	_reset_messages()

func _reset_messages() -> void:
	poop_count = 0
	ending_message.visible = false
	negotiating_bird_message.visible = false

func _start_ending_sequence() -> void:
	ending_started = true
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)
	var t := create_tween()
	t.tween_interval(ENDING_DELAY)
	t.tween_property(rect, "color:a", 1.0, FADE_DURATION)
	t.tween_callback(func(): get_tree().change_scene_to_file(ending_scene_path))
