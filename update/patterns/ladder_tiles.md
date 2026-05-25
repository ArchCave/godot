# 패턴: 사다리 (TileMap 기반)

> 맵에 올라탈 수 있는 사다리를 깔고 싶다. `player.gd`가 이미 climb 상태머신을 가지고 있으므로, **TileMap의 특정 타일에 custom_data `is_ladder=true`**를 켜놓고 레벨에 그 TileMapLayer를 두면 끝.

핵심 파일: `0303-renewal/Scripts/player.gd` (`_is_on_ladder`, `_physics_process` 사다리 분기)

---

## 1. 동작 개요

`player.gd._physics_process()` 첫 부분:

```gdscript
var v_input := Input.get_axis("ui_up", "ui_down")
var on_ladder := _is_on_ladder()

if on_ladder and not is_climbing:
    if v_input != 0.0 or (not is_on_floor() and velocity.y > 0.0):
        is_climbing = true
        velocity.y = 0.0
if is_climbing and not on_ladder:
    is_climbing = false

if is_climbing:
    velocity.y = v_input * climb_speed
    velocity.x = Input.get_axis("ui_left", "ui_right") * move_speed
    if Input.is_action_just_pressed("ui_jump"):
        is_climbing = false
        velocity.y = -jump_force * 0.7
    move_and_slide()
    update_animation()
    return
```

진입 트리거:
- 위/아래 입력 누름 — 명시적으로 잡기
- **또는** 사다리 영역 위에 떨어지는 중(`velocity.y > 0`) — 자동 잡기 (추락 방지)

탈출:
- 사다리 영역에서 벗어남
- 점프 키 (`ui_jump`) — 사다리에서 점프 (위로 jump_force * 0.7)

---

## 2. 셋업 절차

### Step 1 — TileSet에 custom_data 추가
1. TileSet 리소스(예: `Resorces/TileSet_Lab_high.tres`)를 열기.
2. TileSet 인스펙터에서 **Custom Data Layers** → 새 레이어 추가 → 이름 `is_ladder`, 타입 `bool`.
3. 사다리로 쓸 타일 선택 → 우측 패널 → custom_data 영역에서 `is_ladder = true` 체크.

### Step 2 — 레벨 씬에 TileMapLayer 추가
1. 레벨 씬 트리에 `TileMapLayer` 추가.
2. **TileSet 필드**에 위의 리소스 드래그.
3. 사다리 타일을 원하는 위치에 그림.
4. **그룹에 등록**: TileMapLayer 노드 → 우측 Groups 탭 → "Ladders" 추가.

### Step 3 — Player.gd가 자동으로 찾음
`player.gd._ready()`:
```gdscript
if ladder_tilemap == null:
    var found := get_tree().get_first_node_in_group("Ladders")
    if found is TileMapLayer:
        ladder_tilemap = found
```

> 인스펙터에서 `Ladder Tilemap` 필드에 NodePath를 직접 지정해도 됨. 비워두면 그룹으로 탐색.

### Step 4 — 캐릭터에 Ladder 애니메이션 추가 (선택)
`AnimationLibrary`에 `Ladder` 클립을 만들면 사다리 위에서 그게 재생됨. 위/아래 입력이 없으면 `anim.speed_scale = 0`으로 같은 프레임 정지.

`Ladder` 클립이 없는 캐릭터(예: planner)는 폴백으로 Walk/Idle 사용.

---

## 3. TileMapLayer 좌표 변환 (스크립트 내부)

```gdscript
func _is_on_ladder() -> bool:
    if ladder_tilemap == null:
        return false
    var local := ladder_tilemap.to_local(global_position)
    var coords := ladder_tilemap.local_to_map(local)
    var data := ladder_tilemap.get_cell_tile_data(coords)
    return data != null and data.get_custom_data("is_ladder")
```

- `to_local(global_position)` — 플레이어 월드 좌표 → TileMap 로컬 좌표
- `local_to_map(local)` — 로컬 좌표 → 타일 격자 좌표 (Vector2i)
- `get_cell_tile_data(coords)` — 그 격자의 TileData (없으면 null = 빈 타일)
- `get_custom_data("is_ladder")` — bool 반환. layer 이름 정확히 일치해야 함.

---

## 4. 사다리 위에서 점프 플랫폼은 어떻게 처리되나?

사다리 처리는 `_physics_process` 맨 앞에서 `return`하므로, climb 중에는 점프 플랫폼의 drop-through나 중력이 적용되지 않는다.

사다리가 점프 플랫폼과 겹쳐 있으면:
- 사다리 우선 — climb 중에는 플랫폼 위에 있어도 안 떨어짐.
- 점프 키로 사다리에서 빠져나오면 그 다음 프레임부터 일반 물리 → 플랫폼 위에 안착하거나 통과.

---

## 5. 캐릭터별 사다리 활성/비활성

현재 구조는 모든 캐릭터가 사다리를 탈 수 있다. 만약 **researcher만 사다리 가능, bird/planner는 불가**처럼 하고 싶다면:

```gdscript
# player.gd._is_on_ladder() 안에서
func _is_on_ladder() -> bool:
    if ladder_tilemap == null:
        return false
    # 사다리를 못 타는 캐릭터는 false 반환
    if character_id in [&"bird", &"planner"]:
        return false
    var local := ladder_tilemap.to_local(global_position)
    ...
```

또는 `CharacterData`에 `can_climb : bool` 필드 추가해서 데이터 기반으로 제어.

---

## 6. 자주 하는 실수

- **사다리 타일을 그렸는데 climb이 안 됨**: `is_ladder` custom_data를 `true`로 설정 안 함. 또는 layer 이름 오타.
- **TileMapLayer가 "Ladders" 그룹에 없음**: 그룹 정확히 `Ladders` (대문자 L, 복수형). 오타 흔함.
- **사다리에 자동으로 잡힘 (위/아래 안 눌렀는데)**: 떨어지는 도중 자동 잡기 트리거(`not is_on_floor() and velocity.y > 0.0`)가 작동. 의도된 동작 — 추락사 방지. 만약 끄려면 그 조건만 제거.
- **사다리에서 좌우로 빠져나갈 수 없음**: `velocity.x = Input.get_axis("ui_left", "ui_right") * move_speed`가 있으므로 가능. 다만 사다리 영역 밖으로 벗어나면 즉시 climb 해제. 사다리 폭이 좁아 잘 안 빠질 때가 있음 — 사다리 타일을 옆에 1칸 더 깔거나, `_is_on_ladder` 판정에 1칸 좌우 여유를 줄 수 있음.
