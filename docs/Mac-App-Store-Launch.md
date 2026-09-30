# Lilim 유료 Mac App Store 출시 준비

2026-09-30의 최초 조사 기록이다. 이후 Xcode 프로젝트·폴더 권한 복원·개인정보 manifest·Archive를 준비하고 샌드박스 터미널 제한을 실측했다. 최신 상태는 [출시 준비 상태](../Release/Readiness.md)를 확인한다. App Store 계정·계약 상태는 조회하지 않았으며 실제 제출도 하지 않았다.

**지금 가장 먼저 할 일은 샌드박스에서도 파일 탐색과 내장 터미널을 유지할 수 있는지 확인하는 것이다.** 현재 빌드는 App Store 제출용으로 준비되지 않았다. 일회성 유료 판매 자체는 App Store Connect에서 가격을 지정하는 방식으로 시작할 수 있다.

1. **기술적으로 가능한지 먼저 확인한다.**

   Mac App Store 앱은 App Sandbox를 적용해야 한다. 현재 Lilim은 로컬 폴더를 직접 탐색하고, `forkpty`와 `execve`로 사용자 Mac의 로그인 셸을 실행한다. 따라서 기존 동작에 샌드박스 설정만 추가해도 모두 작동한다고 볼 수 없다. [Apple 심사 규정 2.4.5](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility)

   사용자가 시스템 폴더 선택 창으로 허용한 폴더는 하위 항목까지 접근할 수 있으며, 재실행 후 권한을 복원하려면 security-scoped bookmark가 필요하다. 폴더 읽기·쓰기 권한이 해당 위치의 임의 실행 파일을 실행할 권한까지 부여하지는 않는다. Homebrew 도구와 사용자 스크립트를 일반 터미널처럼 실행하는 경험은 별도 검증 대상이다. [샌드박스 파일 접근](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)

   자식 프로세스도 부모의 샌드박스 제한을 받는다. 파일 선택으로 나중에 얻은 접근 권한을 셸·도구에 어떻게 전달할지도 확인해야 한다. 별도 프로세스를 만든다는 이유로 권한 문제가 해결되지는 않는다. [샌드박스 상속](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html)

   | 현재 코드에서 확인한 상태 | 출시 전에 필요한 작업 |
   | --- | --- |
   | 샌드박스 entitlement 파일 없음 | App Store 대상과 필요한 권한 설정, 실제 샌드박스 실행 검증 |
   | 최근 폴더·즐겨찾기를 UserDefaults의 경로 문자열로 저장 | 접근 권한을 보존하는 bookmark 저장·복원·만료 처리 |
   | 홈·문서·데스크탑 등 절대 경로 탐색 | 사용자가 폴더 접근을 허용하는 흐름, 권한 취소 시 복구 안내 |
   | 사용자 셸과 `/usr/bin/zip` 실행 | 셸 초기화 파일, CLI 실행, 압축, 권한 전달을 각각 검증 |
   | 임시 ad hoc 서명으로 `.app` 생성 | 개발자 팀의 App Store 배포 서명·프로비저닝·제출 빌드 구성 |
   | Swift Package와 빌드 스크립트 사용, 활성 개발 도구는 Command Line Tools | 정식 Xcode 앱 대상과 Archive·제출 흐름 준비를 권장 |
   | 현재 산출물은 arm64, 최소 macOS 14 | 판매할 CPU·OS 지원 범위를 결정하고 해당 조합에서 검증 |
   | PrivacyInfo.xcprivacy 없음 | 사용 API와 실제 데이터 처리에 맞는 privacy manifest 작성 |

   코드 근거: [BrowserState.swift](../Sources/Lilim/BrowserState.swift), [PTYBridge.c](../Sources/PTYBridge/PTYBridge.c), [FileOperationService.swift](../Sources/Lilim/FileOperationService.swift), [build-app.sh](../scripts/build-app.sh), [Info.plist](../App/Info.plist).

   Desktop/Documents 접근 목적을 Info.plist에 설명하는 것과 App Sandbox의 파일 접근 허용은 별도로 다뤄야 한다. 심사 통과 가능성은 실제 샌드박스 빌드와 Apple 심사를 거쳐 판단한다.

2. **판매자 명의와 개발자 계정을 준비한다.**

   Apple Developer Program은 연 US$99이며 지역별 실제 청구 금액은 가입 화면에서 확인한다. 개인·개인사업자는 개인 등록이 가능하고 판매자 이름에 법적 실명이 표시된다. 조직 등록은 계약 가능한 법적 실체와 D-U-N-S 번호 등이 필요하며 법적 조직명이 판매자로 표시된다. 앱 이름 Lilim과 판매자 명의는 별개다. [가입 조건과 비용](https://developer.apple.com/programs/enroll/)

   계정 유형은 공개할 판매자 명의와 실제 사업 형태를 기준으로 정한다. 사업자등록만으로 Apple의 조직 계정 자격이 자동으로 생기는 것은 아니다.

3. **유료 앱 계약·은행·세금 정보를 등록한다.**

   App Store Connect의 Business에서 Paid Apps Agreement를 체결하고, 가입한 개인 또는 법인 명의의 정산 계좌와 필요한 세금 양식을 등록한다. 미국 외 개발자에게는 답변에 따라 W-8BEN, W-8BEN-E 등의 양식이 제시될 수 있다. [유료 앱 계약](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/), [은행 정보](https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information/), [세금 정보](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/)

   한국 소재 개발자에 대해 Apple은 사업자등록번호와 최근 90일 이내 발급된 영문 사업자등록증명 등을 요구한다. 비영리 조직 등에는 국세청 고유번호와 증명서 경로가 있다. 계정에 표시되는 한국 세금 양식을 확인하고 해당 서류를 준비한다. 개인 개발자 가입과 유료 정산 서류 준비는 별도 단계다. [한국 세금 서류 요건](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/)

   한국 판매자 정보도 확인·등록해야 한다. 개인 계정과 조직 계정에 따라 이메일, 사업자등록번호, 조직명·전화번호 등 공개 항목이 다르다. EU에도 판매하면 DSA에 따른 trader 상태와 해당 연락처 공개·검증 요건을 함께 처리한다. [한국 판매자 정보](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-korea-compliance-information/), [EU 판매자 정보](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)

4. **판매 방식과 가격을 정한다.**

   현재처럼 로컬에서 동작하는 도구는 **일회성 유료 다운로드로 시작하는 것을 권장한다.** App Store Connect에서 앱 가격을 지정하므로 별도 인앱 결제 기능 없이 판매를 시작할 수 있다. 무료 다운로드 후 기능을 유료로 해제하는 모델을 선택하면 인앱 구입 설정과 StoreKit 구현이 추가된다. [앱 가격 지정](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/), [인앱 구입 준비](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/)

   | 비용·정산 항목 | 기본 조건 |
   | --- | --- |
   | 개발자 프로그램 | 연 US$99 또는 지역별 청구 금액 |
   | 일반 판매 수수료 | 기본 30% |
   | Small Business Program | 자격을 충족하고 등록·승인되면 15% |
   | 실제 입금액 | 수수료 외 적용 세금·조정·환전·은행 비용 등을 반영 |
   | 입금 시기 | 계약·계좌·최소 지급액 등 요건 충족 시 Apple 회계월 말로부터 45일 이내 |

   Small Business Program은 신규 개발자도 신청할 수 있다. 이전 연도의 전체 앱 정산 수익과 관련 개발자 계정 합산액 등 US$100만 기준을 확인하며, 당해 연도 기준을 넘으면 이후 매출에는 표준 수수료가 적용된다. 15%는 자동 적용되지 않는다. [표준 수수료](https://developer.apple.com/programs/whats-included/), [Small Business Program](https://developer.apple.com/app-store/small-business-program/), [가격과 개발자 수익](https://developer.apple.com/help/app-store-connect/reference/pricing-and-availability/app-pricing-and-availability/), [지급 조건](https://developer.apple.com/help/app-store-connect/getting-paid/overview-of-receiving-payments/)

   구체적인 판매가는 지원 범위와 베타 피드백을 보고 정한다. 이 문서에는 경쟁 제품 가격 조사나 예상 수익 계산을 포함하지 않았다.

5. **유료 제품으로서 안정성과 제출 자료를 완성한다.**

   다음 항목을 실제 사용자 환경에서 확인한다. 이는 Lilim에 대한 개발 권장 사항이다.

   - 파일 복사·이동·휴지통·덮어쓰기·실행 취소: 권한 거부, 같은 이름, 읽기 전용 폴더, 외장 디스크, 작업 중 오류에서 데이터 보존.
   - 터미널: 한글 입력·조합형 파일명, 화면 크기 변경, 여러 탭, 셸 종료, `git`·`ssh`·`vim`·`less` 및 지원할 개발 도구의 동작.
   - 권한: 최초 허용, 재실행 후 복원, 권한 취소, 폴더 이름 변경, 볼륨 연결 해제 후 복구.
   - 사용성: 단축키와 메뉴, 키보드 탐색, VoiceOver, 글자 크기·대비, 한국어·영어 지원 범위.
   - 지원 OS·CPU별 설치와 실행, 크래시 진단용 심볼 보관, 고객 문의 대응 경로.

   현재 파일 작업 검사가 통과한 것과 App Store 빌드 검증은 별개다. Finder 기능별 구현 범위는 [Finder-Features.md](Finder-Features.md)에 기록되어 있다.

   제출 자료는 앱 이름·설명·키워드·카테고리, 최종 아이콘, 실제 사용 화면의 스크린샷, 지원 URL, 개인정보처리방침 URL, 개인정보 수집 답변, 연령 등급, 암호화 관련 답변과 심사 메모를 준비한다. 카테고리는 개발자 도구를 우선 검토하고, 설명은 검증된 파일 탐색·터미널 기능을 중심으로 작성한다. [출시 절차](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/overview-of-publishing-your-app-on-the-app-store/), [암호화 관련 제출 정보](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-export-compliance-information-for-beta-builds/)

   개인정보를 수집하지 않는 앱도 개인정보처리방침 URL은 필요하다. “데이터 수집 없음” 응답은 앱과 포함된 SDK의 실제 동작에 맞춰 선택한다. UserDefaults와 파일 시간 정보 등 required reason API 사용 사유도 manifest에서 검토한다. [App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/), [API 사용 사유](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)

   Mac App Store판은 업데이트를 스토어로 배포하며 별도 라이선스 키 입력이나 자체 복제 방지 체계를 요구하지 않는다. 심사 메모에는 폴더 권한 부여 방법과 내장 터미널의 실행·접근 범위를 구체적으로 설명한다. [Mac App Store 심사 규정](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility)

6. **서명된 빌드를 업로드하고 심사 후 판매한다.**

   순서는 다음과 같다.

   1. 정식 Xcode와 개발자 팀을 설정하고 앱 대상·Bundle ID를 확정한다.
   2. 샌드박스 및 배포 서명을 구성하고 제출 가능한 빌드를 만든다.
   3. App Store Connect에 macOS 앱 레코드를 만들고 빌드를 업로드한다.
   4. TestFlight로 베타 검증하고 발견된 문제를 수정한다.
   5. 계약·정산 정보, 판매 국가·가격·세금 카테고리, 앱 소개·개인정보·심사 정보를 완성한다.
   6. 심사에 제출하고 문의·수정 요청에 대응한다.
   7. 승인 후 지정한 방식으로 출시하고 업데이트·고객 지원을 운영한다.

   현재 `codesign --sign -`로 만든 앱은 이 제출 빌드를 대신하지 않는다. Mac App Store 제출과 외부 배포용 Developer ID 공증은 서로 다른 흐름이다. [빌드 업로드](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [배포와 베타 테스트](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

7. **Lilim에 권하는 실행 순서**

   | 순서 | 완료 기준 |
   | --- | --- |
   | 1. 샌드박스 실험 | 허용한 폴더의 파일 작업과 내장 터미널이 지원하려는 범위에서 실제로 동작 |
   | 2. 배포 경로 결정 | 검증 결과를 바탕으로 Store판의 지원 범위 확정 |
   | 3. 판매자 준비 | 계정 명의, 유료 계약, 한국 세금·계좌 서류, 수수료 프로그램 준비 |
   | 4. 제품 안정화 | 권한·파일 작업·터미널 오류 검증과 베타 피드백 반영 |
   | 5. 출시 자료·빌드 | 지원 사이트, 정책, 스크린샷, 서명된 제출 빌드 완성 |
   | 6. 심사·판매 | 승인, 가격·국가·출시 시점 확정, 고객 지원 운영 |

   샌드박스에서 핵심 터미널 경험을 유지하기 어렵다면 **공식 사이트에서 직접 판매하는 경로도 비교할 가치가 있다.** 외부 배포는 Developer ID 서명·Hardened Runtime·공증을 준비하고 결제·업데이트·라이선스 운영을 별도로 마련한다. 이 경우에도 macOS의 파일 보호와 사용자 권한 처리는 필요하다. [외부 배포 서명](https://developer.apple.com/developer-id/), [공증 요건](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

   이 대안은 현재 기능을 유지할 수 있는 배포 경로를 비교하자는 권고다. 이 정리 작업에서는 앱의 기능이나 배포 방식을 변경하지 않았다.
