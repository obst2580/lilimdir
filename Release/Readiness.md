# 출시 준비 상태

2026-09-30. 아직 App Store에 업로드하거나 판매하지 않았다.

현재는 개인용으로 직접 사용하면서 개선하는 방향이다. 판매·App Store 출시 준비는 보류하며 아래 내용은 기존 검증 기록으로 보관한다. 소스는 공개 GitHub 저장소에 보관하며, 오픈소스 라이선스는 아직 선택하지 않았다.

초기 목표는 App Store 유료 판매였다. 자체 판매 사이트·결제·라이선스 서버 개발은 범위에서 제외했다. 출시를 다시 검토할 때는 기존 판매 서비스 활용도 비교할 수 있지만, 최종 배포 경로와 판매 서비스는 아직 확정하지 않았다.

| 항목 | 상태 |
| --- | --- |
| Xcode 프로젝트 | 완료: Lilim / Lilim-AppStore 공유 scheme |
| Store 시험 빌드 | Debug 빌드 성공 |
| Store Archive | Release Archive 성공, arm64 + x86_64. 배포 서명 없음 |
| 직접 배포 Archive | Release Archive 성공, arm64 + x86_64. 배포 서명·공증 전 |
| 폴더 권한 | bookmark 저장·복원 구현. 실제 샌드박스 앱에서 폴더 선택·생성·재실행 복원 확인 |
| 개인정보 manifest | 번들에 포함. UserDefaults·파일 시간 API 사유 선언 |
| 기존 회귀 검사 | 파일 작업·한글·화면 크기 변경·PTY·탭 동작 통과 |
| 일반 앱의 폴더 클릭 연동 | 실제 UI에서 한글 하위 폴더를 한 번 클릭해 현재 탭 경로 이동 확인. `pwd` 출력도 선택한 폴더와 일치. 탭 1개 유지 |
| 폴더 심볼릭 링크 | 파일로 잘못 분류되던 문제 수정. 폴더 링크의 클릭·열기가 내부 탐색으로 이어지는 검사, 파일 링크·앱 링크·끊어진 링크 구분 검사 통과 |
| 즐겨찾기 | 폴더/사이드바 우클릭·별·사이드바 +·메뉴 막대 지원. 여러 폴더 추가, 중복 방지, 저장/복원, 제거 및 내부 경로 이동 검사 통과 |
| 내장 터미널의 샌드박스 동작 | 차단 문제 재현: 작업 제어와 사용자 CLI 실행 실패 |
| 판매 문구·지원 페이지 | 스토어 문구와 지원·개인정보 안내 초안 준비. 연락처·공개 URL·최종 지원 범위 확정 필요 |
| 개발자 계정·Team·배포 인증서 | Xcode에 등록된 Apple 계정 없음 확인. 로그인 창 준비. 로컬 유효 서명 ID 0개. 유료 멤버십·Team은 로그인 후 확인 필요 |
| 유료 계약·은행·한국/미국 세금 정보 | 계정 소유자의 처리 필요 |
| TestFlight·심사·판매 | 미진행 |

**재현된 기술 문제**

동일 PTY 코드를 App Sandbox로 서명한 시험 앱에서 실행했다. 사용자에게 허용받지 않은 외부 파일의 접근 거부도 확인해 실제 샌드박스가 적용되었음을 검사했다.

```text
PASS · sandbox login shell and builtin
PASS · sandbox system command
FAIL · controlling terminal and foreground shell tracking
PASS · shell working directory tracking
PASS · parent writes in user-selected folder
PASS · child uses user-selected folder
FAIL · child executes user-selected external tool
```

실제 앱에서도 `zsh: can't set tty pgrp: operation not permitted`가 출력되고 폴더 이동이 대기 상태에 머물렀다. 시스템 명령 실행 성공만으로 일반 터미널 호환성을 판단할 수 없다. 외부 실행 파일 검사는 이 프로젝트의 단순 C 검증 프로그램을 임시 폴더에 만들어 수행했다.

폴더 접근 권한은 사용자 설치 프로그램의 실행 허용과 다르다. 이 제약을 해소하기 위해 샌드박스를 우회하는 외부 helper나 광범위한 임시 예외를 적용하지 않았다. [Apple 파일 접근 문서](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)

App Store의 권한 범위에서 현재 터미널 구현의 차단 원인과 가능한 개선 방법을 확인해야 한다. 핵심 터미널 기능을 임의로 삭제하거나 바꾸지 않는다. 직접 배포 Archive는 이미 수행한 비교 검증 기록이다. 기존 판매 플랫폼을 활용하는 직접 배포도 비교 대상이며, 이 경로를 확정하거나 판매 계정을 생성한 상태는 아니다.

**검사·빌드 명령**

```sh
bash scripts/check.sh
bash scripts/check-sandbox.sh
bash scripts/archive-app.sh store local
bash scripts/archive-app.sh direct local
python3 scripts/preflight-release.py .build/archives/Lilim-AppStore.xcarchive/Products/Applications/LilimStore.app --channel store
```

`check-sandbox.sh`는 현재 작업 제어 검사가 실패하므로 종료 코드 1이 정상적인 재현 결과다. 이를 성공으로 무시하고 제출하지 않는다. 외부 CLI 검사는 다음 명령으로 창을 열고 **이 스크립트가 만든 external-fixture 폴더만** 선택한 뒤 창의 결과와 생성된 `sandbox-results.txt`를 확인한다. 수동 UI 모드의 앱 종료 코드는 자동 판정용이 아니다.

```sh
bash scripts/check-sandbox.sh --choose-folder "$PWD/.build/sandbox-probe/external-fixture"
```

일반 앱은 기존 `bash scripts/build-app.sh release`로 빌드한다. Xcode 프로젝트에 Swift 파일을 추가하면 `python3 scripts/generate-xcode-project.py`로 참조를 갱신한다. Xcode의 전역 개발 도구 설정은 변경하지 않는다.

최종 로컬 Archive를 제출 전 검사에 넣었으며 서명·Team이 없는 상태를 실패로 표시했다. Store Archive는 서명 시 부여되는 sandbox 권한도 아직 포함하지 않는다. 별도로 sandbox 권한을 넣어 서명한 검증 앱에서 터미널 작업 제어 실패를 확인했다. 직접 배포 Archive 역시 Developer ID 서명·Gatekeeper 검사를 통과하기 전 상태다. Archive 생성 성공은 판매 가능한 앱이라는 뜻이 아니다.

최종 Store Archive의 복사본 `.build/ui-check/Lilim Store QA Final.app`에도 ad hoc 서명과 sandbox 권한을 적용했다. 제출 전 검사에서 번들·manifest·서명 유효성·sandbox 권한은 통과했고, 개발자 Team 서명과 sandbox 터미널 회귀 검사는 실패했다. 최신 `codesign`의 기본 출력은 plist XML이 아니므로 검사에서는 `--xml`을 명시해 실제 권한을 읽는다.

`preflight-release.py`는 검사 대상 앱을 수정하지 않으며, Store 검사에서는 `.build/sandbox-probe`에 별도 검증 앱과 테스트 파일을 만든다. 사용자 폴더 허용 후 외부 CLI를 실행하는 수동 검사는 별도로 수행해야 한다.

**소유자가 준비할 항목**

- 기존 Apple Developer 유료 계정 여부와 판매자 계정 유형.
- Xcode 계정 로그인과 사용 가능한 Team. 인증서·비밀번호를 채팅에 전달할 필요는 없다.
- 가입 결제·본인 확인·유료 계약 동의·은행 및 세금 양식.
- 지원 이메일·지원/개인정보 안내의 공개 URL·판매가·판매 국가. 자체 판매 도메인은 필요 항목으로 두지 않는다.
- 최종 앱과 상품 페이지 확인 후 실제 심사 제출·공개 결정.

스토어 상품 페이지와 지원·개인정보 안내는 아직 초안이다. 기술 검증, 배포 서명, 실제 연락처·공개 URL이 준비된 뒤 제출용 내용을 확정한다. 기존 소개 페이지는 로컬 초안으로만 남겨 두며 자체 판매 사이트 구축을 추진하지 않는다.
