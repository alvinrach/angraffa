# Chronology

## 2026-09-09: Foundation Setup, Supabase Integration & iOS Client

**Built**
- iOS SwiftUI client with `ChatView`, `ProfileView`, and two-tab navigation in `JobAgentApp`.
- Supabase integration (`supabase-swift` v2.x) with `SupabaseService` for database operations and resume PDF uploads to the `resumes` storage bucket.
- Data models for `ChatMessage` (with application statuses) and `Profile` (with structured contact info and `answers_json` Q&A memory).
- XcodeGen specification (`ios/project.yml`) generating `JobAgentApp.xcodeproj`.
- Keyboard dismissal mechanisms (interactive scroll, tap-to-dismiss, and keyboard "Done" toolbar).
- Architecture research documentation (`research/research2-backend.md`) detailing backend, Playwright automation, and streaming protocols.
- Multi-platform `.gitignore` covering Xcode, macOS, Python, and Android artifacts.

**Commits**
- `89d7fa1` feat: initialize iOS project with SwiftUI architecture & context engineering
- `ef7f9e5` feat: integrate Supabase for profile management and resume storage with supporting UI and view models
- `f078f8e` chore: enable UILaunchScreen generation in Xcode project settings
- `1cb1444` feat: improve keyboard interaction and dismissal behavior in Profile and Chat views
- `3a8a4a1` feat: implement keyboard dismissal handling in ProfileView via tap gesture and toolbar button

**Uncommitted**
- `.agents/`: chronology-writer agent skill configuration

**Decisions**
- Free iOS Sideloading: Used Xcode Personal Team signing (7-day free renewal) to install and run directly on iPhone 15 without the $99/year Apple Developer program.
- Architecture: Selected a lightweight monorepo (`ios/`, `backend/`, `android/`) to keep data schemas and API contracts unified without requiring heavy monorepo tooling.
- Browser Automation: Chose Playwright on an Ubuntu VM over direct API calls (too fragile with anti-bot/CSRF) and on-device `WKWebView` (restricted file upload sandbox on iOS). Screenshots are used for visual verification receipts in the chat, while DOM locators handle actual form filling.
- Communication Protocol: Selected HTTP with Server-Sent Events (SSE) / streaming over WebSockets to tolerate mobile network switching (Wi-Fi/5G) and background sleep natively in Swift.
- Persistence & Storage: Selected Supabase for unified Postgres relational storage, JSONB custom Q&A memory, and blob storage for resumes and screenshots.
- Keyboard Handling: Combined `.scrollDismissesKeyboard(.interactively)`, `.onTapGesture`, and a `ToolbarItemGroup(placement: .keyboard)` Done button because SwiftUI `Form` consumes touch gestures differently from standard `ScrollView`.

**Surprises**
- Root-level `.xcodeproj` initially left behind after moving files into `ios/`, resolved by cleaning the root artifact and regenerating via `xcodegen` inside `ios/`.
- SwiftUI `Form` in `ProfileView` did not propagate basic tap gestures to dismiss the keyboard, requiring a global responder helper and keyboard toolbar.

**Open**
- Python Playwright backend engine implementation in `backend/` with HTTP SSE streaming.
- Live HTTP client in `ChatViewModel` to trigger form auto-filling from the chat input.
- Execution of Supabase RLS policies for storage and table permissions.

since: 3a8a4a1c902e26b02d87d47ca71af9a982dcb48b
