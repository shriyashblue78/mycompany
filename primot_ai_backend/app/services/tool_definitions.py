from typing import Any, Dict, List, Optional

ERP_TOOL_DEFINITIONS: List[Dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "find_party",
            "description": "Search party (customer/supplier) by name, phone, or vendor code.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Party name, phone, or vendor code."
                    }
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "find_employee",
            "description": "Search for an employee by name, email, phone, designation, department, or employee ID in Primot ERP.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Employee name, email, phone, designation, department, or ID."
                    }
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_item",
            "description": "Get item details from inventory by number, part number, ID, or name.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Item number, part number, ID, or name."
                    }
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_stock",
            "description": "Check current recorded stock in inventory for an item.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Item number, part number, or name."
                    }
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "sales_summary",
            "description": "Summarize total sales amount (in ₹), count, and status over date range. Excludes Cancelled.",
            "parameters": {
                "type": "object",
                "properties": {
                    "start_date": {
                        "type": "string",
                        "description": "Start date in YYYY-MM-DD."
                    },
                    "end_date": {
                        "type": "string",
                        "description": "End date in YYYY-MM-DD."
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "purchase_summary",
            "description": "Summarize total purchase amount (in ₹), count, and status over date range. Excludes Cancelled.",
            "parameters": {
                "type": "object",
                "properties": {
                    "start_date": {
                        "type": "string",
                        "description": "Start date in YYYY-MM-DD."
                    },
                    "end_date": {
                        "type": "string",
                        "description": "End date in YYYY-MM-DD."
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "party_sales_total",
            "description": "Calculate total billed invoice sales (in ₹) for a party. Excludes Cancelled.",
            "parameters": {
                "type": "object",
                "properties": {
                    "party_identifier": {
                        "type": "string",
                        "description": "Party name or ID."
                    }
                },
                "required": ["party_identifier"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "compare_periods",
            "description": "Compare sales or purchases between two date ranges (e.g. this month vs last month, this week vs last week).",
            "parameters": {
                "type": "object",
                "properties": {
                    "report_type": {
                        "type": "string",
                        "enum": ["sales", "purchases"],
                        "description": "'sales' or 'purchases'."
                    },
                    "period1_start": {"type": "string", "description": "Period 1 start (YYYY-MM-DD)."},
                    "period1_end": {"type": "string", "description": "Period 1 end (YYYY-MM-DD)."},
                    "period2_start": {"type": "string", "description": "Period 2 start (YYYY-MM-DD)."},
                    "period2_end": {"type": "string", "description": "Period 2 end (YYYY-MM-DD)."},
                    "period1_label": {"type": "string", "description": "Label for period 1 (e.g. 'Last Month')."},
                    "period2_label": {"type": "string", "description": "Label for period 2 (e.g. 'This Month')."}
                },
                "required": ["report_type", "period1_start", "period1_end", "period2_start", "period2_end"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "party_insights",
            "description": "Rank top customers or suppliers by transaction volume and order frequency in Primot ERP.",
            "parameters": {
                "type": "object",
                "properties": {
                    "party_type": {
                        "type": "string",
                        "enum": ["Customer", "Supplier"],
                        "description": "'Customer' for top customers or 'Supplier' for top suppliers."
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of parties to return (default 5)."
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "inventory_insights",
            "description": "Analyze inventory stock, identify low-stock items below minimum level, and category stock breakdown.",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "navigate_to_page",
            "description": "Navigate to a Primot ERP page (e.g. inventory, sales, employees, attendance, purchase, dashboard).",
            "parameters": {
                "type": "object",
                "properties": {
                    "destination": {
                        "type": "string",
                        "description": "Destination page name or keyword."
                    }
                },
                "required": ["destination"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "prepare_form",
            "description": "Prepare a create/edit form for Parties, Items, Employees, Sales, or Purchases for user review.",
            "parameters": {
                "type": "object",
                "properties": {
                    "module": {
                        "type": "string",
                        "description": "parties, items, employees, sales, or purchases."
                    },
                    "operation": {
                        "type": "string",
                        "enum": ["create", "edit"],
                        "description": "'create' or 'edit'."
                    },
                    "target_record": {
                        "type": "string",
                        "description": "Record name, ID, or phone for edit."
                    },
                    "fields": {
                        "type": "object",
                        "description": "Extracted field values dictionary."
                    }
                },
                "required": ["module", "operation", "fields"]
            }
        }
    }
]


# Tool name to schema mapping
TOOL_BY_NAME: Dict[str, Dict[str, Any]] = {
    t["function"]["name"]: t for t in ERP_TOOL_DEFINITIONS
}


def filter_relevant_tools(user_message: str, history: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
    """
    Selects relevant tools based on user intent in message and recent context,
    avoiding sending irrelevant schemas and conserving context tokens.
    If intent is ambiguous or broad, safely defaults to all tools.
    """
    text = (user_message or "").lower()
    if history:
        # Include last user message from history for follow-up context
        for h in reversed(history):
            content = getattr(h, "content", None) or (h.get("content") if isinstance(h, dict) else "")
            if content:
                text += " " + str(content).lower()
                break

    relevant: List[str] = []

    # Navigation keywords
    if any(k in text for k in ["open", "go to", "navigate", "take me", "show screen", "page", "screen"]):
        relevant.append("navigate_to_page")

    # Form prefill / creation / editing keywords (PRIORITY over analytics)
    is_form_intent = any(k in text for k in [
        "create", "add", "new", "update", "edit", "change", "set", "modify",
        "register", "prepare", "draft", "make entry", "entry for", "order for",
        "purchase entry", "sales entry", "sale entry"
    ])
    if is_form_intent:
        relevant.append("prepare_form")
        if any(k in text for k in ["supplier", "vendor", "party", "customer"]):
            relevant.append("find_party")
        if any(k in text for k in ["item", "stock", "product", "rod", "bolt", "sheet", "material"]):
            relevant.extend(["get_item", "get_stock"])

    # Comparisons and trends
    if any(k in text for k in ["compare", "vs", "versus", "comparison", "trend", "difference", "growth"]):
        relevant.append("compare_periods")
        if any(k in text for k in ["purchase", "procurement", "bought"]):
            relevant.append("purchase_summary")
        else:
            relevant.append("sales_summary")

    # Insights & Analytics / Rankings
    if any(k in text for k in ["top customer", "top supplier", "best customer", "highest sales party", "ranking", "party insight"]):
        relevant.append("party_insights")

    if any(k in text for k in ["low stock", "shortage", "minimum stock", "inventory summary", "category stock", "stock insight"]):
        relevant.extend(["inventory_insights", "get_stock"])

    # Stock / inventory item keywords (only add search tools if not pure form intent)
    if any(k in text for k in ["stock", "quantity", "inventory", "available", "unit", "level", "item", "part", "material", "rod", "sheet", "bolt"]):
        relevant.extend(["get_stock", "get_item"])
        if not is_form_intent:
            relevant.append("inventory_insights")

    # Sales / revenue / billing keywords (do not add summary if intent is explicitly creating/drafting an entry)
    if any(k in text for k in ["sale", "sales", "billed", "invoice", "revenue", "sold"]):
        if not is_form_intent:
            relevant.extend(["sales_summary", "party_sales_total"])

    # Purchase / vendor buying keywords (do not add summary if intent is explicitly creating/drafting an entry)
    if any(k in text for k in ["purchase", "purchases", "bought", "procurement", "supplier order"]):
        if not is_form_intent:
            relevant.append("purchase_summary")

    # Party / customer / supplier keywords
    if any(k in text for k in ["party", "parties", "customer", "supplier", "vendor", "client", "contact", "phone", "balance", "due"]):
        relevant.append("find_party")
        if not is_form_intent:
            relevant.extend(["party_sales_total", "party_insights"])

    # Employee / staff keywords
    if any(k in text for k in ["employee", "employees", "staff", "worker", "personnel", "designation", "department", "salary", "joining"]):
        relevant.append("find_employee")
        if any(k in text for k in ["open", "go to", "show", "screen", "record"]):
            relevant.append("navigate_to_page")

    # If specific tools matched, return unique subset
    if relevant:
        seen = set()
        result = []
        for name in relevant:
            if name in TOOL_BY_NAME and name not in seen:
                seen.add(name)
                result.append(TOOL_BY_NAME[name])
        return result

    # Default fallback: return all tools if intent cannot be narrowed
    return ERP_TOOL_DEFINITIONS

