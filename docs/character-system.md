# 캐릭터와 상호작용 시스템

## 구현 범위

플레이어와 NPC의 공통 기반, 설정·실행 상태 분리, 이동·입력·표현 분리, 행동 잠금, 상호작용 행동 클래스를 구현했습니다. 기존 4/8방향 이동, 대화, 조건부 문 출입, 게시판, 체크포인트를 이 구조로 이전했습니다.

관계 그래프와 신체 상태·시간 진행은 [관계·생활 시스템 가이드](relationship-life-system.md)에 이어서 구현했습니다. 체력·피해·회복·전투 불능과 단기 스태미나, 선택적 전투 컴포넌트는 [전투 기반 가이드](combat-system.md)에 구현했습니다. 파일에 저장하는 슬롯/자동 저장 기능도 아직 없고 JSON으로 변환 가능한 상태 스냅샷을 제공합니다.

## 씬 구성

```text
character.tscn — SchoolCharacter (CharacterBody2D)
├── CollisionShape2D       발밑 충돌
├── Movement               MovementComponent
├── Controller             CharacterController
├── Visual                 CharacterVisual, 임시 도형 표현
├── Needs                  NeedsComponent, 선택적 프로필 연결
├── Health                 HealthComponent
└── Stamina                StaminaComponent, 선택적 프로필 연결

player.tscn — character.tscn 상속
├── Controller             PlayerController로 교체
├── InteractionDetector    주변 대상 선택
└── Camera2D

npc.tscn — character.tscn 상속
├── Controller             AIController로 교체
└── Interaction            InteractionComponent + 행동 Resource

interactable.tscn — StaticBody2D, 사물 전용
├── CollisionShape2D
└── Interaction            동일한 InteractionComponent + 행동 Resource
```

`SchoolPlayer`는 플레이어 역할을 표시하는 얇은 하위 클래스입니다. 공통 이동·잠금은 `SchoolCharacter`에 있으며 대화 컨트롤러도 `SchoolCharacter`를 받습니다. 인물별로 스크립트를 복제하지 않습니다.

## 책임과 소유권

| 클래스 | 책임 |
|---|---|
| `CharacterDefinition` | 공유 가능한 편집 데이터: 이름, 옷 색상, 이동 수치, 초기 최대 체력 |
| `CharacterState` | 인물마다 독립적인 현재 체력, 방향, 활동 상태와 NeedsState |
| `CharacterStateStore` | 캐릭터 ID별 상태 보관, 스냅샷과 복원 |
| `SchoolCharacter` | 공통 물리 본체, 상태 연결, 행동 허용 판단과 잠금 |
| `MovementComponent` | 입력 방향을 4/8방향으로 보정, 가속·감속·충돌 이동 |
| `PlayerController` | 이동 입력 읽기, E/Tab/R/F2 처리 |
| `AIController` | `steer(direction)` / `stop()` 명령을 이동 방향으로 제공 |
| `CharacterVisual` | 외형, 발걸음, 방향과 상호작용 강조 표시 |

`SessionState.characters`가 상태 저장소를 소유합니다. 구역 교체 시 NPC 노드는 사라지지만 상태 객체는 유지됩니다. 새 구역의 NPC는 트리에 들어가기 전에 같은 ID의 상태에 연결됩니다. 노드 경로나 `instance_id`를 저장 키로 사용하지 않습니다.

구역 로딩 전에 캐릭터 ID·정의 누락, 구역 내 중복 ID, 플레이어와의 ID 충돌을 검사합니다. 같은 인물이 다른 구역에 등장한다면 같은 ID를 사용하고, 다른 인물은 다른 ID를 사용합니다. 동적 생성 기능을 추가할 때도 생성자가 이 규칙을 보장해야 합니다.

설정 Resource는 실행 중 변경하지 않습니다. 같은 설정을 쓰는 학생 둘의 체력·방향은 서로 독립적입니다. 이동 방식은 `Movement.mode`, 이동 수치는 `definition`에서 편집합니다.

### 제어와 행동 제한

캐릭터가 컨트롤러의 방향을 받아 이동 컴포넌트를 실행합니다. 이동 컴포넌트에는 `Input` 접근이 없습니다. AI는 명령이 없으면 정지하며, 길 찾기·일정표·자동 순찰은 아직 구현하지 않았습니다.

- `can_act(Action.MOVE / INTERACT / ATTACK / RECOVER)`: 트리 처리 가능 여부, 활동 상태, 해당 행동의 잠금을 확인합니다.
- `acquire_action_lock(mask)`: 특정 행동을 차단하고 고유 토큰을 반환합니다.
- `release_action_lock(token)`: 해당 호출자의 잠금만 해제합니다.
- 기존 `acquire_control_lock()`은 이동·상호작용·공격·복귀를 모두 차단합니다. 대화와 구역 전환이 이 API를 사용합니다.
- `SLEEPING`, `INCAPACITATED`에서는 이동·상호작용을 막습니다. 휴식·수면은 NeedsComponent, 체력 고갈에 따른 전투 불능 진입은 HealthComponent에서 담당합니다.

잠금은 일시적인 실행 상태이므로 저장하지 않습니다. 저장된 활동 상태는 복원합니다.

### 상태 스냅샷

`session.characters.snapshot()`은 `schema_version: 3`과 캐릭터 레코드 배열을 반환합니다. `JSON.stringify()` / `JSON.parse_string()` 왕복 후 새 저장소의 `restore()`로 복원할 수 있습니다.

캐릭터 버전 1·2도 읽을 수 있으며 누락된 신체 상태와 스태미나는 프로필 연결 시 생성합니다. 관계·시간까지 함께 저장할 때는 `session.snapshot()`을 사용하세요. 복원은 빈 저장소에만 허용합니다. 모든 레코드의 ID, 수치, 방향, 활동 상태와 중복 여부를 검증한 뒤 한 번에 적용합니다. 잘못된 레코드로 일부 상태만 바뀌지 않으며, 이미 연결된 캐릭터의 상태 참조를 교체하지 않습니다. 실제 저장 기능을 추가할 때 새 `SessionState`를 복원한 뒤 월드에 전달하세요.

맵 위치, 컨트롤러의 이동 명령, 체크포인트, 이동 모드, 잠금 토큰은 이 스냅샷에 포함하지 않습니다. NPC 위치는 구역 씬의 배치를 사용합니다. 전체 게임 저장 형식은 별도로 확장해야 합니다.

## 상호작용 흐름

```text
PlayerController: E
  → InGame: 요청 수신
  → InteractionDetector: 현재 구역에서 대상 재선택
  → InteractionComponent: 거리·방향·벽·활성 상태·행동 잠금 재검사
  → InteractionAction: 조건 확인 후 개별 행동 실행
  → InteractionContext: 대화 / 구역 이동 / 체크포인트 요청 시그널
  → InGame과 기존 GameCoordinator: 실제 게임 서비스 연결
```

| 구성 | 계약 |
|---|---|
| `InteractionDetector` | 현재 구역으로 탐색 범위 제한, 거리·방향 점수와 Tab 선택, 포커스 정리 |
| `InteractionComponent` | `can_interact(context)`, `get_prompt(context)`, `interact(context)` |
| `InteractionAction` | `can_interact(context)`, 조건부 실행, 하위 클래스의 `_execute(context)` |
| `InteractionContext` | 행동 주체와 세션 상태, 게임 동작 요청 시그널 |

실행 직전에 대상을 다시 검증하므로 포커스가 잡힌 뒤 대상이 비활성화되거나 멀어져도 실행되지 않습니다. 자신과 대상의 충돌체는 광선 검사에서 제외하고 사이의 벽은 검사합니다. 대상 컴포넌트는 충돌 본체 바로 아래에 배치합니다.

`interact()`의 반환값은 행동 요청을 보냈는지를 뜻합니다. 목적지 로딩이나 대화 데이터 처리의 최종 성공은 각 담당 시스템에서 결정합니다.

기본 행동은 다음 세 가지이며, 관계 조건·섭취·휴식 행동은 [생활 시스템 가이드](relationship-life-system.md)에 설명합니다.

- `DialogueInteraction`: `dialogue_id`의 대화 요청. NPC와 게시판이 함께 사용합니다.
- `DoorInteraction`: `destination_zone`, `destination_spawn`으로 이동 요청.
- `CheckpointInteraction`: 행동 주체가 서 있는 위치를 체크포인트로 요청.

모든 행동은 `required_flag`와 `locked_dialogue_id`를 사용할 수 있습니다. 조건 미충족 시 잠금 안내 대화를 요청하고 본래 행동은 실행하지 않습니다. NPC 종류나 사물의 `kind`를 보고 행동을 결정하는 분기는 인게임에서 제거했습니다. 사물의 `kind`는 외형·충돌 편집에만 사용합니다.

행동 Resource에도 사용 횟수나 현재 실행 주체를 저장하지 않습니다. 일회성 여부는 고유한 세션 플래그로 표현하고 사용자 입력·HUD·대화창을 행동 클래스에서 직접 참조하지 않습니다.

## 새 NPC 추가

1. `data/characters/`에 `CharacterDefinition` Resource를 만듭니다. 이름·색상·이동 수치를 설정합니다.
2. 구역에 `scenes/characters/npc.tscn`을 인스턴스로 추가합니다.
3. 루트의 `character_id`를 고유하게 지정하고 `definition`을 연결합니다.
4. 인스턴스의 **Editable Children / 자식 편집 가능**을 켜고 `Interaction`을 선택합니다.
5. `action`에 `DialogueInteraction` Resource를 만들고 `dialogue_id`를 지정합니다. 기본 안내는 “대화하기”이며 이름은 캐릭터 정의에서 가져옵니다.
6. 해당 대사 ID를 대화 JSON에 추가하고 NPC의 발밑 위치와 접근 공간을 확인합니다.

서윤·민재가 이 설정의 예입니다. 기반 `character.tscn`, `npc.tscn`은 ID·정의를 채워 사용하는 템플릿이며, 완성된 월드는 `ingame.tscn`을 F6으로 실행합니다.

게시판·문·깃발은 기존 `interactable.tscn`을 배치하되 이름·안내·행동은 자식 `Interaction`에서 설정합니다. 새로운 행동은 `InteractionAction`을 상속하여 `_execute()`를 구현합니다. 감지기·캐릭터·인게임에 종류별 분기를 추가하지 않습니다. 새로운 게임 서비스가 필요하면 명시적인 연동 경로를 추가하세요.

## 검증

```sh
godot --headless --path gd-game-02 --editor --import --quit
godot --headless --path gd-game-02 --script res://tests/character_test.gd
godot --headless --path gd-game-02 --script res://tests/systems_test.gd
godot --headless --path gd-game-02 --script res://tests/dialogue_test.gd
godot --headless --path gd-game-02 --script res://tests/ui_world_test.gd
```

캐릭터 검사는 상태 독립성·JSON 왕복·불완전 복원 방지, AI 이동과 제동, 중첩/행동별 잠금, 수면·전투 불능 제한, 직접 호출의 거리·방향·벽 검증, 사용자 정의 행동, 월드별 대상 분리, 구역 왕복 시 상태 유지를 확인합니다. 기존 검사는 실제 E 입력과 대화 완료·취소, 잠긴 문, 충돌, 체크포인트, HUD와 일시정지를 계속 검증합니다.
