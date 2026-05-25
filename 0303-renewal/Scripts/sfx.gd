extends Node

## 게임 전역 사운드 매니저 (오토로드 이름: Sfx).
## 어디서든 `Sfx.play("jump")` 처럼 효과음을 재생한다.
##
## 주의: .m4a 는 Godot가 import 하지 않으므로, import된 .ogg 파일을 사용한다.
## 새 효과음은 ONE_SHOTS 사전에 한 줄 추가하면 끝.

# ── 단발 효과음: 이름 → 스트림 ──────────────────────────────────────────────
const ONE_SHOTS := {
	"jump":               preload("res://Resorces/media/jump.ogg"),
	"land":               preload("res://Resorces/media/land.ogg"),
	"skill":              preload("res://Resorces/media/land2.ogg"),  # 특기(○ 버튼) 소리
	"spawn":              preload("res://Resorces/media/spawn.ogg"),
	"shoot":              preload("res://Resorces/media/shoot.ogg"),
	"dead":               preload("res://Resorces/media/dead.ogg"),
	"enemy_hit":          preload("res://Resorces/media/enemy_hit.ogg"),
	"coin_collect":       preload("res://Resorces/media/coin_collect.ogg"),
	"click":              preload("res://Resorces/media/click.ogg"),
	"chest_open":         preload("res://Resorces/media/chest_open.ogg"),
	"checkpoint_actived": preload("res://Resorces/media/checkpoint_actived.ogg"),
}

# ── 걸을 때 반복 재생할 발소리 ──────────────────────────────────────────────
const FOOTSTEPS_STREAM : AudioStream = preload("res://Resorces/media/footsteps.ogg")

# ── 게임 진입 시 무작위로 트는 배경음 ───────────────────────────────────────
const BGM_TRACKS : Array[AudioStream] = [
	preload("res://Resorces/media/bgm_0.ogg"),
	preload("res://Resorces/media/bgm_1.ogg"),
	preload("res://Resorces/media/bgm_2.ogg"),
	preload("res://Resorces/media/bgm_3.ogg"),
	preload("res://Resorces/media/bgm_4.ogg"),
]

const POOL_SIZE := 8

var _pool : Array[AudioStreamPlayer] = []
var _next : int = 0
var _walk_player : AudioStreamPlayer
var _bgm_player : AudioStreamPlayer
var _walking : bool = false  # 발소리 루프 유지 여부

func _ready() -> void:
	# 일시정지(get_tree().paused) 중에도 효과음/메뉴 클릭음이 재생되도록.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 단발 효과음이 겹쳐 재생될 수 있도록 플레이어 풀을 만든다.
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	# 발소리(반복) 전용 플레이어
	_walk_player = AudioStreamPlayer.new()
	add_child(_walk_player)
	_walk_player.finished.connect(_on_walk_finished)
	# BGM(반복) 전용 플레이어
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	_bgm_player.finished.connect(_on_bgm_finished)

## 단발 효과음 재생. 풀에서 다음 플레이어를 돌려 써서 소리가 겹쳐도 끊기지 않는다.
func play(sound_name: String, volume_db: float = 0.0) -> void:
	var stream : AudioStream = ONE_SHOTS.get(sound_name)
	if stream == null:
		push_warning("Sfx.play: 알 수 없는 효과음 '%s'" % sound_name)
		return
	var p : AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.play()

## 걸음 시작 (발소리 반복). 이미 재생 중이면 무시.
func start_footsteps() -> void:
	if _walking:
		return
	_walking = true
	_walk_player.stream = FOOTSTEPS_STREAM
	_walk_player.play()

## 걸음 정지.
func stop_footsteps() -> void:
	if not _walking:
		return
	_walking = false
	_walk_player.stop()

# 발소리가 끝나면, 아직 걷는 중일 때만 다시 재생해 루프를 만든다
# (스트림 자체가 loop면 이 신호가 안 와도 알아서 반복된다).
func _on_walk_finished() -> void:
	if _walking:
		_walk_player.play()

## 맵 진입 시 무작위 BGM 재생 (반복). 이미 재생 중이면 무시 →
## 맵 전환/리스폰에도 BGM이 끊기거나 다시 시작되지 않고 그대로 이어진다.
func play_random_bgm() -> void:
	if _bgm_player.playing:
		return
	if BGM_TRACKS.is_empty():
		return
	_bgm_player.stream = BGM_TRACKS[randi() % BGM_TRACKS.size()]
	_bgm_player.play()

## BGM 정지.
func stop_bgm() -> void:
	_bgm_player.stop()

# BGM이 끝나면 같은 곡을 다시 재생해 루프.
func _on_bgm_finished() -> void:
	if _bgm_player.stream != null:
		_bgm_player.play()
