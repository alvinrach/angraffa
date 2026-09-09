# Research 2: Backend & Browser Automation Architecture

> **Date (UTC):** 2026-09-09 11:56:49 UTC

## 1. Executive Summary
This document captures the architectural research and decisions for the **Job Auto-Fill Agent Backend** running on an Ubuntu VM (and tested locally on Mac M4), orchestrating headless browser automation, and integrating with Supabase and the mobile client (iOS/Android).

---

## 2. Browser Automation Strategy: Playwright vs Alternatives

### How Playwright Actually Works
Playwright operates by controlling a real **headless Chromium / Chrome engine** on the VM. It interacts directly with the **DOM (Document Object Model)** tree of the webpage:
- **DOM Inspection**: Scans `<input>`, `<textarea>`, `<select>`, `<button>`, and dynamic custom components.
- **Programmatic Actions**:
  - `page.locator('input[name="first_name"]').fill("...")`
  - `page.locator('input[type="file"]').set_input_files("resume.pdf")`
  - `page.locator('select#country').select_option("...")`
  - `page.locator('button[type="submit"]').click()`
- **Auto-Waiting**: Automatically waits for elements to be actionable, attached, and visible before performing actions, avoiding brittle race conditions in modern single-page apps (SPAs).

### Role of Screenshots (Verification, Not Mechanism)
Playwright does **not** rely on screenshots to fill forms. Instead:
1. **User Peace of Mind**: A screenshot of the completed form is captured before/after submission and sent to the mobile chat UI so the user can visually verify the inputs.
2. **Visual Fallback**: In rare cases where non-standard canvas or custom shadow DOM components exist, an LLM with Vision (e.g., Gemini 2.5 Flash) can inspect the screenshot to locate coordinate positions.

### Alternatives Analyzed

| Strategy | Mechanism | Pros | Cons / Failure Points | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **Direct API Reverse Engineering** | Raw HTTP `POST` requests to ATS endpoints | Sub-second speed, low resource usage | Breaks with CSRF tokens, Cloudflare bot protection, dynamic sessions | ❌ Rejected |
| **Browser Extension** | Runs in desktop Chrome | Uses existing cookies/sessions | Not autonomous; requires open laptop, defeats mobile-first goal | ❌ Rejected |
| **iOS WKWebView + JS** | In-app hidden browser | Fully client-side | iOS sandbox restricts programmatic file uploads; fails on heavy SPAs | ❌ Rejected |
| **Headless Browser (Playwright)** | Cloud/VM headless Chromium | Native file uploads, handles dynamic SPAs (Workday, Greenhouse, Lever, Ashby), 24/7 background execution | Uses ~150–300MB RAM per instance | ✅ **Selected** |

---

## 3. Communication Protocol: HTTP Streaming (SSE) vs WebSockets

### Selected: HTTP POST + Server-Sent Events (SSE)
- **Why over WebSockets**: Mobile networks switch frequently (Wi-Fi ↔ 5G) and apps go into background/sleep. WebSockets drop and require complex reconnection state machines in Swift. HTTP is stateless, standard, and native in Swift via `URLSession.shared.bytes(for:)`.
- **Event Flow**:
  1. `POST /api/apply` with `{ "url": "https://...", "profile_id": "..." }`
  2. Server keeps connection open and streams JSON chunks (`text/event-stream`):
     - `data: {"status": "fetching", "message": "Opening job page..."}`
     - `data: {"status": "filling", "message": "Filling fields & attaching resume..."}`
     - `data: {"status": "completed", "message": "Submitted successfully", "screenshot_url": "..."}`

---

## 4. Cross-Platform Consistency: Mac M4 (Local) vs Ubuntu VM (Production)

| Component | Mac M4 (Local Dev) | Ubuntu VM (Production) | Solution |
| :--- | :--- | :--- | :--- |
| **Browser GUI** | `headless=False` (watch browser type on screen) | `headless=True` (no GUI display) | Controlled via `HEADLESS` env variable |
| **Linux Dependencies** | Handled natively by macOS | Requires Linux font & graphics packages (`libnss3`, `libgbm`) | Managed via `playwright install --with-deps` or Docker image |
| **Containerization** | `mcr.microsoft.com/playwright/python` | `mcr.microsoft.com/playwright/python` | Identical Linux image via Docker Compose |

---

## 5. Supabase Integration Touchpoints

1. **Storage**:
   - `resumes/`: Master PDF files (uploaded from iOS app, downloaded by VM agent during form filling).
   - `screenshots/`: Form filling confirmation screenshots (uploaded by VM agent, viewed in iOS app).
2. **Database**:
   - `profiles`: User info, contact links, and `answers_json` for custom question Q&A memory.
   - `applications`: Application logs, statuses (`pending`, `filling`, `submitted`, `failed`), and timestamps.
