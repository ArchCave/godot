# 패턴: CharacterBody2D 적이 player_bullet 데미지 받기

> 적이 `Area2D` 루트면 `player_bullet`이 그냥 충돌해서 끝. 하지만 `CharacterBody2D` 루트 적(BirdEnemy처럼 점프하는 적)은 충돌 처리가 다르다 — `player_bullet`은 Area2D만 호출하므로 **forwarder**가 필요.

핵심 파일: `0303-renewal/Scripts/enemy_hurt_area.gd`

---

## 1. 문제 상황

`player_bullet.tscn`(Area2D 가정)이 충돌 대상의 `take_bullet_damage(amount)` 메서드를 호출한다.
- 적이 **`Area2D` 루트**: 적 본체에 `take_bullet_damage` 메서드 있음 → OK.
- 적이 **`CharacterBody2D` 루트** (예: `BirdEnemy`): 본체에 `take_bullet_damage` 있어도, bullet의 area_entered 신호는 Area2D만 잡음. 그러면 본체가 직접 호출되지 않음.

**해결**: CharacterBody2D 본체 안에 Area2D 자식(`HurtArea`)을 두고, 그 Area2D에 `enemy_hurt_area.gd`를 붙임. 이 forwarder가 자기 `take_bullet_damage`를 받아 `get_parent().take_bullet_damage()`로 위임.

---

## 2. enemy_hurt_area.gd

```gdscript
extends Area2D
## CharacterBody2D 루트의 적에 붙는 Area2D용 forwarder.
## player_bullet은 Area2D의 take_bullet_damage만 호출하므로, 부모(적 본체)로 위임한다.

func take_bullet_damage(amount: int) -> void:
    var p := get_parent()
    if p != null and p.has_method("take_bullet_damage"):
        p.take_bullet_damage(amount)
```

8 lines. 단순하지만 핵심.

---

## 3. 셋업 절차

### Step 1 — 적 씬 구조
```
BirdEnemy (CharacterBody2D, bird_enemy.gd, take_bullet_damage 보유)
├── Sprite2D
├── CollisionShape2D                          ← 적의 물리 충돌 (땅/벽)
└── HurtArea (Area2D, enemy_hurt_area.gd)     ← 총알 받는 영역
    └── CollisionShape2D                        ← 총알 hit 박스
```

### Step 2 — Area2D의 collision_layer/mask 설정
- `HurtArea`의 collision_layer는 "총알이 detect할 레이어" (보통 enemies 레이어).
- `HurtArea`의 collision_mask는 무관 (Area2D는 body 감지가 필요 없으면 0이어도 됨).
- `player_bullet.tscn`이 enemies 레이어를 mask로 detect하도록 설정.

### Step 3 — 끝
`enemy_hurt_area.gd`는 신호 연결 불필요. `player_bullet`이 area_entered를 잡아서 그 Area2D의 `take_bullet_damage`를 호출하면 자동으로 부모로 forward.

---

## 4. 적 본체의 take_bullet_damage 구현

```gdscript
# bird_enemy.gd (CharacterBody2D 루트)
extends CharacterBody2D

@export var max_health : int = 2
var health : int

func _ready() -> void:
    health = max_health
    hurt_area.body_entered.connect(_on_hurt_area_body_entered)

## player_bullet -> enemy_hurt_area(forwarder) -> 여기로 전달됨.
func take_bullet_damage(amount: int) -> void:
    health -= amount
    if health <= 0:
        PlayerStats.bird_enemy_kills += 1
        queue_free()
```

원하면 여기에 `enemy_to` 가드를 추가해 캐릭터별 데미지 적용 가능 ([per_character_enemy.md](per_character_enemy.md)).

---

## 5. 왜 forward만 하고 Area2D 자체에 데미지 처리 안 하나?

체력/킬카운트/사망 처리는 **본체 책임**이기 때문. Area2D는 충돌 박스일 뿐이고, 죽으면서 사라져야 하는 건 본체(`queue_free()`로 본체+자식 다 함께 사라짐).

forwarder가 직접 데미지를 처리하면:
- 본체와 Area2D가 따로 죽을 위험.
- 본체의 `health` 변수와 동기화 깨짐.
- 본체에서 적 상태(예: 사망 직전 빨개짐)를 트래킹할 수 없음.

---

## 6. 자주 하는 실수

- **Area2D에 스크립트를 안 붙임**: 그러면 `take_bullet_damage` 메서드가 없어서 player_bullet이 호출해도 무시됨. `enemy_hurt_area.gd` 부착 필수.
- **HurtArea의 monitoring/monitorable 비활성**: 기본값 true지만, 어떤 적은 도중에 toggle하기도 함. `_ready`에 명시적으로 `monitoring = true`.
- **본체에 `take_bullet_damage` 메서드 없음**: forwarder가 `has_method` 가드를 가지고 있어 push_error 안 나지만, 무반응. 본체에 메서드 추가.
- **layer/mask 미스매치**: player_bullet이 enemy hurt_area를 detect 안 함. Physics Layers/Masks를 Project Settings → Layer Names에서 명확히 이름 짓고 일치시킬 것.

---

## 7. Area2D 루트 적은 그냥 직접

`Enemy.gd` / `drone_taxi.gd`는 본체가 `Area2D`라서 forwarder 없이 직접 `take_bullet_damage`를 가짐:

```gdscript
extends Area2D
func take_bullet_damage(amount: int) -> void:
    if not _is_enemy_to_selected():
        return
    health -= amount
    ...
```

선택 가이드:
- 적이 점프하거나 중력에 영향받는다 → `CharacterBody2D` 루트 + HurtArea + forwarder.
- 적이 둥둥 떠다니거나 자체 움직임만 한다 → `Area2D` 루트 + 직접.
