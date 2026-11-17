from typing import Dict, List, Optional
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
    pending_delivery_count: int = 0
    completed_delivery_count: int = 0
    pending_count: int = 0  # Delivery status (e.g. pending delivery)
    completed_count: int = 0  # Delivery status (e.g. delivered/received)
    approved_count: int = 0  # Management approval status
    pending_approval_count: int = 0  # Management approval status
    transactions: List[TransactionRecord] = Field(default_factory=list)


class PartySalesTotalResult(BaseModel):
    party_id: Optional[str] = None
    party_name: str
    total_billed_amount: float = 0.0
    currency: str = "₹"
    sales_count: int = 0
    pending_approval_count: int = 0
    approved_count: int = 0
    recent_transactions: List[TransactionRecord] = Field(default_factory=list)
    note: str = (
        "Reflects billed sales total in Primot excluding Cancelled vouchers. "
        "Customer payment tracking and outstanding balance calculations are unsupported."
    )


class ComparisonPeriod(BaseModel):
    label: str
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    total_amount: float = 0.0
    transaction_count: int = 0


class ReportComparisonResult(BaseModel):
    report_type: str  # "sales_comparison" or "purchase_comparison"
    currency: str = "₹"
    period_1: ComparisonPeriod
    period_2: ComparisonPeriod
    difference_amount: float = 0.0
    percentage_change: Optional[float] = None
    trend: str = "flat"  # "up", "down", "flat"


class PartyInsightItem(BaseModel):
    party_id: Optional[str] = None
    party_name: str
    total_amount: float = 0.0
    transaction_count: int = 0
    party_type: str = "Customer"


class PartyInsightsResult(BaseModel):
    insight_type: str  # "top_customers", "top_suppliers", "party_sales_ranking"
    currency: str = "₹"
    parties: List[PartyInsightItem] = Field(default_factory=list)
    total_parties: int = 0


class LowStockItemSummary(BaseModel):
    item_id: str
    item_number: str
    item_name: str
    category: str
    stock_unit: str
    current_stock: float
    minimum_level: float
    shortage: float


class EmployeeSummary(BaseModel):
    employee_id: str
    name: str
    email: str
    phone: str
    designation: str
    department: str
    role: str
    status: str


class FindEmployeeResult(BaseModel):
    matches: List[EmployeeSummary] = Field(default_factory=list)
    total_matches: int = 0
    message: str = ""


class InventoryInsightsResult(BaseModel):
    total_items: int = 0
    low_stock_count: int = 0
    low_stock_items: List[LowStockItemSummary] = Field(default_factory=list)
    category_summary: Dict[str, Dict[str, float]] = Field(default_factory=dict)
    disclaimer: str = "Stock reflects current recorded inventory in Primot ERP."


