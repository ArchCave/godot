# 패턴: 특정 캐릭터에만 반응하는 Area2D

> "researcher가 들어왔을 때만 안내 창이 뜨게 하고 싶다", "bird일 때만 다이얼로그 말풍선", "planner 전용 힌트 표시" 같은 케이스.

---

## 1. 어떤 노드들이 이 패턴을 쓰나

| 스크립트 | 트리거 시 동작 |
| --- | --- |
| `Scripts/Intro_Guide.gd` | 자식 `IntroGuide` 스프라이트 + 선택 `IntroBackground`를 보였다 가렸다 |
| `Scripts/bird_intro_talk.gd` | 자식 말풍선 스프라이트 표시 + 플레이어 X 좌표 따라감 + 선택 `pause_background` |
| `Scripts/researcher_notice4.gd` | 자식 `notice` 스프라이트를 N초간 표시 (한 번만) |
| `Scripts/Dialogue_area_2d.gd` | 자식 `IntroDialog` 표시/숨김 (※ `&"bird"` 하드코딩 — 일반화 X) |

> **공통 핵심 필드**: `@export var allowed_character_id: StringName = &""`
>
> - 빈 값(`&""`)이면 **모든 캐릭터에 반응** (기본값, 구버전 호환).
> - `&"bird"`, `&"researcher"`, `&"planner"` 중 하나를 넣으면 그 캐릭터만 통과.

---

## 2. 셋업 절차 (Step-by-step)

### Step 1 — 씬 구조
```
Area2D (root)             ← 스크립트 부착
├── CollisionShape2D       ← 발동 영역
└── Sprite2D (anything)    ← 표시될 안내/말풍선/sprite. name은 스크립트가 찾는 이름
```

스크립트별 자식 이름 규약:
- `Intro_Guide.gd` → `IntroGuide` (필수), `IntroBackground` (옵션)
- `bird_intro_talk.gd` → 아무 Sprite2D (자동 탐색) + `pause_background` (옵션)
- `researcher_notice4.gd` → `notice` (필수)

### Step 2 — 신호 연결
대부분이 `body_entered` / `body_exited` 사용. 인스펙터 → Node 탭에서 두 신호를 자기 자신의 `_on_body_entered` / `_on_body_exited`에 연결.

> `researcher_notice4.gd`는 신호를 안 쓰고 `_physics_process`에서 직접 `get_overlapping_bodies()` 폴링한다. **이유**: Area2D가 트리에 추가된 직후 첫 프레임 신호가 누락되는 케이스가 있어서. 한 번 보이고 사라지는 1회성 notice라 신호 누락이 치명적임. 비슷한 1회성 패턴이 필요하면 그 스크립트를 복제하는 게 안전하다.

### Step 3 — 인스펙터에서 캐릭터 지정
1. Area2D 노드 선택
2. **Allowed Character Id** 필드에 `bird` / `researcher` / `planner` 중 하나 입력 (`StringName`이지만 인스펙터에선 그냥 텍스트 — `&` 안 붙임)
3. 빈 칸이면 "모든 캐릭터에 반응"

### Step 4 — Player가 "Player" 그룹에 있는지 확인
- `Player.tscn`의 루트는 자동으로 그룹에 들어가지 않을 수 있다. `player.gd._ready()`에 `if not is_in_group("Player"): add_to_group("Player")` 가드가 들어있으므로 별도 설정 불필요.

---

## 3. 직접 짜는 새 스크립트 템플릿

```gdscript
extends Area2D
## TODO: 이 트리거가 무엇을 하는지 한 줄 설명.

## 빈 값이면 모든 캐릭터에 반응. bird/researcher/planner 중 하나를 인스펙터에서 설정.
@export var allowed_character_id : StringName = &""

@onready var thing_to_show : Node = $YourSpriteOrControl  # 보이게 할 노드

func _ready() -> void:
    thing_to_show.visible = false

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("Player"):
        return
    if not _is_allowed_character():
        return
    thing_to_show.visible = true

func _on_body_exited(body: Node2D) -> void:
    if not body.is_in_group("Player"):
        return
    if not _is_allowed_character():
        return
    thing_to_show.visible = false

func _is_allowed_character() -> bool:
    if allowed_character_id == &"":
        return true
    return PlayerStats.selected_character_id == allowed_character_id
```

> **왜 `_is_allowed_character()`를 두 번 다 (entered/exited) 호출하나?**
> 캐릭터를 도중에 바꾸는 경우는 없지만, 코드 대칭성을 위해 둘 다 가드한다. 빠뜨리면 "들어올 땐 무시했는데 나갈 때 visible=false가 호출되는" 버그가 잠재.

---

## 4. 동작 검증 (수동 테스트)

1. 캐릭터 선택 화면에서 **bird** 선택 → 의도한 게이트 통과 / 다른 게이트 통과 X.
2. 씬을 다시 로드해 **researcher** 선택 → 반대 게이트만 통과.
3. **개발자 모드 단축 테스트**: `level_X.tscn`을 직접 F6 실행하면 캐릭터 선택을 거치지 않으므로 `PlayerStats.selected_character_id`가 `DEFAULT_CHARACTER_ID = &"bird"` 폴백 상태. 즉 bird 게이트만 통과한다. researcher/planner 게이트를 단독 테스트할 땐 `_ready()` 첫 줄에 임시로 `PlayerStats.selected_character_id = &"researcher"`를 넣고 테스트, 끝나면 지우기.

---

## 5. 주의사항

- **`StringName` vs `String`**: 인스펙터 텍스트 박스에 그냥 `bird`라고 치면 Godot이 자동으로 `&"bird"`로 변환한다. 코드에서 비교할 땐 `&"bird"` 사용 (StringName 리터럴이 더 빠름).
- **선택 캐릭터 정보가 비어있을 때**: `Dialogue_area_2d.gd`처럼 직접 `PlayerStats.selected_character_id != &"bird"`를 비교해도 되지만, 폴백 보장(`get_selected()`는 절대 null 안 반환)을 활용하려면 `PlayerStats.get_selected().id`를 쓰는 게 더 안전.
- **CollisionLayer/Mask**: Area2D의 mask가 플레이어 레이어를 감지하도록 설정돼 있어야 함. 기존 노드들과 동일한 레이어를 사용하면 보통 문제없다.

---

## 6. 관련 패턴

- 적이 캐릭터별 타겟팅을 할 때 → [per_character_enemy.md](per_character_enemy.md) (`enemy_to` 패턴)
- 캐릭터별 출구 → [endflag_per_character.md](endflag_per_character.md)
- 캐릭터별 시작 위치 → [player_spawner.md](player_spawner.md)
