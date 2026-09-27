# 📖 Crammie (크래미)

> **"시험 직전, 교재 PDF 하나로 벼락치기."**
> 교재 PDF를 통째로 넣고 시험 범위 페이지만 고르면, 핵심 개념을 암기했는지 확인하고 AI가 간단한 시험 문제를 만들어 주는 macOS 앱이에요.

## ✨ 계획 중인 기능

* **📄 PDF 통째로 불러오기** ✅ — 교재를 미리 자를 필요 없이 그대로 넣어요.
* **🎯 시험 범위 설정** ✅ — 설정 화면에서 페이지 범위를 지정해요 (예: `45-78`). 책 쪽수로 적고, 표지 때문에 어긋나면 맞춰 줄 수 있어요.
* **🧠 핵심 개념 카드** — AI가 범위 안의 핵심 개념을 뽑아 카드로 만들어요.
* **✍️ AI 시험 문제** — 객관식 · OX · 빈칸 · 서술형. 문제마다 근거 페이지를 표시해요.
* **🔁 오답 반복** — 틀린 것만 다시 풀고 오답 노트로 모아요.

## 🛠️ 기술 스택

* **Platform**: macOS 27
* **Language / UI**: Swift, SwiftUI
* **Data**: SwiftData
* **PDF**: PDFKit
* **AI**: Claude API (`URLSession`), API 키는 키체인에 보관

## ▶️ 실행하기

1. `Crammie.xcodeproj`를 Xcode로 열어요.
2. **Signing & Capabilities → Team**에서 Personal Team을 골라요.
3. ⌘R로 실행해요.

자세한 결정 사항은 [`docs/CONTEXT.md`](docs/CONTEXT.md)를 참고해 주세요.
