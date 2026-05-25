extends Area2D
## TileMap slam 톱 영역. tilemap_slam.gd가 "콰광 도착" 시점에 slam_impact 신호를
## emit하면 그 순간 영역 안에 있는 모든 BirdEnemy를 die_by_slam → 3초 후 같은 자리
## 재스폰. 즉 단순 영역 진입으로는 죽지 않고, 슬램이 실제로 내리치는 순간에만 죽음.
##
## 사용법:
##   1) 이 노드(Area2D)에 본 스크립트 부착
##   2) 자식 CollisionShape2D로 톱 이미지에 닿는 영역 정의
##   3) Inspector에서 slam_source = tilemap_slam.gd가 부착된 TileMapLayer 지정
##   4) bird_enemy_scene은 기본값(BirdEnemy.tscn)이면 따로 설정 불필요

@export var bird_enemy_scene : PackedScene = preload("res://Scenes/BirdEnemy.tscn")
@export var respawn_delay : float = 3.0
## slam_impact 신호를 듣는 대상 (tilemap_slam.gd 부착 노드).
@export var slam_source : NodePath

var _disabled : bool = false

## 외부(planner_button 등)에서 새 죽이기 효과를 영구 무효화할 때 호출.
## 이후의 slam_impact는 무시되며, 이미 예약된 respawn 도 새 BirdEnemy 인스턴스를 만들지만
## 그 시점엔 새들이 deactivate 된 상태이므로 시각적 영향은 없다.
func disable_kills() -> void:
	_disabled = true

const PoopCoinScript := preload("res://Scripts/poop_coin.gd")

func _ready() -> void:
	# 특수 코인 생성 한도 카운터를 레벨 로드마다 깨끗이 초기화
	# (정적 변수라 씬 재로드 시 잔여값이 남을 수 있음 → 누적 방지).
	PoopCoinScript.special_alive = 0
	if slam_source != NodePath(""):
		var src := get_node_or_null(slam_source)
		if src != null and src.has_signal("slam_impact"):
			src.slam_impact.connect(_on_slam_impact)
		else:
			push_warning("[bird_killer] slam_source 노드를 찾지 못했거나 slam_impact 신호 없음: %s" % slam_source)

## "콰광 내리치는 순간"에 호출됨. 그 시점에 영역 안 모든 살아있는 BirdEnemy를 즉사.
func _on_slam_impact() -> void:
	if _disabled:
		return
	var targets : Array = []
	for b in get_overlapping_bodies():
		if _is_killable(b) and not targets.has(b):
			targets.append(b)
	for bird in targets:
		_kill_and_respawn(bird)

## 죽이기 가능한 BirdEnemy인지 (이미 die_by_slam 진행 중이면 false).
func _is_killable(b: Node) -> bool:
	if b == null or not is_instance_valid(b):
		return false
	if not b.has_method("die_by_slam"):
		return false
	if "_dying" in b and b._dying:
		return false
	return true

func _kill_and_respawn(bird: Node2D) -> void:
	if not _is_killable(bird):
		return
	var spawn_pos : Vector2 = bird.global_position
	var parent := bird.get_parent()
	bird.die_by_slam()
	_schedule_respawn(spawn_pos, parent)

func _schedule_respawn(pos: Vector2, parent: Node) -> void:
	if parent == null:
		return
	var timer := get_tree().create_timer(respawn_delay)
	timer.timeout.connect(func():
		# 버튼 등으로 이미 _disabled 가 켜졌으면 이전에 예약된 respawn도 무시.
		# (안 그러면 deactivate 후에 새 새가 또 튀어나옴.)
		if _disabled:
			return
		if not is_instance_valid(parent):
			return
		var new_bird : Node = bird_enemy_scene.instantiate()
		parent.add_child(new_bird)
		if new_bird is Node2D:
			(new_bird as Node2D).global_position = pos
	)
