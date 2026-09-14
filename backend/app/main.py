import json
import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from sse_starlette.sse import EventSourceResponse

from app.config import HOST, PORT
from app.schemas.application import ApplyRequest, HealthResponse
from app.services.smartrecruiter_service import run_smartrecruiter_application

app = FastAPI(
    title="JobAgent Automation API",
    version="1.0.0",
    description="Automated Job Application Engine with Playwright & Supabase"
)

# Enable CORS for iOS Simulator and external requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for the automation server."""
    return HealthResponse(
        status="healthy",
        service="jobagent-backend",
        version="1.0.0"
    )


@app.post("/api/apply")
async def apply_to_job(payload: ApplyRequest):
    """
    Trigger automated job application for the given job_url and stream real-time SSE progress events.
    """
    async def event_generator():
        async for item in run_smartrecruiter_application(
            job_url=payload.job_url,
            user_id=payload.user_id
        ):
            yield {
                "event": item.get("event", "message"),
                "data": json.dumps(item.get("data", {}))
            }

    return EventSourceResponse(event_generator())


if __name__ == "__main__":
    uvicorn.run("app.main:app", host=HOST, port=PORT, reload=True)
