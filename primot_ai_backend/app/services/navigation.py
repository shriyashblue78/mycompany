import re
from typing import Any, Dict, List, Optional, Set, Tuple

# Controlled allowlist of navigable ERP routes verified against lib/core/routing/app_router.dart
NAVIGABLE_DESTINATIONS: List[Dict[str, Any]] = [
    {
        "id": "dashboard",
        "route": "/dashboard",
        "title": "Dashboard",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Accountant", "Employee"},
        "keywords": ["dashboard", "home", "main screen", "overview", "home page"],
    },
    {
        "id": "inventory",
        "route": "/inventory",
        "title": "Inventory Management",
        "allowed_roles": {"Owner", "HR", "Supervisor"},
        "keywords": ["inventory", "stock", "items", "item list", "products", "materials"],
    },
    {
        "id": "sales",
        "route": "/sales",
        "title": "Sales Management",
        "allowed_roles": {"Owner", "Accountant"},
        "keywords": ["sales", "sale", "invoices", "orders", "customer orders", "billing"],
    },
    {
        "id": "sales_analytics",
        "route": "/sales/analytics",
        "title": "Sales Analytics",
        "allowed_roles": {"Owner"},
        "keywords": ["sales analytics", "sales report", "sales insights", "revenue analytics"],
    },
    {
        "id": "purchase",
        "route": "/purchase",
        "title": "Purchase Management",
        "allowed_roles": {"Owner", "Accountant"},
        "keywords": ["purchase", "purchases", "procurement", "vendor orders", "po", "purchase orders"],
    },
    {
        "id": "parties",
        "route": "/parties",
        "title": "Parties & Vendors",
        "allowed_roles": {"Owner", "Accountant"},
        "keywords": ["parties", "party", "customers", "vendors", "suppliers", "clients"],
    },
    {
        "id": "employees",
        "route": "/employees",
        "title": "Employee Management",
        "allowed_roles": {"Owner", "HR", "Supervisor"},
        "keywords": ["employees", "employee", "staff", "workers", "team", "personnel", "employee management"],
    },
    {
        "id": "attendance",
        "route": "/attendance",
        "title": "Attendance",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Employee"},
        "keywords": ["attendance", "present", "clock in", "check in", "attendance tracking", "attendance portal"],
    },
    {
        "id": "todays_attendance",
        "route": "/attendance/today",
        "title": "Today's Attendance",
        "allowed_roles": {"Owner", "HR", "Supervisor"},
        "keywords": ["todays attendance", "today's attendance", "today attendance", "attendance today"],
    },
    {
        "id": "tasks",
        "route": "/tasks",
        "title": "Task Management",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Employee"},
        "keywords": ["tasks", "task", "assignments", "todo", "to do", "task management"],
    },
    {
        "id": "my_tasks",
        "route": "/tasks/my-tasks",
        "title": "My Tasks",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Employee"},
        "keywords": ["my tasks", "my task", "assigned to me", "my assignments"],
    },
    {
        "id": "leaves",
        "route": "/leaves",
        "title": "Leaves Portal",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Employee"},
        "keywords": ["leaves", "leave", "vacation", "holiday", "time off", "leaves portal"],
    },
    {
        "id": "apply_leave",
        "route": "/leaves/apply",
        "title": "Apply Leave",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Employee"},
        "keywords": ["apply leave", "take leave", "request leave", "new leave"],
    },
    {
        "id": "production",
        "route": "/production",
        "title": "Production Control",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Employee"},
        "keywords": ["production", "manufacturing", "work orders", "assembly", "production control"],
    },
    {
        "id": "machines",
        "route": "/machines",
        "title": "Machines",
        "allowed_roles": {"Owner", "HR", "Supervisor"},
        "keywords": ["machines", "machine", "equipment", "machinery"],
    },
    {
        "id": "tooling",
        "route": "/tooling",
        "title": "Tooling",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Employee"},
        "keywords": ["tooling", "tools", "tool"],
    },
    {
        "id": "drawings",
        "route": "/drawings",
        "title": "Drawings",
        "allowed_roles": {"Owner", "HR", "Supervisor"},
        "keywords": ["drawings", "drawing", "blueprints", "cad", "technical drawings"],
    },
    {
        "id": "programs",
        "route": "/programs",
        "title": "Programs",
        "allowed_roles": {"Owner", "HR", "Supervisor"},
        "keywords": ["programs", "program", "cnc programs", "gcode", "g-code"],
    },
    {
        "id": "inward_outward",
        "route": "/inward-outward",
        "title": "Inward / Outward",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Accountant"},
        "keywords": ["inward outward", "inward/outward", "inward", "outward", "gate pass", "dispatch"],
    },
    {
        "id": "reports",
        "route": "/reports",
        "title": "Analytics & Reports",
        "allowed_roles": {"Owner", "HR"},
        "keywords": ["reports", "report", "analytics", "business reports", "work report"],
    },
    {
        "id": "notifications",
        "route": "/notifications",
        "title": "Notifications & Broadcast",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Accountant", "Employee"},
        "keywords": ["notifications", "notification", "announcements", "alerts", "messages", "broadcasts"],
    },
    {
        "id": "project_tracker",
        "route": "/project-tracker",
        "title": "Project Tracker",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Employee"},
        "keywords": ["project tracker", "projects", "project", "milestones"],
    },
    {
        "id": "masters",
        "route": "/masters",
        "title": "Masters Management",
        "allowed_roles": {"Owner", "Accountant"},
        "keywords": ["masters", "master", "master data", "categories", "units", "taxes"],
    },
    {
        "id": "tally",
        "route": "/tally",
        "title": "Tally Integration",
        "allowed_roles": {"Owner", "Accountant"},
        "keywords": ["tally", "tally export", "tally integration"],
    },
    {
        "id": "settings",
        "route": "/settings",
        "title": "Settings & Profile",
        "allowed_roles": {"Owner", "HR", "Supervisor", "Accountant", "Employee"},
        "keywords": ["settings", "profile", "account", "preferences", "my account"],
    },
    {
        "id": "subscription",
        "route": "/subscription/plans",
        "title": "Subscription & Plans",
        "allowed_roles": {"Owner", "HR"},
        "keywords": ["subscription", "plans", "pricing", "upgrade", "billing plan", "renewal"],
    },
]

# Set of all valid canonical routes for O(1) membership validation
ALLOWED_CANONICAL_ROUTES: Set[str] = {item["route"] for item in NAVIGABLE_DESTINATIONS}


def normalize_query(text: str) -> str:
    """Normalizes text for keyword matching."""
    cleaned = re.sub(r'[^a-zA-Z0-9\s/]', '', text.lower())
    return " ".join(cleaned.split())


def resolve_navigation(destination: str, user_role: str) -> Tuple[bool, Dict[str, Any]]:
    """
    Validates destination against the controlled allowlist and checks role permissions.
    
    Returns:
        (success: bool, result_payload: Dict[str, Any])
    """
    dest_clean = normalize_query(destination)
    if not dest_clean:
        return False, {
            "error": "Destination cannot be empty.",
            "action": None,
        }

    matched_entry: Optional[Dict[str, Any]] = None

    # 1. Exact route path match
    for entry in NAVIGABLE_DESTINATIONS:
        if destination.strip().lower() == entry["route"].lower():
            matched_entry = entry
            break

    # 2. Exact keyword or ID match
    if not matched_entry:
        for entry in NAVIGABLE_DESTINATIONS:
            if dest_clean == entry["id"] or dest_clean in entry["keywords"]:
                matched_entry = entry
                break

    # 3. Word-boundary phrase matching (e.g. "open inventory" contains whole word "inventory")
    if not matched_entry:
        for entry in NAVIGABLE_DESTINATIONS:
            for kw in entry["keywords"]:
                # Match standalone word/phrase with word boundaries
                pattern = r'\b' + re.escape(kw) + r'\b'
                if re.search(pattern, dest_clean):
                    matched_entry = entry
                    break
            if matched_entry:
                break

    if not matched_entry:
        return False, {
            "error": f"Unknown destination '{destination}'. Destination does not exist in Primot ERP.",
            "action": None,
        }

    # Role permission check (derived from authenticated user context)
    allowed_roles: Set[str] = matched_entry["allowed_roles"]
    if user_role not in allowed_roles:
        return False, {
            "error": f"Access denied: Role '{user_role}' is not authorized to access '{matched_entry['title']}'.",
            "action": None,
            "required_roles": list(allowed_roles),
        }

    # Confirmed valid and authorized destination
    canonical_route = matched_entry["route"]
    assert canonical_route in ALLOWED_CANONICAL_ROUTES, "Route must be in allowlist"

    return True, {
        "action": "navigate",
        "route": canonical_route,
        "title": matched_entry["title"],
        "message": f"Navigating to {matched_entry['title']}.",
    }
