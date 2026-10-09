import Foundation
import CoreFoundation

@main
struct SearchTests {
    static func main() throws {
        precondition(searchRoot(for: "").path == "/", "目录留空必须搜索整机，而不是当前工作目录")
        precondition(searchRoot(for: "/Users").path == "/Users", "指定目录不得扩大为整机")
        precondition(searchRoot(for: "~").path == NSHomeDirectory(), "保留用户目录简写支持")
        print("通过：目录留空搜索整机，指定目录和用户目录简写保持有效。")
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let nested = root.appendingPathComponent("子目录")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let needle = "tsl76.vfoo.cc:47810"
        let target = nested.appendingPathComponent("中文报告.txt")
        try (String(repeating: "a", count: 65530) + needle).write(to: target, atomically: true, encoding: .utf8)
        try "tsl76XvfooXcc:47810".write(to: root.appendingPathComponent("相似.txt"), atomically: true, encoding: .utf8)
        try ("中文" + needle).write(to: root.appendingPathComponent("宽字符.txt"), atomically: true, encoding: .utf16)
        try Data([0, 1, 2]).write(to: root.appendingPathComponent("binary.dat"))
        try FileManager.default.createSymbolicLink(at: nested.appendingPathComponent("循环"), withDestinationURL: root)
        let names = search(SearchQuery(root: root, name: "报告", content: ""))
        precondition(names.files.count == 1 && names.files[0].lastPathComponent == "中文报告.txt" && names.files[0].deletingLastPathComponent().lastPathComponent == "子目录", "必须递归匹配中文文件名")
        let content = search(SearchQuery(root: root, name: "", content: needle))
        precondition(content.files.count == 2 && content.binary == 1, "精确匹配跨块和 UTF-16；排除相似内容及二进制")
        let both = search(SearchQuery(root: root, name: "报告", content: needle))
        precondition(both.files == names.files, "组合条件必须同时满足")
        let gb = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        try "中文关键字".write(to: root.appendingPathComponent(".隐藏文本"), atomically: true, encoding: gb)
        let chinese = search(SearchQuery(root: root, name: "", content: "中文关键字"))
        precondition(chinese.files.count == 1 && chinese.files[0].lastPathComponent == ".隐藏文本", "隐藏文件和 GB18030 中文必须可搜索")
        do {
            _ = try containsText(root.appendingPathComponent("不存在.txt"), text: needle, cancelled: { false })
            preconditionFailure("读取失败必须抛出错误")
        } catch { print("通过：读取失败不会被当成无匹配。") }
        let stopped = search(SearchQuery(root: root, name: "", content: needle), cancelled: { true })
        precondition(stopped.cancelled && stopped.files.isEmpty, "取消后必须停止扫描")
        print("通过：递归、中文文件名、跨块精确匹配、UTF-16、GB18030、隐藏文件、组合条件、二进制跳过、符号链接循环、取消。")
    }
}
