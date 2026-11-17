import json
import logging
from datetime import datetime, date, timedelta
from typing import Any, Dict, Optional, Tuple

from app.services.erp_tools import erp_tools_service
from app.services.navigation import resolve_navigation
from app.services.form_prefill import FormPrefillService

logger = logging.getLogger(__name__)

APPROVED_TOOL_NAMES = {
    "find_party",
    "find_employee",
    "get_item",
    "get_stock",
    "sales_summary",
    "purchase_summary",
    "party_sales_total",
    "compare_periods",
    "party_insights",
    "inventory_insights",
    "navigate_to_page",
    "prepare_form",
}


def _get_month_bounds(year: int, month: int) -> Tuple[date, date]:
    """Returns (start_date, end_date) for a given year and month."""
    start_d = date(year, month, 1)
    if month == 12:
        end_d = date(year, 12, 31)
    else:
        end_d = date(year, month + 1, 1) - timedelta(days=1)
    return start_d, end_d


def _parse_date_arg(val: Any, is_end_date: bool = False) -> Optional[date]:
    """
    Parses dates from model tool call arguments.
    Supports:
    - date objects
    - Standard ISO dates: YYYY-MM-DD (including timestamps with T)
    - Relative keywords: 'today', 'yesterday', 'this_month', 'last_month'
    - Month identifiers: 'YYYY-MM' (resolves to start or end of month depending on is_end_date)
    """
    if not val:
        return None
    if isinstance(val, date):
        return val
    if isinstance(val, str):
        val = val.strip()
        lower_val = val.lower().replace("-", "_").replace(" ", "_")
        today = date.today()

        if lower_val in ("today", "now"):
            return today
        if lower_val == "yesterday":
            return today - timedelta(days=1)
        if lower_val in ("this_month", "current_month"):
            start_m, end_m = _get_month_bounds(today.year, today.month)
            return end_m if is_end_date else start_m
        if lower_val in ("last_month", "previous_month"):
            last_month_date = today.replace(day=1) - timedelta(days=1)
            start_m, end_m = _get_month_bounds(last_month_date.year, last_month_date.month)
            return end_m if is_end_date else start_m

        # Handle ISO timestamp strings
        if "T" in val:
            val = val.split("T")[0].strip()

        # Check for year-month string like '2026-11'
        try:
            ym = datetime.strptime(val, "%Y-%m").date()
            start_m, end_m = _get_month_bounds(ym.year, ym.month)
            return end_m if is_end_date else start_m
        except ValueError:
            pass

        for fmt in ("%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y", "%Y/%m/%d"):
            try:
                return datetime.strptime(val, fmt).date()
            except ValueError:
                continue
    return None


def execute_tool_call(
    company_id: str,
    tool_name: str,
    arguments: Any,
    user_role: str = "Owner",
) -> Tuple[bool, Dict[str, Any]]:
    """
    Validates tool name, rejects unauthorized tools, enforces company_id from
    authenticated context (rejecting any attempt by the LLM to override company_id),
    executes Phase 2 service, and returns JSON-serializable results.
    
    Returns:
        (success: bool, result_dict: Dict[str, Any])
    """
    if not company_id:
        return False, {"error": "Missing authenticated company context."}

    if tool_name not in APPROVED_TOOL_NAMES:
        return False, {
            "error": f"Tool '{tool_name}' is not an approved read-only ERP tool.",
            "allowed_tools": list(APPROVED_TOOL_NAMES),
        }

    # Parse arguments if passed as JSON string
    args: Dict[str, Any] = {}
    if isinstance(arguments, str):
        try:
            args = json.loads(arguments) if arguments.strip() else {}
        except Exception as e:
            return False, {"error": f"Invalid JSON arguments: {str(e)}"}
    elif isinstance(arguments, dict):
        args = arguments
    else:
        return False, {"error": "Arguments must be a JSON object or dictionary."}

    # Security check: Never allow model to pass or override company_id or any tenant key
    for tenant_key in ("company_id", "companyId", "company", "tenant_id", "tenantId"):
        if tenant_key in args:
            logger.warning(
                "Model attempted to specify %s in tool arguments for %s. Overriding with authenticated context.",
                tenant_key,
                tool_name,
            )
            args.pop(tenant_key, None)

    try:
        if tool_name == "find_party":
            query = str(args.get("query") or args.get("q") or "").strip()
            if not query:
                return False, {"error": "Missing required argument 'query'."}
            res = erp_tools_service.find_party(company_id=company_id, query=query)
            return True, res.model_dump()

        elif tool_name == "find_employee":
            query = str(args.get("query") or args.get("q") or "").strip()
            if not query:
                return False, {"error": "Missing required argument 'query'."}
            res = erp_tools_service.find_employee(company_id=company_id, query=query)
            return True, res.model_dump()

        elif tool_name == "get_item":
            query = str(args.get("query") or args.get("q") or "").strip()
            if not query:
                return False, {"error": "Missing required argument 'query'."}
            res = erp_tools_service.get_item(company_id=company_id, query=query)
            if not res:
                return True, {"found": False, "message": f"Item '{query}' not found in Primot inventory."}
            return True, {"found": True, "item": res.model_dump()}

        elif tool_name == "get_stock":
            query = str(args.get("query") or args.get("q") or "").strip()
            if not query:
                return False, {"error": "Missing required argument 'query'."}
            res = erp_tools_service.get_stock(company_id=company_id, query=query)
            if not res:
                return True, {"found": False, "message": f"Item '{query}' not found in Primot inventory."}
            return True, {"found": True, "stock": res.model_dump()}

        elif tool_name == "sales_summary":
            start_d = _parse_date_arg(args.get("start_date"), is_end_date=False)
            end_d = _parse_date_arg(args.get("end_date"), is_end_date=True)
            res = erp_tools_service.sales_summary(
                company_id=company_id,
                start_date=start_d,
                end_date=end_d,
            )
            return True, res.model_dump()

        elif tool_name == "purchase_summary":
            start_d = _parse_date_arg(args.get("start_date"), is_end_date=False)
            end_d = _parse_date_arg(args.get("end_date"), is_end_date=True)
            res = erp_tools_service.purchase_summary(
                company_id=company_id,
                start_date=start_d,
                end_date=end_d,
            )
            return True, res.model_dump()

        elif tool_name == "party_sales_total":
            party_ident = str(args.get("party_identifier") or args.get("party") or args.get("party_name") or "").strip()
            if not party_ident:
                return False, {"error": "Missing required argument 'party_identifier'."}
            res = erp_tools_service.party_sales_total(
                company_id=company_id,
                party_identifier=party_ident,
            )
            return True, res.model_dump()

        elif tool_name == "compare_periods":
            rep_type = str(args.get("report_type") or "sales").strip().lower()
            p1_start = _parse_date_arg(args.get("period1_start"), is_end_date=False)
            p1_end = _parse_date_arg(args.get("period1_end"), is_end_date=True)
            p2_start = _parse_date_arg(args.get("period2_start"), is_end_date=False)
            p2_end = _parse_date_arg(args.get("period2_end"), is_end_date=True)
            p1_label = str(args.get("period1_label") or "Period 1")
            p2_label = str(args.get("period2_label") or "Period 2")
            res = erp_tools_service.compare_periods(
                company_id=company_id,
                report_type=rep_type,
                period1_start=p1_start,
                period1_end=p1_end,
                period2_start=p2_start,
                period2_end=p2_end,
                period1_label=p1_label,
                period2_label=p2_label,
            )
            return True, res.model_dump()

        elif tool_name == "party_insights":
            p_type = str(args.get("party_type") or "Customer").strip()
            limit = int(args.get("limit") or 5)
            res = erp_tools_service.party_insights(
                company_id=company_id,
                party_type=p_type,
                limit=limit,
            )
            return True, res.model_dump()

        elif tool_name == "inventory_insights":
            res = erp_tools_service.inventory_insights(company_id=company_id)
            return True, res.model_dump()

        elif tool_name == "navigate_to_page":
            dest = str(args.get("destination") or args.get("page") or args.get("module") or "").strip()
            if not dest:
                return False, {"error": "Missing required argument 'destination'."}
            success, nav_res = resolve_navigation(destination=dest, user_role=user_role)
            return success, nav_res

        elif tool_name == "prepare_form":
            mod = str(args.get("module") or "").strip()
            op = str(args.get("operation") or "create").strip()
            target = args.get("target_record")
            raw_f = args.get("fields") or {}
            if not isinstance(raw_f, dict):
                raw_f = {}

            service = FormPrefillService()
            res = service.process_form_request(
                company_id=company_id,
                user_role=user_role,
                module=mod,
                operation=op,
                raw_fields=raw_f,
                target_record=target,
            )
            if "error" in res:
                return False, res
            return True, res

        return False, {"error": f"Unhandled tool '{tool_name}'."}

    except Exception as e:
        logger.error("Error executing ERP tool %s: %s", tool_name, e, exc_info=True)
        return False, {"error": f"Tool execution failed: {str(e)}"}

