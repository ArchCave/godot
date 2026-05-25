# 패턴: One-way 점프 플랫폼 + drop-through

> 위에서 떨어지면 안착, 옆/아래에서 자유 통과, `ui_down` 누르면 아래로 떨어짐. + 옵션으로 패트롤(좌우/상하).

핵심 파일: `0303-renewal/Scripts/jump_platform.gd`

---

## 1. 동작 개요

이전 버전은 수동 collision toggle을 했지만, 이번 리팩토링에서 **Godot 내장 `CollisionShape2D.one_way_collision`**을 활용하는 방식으로 바뀌었다.

```gdscript
func _ready() -> void:
    ...
    for c in _all_children(self):
        if c is CollisionShape2D:
            c.one_way_collision = true  # ← Godot 내장
            _shapes.append(c)
    _move_origin = position
```

`one_way_collision = true`만 켜두면:
- 위→아래 진입은 안착.
- 아래→위 진입은 통과.
- 옆에서 부딪혀도 통과 (얇은 발판은 측면 충돌이 거의 없으므로 자연스럽다).

**drop-through (`ui_down`)**:
- 플레이어가 이 발판 위에 서 있을 때(`_is_player_standing_on_self`) `ui_down`을 누르면, **모든 CollisionShape2D를 일괄 disable** → `drop_duration` (기본 0.3s) 후 일괄 enable.
- 일괄 disable이 필수: 한 Jump 노드에 shape들이 16px 간격으로 빽빽이 쌓여있어, 하나만 끄면 바로 아래 shape에 다시 안착됨.

**패트롤**:
- `MovementMode { NONE, HORIZONTAL, VERTICAL }`.
- `movement_distance`만큼 한쪽으로 갔다가 반대로 왕복.
- 움직이는 플랫폼은 항상 솔리드 (one_way 무시 안 함 — `c.one_way_collision`은 그대로 true지만, drop-through 로직은 패트롤 모드일 때 매 프레임 `s.disabled = false`로 강제 enable해서 의도치 않은 disable을 막음).

---

## 2. 셋업 절차

### Step 1 — 점프 플랫폼 노드 만들기
1. `AnimatableBody2D` 만들고 `jump_platform.gd` 부착.
2. 자식 `CollisionShape2D` 추가 (보통 가로로 긴 RectangleShape2D, 두께 얇게).
3. 시각용 Sprite2D 자식 추가.

### Step 2 — 인스펙터 설정
| 필드 | 기본값 | 메모 |
| --- | --- | --- |
| `Player` (NodePath) | 비움 | 비우면 그룹 폴백 — 보통 비워두면 됨 |
| `Player Foot Offset` | 9.0 | 캡슐 바닥 위치 (보통 그대로) |
| `Drop Duration` | 0.3 | drop-through 동안 disable 유지 시간 |
| `Movement Mode` | NONE | HORIZONTAL / VERTICAL 패트롤 |
| `Movement Distance` | 0 | 왕복 거리 (px) |
| `Movement Direction` | -1 | -1 = 왼쪽/위 먼저, 1 = 오른쪽/아래 먼저 |
| `Movement Speed` | 30 | px/s |

### Step 3 — 끝
신호 연결 불필요 — 모두 코드에서 처리.

---

## 3. 동작 원리 (왜 일괄 disable인가)

한 점프 플랫폼 노드 안에 보통 여러 개의 작은 CollisionShape2D가 16px 간격으로 쌓여있다 (긴 발판을 만들기 위해). 이 상태에서:

- `ui_down`을 누르면 한 shape만 disable → 플레이어가 그 shape 아래로 1px 떨어짐 → 즉시 다음 shape에 안착 → 떨어진 거나 마나.
- 그래서 **모든 shape를 동시에 disable** + 플레이어 y를 +2px 살짝 밀어줘서 첫 프레임의 충돌을 회피.

```gdscript
if Input.is_action_just_pressed("ui_down") and _player.is_on_floor() and _is_player_standing_on_self():
    for s in _shapes:
        s.disabled = true
    _player.global_position.y += 2.0
    await get_tree().create_timer(drop_duration).timeout
    for s in _shapes:
        s.disabled = false
```

`_is_player_standing_on_self()`는 `move_and_slide` 결과의 KinematicCollision2D 리스트를 순회해서 자기 자신이 충돌체인지 확인. 다른 발판 위에 있을 땐 발동 안 함.

---

## 4. 패트롤 플랫폼

```gdscript
@export var movement_mode : MovementMode = MovementMode.HORIZONTAL
@export var movement_distance : float = 64.0
@export var movement_direction : int = -1   # 처음에 어느 쪽으로 갈지
@export var movement_speed : float = 30.0
```

`_apply_patrol`이 매 프레임 `_move_offset`을 누적 → `position = _move_origin + 방향 * offset`. 한계 도달 시 `_move_phase`를 뒤집어서 왕복.

**Tip**: `AnimatableBody2D`는 플레이어를 자동으로 같이 운반한다 (`move_and_slide` 시 캐리어 인식). 즉 패트롤 발판 위에 올라타면 플레이어가 발판과 함께 이동.

---

## 5. 플레이어 참조 해결 (그룹 폴백)

`PlayerSpawner`로 동적 스폰되는 환경에서 `_ready()`에 플레이어가 아직 트리에 없을 수 있다. 그래서:

```gdscript
func _resolve_player() -> void:
    if player != NodePath(""):
        _player = get_node_or_null(player) as CharacterBody2D
    if _player == null:
        for group_name in ["Player", "player"]:
            var nodes := get_tree().get_nodes_in_group(group_name)
            if nodes.size() > 0:
                _player = nodes[0] as CharacterBody2D
                break

func _physics_process(delta: float) -> void:
    _apply_patrol(delta)
    if _player == null:
        _resolve_player()
        if _player == null:
            return
    ...
```

매 프레임 재시도 — 비싸 보이지만 한 번 잡으면 끝이고, 잡힐 때까진 가벼운 그룹 쿼리뿐.

---

## 6. 자주 하는 실수

- **위에서 안 안착되고 그냥 통과**: `CollisionShape2D.one_way_collision`이 `false`인 채로 남았거나, `_shapes`에 안 들어감. `_ready`에서 `_all_children` 순회로 모든 자식 CollisionShape2D를 잡지만, 자식이 깊이 들어가 있으면 잘 잡힘. 단, RigidBody2D 같은 다른 노드 안의 CollisionShape2D는 안 잡음 — `AnimatableBody2D` 직접 자식이어야 함(현재는 그렇게 돼있음).
- **`ui_down` 눌러도 안 떨어짐**: `_is_player_standing_on_self`가 false 반환. `move_and_slide` 후의 충돌 리스트에 자기 자신이 없는 경우. 발판이 너무 좁거나, 캐릭터가 발판 가장자리에 살짝 걸쳐 있을 때 발생할 수 있음. 발판 가로폭을 충분히.
- **drop-through 중 한 발 더 떨어짐**: 0.3초가 너무 짧아 disable 풀리는 순간 플레이어가 다음 발판에 안 닿은 상태. `drop_duration`을 0.5~0.7로 올리거나, disable을 단계적으로 해제.
- **패트롤 발판 위 플레이어가 떨어짐**: `AnimatableBody2D` 대신 `StaticBody2D`로 만들면 캐리 안 됨. `AnimatableBody2D` 맞는지 확인.
