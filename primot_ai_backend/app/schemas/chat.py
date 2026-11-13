from typing import List, Optional
from pydantic import BaseModel, Field


class AuthenticatedUser(BaseModel):
    """
    Internal model representing the verified user context derived from
    Firebase Auth and Firestore users/{uid}.
    """
    uid: str
    company_id: str
    employee_id: str
    role: str
    name: str
    email: str
    status: str
    department: Optional[str] = ""
    designation: Optional[str] = ""


class ChatMessageItem(BaseModel):
    """A prior conversation turn for retaining context in follow-up queries."""
    role: str = Field(..., pattern="^(user|assistant)$", description="Role of the sender ('user' or 'assistant').")
    content: str = Field(..., min_length=1, max_length=4000, description="Message text.")


class ChatRequest(BaseModel):
    """Incoming chat message payload from the client."""
    message: str = Field(..., min_length=1, max_length=2000, description="User prompt or question.")
    history: Optional[List[ChatMessageItem]] = Field(
        default_factory=list,
        description="Optional recent conversation turns for context retention.",
    )


class NavigationAction(BaseModel):
    """Structured navigation payload for the client GoRouter."""
    action: str = Field(default="navigate", description="Action type ('navigate').")
    route: str = Field(..., description="Canonical approved GoRouter route path.")
    title: str = Field(..., description="User-facing title of the target screen.")


class ChatResponse(BaseModel):
    """
    Client-safe chat response.
    Never exposes internal system tokens, secrets, or raw user authentication payloads.
    Includes optional structured action (such as navigation).
    """
    reply: str
    action: Optional[NavigationAction] = None
    status: str = "success"
