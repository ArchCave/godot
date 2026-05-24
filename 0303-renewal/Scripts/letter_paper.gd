extends Node2D
## Researcher의 스킬: 논문을 그 자리에 떨궈둠. lifetime(기본 3초) 뒤 픽셀 단위로 dissolve.
##
## dissolve는 fragment shader로 각 텍셀에 hash 노이즈를 부여하고,
## progress (0→1) 트윈이 진행됨에 따라 hash 값이 progress보다 작은 픽셀부터 알파=0.
## 즉 픽셀 하나하나가 무작위 순서로 스르르 사라진다.
##
## Bird의 poop_coin과 동일한 진입점 (player.gd._spawn_poop) 사용 —
## researcher.tres의 skill_scene 필드에 본 씬을 지정하면 끝.
##
## 보너스 코인: 논문을 papers_per_coin (기본 20)개 사용할 때마다 dissolve 자리에
## 보너스 코인 1개 spawn → bird처럼 점수/점프력 상승. 카운터는 PlayerStats에 누적.

@export var lifetime : float = 3.0
@export var dissolve_duration : float = 1.2
@export var spawn_pop_height : float = 4.0
@export var spawn_pop_duration : float = 0.25
## 스폰 위치에 더해질 Y 오프셋 (음수면 위). 논문이 ground_y에 너무 붙어 보이는 걸 보정.
@export var ground_offset_y : float = -4.0
## 몇 개 dissolve할 때마다 보너스 코인 1개를 떨굴지.
@export var papers_per_coin : int = 20
## 보너스 코인 씬. poop_coin과 동일한 씬을 재사용해 일관된 픽업 동작 제공.
@export var bonus_coin_scene : PackedScene = preload("res://Scenes/poop_coin.tscn")

@onready var sprite : Sprite2D = $Sprite2D

const SHADER_CODE := "shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = floor(UV * tex_size);
	float n = hash(pixel);
	base.a *= step(progress, n);
	COLOR = base;
}
"

var _material : ShaderMaterial

func _ready() -> void:
	# 스폰 위치를 살짝 올려 ground_y에 너무 붙지 않게.
	position.y += ground_offset_y
	_setup_shader()
	_play_spawn_anim()
	await get_tree().create_timer(lifetime).timeout
	_dissolve_and_die()

func _setup_shader() -> void:
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("progress", 0.0)
	sprite.material = _material

## 떨어지듯 살짝 위에서 페이드인.
func _play_spawn_anim() -> void:
	var rest_y : float = sprite.position.y
	sprite.position.y -= spawn_pop_height
	sprite.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(sprite, "modulate:a", 1.0, spawn_pop_duration)
	t.tween_property(sprite, "position:y", rest_y, spawn_pop_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 픽셀이 무작위로 사라지는 dissolve → 보너스 코인 체크 → queue_free.
func _dissolve_and_die() -> void:
	var t := create_tween()
	t.tween_method(_set_progress, 0.0, 1.0, dissolve_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(_on_dissolve_finished)

func _on_dissolve_finished() -> void:
	_try_spawn_bonus_coin()
	queue_free()

## papers_per_coin 마다 보너스 코인 1개 spawn. 코인은 drop_ready=true로
## 스폰돼서 살짝 튀어 올랐다 떨어지며 활성 상태가 됨 (즉시 픽업 가능).
func _try_spawn_bonus_coin() -> void:
	if bonus_coin_scene == null or papers_per_coin <= 0:
		return
	PlayerStats.researcher_paper_count += 1
	if PlayerStats.researcher_paper_count < papers_per_coin:
		return
	PlayerStats.researcher_paper_count = 0

	var parent := get_parent()
	if parent == null:
		return
	var coin := bonus_coin_scene.instantiate()
	if coin is Node2D:
		(coin as Node2D).global_position = global_position
	if "drop_ready" in coin:
		coin.drop_ready = true
	parent.add_child(coin)

func _set_progress(v: float) -> void:
	if _material != null:
		_material.set_shader_parameter("progress", v)
