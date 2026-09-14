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

## 2026-09-12: OTP Auth, Profile Expansion & SmartRecruiters Automation Research

**Built**
- `[me]` Supabase OTP email authentication flow (`AuthView.swift`, `AuthViewModel.swift`) with 8-digit verification and clipboard paste support.
- `[me]` Expanded iOS profile model and UI (`Profile.swift`, `ProfileViewModel.swift`, `ProfileView.swift`) with first/last name split, phone country code (`+971`/`+62`), phone number, city, country, LinkedIn URL, and CV PDF storage upload.
- `[forced]` Stealth Chromium launch configuration (`--disable-blink-features=AutomationControlled`, desktop User-Agent, `domcontentloaded`) to bypass SmartRecruiters' DataDome bot protection.
- `[agent]` Research-grade Playwright automation harness in `backend/testdrive/smartrecruiter/test_smartrecruiter_application.py` managed via `uv`.
- `[me]` Q&A chronology skill (`qna-chronology-writer`) and research findings in `research/research3-playwright.md`.
- `[me]` Architecture specification (`plans/plan3-swift-playwright.md`) establishing the "Curate Once in Phone, Auto-Apply Accurately Everywhere" strategy.
- `[agent]` 100% validated end-to-end SmartRecruiters form filling covering Step 1 (Personal Info & bottom CV upload) and Step 2 (Radios, Comboboxes, text/number inputs, 1440-char pitch textarea, and privacy consent checkbox).
- `[me]` Backend environment configuration (`.env`, `.env.example`) with `python-dotenv`.

**Commits**
- `a419046` feat: add project chronology documentation and automated chronology-writer agent skill
- `ea0bf0d` feat: initialize backend project and add Playwright research investigation documentation
- `d5b2800` feat: implement email OTP authentication flow and expand user profile model fields
- `7f6bed4` feat: integrate Supabase and Playwright for automated SmartRecruiters job application testing
- `5669736` feat: update SmartRecruiters application test script with improved form filling and add test screenshots

**Uncommitted**
- `plans/plan4-langgraph.md`: Placeholder for future LangGraph ReAct agent architecture.

**Decisions**
- Abandoned "Easy Apply" AI Resume Parser: Chose direct database field population and bottom `Resume *` file attachment over the top resume parser because the parser creates broken, unconfirmed draft experience accordions missing required fields (`Title*`, `Company*`, `To Date*`) that trap form validation.
- Curated Profile & Answer Memory: Stored structured personal details, work history, and default screening answers in Supabase (`profiles`, `answers_json`) so fields can be curated once on the phone and reused cleanly across applications.
- Non-Headless Stealth: Selected non-headless Chromium with automation blink features disabled to cleanly bypass DataDome anti-bot challenges on job portals.
- Combobox Interaction: Used keyboard navigation (`ArrowDown` + `Enter`) and selector dropdown fallback on custom Angular `<spl-select>` and `<spl-autocomplete>` elements to handle dynamic DOM rendering.
- Scope Separation: Moved LangGraph agentic reasoning to a dedicated future plan (`plans/plan4-langgraph.md`), keeping `plan3-swift-playwright.md` strictly focused on deterministic Swift + Playwright architecture.

**Surprises**
- SmartRecruiters' top resume parser auto-generated draft project cards with missing required fields, causing Angular DOM detachment errors when trying to dismiss them programmatically.
- DataDome CAPTCHA immediately blocked standard headless Chromium, resolved using stealth launch arguments and desktop macOS User-Agent.
- Step 2 questions render custom Angular web components (`<spl-button>`, `input[id^="question_"]`) rather than standard HTML form controls, requiring explicit locator scoping.

**Open**
- Add structured Work Experiences and Default Screening Answers UI sections in `ProfileView.swift`.
- Wrap Playwright engine into FastAPI backend service (`POST /api/apply` SSE streamer).
- Connect iOS `ChatViewModel` to trigger backend application flow and display live streaming logs and review screenshots.

since: 566973624e86b9cbf1656370d2b979cc7f9e3868

## 2026-09-14: FastAPI SSE Backend, iOS Live Streaming & Storage RLS Fixes

**Built**
- `[me]` Experience model and editing modal (`Experience.swift`, `ExperienceEditView.swift`, and expanded `ProfileView.swift`) supporting multi-experience curation with job titles, companies, locations, date ranges, current employment toggles, and bullet descriptions.
- `[me]` Default screening answers configuration UI in `ProfileView.swift` mapped to Supabase `answers_json` storage.
- `[agent]` Dynamic profile data injection in Playwright runner (`smartrecruiter_service.py`), mapping database answers to form controls without hardcoded constants.
- `[agent]` FastAPI backend service (`backend/app/main.py`) exposing `POST /api/apply` with Server-Sent Events (SSE) streaming via `asyncio` and `EventSourceResponse`.
- `[agent]` Backend services (`smartrecruiter_service.py`, `supabase_service.py`) orchestrating Playwright automation, real-time log event streaming (`log`, `step`, `screenshot`, `completed`), Supabase CV download, screenshot upload, and application status persistence.
- `[me]` iOS live event streaming client (`BackendAPIService.swift`, `ChatViewModel.swift`, `ChatView.swift`) using `URLSession.bytes` async sequences, rendering live terminal logs and visual verification cards.
- `[forced]` iOS App Transport Security (`NSAllowsArbitraryLoads: YES`) and Local Network permissions (`NSLocalNetworkUsageDescription`) in `ios/project.yml`.
- `[me]` Backend Server Connection settings field in `ProfileView.swift` with `@AppStorage` persistence for easy LAN IP configuration.
- `[forced]` Supabase Postgres RLS policy fix for `storage.objects` and `profiles` enabling seamless `upsert: true` CV uploads.

**Commits**
- `d0e9bd2` feat: add project chronology documentation and create LangGraph ReAct agent plan
- `779abe3` feat: add experience editing view and parameterize smartrecruiter test script with dynamic profile answers
- `ddd550d` feat: implement FastAPI backend service and iOS client integration for job application streaming

**Decisions**
- Server Binding: Bound FastAPI to `0.0.0.0:8000` instead of `127.0.0.1` so physical iOS devices on the local Wi-Fi subnet can reach the host Mac.
- Real-time Protocol: Used standard HTTP Server-Sent Events (SSE) via `URLSession.bytes` instead of WebSocket full-duplex connection, simplifying iOS reconnect logic, state management, and firewall traversal.
- RLS Policy Architecture: Configured `storage.objects` policies for `resumes` and `screenshots` to comprehensive `FOR ALL` with explicit `WITH CHECK (bucket_id = ...)` to allow `upsert: true` without PostgreSQL constraint violations.
- In-App Backend Configuration: Exposed the backend base URL directly in the iOS Profile settings backed by `@AppStorage` so device IP changes on dynamic DHCP networks can be updated immediately without recompiling.

**Surprises**
- `upsert: true` in `supabase-swift` Storage uploads triggered `new row violates row-level security policy` because Postgres RLS requires a matching `WITH CHECK` clause on `UPDATE` policies even when `INSERT` passes.
- Physical iPhone silently failed to establish TCP connections to the local Mac IP until `NSLocalNetworkUsageDescription` was added to `Info.plist` and both devices were aligned on the same Wi-Fi SSID.
- Initial uvicorn listener bound to `127.0.0.1` blocked external network packets arriving from the iPhone.

**Open**
- Multi-platform job portal expansion (Workday, Greenhouse, Lever).
- Background task worker/queue if multiple applications are triggered simultaneously.
- LangGraph ReAct agent integration (`plans/plan4-langgraph.md`) for ambiguous/unseen screening questions.

since: ddd550dd59e8fac1935c9a06343f167c336eacef


