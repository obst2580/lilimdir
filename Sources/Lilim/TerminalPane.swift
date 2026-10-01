import SwiftUI

struct TerminalPane: View {
    @Bindable var terminals: TerminalStore
    @Bindable var browser: BrowserState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "terminal").foregroundStyle(Theme.terminalAccent)
                Text("터미널").font(.system(size: 12, weight: .medium))
                Spacer()
                Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(Theme.terminalAccent)
                Text("현재 탭에서 이동").font(.system(size: 10)).foregroundStyle(.secondary)
                Button("새 터미널 탭", systemImage: "plus") {
                    terminals.newSession(directory: browser.currentDirectory)
                }.buttonStyle(.borderless).labelStyle(.iconOnly).foregroundStyle(Theme.terminalAccent)
                    .help("새 터미널 · ⌘T")
            }.padding(.horizontal, 16).padding(.vertical, 13)
            Divider().overlay(.white.opacity(0.04))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(terminals.sessions) { session in
                        HStack(spacing: 7) {
                            Button {
                                terminals.selectedID = session.id
                                session.updateDirectory()
                                browser.navigate(to: session.pendingDirectory ?? session.currentDirectory)
                                session.focus()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill").font(.system(size: 5))
                                        .foregroundStyle(session.isRunning ? Theme.terminalAccent : .secondary)
                                    Text(session.currentDirectory.lastPathComponent.isEmpty ? "/" : session.currentDirectory.lastPathComponent)
                                        .font(.system(size: 11)).lineLimit(1)
                                }
                            }.buttonStyle(.plain).help(session.currentDirectory.path)
                            Button("세션 닫기", systemImage: "xmark") {
                                if session.isRunning { terminals.pendingClose = session.id }
                                else { terminals.close(session.id) }
                            }
                            .font(.system(size: 8)).buttonStyle(.plain).labelStyle(.iconOnly).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .background(session.id == terminals.selectedID ? Theme.terminalAccent.opacity(0.13) : .clear,
                                    in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(session.id == terminals.selectedID ? Theme.terminalAccent.opacity(0.35) : .clear, lineWidth: 1)
                        }
                    }
                }.padding(6)
            }
            Divider().overlay(.white.opacity(0.04))
            if let session = terminals.active {
                HStack(spacing: 6) {
                    Image(systemName: "folder").font(.system(size: 10)).foregroundStyle(Theme.terminalAccent)
                    Text(PathUtilities.displayPath(session.currentDirectory))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if session.currentDirectory.path != browser.currentDirectory.path {
                        Button("탐색기를 이 경로로 이동", systemImage: "arrow.left.to.line") {
                            browser.navigate(to: session.currentDirectory)
                        }.buttonStyle(.plain).labelStyle(.iconOnly).help("탐색기를 터미널의 작업 경로로 이동")
                    }
                    Button("터미널에 포커스", systemImage: "cursorarrow.click", action: session.focus)
                        .buttonStyle(.plain).labelStyle(.iconOnly).help("터미널에 포커스 · ⌘↩")
                }.padding(.horizontal, 16).padding(.vertical, 9)
                TerminalSurface(session: session).id(session.id)
                    .onChange(of: session.fontSize) { session.hostView.needsLayout = true }
                HStack {
                    Text(session.navigationError ?? session.exitMessage ?? session.pendingDirectory.map {
                        "\($0.lastPathComponent)로 이동 대기 중"
                    } ?? "\(ProcessInfo.processInfo.environment["SHELL"].map { URL(fileURLWithPath: $0).lastPathComponent } ?? "zsh") · 로그인 셸")
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if session.applicationScrollActive {
                        Label("프로그램 내부 스크롤", systemImage: "arrow.up.arrow.down")
                            .foregroundStyle(Theme.terminalAccent)
                            .help("오른쪽 위·아래 버튼으로 이동합니다. 프로그램이 전체 기록 길이와 현재 위치를 제공하지 않아 위치 막대는 표시할 수 없습니다.")
                    } else {
                        Text("⌘↩ 터미널 포커스")
                    }
                }.font(.system(size: 10)).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.terminalSecondary)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "terminal").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text("이 폴더에서 시작하세요").font(.system(size: 15, weight: .medium))
                    Button("터미널 열기") { terminals.newSession(directory: browser.currentDirectory) }
                        .buttonStyle(.bordered)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Theme.terminalText).background(Theme.terminal)
        .tint(Theme.terminalAccent)
        .environment(\.colorScheme, .dark)
        .onAppear { terminals.navigate(directory: browser.currentDirectory) }
        .onChange(of: browser.currentDirectory) { terminals.navigate(directory: browser.currentDirectory) }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                for session in terminals.sessions where session.id == terminals.selectedID || session.pendingDirectory != nil {
                    session.updateDirectory()
                }
            }
        }
        .alert("터미널 세션을 닫을까요?", isPresented: Binding(
            get: { terminals.pendingClose != nil }, set: { if !$0 { terminals.pendingClose = nil } }
        )) {
            Button("취소", role: .cancel) { terminals.pendingClose = nil }
            Button("세션 닫기", role: .destructive) { if let id = terminals.pendingClose { terminals.close(id) } }
        } message: { Text("이 세션의 셸과 실행 중인 작업이 종료됩니다.") }
    }
}
