# Planote – iOS 26 Liquid Glass UI

手書きメモからスケジュールを抽出するアプリ「Planote」のSwiftUIプロトタイプです。  
iOS 26の**Liquid Glass**デザイン言語をベースに、ブルーテーマで設計されています。

## 画面構成

| 画面 | ファイル | 概要 |
|------|----------|------|
| ホーム | `HomeView.swift` | 今日の予定一覧、クイックアクション |
| スキャン | `ScanView.swift` | カメラビューファインダー、シャッターボタン |
| 確認 | `ReviewView.swift` | OCR結果の確認・選択 |
| カレンダー | `CalendarView.swift` | 月間カレンダー、予定一覧 |

## セットアップ方法

### 方法 A: XcodeGen を使う（推奨）

```bash
# XcodeGen がなければインストール
brew install xcodegen

# プロジェクトルートで実行
cd Planote
xcodegen generate

# Xcode で開く
open Planote.xcodeproj
```

### 方法 B: Xcode で手動作成

1. Xcode を開き **File → New → Project** を選択
2. **iOS → App** テンプレートを選択
3. 以下を設定:
   - Product Name: `Planote`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Minimum Deployment: **iOS 17.0**
4. プロジェクトが作成されたら、自動生成された `ContentView.swift` と `PlanoteApp.swift` を削除
5. `Planote/` フォルダ内の全ファイルをプロジェクトにドラッグ&ドロップ
6. `App/PlanoteApp.swift` がアプリのエントリポイントになっていることを確認

## プロジェクト構成

```
Planote/
├── project.yml              ← XcodeGen 設定
├── README.md
└── Planote/
    ├── App/
    │   └── PlanoteApp.swift          ← @main エントリポイント
    ├── Views/
    │   ├── ContentView.swift         ← タブ切替 + Floating Tab Bar
    │   ├── HomeView.swift
    │   ├── ScanView.swift
    │   ├── ReviewView.swift
    │   └── CalendarView.swift
    ├── Components/
    │   └── Components.swift          ← 再利用コンポーネント群
    ├── Models/
    │   └── ScheduleItem.swift        ← データモデル + サンプルデータ
    ├── Theme/
    │   └── PlanoteTheme.swift        ← カラー定義 + Glass Effect
    ├── Assets.xcassets/
    └── Preview Content/
```

## iOS 26 ネイティブ Liquid Glass への移行

iOS 26 SDK (Xcode 17+) が利用可能になったら、`PlanoteTheme.swift` 内の
カスタム `.glassBackground()` モディファイアを SwiftUI ネイティブの
`.glassEffect()` に置き換えられます:

```swift
// Before (iOS 17 互換)
.glassBackground()

// After (iOS 26+)
.glassEffect(.regular)
.glassEffect(.regular.interactive)  // インタラクティブ
```

## ライト/ダークモード

すべてのカラーは `Color(light:dark:)` イニシャライザで定義されており、
システムのアピアランス設定に自動的に追従します。

## 動作要件

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+
