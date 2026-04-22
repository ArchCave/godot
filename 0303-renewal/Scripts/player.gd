extends CharacterBody2D
const PoopCoin = preload("res://Scenes/poop_coin.tscn")
const PlayerBullet = preload("res://Scenes/player_bullet.tscn")
signal OnUpdateHealth(health: int)
signal OnUpdateScore(score: int)

@export var move_speed : float = 25
@export var gravity : float = 420
@export var jump_force : float = 100
@export var health : int = 5
@export var game_over_scene: String = "res://Scenes/level_1.tscn"
@export var invincibility_duration : float = 1.0
@export var coyote_time : float = 0.08
@export var jump_buffer_time : float = 0.1

var base_jump_force : float
var move_input : float
var is_invincible : bool = false
var coyote_timer : float = 0.0
var jump_buffer_timer : float = 0.0
var coin_msg_label : Label = null
var coin_msg_tween : Tween = null

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

func _spawn_poop() -> void:
	var poop = PoopCoin.instantiate()
	if ray.is_colliding():
		var ground_y = ray.get_collision_point().y
		poop.position = Vector2(self.position.x, ground_y)
	else:
		poop.position = self.position
	get_parent().add_child(poop)

func _physics_process(delta):
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

	velocity.x = move_input * move_speed

	if move_input != 0:
		sprite.flip_h = move_input < 0

	move_and_slide()
	update_animation()

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
	get_tree().change_scene_to_file(game_over_scene)

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
