import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from dotenv import load_dotenv
from playwright.sync_api import sync_playwright
from supabase import create_client, Client

# Unbuffered stdout
sys.stdout.reconfigure(line_buffering=True)

# Load environment variables from backend/.env
ENV_PATH = Path(__file__).resolve().parent.parent.parent / ".env"
load_dotenv(dotenv_path=ENV_PATH)

JOB_URL = os.getenv(
    "SMARTRECRUITERS_JOB_URL",
    "https://jobs.smartrecruiters.com/oneclick-ui/company/DeliveryHero/publication/84bc4187-c445-4d42-8825-181052cb6751?dcr_ci=DeliveryHero"
)
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")

DATA_DIR = Path(__file__).parent.parent / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)
LOCAL_CV_PATH = DATA_DIR / "cv.pdf"


def fetch_profile_and_cv():
    print("🔹 Connecting to Supabase...")
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    res = supabase.table("profiles").select("*").order("updated_at", desc=True).limit(1).execute()
    if not res.data:
        raise ValueError("No profile found in Supabase database!")
    profile = res.data[0]
    print(f"✅ Found Profile: {profile.get('first_name')} {profile.get('last_name')} ({profile.get('email')})")
    
    resume_path = profile.get("resume_path")
    if not resume_path:
        raise ValueError("Profile does not have a resume_path set!")
    
    encoded_path = urllib.parse.quote(resume_path)
    download_url = f"{SUPABASE_URL}/storage/v1/object/authenticated/resumes/{encoded_path}"
    req = urllib.request.Request(
        download_url,
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}"
        }
    )
    with urllib.request.urlopen(req) as response:
        cv_bytes = response.read()
        with open(LOCAL_CV_PATH, "wb") as f:
            f.write(cv_bytes)
    print(f"✅ CV saved to {LOCAL_CV_PATH} ({len(cv_bytes)} bytes)")
    return profile


def select_combobox_option(page, input_locator, fallback_text=None):
    """Click a SmartRecruiters combobox and pick the best matching or first valid option."""
    try:
        input_locator.scroll_into_view_if_needed()
        input_locator.click(force=True)
        page.wait_for_timeout(600)
        
        # Look for dropdown list options
        options = page.locator('.c-spl-select__option, .c-spl-autocomplete__list-item, [role="option"], ul li')
        count = options.count()
        if count > 0:
            # Pick first visible option with non-empty text
            for i in range(count):
                opt = options.nth(i)
                if opt.is_visible() and opt.inner_text().strip():
                    text = opt.inner_text().strip()
                    opt.click()
                    print(f"    ✅ Selected dropdown: \"{text}\"")
                    page.wait_for_timeout(300)
                    return text
        
        # Fallback: keyboard navigation
        input_locator.press("ArrowDown")
        page.wait_for_timeout(200)
        input_locator.press("Enter")
        print("    ✅ Selected via ArrowDown+Enter")
    except Exception as e:
        if fallback_text:
            try:
                input_locator.fill(fallback_text)
                print(f"    ⚠️ Fallback filled: {fallback_text}")
            except Exception:
                pass
        print(f"    ⚠️ Combobox error: {e}")


def test_smartrecruiter_application():
    profile = fetch_profile_and_cv()

    with sync_playwright() as p:
        print("\n🚀 Launching Chromium (Stealth Non-Headless)...")
        browser = p.chromium.launch(
            headless=False,
            args=[
                "--disable-blink-features=AutomationControlled",
                "--no-sandbox",
                "--start-maximized"
            ]
        )
        context = browser.new_context(
            viewport={"width": 1280, "height": 960},
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
        )
        page = context.new_page()

        print(f"🌐 Navigating to: {JOB_URL}")
        page.goto(JOB_URL, wait_until="domcontentloaded")
        page.wait_for_timeout(3000)
        print(f"📄 Page Title: {page.title()}")

        # ==========================================
        # STEP 1: Upload CV to Resume Input
        # ==========================================
        print("\n📎 Step 1: Uploading CV to mandatory Resume attachment...")
        file_inputs = page.locator('input[type="file"]').all()
        if file_inputs:
            file_inputs[-1].set_input_files(str(LOCAL_CV_PATH))
            print("  ✅ CV attached to Resume field.")
            page.wait_for_timeout(1500)

        # ==========================================
        # STEP 1: Fill Personal Information
        # ==========================================
        print("\n✍️ Step 1: Filling Personal Information from Supabase Profile...")
        page.locator("input#first-name-input").fill(profile.get("first_name") or "Alvin")
        page.locator("input#last-name-input").fill(profile.get("last_name") or "Rachmat")
        email = profile.get("email") or "alvinracht@gmail.com"
        page.locator("input#email-input").fill(email)
        page.locator("input#confirm-email-input").fill(email)

        city = profile.get("city") or "Abu Dhabi"
        city_input = page.locator('input[placeholder*="Search"], [data-test*="location"] input, input[id*="spl-form"]').first
        city_input.fill(city)
        page.wait_for_timeout(1200)
        autocomplete_option = page.locator(".c-spl-autocomplete__list-item, .pac-item, [role=\"option\"]").first
        if autocomplete_option.count() > 0 and autocomplete_option.is_visible():
            autocomplete_option.click()
            print(f"  ✅ Selected City: {city}")

        phone_num = profile.get("phone_number") or "502140290"
        phone_input = page.locator('input[type="tel"]')
        if phone_input.count() > 0:
            phone_input.fill(phone_num)
            print(f"  ✅ Filled Phone: {phone_num}")

        linkedin = profile.get("linkedin_url") or "https://www.linkedin.com/in/alvin-rachmat"
        linkedin_input = page.locator("input#linkedin-input")
        if linkedin_input.count() > 0:
            linkedin_input.fill(linkedin)
            print(f"  ✅ Filled LinkedIn: {linkedin}")

        page.wait_for_timeout(800)

        # ==========================================
        # STEP 1 -> STEP 2 Transition
        # ==========================================
        print("\n➡️ Advancing to Step 2...")
        next_btn = page.locator('button:has-text("Next"), spl-button:has-text("Next")').first
        next_btn.scroll_into_view_if_needed()
        page.wait_for_timeout(500)
        next_btn.click(force=True)
        
        # Wait for Step 2 elements to mount
        page.wait_for_selector('textarea', timeout=15000)
        page.wait_for_timeout(1500)
        print("✅ Step 2 DOM mounted successfully!")

        # ==========================================
        # STEP 2: Radios (No to all 3)
        # ==========================================
        print("\n🔘 Step 2: Clicking 'No' to screening radio questions...")
        no_radios = page.locator('label:has-text("No"), input[type="radio"][value="false"]').all()
        for i, r in enumerate(no_radios):
            try:
                r.scroll_into_view_if_needed()
                r.click(timeout=1000)
                print(f"  • Radio {i+1} -> No")
            except Exception as e:
                print(f"  ⚠️ Radio {i+1} error: {e}")

        # ==========================================
        # ==========================================
        # STEP 2: Textarea Pitch
        # ==========================================
        print("\n📝 Step 2: Filling skillset match pitch...")
        answers = profile.get("answers_json") or {}
        nationality = answers.get("nationality", "Indonesian")
        visa_status = answers.get("visa_status", "Resident Visa")
        marital_status = answers.get("marital_status", "Single")
        reason_to_join = answers.get("reason_to_join", "Career growth - this role will be a step up for me")
        notice_period = answers.get("notice_period", "1 month")
        start_date = answers.get("start_date", answers.get("earliest_start_date", "01/10/2026"))
        current_salary = answers.get("current_salary", "AED 25,000")
        expected_salary = answers.get("expected_salary", "AED 30,000")
        gender = answers.get("gender", "Male")
        skillset_pitch = answers.get(
            "skillset_pitch",
            "Senior Data Scientist with 7+ years of experience in ML engineering, predictive modeling, and scalable real-time analytics aligned with talabat and Delivery Hero platforms."
        )

        textareas = page.locator("textarea").all()
        if textareas:
            textareas[0].scroll_into_view_if_needed()
            textareas[0].fill(skillset_pitch)
            print(f"  ✅ Pitch filled ({len(skillset_pitch)} characters).")

        # ==========================================
        # STEP 2: Text Inputs & Comboboxes by Exact Sequence
        # ==========================================
        print("\n✍️ Step 2: Filling Screening Questions & Dropdowns from Profile Answers...")
        visible_text_inputs = [inp for inp in page.locator('input[type="text"]').all() if inp.is_visible()]
        print(f"  Found {len(visible_text_inputs)} visible text/combobox fields.")

        # Input [1]: Nationality
        if len(visible_text_inputs) > 1:
            visible_text_inputs[1].scroll_into_view_if_needed()
            visible_text_inputs[1].fill(nationality)
            print(f"  • [1] Nationality: {nationality}")

        # Input [2]: Visa status (Combobox)
        if len(visible_text_inputs) > 2:
            print(f"  • [2] Selecting Visa status ({visa_status}):")
            select_combobox_option(page, visible_text_inputs[2], fallback_text=visa_status)

        # Input [3]: Marital status (Combobox)
        if len(visible_text_inputs) > 3:
            print(f"  • [3] Selecting Marital status ({marital_status}):")
            select_combobox_option(page, visible_text_inputs[3], fallback_text=marital_status)

        # Input [4]: Reason to join (Combobox)
        if len(visible_text_inputs) > 4:
            print(f"  • [4] Selecting Reason to join ({reason_to_join}):")
            select_combobox_option(page, visible_text_inputs[4], fallback_text=reason_to_join)

        # Input [5]: Notice Period
        if len(visible_text_inputs) > 5:
            visible_text_inputs[5].scroll_into_view_if_needed()
            visible_text_inputs[5].fill(notice_period)
            print(f"  • [5] Notice period: {notice_period}")

        # Input [6]: Earliest Start Date
        if len(visible_text_inputs) > 6:
            visible_text_inputs[6].scroll_into_view_if_needed()
            visible_text_inputs[6].fill(start_date)
            print(f"  • [6] Earliest start date: {start_date}")

        # Input [7]: Current Monthly Salary
        if len(visible_text_inputs) > 7:
            visible_text_inputs[7].scroll_into_view_if_needed()
            visible_text_inputs[7].fill(current_salary)
            print(f"  • [7] Current monthly salary: {current_salary}")

        # Input [8]: Expected Monthly Salary
        if len(visible_text_inputs) > 8:
            visible_text_inputs[8].scroll_into_view_if_needed()
            visible_text_inputs[8].fill(expected_salary)
            print(f"  • [8] Expected monthly salary: {expected_salary}")

        # Input [9]: Gender (Combobox)
        if len(visible_text_inputs) > 9:
            print(f"  • [9] Selecting Gender ({gender}):")
            select_combobox_option(page, visible_text_inputs[9], fallback_text=gender)

        # ==========================================
        # STEP 2: Consent Checkbox
        # ==========================================
        print("\n☑️ Step 2: Checking Privacy Consent Checkbox...")
        checkboxes = page.locator('input[type="checkbox"]').all()
        for cb in checkboxes:
            try:
                cb.scroll_into_view_if_needed()
                cb.check(timeout=1500)
                print("  ✅ Checked privacy consent.")
            except Exception as e:
                print(f"  ⚠️ Checkbox error: {e}")

        page.wait_for_timeout(2000)

        # ==========================================
        # Step 2 Verification Screenshot
        # ==========================================
        screenshot_path = Path(__file__).parent / "smartrecruiter_complete_success.png"
        page.screenshot(path=str(screenshot_path), full_page=True)
        print(f"\n🎉 FULL APPLICATION FILLED! Screenshot saved to:\n   {screenshot_path}")

        print("\n👀 Keeping browser open for 15 seconds so you can see the result...")
        page.wait_for_timeout(15000)

        browser.close()
        print("✅ Finished test successfully.")


if __name__ == "__main__":
    test_smartrecruiter_application()
