extends CharacterBody2D
const PoopCoin = preload("res://Scenes/poop_coin.tscn")
const PlayerBullet = preload("res://Scenes/player_bullet.tscn")
signal OnUpdateHealth(health: int)
signal OnUpdateScore(score: int)
signal OnPoopSpawned
signal OnAttackFired

@export var move_speed : float = 25
@export var air_speed_multiplier : float = 1.6  # 점프 중 수평 가속 배수
@export var gravity : float = 420
@export var jump_force : float = 100
@export var health : int = 5
@export var invincibility_duration : float = 1.0
@export var coyote_time : float = 0.08
@export var jump_buffer_time : float = 0.1
@export var fall_death_y : float = 260.0
@export var climb_speed : float = 40.0
# 사다리가 그려진 TileMapLayer. is_ladder=true 인 타일을 검사함. 비워두면 사다리 비활성.
@export var ladder_tilemap : TileMapLayer

var base_jump_force : float
var move_input : float
var is_invincible : bool = false
var coyote_timer : float = 0.0
var jump_buffer_timer : float = 0.0
var coin_msg_label : Label = null
var coin_msg_tween : Tween = null
var is_climbing : bool = false

@onready var ray: RayCast2D = $RayCast2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	base_jump_force = jump_force
	anim.play("Idle")
	_update_jump_force()

func _shoot() -> void:
	var bullet = PlayerBullet.instantiate()
	bullet.direction = -1.0 if sprite.flip_h else 1.0
	bullet.position = self.position
	get_parent().add_child(bullet)
	OnAttackFired.emit()

func _spawn_poop() -> void:
	var poop = PoopCoin.instantiate()
	if ray.is_colliding():
		var ground_y = ray.get_collision_point().y
		poop.position = Vector2(self.position.x, ground_y)
	else:
		poop.position = self.position
	get_parent().add_child(poop)
	OnPoopSpawned.emit()

func _physics_process(delta):
	# ── 사다리 처리 (일반 물리보다 먼저) ──
	var v_input := Input.get_axis("ui_up", "ui_down")  # -1 위, +1 아래
	var on_ladder := _is_on_ladder()

	# 사다리 영역에서 climb 진입 조건:
	#   1) 위/아래 키 누름  또는
	#   2) 발 밑이 비어 떨어지는 중인데 사다리 영역에 들어옴(자동 grab → 추락 방지)
	if on_ladder and not is_climbing:
		if v_input != 0.0 or (not is_on_floor() and velocity.y > 0.0):
			is_climbing = true
			velocity.y = 0.0  # 잡는 순간 낙하 정지

	# 사다리에서 벗어나면 자동 해제
	if is_climbing and not on_ladder:
		is_climbing = false

	if is_climbing:
		velocity.y = v_input * climb_speed
		velocity.x = Input.get_axis("ui_left", "ui_right") * move_speed
		# 점프키로 사다리 탈출
		if Input.is_action_just_pressed("ui_jump"):
			is_climbing = false
			velocity.y = -jump_force * 0.7
		move_and_slide()
		update_animation()
		if global_position.y > fall_death_y:
			_fall_die()
		return

	# 중력 적용
	if not is_on_floor():
		velocity.y += gravity * delta
		coyote_timer -= delta
	else:
		coyote_timer = coyote_time

	move_input = Input.get_axis("ui_left", "ui_right")

	# 점프 버퍼: 공중에서 미리 누른 점프를 기억
	if Input.is_action_just_pressed("ui_jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# 점프 (코요테 타임 + 입력 버퍼링)
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = -jump_force
		coyote_timer = 0.0
		jump_buffer_timer = 0.0

	if Input.is_action_just_pressed("ui_attack"):
		_shoot()

	if Input.is_action_just_pressed("ui_skill"):
		_spawn_poop()

	var current_speed : float = move_speed
	if not is_on_floor():
		current_speed *= air_speed_multiplier
	velocity.x = move_input * current_speed

	if move_input != 0:
		sprite.flip_h = move_input < 0

	move_and_slide()
	update_animation()

	if global_position.y > fall_death_y:
		_fall_die()

func _is_on_ladder() -> bool:
	if ladder_tilemap == null:
		return false
	var local := ladder_tilemap.to_local(global_position)
	var coords := ladder_tilemap.local_to_map(local)
	var data := ladder_tilemap.get_cell_tile_data(coords)
	return data != null and data.get_custom_data("is_ladder")

func update_animation():
	if not is_on_floor():
		play_anim("Jump")
	elif move_input != 0:
		play_anim("Walk")
	else:
		play_anim("Idle")

func play_anim(anim_name: String):
	if anim.current_animation != anim_name:
		anim.play(anim_name)

func take_damage(amount: int):
	if is_invincible:
		return
	health -= amount
	OnUpdateHealth.emit(health)
	if health <= 0:
		_die()
	else:
		_start_invincibility()

func _start_invincibility() -> void:
	is_invincible = true
	var tween = create_tween()
	for i in int(invincibility_duration / 0.1):
		tween.tween_property(sprite, "modulate:a", 0.3, 0.05)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.05)
	tween.tween_callback(func(): is_invincible = false)

func _die() -> void:
	set_physics_process(false)
	is_invincible = true
	anim.play("Death")
	anim.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)

func _on_death_animation_finished(_anim_name: String) -> void:
	get_tree().reload_current_scene()

func _fall_die() -> void:
	# 플로어 밖으로 떨어졌을 때: 현재 맵을 즉시 리셋
	set_physics_process(false)
	is_invincible = true
	get_tree().reload_current_scene()

func increase_score(amount: int):
	PlayerStats.score += amount
	OnUpdateScore.emit(PlayerStats.score)
	_update_jump_force()

func show_coin_message() -> void:
	if coin_msg_label and is_instance_valid(coin_msg_label):
		# 이미 표시 중이면 타이머만 리셋
		coin_msg_label.modulate.a = 1.0
		if coin_msg_tween and coin_msg_tween.is_running():
			coin_msg_tween.kill()
	else:
		# 새로 생성: 플레이어 머리 위
		var coin_scene = load("res://Scenes/poop_coin.tscn")
		var tmp = coin_scene.instantiate()
		var src_label = tmp.get_node("CoinMessage")
		coin_msg_label = src_label.duplicate()
		tmp.queue_free()
		coin_msg_label.visible = true
		coin_msg_label.modulate.a = 0.0
		add_child(coin_msg_label)

	coin_msg_label.position = Vector2(-coin_msg_label.size.x * 0.5, -16)
	coin_msg_label.scale = Vector2.ONE
	coin_msg_label.pivot_offset = coin_msg_label.size * 0.5

	coin_msg_tween = create_tween()
	# 페이드인 + 살짝 커졌다 원래대로
	coin_msg_tween.tween_property(coin_msg_label, "modulate:a", 1.0, 0.15)
	coin_msg_tween.parallel().tween_property(coin_msg_label, "scale", Vector2(1.3, 1.3), 0.15)
	coin_msg_tween.tween_property(coin_msg_label, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 유지
	coin_msg_tween.tween_interval(1.0)
	# 페이드아웃
	coin_msg_tween.tween_property(coin_msg_label, "modulate:a", 0.0, 0.3)
	coin_msg_tween.tween_callback(func():
		if coin_msg_label and is_instance_valid(coin_msg_label):
			coin_msg_label.queue_free()
			coin_msg_label = null
	)

func _update_jump_force():
	var multiplier : float = 1.0
	if PlayerStats.score >= 120:
		multiplier = 3.0
	elif PlayerStats.score >= 90:
		multiplier = 2.5
	elif PlayerStats.score >= 60:
		multiplier = 2.0
	elif PlayerStats.score >= 30:
		multiplier = 1.5
	elif PlayerStats.score >= 15:
		multiplier = 1.25
	jump_force = base_jump_force * multiplier
	


func _on_enemy_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
