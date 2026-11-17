"""
Unit and Integration Tests for Phase 8 AI-Assisted Form Filling & Editing.
Tests role authorization, company scoping, field sanitization, record resolution,
missing field tracking, and structured action payloads.
"""

import unittest
from unittest.mock import MagicMock, patch

from app.services.form_prefill import (
    FormPrefillService,
    ALLOWED_FORM_MODULES,
    normalize_module,
    normalize_unit,
    normalize_category,
)
from app.services.tool_executor import execute_tool_call
from app.services.chat_service import ChatService
from app.schemas.chat import AuthenticatedUser
from tests.test_local_llm import MockLLMProvider


class DummyDoc:
    def __init__(self, doc_id: str, data: dict):
        self.id = doc_id
        self._data = data

    def to_dict(self):
        return self._data


class TestFormPrefill(unittest.TestCase):
    def setUp(self):
        self.mock_db = MagicMock()
        self.service = FormPrefillService(db=self.mock_db)

    def test_normalize_module_and_units(self):
        """Verify natural language module and unit synonyms resolve to canonical forms."""
        self.assertEqual(normalize_module("party"), "parties")
        self.assertEqual(normalize_module("parties"), "parties")
        self.assertEqual(normalize_module("customer"), "parties")
        self.assertEqual(normalize_module("item"), "items")
        self.assertEqual(normalize_module("inventory"), "items")
        self.assertEqual(normalize_module("employee"), "employees")
        self.assertEqual(normalize_module("staff"), "employees")
        self.assertEqual(normalize_module("sale"), "sales")
        self.assertEqual(normalize_module("billing"), "sales")
        self.assertEqual(normalize_module("purchase"), "purchases")
        self.assertIsNone(normalize_module("unknown_module"))

        self.assertEqual(normalize_unit("kg"), "Kg")
        self.assertEqual(normalize_unit("kilograms"), "Kg")
        self.assertEqual(normalize_unit("pcs"), "Nos")
        self.assertEqual(normalize_unit("liter"), "Litre")

        self.assertEqual(normalize_category("raw material"), "Raw Material")
        self.assertEqual(normalize_category("finished"), "Finished Goods")

    def test_party_creation_complete_info(self):
        """Verify party creation with valid info returns structured prefill action."""
        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="parties",
            operation="create",
            raw_fields={
                "partyName": "ABC Industries",
                "contactNumber": "9876543210",
                "gstin": "27AAAAA0000A1Z5",
                "address": "Plot 10, MIDC",
                "state": "Maharashtra",
            },
        )
        self.assertIn("action", res)
        action = res["action"]
        self.assertEqual(action["action"], "prefill_form")
        self.assertEqual(action["module"], "parties")
        self.assertEqual(action["operation"], "create")
        self.assertEqual(action["route"], "/parties/add")
        self.assertEqual(action["fields"]["partyName"], "ABC Industries")
        self.assertEqual(action["fields"]["contactNumber"], "9876543210")
        self.assertEqual(action["missing_fields"], [])

    def test_party_creation_missing_mandatory_field(self):
        """Verify missing mandatory partyName is tracked in missing_fields."""
        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="parties",
            operation="create",
            raw_fields={"contactNumber": "9876543210"},
        )
        self.assertIn("action", res)
        self.assertIn("partyName", res["action"]["missing_fields"])

    def test_party_invalid_state_not_inferred_or_populated(self):
        """Verify cities or non-states (e.g. Pune) are rejected and never populated in state."""
        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="parties",
            operation="create",
            raw_fields={
                "partyName": "ABC Industries",
                "address": "Hadapsar, Pune",
                "state": "Pune",
            },
        )
        self.assertIn("action", res)
        fields = res["action"]["fields"]
        self.assertEqual(fields["partyName"], "ABC Industries")
        self.assertEqual(fields["address"], "Hadapsar, Pune")
        self.assertNotIn("state", fields, "State must never be set to a city such as Pune")

    def test_party_valid_state_normalized(self):
        """Verify valid state variations normalize to canonical title case."""
        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="parties",
            operation="create",
            raw_fields={
                "partyName": "ABC Industries",
                "state": "maharashtra",
            },
        )
        self.assertIn("action", res)
        self.assertEqual(res["action"]["fields"]["state"], "Maharashtra")

    def test_party_type_vendor_maps_to_supplier(self):
        """Verify vendor partyType is normalized to Supplier to match ERP dropdowns."""
        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="parties",
            operation="create",
            raw_fields={
                "partyName": "ABC Industries",
                "partyType": "vendor",
            },
        )
        self.assertIn("action", res)
        self.assertEqual(res["action"]["fields"]["partyType"], "Supplier")

    def test_party_contact_person_name_extracted_and_mapped(self):
        """Verify contact person name in user extraction maps cleanly to contactPersonName."""
        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="parties",
            operation="create",
            raw_fields={
                "partyName": "ABC Industries",
                "contact_person": "Rahul Sharma",
                "phone": "9876543210",
            },
        )
        self.assertIn("action", res)
        fields = res["action"]["fields"]
        self.assertEqual(fields["contactPersonName"], "Rahul Sharma")
        self.assertEqual(fields["contactNumber"], "9876543210")

    def test_party_vendor_code_not_fabricated_from_phone(self):
        """Verify phone number or 10-digit number is never copied into vendorCode."""
        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="parties",
            operation="create",
            raw_fields={
                "partyName": "ABC Industries",
                "contactNumber": "9876543210",
                "vendorCode": "9876543210",  # Erroneous phone copied as vendor code
            },
        )
        self.assertIn("action", res)
        fields = res["action"]["fields"]
        self.assertEqual(fields["contactNumber"], "9876543210")
        self.assertNotIn("vendorCode", fields, "vendorCode must not be populated with a phone number")

    def test_party_valid_explicit_vendor_code_preserved(self):
        """Verify explicit vendor codes like 'VEN-101' are preserved."""
        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="parties",
            operation="create",
            raw_fields={
                "partyName": "ABC Industries",
                "vendorCode": "VEN-101",
            },
        )
        self.assertIn("action", res)
        self.assertEqual(res["action"]["fields"]["vendorCode"], "VEN-101")

    def test_unauthorized_role_rejected(self):
        """Verify role permissions are strictly enforced."""
        # Accountant cannot create/edit parties or employees
        res_party = self.service.process_form_request(
            company_id="comp_123",
            user_role="Accountant",
            module="parties",
            operation="create",
            raw_fields={"partyName": "ABC Corp"},
        )
        self.assertIn("error", res_party)
        self.assertIn("Access denied", res_party["error"])

        # Employee cannot create items
        res_item = self.service.process_form_request(
            company_id="comp_123",
            user_role="Employee",
            module="items",
            operation="create",
            raw_fields={"itemName": "Copper Rod"},
        )
        self.assertIn("error", res_item)
        self.assertIn("Access denied", res_item["error"])

        # Supervisor CAN create items
        res_sup = self.service.process_form_request(
            company_id="comp_123",
            user_role="Supervisor",
            module="items",
            operation="create",
            raw_fields={"itemName": "Steel Bolt", "unit": "Nos"},
        )
        self.assertIn("action", res_sup)
        self.assertEqual(res_sup["action"]["module"], "items")

    def test_invalid_arbitrary_fields_stripped(self):
        """Verify arbitrary or malicious fields are stripped from the prefill payload."""
        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="items",
            operation="create",
            raw_fields={
                "itemName": "Brass Fitting",
                "unit": "kg",
                "malicious_script": "<script>alert(1)</script>",
                "is_admin": True,
                "company_id": "comp_HACKED",
            },
        )
        self.assertIn("action", res)
        fields = res["action"]["fields"]
        self.assertIn("itemName", fields)
        self.assertEqual(fields["unit"], "Kg")
        self.assertNotIn("malicious_script", fields)
        self.assertNotIn("is_admin", fields)
        self.assertNotIn("company_id", fields)

    def test_edit_record_single_match(self):
        """Verify editing an existing record resolves ID and generates edit route."""
        # Mock Firestore stream
        mock_docs = [
            DummyDoc("item_abc_1", {"itemName": "Copper Rod", "currentStock": 50.0, "unit": "Kg"}),
            DummyDoc("item_abc_2", {"itemName": "Aluminum Sheet", "currentStock": 20.0, "unit": "Nos"}),
        ]
        self.mock_db.collection().document().collection().stream.return_value = mock_docs

        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="items",
            operation="edit",
            target_record="Copper Rod",
            raw_fields={"currentStock": 100.0, "unit": "Kg"},
        )
        self.assertIn("action", res)
        action = res["action"]
        self.assertEqual(action["operation"], "edit")
        self.assertEqual(action["route"], "/inventory/edit/item_abc_1")
        self.assertEqual(action["record_id"], "item_abc_1")
        self.assertEqual(action["fields"]["currentStock"], 100.0)

    def test_edit_record_multiple_matches_clarification(self):
        """Verify that when multiple records match, AI asks for clarification rather than guessing."""
        mock_docs = [
            DummyDoc("item_1", {"itemName": "Copper Rod Grade A"}),
            DummyDoc("item_2", {"itemName": "Copper Rod Grade B"}),
        ]
        self.mock_db.collection().document().collection().stream.return_value = mock_docs

        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="items",
            operation="edit",
            target_record="Copper Rod",
            raw_fields={"currentStock": 80.0},
        )
        self.assertIn("need_clarification", res)
        self.assertIn("Multiple Item records match", res["need_clarification"])
        self.assertNotIn("action", res)

    def test_edit_record_not_found(self):
        """Verify editing a non-existent record asks for clarification."""
        self.mock_db.collection().document().collection().stream.return_value = []

        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="parties",
            operation="edit",
            target_record="NonExistent Enterprises",
            raw_fields={"contactNumber": "9876543210"},
        )
        self.assertIn("need_clarification", res)
        self.assertIn("No existing Party record found", res["need_clarification"])

    def test_sales_and_purchase_form_prefill(self):
        """Verify Sales and Purchase creation for Accountant role."""
        # Sales
        res_sale = self.service.process_form_request(
            company_id="comp_123",
            user_role="Accountant",
            module="sales",
            operation="create",
            raw_fields={
                "customerName": "ABC Industries",
                "itemName": "Steel Rod",
                "quantity": 10,
                "price": 250.0,
            },
        )
        self.assertIn("action", res_sale)
        self.assertEqual(res_sale["action"]["route"], "/sales/add")
        self.assertEqual(res_sale["action"]["fields"]["price"], 250.0)

        # Purchase
        res_purch = self.service.process_form_request(
            company_id="comp_123",
            user_role="Accountant",
            module="purchases",
            operation="create",
            raw_fields={
                "supplierName": "XYZ Metals",
                "itemName": "Zinc Ingot",
                "quantity": 5,
                "price": 1200.0,
            },
        )
        self.assertIn("action", res_purch)
        self.assertEqual(res_purch["action"]["route"], "/purchase/add")

    def test_tool_executor_handles_prepare_form(self):
        """Verify execute_tool_call executes prepare_form with company_id enforcement."""
        with patch("app.services.form_prefill.FormPrefillService.process_form_request") as mock_proc:
            mock_proc.return_value = {
                "action": {
                    "action": "prefill_form",
                    "module": "parties",
                    "operation": "create",
                    "route": "/parties/add",
                    "fields": {"partyName": "ABC Corp"},
                    "title": "Review & Create Party",
                }
            }

            success, res = execute_tool_call(
                company_id="comp_999",
                tool_name="prepare_form",
                arguments={
                    "module": "parties",
                    "operation": "create",
                    "fields": {"partyName": "ABC Corp"},
                    "company_id": "malicious_comp_id",  # Should be stripped
                },
                user_role="Owner",
            )
            self.assertTrue(success)
            self.assertIn("action", res)
            mock_proc.assert_called_once()
            args, kwargs = mock_proc.call_args
            self.assertEqual(kwargs["company_id"], "comp_999")
            self.assertEqual(kwargs["user_role"], "Owner")

    def test_chat_service_returns_structured_prefill_action(self):
        """Verify end-to-end ChatService produces ProcessChatResult with .action."""
        mock_tool_call = {
            "id": "call_1",
            "type": "function",
            "function": {
                "name": "prepare_form",
                "arguments": json_dump({
                    "module": "parties",
                    "operation": "create",
                    "fields": {"partyName": "ABC Industries", "contactNumber": "9876543210"},
                }),
            },
        }

        mock_provider = MockLLMProvider(
            turns_sequence=[
                {"content": None, "tool_calls": [mock_tool_call]},
                {"content": "I have prepared the party form for ABC Industries with phone 9876543210. Please review and save."},
            ]
        )

        service = ChatService(llm_provider=mock_provider)

        test_user = AuthenticatedUser(
            uid="user_1",
            company_id="comp_123",
            employee_id="EMP-01",
            role="Owner",
            name="Alice",
            email="alice@company.com",
            status="Active",
        )

        import asyncio
        result = asyncio.run(service.process_chat(user=test_user, user_message="Add party ABC Industries"))

        self.assertIn("ABC Industries", str(result))
        self.assertIsNotNone(result.action)
        self.assertEqual(result.action["action"], "prefill_form")
        self.assertEqual(result.action["route"], "/parties/add")
        self.assertEqual(result.action["fields"]["partyName"], "ABC Industries")

    def test_dropdown_normalization_and_invalid_filtering(self):
        """Verify department, role, status, category, unit, state normalization and invalid rejection."""
        from app.services.form_prefill import (
            normalize_department,
            normalize_role,
            normalize_status,
            normalize_state,
        )

        # Department
        self.assertEqual(normalize_department("marketing"), "Marketing")
        self.assertEqual(normalize_department("Machining Dept"), "Machining")
        self.assertIsNone(normalize_department("Finance"))  # Not in allowed list

        # Role
        self.assertEqual(normalize_role("hr"), "HR")
        self.assertEqual(normalize_role("supervisor"), "Supervisor")
        self.assertEqual(normalize_role("accountant"), "Accountant")
        self.assertEqual(normalize_role("employee"), "Employee")
        self.assertIsNone(normalize_role("Owner"))  # Excluded from assignable roles
        self.assertIsNone(normalize_role("SuperUser"))

        # Status
        self.assertEqual(normalize_status("active"), "Active")
        self.assertEqual(normalize_status("INACTIVE"), "Inactive")
        self.assertIsNone(normalize_status("Suspended"))

        # State
        self.assertEqual(normalize_state("maharashtra"), "Maharashtra")
        self.assertEqual(normalize_state("karnataka"), "Karnataka")
        self.assertIsNone(normalize_state("Pune"))

    def test_all_modules_missing_mandatory_fields(self):
        """Verify missing mandatory fields tracking across all 5 ERP modules."""
        # Party missing state
        res_party = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="parties",
            operation="create",
            raw_fields={"partyName": "ABC Corp", "contactNumber": "9876543210"},
        )
        self.assertIn("state", res_party["action"]["missing_fields"])

        # Item missing partNumber and process
        res_item = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="items",
            operation="create",
            raw_fields={"itemName": "Steel Bolt"},
        )
        self.assertIn("partNumber", res_item["action"]["missing_fields"])
        self.assertIn("process", res_item["action"]["missing_fields"])

        # Employee missing email, phone, designation
        res_emp = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="employees",
            operation="create",
            raw_fields={"name": "Rahul Sharma"},
        )
        self.assertIn("email", res_emp["action"]["missing_fields"])
        self.assertIn("phone", res_emp["action"]["missing_fields"])
        self.assertIn("designation", res_emp["action"]["missing_fields"])

        # Sales missing customerPhone, itemName, quantity, price
        res_sales = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="sales",
            operation="create",
            raw_fields={"customerName": "ABC Corp"},
        )
        self.assertIn("customerPhone", res_sales["action"]["missing_fields"])
        self.assertIn("itemName", res_sales["action"]["missing_fields"])
        self.assertIn("quantity", res_sales["action"]["missing_fields"])
        self.assertIn("price", res_sales["action"]["missing_fields"])

        # Purchase missing supplierName, itemName, quantity, price
        res_purch = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="purchases",
            operation="create",
            raw_fields={"supplierName": "XYZ Corp"},
        )
        self.assertIn("itemName", res_purch["action"]["missing_fields"])
        self.assertIn("quantity", res_purch["action"]["missing_fields"])
        self.assertIn("price", res_purch["action"]["missing_fields"])

    def test_sales_party_master_customer_phone_reuse(self):
        """Verify verified contact details from Party Master are reused in sales draft."""
        mock_party_doc = DummyDoc(
            "party_abc",
            {
                "partyName": "ABC Industries",
                "contactNumber": "9876543210",
                "partyType": "Customer",
                "state": "Maharashtra",
            },
        )
        self.mock_db.collection.return_value.document.return_value.collection.return_value.stream.return_value = [
            mock_party_doc
        ]

        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="sales",
            operation="create",
            raw_fields={
                "customerName": "ABC Industries",
                "itemName": "Steel Rod",
                "quantity": 10,
                "price": 100,
            },
        )
        self.assertIn("action", res)
        fields = res["action"]["fields"]
        self.assertEqual(fields["customerName"], "ABC Industries")
        self.assertEqual(fields["customerPhone"], "9876543210")
        self.assertNotIn("customerPhone", res["action"]["missing_fields"])

    def test_sales_party_master_missing_contact_not_fabricated(self):
        """Verify missing contact info is marked as missing instead of guessing or fabricating."""
        mock_party_doc = DummyDoc(
            "party_xyz",
            {
                "partyName": "XYZ Industries",
                "partyType": "Customer",
                # No contactNumber in record
            },
        )
        self.mock_db.collection.return_value.document.return_value.collection.return_value.stream.return_value = [
            mock_party_doc
        ]

        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="sales",
            operation="create",
            raw_fields={
                "customerName": "XYZ Industries",
                "itemName": "Steel Rod",
                "quantity": 10,
                "price": 100,
            },
        )
        self.assertIn("action", res)
        fields = res["action"]["fields"]
        self.assertEqual(fields["customerName"], "XYZ Industries")
        self.assertNotIn("customerPhone", fields)
        self.assertIn("customerPhone", res["action"]["missing_fields"])

    def test_sales_strictly_maps_supplier_to_customer(self):
        """Verify supplierName/supplierPhone is strictly mapped to customerName/customerPhone and never left in sales."""
        res = self.service.process_form_request(
            company_id="comp_123",
            user_role="Owner",
            module="sales",
            operation="create",
            raw_fields={
                "supplierName": "ABC Industries",
                "supplierPhone": "9876543210",
                "itemName": "Steel Rod",
                "quantity": 10,
                "price": 100,
            },
        )
        self.assertIn("action", res)
        fields = res["action"]["fields"]
        self.assertEqual(fields["customerName"], "ABC Industries")
        self.assertEqual(fields["customerPhone"], "9876543210")
        self.assertNotIn("supplierName", fields)
        self.assertNotIn("supplierPhone", fields)

    def test_dynamic_employee_navigation(self):
        """Verify dynamic /employees/:id navigation route resolution and role permission checks."""
        from app.services.navigation import resolve_navigation

        # Owner can navigate to specific employee record
        success, res = resolve_navigation("/employees/EMP-101", user_role="Owner")
        self.assertTrue(success)
        self.assertEqual(res["route"], "/employees/EMP-101")
        self.assertEqual(res["title"], "Employee Record (EMP-101)")

        # HR can navigate to specific employee record
        success, res = resolve_navigation("/employees/EMP-101", user_role="HR")
        self.assertTrue(success)
        self.assertEqual(res["route"], "/employees/EMP-101")

        # Accountant is denied
        success, res = resolve_navigation("/employees/EMP-101", user_role="Accountant")
        self.assertFalse(success)
        self.assertIn("Access denied", res["error"])

    def test_chat_service_open_this_employee_context(self):
        """Verify 'open this employee' resolves context employee and generates navigation action."""
        mock_provider = MockLLMProvider(
            turns_sequence=[
                {
                    "content": None,
                    "tool_calls": [
                        {
                            "id": "call_nav",
                            "type": "function",
                            "function": {
                                "name": "navigate_to_page",
                                "arguments": json_dump({"destination": "this employee"}),
                            },
                        }
                    ],
                },
                {"content": "I am opening Rahul Sharma's employee record."},
            ]
        )
        service = ChatService(llm_provider=mock_provider)

        test_user = AuthenticatedUser(
            uid="user_1",
            company_id="comp_123",
            employee_id="EMP-01",
            role="Owner",
            name="Alice",
            email="alice@company.com",
            status="Active",
        )

        history = [
            DummyDoc("msg1", {"role": "user", "content": "Find employee Rahul"}),
            DummyDoc(
                "msg2",
                {
                    "role": "assistant",
                    "content": "Found 1 matching employee: Rahul Sharma (Engineer). (ID: EMP-999)",
                },
            ),
        ]

        import asyncio
        result = asyncio.run(
            service.process_chat(
                user=test_user,
                user_message="open this employee",
                history=history,
            )
        )

        self.assertIsNotNone(result.action)
        self.assertEqual(result.action["action"], "navigate")
        self.assertEqual(result.action["route"], "/employees/EMP-999")
        self.assertEqual(result.action["title"], "Employee Record (EMP-999)")


def json_dump(obj):
    import json
    return json.dumps(obj)


if __name__ == "__main__":
    unittest.main()
