from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class ApplyRequest(BaseModel):
    job_url: str = Field(..., description="Target job application URL")
    user_id: Optional[str] = Field(None, description="Supabase Auth User ID")


class StreamEvent(BaseModel):
    event: str = Field(..., description="Event type: log, step, screenshot, completed, error")
    data: Dict[str, Any] = Field(default_factory=dict)


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
