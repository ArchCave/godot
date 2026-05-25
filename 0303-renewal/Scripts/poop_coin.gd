extends Area2D

# 미리 배치된 보너스 코인 모드. 즉시 활성화된 녹색 코인으로 시작 (똥 단계/대기/낙하 없음).
@export var pre_placed : bool = false
# 먹었을 때 점수 증가량. 일반 코인은 1, 보너스 코인은 큰 값으로 설정.
@export var score_value : int = 1
## false면 특수 코인: 먹어도 점수/점프력으로 전환되지 않고, 시각적으로 약간 다르게 표시됨.
## (level_8 슬램으로 죽는 새가 떨어뜨리는 코인이 이 모드.)
@export var grants_power : bool = true
## 특수 코인일 때 적용하는 색상 틴트 (일반 코인과 구분).
@export var special_tint : Color = Color(0.55, 0.8, 1.0)

## 현재 살아있는 특수 코인 수. bird_enemy.gd가 생성 상한 체크에 사용.
static var special_alive : int = 0

@onready var sprite      = $Sprite2D
@onready var anim_sprite = $AnimatedSprite2D
@onready var collision   = $CollisionShape2D
@onready var timer       = $Timer

var is_coin := false
var drop_ready := false
var velocity_y : float = 0.0
## 분수처럼 흩어지게 하려면 spawn 직후 velocity_x를 다른 값으로 설정 (px/s).
## 바닥에 닿으면 velocity_x도 0으로 정지.
var velocity_x : float = 0.0
var coin_gravity : float = 300.0
var falling : bool = false
var ground_ray : RayCast2D

func _ready():
	$CoinMessage.visible = false
	if pre_placed:
		is_coin = true
		sprite.visible = false
		anim_sprite.visible = true
		anim_sprite.play("spin")
		collision.set_deferred("disabled", false)
	elif drop_ready:
		# 적에서 드롭된 코인: 위로 살짝 튀어오른 뒤 낙하
		sprite.visible = false
		anim_sprite.visible = true
		anim_sprite.play("spin")
		collision.set_deferred("disabled", false)
		# velocity_x/velocity_y는 스폰 측이 트리에 넣기 전에 미리 지정해 둔 값을 그대로 사용.
		# (분수처럼 흩어지려면 스폰 측에서 vx/vy를 설정한다.) 아무것도 지정 안 했으면(0)
		# 기본값으로 위로 살짝 튀어오르게 한다 — 단일 코인 드롭(Enemy/Researcher) 호환.
		if velocity_y == 0.0:
			velocity_y = -80.0
		falling = true
		# 바닥 감지용 레이캐스트. 충분히 길게 두어 아래의 실제 바닥을 항상 인지하고,
		# 코인이 그 바닥 높이에 도달했을 때만 멈춘다 (공중에서 멈추는 것 방지).
		ground_ray = RayCast2D.new()
		ground_ray.target_position = Vector2(0, 600)
		ground_ray.enabled = true
		add_child(ground_ray)
	else:
		# 스킬로 생성된 코인: 20초 후 변환
		sprite.visible = true
		anim_sprite.visible = false
		collision.set_deferred("disabled", true)
		timer.wait_time = 20.0
		timer.start()
		timer.timeout.connect(_on_timer_timeout)

	# 특수 코인: 시각적으로 구분하고, 살아있는 개수를 추적 (생성 상한용).
	# special_alive 증가는 생성 측(bird_enemy.gd)에서 동기적으로 예약하고,
	# 여기선 트리에서 빠질 때(먹힘/씬 종료) 감소만 담당해 균형을 맞춘다.
	if not grants_power:
		modulate = special_tint
		tree_exited.connect(func(): special_alive -= 1)

func _physics_process(delta: float) -> void:
	if not falling:
		return
	velocity_y += coin_gravity * delta
	position.x += velocity_x * delta
	position.y += velocity_y * delta
	# 위로 튀어오르는 동안(velocity_y<=0)엔 착지 판정 안 함.
	if velocity_y <= 0.0 or ground_ray == null:
		return
	ground_ray.force_raycast_update()  # 이동 후 위치 기준으로 즉시 재검사
	if not ground_ray.is_colliding():
		return
	var collider := ground_ray.get_collider()
	# 새(Enemy)/플레이어/다른 코인 위에는 멈추지 않는다 — 실제 바닥에만 정지.
	# (전부 기본 레이어 1이라 ray가 모두 감지하므로 그룹으로 구분.)
	if collider is Node and ((collider as Node).is_in_group("Enemy") or (collider as Node).is_in_group("Player")):
		return
	var floor_y : float = ground_ray.get_collision_point().y - 4.0
	# 바닥 높이에 실제로 도달했을 때만 스냅 (긴 ray로 인한 순간이동 방지, 통과 방지).
	if position.y >= floor_y:
		position.y = floor_y
		velocity_y = 0.0
		velocity_x = 0.0
		falling = false

func _on_timer_timeout() -> void:
	is_coin = true
	sprite.visible = false
	anim_sprite.visible = true
	anim_sprite.play("spin")
	collision.set_deferred("disabled", false)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	# 특수 코인은 먹어도 점수/점프력으로 전환되지 않는다 (그냥 사라짐).
	if grants_power:
		body.increase_score(score_value)
		body.show_coin_message()
	Sfx.play("coin_collect")   # 코인 획득
	queue_free()
