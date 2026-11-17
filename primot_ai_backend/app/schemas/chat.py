from typing import Any, Dict, List, Optional, Union
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


class FormPrefillAction(BaseModel):
    """Structured form prefilling action for creating or editing ERP records."""
    action: str = Field(default="prefill_form", description="Action type ('prefill_form').")
    module: str = Field(..., description="Canonical module identifier ('parties', 'items', 'employees', 'sales', 'purchases').")
    operation: str = Field(..., description="Operation type ('create' or 'edit').")
    route: str = Field(..., description="Canonical approved GoRouter form route.")
    record_id: Optional[str] = Field(default=None, description="Firestore document ID for edits.")
    record_title: Optional[str] = Field(default=None, description="Title/name of the record being created or edited.")
    fields: Dict[str, Any] = Field(default_factory=dict, description="Pre-filled/modified form fields.")
    missing_fields: List[str] = Field(default_factory=list, description="Mandatory fields that remain unpopulated.")
    title: str = Field(..., description="User-facing title for the form action.")


class VisualReportAction(BaseModel):
    """Structured report data payload for displaying interactive charts/tables in chat."""
    action: str = Field(default="business_report", description="Action type ('business_report').")
    report_type: str = Field(..., description="Report type ('sales_summary', 'purchase_summary', 'sales_comparison', 'purchase_comparison', 'party_insights', 'inventory_insights').")
    title: str = Field(..., description="Report title.")
    subtitle: Optional[str] = Field(default="", description="Period or filter subtitle.")
    data: Dict[str, Any] = Field(default_factory=dict, description="Structured metrics, breakdown, or comparison data.")


class WorkflowStep(BaseModel):
    """A discrete operation step within a multi-step ERP workflow."""
    step_number: int = Field(..., description="1-based step index.")
    title: str = Field(..., description="Action title (e.g. 'Find Supplier', 'Prepare Purchase Draft').")
    description: str = Field(..., description="Description of the operation.")
    status: str = Field(default="pending", description="Status ('completed', 'ready_for_review', 'pending', 'failed').")
    action_type: str = Field(..., description="Sub-action type ('navigate', 'prefill_form', 'business_report', 'info').")
    route: Optional[str] = Field(default=None, description="GoRouter route if applicable.")
    payload: Dict[str, Any] = Field(default_factory=dict, description="Fields, parameters, or prefill action data.")


class WorkflowAction(BaseModel):
    """Structured multi-step workflow automation proposal requiring user review."""
    action: str = Field(default="workflow_automation", description="Action type ('workflow_automation').")
    workflow_id: str = Field(..., description="Unique workflow identifier to prevent duplicate confirmation.")
    title: str = Field(..., description="Workflow title (e.g. 'Low Stock Reorder Workflow').")
    summary: str = Field(..., description="Summary of multi-step task.")
    steps: List[WorkflowStep] = Field(default_factory=list, description="Ordered proposed steps.")
    requires_approval: bool = Field(default=True, description="Always requires explicit confirmation for database writes.")


class ChatResponse(BaseModel):
    """
    Client-safe chat response.
    Never exposes internal system tokens, secrets, or raw user authentication payloads.
    Includes optional structured action (such as navigation, form prefill, business report, or workflow automation).
    """
    reply: str
    action: Optional[Union[NavigationAction, FormPrefillAction, VisualReportAction, WorkflowAction, Dict[str, Any]]] = None
    status: str = "success"
