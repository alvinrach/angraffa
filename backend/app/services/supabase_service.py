import os
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Optional, Dict, Any
from supabase import create_client, Client
from app.config import SUPABASE_URL, SUPABASE_KEY, DATA_DIR


class BackendSupabaseService:
    def __init__(self):
        if not SUPABASE_URL or not SUPABASE_KEY:
            raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set in environment.")
        self.client: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    def fetch_profile(self, user_id: Optional[str] = None) -> Dict[str, Any]:
        """Fetch profile for user_id or the latest updated profile."""
        query = self.client.table("profiles").select("*")
        if user_id:
            res = query.eq("id", user_id).limit(1).execute()
        else:
            res = query.order("updated_at", desc=True).limit(1).execute()

        if not res.data:
            raise ValueError("No profile found in Supabase database!")
        return res.data[0]

    def download_cv(self, resume_path: str) -> Path:
        """Download CV PDF from Supabase Storage and return local file path."""
        local_path = DATA_DIR / "cv.pdf"
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
            with open(local_path, "wb") as f:
                f.write(cv_bytes)
        return local_path

    def upload_screenshot(self, screenshot_path: Path, filename: str) -> str:
        """Upload a screenshot to the screenshots storage bucket and return public URL."""
        with open(screenshot_path, "rb") as f:
            screenshot_bytes = f.read()

        storage_path = f"app_runs/{filename}"
        try:
            self.client.storage.from_("screenshots").upload(
                storage_path,
                screenshot_bytes,
                file_options={"content-type": "image/png", "upsert": "true"}
            )
        except Exception as e:
            # If bucket doesn't exist or error, return local path representation
            print(f"⚠️ Storage upload warning: {e}")

        # Return public URL
        return f"{SUPABASE_URL}/storage/v1/object/public/screenshots/{storage_path}"

    def create_application_record(
        self,
        user_id: str,
        job_url: str,
        company_name: str = "SmartRecruiters",
        job_title: str = "Automated Application"
    ) -> str:
        """Create a new application tracking record in public.applications table."""
        try:
            res = self.client.table("applications").insert({
                "user_id": user_id,
                "job_url": job_url,
                "company_name": company_name,
                "job_title": job_title,
                "status": "running"
            }).execute()
            if res.data:
                return str(res.data[0].get("id"))
        except Exception as e:
            print(f"⚠️ Application record insert warning: {e}")
        return "temp-app-id"

    def update_application_status(
        self,
        app_id: str,
        status: str,
        screenshot_url: Optional[str] = None
    ):
        """Update status of the application record."""
        try:
            payload = {"status": status}
            if screenshot_url:
                payload["screenshot_url"] = screenshot_url
            self.client.table("applications").update(payload).eq("id", app_id).execute()
        except Exception as e:
            print(f"⚠️ Application status update warning: {e}")


supabase_service = BackendSupabaseService()
