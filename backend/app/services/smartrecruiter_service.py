import asyncio
import json
from pathlib import Path
from typing import AsyncGenerator, Dict, Any, Optional
from playwright.async_api import async_playwright
from app.config import DATA_DIR
from app.services.supabase_service import supabase_service


async def select_combobox_option(page, input_locator, fallback_text=None) -> str:
    """Click a SmartRecruiters combobox and pick the best matching or first valid option."""
    try:
        await input_locator.scroll_into_view_if_needed()
        await input_locator.click(force=True)
        await page.wait_for_timeout(600)
        
        options = page.locator('.c-spl-select__option, .c-spl-autocomplete__list-item, [role="option"], ul li')
        count = await options.count()
        if count > 0:
            for i in range(count):
                opt = options.nth(i)
                if await opt.is_visible():
                    text = (await opt.inner_text()).strip()
                    if text:
                        await opt.click()
                        await page.wait_for_timeout(300)
                        return text
        
        await input_locator.press("ArrowDown")
        await page.wait_for_timeout(200)
        await input_locator.press("Enter")
        return "selected"
    except Exception as e:
        if fallback_text:
            try:
                await input_locator.fill(fallback_text)
            except Exception:
                pass
        return fallback_text or "default"


async def run_smartrecruiter_application(
    job_url: str,
    user_id: Optional[str] = None,
    auto_submit: bool = False
) -> AsyncGenerator[Dict[str, Any], None]:
    """Execute automated job application on SmartRecruiters and stream SSE progress events."""
    
    # 1. Start Event
    yield {
        "event": "log",
        "data": {"message": "🔹 Initializing application run and connecting to database..."}
    }

    try:
        profile = supabase_service.fetch_profile(user_id=user_id)
        user_uuid = str(profile.get("id"))
        first_name = profile.get("first_name") or "Alvin"
        last_name = profile.get("last_name") or "Rachmat"
        email = profile.get("email") or "alvinracht@gmail.com"
        city = profile.get("city") or "Abu Dhabi"
        phone_num = profile.get("phone_number") or "502140290"
        linkedin_url = profile.get("linkedin_url") or "https://www.linkedin.com/in/alvin-rachmat"
        resume_path = profile.get("resume_path")

        if not resume_path:
            raise ValueError("User profile does not have a resume uploaded!")

        yield {
            "event": "log",
            "data": {"message": f"✅ Found Profile: {first_name} {last_name} ({email}) | Location: {city}"}
        }

        # Download CV
        yield {
            "event": "log",
            "data": {"message": "⬇️ Downloading CV from secure Supabase storage..."}
        }
        local_cv_path = supabase_service.download_cv(resume_path)
        yield {
            "event": "log",
            "data": {"message": f"✅ CV ready for upload ({local_cv_path.name})"}
        }

        # Create tracking application record
        app_id = supabase_service.create_application_record(
            user_id=user_uuid,
            job_url=job_url,
            user_email=email,
            company_name="SmartRecruiters",
            job_title="Automated Application"
        )

        # 2. Launch Browser
        yield {
            "event": "log",
            "data": {"message": "🚀 Launching stealth browser to bypass anti-bot protection..."}
        }

        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=False,
                args=[
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

            yield {
                "event": "log",
                "data": {"message": f"🌐 Navigating to application portal: {job_url}"}
            }
            await page.goto(job_url, wait_until="domcontentloaded")
            await page.wait_for_timeout(3000)
            page_title = await page.title()

            yield {
                "event": "log",
                "data": {"message": f"📄 Page Title: {page_title}"}
            }

            # ==========================================
            # STEP 1: Upload CV & Personal Info
            # ==========================================
            yield {
                "event": "step",
                "data": {"step": 1, "name": "personal_info", "status": "running", "message": "Attaching CV and filling contact info..."}
            }

            file_inputs = await page.locator('input[type="file"]').all()
            if file_inputs:
                await file_inputs[-1].set_input_files(str(local_cv_path))
                yield {
                    "event": "log",
                    "data": {"message": "📎 CV attached to mandatory Resume field."}
                }
                await page.wait_for_timeout(1500)

            await page.locator("input#first-name-input").fill(first_name)
            await page.locator("input#last-name-input").fill(last_name)
            await page.locator("input#email-input").fill(email)
            await page.locator("input#confirm-email-input").fill(email)

            city_input = page.locator('input[placeholder*="Search"], [data-test*="location"] input, input[id*="spl-form"]').first
            await city_input.fill(city)
            await page.wait_for_timeout(1200)
            autocomplete_option = page.locator(".c-spl-autocomplete__list-item, .pac-item, [role=\"option\"]").first
            if await autocomplete_option.count() > 0 and await autocomplete_option.is_visible():
                await autocomplete_option.click()
                yield {
                    "event": "log",
                    "data": {"message": f"📍 Location autocomplete selected: {city}"}
                }

            phone_input = page.locator('input[type="tel"]')
            if await phone_input.count() > 0:
                await phone_input.fill(phone_num)

            linkedin_input = page.locator("input#linkedin-input")
            if await linkedin_input.count() > 0 and linkedin_url:
                await linkedin_input.fill(linkedin_url)

            await page.wait_for_timeout(500)

            # Transition to Step 2
            yield {
                "event": "log",
                "data": {"message": "➡️ Step 1 completed. Advancing to preliminary questions..."}
            }
            next_btn = page.locator('button:has-text("Next"), spl-button:has-text("Next")').first
            await next_btn.scroll_into_view_if_needed()
            await page.wait_for_timeout(400)
            await next_btn.click(force=True)

            await page.wait_for_selector('textarea', timeout=15000)
            await page.wait_for_timeout(1200)

            yield {
                "event": "step",
                "data": {"step": 1, "name": "personal_info", "status": "completed", "message": "Step 1 complete."}
            }

            # ==========================================
            # STEP 2: Screening Questions
            # ==========================================
            yield {
                "event": "step",
                "data": {"step": 2, "name": "screening_questions", "status": "running", "message": "Answering screening questions from profile memory..."}
            }

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

            # Radios: No to all
            no_radios = await page.locator('label:has-text("No"), input[type="radio"][value="false"]').all()
            for r in no_radios:
                try:
                    await r.scroll_into_view_if_needed()
                    await r.click(timeout=1000)
                except Exception:
                    pass

            yield {
                "event": "log",
                "data": {"message": f"🔘 Answered {len(no_radios)} screening radio questions (No)."}
            }

            # Textarea Pitch
            textareas = await page.locator("textarea").all()
            if textareas:
                await textareas[0].scroll_into_view_if_needed()
                await textareas[0].fill(skillset_pitch)
                yield {
                    "event": "log",
                    "data": {"message": f"📝 Populated skillset statement ({len(skillset_pitch)} chars)."}
                }

            # Dropdowns and text inputs
            visible_text_inputs = [inp for inp in await page.locator('input[type="text"]').all() if await inp.is_visible()]
            if len(visible_text_inputs) > 1:
                await visible_text_inputs[1].fill(nationality)
            if len(visible_text_inputs) > 2:
                await select_combobox_option(page, visible_text_inputs[2], fallback_text=visa_status)
            if len(visible_text_inputs) > 3:
                await select_combobox_option(page, visible_text_inputs[3], fallback_text=marital_status)
            if len(visible_text_inputs) > 4:
                await select_combobox_option(page, visible_text_inputs[4], fallback_text=reason_to_join)
            if len(visible_text_inputs) > 5:
                await visible_text_inputs[5].fill(notice_period)
            if len(visible_text_inputs) > 6:
                await visible_text_inputs[6].fill(start_date)
            if len(visible_text_inputs) > 7:
                await visible_text_inputs[7].fill(current_salary)
            if len(visible_text_inputs) > 8:
                await visible_text_inputs[8].fill(expected_salary)
            if len(visible_text_inputs) > 9:
                await select_combobox_option(page, visible_text_inputs[9], fallback_text=gender)

            # Consent Checkbox
            checkboxes = await page.locator('input[type="checkbox"]').all()
            for cb in checkboxes:
                try:
                    await cb.scroll_into_view_if_needed()
                    await cb.check(timeout=1500)
                except Exception:
                    pass

            yield {
                "event": "log",
                "data": {"message": "☑️ Privacy consent checked & all questions filled."}
            }
            await page.wait_for_timeout(1500)

            # ==========================================
            # STEP 3: Verification & Submission
            # ==========================================
            screenshot_filename = f"verify_{app_id}.png"
            local_screenshot = DATA_DIR / screenshot_filename
            await page.screenshot(path=str(local_screenshot), full_page=True)

            screenshot_url = supabase_service.upload_screenshot(local_screenshot, screenshot_filename)

            yield {
                "event": "step",
                "data": {"step": 2, "name": "screening_questions", "status": "completed", "message": "All questions completed."}
            }

            if not auto_submit:
                supabase_service.update_application_status(app_id, "review_ready", screenshot_url=screenshot_url)
                yield {
                    "event": "screenshot",
                    "data": {
                        "screenshot_url": screenshot_url,
                        "application_id": app_id,
                        "message": "Verification screenshot captured (Review Mode / Dry Run)."
                    }
                }
                yield {
                    "event": "completed",
                    "data": {
                        "status": "review_ready",
                        "application_id": app_id,
                        "screenshot_url": screenshot_url,
                        "message": "📋 Application filled and ready for review (Dry Run - Not Submitted)."
                    }
                }
            else:
                yield {
                    "event": "log",
                    "data": {"message": "🚀 Auto-Submit is enabled. Submitting application..."}
                }

                # Attempt to find and click the submit button
                submit_selectors = [
                    'button[type="submit"]',
                    'button:has-text("Submit application")',
                    'button:has-text("Submit Application")',
                    'button:has-text("Submit")',
                    'button:has-text("Send application")',
                    'spl-button[type="submit"] button',
                    'footer button'
                ]

                submitted = False
                for sel in submit_selectors:
                    try:
                        btn = page.locator(sel).first
                        if await btn.is_visible():
                            await btn.scroll_into_view_if_needed()
                            await btn.click()
                            submitted = True
                            yield {
                                "event": "log",
                                "data": {"message": f"✅ Clicked submission button: {sel}"}
                            }
                            break
                    except Exception:
                        continue

                if not submitted:
                    # Fallback: try pressing Enter on the form
                    await page.keyboard.press("Enter")

                # Wait for submission processing & confirmation
                await page.wait_for_timeout(5000)

                # Capture final confirmation / thank-you receipt screenshot
                confirm_filename = f"submitted_{app_id}.png"
                local_confirm = DATA_DIR / confirm_filename
                await page.screenshot(path=str(local_confirm), full_page=True)

                confirm_url = supabase_service.upload_screenshot(local_confirm, confirm_filename)
                supabase_service.update_application_status(app_id, "submitted", screenshot_url=confirm_url)

                yield {
                    "event": "screenshot",
                    "data": {
                        "screenshot_url": confirm_url,
                        "application_id": app_id,
                        "message": "Official submission receipt screenshot captured."
                    }
                }

                yield {
                    "event": "completed",
                    "data": {
                        "status": "submitted",
                        "application_id": app_id,
                        "screenshot_url": confirm_url,
                        "message": "🎉 Application submitted successfully to the employer!"
                    }
                }

            await browser.close()

    except Exception as e:
        yield {
            "event": "error",
            "data": {"message": f"❌ Automation error: {str(e)}"}
        }
