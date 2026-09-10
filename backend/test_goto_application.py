from pathlib import Path

from playwright.sync_api import sync_playwright


URL = "https://jobs.lever.co/GoToGroup/02ee8df1-3120-4f67-8a6d-c5cbaeaef36c/apply"

CV_PATH = Path("/Users/alvinrachmat/angraffa/backend/testdrive/data/cv.pdf")


def test_goto_application_upload_cv():
    with sync_playwright() as p:

        # =========================
        # Launch browser
        # =========================

        browser = p.chromium.launch(
            headless=False,
            args=["--start-maximized"]
        )

        page = browser.new_page(
            viewport=None
        )

        # =========================
        # Open application page
        # =========================

        page.goto(
            URL,
            wait_until="domcontentloaded"
        )

        page.wait_for_load_state("networkidle")

        print("Page:", page.title())

        # =========================
        # Check CV
        # =========================

        assert CV_PATH.exists(), f"CV not found: {CV_PATH}"

        # =========================
        # Upload CV
        # =========================

        file_input = page.locator(
            'input[type="file"]'
        ).first

        print(
            "File inputs:",
            page.locator('input[type="file"]').count()
        )

        file_input.set_input_files(
            str(CV_PATH)
        )

        print("CV uploaded successfully!")

        # Wait for CV processing
        page.wait_for_timeout(10000)

        # =========================
        # Screenshot after upload
        # =========================

        page.screenshot(
            path="testdrive/goto-cv-uploaded.png",
            full_page=True,
        )

        # =========================
        # Work Eligibility
        # =========================

        comboboxes = page.get_by_role(
            "combobox"
        )

        print(
            "Combobox count:",
            comboboxes.count()
        )

        # Work Eligibility = combobox kedua
        work_eligibility = comboboxes.nth(1)

        # Scroll to Work Eligibility
        work_eligibility.scroll_into_view_if_needed()

        # Make browser active
        page.bring_to_front()

        page.wait_for_timeout(1000)

        # Open dropdown
        work_eligibility.click()

        print("Work Eligibility dropdown opened!")

        # Select option
        page.get_by_text(
            "Yes, by way of having a work permit",
            exact=True
        ).click()

        print(
            "Work Eligibility selected: "
            "Yes, by way of having a work permit"
        )

        # =========================
        # Keep browser open
        # =========================

        page.wait_for_timeout(30000)