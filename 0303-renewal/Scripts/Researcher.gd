extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK, HURT }

@export var max_health : int = 3
@export var detection_range : float = 108.0
@export var attack_range : float = 14.0
@export var chase_speed : float = 42.0
@export var patrol_speed : float = 24.0
@export var attack_cooldown : float = 1.0
@export var attack_damage : int = 1
# matches player's 2단계 점프 (base_jump_force 100 * 1.5)
@export var jump_force : float = 150.0
@export var fall_gravity : float = 420.0
@export var jump_interval : float = 0.5
@export var fall_death_y : float = 260.0
# pathing probes
@export var wall_probe_dist : float = 10.0
@export var ground_probe_offset_x : float = 10.0
@export var ground_probe_depth : float = 20.0
@export var drop_scan_depth : float = 96.0
@export var drop_reach_min_dist : float = 40.0
# anti-jitter
@export var facing_deadzone : float = 6.0
@export var facing_flip_cooldown : float = 0.18
@export var attack_exit_margin : float = 6.0
@export var unreachable_height : float = 32.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var state : State = State.PATROL
var health : int
var target : Node2D = null
var attack_timer : float = 0.0
var attack_has_hit : bool = false
var facing : float = 1.0
var jump_timer : float = 0.0
var facing_flip_timer : float = 0.0
var current_anim : String = ""

const PoopCoin = preload("res://Scenes/poop_coin.tscn")

func _ready() -> void:
	health = max_health
	_play_anim("idle")

func _physics_process(delta: float) -> void:
	# fall-off detection: below map → die
	if global_position.y > fall_death_y:
		queue_free()
		return

	# gravity — always applied so researcher can fall off ledges
	if not is_on_floor():
		velocity.y += fall_gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if state == State.HURT:
		velocity.x = 0.0
		move_and_slide()
		return

	# 면역 레벨에서 선택된 캐릭터는 적이 아님 — 타겟 자체를 잡지 않고 PATROL 유지.
	if PlayerStats.is_selected_immune_in_current_level():
		target = null
		if state != State.PATROL and state != State.HURT:
			_enter_state(State.PATROL)
	elif target == null or not is_instance_valid(target):
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			target = players[0]

	_update_facing(delta)
	jump_timer -= delta

	var desired_vx : float = 0.0
	match state:
		State.PATROL:
			desired_vx = _patrol_logic()
		State.CHASE:
			desired_vx = _chase_logic()
		State.ATTACK:
			_attack_logic(delta)

	velocity.x = desired_vx
	move_and_slide()

func _update_facing(delta: float) -> void:
	facing_flip_timer -= delta
	# only track the player while chasing/attacking; PATROL keeps its own facing
	var tracks_target = (state == State.CHASE or state == State.ATTACK) \
			and target and facing_flip_timer <= 0.0
	if tracks_target:
		var dx = target.global_position.x - global_position.x
		if absf(dx) > facing_deadzone:
			var new_facing = signf(dx)
			if new_facing != 0.0 and new_facing != facing:
				facing = new_facing
				facing_flip_timer = facing_flip_cooldown
	anim_sprite.flip_h = facing < 0

func _play_anim(anim_name: String) -> void:
	if current_anim == anim_name:
		return
	current_anim = anim_name
	anim_sprite.play(anim_name)

func _request_jump() -> void:
	if not is_on_floor():
		return
	if jump_timer > 0.0:
		return
	velocity.y = -jump_force
	jump_timer = jump_interval

func _wall_ahead(dir: float) -> bool:
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(dir * wall_probe_dist, 0.0),
		collision_mask)
	params.exclude = [get_rid()]
	return not space.intersect_ray(params).is_empty()

func _ground_ahead(dir: float) -> bool:
	var space = get_world_2d().direct_space_state
	var from = global_position + Vector2(dir * ground_probe_offset_x, 0.0)
	var params = PhysicsRayQueryParameters2D.create(
		from, from + Vector2(0.0, ground_probe_depth), collision_mask)
	params.exclude = [get_rid()]
	return not space.intersect_ray(params).is_empty()

func _find_landing_y(dir: float) -> float:
	# sweep horizontal probes; for each, cast a deep vertical ray that catches
	# both higher ledges (jump target) and lower platforms (drop target).
	# returns y of the first landing found, or INF if nothing within reach.
	var air_time := 2.0 * jump_force / fall_gravity
	var max_dist := maxf(chase_speed * air_time, drop_reach_min_dist)
	var d := ground_probe_offset_x + 4.0
	var space = get_world_2d().direct_space_state
	while d <= max_dist + 4.0:
		var from = global_position + Vector2(dir * d, -32.0)
		var params = PhysicsRayQueryParameters2D.create(
			from, from + Vector2(0.0, 32.0 + drop_scan_depth), collision_mask)
		params.exclude = [get_rid()]
		var result = space.intersect_ray(params)
		if not result.is_empty():
			return result.position.y
		d += 4.0
	return INF

func _patrol_logic() -> float:
	# detect player
	if target and not _is_target_unreachable() \
			and global_position.distance_to(target.global_position) <= detection_range:
		_enter_state(State.CHASE)
		return 0.0

	# reverse at wall or ledge so we never walk off the platform
	if is_on_floor() and (_wall_ahead(facing) or not _ground_ahead(facing)):
		facing = -facing
		facing_flip_timer = facing_flip_cooldown

	return patrol_speed * facing

func _chase_logic() -> float:
	if not target:
		_enter_state(State.PATROL)
		return 0.0
	if _is_target_unreachable():
		_enter_state(State.PATROL)
		return 0.0
	var dist = global_position.distance_to(target.global_position)
	if dist <= attack_range:
		_enter_state(State.ATTACK)
		return 0.0

	# smart pathing: only act on obstacles while on the ground
	if is_on_floor():
		if _wall_ahead(facing):
			_request_jump()
		elif not _ground_ahead(facing):
			# ledge: check if there's a landing somewhere within reach
			var landing_y = _find_landing_y(facing)
			if landing_y == INF:
				return 0.0  # nothing to land on — stop at edge
			if landing_y < global_position.y + 4.0:
				# landing at same level or above — need a jump
				_request_jump()
			# landing is below — just walk off, gravity handles it
		elif target.global_position.y < global_position.y - 24.0:
			# player on a higher platform — try to hop up
			_request_jump()
	return chase_speed * facing

func _attack_logic(delta: float) -> void:
	attack_timer -= delta
	if not attack_has_hit and attack_timer <= attack_cooldown * 0.5:
		attack_has_hit = true
		if target and global_position.distance_to(target.global_position) <= attack_range + attack_exit_margin:
			if target.has_method("take_damage"):
				target.take_damage(attack_damage)
	if attack_timer <= 0.0:
		if target and global_position.distance_to(target.global_position) > attack_range + attack_exit_margin:
			_enter_state(State.CHASE)
		else:
			attack_timer = attack_cooldown
			attack_has_hit = false

func _is_target_unreachable() -> bool:
	# player well above current ground — can't reach with a jump
	return target and (global_position.y - target.global_position.y) > unreachable_height

func _enter_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	match state:
		State.PATROL:
			_play_anim("idle")
		State.CHASE:
			_play_anim("idle")
		State.ATTACK:
			_play_anim("idle")
			attack_timer = attack_cooldown
			attack_has_hit = false

func take_bullet_damage(amount: int) -> void:
	if state == State.HURT:
		return
	health -= amount
	if health <= 0:
		_die()
	else:
		_hurt_react()

func _hurt_react() -> void:
	state = State.HURT
	var tween = create_tween()
	tween.tween_callback(func(): _play_anim("stand"))
	tween.tween_interval(0.12)
	tween.tween_callback(func(): _play_anim("kill"))
	tween.tween_interval(0.12)
	for i in 2:
		tween.tween_property(anim_sprite, "modulate:a", 0.3, 0.07)
		tween.tween_property(anim_sprite, "modulate:a", 1.0, 0.07)
	tween.tween_callback(func():
		anim_sprite.modulate.a = 1.0
		state = State.CHASE  # force transition below
		_enter_state(State.PATROL)
	)

func _die() -> void:
	state = State.HURT
	PlayerStats.enemy_kills += 1
	var tween = create_tween()
	tween.tween_callback(func(): _play_anim("stand"))
	tween.tween_interval(0.15)
	tween.tween_callback(func(): _play_anim("kill"))
	tween.tween_interval(0.18)
	for i in 4:
		tween.tween_property(anim_sprite, "modulate:a", 0.2, 0.08)
		tween.tween_property(anim_sprite, "modulate:a", 1.0, 0.08)
	tween.tween_callback(func(): _drop_coin_and_free())

func _drop_coin_and_free() -> void:
	var coin = PoopCoin.instantiate()
	coin.position = global_position
	coin.drop_ready = true
	get_parent().add_child(coin)
	queue_free()

func on_player_contact(body: Node2D) -> void:
	if state == State.HURT:
		return
	if not body.is_in_group("Player"):
		return
	if PlayerStats.is_selected_immune_in_current_level():
		return
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)
