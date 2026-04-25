extends Sprite2D

# 위/아래로 흔들리는 진폭(픽셀). 약 반 블럭 정도면 8 전후가 자연스러움.
@export var amplitude: float = 8.0
# 한 사이클(위→아래→위) 도는 데 걸리는 시간(초). 값이 클수록 더 천천히 살랑거림.
@export var period: float = 4.0
# 스프라이트 투명도. 0.0(투명) ~ 1.0(불투명). 0.7 = 70%.
@export_range(0.0, 1.0) var alpha: float = 0.7

var _base_y: float
var _t: float = 0.0

func _ready() -> void:
	_base_y = position.y
	modulate.a = alpha

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t / period * TAU) * amplitude
