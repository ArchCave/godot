# 패턴: 캐릭터별 EndFlag (출구)

> 같은 맵 안에 캐릭터마다 다른 출구를 두고 싶을 때 (bird→다음 bird 레벨, researcher→다음 researcher 레벨).

핵심 파일: `0303-renewal/Scripts/endflag.gd`

---

## 1. 동작 개요

`EndFlag`는 `Area2D + AnimatedSprite2D`. `_ready()`에서:
1. `PlayerStats.get_selected().id`를 가져옴.
2. `character_id == &""` → **모든 캐릭터에 활성** (기본값, 단일 출구 레벨용).
3. `character_id != selected_id` → **숨기고 비활성** (`visible = false`, `monitoring/monitorable = false`, `collision.disabled = true`).
   - **`queue_free` 안 함**. 트리에 남아있고 단지 보이지 않을 뿐.
4. `character_id == selected_id` → **보이게 + 활성**.

플레이어가 활성 EndFlag에 닿으면:
1. `triggered` 플래그로 중복 방지.
2. 플레이어 `Idle` 애니메이션 강제 (walk/jump 자세에서 굳지 않게).
3. 플레이어 `set_physics_process(false)` (얼림).
4. `anim_sprite.play("end")` 재생.
5. 애니메이션 끝나면 `change_scene_to_packed(scene_to_load)`.

---

## 2. 셋업 절차

### Step 1 — EndFlag 인스턴스화
1. 레벨 씬에 `EndFlag` 노드(또는 기존 EndFlag 씬) 배치.
2. 인스펙터 필드 채우기:
   - **Scene To Load**: 다음 레벨 PackedScene 드래그
   - **Character Id**: `bird` / `researcher` / `planner` 또는 비워둠

### Step 2 — 신호 자동 연결
`body_entered` → `_on_body_entered`, `anim_sprite.animation_finished` → `_on_animation_finished`는 스크립트 안에서 처리 (인스펙터 연결 불필요).

### Step 3 — 캐릭터별로 여러 개 깔기 (선택)
같은 맵에 3개의 EndFlag를 다른 위치에 배치, 각각 다른 `character_id`와 `scene_to_load` 지정. 선택 캐릭터에 따라 알맞은 하나만 보이고 작동.

---

## 3. 왜 `queue_free`가 아니라 비파괴 비활성화인가

`endflag.gd` 코멘트에 명시돼 있음:
> "(queue_free 안 함 — 트리에는 남아있고 단지 비활성/숨김.)"

이유:
- **레벨 디자인 의도**: 다른 캐릭터로 같은 맵을 플레이할 때 시각적으로 "다른 출구가 있을 수 있음"이 암시될 수 있게 (지금은 visible=false라 안 보이지만, 디자인상 토글 변경이 쉬움).
- **씬 일관성**: `queue_free`된 노드는 신호 연결이 끊겨 다른 노드가 참조하면 null 에러. 비활성화는 참조는 유지.

> 단점: 트리에 3개가 다 남으니 노드 수가 늘긴 함. EndFlag는 가벼우므로 무시 가능.

---

## 4. 자주 하는 응용

### 4.1 다음 씬을 동적으로 결정
`scene_to_load` export 대신 코드에서:

```gdscript
func _on_animation_finished() -> void:
    if not triggered:
        return
    # 캐릭터별 다음 씬
    var next : String = ""
    match PlayerStats.selected_character_id:
        &"bird": next = "res://Scenes/level_2.tscn"
        &"researcher": next = "res://Scenes/level_8.tscn"
        &"planner": next = "res://Scenes/ending.tscn"
    get_tree().change_scene_to_file(next)
```

(이게 필요한 경우는 거의 없다 — 캐릭터별로 EndFlag를 3개 두면 자연스럽게 분기된다.)

### 4.2 "엔딩 출구"
`scene_to_load = res://Scenes/ending.tscn`로 지정. 엔딩 씬에서 `PlayerStats.reset_all()` 호출해 캐릭터 선택 화면 복귀.

### 4.3 트리거 조건 추가
"적을 다 죽이지 않으면 발동 안 함" 같은 게이팅:

```gdscript
func _on_body_entered(body: Node2D) -> void:
    if triggered:
        return
    if not body.is_in_group("Player"):
        return
    if PlayerStats.enemy_kills < required_kills:
        return  # 조건 불만족 — 무시
    triggered = true
    ...
```

---

## 5. 함정

- **`triggered` 플래그**: 캐릭터가 영역에 들어왔다 나갔다 반복하면 여러 번 호출되는 걸 막는다. 빼면 안 됨.
- **`set_physics_process(false)`**: 트리거 후 캐릭터가 못 움직이게 됨. 다음 씬으로 넘어가니 의도된 동작. 만약 EndFlag가 트리거됐는데 씬 전환을 미루는 연출이 있으면 플레이어가 한 자리에 굳어 있는 게 자연스럽다.
- **`anim_sprite.play("end")`**: AnimatedSprite2D에 `end`라는 애니메이션이 정의돼 있어야 함. 없으면 `_on_animation_finished`가 호출되지 않아 씬 전환이 안 일어남. 새 EndFlag 만들 때 확인.

---

## 6. 관련 패턴

- 캐릭터별 시작 위치 → [player_spawner.md](player_spawner.md)
- 캐릭터별 시작 레벨/스토리 → [per_character_story_branch.md](per_character_story_branch.md)
