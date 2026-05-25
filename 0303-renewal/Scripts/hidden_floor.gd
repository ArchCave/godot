extends StaticBody2D

## 비폭력(pacifist) 통로용 숨겨진 바닥.
## 이 레벨 안에서 드론(적)을 한 마리도 죽이지 않았을 때만 통과 가능(콜리전 해제).
## 이 레벨에서 적을 한 번이라도 죽이면 즉시 영구히 막힌다.

@export var target_shape_name : String = "CollisionShape2D_2"

var _shape : CollisionShape2D
# 이 레벨 진입 시점의 누적 킬 수. enemy_kills는 전역 누적이므로
# (현재값 - 기준점) 으로 "이 맵 안에서의" 킬만 센다.
var _baseline_kills : int = 0

func _ready() -> void:
	_shape = get_node_or_null(target_shape_name) as CollisionShape2D
	_baseline_kills = PlayerStats.enemy_kills
	# 진입 시점엔 이 레벨 킬이 0 → 통과 가능(disabled = true).
	if _shape:
		_shape.set_deferred("disabled", true)

func _process(_delta: float) -> void:
	# 이 레벨에서 적을 죽인 순간 통로를 영구히 막는다.
	if PlayerStats.enemy_kills > _baseline_kills:
		if _shape:
			_shape.set_deferred("disabled", false)  # disabled = false → 콜리전 활성 = 막힘
		set_process(false)
