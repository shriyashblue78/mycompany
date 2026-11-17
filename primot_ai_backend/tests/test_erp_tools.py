import unittest
from datetime import date, datetime
from unittest.mock import MagicMock
from app.services.erp_tools import ERPReadToolsService


class MockDocumentSnapshot:
    def __init__(self, doc_id: str, data: dict, exists: bool = True):
        self.id = doc_id
        self._data = data
        self.exists = exists

    def to_dict(self):
        return self._data


class TestERPReadTools(unittest.TestCase):
    def setUp(self):
        self.mock_db = MagicMock()
        self.service = ERPReadToolsService(db=self.mock_db)
        self.company_a = "COMP_ALPHA"
        self.company_b = "COMP_BETA"

    def test_company_isolation_enforced(self):
        """Verify queries always access /companies/{company_id} and reject empty company_id."""
        with self.assertRaises(ValueError):
            self.service.find_party(company_id="", query="Apex")

        with self.assertRaises(ValueError):
            self.service.get_stock(company_id="", query="Bolt")

        with self.assertRaises(ValueError):
            self.service.sales_summary(company_id="")

        with self.assertRaises(ValueError):
            self.service.purchase_summary(company_id="")

        with self.assertRaises(ValueError):
            self.service.party_sales_total(company_id="", party_identifier="Apex")

    def test_find_party_multiple_matches_and_empty(self):
        """Verify multiple matches are returned without guessing, and empty queries handled cleanly."""
        parties_data = [
            MockDocumentSnapshot("P1", {"partyName": "Apex Steel Ltd", "contactNumber": "9876543210"}),
            MockDocumentSnapshot("P2", {"partyName": "Apex Polymers", "contactNumber": "9998887776"}),
            MockDocumentSnapshot("P3", {"partyName": "Delta Corp", "contactNumber": "1112223334"}),
        ]
        self.mock_db.collection().document().collection().stream.return_value = parties_data

        # Search for "Apex" -> multiple matches
        result = self.service.find_party(self.company_a, "Apex")
        self.assertEqual(result.total_matches, 2)
        self.assertEqual(len(result.matches), 2)
        self.assertIn("Found 2 matching parties", result.message)

        # Search for non-existent party
        result_empty = self.service.find_party(self.company_a, "NonExistent")
        self.assertEqual(result_empty.total_matches, 0)
        self.assertEqual(len(result_empty.matches), 0)
        self.assertIn("No parties found", result_empty.message)

        # Empty search query
        result_blank = self.service.find_party(self.company_a, "")
        self.assertEqual(result_blank.total_matches, 0)
        self.assertIn("cannot be empty", result_blank.message)

    def test_get_stock_with_disclaimer_and_low_stock(self):
        """Verify stock calculation reads recorded_current_stock and sets disclaimer."""
        item_doc = MockDocumentSnapshot(
            "ITEM01",
            {
                "itemNo": "ITM-001",
                "itemDescription": "Steel Nut M8",
                "currentStock": 5.0,
                "minimumLevel": 10.0,
                "stockUnit": "Nos",
            },
        )
        # Mock direct get() as not found, stream() returns item
        self.mock_db.collection().document().collection().document().get.return_value = MockDocumentSnapshot("ITEM01", {}, exists=False)
        self.mock_db.collection().document().collection().stream.return_value = [item_doc]

        stock = self.service.get_stock(self.company_a, "ITM-001")
        self.assertIsNotNone(stock)
        self.assertEqual(stock.recorded_current_stock, 5.0)
        self.assertTrue(stock.is_low_stock)
        self.assertIn("recorded in Primot inventory", stock.disclaimer)

    def test_sales_summary_cancelled_exclusion_and_effective_items(self):
        """
        Verify Primot ERP Rule:
        1. status == 'Cancelled' is strictly excluded from totals.
        2. approvalStatus ('Pending Approval' or 'Approved') does NOT exclude records.
        3. Multi-item and single-item transactions correctly processed.
        """
        sales_docs = [
            MockDocumentSnapshot(
                "S1",
                {
                    "saleNumber": "SAL-001",
                    "saleDate": "2026-11-05T10:00:00",
                    "totalAmount": 1000.0,
                    "status": "Delivered",
                    "approvalStatus": "Approved",
                    "items": [{"itemName": "Part A", "quantity": 10}],
                },
            ),
            MockDocumentSnapshot(
                "S2",
                {
                    "saleNumber": "SAL-002",
                    "saleDate": datetime(2026, 11, 6, 14, 30),
                    "totalAmount": 500.0,
                    "status": "Pending",
                    "approvalStatus": "Pending Approval",  # Must be included in totals
                    "itemName": "Part B",
                },
            ),
            MockDocumentSnapshot(
                "S3",
                {
                    "saleNumber": "SAL-003",
                    "saleDate": "2026-11-06T18:00:00",
                    "totalAmount": 2000.0,
                    "status": "Cancelled",  # Must be excluded from totals
                    "approvalStatus": "Approved",
                    "itemName": "Part C",
                },
            ),
        ]
        self.mock_db.collection().document().collection().stream.return_value = sales_docs

        summary = self.service.sales_summary(
            self.company_a,
            start_date=date(2026, 11, 1),
            end_date=date(2026, 11, 10),
        )

        # S1 (1000) + S2 (500) = 1500 (S3 cancelled excluded)
        self.assertEqual(summary.total_amount, 1500.0)
        self.assertEqual(summary.transaction_count, 2)
        self.assertEqual(summary.completed_count, 1)  # S1 Delivered
        self.assertEqual(summary.pending_count, 1)    # S2 Pending
        self.assertEqual(len(summary.transactions), 2)

    def test_purchase_summary_date_filtering_and_status(self):
        """Verify purchases respect date ranges and exclude Cancelled."""
        purchase_docs = [
            MockDocumentSnapshot(
                "P1",
                {
                    "purchaseNumber": "PUR-001",
                    "purchaseDate": "2026-10-15T10:00:00",  # Out of range
                    "totalAmount": 3000.0,
                    "status": "Received",
                },
            ),
            MockDocumentSnapshot(
                "P2",
                {
                    "purchaseNumber": "PUR-002",
                    "purchaseDate": "2026-11-08T10:00:00",  # Within range
                    "totalAmount": 1200.0,
                    "status": "Received",
                },
            ),
            MockDocumentSnapshot(
                "P3",
                {
                    "purchaseNumber": "PUR-003",
                    "purchaseDate": "2026-11-09T10:00:00",  # Within range
                    "totalAmount": 800.0,
                    "status": "Pending",
                },
            ),
            MockDocumentSnapshot(
                "P4",
                {
                    "purchaseNumber": "PUR-004",
                    "purchaseDate": "2026-11-09T12:00:00",  # Within range, but cancelled
                    "totalAmount": 400.0,
                    "status": "Cancelled",
                },
            ),
        ]
        self.mock_db.collection().document().collection().stream.return_value = purchase_docs

        summary = self.service.purchase_summary(
            self.company_a,
            start_date=date(2026, 11, 1),
            end_date=date(2026, 11, 15),
        )

        # Only P2 (1200) + P3 (800) = 2000
        self.assertEqual(summary.total_amount, 2000.0)
        self.assertEqual(summary.transaction_count, 2)
        self.assertEqual(summary.completed_count, 1)
        self.assertEqual(summary.pending_count, 1)

    def test_party_sales_total(self):
        """Verify party billed sales accumulation excluding cancelled sales."""
        sales_docs = [
            MockDocumentSnapshot(
                "S1",
                {
                    "partyId": "PARTY_100",
                    "customerName": "Omega Auto",
                    "totalAmount": 2500.0,
                    "status": "Delivered",
                    "approvalStatus": "Approved",
                },
            ),
            MockDocumentSnapshot(
                "S2",
                {
                    "partyId": "PARTY_100",
                    "customerName": "Omega Auto",
                    "totalAmount": 1500.0,
                    "status": "Pending",
                    "approvalStatus": "Pending Approval",
                },
            ),
            MockDocumentSnapshot(
                "S3",
                {
                    "partyId": "PARTY_100",
                    "customerName": "Omega Auto",
                    "totalAmount": 900.0,
                    "status": "Cancelled",  # Excluded
                    "approvalStatus": "Approved",
                },
            ),
            MockDocumentSnapshot(
                "S4",
                {
                    "partyId": "PARTY_200",
                    "customerName": "Beta Industries",  # Different party
                    "totalAmount": 5000.0,
                    "status": "Delivered",
                },
            ),
        ]
        self.mock_db.collection().document().collection().stream.return_value = sales_docs

        # Query by partyId
        res_by_id = self.service.party_sales_total(self.company_a, "PARTY_100")
        self.assertEqual(res_by_id.total_billed_amount, 4000.0)
        self.assertEqual(res_by_id.sales_count, 2)
        self.assertEqual(res_by_id.approved_count, 1)
        self.assertEqual(res_by_id.pending_approval_count, 1)

        # Query by name
        res_by_name = self.service.party_sales_total(self.company_a, "Omega Auto")
        self.assertEqual(res_by_name.total_billed_amount, 4000.0)

    def test_compare_periods_sales(self):
        """Verify sales date-range comparison calculates differences and trends correctly."""
        # 3 sales documents
        sales_docs = [
            MockDocumentSnapshot(
                "S1",
                {"saleDate": "2026-10-10", "totalAmount": 1000.0, "status": "Delivered"},
            ),
            MockDocumentSnapshot(
                "S2",
                {"saleDate": "2026-11-05", "totalAmount": 2500.0, "status": "Pending"},
            ),
            MockDocumentSnapshot(
                "S3",
                {"saleDate": "2026-11-10", "totalAmount": 500.0, "status": "Cancelled"},  # Excluded
            ),
        ]
        self.mock_db.collection().document().collection().stream.return_value = sales_docs

        comp = self.service.compare_periods(
            company_id=self.company_a,
            report_type="sales",
            period1_start=date(2026, 10, 1),
            period1_end=date(2026, 10, 31),
            period2_start=date(2026, 11, 1),
            period2_end=date(2026, 11, 30),
            period1_label="October",
            period2_label="November",
        )

        self.assertEqual(comp.period_1.total_amount, 1000.0)
        self.assertEqual(comp.period_2.total_amount, 2500.0)
        self.assertEqual(comp.difference_amount, 1500.0)
        self.assertEqual(comp.percentage_change, 150.0)
        self.assertEqual(comp.trend, "up")

    def test_party_insights_top_customers(self):
        """Verify party insights ranks parties by volume and excludes cancelled sales."""
        sales_docs = [
            MockDocumentSnapshot(
                "S1",
                {"customerName": "Customer Alpha", "totalAmount": 5000.0, "status": "Delivered"},
            ),
            MockDocumentSnapshot(
                "S2",
                {"customerName": "Customer Beta", "totalAmount": 8000.0, "status": "Pending"},
            ),
            MockDocumentSnapshot(
                "S3",
                {"customerName": "Customer Alpha", "totalAmount": 2000.0, "status": "Approved"},
            ),
            MockDocumentSnapshot(
                "S4",
                {"customerName": "Customer Beta", "totalAmount": 9999.0, "status": "Cancelled"},  # Excluded
            ),
        ]
        self.mock_db.collection().document().collection().stream.return_value = sales_docs

        res = self.service.party_insights(company_id=self.company_a, party_type="Customer", limit=2)
        self.assertEqual(len(res.parties), 2)
        # Beta has 8000, Alpha has 5000 + 2000 = 7000
        self.assertEqual(res.parties[0].party_name, "Customer Beta")
        self.assertEqual(res.parties[0].total_amount, 8000.0)
        self.assertEqual(res.parties[1].party_name, "Customer Alpha")
        self.assertEqual(res.parties[1].total_amount, 7000.0)

    def test_inventory_insights_low_stock_and_categories(self):
        """Verify inventory insights calculates shortage against minimum level and category totals."""
        inv_docs = [
            MockDocumentSnapshot(
                "I1",
                {
                    "itemNo": "ROD-01",
                    "itemDescription": "Copper Rod",
                    "category": "Raw Material",
                    "currentStock": 20.0,
                    "minimumLevel": 50.0,
                    "stockUnit": "Kg",
                },
            ),
            MockDocumentSnapshot(
                "I2",
                {
                    "itemNo": "BOLT-01",
                    "itemDescription": "Steel Bolt",
                    "category": "Hardware",
                    "currentStock": 100.0,
                    "minimumLevel": 20.0,
                    "stockUnit": "Nos",
                },
            ),
        ]
        self.mock_db.collection().document().collection().stream.return_value = inv_docs

        insights = self.service.inventory_insights(company_id=self.company_a)
        self.assertEqual(insights.total_items, 2)
        self.assertEqual(insights.low_stock_count, 1)
        self.assertEqual(insights.low_stock_items[0].item_number, "ROD-01")
        self.assertEqual(insights.low_stock_items[0].shortage, 30.0)
        self.assertIn("Raw Material", insights.category_summary)
        self.assertEqual(insights.category_summary["Raw Material"]["total_stock"], 20.0)

    def test_find_employee_schema_clean_and_no_party_fields(self):
        """
        Verify find_employee:
        1. Returns only genuine Employee schema fields (no vendorCode, gstin, contactPersonName).
        2. Excludes soft-deleted employees (isDeleted=True).
        3. Limits each field to one occurrence without duplicated or fabricated data.
        """
        emp_docs = [
            MockDocumentSnapshot(
                "EMP01",
                {
                    "employeeId": "EMP01",
                    "name": "Rahul Sharma",
                    "email": "rahul.sharma@primot.erp",
                    "phone": "9876543210",
                    "designation": "Quality Engineer",
                    "department": "Quality",
                    "role": "Supervisor",
                    "status": "Active",
                    "isDeleted": False,
                    # Erroneous Party fields if accidentally present in document must NOT leak
                    "vendorCode": "VEN-999",
                    "gstin": "27AAAAA0000A1Z5",
                    "contactPersonName": "Should Not Exist",
                },
            ),
            MockDocumentSnapshot(
                "EMP02",
                {
                    "employeeId": "EMP02",
                    "name": "Rahul Verma",
                    "email": "rahul.verma@primot.erp",
                    "phone": "9876500000",
                    "designation": "Operator",
                    "department": "Machining",
                    "role": "Employee",
                    "status": "Active",
                    "isDeleted": True,  # Soft-deleted employee must be excluded
                },
            ),
        ]
        self.mock_db.collection().document().collection().stream.return_value = emp_docs

        res = self.service.find_employee(company_id=self.company_a, query="Rahul")
        self.assertEqual(res.total_matches, 1)
        self.assertEqual(len(res.matches), 1)

        emp = res.matches[0]
        self.assertEqual(emp.employee_id, "EMP01")
        self.assertEqual(emp.name, "Rahul Sharma")
        self.assertEqual(emp.designation, "Quality Engineer")
        self.assertEqual(emp.department, "Quality")
        self.assertEqual(emp.role, "Supervisor")
        self.assertEqual(emp.status, "Active")

        # Crucial security & data integrity checks:
        emp_dict = emp.model_dump()
        self.assertNotIn("vendorCode", emp_dict)
        self.assertNotIn("vendor_code", emp_dict)
        self.assertNotIn("gstin", emp_dict)
        self.assertNotIn("contactPersonName", emp_dict)
        self.assertNotIn("contact_person", emp_dict)

    def test_party_sales_total_preserves_transaction_statuses(self):
        """
        Verify party transaction history preserves exact Firestore values for
        both delivery status ('status') and managerial approval ('approval_status')
        without conflation.
        """
        sales_docs = [
            MockDocumentSnapshot(
                "S101",
                {
                    "saleNumber": "SO-2026-001",
                    "customerName": "ABC Industries",
                    "totalAmount": 15000.0,
                    "status": "Pending",  # Voucher delivery status
                    "approvalStatus": "Approved",  # Manager approval status
                    "saleDate": "2026-11-10T10:00:00",
                },
            ),
            MockDocumentSnapshot(
                "S102",
                {
                    "saleNumber": "SO-2026-002",
                    "customerName": "ABC Industries",
                    "totalAmount": 25000.0,
                    "status": "Delivered",  # Voucher delivery status
                    "approvalStatus": "Pending Approval",  # Manager approval status
                    "saleDate": "2026-11-12T11:00:00",
                },
            ),
        ]
        self.mock_db.collection().document().collection().stream.return_value = sales_docs

        res = self.service.party_sales_total(company_id=self.company_a, party_identifier="ABC Industries")
        self.assertEqual(res.sales_count, 2)
        self.assertEqual(res.total_billed_amount, 40000.0)
        self.assertEqual(len(res.recent_transactions), 2)

        t1 = res.recent_transactions[0]
        self.assertEqual(t1.reference_number, "SO-2026-001")
        self.assertEqual(t1.status, "Pending")
        self.assertEqual(t1.approval_status, "Approved")

        t2 = res.recent_transactions[1]
        self.assertEqual(t2.reference_number, "SO-2026-002")
        self.assertEqual(t2.status, "Delivered")
        self.assertEqual(t2.approval_status, "Pending Approval")

    def test_sales_summary_distinguishes_delivery_and_approval_statuses(self):
        """Verify delivery status (Pending/Delivered) and approval status (Approved/Pending Approval) are separate."""
        sales_docs = [
            # Delivery Pending, Approved
            MockDocumentSnapshot("s1", {
                "saleNumber": "SO-001",
                "saleDate": "2026-11-01",
                "customerName": "Customer A",
                "totalAmount": 1000.0,
                "status": "Pending",
                "approvalStatus": "Approved",
            }),
            # Delivered, Pending Approval
            MockDocumentSnapshot("s2", {
                "saleNumber": "SO-002",
                "saleDate": "2026-11-02",
                "customerName": "Customer B",
                "totalAmount": 2000.0,
                "status": "Delivered",
                "approvalStatus": "Pending Approval",
            }),
            # Delivered, Approved
            MockDocumentSnapshot("s3", {
                "saleNumber": "SO-003",
                "saleDate": "2026-11-03",
                "customerName": "Customer C",
                "totalAmount": 3000.0,
                "status": "Delivered",
                "approvalStatus": "Approved",
            }),
        ]
        self.mock_db.collection().document().collection().stream.return_value = sales_docs

        res = self.service.sales_summary(company_id=self.company_a)
        self.assertEqual(res.transaction_count, 3)
        self.assertEqual(res.pending_delivery_count, 1)
        self.assertEqual(res.completed_delivery_count, 2)
        self.assertEqual(res.approved_count, 2)
        self.assertEqual(res.pending_approval_count, 1)


if __name__ == "__main__":
    unittest.main()

