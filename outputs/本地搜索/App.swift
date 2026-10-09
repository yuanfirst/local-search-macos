import SwiftUI
import AppKit

struct FileRow: Identifiable {
    let url: URL
    var id: URL { url }
}

@MainActor
final class SearchModel: ObservableObject {
    @Published var selection: URL?
    @Published var showIssues = false
    @Published var root = ""
    @Published var name = ""
    @Published var content = ""
    @Published var running = false
    @Published var status = "输入至少一个搜索条件。"
    @Published var report = SearchReport()
    private var task: Task<Void, Never>?

    func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK { root = panel.url?.path ?? "" }
    }

    func start() {
        let url = searchRoot(for: root)
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &directory),
              directory.boolValue else { status = "文件夹不存在，请重新选择。"; return }
        let query = SearchQuery(root: url, name: name, content: content)
        running = true
        report = SearchReport()
        status = "正在扫描…"
        task = Task {
            let worker = Task.detached {
                search(query, cancelled: { Task.isCancelled }, progress: { count in
                    Task { @MainActor in self.status = "已扫描 \(count) 个文件…" }
                })
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: { worker.cancel() }
            report = result
            running = false
            status = "\(result.cancelled ? "已停止（结果不完整）" : "搜索完成") · 扫描 \(result.scanned) · 找到 \(result.files.count) · 非文本跳过 \(result.binary) · 读取异常 \(result.issues.count)"
        }
    }

    func stop() { task?.cancel() }

    func open(_ url: URL) {
        if !NSWorkspace.shared.open(url) { status = "无法打开文件：\(url.path)" }
    }
}

struct SearchView: View {
    @StateObject private var model = SearchModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("本地搜索").font(.largeTitle.bold())
            Text("在整机或指定文件夹及全部子目录中查找文件").foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("搜索文件夹")
                    TextField("", text: $model.root).accessibilityLabel("搜索文件夹")
                    Button("选择文件夹…", action: model.choose)
                }
                GridRow {
                    Text("文件名包含")
                    TextField("", text: $model.name).accessibilityLabel("文件名包含")
                        .gridCellColumns(2)
                }
                GridRow {
                    Text("文本内容包含")
                    TextField("", text: $model.content).accessibilityLabel("文本内容包含")
                        .gridCellColumns(2)
                }
            }.textFieldStyle(.roundedBorder).disabled(model.running)
            HStack {
                Text("区分大小写 · 按原文匹配 · 两项条件同时满足")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                if model.running { Button("停止", action: model.stop).keyboardShortcut(.cancelAction) }
                Button("开始搜索") { model.selection = nil; model.start() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                    .disabled(model.running || (model.name.isEmpty && model.content.isEmpty))
            }
            Table(model.report.files.map { FileRow(url: $0) }, selection: $model.selection) {
                TableColumn("文件名") { row in
                    Text(row.url.lastPathComponent).help(row.url.lastPathComponent)
                }.width(min: 160, ideal: 220)
                TableColumn("完整路径") { row in Text(row.url.path).help(row.url.path) }
            }
            .overlay {
                if model.report.files.isEmpty {
                    Text(model.running ? "正在搜索，请稍候…" : "暂无结果")
                        .foregroundStyle(.secondary).allowsHitTesting(false)
                }
            }
            HStack {
                Text(model.status).font(.callout).textSelection(.enabled)
                Spacer()
                if !model.report.issues.isEmpty {
                    Button("查看异常") { model.showIssues = true }
                }
            }
            HStack {
                Text("内容支持 TXT、日志、CSV、JSON、代码等纯文本；不解析 Word / PDF。")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("打开") { if let url = model.selection { model.open(url) } }.disabled(model.selection == nil)
                Button("在 Finder 中显示") {
                    if let url = model.selection { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }.disabled(model.selection == nil)
            }
        }
        .padding(24).frame(minWidth: 850, minHeight: 580)
        .background(.regularMaterial)
        .sheet(isPresented: $model.showIssues) {
            VStack(alignment: .leading) {
                Text("未能读取的文件或文件夹").font(.headline)
                ScrollView { Text(model.report.issues.joined(separator: "\n\n")).textSelection(.enabled) }
                Button("关闭") { model.showIssues = false }.keyboardShortcut(.cancelAction)
            }.padding(24).frame(width: 700, height: 420)
        }
    }
}

@main
struct LocalSearchApp: App {
    var body: some Scene {
        WindowGroup("本地搜索") { SearchView() }
            .defaultSize(width: 1000, height: 700)
    }
}
