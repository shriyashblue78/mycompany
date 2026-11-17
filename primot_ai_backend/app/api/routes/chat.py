import logging
from fastapi import APIRouter, Depends
from app.core.auth import get_current_user
from app.schemas.chat import (
    AuthenticatedUser,
    ChatRequest,
    ChatResponse,
    NavigationAction,
    FormPrefillAction,
    VisualReportAction,
    WorkflowAction,
)
from app.services.chat_service import chat_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="", tags=["chat"])


@router.post("/chat", response_model=ChatResponse)
async def chat_endpoint(
    request: ChatRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> ChatResponse:
    """
    Chat endpoint protected by Firebase Bearer Authentication.
    
    1. Authenticates caller and verifies active tenant company context.
    2. Sends query and approved Phase 2 tool definitions to the local llama.cpp model.
    3. Executes validated tools strictly within caller's company.
    4. Feeds verified data back to model for a grounded natural-language answer.
    """
    logger.info(
        "Chat inquiry received from user %s (role: %s, companyId: %s)",
        current_user.name,
        current_user.role,
        current_user.company_id,
    )

    answer = await chat_service.process_chat(
        user=current_user,
        user_message=request.message,
        history=request.history,
    )

    action_dict = getattr(answer, "action", None)
    action_obj = None
    if action_dict:
        action_type = action_dict.get("action")
        if action_type == "navigate":
            action_obj = NavigationAction(**action_dict)
        elif action_type == "prefill_form":
            action_obj = FormPrefillAction(**action_dict)
        elif action_type == "business_report":
            action_obj = VisualReportAction(**action_dict)
        elif action_type == "workflow_automation":
            action_obj = WorkflowAction(**action_dict)
        else:
            action_obj = action_dict

    return ChatResponse(
        reply=str(answer),
        action=action_obj,
        status="success",
    )
