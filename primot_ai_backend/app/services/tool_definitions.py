from typing import Any, Dict, List

ERP_TOOL_DEFINITIONS: List[Dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "find_party",
            "description": "Search for a party (customer or supplier) by name, phone number, or vendor code. Always returns exact or partial matches if found.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Party name, phone number, or vendor code to search for."
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
            "description": "Retrieve item specifications and details from Primot inventory by item number, part number, item ID, or item name.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Item number, part number, item ID, or item name."
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
            "description": "Check current recorded stock in Primot inventory for an item. Note: reflects recorded inventory, not physically verified stock.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Item number, part number, or item name to check stock for."
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
            "description": "Summarize total sales amount (in ₹ INR), transaction count, and status breakdown over a date range. Excludes Cancelled sales. Always use explicit YYYY-MM-DD dates.",
            "parameters": {
                "type": "object",
                "properties": {
                    "start_date": {
                        "type": "string",
                        "description": "Start date in YYYY-MM-DD format."
                    },
                    "end_date": {
                        "type": "string",
                        "description": "End date in YYYY-MM-DD format."
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "purchase_summary",
            "description": "Summarize total purchase amount (in ₹ INR), transaction count, and status breakdown over a date range. Excludes Cancelled purchases. Always use explicit YYYY-MM-DD dates.",
            "parameters": {
                "type": "object",
                "properties": {
                    "start_date": {
                        "type": "string",
                        "description": "Start date in YYYY-MM-DD format."
                    },
                    "end_date": {
                        "type": "string",
                        "description": "End date in YYYY-MM-DD format."
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "party_sales_total",
            "description": "Calculate total billed invoice sales amount (in ₹ INR) for a specific customer/party. Excludes Cancelled sales. Note: Only returns billed amounts; customer payment tracking and outstanding balances are unsupported.",
            "parameters": {
                "type": "object",
                "properties": {
                    "party_identifier": {
                        "type": "string",
                        "description": "Party name or party ID."
                    }
                },
                "required": ["party_identifier"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "navigate_to_page",
            "description": "Navigate to an existing Primot ERP page or module. Use this when the user asks to open, view, go to, or navigate to a screen or module.",
            "parameters": {
                "type": "object",
                "properties": {
                    "destination": {
                        "type": "string",
                        "description": "Name or keyword of the target page (e.g. 'inventory', 'sales', 'employees', 'attendance', 'purchase', 'dashboard', 'tasks', 'leaves', 'production', 'machines', 'reports', 'settings', 'parties')."
                    }
                },
                "required": ["destination"]
            }
        }
    }
]

