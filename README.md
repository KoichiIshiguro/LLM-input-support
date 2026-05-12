# LLMime

**どこでも、すぐに、AI の力を借りる。**

LLMime は macOS のシステム全体で動作する AI 入力支援ツールです。ホットキー一発で軽量なポップアップが現れ、テキストの書き換え・翻訳・要約・自由生成をその場で行い、結果をカーソル位置に直接挿入します。

## ダウンロード

[**LLMime.zip (macOS)**](https://github.com/KoichiIshiguro/LLM-input-support/releases/latest/download/LLMime.zip) — 最新リリースをダウンロード

> 展開して `LLMime.app` をアプリケーションフォルダに移動し、起動してください。初回起動時に権限の許可と Gemini API キーの設定が必要です。

## 特徴

- **システムワイド** — どのアプリでも、テキストを選択してホットキーを押すだけ
- **書き換えファースト** — テキスト選択中はデフォルトで書き換え。空欄 Enter で即実行
- **指示に忠実** — 「英語に翻訳して」「箇条書きにまとめて」など、プロンプトで自由に指示可能
- **ストリーミング生成** — レスポンスをリアルタイムに表示（SSE）
- **軽量常駐** — メニューバーアプリとして常駐。メモリフットプリント最小
- **カスタムホットキー** — 設定画面でキーを押すだけで記録。英数+かな同時押しにも対応
- **セキュア** — API キーは macOS Keychain に保存。ソースコードに秘密情報なし

## デモ

```
[テキストエディタで文章を選択] → ⌃⌥Space → ポップアップ表示 → Enter → 書き換え結果を挿入
```

## 動作要件

- macOS 14 (Sonoma) 以降
- Swift 6.x / Swift Package Manager
- Google Gemini API キー

## ビルド & 実行

```bash
# ビルド（/tmp/LLMime.app に出力）
bash build.sh

# 実行
open /tmp/LLMime.app
```

初回起動時に以下の権限を許可してください：

| 権限 | 用途 |
|------|------|
| アクセシビリティ | カーソル位置の取得・テキスト選択の読み取り |
| オートメーション (System Events) | 生成テキストの挿入 (Cmd+V) |
| 入力監視 | ホットキー検知（英数+かな使用時） |

## 設定

メニューバーのアイコンから「設定…」を開きます。

- **API キー** — Google AI Studio で取得した Gemini API キー
- **モデル** — gemini-2.5-flash-lite / flash / pro から選択
- **ホットキー** — 「変更」→ 任意のキーコンビネーションを押して記録

## 使い方

| 操作 | 動作 |
|------|------|
| テキスト選択 → ホットキー | 選択テキスト付きでポップアップ表示 |
| プロンプト空欄で Enter | 選択テキストを書き換え |
| プロンプト入力して Enter | 指示に従って生成 |
| Enter（生成後） | 結果を元アプリに挿入 |
| ⌘Enter（生成後） | プロンプトを再送信 |
| Esc | 生成中ならキャンセル / ポップアップを閉じる |

## 技術スタック

- **Swift / SwiftUI + AppKit** — NSPanel ベースのフローティングポップアップ
- **Carbon API** — RegisterEventHotKey による確実なグローバルホットキー
- **CGEventTap** — 英数+かなキーのコード検知
- **AXUIElement** — テキストカーソル位置の取得
- **URLSession + SSE** — Gemini API ストリーミング
- **NSAppleScript** — System Events 経由のテキスト挿入
- **Keychain Services** — API キーのセキュアな保存

## ライセンス

MIT License
