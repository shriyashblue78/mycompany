from typing import List, Optional
from pydantic import BaseModel, Field


class PartySummary(BaseModel):
    party_id: str
    party_name: str
    party_type: str = "Customer"
    contact_number: Optional[str] = ""
    contact_person: Optional[str] = ""
    email: Optional[str] = ""
    gstin: Optional[str] = ""
    address: Optional[str] = ""
    state: Optional[str] = ""
    vendor_code: Optional[str] = ""


class FindPartyResult(BaseModel):
    matches: List[PartySummary] = Field(default_factory=list)
    total_matches: int = 0
    message: str = ""


class ItemDetail(BaseModel):
    item_id: str
    item_number: str
    item_name: str
    category: str = "General"
    stock_unit: str = "Nos"
    current_stock: float = 0.0
    minimum_level: float = 0.0
    unit_rate: float = 0.0
    is_finished_item: bool = False
    hsn_sac: Optional[str] = ""
    under_group: Optional[str] = ""
    store_location: Optional[str] = ""


class StockResult(BaseModel):
    item_id: str
    item_number: str
    item_name: str
    stock_unit: str = "Nos"
    recorded_current_stock: float = 0.0
    minimum_level: float = 0.0
    is_low_stock: bool = False
    disclaimer: str = "This reflects current stock recorded in Primot inventory, not verified physical on-hand stock."


class TransactionItemDetail(BaseModel):
    item_number: Optional[str] = ""
    item_name: str
    quantity: float = 0.0
    unit: str = "Nos"
    rate: float = 0.0
    amount: float = 0.0


class TransactionRecord(BaseModel):
    id: str
    reference_number: str
    date: Optional[str] = None
    party_name: str
    total_amount: float
    status: str
    approval_status: str
    items_count: int = 0


class SummaryResult(BaseModel):
    transaction_type: str  # "sales" or "purchases"
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    total_amount: float = 0.0
    currency: str = "₹"
    transaction_count: int = 0
    pending_count: int = 0
    completed_count: int = 0  # Delivered (sales) or Received (purchases)
    transactions: List[TransactionRecord] = Field(default_factory=list)


class PartySalesTotalResult(BaseModel):
    party_id: Optional[str] = None
    party_name: str
    total_billed_amount: float = 0.0
    currency: str = "₹"
    sales_count: int = 0
    pending_approval_count: int = 0
    approved_count: int = 0
    note: str = (
        "Reflects billed sales total in Primot excluding Cancelled vouchers. "
        "Customer payment tracking and outstanding balance calculations are unsupported."
    )

