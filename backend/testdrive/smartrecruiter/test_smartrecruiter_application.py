import os
import urllib.parse
import urllib.request
from pathlib import Path
from dotenv import load_dotenv
from playwright.sync_api import sync_playwright
from supabase import create_client, Client

# Load environment variables from backend/.env
ENV_PATH = Path(__file__).resolve().parent.parent.parent / ".env"
load_dotenv(dotenv_path=ENV_PATH)

# ==========================================
# Configuration & Target Job
# ==========================================
JOB_URL = os.getenv(
    "SMARTRECRUITERS_JOB_URL",
    "https://jobs.smartrecruiters.com/oneclick-ui/company/DeliveryHero/publication/84bc4187-c445-4d42-8825-181052cb6751?dcr_ci=DeliveryHero"
)
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError(f"SUPABASE_URL and SUPABASE_KEY must be set in {ENV_PATH}")

DATA_DIR = Path(__file__).parent.parent / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)
LOCAL_CV_PATH = DATA_DIR / "cv.pdf"


def fetch_profile_and_cv():
    """Fetch latest profile from Supabase and download the user's CV PDF."""
    print("🔹 Connecting to Supabase...")
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # Query latest profile
    res = supabase.table("profiles").select("*").order("updated_at", desc=True).limit(1).execute()
    if not res.data:
        raise ValueError("No profile found in Supabase database!")
    
    profile = res.data[0]
    print(f"✅ Found Profile: {profile.get('first_name')} {profile.get('last_name')} ({profile.get('email')})")
    print(f"📍 Location: {profile.get('city')}, {profile.get('country')}")
    print(f"📞 Phone: {profile.get('phone_country_code')} {profile.get('phone_number')}")
    
    resume_path = profile.get("resume_path")
    if not resume_path:
        raise ValueError("Profile does not have a resume_path set!")
    
    # Download CV if not locally present or always refresh
    print(f"⬇️ Downloading CV from Supabase Storage: {resume_path}...")
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


def test_smartrecruiter_application():
    profile = fetch_profile_and_cv()

    with sync_playwright() as p:
        print("\n🚀 Launching Chromium (Non-Headless with anti-bot bypass)...")
        browser = p.chromium.launch(
            headless=False,
            args=[
                "--disable-blink-features=AutomationControlled",
                "--no-sandbox",
                "--start-maximized"
            ]
        )
        context = browser.new_context(
            viewport=None,
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
        print("\n📎 Uploading CV...")
        file_inputs = page.locator('input[type="file"]').all()
        if file_inputs:
            # The bottom file input is the mandatory Resume attachment
            resume_input = file_inputs[-1]
            resume_input.set_input_files(str(LOCAL_CV_PATH))
            print("✅ CV attached to Resume field.")
            page.wait_for_timeout(2000)

        # ==========================================
        # STEP 2: Fill Personal Information
        # ==========================================
        print("\n✍️ Filling Personal Information from Supabase Profile...")

        # First Name
        first_name = profile.get("first_name") or "Alvin"
        page.locator("input#first-name-input").fill(first_name)
        print(f"  • First Name: {first_name}")

        # Last Name
        last_name = profile.get("last_name") or "Rachmat"
        page.locator("input#last-name-input").fill(last_name)
        print(f"  • Last Name: {last_name}")

        # Email & Confirm Email
        email = profile.get("email") or "alvinracht@gmail.com"
        page.locator("input#email-input").fill(email)
        page.locator("input#confirm-email-input").fill(email)
        print(f"  • Email: {email}")

        # City / Location with Autocomplete Dropdown
        city = profile.get("city") or "Abu Dhabi"
        print(f"  • City: {city} (typing and selecting autocomplete...)")
        city_input = page.locator('input[placeholder*="Search"], [data-test*="location"] input, input[id*="spl-form"]').first
        city_input.fill(city)
        page.wait_for_timeout(1500)
        
        # Click the first autocomplete match if visible
        autocomplete_option = page.locator(".c-spl-autocomplete__list-item, .pac-item, [role=\"option\"]").first
        if autocomplete_option.count() > 0 and autocomplete_option.is_visible():
            autocomplete_option.click()
            print("    ✅ Clicked city autocomplete dropdown.")

        # Phone Number
        phone_num = profile.get("phone_number") or "502140290"
        phone_input = page.locator('input[type="tel"]')
        if phone_input.count() > 0:
            phone_input.fill(phone_num)
            print(f"  • Phone Number: {phone_num}")

        # LinkedIn
        linkedin = profile.get("linkedin_url")
        if linkedin:
            linkedin_input = page.locator("input#linkedin-input")
            if linkedin_input.count() > 0:
                linkedin_input.fill(linkedin)
                print(f"  • LinkedIn: {linkedin}")

        page.wait_for_timeout(1000)

        # ==========================================
        # STEP 3: Advance to Step 2 (Next Button)
        # ==========================================
        print("\n➡️ Clicking 'Next' button...")
        next_btn = page.locator('button:has-text("Next"), spl-button:has-text("Next")').first
        next_btn.scroll_into_view_if_needed()
        page.wait_for_timeout(500)
        next_btn.click()
        page.wait_for_timeout(5000)

        # ==========================================
        # STEP 4: Verification Screenshot
        # ==========================================
        screenshot_path = Path(__file__).parent / "smartrecruiter_step2.png"
        page.screenshot(path=str(screenshot_path), full_page=True)
        print(f"📸 Screenshot of Step 2 saved to: {screenshot_path}")

        print("\n👀 Keeping browser open for 30 seconds so you can see the result...")
        page.wait_for_timeout(30000)

        browser.close()
        print("✅ Finished test successfully.")


if __name__ == "__main__":
    test_smartrecruiter_application()
