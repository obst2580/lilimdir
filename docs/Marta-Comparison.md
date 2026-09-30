# Marta와 현재 앱 비교

검토일: 2026-09-30, 한국 시간. 우리 앱의 실행 이름은 아직 Lilim이며 FindTerm은 이름 후보다.

Marta의 공식 사이트·기능별 문서·공식 화면 예시와 우리 앱의 실제 Swift/C 구현을 비교했다. Marta를 설치하거나 실행한 비교 시험은 수행하지 않았다. 기능 설명과 화면 구성은 확인했지만 실행 중인 명령, 한글 입력기, TUI 호환성, 대용량 파일 처리의 실제 결과는 비교하지 않았다. 공식 다운로드 페이지에 표시된 버전은 0.8.2 beta다. 문서에 없는 기능은 없다고 단정하지 않는다.

핵심 판단: 파일 관리자와 내장 터미널을 결합하고 경로를 연동하는 중심 기능은 크게 겹친다. 화면의 작업 방식은 다르며, 현재 우리 앱의 고급 파일 관리 기능은 Marta보다 범위가 좁다. 기능 동일성의 객관적인 분모가 없으므로 동일률을 숫자로 표시하지 않는다.

| 항목 | Marta 공식 설명 | 현재 우리 앱 | 판단 |
| --- | --- | --- | --- |
| 기본 화면 | 좌우 두 파일 탐색 패널. 원본/목적지를 함께 보며 복사·이동 | 위치 사이드바 + 파일 탐색기 + 오른쪽 터미널. 하나의 탐색기 | 작업 구성은 다름. [기본 구성](https://marta.sh/docs/) |
| 내장 터미널 | etty, 각 탐색 패널에 PTY 세션. 상태줄 아래에 표시하고 숨길 수 있으며 숨겨도 셸 실행 유지 | 오른쪽에 터미널 패널. 독립된 터미널 탭별 PTY/셸 유지 | 중심 기능 겹침. 세션을 배치·선택하는 UI는 다름. [터미널](https://marta.sh/docs/advanced/terminal/) |
| 탐색기 → 터미널 | 기본으로 경로 동기화 | 폴더 진입 시 활성 터미널 탭의 셸에 cd. 셸 변수·출력 유지 | 같은 목적. 기존 세션 연동을 우리만의 기능으로 주장하기 어려움. [터미널](https://marta.sh/docs/advanced/terminal/) |
| 터미널 → 탐색기 | 기본으로 자동 동기화. 중첩 셸·SSH는 예외로 명시 | 셸 작업 경로를 표시하고 화살표 버튼을 눌러 탐색기 이동 | Marta는 자동, 현재 우리는 사용자 동작으로 반영. [터미널](https://marta.sh/docs/advanced/terminal/) |
| 폴더 진입 | 기본 설명은 Return/더블클릭 | 일반 클릭 한 번으로 진입, 계층 컬럼 확장 및 활성 터미널 이동 | 기본 조작 다름. Marta의 모든 사용자 설정에서 한 번 클릭이 불가능하다는 주장은 아님. [탐색](https://marta.sh/docs/navigation/base/) |
| 컬럼 보기 | Table 또는 1/2/3열 목록. 공식 예시에서 같은 Library 폴더 항목을 두 열로 배치 | 각각 다른 부모/자식 폴더를 옆 컬럼에 펼침. 깊이 제한 없이 확장 | 이름이 비슷하지만 의미가 다름. [설명과 화면](https://marta.sh/docs/core/display-modes/) |
| 보기 방식 | 상세 Table, 다중 열 목록 | 아이콘·목록·계층 컬럼·갤러리 | 표시 방식 다름. [보기](https://marta.sh/docs/core/display-modes/) |
| 현재 위치/새 탭 | 같은 패널·다른 패널·새 탭·백그라운드 탭·새 창을 구분하는 액션 | 일반 폴더 클릭은 현재 터미널 탭. +/⌘T/우클릭으로 새 터미널 탭 | 명시적 새 탭 자체는 고유 기능이 아님. Marta의 탐색 탭과 우리 터미널 탭은 대상이 다름. [열기 모드](https://marta.sh/docs/configuration/hotkeys/) |
| 즐겨찾기 | 액션 메뉴로 접근. 숫자 선택, 사용자 이름·그룹·구분선은 텍스트 설정 | 상시 사이드바·별·우클릭·폴더 선택 +·메뉴 막대. 목록 저장, 중복 방지. 그룹/사용자 별칭/순서 편집 없음 | 목적은 같고 관리 UI가 다름. [즐겨찾기](https://marta.sh/docs/navigation/favorites/) |
| 최근 위치 | 탐색 탭별 기록, 탭을 닫으면 폐기 | 앱 공통 최근 위치를 저장하고 재실행 후 복원 | 기록의 수명과 범위 다름. [최근 위치](https://marta.sh/docs/navigation/recent/) |
| 경로/기본 파일 작업 | 경로 표시, 복사·이동·이름 변경·복제·휴지통·새 파일/폴더 | 같은 종류의 작업 제공. 목적지 선택, 클립보드와 드래그 사용 | 상당히 겹침. 두 파일 패널 사이 바로 복사는 우리 앱에 없음. [작업](https://marta.sh/docs/core/file-operations/) |
| 미리보기/정보 | Quick Look과 Finder Get Info 연결 | Quick Look, 갤러리 미리보기, 자체 정보 창과 권한·잠금 편집 | 일부 겹침, 정보 창 구현은 다름. [탐색](https://marta.sh/docs/navigation/base/) |

## 현재 Marta의 범위가 더 넓은 항목

| 기능 | Marta | 현재 우리 앱 |
| --- | --- | --- |
| 검색 | Spotlight 기반 전역/현재 위치 검색. 파일 종류·내용·메타데이터 조건, 경로 완성. [Look Up](https://marta.sh/docs/actions/lookup/) | 현재 폴더와 하위의 이름 부분 일치. 25,000개 조사/200개 결과 한도. 일부 개발 폴더와 링크 내부 제외 |
| 압축 파일 | ZIP 읽기/쓰기 및 여러 형식 읽기. 압축 파일을 폴더처럼 탐색하고 중첩 ZIP 수정. [압축](https://marta.sh/docs/advanced/archive/) | ZIP 생성. 열기/압축 해제는 연결된 외부 앱 사용. 내부 가상 파일 시스템 없음 |
| 작업 대기열 | 창 사이 공통 대기열, 작업별 진행 상태·일시정지·중단. [대기열](https://marta.sh/docs/core/operation-queue/) | 한 번에 한 작업, 항목 사이 취소. 바이트 진행률·일시정지·여러 작업 대기열 없음 |
| 디스크 분석 | 하위 폴더 용량 계산 후 가상 탭에 크기순 표시. [분석](https://marta.sh/docs/actions/disk-usage/) | 선택 항목의 정보/폴더 내 항목 수. 비교 가능한 전체 디스크 분석 화면 없음 |
| 하위 파일 펼치기 | 하위 계층을 하나의 가상 목록으로 표시. [Flatten](https://marta.sh/docs/actions/flatten/) | 재귀 검색 결과는 있지만 별도의 Flatten 탐색 모드 없음 |
| 사용자 설정 | Marco 텍스트 편집으로 설정, 단축키·테마·폰트 변경. [설정](https://marta.sh/docs/configuration/editor/) | 보기·정렬 저장, 사이드바 토글, 터미널 글자 크기. 설정 편집기/키 재지정/테마 선택 없음 |
| 확장 | Lua API, 사용자 액션, 외부 앱/CLI 실행 Gadgets. [Gadgets](https://marta.sh/docs/advanced/gadgets/), [공식 소개](https://marta.sh/) | 일반 셸 CLI 실행과 파일 기본 앱/공유 연결. 플러그인·등록 액션 시스템 없음 |
| 여러 탐색 창 | 여러 창과 탐색 탭. [공식 소개](https://marta.sh/) | 하나의 작업 창, 터미널 탭 지원 |

## 현재 증거로 단정할 수 없는 사항

- Marta가 우리와 같은 방식으로 실행 중인 프로그램에 cd 입력을 피하는지, 작업 종료 후 마지막 선택 폴더로 이동을 대기하는지: 공식 설명만으로 확인하지 못했다. 우리 구현은 PTY의 foreground process group을 확인하고 이동을 대기한다.
- Marta의 셸 환경변수 보존, 각 탐색 탭과 PTY의 정확한 생성/종료 관계: 세션 유지·경로 동기화는 문서에 있지만 우리와 같은 조건의 실행 검사는 하지 않았다.
- 한글 조합/분해형 폴더명, emoji, TUI, 창 크기 변경, 처리 속도·안정성: 두 앱의 같은 조건 실행 비교가 필요하다. 우리 터미널도 모든 VT/xterm 동작을 구현한 상태가 아니다.
- 실행 취소 범위와 복구 보장: 우리는 파일 작업별 역작업을 구현했다. 확인한 Marta 문서에서 같은 범위의 보장 여부를 확인하지 못했으므로 차별점으로 확정하지 않는다.
- Marta에 Finder식 계층 컬럼이 추가 설정/확장으로 가능한지: 확인한 기본 보기 설명은 Table/여러 열 목록이다. 공식 범위 밖을 추측하지 않는다.

## 제품 판단

“폴더 탐색 + 내장 터미널 + 경로 연동”이라는 설명만으로는 Marta와 구분하기 어렵다. 실제로 구분되는 현재 작업 흐름은 Finder식 계층 컬럼, 위치를 상시 보여주는 사이드바, 한 번 클릭으로 오른쪽 활성 터미널을 이동하는 조합이다. “현재 셸 유지”, “즐겨찾기”, “명시적 새 탭”은 각각 이미 겹치는 개념이다.

따라서 유료 제품의 방향은 이 화면이 Finder에 익숙한 사용자에게 얼마나 쉽게 이해되고, 파일 탐색에서 명령 실행까지 얼마나 적은 조작으로 이어지는지 검증하는 것이다. 단순함은 설계 목표이며, 실제 사용성 우위나 판매 가능성이 검증된 것은 아니다. 공식 [다운로드 안내](https://marta.sh/download/)에는 공개 beta 다운로드와 Patreon 후원이 표시돼 있다. 현재 안내만으로 향후 가격이나 개발 중단 여부를 추정하지 않는다.

## 우리 앱의 구현 근거

- `Sources/Lilim/WorkspaceView.swift`, `ExplorerView.swift`: 세 패널과 부모/자식 컬럼, 보기 방식.
- `BrowserFileActions.swift`, `FileRowHostView.swift`: 일반 클릭 탐색, 수정 키로 다중 선택.
- `TerminalPane.swift`, `TerminalStore.swift`, `TerminalSession.swift`, `PTYProcess.swift`: 활성 탭 경로 변경, 역방향 이동 버튼, 셸 유지, foreground 검사.
- `BrowserState.swift`, `SidebarView.swift`, `WorkspaceCommands.swift`: 즐겨찾기 저장/복원과 접근 UI, 최근 기록.
- `DirectoryService.swift`: 재귀 이름 검색, 조사/결과 한도.
- `FileOperations.swift`, `FileOperationService.swift`: 직렬 작업·취소·역작업 기록.
- `docs/Finder-Features.md`, `Tests/Checks.swift`, `Tests/FileOperationChecks.swift`: 현재 범위와 이전 회귀 검사. 이번 검토에서는 앱 소스를 변경하거나 검사를 다시 실행하지 않았다.
