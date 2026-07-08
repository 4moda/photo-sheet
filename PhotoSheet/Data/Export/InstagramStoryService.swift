import UIKit

/// Instagram Story への直接共有。
/// 現在の Meta の仕様では `source_application` に Meta developers で発行した App ID が必要なため、
/// 未設定（nil）の間はボタン自体を出さず、システム共有シート経由での Instagram 共有にフォールバックする。
enum InstagramStoryService {
    /// Meta developers で発行した App ID（取得後に設定する）
    static let metaAppID: String? = nil

    @MainActor
    static var isAvailable: Bool {
        guard metaAppID != nil, let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    @MainActor
    static func share(pngData: Data) {
        guard let appID = metaAppID,
              let url = URL(string: "instagram-stories://share?source_application=\(appID)") else {
            return
        }
        let items: [String: Any] = ["com.instagram.sharedSticker.backgroundImage": pngData]
        let options: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(300)
        ]
        UIPasteboard.general.setItems([items], options: options)
        UIApplication.shared.open(url)
    }
}
