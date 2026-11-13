from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.firebase import initialize_firebase
from app.api.routes import chat, tools


def create_application() -> FastAPI:
    """Application factory for Primot AI Backend."""
    app = FastAPI(
        title=settings.APP_NAME,
        version="1.0.0",
        description="FastAPI AI Backend for Primot ERP with multi-tenant company isolation.",
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None,
    )

    # Configure CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Startup event to warm up Firebase SDK
    @app.on_event("startup")
    async def startup_event():
        try:
            initialize_firebase()
        except Exception:
            # Non-blocking on startup if running in mocked/testing mode
            pass

    # Health check
    @app.get("/health", tags=["system"])
    async def health_check():
        return {
            "status": "online",
            "environment": settings.ENVIRONMENT,
            "project_id": settings.FIREBASE_PROJECT_ID,
        }

    # Register API routes
    app.include_router(chat.router)
    app.include_router(tools.router)

    return app


app = create_application()

