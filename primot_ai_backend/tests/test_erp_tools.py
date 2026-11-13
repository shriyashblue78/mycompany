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


if __name__ == "__main__":
    unittest.main()

