import json
import unittest
from unittest.mock import MagicMock, patch

from app.schemas.chat import AuthenticatedUser
from app.services.navigation import (
    resolve_navigation,
    NAVIGABLE_DESTINATIONS,
    ALLOWED_CANONICAL_ROUTES,
)
from app.services.tool_executor import execute_tool_call
from app.services.chat_service import ChatService
from tests.test_local_llm import MockLLMProvider


class TestNavigationTool(unittest.TestCase):
    def setUp(self):
        self.owner = AuthenticatedUser(
            uid="user_owner",
            company_id="COMP_ALPHA",
            employee_id="EMP_001",
            role="Owner",
            name="Alice Owner",
            email="alice@example.com",
            status="Active",
        )
        self.accountant = AuthenticatedUser(
            uid="user_acc",
            company_id="COMP_ALPHA",
            employee_id="EMP_002",
            role="Accountant",
            name="Bob Accountant",
            email="bob@example.com",
            status="Active",
        )
        self.employee = AuthenticatedUser(
            uid="user_emp",
            company_id="COMP_ALPHA",
            employee_id="EMP_003",
            role="Employee",
            name="Charlie Employee",
            email="charlie@example.com",
            status="Active",
        )

    def test_canonical_routes_are_strictly_defined(self):
        """Verify that every route in the navigation registry is a valid path starting with '/'."""
        self.assertGreater(len(NAVIGABLE_DESTINATIONS), 15)
        for item in NAVIGABLE_DESTINATIONS:
            self.assertTrue(item["route"].startswith("/"), f"Route {item['route']} must start with /")
            self.assertIn(item["route"], ALLOWED_CANONICAL_ROUTES)
            self.assertTrue(len(item["allowed_roles"]) > 0)

    def test_valid_navigation_routes_resolve_correctly(self):
        """Verify that natural keywords resolve to correct canonical routes for Owner."""
        test_cases = [
            ("inventory", "/inventory", "Inventory Management"),
            ("open stock", "/inventory", "Inventory Management"),
            ("sales", "/sales", "Sales Management"),
            ("purchase", "/purchase", "Purchase Management"),
            ("employees", "/employees", "Employee Management"),
            ("attendance", "/attendance", "Attendance"),
            ("my tasks", "/tasks/my-tasks", "My Tasks"),
            ("production", "/production", "Production Control"),
            ("reports", "/reports", "Analytics & Reports"),
            ("settings", "/settings", "Settings & Profile"),
            ("dashboard", "/dashboard", "Dashboard"),
        ]

        for query, expected_route, expected_title in test_cases:
            success, res = resolve_navigation(destination=query, user_role="Owner")
            self.assertTrue(success, f"Failed to resolve '{query}'")
            self.assertEqual(res["route"], expected_route)
            self.assertEqual(res["title"], expected_title)
            self.assertEqual(res["action"], "navigate")

    def test_role_based_navigation_rejection(self):
        """
        Verify that users without required roles cannot navigate to restricted modules.
        - Accountant cannot access /employees or /inventory or /production
        - Employee cannot access /sales or /purchase or /inventory
        """
        # Accountant attempting to navigate to Employee Management
        success, res = resolve_navigation(destination="employees", user_role="Accountant")
        self.assertFalse(success)
        self.assertIn("Access denied", res["error"])
        self.assertIn("Accountant", res["error"])

        # Accountant attempting to navigate to Inventory
        success, res = resolve_navigation(destination="inventory", user_role="Accountant")
        self.assertFalse(success)
        self.assertIn("Access denied", res["error"])

        # Employee attempting to navigate to Sales
        success, res = resolve_navigation(destination="sales", user_role="Employee")
        self.assertFalse(success)
        self.assertIn("Access denied", res["error"])

        # Employee attempting to navigate to Purchase
        success, res = resolve_navigation(destination="purchase", user_role="Employee")
        self.assertFalse(success)
        self.assertIn("Access denied", res["error"])

    def test_role_based_navigation_allowed_for_authorized_roles(self):
        """
        Verify that authorized roles succeed:
        - Accountant accessing Sales and Purchase -> allowed
        - Employee accessing Attendance, My Tasks, and Leaves -> allowed
        """
        # Accountant accessing Sales
        success, res = resolve_navigation(destination="sales", user_role="Accountant")
        self.assertTrue(success)
        self.assertEqual(res["route"], "/sales")

        # Accountant accessing Purchase
        success, res = resolve_navigation(destination="purchase", user_role="Accountant")
        self.assertTrue(success)
        self.assertEqual(res["route"], "/purchase")

        # Employee accessing Attendance
        success, res = resolve_navigation(destination="attendance", user_role="Employee")
        self.assertTrue(success)
        self.assertEqual(res["route"], "/attendance")

        # Employee accessing My Tasks
        success, res = resolve_navigation(destination="my tasks", user_role="Employee")
        self.assertTrue(success)
        self.assertEqual(res["route"], "/tasks/my-tasks")

    def test_invalid_and_arbitrary_routes_rejected(self):
        """Verify that unknown pages, URLs, or arbitrary code injection destinations are rejected."""
        invalid_queries = [
            "unknown_admin_portal",
            "http://malicious-site.com",
            "javascript:alert(1)",
            "../../etc/passwd",
            "<script>alert('xss')</script>",
            "drop database",
            "",
            "   ",
        ]

        for bad_dest in invalid_queries:
            success, res = resolve_navigation(destination=bad_dest, user_role="Owner")
            self.assertFalse(success, f"Destination '{bad_dest}' should have been rejected")
            self.assertIn("error", res)

    def test_tool_executor_handles_navigate_to_page(self):
        """Verify execute_tool_call executes navigate_to_page using authenticated user_role."""
        # Valid execution by Owner
        success, res = execute_tool_call(
            company_id="COMP_ALPHA",
            tool_name="navigate_to_page",
            arguments={"destination": "inventory"},
            user_role="Owner",
        )
        self.assertTrue(success)
        self.assertEqual(res["route"], "/inventory")
        self.assertEqual(res["action"], "navigate")

        # Unauthorized execution by Accountant
        success, res = execute_tool_call(
            company_id="COMP_ALPHA",
            tool_name="navigate_to_page",
            arguments={"destination": "inventory"},
            user_role="Accountant",
        )
        self.assertFalse(success)
        self.assertIn("Access denied", res["error"])

    def test_chat_service_returns_structured_navigation_action(self):
        """
        Verify end-to-end that when LLM invokes navigate_to_page:
        1. Tool executes and returns canonical route.
        2. ChatService captures the structured navigation action.
        3. Result object exposes .action with {"action": "navigate", "route": ..., "title": ...}.
        """
        mock_tool_call = {
            "id": "nav_call_1",
            "type": "function",
            "function": {
                "name": "navigate_to_page",
                "arguments": json.dumps({"destination": "inventory"}),
            },
        }

        mock_provider = MockLLMProvider(
            turns_sequence=[
                {"content": None, "tool_calls": [mock_tool_call]},
                {"content": "Navigating you to Inventory Management. You can tap the button below to proceed."},
            ]
        )

        chat = ChatService(llm_provider=mock_provider)
        import asyncio
        result = asyncio.run(chat.process_chat(self.owner, "Open inventory please"))

        self.assertIn("Inventory Management", str(result))
        self.assertIsNotNone(result.action)
        self.assertEqual(result.action["action"], "navigate")
        self.assertEqual(result.action["route"], "/inventory")
        self.assertEqual(result.action["title"], "Inventory Management")


if __name__ == "__main__":
    unittest.main()

