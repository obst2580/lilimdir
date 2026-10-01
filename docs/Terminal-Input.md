# 터미널 입력과 Shift+Enter

검증일: 2026-10-02. Codex CLI 0.159.2, Claude Code 2.1.287 기준.

## 원인과 수정

기존 터미널은 Return과 숫자 키패드 Enter에서 Shift 여부와 관계없이 `CR` (`0d`)을 전송했다. Claude Code·Codex는 일반 Enter와 Shift+Enter를 구분할 수 없어 줄바꿈 대신 제출을 실행했다.

수정 후 Shift+Enter는 `CSI 13;2u` (`1b 5b 31 33 3b 32 75`)로 전달한다. CLI가 Shift가 눌린 Enter를 인식해 입력창에 줄바꿈을 넣는다. Shift와 함께 Option·Control을 누르면 해당 조합도 보존한다. Caps Lock·키패드·AppKit의 기능 키 표시는 조합 값에 포함하지 않는다.

- 일반 Enter는 기존 `CR`로 전달해 셸 명령 실행과 프롬프트 제출을 유지한다.
- Return과 숫자 키패드 Enter는 동일하게 처리한다.
- Option+Enter는 `ESC CR`로 전달해 지원하는 CLI의 보조 줄바꿈 키를 사용할 수 있게 한다.
- 입력기에서 문자를 조합 중이면 키 인코딩을 바로 전송하지 않고 기존 네이티브 입력기 처리를 유지한다.
- 프로그램의 키 설정에 따라 동작은 달라질 수 있다. 셸이나 모든 콘솔 프로그램에 줄바꿈 동작을 강제하지 않는다.

CSI-u의 키 번호와 수정 키 표현은 [kitty 키보드 프로토콜](https://sw.kovidgoyal.net/kitty/keyboard-protocol/)을 기준으로 한다. 이번 수정은 Enter 조합 키의 전송이며, 전체 kitty 키보드 프로토콜 협상·키 해제 보고를 구현했다고 주장하지 않는다. Claude Code의 줄바꿈 동작은 [공식 터미널 설정 문서](https://code.claude.com/docs/en/terminal-config#enter-multiline-prompts)에서도 확인할 수 있다.

## 검증

실제 사용자 작업과 분리한 앱과 임시 검사 폴더에서 확인했다. 모델 요청을 제출하지 않고 CLI 입력창에 임시 문구만 작성했다.

| 검사 | 결과 |
| --- | --- |
| 실제 PTY에서 Shift+Return 수신 | `1b 5b 31 33 3b 32 75` 확인 |
| 실제 PTY에서 일반 Return 수신 | 기존 `0d` 확인 |
| 실제 PTY에서 Shift+숫자 키패드 Enter 수신 | Shift+Return과 같은 바이트 확인 |
| 실제 PTY에서 Option+Return 수신 | `1b 0d` 확인 |
| Codex 입력창 | `/status` 입력 후 Shift+Enter와 두 번째 줄 입력. 제출 없이 두 줄이 입력창에 유지됨 |
| Claude Code 입력창 | `/help` 입력 후 Shift+Enter와 두 번째 줄 입력. 제출 없이 두 줄이 입력창에 유지됨 |
| Claude Code Option+Enter | 세 번째 줄을 추가해 제출 없이 입력창에 유지됨 |
| 회귀 검사 | 일반 Enter·Shift 조합·키패드/잠금 표시·Option/Control 조합 인코딩 통과 |
| 기존 검사 | 탐색·즐겨찾기·파일 작업·한글·크기 변경·PTY·터미널 탭·스크롤 검사 통과 |

Claude Code의 기본 실행은 초기화가 지연되어 CLI의 `--safe-mode` 옵션으로 사용자 커스터마이징 없이 입력창을 검증했다. 이 옵션은 해당 검사 실행에만 사용했으며 사용자 설정 파일이나 실제 실행 중인 세션을 변경하지 않았다. 사용자 키 바인딩·tmux/SSH 등 중간 프로그램이 입력을 다시 처리하는 경우는 별도로 검증하지 않았다.

```sh
bash scripts/check.sh
bash scripts/build-app.sh release
```

## 수정 빌드 사용

터미널 작업을 마친 뒤 Lilim을 완전히 종료하고 다시 실행한다. 실행 중인 앱에는 교체한 실행 파일의 키 처리가 자동으로 적용되지 않는다.
