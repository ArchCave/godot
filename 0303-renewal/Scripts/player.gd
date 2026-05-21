extends CharacterBody2D

## Player 본체. 모든 플레이어블 캐릭터(걸음새 새/Researcher/Planner)가 이 스크립트를 공유한다.
##
## _ready() 시점에 PlayerStats.get_selected() (CharacterData)를 읽어
##   - Sprite2D 텍스처/프레임 레이아웃
##   - AnimationPlayer 라이브러리
##   - 이동/점프/체력/사다리 등 스탯
##   - 공격/스킬 씬
## 을 자기 자신에 적용하기 때문에 레벨 파일을 수정할 필요가 없다.
## 새 캐릭터는 .tres 추가 → PlayerStats.characters에 등록 한 줄이면 끝.

signal OnUpdateHealth(health: int)
signal OnUpdateScore(score: int)
signal OnPoopSpawned
signal OnAttackFired

## 이 노드가 어떤 캐릭터인지 식별하기 위한 fallback id.
## 일반적으로 PlayerStats.get_selected().id 가 우선되며, 그게 비었을 때만 사용.
@export var character_id : StringName = &"bird"

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

# ── 캐릭터별 스킬/공격 씬 (CharacterData가 _ready에서 주입; 인스펙터 값은 폴백) ──
## 새 캐릭터는 자신의 .tres에 attack_scene/skill_scene을 지정하면
## 별도 코드 수정 없이 곧바로 공격/스킬을 갖게 됨. null이면 비활성.
@export var attack_scene : PackedScene = preload("res://Scenes/player_bullet.tscn")
@export var skill_scene  : PackedScene = preload("res://Scenes/poop_coin.tscn")

## 현재 활성화된 캐릭터 데이터. UI/적/외부 시스템이 캐릭터 식별이 필요할 때 참조.
var character_data : CharacterData = null

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
	# CharacterData(.tres) → 자기 자신에 적용 (sprite/anim/스탯/skill)
	_apply_character_data()
	base_jump_force = jump_force
	# Ensure enemies (Researcher.gd, etc.) can always find the player regardless
	# of how this scene was instantiated.
	if not is_in_group("Player"):
		add_to_group("Player")
	# 레벨 씬이 ladder_tilemap을 직접 설정하지 않은 경우, "Ladders" 그룹에서 자동 탐색.
	# PlayerSpawner를 통해 인스턴스화될 때 NodePath 참조를 일일이 매기지 않아도 되게 함.
	if ladder_tilemap == null:
		var found := get_tree().get_first_node_in_group("Ladders")
		if found is TileMapLayer:
			ladder_tilemap = found
	anim.play("Idle")
	_update_jump_force()

# ── CharacterData 적용 ─────────────────────────────────────────────────
## PlayerStats.get_selected()를 읽어 비주얼/스탯/스킬을 자기 자신에 적용.
## 데이터가 없거나 비어있는 필드는 인스펙터 기본값(= 걸음새 새)을 그대로 유지.
func _apply_character_data() -> void:
	if not is_instance_valid(PlayerStats):
		return
	character_data = PlayerStats.get_selected()
	if character_data == null:
		return

	# fallback character_id
	character_id = character_data.id

	# ── 비주얼: 스프라이트 시트 ──
	if character_data.sprite_texture != null:
		sprite.texture = character_data.sprite_texture
		sprite.hframes = max(character_data.sprite_hframes, 1)
		sprite.vframes = max(character_data.sprite_vframes, 1)
	sprite.offset = character_data.sprite_offset

	# ── 비주얼: 애니메이션 라이브러리 (기본 "" 라이브러리를 통째로 교체) ──
	if character_data.animation_library != null:
		if anim.has_animation_library(""):
			anim.remove_animation_library("")
		anim.add_animation_library("", character_data.animation_library)

	# ── 스탯 ──
	move_speed = character_data.move_speed
	air_speed_multiplier = character_data.air_speed_multiplier
	jump_force = character_data.jump_force
	health = character_data.max_health
	climb_speed = character_data.climb_speed

	# ── 스킬/공격 (CharacterData가 명시한 값으로 덮어쓰기; null은 비활성) ──
	attack_scene = character_data.attack_scene
	skill_scene = character_data.skill_scene

func _shoot() -> void:
	if attack_scene == null:
		return  # 이 캐릭터는 공격 스킬이 없음
	var bullet = attack_scene.instantiate()
	if "direction" in bullet:
		bullet.direction = -1.0 if sprite.flip_h else 1.0
	bullet.position = self.position
	get_parent().add_child(bullet)
	OnAttackFired.emit()

func _spawn_poop() -> void:
	if skill_scene == null:
		return  # 이 캐릭터는 스킬이 없음
	var skill = skill_scene.instantiate()
	if ray.is_colliding():
		var ground_y = ray.get_collision_point().y
		skill.position = Vector2(self.position.x, ground_y)
	else:
		skill.position = self.position
	get_parent().add_child(skill)
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
	# 사다리 위에서는 Ladder 애니메이션. 위/아래 입력 없으면 같은 프레임에서 정지.
	# Ladder 애니메이션이 라이브러리에 없는 캐릭터는 폴백으로 기존 분기 사용.
	if is_climbing and anim.has_animation("Ladder"):
		play_anim("Ladder")
		var v_input := Input.get_axis("ui_up", "ui_down")
		anim.speed_scale = 1.0 if v_input != 0.0 else 0.0
		return

	anim.speed_scale = 1.0
	if not is_on_floor():
		play_anim("Jump")
	elif move_input != 0:
		play_anim("Walk")
	else:
		play_anim("Idle")

func play_anim(anim_name: String):
	if anim.current_animation != anim_name:
		anim.play(anim_name)
	_apply_anim_offset(anim_name)

func _apply_anim_offset(anim_name: String) -> void:
	if character_data == null:
		return
	var delta : Vector2 = Vector2.ZERO
	match anim_name:
		"Idle": delta = character_data.idle_offset_delta
		"Walk": delta = character_data.walk_offset_delta
	sprite.offset = character_data.sprite_offset + delta

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
