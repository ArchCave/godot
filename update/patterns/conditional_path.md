# 패턴: 게임 상태에 따른 통로 개폐

> "BirdEnemy를 한 마리도 죽이지 않았으면 다음 길을 열어준다." 같이 **PlayerStats의 카운터를 읽어 영역 자체를 제거**해서 길을 여는 패턴.

핵심 파일: `0303-renewal/Scripts/conditional_through.gd`

---

## 1. 동작 개요

```
ConditionalThrough (Area2D, conditional_through.gd)   ← 이 노드 + 자식 전부가 길을 막음
├── CollisionShape2D                                   ← Area2D 트리거
└── StaticBody2D                                       ← 실제 벽
    └── CollisionShape2D
```

플레이어가 Area2D에 진입하면:
- 조건 만족 → 자기 자신(부모 Area2D)을 `queue_free()` → 자식 StaticBody2D까지 같이 사라짐 → 길 개방.
- 조건 불만족 → 그대로 → 길 막힘.

현재 스크립트의 조건은 `PlayerStats.bird_enemy_kills == 0` (BirdEnemy를 한 마리도 안 죽였을 때만 통과).

---

## 2. 셋업 절차

### Step 1 — 씬 만들기
1. Area2D 만들고 `conditional_through.gd` 부착.
2. 자식 CollisionShape2D (Area2D의 발동 영역 — 보통 벽 약간 앞).
3. 자식 StaticBody2D + 그 자식 CollisionShape2D (실제 벽).

### Step 2 — 레벨 8에 인스턴스화
`level_8.tscn`이 이미 이 패턴을 쓴다. 새 레벨에 옮길 땐 위 구조를 통째로 복제.

### Step 3 — 신호 연결
`body_entered` → `_on_body_entered` (스크립트의 `_ready()`에서 코드로 연결됨, 인스펙터에서 추가 작업 불필요).

---

## 3. 다른 조건으로 응용

```gdscript
# 코인 30개 모았으면 길 열림
func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("Player"):
        return
    if PlayerStats.score >= 30:
        queue_free()

# 특정 캐릭터일 때만 길 열림
func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("Player"):
        return
    if PlayerStats.selected_character_id == &"researcher":
        queue_free()

# 적을 N마리 이상 죽였을 때만 길 열림
func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("Player"):
        return
    if PlayerStats.enemy_kills >= 5:
        queue_free()
```

> **반대 패턴(조건 충족 시 막힘)**: `queue_free`를 호출 안 하고, 대신 `StaticBody2D.show()` + collision enable로 토글. 하지만 보통은 "조건 만족 시 영구 해방"이 게임 디자인상 깔끔.

---

## 4. "길은 열리지만 메시지를 띄우고 싶다" 변형

```gdscript
func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("Player"):
        return
    if PlayerStats.bird_enemy_kills == 0:
        # "비폭력 통로 발견" 같은 토스트 띄우기
        var msg = preload("res://Scenes/toast_message.tscn").instantiate()
        msg.text = "비폭력 통로 발견!"
        get_tree().current_scene.add_child(msg)
        queue_free()
```

---

## 5. 새 카운터 만들기

게임 진행 상태를 추적할 새 카운터가 필요하면 `0303-renewal/Scripts/player_stats.gd`에 추가:

```gdscript
var score : int = 0
var enemy_kills : int = 0
var bird_enemy_kills : int = 0
var puzzle_solved_count : int = 0   # ← 추가

func reset() -> void:
    score = 0
    enemy_kills = 0
    bird_enemy_kills = 0
    puzzle_solved_count = 0
```

`reset_all()`까지 갱신하는 것 잊지 말 것 (캐릭터 재선택 시 카운터 초기화 의도라면).

---

## 6. 주의사항

- **`queue_free()`는 그 프레임 끝에 노드를 제거**한다. 즉 같은 프레임 안에서 다른 신호가 또 발동되거나 하지 않음.
- **씬 리로드 시(`get_tree().reload_current_scene()`) 카운터는 유지**된다 (PlayerStats는 autoload). 캐릭터 사망 후 리로드해도 `bird_enemy_kills`는 그대로. 의도된 동작인지 확인할 것 — 만약 "리트라이 시 카운터 리셋"이 필요하면 player의 `_die()`나 `_fall_die()`에 `PlayerStats.reset()` 한 줄.
- **다음 레벨로 넘어갈 때 카운터 처리**: 현재 코드는 자동 리셋 안 함. 캐릭터 선택 화면으로 돌아갈 때만 `reset_all()` 호출하는 게 자연스러움.
