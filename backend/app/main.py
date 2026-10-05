import json
import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from sse_starlette.sse import EventSourceResponse

from app.config import HOST, PORT
from app.schemas.application import ApplyRequest, HealthResponse
from app.services.langgraph_service import run_langgraph_application_stream
from app.services.cv_service import cv_parser_service

app = FastAPI(
    title="JobAgent Automation API",
    version="1.0.0",
    description="LangGraph Autonomous Self-Healing Job Application Engine"
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


@app.post("/api/cv/convert-md")
async def convert_cv_to_markdown(payload: dict = {}):
    """
    One-time CV conversion endpoint: downloads user's PDF resume and parses to Markdown using pymupdf4llm.
    """
    user_id = payload.get("user_id")
    try:
        result = cv_parser_service.process_and_save_user_cv(user_id=user_id)
        return result
    except Exception as e:
        return {"status": "error", "message": str(e)}


@app.post("/api/apply")
async def apply_to_job(payload: ApplyRequest):
    """
    Trigger automated job application using LangGraph StateGraph engine and stream SSE events.
    """
    async def event_generator():
        async for item in run_langgraph_application_stream(
            job_url=payload.job_url,
            user_id=payload.user_id,
            auto_submit=payload.auto_submit
        ):
            yield {
                "event": item.get("event", "message"),
                "data": json.dumps(item.get("data", {}))
            }

    return EventSourceResponse(event_generator())


if __name__ == "__main__":
    uvicorn.run("app.main:app", host=HOST, port=PORT, reload=True)

