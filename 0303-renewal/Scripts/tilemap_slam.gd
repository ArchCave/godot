extends TileMapLayer
## slam_impact: 콰광 낙하가 원위치에 도달한 시점에 emit. bird_killer.gd 같은 외부
## 노드가 "내리친 순간"에만 동작하도록 동기화하는 데 사용.
signal slam_impact

## 자기 자신을 위로 부드럽게 올렸다가 원래 위치로 콰광 떨어뜨리는 모션을 반복.
##
## 사이클 1회:
##   1) rise_duration 동안 (rise_tiles * tile_size) 만큼 위로 부드럽게 상승 (SINE EaseOut)
##   2) hold_at_top 동안 정점에서 정지 (긴장감)
##   3) slam_duration 동안 원래 위치로 가속 낙하 (QUART EaseIn — "콰광")
##   4) 짧은 반동(bounce_pixels 위로 살짝 튕겼다 안착)
##   5) hold_at_bottom 만큼 정지 후 1)로 반복.
##
## 인스펙터에서 모든 타이밍/거리/반동을 조절 가능.

@export var rise_tiles : int = 4
@export var tile_size : float = 16.0
@export var rise_duration : float = 1.2
@export var hold_at_top : float = 0.3
@export var slam_duration : float = 0.12
@export var bounce_pixels : float = 3.0
@export var bounce_duration : float = 0.18
@export var hold_at_bottom : float = 0.6

var _origin_y : float
var _tween : Tween

func _ready() -> void:
	_origin_y = position.y
	_start_loop()

## 외부(planner_button 등)에서 슬램 모션을 그 자리에 멈추고 싶을 때 호출.
## 재개는 의도적으로 노출하지 않음 — 한 번 멈추면 그 레벨에서는 끝.
func pause_slam() -> void:
	if _tween != null and _tween.is_valid():
		_tween.pause()

func _start_loop() -> void:
	var top_y : float = _origin_y - float(rise_tiles) * tile_size
	_tween = create_tween().set_loops()
	var t : Tween = _tween
	# 1) 부드럽게 위로 (정점 근처에서 점점 느려짐)
	t.tween_property(self, "position:y", top_y, rise_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 2) 정점에서 잠시 멈춤
	t.tween_interval(hold_at_top)
	# 3) 콰광! 가속 낙하
	t.tween_property(self, "position:y", _origin_y, slam_duration)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	# 3-1) 바닥 도달 시점에 신호 emit (bird_killer 등이 듣는다)
	t.tween_callback(func(): slam_impact.emit())
	# 4) 충돌 반동 (위로 살짝 튀어올랐다 다시 안착)
	t.tween_property(self, "position:y", _origin_y - bounce_pixels, bounce_duration * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", _origin_y, bounce_duration * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# 5) 한숨 돌리고 반복
	t.tween_interval(hold_at_bottom)
