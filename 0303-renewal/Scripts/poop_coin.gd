extends Area2D

# 미리 배치된 보너스 코인 모드. 즉시 활성화된 녹색 코인으로 시작 (똥 단계/대기/낙하 없음).
@export var pre_placed : bool = false
# 먹었을 때 점수 증가량. 일반 코인은 1, 보너스 코인은 큰 값으로 설정.
@export var score_value : int = 1

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
		velocity_y = -80.0
		falling = true
		# 바닥 감지용 레이캐스트
		ground_ray = RayCast2D.new()
		ground_ray.target_position = Vector2(0, 6)
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

func _physics_process(delta: float) -> void:
	if not falling:
		return
	velocity_y += coin_gravity * delta
	position.x += velocity_x * delta
	position.y += velocity_y * delta
	# 바닥에 닿으면 멈춤
	if ground_ray and ground_ray.is_colliding() and velocity_y > 0:
		position.y = ground_ray.get_collision_point().y - 4.0
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
	body.increase_score(score_value)
	body.show_coin_message()
	queue_free()
