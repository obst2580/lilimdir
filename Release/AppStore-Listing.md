# Lilim 상품 페이지 초안

작성일: 2026-09-30. 아직 제출·공개하지 않았다. 아래 문구는 현재 일반 배포판을 기준으로 작성했으며, App Store판의 터미널 제한 해결 후 지원 범위에 맞춰 확정한다.

| 항목 | 초안 |
| --- | --- |
| 앱 이름 | Lilim |
| 한국어 부제 | 폴더 탐색과 터미널을 한 창에서 |
| 영어 부제 | Browse files. Work in a shell. |
| 기본 카테고리 | 개발자 도구 |
| 보조 카테고리 | 유틸리티 |
| 판매 방식 | 일회성 유료 다운로드 권장 |
| 판매가·국가 | 미확정 |
| 판매자 명의 | 계정 소유자가 확정 |
| 지원 URL·개인정보 URL | 지원·개인정보 안내의 공개 페이지 URL 입력. 자체 판매 사이트 개발은 하지 않음 |
| Bundle ID 초안 | dev.lilim.workspace.appstore — 계정에 등록하기 전 확정 |

**한국어 설명**

Lilim은 파일 탐색기와 터미널을 하나의 Mac 창에 모은 작업 도구입니다.

컬럼 보기로 폴더를 따라가고, 경로 표시와 검색으로 필요한 파일을 찾으세요. 선택한 폴더에서 터미널 작업을 이어갈 수 있습니다. 새 터미널 탭은 필요할 때 직접 열 수 있습니다.

- 아이콘·목록·컬럼·갤러리 보기
- 즐겨찾기, 최근 방문 폴더, 숨김 파일 표시, 하위 폴더 이름 검색
- 복사·이동·휴지통·이름 변경·복제·새 폴더 생성
- 같은 이름 처리와 파일 작업 실행 취소·다시 실행
- Quick Look, 파일 정보, 태그, 공유, ZIP 압축
- 한글 파일명 표시와 키보드 단축키

지원하는 터미널 명령과 호환 범위는 출시 버전의 지원 페이지에서 확인할 수 있습니다.

**English description**

Lilim brings a file browser and a terminal into one Mac workspace.

Browse folders in columns, follow the path bar, and find files by name. Continue terminal work in the folder you choose, and open additional terminal tabs when you need them.

Browse in icon, list, column, or gallery views. Keep favorite folders close, preview files with Quick Look, and manage files with copy, move, rename, duplicate, and Trash actions. Handle name conflicts and undo supported file operations.

See the support page for the terminal commands and compatibility supported by the release version.

**스크린샷 촬영 구성**

1. 가상의 프로젝트 폴더와 터미널을 함께 보여주는 전체 작업 화면.
2. 3개 이상의 컬럼, 경로 표시, 즐겨찾기로 폴더를 찾는 화면.
3. 파일 선택·복사·이동·이름 충돌 처리를 보여주는 화면.
4. 한글 파일명과 Quick Look·갤러리 화면.
5. 현재 탭에서 폴더를 이동하고 명시적으로 새 탭을 여는 화면.

실제 계정 이름·개인 파일·명령 기록 대신 촬영용 임시 데이터를 사용한다. 현재 샌드박스 터미널 동작은 실패하므로 위 1·5번을 스토어판의 정상 동작으로 촬영·제출할 수 없다.

**심사 설명 초안 — 기술 문제 해결 후 최종 확정**

Lilim is a native macOS file browser with an integrated terminal. On first launch, choose a working folder using the system folder picker. The app stores access to selected folders locally. File management actions are available in the contextual menu and application menus. Additional terminal tabs are opened explicitly using the plus button or the contextual menu. All app-owned terminal sessions are terminated when the app quits.

Describe the verified shell, command execution, network access, and folder permission behavior here before submission. Do not submit while the sandbox terminal checks fail.

연령 등급·암호화 관련 질문은 최종 앱의 실제 기능에 맞춰 답변한다. 개인정보 수집 응답은 현재 앱에 분석 SDK·광고·개발자 서버 전송이 없다는 코드 상태를 기준으로 준비하며, 출시 전 다시 확인한다.
