<p align="center">
  <img src="assets/icon.png" width="128" alt="LLMime icon">
</p>

<h1 align="center">LLMime</h1>

<p align="center"><strong>どこでも、すぐに、AI の力を借りる。</strong></p>

<p align="center">
  <a href="https://github.com/KoichiIshiguro/LLM-input-support/releases/latest">
    <img src="https://img.shields.io/github/v/release/KoichiIshiguro/LLM-input-support?label=download&color=7c3aed" alt="Latest Release">
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

LLMime（エルエルマイム）は macOS のシステム全体で動作する AI 入力支援ツールです。
どのアプリを使っていても、ホットキー一発で軽量なポップアップが現れ、今書いている文章をその場で AI が書き換えてくれます。

---

## こんな場面で使えます

### 文章の推敲を一瞬で

メールを書いていて「もうちょっと丁寧にしたいな」と思ったら、文章を選択して **⌃⌥Space → Enter** だけ。
AI が文脈を保ったまま、読みやすく書き換えてくれます。

### 指示を添えれば何でもできる

選択テキストに対して自由に指示を出せます：

- `英語に翻訳して` → 選択した日本語がそのまま英文に
- `箇条書きにまとめて` → 長文を構造化
- `もっとカジュアルに` → フォーマルな文章をくだけたトーンに
- `TypeScriptで書き直して` → コードの言語変換にも

### テキスト選択なしでも使える

ポップアップに直接テキストを打ち込めば、それ自体を書き換え。
下書きを貼り付けてブラッシュアップする、といった使い方も可能です。

### 作業フローを中断しない

生成結果は **Enter キーでカーソル位置に直接挿入**。
ブラウザのコピペ欄でも、コードエディタでも、チャットアプリでも——今使っているアプリを離れることなく AI の出力を受け取れます。

---

## ダウンロード

[**LLMime.zip (macOS)**](https://github.com/KoichiIshiguro/LLM-input-support/releases/latest/download/LLMime.zip) — 最新リリースをダウンロード

> 展開して `LLMime.app` をアプリケーションフォルダに移動し、起動してください。
> 初回起動時に権限の許可と Gemini API キーの設定が必要です。

## 動作要件

- macOS 14 (Sonoma) 以降
- Google Gemini API キー（[Google AI Studio](https://aistudio.google.com/apikey) で無料取得可能）

## セットアップ

### バイナリから

1. 上記リンクから `LLMime.zip` をダウンロード・展開
2. `LLMime.app` をアプリケーションフォルダに配置
3. **初回起動時、macOS が警告を表示します。** 以下のいずれかの方法で開いてください：

   **方法 A: 右クリックで開く（推奨）**
   > `LLMime.app` を **右クリック（または Control+クリック）** →「**開く**」→ 確認ダイアログで「**開く**」

   **方法 B: システム設定から許可**
   > 通常通りダブルクリック → 警告が出たら「完了」→ **システム設定 → プライバシーとセキュリティ** → 下にスクロールすると「"LLMime"は開けませんでした」と表示されるので「**このまま開く**」をクリック

   **方法 C: ターミナル（確実）**
   ```bash
   xattr -cr /Applications/LLMime.app
   ```

4. 起動するとメニューバーにアイコンが表示される
5. 「設定…」から Gemini API キーを入力

> **なぜこの手順が必要？**
> LLMime は Apple Developer ID（年間$99）で署名されていないため、macOS が未検証アプリとして警告します。2回目以降は通常通り起動できます。ソースコードは本リポジトリで全て公開されています。

### ソースからビルド

```bash
git clone https://github.com/KoichiIshiguro/LLM-input-support.git
cd LLM-input-support
bash build.sh     # /tmp/LLMime.app に出力
open /tmp/LLMime.app
```

Swift 6.x / Swift Package Manager が必要です。

### 権限の許可

初回起動時に以下の権限を求められます。すべて許可してください：

| 権限 | 用途 |
|------|------|
| アクセシビリティ | カーソル位置の取得・テキスト選択の読み取り |
| オートメーション (System Events) | 生成テキストの挿入 |
| 入力監視 | ホットキー検知（英数+かな使用時） |

## 使い方

### 基本操作

```
テキスト選択 → ⌃⌥Space → ポップアップ表示 → Enter → 書き換え完了 → Enter → 挿入
```

### キー操作一覧

| 操作 | 動作 |
|------|------|
| テキスト選択 → ホットキー | 選択テキスト付きでポップアップ表示 |
| プロンプト空欄で Enter | 選択テキストをデフォルト書き換え |
| 指示を入力して Enter | 指示に従って処理（翻訳・要約など） |
| Enter（生成後） | 結果を元アプリのカーソル位置に挿入 |
| ⌘Enter（生成後） | プロンプトを再送信してやり直し |
| Esc | 生成中ならキャンセル / ポップアップを閉じる |

### 設定

メニューバーのアイコンから「設定…」を開きます。

- **API キー** — Gemini API キー（Keychain に安全に保存）
- **モデル** — gemini-2.5-flash-lite（高速）/ flash / pro（高精度）
- **ホットキー** — 「変更」ボタンを押して任意のキーコンビネーションを記録
- **英数+かな** — トグルで有効化。JIS キーボードユーザー向け

## 特徴

- **書き換えファースト** — デフォルト動作が書き換え。余計な設定なしですぐ使える
- **システムワイド** — macOS 上のあらゆるアプリで動作
- **ストリーミング表示** — 生成結果がリアルタイムに流れてくる
- **軽量常駐** — メニューバーアプリとして常駐。Dock に表示されず邪魔にならない
- **セキュア** — API キーは macOS Keychain に保存。ソースコードに秘密情報なし
- **カスタムホットキー** — 好みのキーバインドを自由に設定可能

## 技術スタック

| 領域 | 技術 |
|------|------|
| UI | Swift / SwiftUI + AppKit（NSPanel フローティングポップアップ） |
| ホットキー | Carbon RegisterEventHotKey + CGEventTap（英数+かな） |
| カーソル検知 | AXUIElement（Accessibility API） |
| AI | Google Gemini API（URLSession + SSE ストリーミング） |
| テキスト挿入 | NSAppleScript → System Events |
| API キー保存 | Keychain Services |
| CI/CD | GitHub Actions（push で自動ビルド、タグで自動リリース） |

## ライセンス

MIT License
