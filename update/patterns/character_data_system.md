# 패턴: 새 캐릭터 추가 (`CharacterData` Resource 시스템)

> "새 캐릭터 한 명을 더 추가하고 싶다." 이 문서를 따라하면 **레벨 씬은 손대지 않고** `.tres` 파일 한 개 + 코드 한 줄로 끝난다.

---

## 1. 시스템 구조 (한 페이지)

```
PlayerStats (autoload)              ← /root/PlayerStats
├── characters: Array[CharacterData]  ← preload 로 .tres 등록
├── selected_character_id              ← character_select.gd가 씀
└── get_selected() -> CharacterData    ← 절대 null 안 반환

CharacterData (Resource, .tres)      ← Resorces/Characters/*.tres
├── id, display_name
├── sprite_texture, sprite_hframes/vframes, sprite_offset, idle/walk_offset_delta
├── animation_library (Idle/Walk/Jump/Death/Ladder 클립 필수)
├── preview_texture (선택 화면용)
├── move_speed, air_speed_multiplier, jump_force, max_health, climb_speed
├── attack_scene, skill_scene
├── implemented (선택 화면에서 "준비 중" 표시)
└── scene (옵션 — 완전히 다른 노드 구조가 필요할 때만)

Player.tscn (단일 씬)                ← 모든 캐릭터가 공유
└── _ready() → _apply_character_data()
                 ├── sprite.texture/hframes/vframes/offset 갈아끼움
                 ├── anim.add_animation_library("", lib) 로 라이브러리 교체
                 └── move_speed/jump/health/attack/skill 덮어씀
```

핵심 파일:
- `0303-renewal/Scripts/character_data.gd` — Resource 정의 (`class_name CharacterData`)
- `0303-renewal/Scripts/player_stats.gd` — 로스터 + 선택 상태 + 폴백
- `0303-renewal/Scripts/player.gd` `_apply_character_data()` — 주입 진입점
- `0303-renewal/Resorces/Characters/bird.tres`, `planner.tres`, `researcher.tres` — 인스턴스 예시

---

## 2. 캐릭터 추가 절차 (5단계)

### Step 1 — 스프라이트 시트 준비
`0303-renewal/Sprite/{캐릭터명}/` 폴더에 시트 PNG들을 넣는다. 기존 `planner/` `researcher/` 구조 참고:
```
Sprite/myhero/
├── idle/  Layer 1_sprite_myhero1.png …
├── walk/  Layer 1_sprite_myhero0.png …
├── jump/
├── death/
└── ladder/ (선택)
```
Godot이 자동으로 `.import` 파일을 생성한다.

> **시트 vs 개별 PNG**: 기존 캐릭터는 둘 다 섞여 있다(`sprite7-sheet0.png` 같은 시트도 있고, walk/0/1/2 개별 프레임도 있음). `CharacterData.sprite_texture`는 **시트** 한 장(`Texture2D`) + `hframes`/`vframes`를 받는다. 개별 프레임은 `AnimationLibrary` 안에서 각 클립이 별도 SpriteFrames로 잡거나, `Sprite2D.frame`을 직접 트랙으로 키프레이밍해야 한다.
> 가장 빠른 길은 **planner/researcher의 `*_anims.tres`를 복제해서 프레임 텍스처만 갈아끼우는 것**.

### Step 2 — AnimationLibrary 만들기
가장 쉬운 방법: `Resorces/Characters/researcher_anims.tres`를 복제 → `myhero_anims.tres`로 이름 변경 → Godot 에디터에서 열고, 각 애니메이션 트랙의 `Sprite2D:texture` 키를 새 시트로 교체.

**필수 애니메이션 이름** (이 이름을 `player.gd`가 호출함):
- `Idle`
- `Walk`
- `Jump`
- `Death`
- `Ladder` (선택 — 없으면 사다리 위에서 Walk/Idle 폴백)

> 이름이 다르면 동작 안 함. 대소문자 정확히 일치.

### Step 3 — `.tres` 생성
`Resorces/Characters/bird.tres`를 우클릭 → Duplicate → `myhero.tres`. 더블클릭으로 열고 인스펙터 채우기:

| 필드 | 값 예시 | 메모 |
| --- | --- | --- |
| `id` | `&"myhero"` | StringName. 인스펙터에선 `myhero` |
| `display_name` | `"MY HERO"` | 선택 화면 라벨 |
| **In-game Visuals** | | |
| `sprite_texture` | `res://Sprite/myhero/sheet.png` 드래그 | null이면 Player.tscn 기본 유지 |
| `sprite_hframes` / `vframes` | 시트 가로/세로 프레임 수 | |
| `animation_library` | `myhero_anims.tres` 드래그 | |
| `sprite_offset` | 보통 (0, 0) | 시트 여백 때문에 충돌체와 어긋나면 조정 |
| `idle_offset_delta`, `walk_offset_delta` | (0, 0) | Idle 프레임만 위/아래로 다른 경우 미세 보정 |
| **Select Screen Preview** | | |
| `preview_texture` | 보통 idle 1프레임 PNG | 선택 화면용 |
| `preview_frame` | 0 | 시트일 경우 표시할 프레임 |
| **Stats** | | |
| `move_speed` | bird=25, researcher=30 등 | |
| `air_speed_multiplier` | 1.6 | 공중 가속 |
| `jump_force` | 100 | |
| `max_health` | 5 | |
| `climb_speed` | 40.0 | 사다리 없는 캐릭터도 그냥 두면 됨 |
| **Skills** | | |
| `attack_scene` | bird: `player_bullet.tscn` / 다른 캐릭터: 자기 공격 씬 또는 null | |
| `skill_scene` | bird: `poop_coin.tscn` / null 가능 | |
| **Availability** | | |
| `implemented` | true | false면 선택 화면에서 dim + "준비 중" |

### Step 4 — `PlayerStats.characters`에 등록
`0303-renewal/Scripts/player_stats.gd:23` 의 배열에 한 줄 추가:

```gdscript
var characters: Array[CharacterData] = [
    preload("res://Resorces/Characters/bird.tres"),
    preload("res://Resorces/Characters/researcher.tres"),
    preload("res://Resorces/Characters/planner.tres"),
    preload("res://Resorces/Characters/myhero.tres"),   # ← 추가
]
```

### Step 5 — 선택 화면 슬롯 추가
**3개까지는 .tscn에 슬롯이 미리 만들어져 있다.** 그 이상이라면 `Scenes/character_select.tscn`에서 슬롯 노드(`Choices/MyHeroOption` + `Characters/MyHeroSprite`)를 추가하고, `Scripts/character_select.gd:54` 의 `slots` 배열에 한 줄 추가:

```gdscript
slots = [
    { "id": &"bird",       "btn": bird_btn,       "label": bird_label,       "sprite": bird_sprite },
    { "id": &"researcher", "btn": researcher_btn, "label": researcher_label, "sprite": researcher_sprite },
    { "id": &"planner",    "btn": leader_btn,     "label": leader_label,     "sprite": leader_sprite },
    { "id": &"myhero",     "btn": myhero_btn,     "label": myhero_label,     "sprite": myhero_sprite },  # ← 추가
]
```

---

## 3. 시작 레벨 분기 (선택)

캐릭터마다 다른 레벨에서 시작하게 하려면 `Scripts/story1_scene.gd` 의 `ROUTES`에 추가:

```gdscript
const ROUTES := {
    &"bird":       { "sprite": "story1", "next": "res://Scenes/level_1.tscn" },
    &"researcher": { "sprite": "story2", "next": "res://Scenes/level_7.tscn" },
    &"planner":    { "sprite": "story3", "next": "res://Scenes/level_6.tscn" },
    &"myhero":     { "sprite": "story4", "next": "res://Scenes/level_9.tscn" },
}
```

`story1_scene.tscn`에 `story4` Sprite2D 노드를 추가하는 것 잊지 말 것.

---

## 4. 동작 원리 (왜 이렇게 됐는지)

### 4.1 `_apply_character_data()`가 하는 일 (`player.gd:77`)
1. `PlayerStats.get_selected()`로 현재 `CharacterData` 받기 (null 절대 X — 폴백 보장).
2. `character_id` 갱신.
3. `sprite_texture`가 있으면 `Sprite2D.texture` + `hframes/vframes` 덮어씀.
4. `animation_library`가 있으면:
   - `anim.remove_animation_library("")` (빈 라이브러리 제거)
   - `anim.add_animation_library("", lib)` (새 라이브러리를 빈 이름으로 등록)
   - 이렇게 하면 `anim.play("Idle")`가 자동으로 새 클립을 재생.
5. 스탯/스킬 필드 덮어씀.

> **왜 `""`(빈 이름) 라이브러리인가?** `anim.play("Idle")`처럼 라이브러리 이름 없이 호출하면 Godot은 `""` 라이브러리에서 찾는다. 이름 있는 라이브러리(`"researcher/Idle"` 같은)면 호출 시마다 prefix가 필요해 코드가 더러워진다.

### 4.2 폴백 체인 (`player_stats.gd:55 get_selected()`)
1. `characters` 배열에서 `selected_character_id` 매칭 시도.
2. 매칭 실패 → `DEFAULT_CHARACTER_ID = &"bird"` 재탐색.
3. 그것도 실패 → `characters[0]` 반환 (배열 비었으면 null이지만 보통은 절대 안 일어남).

이 덕분에 `level_X.tscn`을 직접 실행해도(F6) 절대 깨지지 않는다.

### 4.3 왜 `Player.tscn` 하나로 충분한가
모든 캐릭터의 노드 구조(CharacterBody2D + Sprite2D + AnimationPlayer + RayCast2D + CollisionShape2D)가 동일. 다른 건 텍스처/애니메이션 데이터 + 스탯 숫자뿐 → Resource로 분리하면 충분.

**예외**: 만약 어떤 캐릭터가 **완전히 다른 노드 구조**가 필요하다면(예: 2번째 콜리전 박스, 추가 RayCast 등) `CharacterData.scene` 필드에 별도 PackedScene을 지정. `PlayerSpawner`가 `get_selected_scene()`을 통해 그걸 쓴다. 단, 그 씬에도 `player.gd`(또는 동등한 인터페이스)가 부착돼 있어야 한다.

---

## 5. 테스트 체크리스트

- [ ] 선택 화면에 새 캐릭터 슬롯이 보이고, 미리보기 스프라이트가 정상.
- [ ] `implemented = false`로 잠시 두고 선택 화면 진입 시 dim + "준비 중" 노티스 정상.
- [ ] `implemented = true` 후 캐릭터 선택 → story 진행 → 시작 레벨로 진입.
- [ ] Idle / Walk / Jump 애니메이션 정상 재생.
- [ ] Death 시 `_die()` → `anim.play("Death")` → 씬 리로드.
- [ ] `attack_scene = null`인 캐릭터는 `ui_attack` 눌러도 아무 일 없음 (push_error 없이 조용히).
- [ ] 사다리 맵에서 `Ladder` 없는 캐릭터가 사다리에 오르면 Walk 폴백으로 동작.

---

## 6. 자주 하는 실수

| 증상 | 원인 |
| --- | --- |
| 캐릭터 선택 후 인게임에 들어가니 bird로 나옴 | `PlayerStats.characters`에 `preload` 등록 안 함 → `get_selected()`가 못 찾아 폴백 |
| 인게임 캐릭터 스프라이트가 잘려서 한 프레임만 나옴 | `sprite_hframes`/`vframes`가 시트 실제 격자와 안 맞음 |
| 점프할 때 위치가 위로 튐 | `sprite_offset.y`가 음수로 너무 크게 잡힘. 0부터 시작해 조정 |
| Walk 애니메이션 안 돌고 1프레임에서 정지 | `AnimationLibrary`에 클립이 1프레임만 있거나 `length`가 0. 에디터에서 클립 시간/Loop 확인 |
| `_apply_character_data` 안 불림 | `PlayerStats`가 autoload 등록 안 됨. `project.godot` 확인 |
