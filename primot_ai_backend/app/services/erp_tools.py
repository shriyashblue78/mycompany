import logging
from datetime import datetime, date
from typing import Any, Dict, List, Optional

from app.core.firebase import get_firestore_client
from app.core.utils import parse_firestore_date, parse_float
from app.schemas.erp_tools import (
    PartySummary,
    FindPartyResult,
    ItemDetail,
    StockResult,
    SummaryResult,
    TransactionRecord,
    PartySalesTotalResult,
)

logger = logging.getLogger(__name__)


class ERPReadToolsService:
    """
    Read-only ERP queries enforcing company isolation strictly derived from
    the authenticated user context.
    
    All methods require `company_id` passed from internal server authentication;
    never from unverified user parameters.
    """

    def __init__(self, db: Any = None):
        self._db = db

    @property
    def db(self):
        if self._db is None:
            self._db = get_firestore_client()
        return self._db

    def find_party(self, company_id: str, query: str) -> FindPartyResult:
        """
        Search parties by name, contact phone, or vendor code.
        Returns all matching parties if multiple found; never guesses.
        """
        if not company_id:
            raise ValueError("Company ID must be provided by authenticated context.")

        query_clean = (query or "").strip().lower()
        if not query_clean:
            return FindPartyResult(matches=[], total_matches=0, message="Search query cannot be empty.")

        parties_ref = self.db.collection("companies").document(company_id).collection("parties")
        docs = parties_ref.stream()

        matches: List[PartySummary] = []
        for doc in docs:
            data = doc.to_dict() or {}
            party_name = str(data.get("partyName", "")).strip()
            phone = str(data.get("contactNumber", "")).strip()
            vendor_code = str(data.get("vendorCode", "")).strip()
            contact_person = str(data.get("contactPersonName", "")).strip()

            # Case-insensitive substring match
            if (
                query_clean in party_name.lower()
                or query_clean in phone.lower()
                or query_clean in vendor_code.lower()
                or query_clean in contact_person.lower()
            ):
                matches.append(
                    PartySummary(
                        party_id=doc.id,
                        party_name=party_name,
                        party_type=str(data.get("partyType", "Customer")),
                        contact_number=phone,
                        contact_person=contact_person,
                        email=str(data.get("email", "")),
                        gstin=str(data.get("gstin", "")),
                        address=str(data.get("address", "")),
                        state=str(data.get("state", "")),
                        vendor_code=vendor_code,
                    )
                )

        count = len(matches)
        if count == 0:
            msg = f"No parties found matching '{query}'."
        elif count == 1:
            msg = f"Found 1 matching party: {matches[0].party_name}."
        else:
            msg = f"Found {count} matching parties. Please specify which party you want."

        return FindPartyResult(matches=matches, total_matches=count, message=msg)

    def get_item(self, company_id: str, query: str) -> Optional[ItemDetail]:
        """
        Retrieve item details from `/companies/{company_id}/inventory`.
        Searches by itemId, exact itemNo/partNumber, or itemName.
        """
        if not company_id:
            raise ValueError("Company ID must be provided by authenticated context.")

        query_clean = (query or "").strip().lower()
        if not query_clean:
            return None

        inv_ref = self.db.collection("companies").document(company_id).collection("inventory")

        # 1. Direct document ID lookup
        direct_doc = inv_ref.document(query.strip()).get()
        if direct_doc.exists:
            return self._doc_to_item_detail(direct_doc.id, direct_doc.to_dict() or {})

        # 2. Iterate collection to match itemNo / partNumber or itemName
        docs = inv_ref.stream()
        candidate = None
        for doc in docs:
            data = doc.to_dict() or {}
            item_no = str(data.get("itemNo") or data.get("partNumber") or "").strip().lower()
            item_name = str(data.get("itemDescription") or data.get("itemName") or "").strip().lower()

            if query_clean == item_no or query_clean == item_name:
                return self._doc_to_item_detail(doc.id, data)
            if query_clean in item_no or query_clean in item_name:
                if candidate is None:
                    candidate = self._doc_to_item_detail(doc.id, data)

        return candidate

    def get_stock(self, company_id: str, query: str) -> Optional[StockResult]:
        """
        Retrieves current recorded stock for an item from Primot inventory.
        Stock is explicitly returned with disclaimer that it represents recorded stock.
        """
        item = self.get_item(company_id=company_id, query=query)
        if not item:
            return None

        is_low = item.current_stock <= item.minimum_level
        return StockResult(
            item_id=item.item_id,
            item_number=item.item_number,
            item_name=item.item_name,
            stock_unit=item.stock_unit,
            recorded_current_stock=item.current_stock,
            minimum_level=item.minimum_level,
            is_low_stock=is_low,
        )

    def sales_summary(
        self,
        company_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
    ) -> SummaryResult:
        """
        Summarizes sales transactions within optional date range.
        Rule: Excludes records where status == 'Cancelled'.
        Does NOT silently filter by approvalStatus.
        """
        if not company_id:
            raise ValueError("Company ID must be provided by authenticated context.")

        sales_ref = self.db.collection("companies").document(company_id).collection("sales")
        docs = sales_ref.stream()

        total_amount = 0.0
        count = 0
        pending_count = 0
        delivered_count = 0
        records: List[TransactionRecord] = []

        for doc in docs:
            data = doc.to_dict() or {}
            status = str(data.get("status", "Pending")).strip()
            # Primot ERP Rule: Exclude Cancelled sales
            if status == "Cancelled":
                continue

            sale_dt = parse_firestore_date(data.get("saleDate"))
            if not self._is_within_range(sale_dt, start_date, end_date):
                continue

            amount = parse_float(data.get("totalAmount"))
            approval_status = str(data.get("approvalStatus", "Approved")).strip()
            customer_name = str(data.get("customerName", "Customer")).strip()
            sale_num = str(data.get("saleNumber") or data.get("invoiceNumber") or doc.id)

            # Determine items count via effectiveItems logic
            items_raw = data.get("items")
            if isinstance(items_raw, list) and len(items_raw) > 0:
                items_cnt = len(items_raw)
            else:
                items_cnt = 1 if data.get("itemName") else 0

            total_amount += amount
            count += 1
            if status == "Pending":
                pending_count += 1
            elif status == "Delivered":
                delivered_count += 1

            records.append(
                TransactionRecord(
                    id=doc.id,
                    reference_number=sale_num,
                    date=sale_dt.strftime("%Y-%m-%d") if sale_dt else None,
                    party_name=customer_name,
                    total_amount=amount,
                    status=status,
                    approval_status=approval_status,
                    items_count=items_cnt,
                )
            )

        return SummaryResult(
            transaction_type="sales",
            start_date=start_date.isoformat() if start_date else None,
            end_date=end_date.isoformat() if end_date else None,
            total_amount=round(total_amount, 2),
            transaction_count=count,
            pending_count=pending_count,
            completed_count=delivered_count,
            transactions=records,
        )

    def purchase_summary(
        self,
        company_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
    ) -> SummaryResult:
        """
        Summarizes purchase transactions within optional date range.
        Rule: Excludes records where status == 'Cancelled'.
        Does NOT silently filter by approvalStatus.
        """
        if not company_id:
            raise ValueError("Company ID must be provided by authenticated context.")

        purchases_ref = self.db.collection("companies").document(company_id).collection("purchases")
        docs = purchases_ref.stream()

        total_amount = 0.0
        count = 0
        pending_count = 0
        received_count = 0
        records: List[TransactionRecord] = []

        for doc in docs:
            data = doc.to_dict() or {}
            status = str(data.get("status", "Pending")).strip()
            # Primot ERP Rule: Exclude Cancelled purchases
            if status == "Cancelled":
                continue

            purchase_dt = parse_firestore_date(data.get("purchaseDate"))
            if not self._is_within_range(purchase_dt, start_date, end_date):
                continue

            amount = parse_float(data.get("totalAmount"))
            approval_status = str(data.get("approvalStatus", "Approved")).strip()
            supplier_name = str(data.get("supplierName", "Supplier")).strip()
            pur_num = str(data.get("purchaseNumber") or data.get("invoiceNumber") or doc.id)

            total_amount += amount
            count += 1
            if status == "Pending":
                pending_count += 1
            elif status == "Received":
                received_count += 1

            records.append(
                TransactionRecord(
                    id=doc.id,
                    reference_number=pur_num,
                    date=purchase_dt.strftime("%Y-%m-%d") if purchase_dt else None,
                    party_name=supplier_name,
                    total_amount=amount,
                    status=status,
                    approval_status=approval_status,
                    items_count=1,
                )
            )

        return SummaryResult(
            transaction_type="purchases",
            start_date=start_date.isoformat() if start_date else None,
            end_date=end_date.isoformat() if end_date else None,
            total_amount=round(total_amount, 2),
            transaction_count=count,
            pending_count=pending_count,
            completed_count=received_count,
            transactions=records,
        )

    def party_sales_total(
        self,
        company_id: str,
        party_identifier: str,
    ) -> PartySalesTotalResult:
        """
        Calculates a party's total billed sales in Primot ERP.
        Excludes Cancelled sales. Matches by partyId or customerName.
        Note: Payment tracking / outstanding balance ledger is not available.
        """
        if not company_id:
            raise ValueError("Company ID must be provided by authenticated context.")

        ident = (party_identifier or "").strip().lower()
        if not ident:
            return PartySalesTotalResult(
                party_name=party_identifier,
                total_billed_amount=0.0,
                sales_count=0,
                note="Party identifier was empty.",
            )

        sales_ref = self.db.collection("companies").document(company_id).collection("sales")
        docs = sales_ref.stream()

        matched_party_name = party_identifier
        matched_party_id = None
        total_billed = 0.0
        sales_count = 0
        pending_approval_count = 0
        approved_count = 0

        for doc in docs:
            data = doc.to_dict() or {}
            status = str(data.get("status", "Pending")).strip()
            if status == "Cancelled":
                continue

            doc_party_id = str(data.get("partyId", "")).strip().lower()
            customer_name = str(data.get("customerName", "")).strip()

            # Match either by partyId or customer name
            if ident == doc_party_id or ident in customer_name.lower():
                amount = parse_float(data.get("totalAmount"))
                total_billed += amount
                sales_count += 1
                matched_party_name = customer_name or matched_party_name
                matched_party_id = data.get("partyId") or matched_party_id

                app_status = str(data.get("approvalStatus", "Approved")).strip()
                if app_status == "Pending Approval":
                    pending_approval_count += 1
                else:
                    approved_count += 1

        return PartySalesTotalResult(
            party_id=matched_party_id,
            party_name=matched_party_name,
            total_billed_amount=round(total_billed, 2),
            sales_count=sales_count,
            pending_approval_count=pending_approval_count,
            approved_count=approved_count,
        )

    @staticmethod
    def _doc_to_item_detail(doc_id: str, data: Dict[str, Any]) -> ItemDetail:
        return ItemDetail(
            item_id=doc_id,
            item_number=str(data.get("itemNo") or data.get("partNumber") or ""),
            item_name=str(data.get("itemDescription") or data.get("itemName") or ""),
            category=str(data.get("category", "General")),
            stock_unit=str(data.get("stockUnit") or data.get("unit") or "Nos"),
            current_stock=parse_float(data.get("currentStock")),
            minimum_level=parse_float(data.get("minimumLevel")),
            unit_rate=parse_float(data.get("unitRate") or data.get("price")),
            is_finished_item=bool(data.get("isFinishedItem", False)),
            hsn_sac=str(data.get("hsnSac") or ""),
            under_group=str(data.get("underGroup") or data.get("group") or ""),
            store_location=str(data.get("storeLocation") or data.get("storeOrWip") or ""),
        )

    @staticmethod
    def _is_within_range(
        dt: Optional[datetime],
        start_date: Optional[date],
        end_date: Optional[date],
    ) -> bool:
        if dt is None:
            return start_date is None and end_date is None
        d = dt.date()
        if start_date and d < start_date:
            return False
        if end_date and d > end_date:
            return False
        return True


# Global singleton instance for service reuse
erp_tools_service = ERPReadToolsService()

