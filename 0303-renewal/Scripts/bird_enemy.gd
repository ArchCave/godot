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
func _spawn_coin_fountain(count: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	# 좌(–) ~ 우(+)로 펼치는 수평 속도. count에 맞게 균등 분포.
	for i in count:
		var t : float = 0.0 if count == 1 else float(i) / float(count - 1)  # 0..1
		var vx : float = lerp(-60.0, 60.0, t)
		var vy : float = -100.0 - randf_range(0.0, 30.0)  # 위로 살짝 무작위
		var coin := PoopCoin.instantiate()
		coin.position = position
		coin.drop_ready = true
		# bullet hit 시그널 콜백 안에서 호출되므로 physics flush 중이다 → call_deferred
		# 로 add_child 미루고, _ready가 velocity_y = -80 으로 덮어쓰므로 우리 값은
		# set_deferred 로 큐에 넣어 _ready 뒤에 적용 (MessageQueue FIFO).
		parent.call_deferred("add_child", coin)
		if "velocity_x" in coin:
			coin.set_deferred("velocity_x", vx)
		if "velocity_y" in coin:
			coin.set_deferred("velocity_y", vy)

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
