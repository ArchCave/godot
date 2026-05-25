extends CharacterBody2D
## 점프하는 새 적. level_8 같이 researcher/planner가 주인공인 맵에서 사용.

@export var gravity : float = 420.0
@export var jump_force : float = 130.0
@export var jump_interval_min : float = 0.6
@export var jump_interval_max : float = 1.6
@export var horizontal_jump_speed : float = 30.0
@export var max_health : int = 2

@onready var sprite : Sprite2D = $Sprite2D
@onready var hurt_area : Area2D = $HurtArea

var health : int
var _jump_timer : float = 0.0
var _facing_dir : float = -1.0
var _dying : bool = false

func _ready() -> void:
	health = max_health
	_reset_jump_timer()
	hurt_area.body_entered.connect(_on_hurt_area_body_entered)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		sprite.frame = 2  # jump pose
	else:
		velocity.x = 0.0
		sprite.frame = 0  # idle/walk pose
		_jump_timer -= delta
		if _jump_timer <= 0.0:
			_jump()

	move_and_slide()

func _jump() -> void:
	velocity.y = -jump_force
	if randf() < 0.4:
		_facing_dir *= -1.0
	velocity.x = horizontal_jump_speed * _facing_dir
	sprite.flip_h = _facing_dir < 0.0
	_reset_jump_timer()

func _reset_jump_timer() -> void:
	_jump_timer = randf_range(jump_interval_min, jump_interval_max)

func _on_hurt_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	# bird player는 같은 새이므로 BirdEnemy의 영향을 받지 않음 (근접 데미지 X).
	if PlayerStats.selected_character_id == &"bird":
		return
	if body.has_method("take_damage"):
		body.take_damage(1)

const PoopCoin := preload("res://Scenes/poop_coin.tscn")
const PoopCoinScript := preload("res://Scripts/poop_coin.gd")
## 슬램으로 죽는 새가 떨어뜨리는 특수 코인의 동시 최대 개수 (바닥에 깔리는 양 제한).
const MAX_SPECIAL_COINS : int = 20

## player_bullet -> enemy_hurt_area(forwarder) -> 여기로 전달됨.
func take_bullet_damage(amount: int) -> void:
	# bird player의 총알도 BirdEnemy에게 영향 없음 (같은 새 종족).
	if PlayerStats.selected_character_id == &"bird":
		return
	health -= amount
	if health <= 0:
		PlayerStats.bird_enemy_kills += 1
		_spawn_coin_fountain(3)
		queue_free()

## 죽은 자리에 코인 N개를 분수처럼 (좌/중/우로 흩어지며 위로 튀어오름) spawn.
## poop_coin.gd가 velocity_x/y와 중력으로 자연스러운 포물선을 그리며 떨어지고
## 바닥 ground_ray가 잡히면 그 자리에 정지 → 플레이어가 픽업 가능.
## special=true면 특수 코인(먹어도 힘 전환 X, 시각 구분)을 떨어뜨리되,
## 바닥에 깔린 특수 코인이 MAX_SPECIAL_COINS를 넘지 않도록 남은 한도만큼만 생성한다.
func _spawn_coin_fountain(count: int, special: bool = false) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var spawn_count : int = count
	if special:
		# 동시 사망 레이스 방지: 한도를 결정 시점에 동기적으로 계산/예약.
		# (코인은 call_deferred로 추가돼 _ready가 늦게 도므로 group 카운트로는 새다.)
		var budget : int = MAX_SPECIAL_COINS - PoopCoinScript.special_alive
		spawn_count = clampi(budget, 0, count)
		if spawn_count <= 0:
			return
	if special:
		# 코인이 표로롱 터지듯 나오는 sparkle 버스트 (1회).
		_spawn_burst_effect(parent)
	# 좌(–) ~ 우(+)로 펼치는 수평 속도. count에 맞게 균등 분포.
	# 공중 체류 시간(약 0.8s) × 속도가 실제 퍼지는 거리라, ±18이면 양쪽으로 약 12~15px
	# (≒ 16px 타일의 0.75칸)만큼 흩어진다. 위로 튀는 분수 높이는 vy로 유지.
	for i in spawn_count:
		var t : float = 0.0 if spawn_count == 1 else float(i) / float(spawn_count - 1)  # 0..1
		var vx : float = lerp(-18.0, 18.0, t)
		# 일반 코인은 위로 살짝 튀어오르고, 가짜(특수) 코인은 생성 시 y속도를 항상 -1.0으로
		# 고정해 위로 튀지 않고 바로 바닥으로 떨어진다.
		var vy : float = -1.0 if special else -100.0 - randf_range(0.0, 30.0)
		var coin := PoopCoin.instantiate()
		coin.position = position
		coin.drop_ready = true
		# velocity는 트리에 넣기 전(=_ready 전)에 동기적으로 설정한다.
		# _ready가 velocity_y==0일 때만 기본값을 넣으므로, 미리 넣은 vx/vy가 보존돼
		# 좌/중/우로 흩어지며 떨어진다. (set_deferred 타이밍 의존을 제거.)
		coin.velocity_x = vx
		coin.velocity_y = vy
		if special:
			# 트리에 넣기 전(=_ready 전)에 동기적으로 설정해야 _ready가 이 값을 읽는다.
			coin.grants_power = false
			PoopCoinScript.special_alive += 1  # 결정 시점에 한도 예약
		# bullet hit / slam 시그널 콜백 안에서 호출되므로 physics flush 중이다 →
		# add_child만 call_deferred 로 미룬다 (즉시 추가 시 "Can't change this state
		# while flushing queries" 오류). velocity는 위에서 이미 동기 설정됨.
		parent.call_deferred("add_child", coin)

## 코인이 "표로롱" 터지듯 나오는 sparkle 파티클 버스트. 죽은 자리에서 1회 분출 후 자동 제거.
func _spawn_burst_effect(parent: Node) -> void:
	var p := CPUParticles2D.new()
	p.position = position
	p.z_index = 3
	p.one_shot = true
	p.explosiveness = 1.0          # 한 번에 팡 터짐
	p.amount = 12
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)   # 위로 솟구쳤다
	p.spread = 180.0               # 사방으로 펼침
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 95.0
	p.gravity = Vector2(0, 240)    # 중력으로 떨어지며 분수 모양
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(1.0, 0.9, 0.45)  # 금빛 반짝임
	p.finished.connect(p.queue_free)
	# die_by_slam은 slam 신호(물리 프레임) 안에서 호출될 수 있어 add_child를 미룬다.
	parent.call_deferred("add_child", p)

## 새를 그 자리에서 조용히 비활성화 (죽음 애니메이션 없음).
## planner_button.gd가 눌렸을 때 맵 전체 새를 한 번에 끄는 용도.
## 즉시 visible/충돌 OFF → 그 다음 queue_free 로 트리에서 완전 제거 (잔재 X).
func deactivate() -> void:
	if _dying:
		return
	_dying = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	visible = false
	if hurt_area:
		hurt_area.set_deferred("monitoring", false)
		hurt_area.set_deferred("monitorable", false)
	for c in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred("disabled", true)
	queue_free()

## TileMap slam에 깔려 즉사. bird Player의 Death 애니메이션과 동일한 frame 시퀀스
## (frame 3 → 4 → 5 → 6, 각 0.2초; Player.tscn::Animation_kyqiw 참조)을 재생.
## 마지막 frame에 도달하면 살짝 페이드아웃 → queue_free. 회전·추락 없음.
## bird_killer.gd가 호출. 죽기 직전 위치는 호출자가 기억해 재스폰.
func die_by_slam() -> void:
	if _dying:
		return
	_dying = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	# hurt 영역과 본체 충돌 비활성 (중복 죽음/플레이어 데미지 방지)
	if hurt_area:
		hurt_area.set_deferred("monitoring", false)
		hurt_area.set_deferred("monitorable", false)
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)

	# 슬램에 맞아 죽는 순간, 그 자리에서 특수 코인 3개를 분수처럼 spawn.
	# 특수 코인은 먹어도 힘으로 전환되지 않고, 바닥에 깔린 총량이 MAX_SPECIAL_COINS로 제한됨.
	# (bird_enemy_kills는 올리지 않아 conditional_through 판정엔 영향 없음.)
	_spawn_coin_fountain(3, true)

	# Bird Death frame 시퀀스: 3 → 4 → 5 → 6 (0.2s 간격)
	var t := create_tween()
	const DEATH_FRAMES : Array[int] = [3, 4, 5, 6]
	const FRAME_DURATION : float = 0.2
	for f in DEATH_FRAMES:
		t.tween_callback(func(): sprite.frame = f)
		t.tween_interval(FRAME_DURATION)
	# 마지막 frame에서 자연스럽게 페이드아웃 → 사라짐
	t.tween_property(sprite, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)
