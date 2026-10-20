import Foundation

enum TimeFormatting {
    /// "1:05.3" - минуты, секунды и десятые доли.
    static func short(_ ms: Int64) -> String {
        let totalTenths = ms / 100
        let minutes = totalTenths / 600
        let seconds = (totalTenths / 10) % 60
        let tenths = totalTenths % 10
        return "\(minutes):" + String(format: "%02d", seconds) + ".\(tenths)"
    }

    /// "1:05" - для списков.
    static func compact(_ ms: Int64) -> String {
        let totalSeconds = ms / 1000
        return "\(totalSeconds / 60):" + String(format: "%02d", totalSeconds % 60)
    }
}
