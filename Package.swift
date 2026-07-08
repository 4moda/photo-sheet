// swift-tools-version: 5.9
import PackageDescription

// ローカル (WSL/Linux) と CI (ubuntu) で Domain + 永続化層を高速にビルド・テストするためのパッケージ定義。
// アプリ本体は XcodeGen (project.yml) が生成する Xcode プロジェクトでビルドする（macOS CI のみ）。
//
// ルール: このパッケージに含まれるソース（PhotoSheet/Domain, PhotoSheet/Data/Persistence,
// PhotoSheetTests）は Foundation のみに依存し、Linux でコンパイル可能に保つこと。
// UIKit / SwiftUI / Photos 等に依存するコードは Presentation 層や Data の他ディレクトリに置く。
let package = Package(
    name: "PhotoSheetCore",
    targets: [
        .target(
            name: "PhotoSheetCore",
            path: "PhotoSheet",
            sources: ["Domain", "Data/Persistence"]
        ),
        .testTarget(
            name: "PhotoSheetCoreTests",
            dependencies: ["PhotoSheetCore"],
            path: "PhotoSheetTests"
        )
    ]
)
