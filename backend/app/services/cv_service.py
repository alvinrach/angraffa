import io
from pathlib import Path
from typing import Optional, Dict, Any
import pymupdf4llm

from app.services.supabase_service import supabase_service


class CVParserService:
    @staticmethod
    def convert_pdf_to_markdown(pdf_source: Any) -> str:
        """
        Convert a PDF file path or byte stream into structured Markdown text using pymupdf4llm.
        """
        if isinstance(pdf_source, (str, Path)):
            return pymupdf4llm.to_markdown(str(pdf_source))
        elif isinstance(pdf_source, (bytes, bytearray)):
            import fitz
            doc = fitz.open(stream=pdf_source, filetype="pdf")
            return pymupdf4llm.to_markdown(doc)
        else:
            raise ValueError("Unsupported PDF source type for Markdown conversion.")

    def process_and_save_user_cv(self, user_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Fetch the user's PDF resume from Supabase, convert to Markdown, and save back to profiles table.
        """
        profile = supabase_service.fetch_profile(user_id=user_id)
        user_uuid = str(profile.get("id"))
        resume_path = profile.get("resume_path")

        if not resume_path:
            raise ValueError("No resume PDF found in user profile. Please upload a CV first.")

        # Download PDF from Supabase
        local_pdf_path = supabase_service.download_cv(resume_path)
        
        # Convert to Markdown
        md_content = self.convert_pdf_to_markdown(local_pdf_path)

        # Save to Supabase profile (in answers_json["resume_markdown"])
        answers = profile.get("answers_json") or {}
        answers["resume_markdown"] = md_content

        update_payload = {"answers_json": answers}
        try:
            supabase_service.client.table("profiles").update(update_payload).eq("id", user_uuid).execute()
        except Exception as e:
            print(f"⚠️ Profile update warning while saving Markdown CV: {e}")

        return {
            "status": "success",
            "user_id": user_uuid,
            "resume_path": resume_path,
            "markdown_length": len(md_content),
            "markdown_preview": md_content[:300]
        }


cv_parser_service = CVParserService()
