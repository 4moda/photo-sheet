import Foundation

/// コンパクトカメラのクォーツデート（右下のオレンジ日付焼き込み）の表記。
/// 例: 2026-07-17 → "'26 7 17"（ゼロ埋めしないのが実物の流儀）
enum DateStamp {
    static func text(for date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "''yy M d"
        return formatter
    }()
}
