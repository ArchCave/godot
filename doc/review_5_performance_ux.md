# 성능 최적화 및 사용자 경험(UX) 코드 리뷰

**프로젝트:** 0303-renewal (Godot 4 GDScript)  
**리뷰 일자:** 2026-04-14  
**리뷰 범위:** player.gd, Player_ui.gd, poop_coin.gd, Enemy.gd, endflag.gd, floor.gd, player_stats.gd  
**리뷰 관점:** 성능 최적화 / 입력 반응성 / 피드백 시스템 / UI-UX / 씬 전환

---

## 1. 성능 분석

### 1-1. 불필요한 `_process` 콜백 제거

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **HIGH** | **Low** |

**현황:**  
아래 세 파일에서 빈 `_process(delta)` 함수가 남아 있다.

- `Player_ui.gd` -- 매 프레임 빈 함수 호출
- `Enemy.gd` -- 매 프레임 빈 함수 호출
- `player_stats.gd` -- Autoload 싱글턴에서 매 프레임 빈 함수 호출
- `floor.gd` -- 매 프레임 빈 함수 호출

**문제점:**  
Godot는 `_process`가 정의되어 있으면 매 프레임 해당 노드에 대해 콜백을 발생시킨다. 노드 수가 적으면 영향이 미미하지만, Enemy나 floor 인스턴스가 수십~수백 개 배치되는 레벨에서는 불필요한 오버헤드가 누적된다. 특히 `player_stats.gd`는 Autoload로 항상 존재하므로 게임 전체 생명주기 동안 매 프레임 빈 호출이 발생한다.

**개선안:**

```gdscript
# 방법 1: 빈 _process 함수를 완전히 삭제한다 (권장)

# 방법 2: 나중에 _process가 필요할 수 있다면 _ready에서 비활성화
func _ready() -> void:
    set_process(false)  # 필요 시 set_process(true)로 활성화
```

---

### 1-2. 오브젝트 풀링 부재 (poop_coin 스폰)

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **MEDIUM** | **Medium** |

**현황 (`player.gd`):**

```gdscript
func _spawn_poop() -> void:
    var poop = PoopCoin.instantiate()   # 매번 새 인스턴스 생성
    ...
    get_parent().add_child(poop)        # 씬 트리에 추가
```

`poop_coin.gd`에서는 `queue_free()`로 소멸시킨다. 즉, **생성 -> 20초 대기 -> 코인 변환 -> 수집 시 소멸** 사이클이 반복된다.

**문제점:**  
- `instantiate()` + `queue_free()`는 메모리 할당/해제를 반복하며 GC 부하를 유발한다.
- 플레이어가 빠르게 스킬을 반복 사용하면 동시에 다수의 poop_coin 노드가 씬 트리에 존재하게 되고, 각각 Timer 노드를 가지고 있어 리소스가 분산된다.
- 수집하지 않은 코인이 무한히 누적될 수 있다.

**개선안 -- 간이 오브젝트 풀:**

```gdscript
# pool_manager.gd (Autoload 등록)
extends Node

const PoopCoin = preload("res://scenes/poop_coin.tscn")
var _pool: Array[Area2D] = []
const MAX_POOL_SIZE := 20

func get_poop() -> Area2D:
    if _pool.size() > 0:
        var obj = _pool.pop_back()
        obj.reset()          # 상태 초기화 함수 (아래 참조)
        return obj
    return PoopCoin.instantiate()

func release_poop(obj: Area2D) -> void:
    if _pool.size() < MAX_POOL_SIZE:
        obj.get_parent().remove_child(obj)
        _pool.append(obj)
    else:
        obj.queue_free()
```

```gdscript
# poop_coin.gd 에 reset() 함수 추가
func reset() -> void:
    is_coin = false
    sprite.visible = true
    anim_sprite.visible = false
    collision.disabled = true
    timer.stop()
    timer.start()
```

---

### 1-3. 인스턴스 수명 관리 미흡

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **HIGH** | **Low** |

**현황:**  
`poop_coin.gd`의 Timer는 20초 후 코인으로 변환하지만, 플레이어가 코인을 수집하지 않으면 **영원히 씬 트리에 남는다.** 스테이지가 길거나 플레이어가 스킬을 자주 사용하면 수십~수백 개의 코인이 누적될 수 있다.

**개선안:**

```gdscript
# poop_coin.gd -- 코인 변환 후 자동 소멸 타이머 추가
func _on_timer_timeout() -> void:
    is_coin = true
    sprite.visible = false
    anim_sprite.visible = true
    anim_sprite.play("spin")
    collision.disabled = false
    # 코인 상태로 전환 후 15초 뒤 자동 소멸
    var expire_timer := get_tree().create_timer(15.0)
    expire_timer.timeout.connect(_expire)

func _expire() -> void:
    if is_inside_tree():
        # 선택: 페이드아웃 연출 후 소멸
        queue_free()
```

---

## 2. 입력 반응성 및 조작감

### 2-1. 점프 속도가 비정상적으로 낮음

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **HIGH** | **Low** |

**현황:**

```gdscript
@export var jump_force : float = 100
@export var gravity : float = 420
```

`jump_force = 100`, `gravity = 420`이면 점프 정점까지 도달 시간은 약 `100 / 420 = 0.24초`, 최대 높이는 약 `100^2 / (2 * 420) = 11.9 픽셀`이다. 일반적인 2D 플랫포머에서는 jump_force가 200~400 범위가 적절하다. 현재 값은 점프가 거의 눈에 보이지 않을 수준이며, 이동 속도(25)도 매우 느려 조작감이 답답하게 느껴질 수 있다.

> 참고: `_update_jump_force()`에서 점수에 따라 최대 4배까지 증가하지만, 초기 플레이 구간에서의 조작감이 매우 불리하다.

**개선안:**

```gdscript
@export var move_speed : float = 120.0    # 기존 25 -> 체감 이동 가능
@export var gravity : float = 800.0       # 기존 420
@export var jump_force : float = 300.0    # 기존 100
```

> 정확한 값은 타일 크기와 레벨 디자인에 따라 튜닝이 필요하지만, 현재 값은 객관적으로 너무 낮다.

---

### 2-2. 코요테 타임(Coyote Time) 및 점프 버퍼링 부재

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **MEDIUM** | **Medium** |

**현황:**

```gdscript
if Input.is_action_just_pressed("ui_jump") and is_on_floor():
    velocity.y = -jump_force
```

플랫폼 가장자리에서 떨어지는 순간 점프 입력이 무시되고, 착지 직전에 미리 누른 점프도 무시된다. 이는 플랫포머의 대표적인 UX 문제이다.

**개선안:**

```gdscript
var coyote_timer : float = 0.0
var jump_buffer_timer : float = 0.0
const COYOTE_TIME := 0.12       # 바닥을 떠난 후 점프 허용 시간
const JUMP_BUFFER := 0.10       # 착지 전 선입력 허용 시간

func _physics_process(delta):
    var was_on_floor := is_on_floor()

    if not is_on_floor():
        velocity.y += gravity * delta

    # 코요테 타임 관리
    if is_on_floor():
        coyote_timer = COYOTE_TIME
    else:
        coyote_timer -= delta

    # 점프 버퍼 관리
    if Input.is_action_just_pressed("ui_jump"):
        jump_buffer_timer = JUMP_BUFFER
    else:
        jump_buffer_timer -= delta

    # 점프 실행 (코요테 타임 OR 바닥 + 버퍼)
    if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
        velocity.y = -jump_force
        jump_buffer_timer = 0.0
        coyote_timer = 0.0

    move_input = Input.get_axis("ui_left", "ui_right")
    velocity.x = move_input * move_speed

    if move_input != 0:
        sprite.flip_h = move_input < 0

    move_and_slide()
    update_animation()
```

---

### 2-3. 가변 점프 높이 미지원

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **LOW** | **Low** |

**현황:**  
점프 버튼을 짧게 눌러도 길게 눌러도 동일한 높이로 점프한다.

**개선안:**

```gdscript
# 점프 버튼을 떼면 상승 속도를 절반으로 줄여 낮은 점프 가능
if Input.is_action_just_released("ui_jump") and velocity.y < 0:
    velocity.y *= 0.5
```

---

## 3. 피드백 시스템

### 3-1. 피격 시 시각 피드백 부재

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **HIGH** | **Medium** |

**현황 (`player.gd`):**

```gdscript
func take_damage(amount : int):
    health -= amount
    OnUpdateHealth.emit(health)
    if health <= 0:
        call_deferred("game_over")
```

체력이 감소해도 플레이어 캐릭터에 아무런 시각적 변화가 없다. 플레이어는 피격 사실을 UI 숫자 변화로만 인지해야 하며, 이는 액션 게임에서 심각한 UX 결함이다.

**개선안:**

```gdscript
func take_damage(amount: int) -> void:
    health -= amount
    OnUpdateHealth.emit(health)
    _play_hit_feedback()
    if health <= 0:
        call_deferred("game_over")

func _play_hit_feedback() -> void:
    # 1) 스프라이트 깜빡임 (빨간색 플래시)
    sprite.modulate = Color.RED
    await get_tree().create_timer(0.1).timeout
    sprite.modulate = Color.WHITE

    # 2) 화면 흔들림 (카메라가 있는 경우)
    var camera = get_viewport().get_camera_2d()
    if camera:
        var tween = create_tween()
        tween.tween_property(camera, "offset", Vector2(8, 0), 0.05)
        tween.tween_property(camera, "offset", Vector2(-8, 0), 0.05)
        tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

    # 3) 넉백
    var knockback_dir = -1.0 if sprite.flip_h else 1.0
    velocity.x = knockback_dir * 150.0
    velocity.y = -100.0
```

---

### 3-2. 점프력 증가 시 피드백 부재

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **MEDIUM** | **Low** |

**현황:**

```gdscript
func _update_jump_force():
    var multiplier : float = 1.0
    if PlayerStats.score >= 240:
        multiplier = 4.0
    # ... (단계별 증가)
    jump_force = base_jump_force * multiplier
```

점프력이 1.5배, 2배, 3배, 4배로 증가하는 중요한 게임플레이 변화가 있지만, 플레이어에게 어떠한 알림도 제공하지 않는다. 플레이어는 자신의 점프력이 변경되었다는 것을 알 방법이 없다.

**개선안:**

```gdscript
signal OnJumpForceChanged(multiplier: float)

func _update_jump_force():
    var old_multiplier := jump_force / base_jump_force
    var new_multiplier : float = 1.0
    if PlayerStats.score >= 240:
        new_multiplier = 4.0
    elif PlayerStats.score >= 180:
        new_multiplier = 3.0
    elif PlayerStats.score >= 120:
        new_multiplier = 2.0
    elif PlayerStats.score >= 60:
        new_multiplier = 1.5
    jump_force = base_jump_force * new_multiplier

    if new_multiplier > old_multiplier:
        OnJumpForceChanged.emit(new_multiplier)
        _play_powerup_effect()

func _play_powerup_effect() -> void:
    # 파티클, 사운드, UI 팝업 등으로 파워업 연출
    var tween = create_tween()
    tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.15)
    tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)
```

---

### 3-3. 스킬 사용 시 피드백 부재

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **MEDIUM** | **Low** |

**현황:**

```gdscript
if Input.is_action_just_pressed("ui_skill"):
    _spawn_poop()
    print("Skill")       # 디버그 출력만 존재
```

스킬 사용 시 `print()`만 호출되고 게임 내 어떠한 피드백도 없다. `ui_attack`도 마찬가지로 `print("Attack")`만 존재한다.

**개선안:**

```gdscript
if Input.is_action_just_pressed("ui_skill"):
    _spawn_poop()
    _play_skill_animation()
    # TODO: AudioStreamPlayer로 효과음 재생

func _play_skill_animation() -> void:
    # 스킬 전용 애니메이션이 있다면 재생
    # 없다면 스프라이트 이펙트로 대체
    var tween = create_tween()
    tween.tween_property(sprite, "modulate", Color(1, 1, 0.5), 0.1)
    tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
```

---

### 3-4. 디버그 print 문 제거 필요

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **LOW** | **Low** |

**현황:**  
`player.gd`에 `print("Attack")`, `print("Skill")`, `print("Player.gd : ", ...)` 등 디버그용 출력이 릴리즈 코드에 남아 있다. 프레임마다 호출되지는 않지만 빌드 시 콘솔 오염과 미세한 성능 저하를 유발한다.

**개선안:**

```gdscript
# 디버그 출력은 조건부로 처리하거나 완전히 제거
const DEBUG := false

func increase_score(amount: int):
    PlayerStats.score += amount
    OnUpdateScore.emit(PlayerStats.score)
    _update_jump_force()
    if DEBUG:
        print("Player.gd : ", PlayerStats.score)
```

---

## 4. UI/UX 개선점

### 4-1. UI 업데이트 시그널 중복 연결

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **MEDIUM** | **Low** |

**현황 (`Player_ui.gd`):**

```gdscript
Player.OnUpdateHealth.connect(_update_hearts)
Player.OnUpdateHealth.connect(_update_heart_score)
Player.OnUpdateScore.connect(_update_energy)
Player.OnUpdateScore.connect(_update_energy_score)
```

동일 시그널에 2개의 콜백을 각각 연결하고 있다. 기능적으로 문제는 없지만, 하나의 통합 함수로 관리하는 것이 유지보수와 호출 순서 제어에 유리하다.

**개선안:**

```gdscript
func _ready():
    hearts = health_container.get_children()
    energy = energy_container.get_children()
    Player.OnUpdateHealth.connect(_on_health_changed)
    Player.OnUpdateScore.connect(_on_score_changed)
    _on_health_changed(Player.health)
    _on_score_changed(PlayerStats.score)

func _on_health_changed(health: int) -> void:
    _update_hearts(health)
    heart_score_text.text = str(health)

func _on_score_changed(score: int) -> void:
    _update_energy(score)
    energy_score_text.text = str(score)
```

---

### 4-2. hearts 배열과 Label 자식 노드 충돌 가능성

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **HIGH** | **Low** |

**현황:**

```gdscript
hearts = health_container.get_children()
```

`HealthContainer`의 모든 자식을 hearts 배열에 넣고 있다. 그런데 `HeartScoreText` Label도 `HealthContainer`의 자식이므로 이 배열에 포함된다. `_update_hearts()`에서 `hearts[i].visible = i < health`를 실행하면 **Label까지 숨겨지는 버그**가 발생할 수 있다.

**개선안:**

```gdscript
func _ready():
    # Label을 제외한 하트 아이콘만 필터링
    for child in health_container.get_children():
        if child is TextureRect:  # 또는 해당 하트 노드 타입
            hearts.append(child)
    for child in energy_container.get_children():
        if child is TextureRect:
            energy.append(child)
```

또는 하트 아이콘들을 별도의 HBoxContainer로 묶어 Label과 분리하는 구조적 개선이 더 바람직하다.

---

### 4-3. 에너지 UI 확장성 문제

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **MEDIUM** | **Medium** |

**현황:**

```gdscript
func _update_energy(score: int):
    for i in len(energy):
        energy[i].visible = i < score
```

점수가 올라갈수록 보이는 에너지 아이콘이 늘어나는 구조인데, 점수가 에너지 아이콘 개수를 초과하면 더 이상 시각적 변화가 없다. 점수가 240 이상까지 올라가는 시스템에서 아이콘 기반 표시는 비현실적이다.

**개선안:**  
프로그레스바(ProgressBar) 또는 숫자 표시로 전환하거나, 에너지 UI를 현재 점프력 단계(1.0x ~ 4.0x)를 표시하는 게이지로 변경하는 것이 적절하다.

---

## 5. 게임 오버 / 씬 전환 UX

### 5-1. 즉시 씬 전환의 UX 문제

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **HIGH** | **Medium** |

**현황:**

```gdscript
# player.gd
func game_over():
    get_tree().change_scene_to_file(game_over_scene)
```

```gdscript
# endflag.gd
func _on_animation_finished() -> void:
    get_tree().change_scene_to_packed(scene_to_load)
```

체력이 0이 되면 **아무런 연출 없이 즉시** 씬이 전환된다. 플레이어는 자신이 왜 죽었는지 인지할 시간조차 없다. endflag는 애니메이션 후 전환하므로 상대적으로 낫지만, 페이드 효과가 없어 전환이 생경하다.

**개선안:**

```gdscript
# player.gd
func game_over():
    # 입력 비활성화
    set_physics_process(false)

    # 사망 연출
    anim.play("Death")  # 사망 애니메이션이 있다면
    await anim.animation_finished

    # 페이드 아웃
    var tween = create_tween()
    var canvas = get_tree().root.get_node("CanvasModulate")  # 또는 ColorRect
    # 간단한 방법: 화면 전체 ColorRect 페이드
    tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
    await tween.finished

    get_tree().change_scene_to_file(game_over_scene)
```

**전용 화면 전환 매니저 권장:**

```gdscript
# scene_transition.gd (Autoload)
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect  # 전체 화면 검은 사각형

func change_scene(path: String, duration := 0.5) -> void:
    var tween = create_tween()
    tween.tween_property(color_rect, "color:a", 1.0, duration)
    await tween.finished
    get_tree().change_scene_to_file(path)
    tween = create_tween()
    tween.tween_property(color_rect, "color:a", 0.0, duration)
```

---

### 5-2. game_over_scene 경로 하드코딩

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **LOW** | **Low** |

**현황:**

```gdscript
@export var game_over_scene: String = "res://Scenes/level_1.tscn"
```

게임 오버 시 `level_1.tscn`으로 이동하는데, 이것이 게임 오버 화면인지 레벨 재시작인지 의도가 불명확하다. 또한 `@export`로 노출되어 있지만 기본값이 레벨 씬이므로 혼란을 줄 수 있다.

**개선안:**  
- 전용 게임 오버 씬(`game_over.tscn`)을 만들어 결과 표시 + 재시작/메뉴 선택지를 제공한다.
- 또는 레벨 재시작이 의도라면 변수명을 `restart_scene`으로 변경하고 주석을 추가한다.

---

### 5-3. 점수 초기화 누락

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **HIGH** | **Low** |

**현황:**  
`PlayerStats.score`는 Autoload 싱글턴의 변수이다. 게임 오버 또는 스테이지 클리어 후 씬이 전환되어도 **점수가 초기화되지 않는다.** 재시작 시 이전 점수가 그대로 남아 점프력이 비정상적으로 높은 상태로 시작할 수 있다.

**개선안:**

```gdscript
# player_stats.gd
func reset() -> void:
    score = 0

# player.gd 또는 레벨 초기화 스크립트에서
func _ready():
    PlayerStats.reset()
    # ...
```

---

## 6. 무적 시간(i-frame) 부재 분석

| 우선순위 | 구현 난이도 |
|---------|-----------|
| **CRITICAL** | **Medium** |

**현황:**

```gdscript
# Enemy.gd
func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("Player"):
        return
    body.take_damage(1)
```

```gdscript
# player.gd
func take_damage(amount: int):
    health -= amount
    OnUpdateHealth.emit(health)
    if health <= 0:
        call_deferred("game_over")
```

적과의 충돌 판정에 무적 시간이 전혀 없다. 이로 인해 다음과 같은 치명적 UX 문제가 발생한다:

1. **연속 피격:** 적의 Area2D와 플레이어가 겹친 상태에서 물리 프레임마다 `_on_body_entered`가 재발동될 수 있다(특히 플레이어가 적 위에 착지하는 경우). 한 번의 실수로 체력이 순식간에 0이 될 수 있다.
2. **다중 적 동시 피격:** 여러 적이 밀집된 구간에서 모든 적에게 동시에 데미지를 받는다.
3. **플레이어 에이전시 상실:** 피격 후 회복할 기회가 없어 게임이 불공정하게 느껴진다.

**개선안:**

```gdscript
# player.gd
var is_invincible := false
const INVINCIBLE_DURATION := 1.5  # 무적 시간 (초)

func take_damage(amount: int) -> void:
    if is_invincible:
        return

    health -= amount
    OnUpdateHealth.emit(health)
    _play_hit_feedback()

    if health <= 0:
        call_deferred("game_over")
        return

    _start_invincibility()

func _start_invincibility() -> void:
    is_invincible = true

    # 깜빡임 연출로 무적 상태 시각화
    var tween = create_tween()
    var blink_count := int(INVINCIBLE_DURATION / 0.15)
    for i in blink_count:
        tween.tween_property(sprite, "modulate:a", 0.3, 0.075)
        tween.tween_property(sprite, "modulate:a", 1.0, 0.075)
    tween.tween_callback(_end_invincibility)

func _end_invincibility() -> void:
    is_invincible = false
    sprite.modulate.a = 1.0
```

---

## 7. 종합 개선 우선순위 정리

| # | 항목 | 우선순위 | 난이도 | 카테고리 |
|---|------|---------|--------|---------|
| 1 | 무적 시간(i-frame) 구현 | CRITICAL | Medium | 게임플레이 |
| 2 | hearts 배열 Label 포함 버그 | HIGH | Low | UI 버그 |
| 3 | 점수 초기화 누락 | HIGH | Low | 게임 로직 |
| 4 | 빈 `_process` 제거 | HIGH | Low | 성능 |
| 5 | 피격 시각 피드백 | HIGH | Medium | UX |
| 6 | 씬 전환 연출 | HIGH | Medium | UX |
| 7 | 이동/점프 파라미터 조정 | HIGH | Low | 조작감 |
| 8 | 코요테 타임 + 점프 버퍼 | MEDIUM | Medium | 조작감 |
| 9 | 점프력 변경 피드백 | MEDIUM | Low | UX |
| 10 | 스킬 사용 피드백 | MEDIUM | Low | UX |
| 11 | UI 시그널 통합 | MEDIUM | Low | 코드 품질 |
| 12 | 에너지 UI 확장성 | MEDIUM | Medium | UI |
| 13 | 오브젝트 풀링 | MEDIUM | Medium | 성능 |
| 14 | 코인 자동 소멸 | MEDIUM | Low | 성능/인스턴스 관리 |
| 15 | 가변 점프 높이 | LOW | Low | 조작감 |
| 16 | 디버그 print 제거 | LOW | Low | 코드 품질 |
| 17 | game_over_scene 네이밍 | LOW | Low | 가독성 |

---

## 부록: 권장 구현 순서

**Phase 1 -- 즉시 수정 (1~2시간):**  
항목 2, 3, 4, 7, 16 -- 버그 수정 및 단순 파라미터 조정

**Phase 2 -- 핵심 UX (3~4시간):**  
항목 1, 5, 6 -- 무적 시간, 피격 피드백, 씬 전환 연출

**Phase 3 -- 조작감 개선 (2~3시간):**  
항목 8, 9, 10, 15 -- 코요테 타임, 파워업 피드백

**Phase 4 -- 구조 개선 (3~4시간):**  
항목 11, 12, 13, 14, 17 -- UI 리팩터링, 오브젝트 풀링
