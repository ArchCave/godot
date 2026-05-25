# Update Docs — `0303-renewal` 아키텍처 가이드

이 폴더는 **2026-05-21 리팩토링 이후의 코드 구조와 자주 쓸 패턴**을 정리한 곳이다. 새 캐릭터/적/지역 추가 같은 일상적 작업은 여기 문서를 따라하면 코드 수정 1~2줄로 끝나도록 설계돼 있다.

---

## 폴더 구성

```
update/
├── README.md                          ← 이 파일 (인덱스)
├── 2026-05-21_summary.md              ← 그날의 변경 전체 요약 (Before/After, 통계, 결정 이유)
└── patterns/                          ← 자주 재사용되는 셋업 패턴
    ├── character_data_system.md       ★ 새 캐릭터 추가
    ├── character_gated_area.md        ★ 특정 캐릭터에만 반응하는 트리거/말풍선
    ├── player_spawner.md              ★ 캐릭터별 시작 위치
    ├── per_character_enemy.md         ★ 특정 캐릭터만 노리는 적
    ├── conditional_path.md            ★ 게임 상태 따라 통로 열림
    ├── endflag_per_character.md       ★ 캐릭터별 출구
    ├── per_character_story_branch.md  ★ 캐릭터별 인트로 + 시작 레벨
    ├── ladder_tiles.md                ★ TileMap 사다리
    ├── one_way_platform_drop.md       ★ 점프 발판 + drop-through
    └── bullet_damage_forwarding.md    ★ CharacterBody2D 적 데미지 받기
```

---

## 어떤 작업에 어떤 문서?

| 하고 싶은 것 | 문서 |
| --- | --- |
| 캐릭터 한 명 더 추가 | [character_data_system.md](patterns/character_data_system.md) |
| 특정 캐릭터에만 보이는 안내/말풍선/대사 | [character_gated_area.md](patterns/character_gated_area.md) |
| 같은 맵에서 캐릭터별 시작 위치 다르게 | [player_spawner.md](patterns/player_spawner.md) |
| 어떤 캐릭터에만 적인 적 (또는 그 캐릭터만 공격) | [per_character_enemy.md](patterns/per_character_enemy.md) |
| 적을 안 죽이면 길이 열림 / 조건부 통로 | [conditional_path.md](patterns/conditional_path.md) |
| 캐릭터별 다음 레벨로 보내기 | [endflag_per_character.md](patterns/endflag_per_character.md) |
| 캐릭터마다 다른 인트로 컷 + 시작 레벨 | [per_character_story_branch.md](patterns/per_character_story_branch.md) |
| 사다리 깔기 | [ladder_tiles.md](patterns/ladder_tiles.md) |
| 위로만 안착되는 발판 (drop-through 포함) | [one_way_platform_drop.md](patterns/one_way_platform_drop.md) |
| 점프하는 적이 총알 데미지 못 받음 | [bullet_damage_forwarding.md](patterns/bullet_damage_forwarding.md) |
| 그날 뭐가 바뀌었는지 전체 그림 | [2026-05-21_summary.md](2026-05-21_summary.md) |

---

## 시스템 한눈에 보기

```
[Character Selection]
character_select.tscn ──(슬롯 dict)──> PlayerStats.characters (Array[CharacterData])
                                                │
                                                └─ selected_character_id
                                                        │
                                                        ▼
[Story Routing]
story1_scene.gd::ROUTES ──> 캐릭터별 다음 레벨로 분기
                                                        │
                                                        ▼
[In-game Spawn]
level_X.tscn 안의 PlayerSpawner들 (character_id별)
   ├─ 매칭 스포너만 살아남아 Player.tscn 인스턴스화
   └─ 불일치 스포너는 queue_free
                                                        │
                                                        ▼
[Player Setup]
Player.tscn _ready() ──> PlayerStats.get_selected() ──> CharacterData(.tres)
   ├─ sprite.texture / hframes / vframes / offset 적용
   ├─ AnimationPlayer 빈 라이브러리("")를 캐릭터별 lib로 통째 교체
   ├─ move_speed / jump_force / max_health / climb_speed 덮어씀
   ├─ attack_scene / skill_scene 덮어씀
   └─ "Player" 그룹 추가 (적/카메라/플랫폼이 자동 추적)
                                                        │
                                                        ▼
[Gameplay]
모든 reactive 노드들이 PlayerStats.selected_character_id 또는 group("Player")으로 식별
   ├─ Intro_Guide / bird_intro_talk / researcher_notice4 (allowed_character_id)
   ├─ Enemy / drone_taxi (enemy_to)
   ├─ EndFlag (character_id) — 다음 씬으로
   ├─ conditional_through (PlayerStats.bird_enemy_kills)
   ├─ smooth_camera ("Player" 그룹 탐색)
   └─ jump_platform ("Player" 그룹 탐색 + one_way_collision)
```

---

## 빠른 명령어 모음 (Windows PowerShell)

### 캐릭터 추가 후 빌드 확인 (헤드리스 Godot으로)
```powershell
& "C:\path\to\godot.exe" --headless --quit "E:\godot\0303-renewal\project.godot"
```

### 캐릭터별로 인게임 단독 테스트 (PlayerStats 임시 강제)
`Scripts/player_stats.gd`의 `selected_character_id`를 일시적으로 변경하고 `level_X.tscn`에서 F6.
```gdscript
var selected_character_id: StringName = &"researcher"   # ← 테스트 후 &"bird"로 복구
```

### 브랜치 작업 흐름 (현재 환경 기준)
```powershell
git status                       # 변경 확인
git diff --stat                  # 라인 통계
git log --oneline -10 renewal    # 최근 커밋
git push                         # renewal은 이미 upstream 설정 됨
```

> 첫 push인지 확인: `git branch -vv` 결과에 `[origin/renewal: …]` 있으면 이미 푸시된 적 있음.

---

## 컨벤션 메모

1. **`StringName` 식별자**: 캐릭터 id는 모두 `&"bird"` 같은 StringName 리터럴. 비교/저장이 빠르고 오타 시 컴파일 단계에서 잡기는 어렵지만 메모리는 가벼움.
2. **빈 값 = "모두에 적용"**: `allowed_character_id`, `enemy_to`, `character_id` (Spawner/EndFlag) 모두 빈 StringName을 폴백/유니버설로 해석. 신규 게이팅 필드를 만들 때 이 컨벤션 유지.
3. **NodePath 폴백 + 그룹 폴백**: 동적 스폰을 가정하고 `_ready()`에서 즉시 못 찾으면 그룹/매 프레임 재시도. `smooth_camera`, `jump_platform`, `background_parallax`, `player`(ladder_tilemap) 모두 동일 패턴.
4. **`queue_free` vs 비활성**: 트리에 잔류시키고 싶으면 `visible=false + monitoring=false + collision.disabled=true`, 영구 삭제는 `queue_free()`. 둘 다 deferred로 호출(`set_deferred("monitoring", false)`).
5. **자식 노드 탐색**: 자주 쓰는 자식은 `@onready var x = $Path` 또는 `get_node_or_null` 폴백. Optional 자식(예: `pause_background`)은 반드시 `get_node_or_null` + null 가드.

---

## 향후 추가할만한 패턴 (TODO)

- 코인/스코어 시스템 + jump_force 멀티플라이어 (player.gd `_update_jump_force()`)
- AnimationLibrary 직접 만들기 (Inspector vs 코드 생성)
- TileMapLayer 멀티 레이어 컨벤션 (Lab_high, Lab_low 등)
- 사운드/BGM 라우팅 (현재 코드에 정리된 패턴 없음)
