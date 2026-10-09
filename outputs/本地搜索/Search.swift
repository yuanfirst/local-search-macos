import Foundation
import CoreFoundation

struct SearchQuery {
    let root: URL
    let name: String
    let content: String
}

struct SearchReport {
    var files: [URL] = []
    var issues: [String] = []
    var scanned = 0
    var binary = 0
    var cancelled = false
}

/// 未指定目录时从整机根目录开始；指定目录时保留路径和波浪号展开规则。
func searchRoot(for path: String) -> URL {
    URL(fileURLWithPath: path.isEmpty ? "/" : (path as NSString).expandingTildeInPath)
}

/// 递归搜索普通文件；不跟随符号链接，避免循环和越出指定目录。
func search(_ query: SearchQuery, cancelled: () -> Bool = { false },
            progress: (Int) -> Void = { _ in }) -> SearchReport {
    var report = SearchReport()
    let manager = FileManager.default
    guard let walker = manager.enumerator(at: query.root,
        includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
        options: [], errorHandler: { url, error in
            report.issues.append("\(url.path)：\(error.localizedDescription)")
            return true
        }) else {
        report.issues.append("无法读取目录：\(query.root.path)")
        return report
    }
    for case let url as URL in walker {
        if cancelled() { report.cancelled = true; break }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true else { continue }
            report.scanned += 1
            if report.scanned % 100 == 0 { progress(report.scanned) }
            guard query.name.isEmpty || url.lastPathComponent.contains(query.name) else { continue }
            if !query.content.isEmpty {
                let match = try containsText(url, text: query.content, cancelled: cancelled)
                if match == nil { report.binary += 1 }
                guard match == true else { continue }
            }
            report.files.append(url)
        } catch {
            report.issues.append("\(url.path)：\(error.localizedDescription)")
        }
    }
    report.cancelled = report.cancelled || cancelled()
    return report
}

/// 分块匹配 UTF-8、GB18030 和 UTF-16 文本，保留块边界以防漏掉跨块关键词。
func containsText(_ url: URL, text: String, cancelled: () -> Bool) throws -> Bool? {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let gb = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    let encodings: [String.Encoding] = [.utf8, gb, .utf16LittleEndian, .utf16BigEndian]
    var patterns = encodings.compactMap { text.data(using: $0) }
    var tail = Data()
    var first = true
    while !cancelled() {
        guard let block = try handle.read(upToCount: 65536), !block.isEmpty else { return false }
        if first {
            first = false
            let bytes = Array(block.prefix(4096))
            let little = bytes.starts(with: [255, 254])
            let big = bytes.starts(with: [254, 255])
            if little || big {
                patterns = [text.data(using: little ? .utf16LittleEndian : .utf16BigEndian)!]
            } else if bytes.contains(0) {
                return nil
            } else {
                patterns = [.utf8, gb].compactMap { text.data(using: $0) }
            }
        }
        tail.append(block)
        if patterns.contains(where: { tail.range(of: $0) != nil }) { return true }
        let overlap = max(0, (patterns.map(\.count).max() ?? 1) - 1)
        tail = Data(tail.suffix(overlap))
    }
    return false
}
