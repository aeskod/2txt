// MARK: - Services/TemplateEngine.swift
import Foundation

enum TemplateEngine {
    static func render(template: String, directoryName: String, at date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents(in: TimeZone.current, from: date)
        func pad(_ v: Int?, _ w: Int) -> String { String(format: "%0\(w)d", v ?? 0) }
        let map: [String:String] = [
            "{yyyy}": pad(comps.year, 4),
            "{yy}": pad((comps.year ?? 0) % 100, 2),
            "{MM}": pad(comps.month, 2),
            "{dd}": pad(comps.day, 2),
            "{HH}": pad(comps.hour, 2),
            "{mm}": pad(comps.minute, 2),
            "{ss}": pad(comps.second, 2),
            "{dir}": sanitizeName(directoryName)
        ]
        var out = template
        for (k,v) in map { out = out.replacingOccurrences(of: k, with: v) }
        return out.replacingOccurrences(of: "/", with: "-") // guard against illegal '/'
    }

    private static func sanitizeName(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return s.components(separatedBy: bad).joined(separator: "-")
    }
}
