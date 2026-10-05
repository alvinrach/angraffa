import asyncio
import importlib
import importlib.util
import json
import os
import sys
import traceback
import types
from pathlib import Path
from typing import TypedDict, Optional, List, Dict, Any, AsyncGenerator

from bs4 import BeautifulSoup
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END
from playwright.async_api import async_playwright

from app.config import (
    OPENAI_API_KEY,
    OPENAI_MODEL_NAME,
    DATA_DIR,
    SCRIPTS_DIR,
)
from app.services.cv_service import cv_parser_service
from app.services.supabase_service import supabase_service


# ==========================================
# 1. State Definition
# ==========================================
class JobApplicationState(TypedDict):
    job_url: str
    user_id: Optional[str]
    auto_submit: bool
    platform_name: str
    has_cv: bool
    md_cv: str
    profile_data: Dict[str, Any]
    cleaned_html: str
    script_code: str
    placeholder_schema: Dict[str, Any]
    filled_json: Dict[str, Any]
    execution_logs: List[str]
    last_error: Optional[str]
    retry_count: int
    screenshot_url: Optional[str]
    status: str
    app_id: str


# ==========================================
# 2. Helpers
# ==========================================
def get_llm():
    """Instantiate OpenAI Chat model."""
    if not OPENAI_API_KEY:
        raise ValueError("OPENAI_API_KEY is not set in backend/.env. Please configure your OpenAI API key.")
    return ChatOpenAI(
        model=OPENAI_MODEL_NAME,
        api_key=OPENAI_API_KEY,
        temperature=0.1
    )


def sanitize_html_for_llm(raw_html: str) -> str:
    """Strip clutter (scripts, styles, SVGs) retaining interactive form elements."""
    soup = BeautifulSoup(raw_html, "html.parser")
    for tag in soup(["script", "style", "svg", "path", "noscript", "iframe", "header", "footer", "nav", "link", "meta"]):
        tag.decompose()

    # Find main form or body container
    forms = soup.find_all("form")
    if forms:
        content = "\n".join([str(f) for f in forms])
    else:
        content = str(soup.body or soup)

    # Truncate if unusually long to protect token budget
    if len(content) > 35000:
        content = content[:35000] + "\n...[truncated remainder of page]"
    return content


def decide_link_platform(url: str) -> str:
    """Modular platform identifier placeholder."""
    url_lower = url.lower()
    if "smartrecruiters.com" in url_lower:
        return "smartrecruiters"
    elif "lever.co" in url_lower:
        return "lever"
    elif "greenhouse.io" in url_lower:
        return "greenhouse"
    elif "myworkdayjobs.com" in url_lower or "workday" in url_lower:
        return "workday"
    return "generic"


def check_script_in_db(platform: str, url: str) -> Optional[Dict[str, Any]]:
    """
    Modular database lookup placeholder.
    FORCED TO ALWAYS RETURN NONE (Always No) for the current phase.
    """
    return None


# ==========================================
# 3. Graph Nodes
# ==========================================
async def start_session_node(state: JobApplicationState) -> Dict[str, Any]:
    """Node: Validate CV, convert to Markdown via pymupdf4llm if needed, and fetch profile."""
    logs = state.get("execution_logs", [])
    logs.append("🔹 [LangGraph] Starting session & validating user profile...")

    profile = supabase_service.fetch_profile(user_id=state.get("user_id"))
    user_uuid = str(profile.get("id"))
    resume_path = profile.get("resume_path")

    if not resume_path:
        logs.append("⚠️ [LangGraph] No CV found in profile. Please upload your CV in the Profile tab.")
        return {
            "has_cv": False,
            "profile_data": profile,
            "status": "missing_cv",
            "execution_logs": logs
        }

    # Ensure Markdown CV exists (One-Time Ingestion)
    answers = profile.get("answers_json") or {}
    md_cv = answers.get("resume_markdown")
    if not md_cv:
        logs.append("📄 [LangGraph] Converting CV PDF to Markdown via pymupdf4llm...")
        conversion_res = cv_parser_service.process_and_save_user_cv(user_id=user_uuid)
        profile = supabase_service.fetch_profile(user_id=user_uuid)
        answers = profile.get("answers_json") or {}
        md_cv = answers.get("resume_markdown", "")

    logs.append(f"✅ [LangGraph] Profile & Markdown CV verified ({len(md_cv)} chars).")

    # Create Supabase tracking record
    app_id = supabase_service.create_application_record(
        user_id=user_uuid,
        job_url=state["job_url"],
        user_email=profile.get("email"),
        company_name=decide_link_platform(state["job_url"]).capitalize(),
        job_title="LangGraph Automated Application"
    )

    return {
        "has_cv": True,
        "md_cv": md_cv,
        "profile_data": profile,
        "app_id": app_id,
        "status": "cv_ready",
        "execution_logs": logs
    }


async def decide_link_node(state: JobApplicationState) -> Dict[str, Any]:
    """Node: Identify ATS platform from job URL."""
    logs = state.get("execution_logs", [])
    platform = decide_link_platform(state["job_url"])
    logs.append(f"🔍 [LangGraph] Platform decider identified: {platform.upper()}")
    return {
        "platform_name": platform,
        "execution_logs": logs
    }


async def check_script_node(state: JobApplicationState) -> Dict[str, Any]:
    """Node: Placeholder for script check in DB (Forced Always No)."""
    logs = state.get("execution_logs", [])
    # Forced Always No for current phase
    logs.append("ℹ️ [LangGraph] Script DB Check: No cached script found (Forced synthesis flow).")
    return {
        "execution_logs": logs
    }


async def fetch_html_node(state: JobApplicationState) -> Dict[str, Any]:
    """Node: Render page with Playwright and extract sanitized HTML."""
    logs = state.get("execution_logs", [])
    logs.append("🌐 [LangGraph] Fetching rendered DOM HTML via stealth browser...")

    cleaned_html = ""
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=False,
            args=[
                # "--headless=new",
                "--disable-blink-features=AutomationControlled",
                "--no-sandbox",
                "--start-maximized"
            ]
        )
        context = await browser.new_context(
            viewport={"width": 1280, "height": 960},
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
        )
        page = await context.new_page()
        await page.goto(state["job_url"], wait_until="domcontentloaded")
        await page.wait_for_timeout(3500)
        raw_html = await page.content()
        cleaned_html = sanitize_html_for_llm(raw_html)
        await browser.close()

    logs.append(f"✅ [LangGraph] HTML extracted & sanitized ({len(cleaned_html)} chars).")
    return {
        "cleaned_html": cleaned_html,
        "execution_logs": logs
    }


async def llm_generate_script_node(state: JobApplicationState) -> Dict[str, Any]:
    """
    Node: LLM 1 (Script Synthesizer).
    STRICT RULE: NO CV or user personal data is provided to this LLM.
    Generates a generalized Playwright script using dictionary placeholders: data["key"].
    """
    logs = state.get("execution_logs", [])
    logs.append("🧠 [LangGraph LLM 1] Synthesizing general Playwright script & variable schema...")

    llm = get_llm()
    system_prompt = """You are an expert Python Playwright automation engineer.
Analyze the provided HTML form and write a complete, standalone Python function:

```python
async def run(page, data: dict):
    # page: Playwright async Page object
    # data: Dictionary containing all values to fill (e.g. data['first_name'], data['resume_path'], data['salary_expectation'])
```

RULES:
1. DO NOT hardcode any personal names, emails, phones, or text answers.
2. Access ALL form inputs, dropdowns, radio buttons, numbers, textareas, and resume file uploads from `data['variable_name']`.
3. For file uploads, use:
   `file_inputs = await page.locator('input[type="file"]').all()`
   `if file_inputs and 'resume_path' in data: await file_inputs[-1].set_input_files(data['resume_path'])`
4. For custom comboboxes/dropdowns, support keyboard navigation (click, wait, ArrowDown, Enter) or clicking option elements.
5. If there is a privacy/terms checkbox, check it.
6. If `data.get('auto_submit', False)` is True, click the submit button at the end. Otherwise, do NOT click submit.
7. Return ONLY valid Python code wrapped in ```python ... ``` block.

At the very end of your response, after the python code block, provide a JSON block listing all variable keys required by the script:
```json
{
  "variables": {
    "first_name": "Applicant first name",
    "last_name": "Applicant last name",
    "email": "Applicant email address",
    "phone": "Applicant phone number with country code",
    "city": "Applicant current city",
    "resume_path": "Absolute path to CV file",
    ...
  }
}
```
"""

    human_prompt = f"Target Job Application URL: {state['job_url']}\n\nSanitized Form HTML:\n{state['cleaned_html']}"

    response = await llm.ainvoke([SystemMessage(content=system_prompt), HumanMessage(content=human_prompt)])
    content = response.content

    # Parse Python code and JSON schema
    script_code = ""
    if "```python" in content:
        script_code = content.split("```python")[1].split("```")[0].strip()
    elif "```" in content:
        script_code = content.split("```")[1].split("```")[0].strip()
    else:
        script_code = content.strip()

    placeholder_schema = {}
    if "```json" in content:
        try:
            json_str = content.split("```json")[1].split("```")[0].strip()
            placeholder_schema = json.loads(json_str).get("variables", {})
        except Exception:
            pass

    # Save script to local storage / DB cache
    script_filename = f"script_{state.get('platform_name', 'portal')}_{state.get('retry_count', 0)}.py"
    (SCRIPTS_DIR / script_filename).write_text(script_code)

    logs.append(f"✅ [LangGraph LLM 1] Script synthesized with {len(placeholder_schema)} variable placeholders.")
    return {
        "script_code": script_code,
        "placeholder_schema": placeholder_schema,
        "execution_logs": logs
    }


async def llm_fill_json_node(state: JobApplicationState) -> Dict[str, Any]:
    """
    Node: LLM 2 (JSON Value Mapper).
    Matches the user's Markdown CV (MdCV) and Profile Answers to the required variable schema.
    """
    logs = state.get("execution_logs", [])
    logs.append("📋 [LangGraph LLM 2] Extracting personalized JSON values from Markdown CV & Profile...")

    llm = get_llm()
    profile = state.get("profile_data") or {}
    answers = profile.get("answers_json") or {}

    system_prompt = """You are an intelligent Career Data Extractor.
Your job is to produce a JSON dictionary containing the exact values for each requested variable placeholder.
Extract the most accurate information from the applicant's Markdown CV and Stored Profile Answers.

OUTPUT FORMAT:
Return ONLY a valid JSON object matching the requested variable keys:
```json
{
  "key1": "value1",
  "key2": "value2"
}
```
"""

    human_prompt = f"""
REQUESTED VARIABLE KEYS & DESCRIPTIONS:
{json.dumps(state.get('placeholder_schema', {}), indent=2)}

APPLICANT PROFILE DATA:
- First Name: {profile.get('first_name')}
- Last Name: {profile.get('last_name')}
- Email: {profile.get('email')}
- Phone: {profile.get('phone_country_code', '')} {profile.get('phone_number', '')}
- Location / City: {profile.get('city')}, {profile.get('country')}
- LinkedIn: {profile.get('linkedin_url')}
- Stored Answers: {json.dumps(answers, indent=2)}

APPLICANT MARKDOWN CV (MdCV):
{state.get('md_cv', '')[:10000]}
"""

    response = await llm.ainvoke([SystemMessage(content=system_prompt), HumanMessage(content=human_prompt)])
    content = response.content

    filled_json = {}
    try:
        if "```json" in content:
            json_str = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            json_str = content.split("```")[1].split("```")[0].strip()
        else:
            json_str = content.strip()
        filled_json = json.loads(json_str)
    except Exception as e:
        logs.append(f"⚠️ [LangGraph LLM 2] JSON parse warning: {e}")

    # Ensure system parameters are injected
    filled_json["auto_submit"] = state.get("auto_submit", False)
    
    # Ensure resume_path is attached
    local_pdf = DATA_DIR / "cv.pdf"
    if local_pdf.exists():
        filled_json["resume_path"] = str(local_pdf.resolve())
        filled_json["cv_path"] = str(local_pdf.resolve())

    # Save filled json
    json_filename = f"payload_{state.get('app_id', 'temp')}_{state.get('retry_count', 0)}.json"
    (DATA_DIR / json_filename).write_text(json.dumps(filled_json, indent=2))

    logs.append(f"✅ [LangGraph LLM 2] Personalized JSON payload mapped ({len(filled_json)} keys).")
    return {
        "filled_json": filled_json,
        "execution_logs": logs
    }


async def execute_script_node(state: JobApplicationState) -> Dict[str, Any]:
    """Node: Dynamically execute the generated Playwright script with the filled JSON."""
    logs = state.get("execution_logs", [])
    logs.append(f"⚡ [LangGraph ExecScript] Executing synthesized Playwright script (Attempt {state.get('retry_count', 0) + 1})...")

    script_code = state.get("script_code", "")
    filled_json = state.get("filled_json", {})
    app_id = state.get("app_id", "temp-app-id")
    screenshot_url = None

    try:
        # 1. Invalidate Python import caches to discover newly generated script file
        importlib.invalidate_caches()

        # 2. Save script to disk and import via importlib
        script_filename = f"script_{state.get('platform_name', 'portal')}_{state.get('retry_count', 0)}.py"
        script_file_path = SCRIPTS_DIR / script_filename
        script_file_path.write_text(script_code)

        module_name = f"dynamic_script_{state.get('platform_name', 'portal')}_{state.get('retry_count', 0)}"
        spec = importlib.util.spec_from_file_location(module_name, str(script_file_path))
        if spec is None or spec.loader is None:
            raise ImportError(f"Failed to create module spec for {script_file_path}")
        
        module = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = module
        spec.loader.exec_module(module)

        if not hasattr(module, "run"):
            raise ValueError("Synthesized script does not define an async 'run(page, data)' entrypoint.")

        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=False,
                args=[
                    # "--headless=new",
                    "--disable-blink-features=AutomationControlled",
                    "--no-sandbox",
                    "--start-maximized"
                ]
            )
            context = await browser.new_context(
                viewport={"width": 1280, "height": 960},
                user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
            )
            page = await context.new_page()
            await page.goto(state["job_url"], wait_until="domcontentloaded")
            await page.wait_for_timeout(3000)

            # Run dynamic script function
            await module.run(page, filled_json)
            await page.wait_for_timeout(3000)

            # Capture verification screenshot
            screenshot_filename = f"langgraph_verify_{app_id}.png"
            local_screenshot = DATA_DIR / screenshot_filename
            await page.screenshot(path=str(local_screenshot), full_page=True)
            screenshot_url = supabase_service.upload_screenshot(local_screenshot, screenshot_filename)

            await browser.close()

        logs.append("🎉 [LangGraph ExecScript] Execution completed successfully!")
        supabase_service.update_application_status(app_id, "submitted" if state.get("auto_submit") else "review_ready", screenshot_url=screenshot_url)

        return {
            "status": "succeeded",
            "screenshot_url": screenshot_url,
            "last_error": None,
            "execution_logs": logs
        }

    except Exception as e:
        err_msg = f"{type(e).__name__}: {str(e)}"
        stack = traceback.format_exc()
        logs.append(f"❌ [LangGraph ExecScript Error]: {err_msg}")
        return {
            "status": "failed",
            "last_error": f"{err_msg}\n{stack}",
            "retry_count": state.get("retry_count", 0) + 1,
            "execution_logs": logs
        }


async def llm_fix_script_node(state: JobApplicationState) -> Dict[str, Any]:
    """Node: LLM 3 (Script Fixer). Self-heal the Playwright script using the error log and traceback."""
    logs = state.get("execution_logs", [])
    logs.append(f"🔧 [LangGraph LLM 3 Fixer] Analyzing error & repairing Playwright script (Retry {state.get('retry_count')}/10)...")

    llm = get_llm()
    system_prompt = """You are an expert Playwright automation debugger.
The previous script failed during execution. Analyze the error traceback, the failed script, and the sanitized HTML.
Fix all invalid selectors, missing timeouts, or incorrect DOM interactions.

OUTPUT FORMAT:
Return ONLY the corrected Python function in a ```python ... ``` block.
Followed by the updated JSON variables schema in a ```json ... ``` block.
"""

    human_prompt = f"""
ERROR TRACEBACK:
{state.get('last_error', '')}

FAILED SCRIPT CODE:
{state.get('script_code', '')}

CURRENT JSON DATA USED:
{json.dumps(state.get('filled_json', {}), indent=2)}

SANITIZED HTML:
{state.get('cleaned_html', '')}
"""

    response = await llm.ainvoke([SystemMessage(content=system_prompt), HumanMessage(content=human_prompt)])
    content = response.content

    script_code = ""
    if "```python" in content:
        script_code = content.split("```python")[1].split("```")[0].strip()
    elif "```" in content:
        script_code = content.split("```")[1].split("```")[0].strip()
    else:
        script_code = content.strip()

    placeholder_schema = state.get("placeholder_schema", {})
    if "```json" in content:
        try:
            json_str = content.split("```json")[1].split("```")[0].strip()
            placeholder_schema = json.loads(json_str).get("variables", placeholder_schema)
        except Exception:
            pass

    logs.append("✅ [LangGraph LLM 3 Fixer] Script repaired. Passing to JSON mapper...")
    return {
        "script_code": script_code,
        "placeholder_schema": placeholder_schema,
        "execution_logs": logs
    }


# ==========================================
# 4. Conditional Edges
# ==========================================
def check_cv_router(state: JobApplicationState) -> str:
    if not state.get("has_cv"):
        return "end_missing_cv"
    return "decide_link"


def execution_outcome_router(state: JobApplicationState) -> str:
    if state.get("status") == "succeeded":
        return "done"
    elif state.get("retry_count", 0) < 10:
        return "fix_script"
    else:
        return "max_retries_exceeded"


# ==========================================
# 5. Build Graph
# ==========================================
def build_job_application_graph():
    workflow = StateGraph(JobApplicationState)

    # Nodes
    workflow.add_node("start_session", start_session_node)
    workflow.add_node("decide_link", decide_link_node)
    workflow.add_node("check_script_db", check_script_node)
    workflow.add_node("fetch_html", fetch_html_node)
    workflow.add_node("llm_gen_script", llm_generate_script_node)
    workflow.add_node("llm_fill_json", llm_fill_json_node)
    workflow.add_node("exec_script", execute_script_node)
    workflow.add_node("llm_fix_script", llm_fix_script_node)

    # Edges
    workflow.set_entry_point("start_session")

    workflow.add_conditional_edges(
        "start_session",
        check_cv_router,
        {
            "end_missing_cv": END,
            "decide_link": "decide_link"
        }
    )

    workflow.add_edge("decide_link", "check_script_db")
    workflow.add_edge("check_script_db", "fetch_html")
    workflow.add_edge("fetch_html", "llm_gen_script")
    workflow.add_edge("llm_gen_script", "llm_fill_json")
    workflow.add_edge("llm_fill_json", "exec_script")

    workflow.add_conditional_edges(
        "exec_script",
        execution_outcome_router,
        {
            "done": END,
            "fix_script": "llm_fix_script",
            "max_retries_exceeded": END
        }
    )

    workflow.add_edge("llm_fix_script", "llm_fill_json")

    return workflow.compile()


job_application_graph = build_job_application_graph()


# ==========================================
# 6. Stream Runner for FastAPI SSE
# ==========================================
async def run_langgraph_application_stream(
    job_url: str,
    user_id: Optional[str] = None,
    auto_submit: bool = False
) -> AsyncGenerator[Dict[str, Any], None]:
    """Stream LangGraph execution events directly to FastAPI SSE."""
    initial_state: JobApplicationState = {
        "job_url": job_url,
        "user_id": user_id,
        "auto_submit": auto_submit,
        "platform_name": "generic",
        "has_cv": False,
        "md_cv": "",
        "profile_data": {},
        "cleaned_html": "",
        "script_code": "",
        "placeholder_schema": {},
        "filled_json": {},
        "execution_logs": [],
        "last_error": None,
        "retry_count": 0,
        "screenshot_url": None,
        "status": "initialized",
        "app_id": "temp-app-id"
    }

    yield {
        "event": "log",
        "data": {"message": f"🚀 Initializing LangGraph Job Automation for: {job_url}"}
    }

    last_log_count = 0
    final_state = initial_state

    try:
        async for output in job_application_graph.astream(initial_state):
            for node_name, node_state in output.items():
                final_state = {**final_state, **node_state}
                logs = final_state.get("execution_logs", [])

                # Stream new logs
                while last_log_count < len(logs):
                    msg = logs[last_log_count]
                    yield {
                        "event": "log",
                        "data": {"message": msg, "node": node_name}
                    }
                    last_log_count += 1

                # Stream step progress
                yield {
                    "event": "step",
                    "data": {
                        "node": node_name,
                        "status": final_state.get("status", "running"),
                        "retry_count": final_state.get("retry_count", 0)
                    }
                }

        # Final Completion
        if final_state.get("status") == "succeeded":
            if final_state.get("screenshot_url"):
                yield {
                    "event": "screenshot",
                    "data": {
                        "screenshot_url": final_state["screenshot_url"],
                        "application_id": final_state.get("app_id"),
                        "message": "Verification receipt screenshot captured."
                    }
                }
            yield {
                "event": "completed",
                "data": {
                    "status": "submitted" if auto_submit else "review_ready",
                    "application_id": final_state.get("app_id"),
                    "screenshot_url": final_state.get("screenshot_url"),
                    "message": "🎉 Application submitted successfully!" if auto_submit else "📋 Application prepared & ready for review!"
                }
            }
        elif final_state.get("status") == "missing_cv":
            yield {
                "event": "error",
                "data": {"message": "⚠️ No CV uploaded yet. Please upload your CV PDF in the Profile tab first."}
            }
        else:
            yield {
                "event": "error",
                "data": {"message": f"❌ Automation failed: {final_state.get('last_error', 'Unknown error')}"}
            }

    except Exception as e:
        yield {
            "event": "error",
            "data": {"message": f"❌ LangGraph Runtime Exception: {str(e)}"}
        }
