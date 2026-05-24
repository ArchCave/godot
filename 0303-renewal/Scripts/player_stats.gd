extends Node

## Global autoload.
## Holds:
##   - run-scoped gameplay stats (score, kills)
##   - the currently selected playable character (persists across scene changes)
##
## ───────────────────────────────────────────────────────────────────────────
## 새 캐릭터 추가하는 방법:
##   1. res://Resorces/Characters/your_character.tres 생성 (기존 .tres 복제)
##   2. 아래 `characters` 배열에 preload 한 줄 추가
##   3. (그게 전부 — character_select / Player.tscn는 이 배열을 자동 인식)
## ───────────────────────────────────────────────────────────────────────────

# ── gameplay stats ─────────────────────────────────────────────────────────
var score : int = 0
var enemy_kills : int = 0
var bird_enemy_kills : int = 0
## Researcher가 사용한 논문 누적 (dissolve 완료 기준). letter_paper.gd가
## 매번 +1, 20개마다 보너스 코인 1개 spawn 후 0으로 리셋.
var researcher_paper_count : int = 0

# ── character roster ───────────────────────────────────────────────────────
## 선택 가능한 모든 캐릭터.
## 캐릭터 선택 화면이 이 배열을 순회해서 버튼/프리뷰를 자동 구성한다.
## NOTE: preload 대신 lazy load — researcher.tres가 letter_paper.tscn을 참조하고,
## letter_paper.gd가 PlayerStats를 참조해서 autoload 등록 중 순환이 생긴다.
## 첫 접근 시 load() 하면 autoload 등록 완료 후라 안전.
const _CHARACTER_PATHS := [
	"res://Resorces/Characters/bird.tres",
	"res://Resorces/Characters/researcher.tres",
	"res://Resorces/Characters/planner.tres",
]
var _characters_cache: Array[CharacterData] = []
var characters: Array[CharacterData]:
	get:
		if _characters_cache.is_empty():
			for p in _CHARACTER_PATHS:
				_characters_cache.append(load(p))
		return _characters_cache

## 기본값 = 걸음새 새 (오리지널 플레이어). 캐릭터 선택을 거치지 않고
## 레벨을 바로 실행해도 안전하게 동작하게 하는 폴백.
const DEFAULT_CHARACTER_ID: StringName = &"bird"
var selected_character_id: StringName = DEFAULT_CHARACTER_ID

# ── lifecycle ──────────────────────────────────────────────────────────────
func reset() -> void:
	score = 0
	enemy_kills = 0
	bird_enemy_kills = 0
	researcher_paper_count = 0

func reset_all() -> void:
	reset()
	selected_character_id = DEFAULT_CHARACTER_ID

# ── character helpers ──────────────────────────────────────────────────────
## 선택 화면 / 디버그용. 알 수 없는 id면 false 반환.
func set_selected_character(id: StringName) -> bool:
	for c in characters:
		if c != null and c.id == id:
			selected_character_id = id
			return true
	push_warning("[PlayerStats] Unknown character id '%s'" % id)
	return false

## 현재 선택된 캐릭터의 데이터. 절대 null을 반환하지 않는다 (폴백 보장).
func get_selected() -> CharacterData:
	for c in characters:
		if c != null and c.id == selected_character_id:
			return c
	# 폴백 1: 기본 캐릭터 id로 재탐색
	for c in characters:
		if c != null and c.id == DEFAULT_CHARACTER_ID:
			return c
	# 폴백 2: 배열 첫 항목 (배열이 비어있지 않다고 가정)
	return characters[0] if characters.size() > 0 else null

## 고급 사용: CharacterData.scene 필드가 설정돼 있으면 그 씬을 반환.
## 보통은 모든 캐릭터가 Player.tscn을 공유하므로 null이 반환되며,
## Player.tscn._ready()가 데이터(sprite/anim/스탯/skill)를 자기 자신에 적용한다.
func get_selected_scene() -> PackedScene:
	var data := get_selected()
	return data.scene if data != null else null

# ── 레벨별 캐릭터 피격 면역 ────────────────────────────────────────────────
## "이 레벨들에선 이 캐릭터가 적의 근접/투사체에 피격되지 않음."
## 적 스크립트(Enemy.gd, drone_taxi.gd 등)가 _on_body_entered에서 이걸 체크.
## 캐릭터의 bullet은 그대로 데미지를 주므로, 면역 = 받기 면역 (주기는 정상).
##
## (const + StringName key 조합이 일부 Godot 4 빌드에서 파싱 실패해
##  autoload 전체를 깨뜨릴 수 있어서 var로 유지.)
var HIT_IMMUNE_BY_CHARACTER : Dictionary = {
	&"researcher": [
		"res://Scenes/level_6.tscn",
		"res://Scenes/level_7.tscn",
		"res://Scenes/level_8.tscn",
	],
}

## 현재 씬에서 선택 캐릭터가 일반 적(Enemy/drone_taxi/Researcher)의 직접 피격에
## 면역인지 여부. 적 스크립트가 _on_body_entered / on_player_contact / target
## acquisition에서 이걸 체크.
##
## 두 가지 규칙이 합쳐짐:
##   A) HIT_IMMUNE_BY_CHARACTER 딕셔너리에 해당 (캐릭터, 레벨) 조합이 있으면 면역.
##   B) planner는 **모든 레벨**에서 일반 적에 면역. planner의 유일한 적은 BirdEnemy.
##      (BirdEnemy는 자체 bird_enemy.gd에서 character_id별 가드를 따로 처리한다.)
func is_selected_immune_in_current_level() -> bool:
	# (B) planner 전역 면역.
	if selected_character_id == &"planner":
		return true
	# (A) 캐릭터 + 레벨 조합 면역.
	var levels : Array = HIT_IMMUNE_BY_CHARACTER.get(selected_character_id, [])
	if levels.is_empty():
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return false
	return tree.current_scene.scene_file_path in levels
