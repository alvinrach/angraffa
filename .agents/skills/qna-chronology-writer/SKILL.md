---
name: qna-chronology-writer
description: Record research, investigation findings, or debugging logs in a structured, dated Q&A format. Always appends to a user-specified existing file, refusing execution if no valid target file is provided.
---

# Q&A Chronology Writer

Append technical investigations, experiments, or research findings in a structured, chronological **Q&A (Question & Answer)** format to a user-provided file.

---

## Strict Prerequisites (Refusal Conditions)

1. **Explicit Target File Required**:
   - The user **MUST explicitly provide the target file path** (e.g. `research/research3-playwright.md`).
   - If the user does not specify a target file in their request, **you MUST REFUSE to execute and ask the user to provide the target file path first**.
2. **File Existence Required**:
   - The target file **MUST already exist** on disk (even if it is currently an empty 0-byte file).
   - If the specified file does not exist, **REFUSE to execute** and instruct the user to create the file first.
3. **Always Appending**:
   - **NEVER overwrite or replace** existing content. Always **APPEND** new entries to the bottom of the file.

---

## Workflow Steps

### Step 1: Validate Prerequisites
- Verify that a target file path was supplied by the user.
- Verify the file exists on the filesystem.
- If either condition fails, stop immediately and report the refusal reason to the user.

### Step 2: Capture UTC Timestamp
Record the current UTC timestamp:
```markdown
> **Date (UTC):** YYYY-MM-DD HH:MM:SS UTC
```

### Step 3: Formulate Distinct Questions (`### Q:`)
Extract and formulate the core questions covering:
1. **Actions & Iterations**: Why were specific tools, flags, or test runs executed?
2. **Behavioral Shifts**: Why did the approach change (e.g. switching from headless to non-headless, changing wait strategies, adding anti-detection flags)?
3. **Findings & Discoveries**: What was uncovered regarding page structure, DOM elements, or file inputs?
4. **Data Evaluation / Gaps**: What data is required vs what is currently available in the database/schema?
5. **Verdict & Next Steps**: Should execution proceed, or pause for fixes?

### Step 4: Provide Factual, Numbered Answers (`**A:**`)
- Keep answers concrete, factual, and backed by actual test outputs and code snippets.
- Break multi-step explanations into numbered lists.
- Avoid vague dialogue or fluffy narrative; focus on technical facts, selectors, HTTP status codes, and database columns.

### Step 5: Append to File
- If the file is not empty, ensure a clean separator (`\n---\n\n`) is added before the new entry.
- Append the new Q&A block to the END of the file.

---

## Output Template Example

```markdown
---

## Q&A Investigation Log (<Short Topic>)

> **Date (UTC):** 2026-09-10 07:42:00 UTC

### Q: Why did you open and close the browser several times? Did you do testing?
**A:** Yes, I ran live diagnostic iterations to inspect the DOM, bypass anti-bot shields, and discover how the platform handles form filling:
1. **Iteration 1 (Timeout on `networkidle`)**: Standard load hung due to background telemetry. Switched to `domcontentloaded`.
2. **Iteration 2 (Bot Challenge)**: Default headless mode triggered DataDome CAPTCHA (`geo.captcha-delivery.com`).
3. **Iteration 3 (Stealth & Non-Headless Switch)**: Added anti-automation flags and User-Agent, successfully bypassing protection.
4. **Iteration 4 (DOM Inspection)**: Identified custom Angular web components (`<spl-input>`).
5. **Iteration 5 (CV Upload Behavior)**: Discovered two distinct file inputs (autofill parser vs mandatory attachment).

---

### Q: What do you think about our current data? Do we lack anything from the database?
**A:** Yes, comparing our database schema with the platform's required fields:
1. **City / Location**: Required (`*`) with autocomplete dropdown. Missing in database.
2. **First / Last Name Split**: Form strictly separates names; database stores a single full name string.
3. **Phone Number Split**: Requires country code separation from local digits.

---

### Q: Verdict — Can we continue to the next step or should we stop?
**A:** Pause and update the database schema and user profile first before writing the automated test script.
```

---

## Rules
- **Target File Mandatory**: Refuse if no target file is provided.
- **Always Append**: Never truncate or replace prior content.
- Always use `### Q: <question>` and `**A:** <answer>`.
- Use exact UTC timestamps.
- Highlight specific fields, CSS selectors, database column names, and error codes in backticks.
- Conclude with an actionable **Verdict** on whether prerequisites are met to continue.
