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

# ── character roster ───────────────────────────────────────────────────────
## 선택 가능한 모든 캐릭터.
## 캐릭터 선택 화면이 이 배열을 순회해서 버튼/프리뷰를 자동 구성한다.
var characters: Array[CharacterData] = [
	preload("res://Resorces/Characters/bird.tres"),
	preload("res://Resorces/Characters/researcher.tres"),
	preload("res://Resorces/Characters/planner.tres"),
]

## 기본값 = 걸음새 새 (오리지널 플레이어). 캐릭터 선택을 거치지 않고
## 레벨을 바로 실행해도 안전하게 동작하게 하는 폴백.
const DEFAULT_CHARACTER_ID: StringName = &"bird"
var selected_character_id: StringName = DEFAULT_CHARACTER_ID

# ── lifecycle ──────────────────────────────────────────────────────────────
func reset() -> void:
	score = 0
	enemy_kills = 0
	bird_enemy_kills = 0

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
