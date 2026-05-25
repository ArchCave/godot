# 패턴: 특정 캐릭터에만 적인 적 (`enemy_to`)

> "이 드론은 bird만 공격한다 (researcher가 지나가도 무시)", "이 적은 모든 캐릭터에게 적이지만 researcher가 쏘는 총알엔 면역" 같은 룰.

핵심 파일:
- `0303-renewal/Scripts/Enemy.gd` (드론 패트롤 적, Area2D 루트)
- `0303-renewal/Scripts/drone_taxi.gd` (Enemy.gd의 변형, AnimationPlayer 없는 버전)
- `0303-renewal/Scripts/bird_enemy.gd` (점프 새, CharacterBody2D 루트) — `enemy_to` 미적용, 항상 모두 공격

---

## 1. 핵심 필드

```gdscript
## 이 적이 노릴 캐릭터. 빈 값(&"")이면 모든 캐릭터에게 적.
## 특정 id (예: &"bird") 설정 시 그 캐릭터에게만 데미지/총알 적용.
@export var enemy_to : StringName = &""

func _is_enemy_to_selected() -> bool:
    if enemy_to == &"":
        return true
    return PlayerStats.selected_character_id == enemy_to
```

이 가드를 **두 군데**에 끼운다:
1. `_on_body_entered(body)`에서 body가 Player일 때 데미지 주기 전.
2. `take_bullet_damage(amount)`에서 데미지 받기 전.

> **(2)가 왜 필요한가?** 적이 bird만 노린다 = bird만 데미지를 입는다. 동시에 **researcher가 쏜 총알엔 면역**으로 처리하고 싶을 때 효과적. 만약 "researcher가 쏘면 죽긴 죽지만 bird를 공격은 안 한다"가 원하는 동작이면 `take_bullet_damage`에선 가드를 빼면 된다.

---

## 2. 셋업 절차

### Step 1 — 인스펙터에서 지정
1. 레벨에서 적(드론) 인스턴스 선택.
2. **Enemy To** 필드에 `bird` / `researcher` / `planner` 중 하나 입력.
3. 비워두면 모두에게 적 (기본값).

### Step 2 — 끝.
`Enemy.gd` / `drone_taxi.gd`는 이미 패턴이 들어 있다. 새 적을 만들면 같은 가드를 복사.

---

## 3. 새 적 스크립트 만들 때 템플릿

```gdscript
extends Area2D  # 또는 CharacterBody2D
## TODO: 적 설명.

@export var max_health : int = 3

## 이 적이 노릴 캐릭터. 빈 값이면 모든 캐릭터에게 적.
@export var enemy_to : StringName = &""

var health : int

func _ready() -> void:
    health = max_health

# 충돌해서 플레이어에 데미지를 줄 때
func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("Player"):
        return
    if not _is_enemy_to_selected():
        return
    body.take_damage(1)

# player_bullet이 직접 호출 (Area2D면 그대로, CharacterBody2D면 enemy_hurt_area 통해 forward)
func take_bullet_damage(amount: int) -> void:
    if not _is_enemy_to_selected():
        return
    health -= amount
    if health <= 0:
        PlayerStats.enemy_kills += 1
        queue_free()

func _is_enemy_to_selected() -> bool:
    if enemy_to == &"":
        return true
    return PlayerStats.selected_character_id == enemy_to
```

---

## 4. 코인 드롭 + 킬 카운트 연동

`Enemy.gd` / `drone_taxi.gd`는 죽을 때 `PlayerStats.enemy_kills += 1` 카운트하고 `_drop_coin()`으로 `poop_coin.tscn`을 떨군다. 새 적도 이 패턴을 따를지(점수 시스템과 연동) 결정.

`bird_enemy.gd`는 다른 카운터(`PlayerStats.bird_enemy_kills += 1`)를 쓴다 — 이건 [conditional_path.md](conditional_path.md)와 연동돼 길 개폐 조건이 됨. 비슷한 게임 진행 게이팅 카운터가 필요하면 `PlayerStats`에 변수 추가하고 새 적이 그걸 카운트하게.

---

## 5. CharacterBody2D 루트 적의 경우 (BirdEnemy 같은)

총알이 hit하는 노드(자식 Area2D)와 데미지 로직이 있는 노드(부모 CharacterBody2D)가 다르므로, **forwarder가 필요하다**:

```
BirdEnemy (CharacterBody2D, bird_enemy.gd, take_bullet_damage 보유)
└── HurtArea (Area2D, enemy_hurt_area.gd)
    └── CollisionShape2D
```

`enemy_hurt_area.gd`가 자기 `take_bullet_damage`를 받으면 `get_parent().take_bullet_damage(amount)`로 위임. 자세한 건 [bullet_damage_forwarding.md](bullet_damage_forwarding.md).

---

## 6. 테스트 체크리스트

- [ ] `enemy_to = "bird"` 적 옆을 researcher로 지나가면 무반응(데미지 X), 총알도 안 맞음.
- [ ] 같은 적이 bird일 땐 정상 데미지/사망.
- [ ] `enemy_to = ""` 적은 캐릭터 무관 모두 공격.
- [ ] 적 사망 시 `PlayerStats.enemy_kills`가 1 증가.

---

## 7. 관련 패턴

- CharacterBody2D 적의 데미지 라우팅 → [bullet_damage_forwarding.md](bullet_damage_forwarding.md)
- 적 처치 수에 따른 길 개폐 → [conditional_path.md](conditional_path.md)
