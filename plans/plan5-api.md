# Plan 5: FastAPI Backend Service & SSE Streaming Architecture

> **Target Platform:** Python FastAPI Backend (`backend/app/`) & iOS Swift Client (`ios/App/`)  
> **Core Objective:** Package the validated Playwright automation engine into a robust, production-ready FastAPI service with Server-Sent Events (SSE) streaming live application logs and review screenshots directly to the iOS `ChatView`.

---

## 1. System Flow & Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    actor User as 📱 iOS User (iPhone)
    participant iOS as 📱 ChatView / ChatViewModel
    participant API as ⚡ FastAPI Backend (/api/apply)
    participant Supabase as ☁️ Supabase (DB & Storage)
    participant Playwright as 🌐 Playwright Engine
    participant Portal as 🏢 Job Portal (SmartRecruiters)

    User->>iOS: Paste Job URL & Tap Send
    iOS->>API: POST /api/apply (job_url, user_id) [SSE Stream]
    API->>iOS: SSE Event: status="started" (Connecting to Supabase...)
    
    API->>Supabase: Fetch Profile, Experiences, Answers, & CV
    Supabase-->>API: Return Profile Data & CV Bytes
    API->>iOS: SSE Event: status="profile_loaded" (Found profile for Alvin Rachmat)
    
    API->>Playwright: Launch Stealth Browser & Navigate to Job URL
    API->>iOS: SSE Event: status="step_1_running" (Bypassing anti-bot & uploading CV...)
    
    Playwright->>Portal: Attach CV, Fill Name, City, Phone, LinkedIn
    Playwright->>Portal: Click Next -> Step 2
    API->>iOS: SSE Event: status="step_1_done" (Step 1 complete, transitioning to Step 2...)
    
    API->>iOS: SSE Event: status="step_2_running" (Answering screening questions...)
    Playwright->>Portal: Fill Radios, Comboboxes, Salaries, Notice, Essay, Consent
    
    Playwright->>API: Capture Verification Screenshot
    API->>Supabase: Upload screenshot to storage (screenshots/bucket)
    API->>Supabase: Save record in applications table
    
    API->>iOS: SSE Event: status="completed", screenshot_url="...", application_id="..."
    iOS->>User: Display Completed Message with Interactive In-App Screenshot Preview
```

---

## 2. Backend Module Structure (`backend/app/`)

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                  # FastAPI app entry point, CORS, health check, router
│   ├── config.py                # Environment settings (.env parser)
│   ├── schemas/
│   │   ├── __init__.py
│   │   └── application.py       # Pydantic models (ApplyRequest, SSEEvent, ApplicationRecord)
│   └── services/
│       ├── __init__.py
│       ├── supabase_service.py  # Supabase client (profile fetch, CV download, screenshot upload)
│       └── runner_service.py    # Playwright runner streaming async generator events
├── testdrive/                   # Research test harness
├── pyproject.toml               # Python dependencies
└── .env                         # Backend environment variables
```

---

## 3. Implementation Steps

### Step 1: Backend Dependencies & Config
- Add `fastapi`, `uvicorn`, `sse-starlette`, `pydantic` to `backend/pyproject.toml`.
- Configure `backend/app/config.py` loading `SUPABASE_URL`, `SUPABASE_KEY`, `HOST`, `PORT`.

### Step 2: Supabase Backend Service (`backend/app/services/supabase_service.py`)
- Fetch profile by user ID or latest profile.
- Download CV PDF bytes from `resumes` bucket.
- Upload captured verification screenshots to `screenshots` bucket with public/signed URLs.
- Insert application record in `public.applications` table (`status`, `job_url`, `screenshot_url`, `logs`).

### Step 3: Playwright Automation Service (`backend/app/services/runner_service.py`)
- Modularize the 100% verified Step 1 & Step 2 form filling logic into an `async def run_smartrecruiter_application(...)` generator.
- Yield real-time event dictionaries:
  - `{"event": "log", "data": {"message": "..."}}`
  - `{"event": "step", "data": {"step": 1, "status": "done"}}`
  - `{"event": "screenshot", "data": {"url": "..."}}`
  - `{"event": "completed", "data": {"status": "success", "application_id": "..."}}`

### Step 4: FastAPI Server & SSE Endpoint (`backend/app/main.py`)
- Implement `POST /api/apply` endpoint returning `EventSourceResponse`.
- Health check `GET /health` returning server status and Playwright readiness.

### Step 5: iOS Client SSE Integration (`ios/App/`)
- Create `BackendAPIService.swift` with `URLSession` async byte streamer parsing SSE events.
- Update `ChatViewModel.swift` to send `ApplyRequest`, stream real-time logs into chat bubble bubbles, and display the screenshot preview when finished.
- Update `ChatMessage.swift` and `ChatView.swift` to render in-app image attachments from `screenshot_url`.

---

## 4. Verification & Testing Checklist

- [ ] FastAPI starts up and responds to `GET /health`.
- [ ] `POST /api/apply` triggers Playwright automation and streams SSE logs live.
- [ ] Screenshot is uploaded to Supabase `screenshots` bucket.
- [ ] iOS `ChatView` connects to `POST /api/apply`, renders live terminal/progress logs, and displays the final verified screenshot card.
