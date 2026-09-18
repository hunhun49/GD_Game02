# 상태 이상 시스템

이동·공격·방어를 막는 효과와 속도를 낮추는 효과, 지속 피해를 같은 캐릭터 컴포넌트에서 관리합니다. 플레이어와 NPC의 공통 `character.tscn`에 `StatusEffects`가 붙어 있습니다.

## 이번에 정한 9종

수치는 플레이 검증을 위한 초기값입니다. `data/status/*.tres`에서 변경합니다.

| 종류 | 초기 지속 시간 | 효과 | 해제 태그 |
|---|---:|---|---|
| 독 | 6초 | 1초마다 독 피해 3 | `poison` |
| 화상 | 6초 | 1초마다 화염 피해 3 | `burn` |
| 출혈 | 6초 | 1초마다 출혈 피해 3 | `bleed` |
| 스턴 | 3초 | 이동·공격·방어·대시·스킬·상호작용 금지 | `stun` |
| 속박 | 3초 | 이동·대시 금지. 제자리 공격·방어·스킬·상호작용 허용 | `root` |
| 공포 | 3초 | 수동 이동·상호작용 허용. 공격·방어·대시·스킬 금지 | `fear` |
| 슬로우 | 3초 | 걷기 속도 60% | `slow` |
| 더움 | 3초 | 공격·대시 동작 속도 75% | `heat` |
| 추움 | 3초 | 공격·대시 동작 속도 75% | `cold` |

공포는 강제 도주가 아닙니다. 더움·추움은 현재 같은 동작 감속 규칙을 공유하며, 환경 온도나 허기·갈증·피로에 자동 연결하지 않았습니다.

### 지속 피해 규칙

- 독·화상·출혈의 주기 처리는 공통입니다. 피해 타입, 표시 키·색상, 치료 태그를 데이터로 구분합니다.
- 적용 즉시 피해를 주지 않고 첫 주기가 지난 뒤부터 줍니다. 만료 시점과 일치하는 마지막 주기까지 적용합니다.
- 낮은 프레임에서도 만료 시간까지의 주기를 처리합니다. 만료 후 추가 피해는 없습니다.
- 이미 걸린 지속 피해는 가드·회피·고정 방어력을 무시합니다. 해당 피해 타입 저항과 `HealthComponent`의 무적은 적용됩니다. 체간 피해는 없습니다.
- 공격자의 ID만 보관하므로 공격자가 사라져도 상태는 유지됩니다. 치명적인 지속 피해는 기존 체력·전투 불능 흐름으로 이어집니다.

### 중복·해제 규칙

- 기존 9종은 `RefreshStatusPolicy`를 사용합니다. 같은 `status_id`를 다시 받으면 기존 설정의 전체 지속 시간으로 갱신합니다. 피해 중첩은 없으며 다음 피해 주기를 미루지 않습니다. 최초 설정·공격자 ID를 유지합니다. 상태별로 중첩·교체 정책을 지정할 수도 있습니다.
- 서로 다른 상태는 함께 유지됩니다. 독·화상·출혈은 각각 피해를 줍니다.
- 능력치별로 같은 보정 그룹 안에서는 가장 강한 감소와 가장 강한 증가를 선택한 뒤 곱합니다. 다른 그룹끼리는 곱하고 최종 배율은 0.1~3으로 제한합니다. 기존 감소 효과의 결과는 같으며, 더움과 추움을 함께 받아도 동작 속도는 75%입니다.
- 스턴을 해제해도 속박이 남아 있으면 이동할 수 없습니다. 상태 해제는 대화·연출 등이 가진 잠금을 해제하지 않습니다.
- `immune_tags`에 등록된 종류는 신규 부여와 갱신을 거부합니다. 이미 걸린 효과를 제거하려면 `cleanse()`를 별도로 호출합니다.
- 사망, 명시적 훈련 초기화, 체크포인트 복귀는 상태를 지웁니다. 단순 전투 이탈은 치료하지 않습니다.

## 클래스 책임

```text
StatusEffectDefinition (Resource)
  효과 목록 + 재적용 정책 + 이름·태그·기간·연출 정보
      ├─ StatusBehavior
      │   ├─ PeriodicDamageStatusBehavior → 주기 피해
      │   ├─ PeriodicHealStatusBehavior → 주기 회복
      │   ├─ ActionLockStatusBehavior → 행동 제한
      │   └─ StatModifierStatusBehavior → 능력치 보정
      └─ StatusReapplyPolicy
          ├─ RefreshStatusPolicy → 시간 갱신
          ├─ StackStatusPolicy → 중첩 수 증가
          └─ ReplaceStatusPolicy → 새 인스턴스로 교체
                  ↓ 적용 시 복제
StatusEffectInstance
  남은 시간·중첩 수·공격자 ID·효과별 실행 상태
                  ↓ 관리
StatusEffectComponent
  부여·조회·면역·만료·치료
      ├─ StatusEffectRunner → 효과 시작·시간 경과·종료
      ├─ StatusModifiers → 행동 제한·능력치 보정 집계
      └─ StatusCharacterBridge → 캐릭터·전투·체력 연결
```


설정 리소스에는 남은 시간 등의 실행 상태를 기록하지 않습니다. 상태 적용 시 데이터를 복제하고, HUD에도 복제된 값 목록만 전달합니다. HUD는 캐릭터 노드를 직접 참조하지 않습니다.

`SchoolCharacter.Action.ATTACK`과 `SKILL` 허가는 독립적으로 확인합니다. `AttackComponent.execution_action`은 실행 중인 공격의 출처를 기록합니다. 따라서 스킬만 막는 침묵은 일반 공격·가드·대시를 취소하지 않습니다. 상태 잠금은 `COMBAT_TICK`과 부활을 막을 수 없습니다. 스턴 중에도 피격 판정과 상태 만료가 계속 동작합니다.

스턴·공포는 지정된 공격·가드·대시와 해당 예약 입력을 중단합니다. 속박은 대시를 중단하고 제자리 공격은 유지합니다. `CombatComponent.interrupt_actions()`가 차단된 행동에 해당하는 실행과 예약 입력만 취소합니다. 침묵으로 상쇄·패링에 따른 강제 회복 시간을 취소할 수 없으며, 취소된 스킬의 쿨다운은 환불하지 않습니다.

### 시간과 속도

- 상태 시간은 실제 게임 실행 초 단위입니다. 학교 시간표의 게임 분이나 동작 속도 배율을 적용하지 않습니다.
- 메뉴 일시정지·대화의 전체 제어 잠금은 상태 시간과 지속 피해를 함께 멈춥니다. 재개할 때 정지한 시간을 몰아서 처리하지 않습니다.
- 스턴·속박·공포 중에도 일시정지 메뉴를 사용할 수 있습니다.
- 더움·추움은 공격의 준비·타격·후딜 및 대시의 이동·회복 타임라인을 느리게 합니다. 대시 총 이동 거리는 유지되고, 현재 회피·돌진 패링 구간도 대시 타임라인을 따릅니다.
- 걷기 속도, 스킬의 별도 쿨다운, 가드의 튕김 시간, 체간 회복, 상태 지속 시간은 동작 감속과 독립적입니다. 입력 예약 시간도 실제 시간으로 계산합니다.
- 슬로우는 걷기 속도만 낮춥니다. 대시를 금지하려면 속박을 사용합니다.

## 새 상태를 추가하는 방법

### 기존 효과 조합으로 만들기

`StatusEffectDefinition` 리소스를 만들고 `behaviors`에 필요한 효과 리소스를 넣습니다. 기존 9종도 모두 이 방식으로 이전했습니다. 관리 컴포넌트에는 독·스턴 등의 종류별 분기가 없습니다.

```gdscript
# 지속 회복과 이동 감속을 함께 주는 상태
var healing := PeriodicHealStatusBehavior.new()
healing.interval = 1.0
healing.amount = 5.0
var slow := StatModifierStatusBehavior.new()
slow.stat = &"movement_speed"
slow.factor = 0.5
var effect := StatusEffectDefinition.new()
effect.status_id = &"restoring_mist"
effect.display_name = "회복 안개"
effect.duration_seconds = 6.0
effect.behaviors = [healing, slow]
character.status_effects().apply_status(effect, source_id)
```

`PeriodicDamageStatusBehavior`와 `PeriodicHealStatusBehavior`의 수치는 중첩 수만큼 곱합니다. 능력치 보정은 기본적으로 중첩 수와 무관하며 `scale_with_stacks`를 켜면 배율을 중첩 수만큼 거듭제곱합니다. 행동 제한은 중첩되어도 같은 행동을 한 번 제한합니다.

현재 실제 플레이에 연결된 능력치 키는 `movement_speed`, `action_speed`입니다. 새로운 키를 집계하는 데 관리 컴포넌트를 수정할 필요는 없지만, 공격력·치유량 같은 새 능력치는 이를 사용하는 전투·회복 코드에서 `stat_multiplier(key)`를 읽어야 동작합니다.

### 중복 적용 정책 선택

| 정책 | 재적용 결과 | 기존 시계·공격자 |
|---|---|---|
| `RefreshStatusPolicy` | 기존 기간으로 갱신 | 유지 |
| `StackStatusPolicy` | 최대 중첩 수까지 증가, 기간 갱신은 선택 | 유지 |
| `ReplaceStatusPolicy` | 기존 종료 후 새 상태 적용 | 새로 시작 |

`ReplaceStatusPolicy.require_higher_priority`를 켜면 `StatusEffectDefinition.priority`가 더 높은 경우에만 교체합니다. 임의의 효과 수치를 보고 강도를 추측하지 않습니다.

모든 정책은 `per_source`를 켜면 공격자별로 독립적인 상태를 유지합니다. 같은 ID의 여러 출처는 `remove_status(id)` 또는 치료 태그로 함께 제거합니다. 공유 중첩은 최초 공격자에게 귀속되므로 출처별 피해 기여가 필요하면 `per_source`를 사용합니다.

동일 ID의 정책과 그룹 기준은 콘텐츠에서 일관되게 설정해야 합니다. 이미 존재하는 인스턴스의 재적용 정책을 따르며, 실행 중 정책을 바꾸려면 기존 상태를 제거하고 다시 부여합니다. 새 정책은 `StatusReapplyPolicy.resolve()`를 구현합니다. 현재 인스턴스를 반환하면 갱신, 새 인스턴스를 반환하면 교체, `null`이면 거부합니다. 정책은 노드 변경·시그널 발행 없이 인스턴스 데이터만 다룹니다.

### 새로운 작동 방식 추가

`StatusBehavior`를 상속한 리소스를 만들고 다음 필요한 지점만 구현합니다.

| 메서드 | 책임 |
|---|---|
| `is_valid()` | 설정 검증 |
| `enter(context)` | 적용 시 실행 상태·구독 초기화 |
| `advance(context, delta)` | 시간 경과 처리 |
| `exit(context)` | 구독·토큰 등 소유 자원 정리 |
| `contribute(modifiers, stacks)` | 행동 제한·능력치 보정을 순수하게 집계 |

설정은 `@export` 속성에 두어 리소스 복제에 포함하고, 타이머·토큰·카운터는 **`context.state`**에 저장합니다. 같은 리소스를 두 캐릭터나 한 상태의 두 슬롯에서 재사용해도 실행 상태가 섞이지 않습니다. `context` 자체를 장기간 보관하지 말고, 콜백은 필요 시 `is_current()`/`is_running()`으로 유효성을 확인합니다.

시작은 목록 순서, 정리는 역순으로 한 번씩 실행합니다. 시간 갱신·중첩은 시작 훅을 다시 호출하지 않습니다. 적용·피해·종료 콜백 안에서 해제나 교체가 발생하면 예전 인스턴스의 나머지 실행을 중단합니다. 교체 중 콜백이 같은 키의 새 상태를 설치한 경우 덮어쓰지 않습니다. `contribute()`에서는 시그널이나 노드를 변경하지 않습니다.

새로운 효과가 기존 게임 기능으로 표현되지 않는다면 연동 서비스도 필요합니다. 예를 들어 보호막·반사는 피해 처리 시점과 소모·재귀 방지 정책을 추가해야 합니다. 이번 리팩터링으로 그 기능까지 구현한 것은 아닙니다. 효과 수명 관리에 새 종류의 조건문을 넣는 대신, 효과 클래스와 필요한 서비스 연결을 추가하는 구조입니다.

## 확장 예제

| 리소스 | 구성 |
|---|---|
| `silence.tres` | `SKILL` 행동만 차단 |
| `regeneration.tres` | 6초간 매초 체력 5 회복 |
| `stacking_poison.tres` | 5중첩까지 증가하는 독, 해독 태그는 기존 독과 공유 |
| `haste.tres` | 6초간 이동 속도 150% |

실험실에서 `Z` 침묵, `C` 재생, `V` 중첩 독, `B` 가속을 부여합니다. `V`를 반복 입력하면 HUD의 중첩 수가 증가합니다. 기본 게임에는 이 단축키가 등록되지 않습니다.

## 공격·스킬에서 부여하기

`AttackDefinition.on_hit_statuses`에 상태 리소스를 넣습니다. `SkillDefinition.attack`이 같은 공격 데이터를 사용하므로 스킬에도 그대로 적용됩니다.

```gdscript
# 예: 기존 공격의 피해 처리 후 화상을 부여
var attack := load("res://data/combat/player_attack.tres").duplicate(true) as AttackDefinition
attack.on_hit_statuses = [load("res://data/status/burn.tres") as StatusEffectDefinition]
character.get_node("Combat").attack = attack
```

- 현재 조건은 **실제 체력 피해가 발생한 적중**입니다. 가드·튕김·회피·상쇄, 전부 저항된 피해, 무적 중인 대상에는 부여하지 않습니다.
- 공격 시작 시 상태 목록도 함께 복제하므로 공유 데이터를 나중에 수정해도 이미 시작한 공격은 변하지 않습니다.
- 다수 적중은 대상별로 적용합니다. 같은 프레임의 피해를 모두 처리한 뒤 상태를 부여하므로, 한쪽의 스턴이 이미 성립한 맞교환을 취소하지 않습니다.
- 피해로 쓰러진 대상은 신규 상태를 받지 않습니다. 초기화로 폐기된 판정은 다음 전투에 상태를 남기지 않습니다.
- 피해 없는 상태 전용 스킬, 가드 관통 상태 부여, 확률·내성 누적은 별도 효과 실행 정책으로 확장할 부분입니다.

## 직접 부여·치료하기

```gdscript
var effects := character.status_effects()
effects.apply_status(load("res://data/status/poison.tres"), attacker_id)
effects.cleanse(&"poison") # 해독제
effects.cleanse(&"burn")   # 화상 치료
effects.cleanse(&"bleed")  # 지혈
effects.remove_status(&"slow")
```

해독제·붕대·화상 연고를 사용하는 [인벤토리](items-inventory-menu.md)에 치료 API를 연결했습니다. 치료 애니메이션은 아직 없습니다. `presentation_key`와 색상을 이용해 이후 독·화상·출혈의 시각 효과를 각각 연결할 수 있습니다.

## 직접 실행

[`status_effect_demo.tscn`](../gd-game-02/scenes/combat/status_effect_demo.tscn)을 열고 **F6**으로 실행합니다. 일반 게임에는 실험실 단축키가 들어가지 않습니다.

- `1` 독 / `2` 화상 / `3` 출혈
- `4` 스턴 / `5` 속박 / `6` 공포
- `7` 슬로우 / `8` 더움 / `9` 추움
- `0` 모든 상태 해제
- 게임 창에 포커스를 둔 상태에서 `F3` 해독 / `F4` 화상 치료 / `F5` 지혈
- HUD에서 적용된 상태와 남은 시간을 확인합니다. 기존 이동·공격·가드·대시·Q 스킬로 제약을 비교합니다.

## 수명과 후속 범위

현재 상태 이상은 **캐릭터 노드의 실행 상태**입니다. 살아 있는 플레이어의 구역 이동에는 유지되지만, 새로 생성되는 NPC나 세이브 복원에는 저장되지 않습니다. 장기 지속 효과를 실제 콘텐츠에 사용하기 전에는 캐릭터 ID 기반 저장·오프스크린 시간 정책을 연결해야 합니다.

범용 스킬 효과 실행기, 투사체, 환경 온도 발생원은 후속 범위입니다. 치료 아이템은 이후 인벤토리 시스템에 연결했습니다. 전투 규칙은 적용됐으며 애니메이션·이펙트는 표시 이벤트에 연결하면 됩니다.

## 검증

```bash
godot --headless --path gd-game-02 --script res://tests/status_effect_test.gd
```

데이터 유효성, 잠금 중첩·해제, 진행 중 공격·대시 취소, 피해 면역·저항·치료, 프레임 간격과 갱신, 동작 감속·입력 예약·쿨다운 분리, 사망·재진입·초기화, 적중 상태 부여, 실제 실험실 HUD·메뉴 연결을 검사합니다. 기존 다수전·전투·대화·생활·관계 검사도 함께 실행합니다.

초기 9종의 상태 검사 87개를 유지하며 `tests/status_extension_test.gd`에서 선택적 행동 중단, 중첩·교체·출처별 정책, 회복·가속 조합, 사용자 정의 효과의 시작·정리와 실행 상태 분리를 추가로 검사합니다.

리팩터링 검증: Godot 4.7.2에서 **13개 검사 모음, 766개 항목 통과, 실패 0건**. 기존 상태 검사 87개와 확장 검사 49개를 포함합니다. 침묵·재생·중첩 독·가속의 실험실 안내 및 HUD 중첩 표시도 실제 렌더링으로 확인했습니다.
