"""InkFlow AI Gateway — a minimal, stateless router to cloud-tier models.

Scope (Phase 3, locked decision): this gateway never stores notes, memory, or
user profiles. It receives a request, forwards it to a model provider,
streams the response back, and forgets it. See
`ai_prompts/04_phase3_cloud_gateway_router.md` for the full scope boundary.
"""

from __future__ import annotations

from fastapi import FastAPI

from .routers import generate, tools, vision

app = FastAPI(title="InkFlow AI Gateway", version="0.1.0")
app.include_router(generate.router)
app.include_router(tools.router)
app.include_router(vision.router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
