from datetime import date
from typing import Optional
from fastapi import APIRouter, Depends, Query, HTTPException, status
from app.core.auth import get_current_user
from app.schemas.chat import AuthenticatedUser
from app.schemas.erp_tools import (
    FindPartyResult,
    ItemDetail,
    StockResult,
    SummaryResult,
    PartySalesTotalResult,
)
from app.services.erp_tools import erp_tools_service

router = APIRouter(prefix="/tools", tags=["erp_tools"])


@router.get("/find-party", response_model=FindPartyResult)
def find_party_endpoint(
    q: str = Query(..., min_length=1, description="Party name, phone, or vendor code"),
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> FindPartyResult:
    """Search parties within the caller's company only."""
    return erp_tools_service.find_party(company_id=current_user.company_id, query=q)


@router.get("/get-item", response_model=ItemDetail)
def get_item_endpoint(
    q: str = Query(..., min_length=1, description="Item ID, item number, or item name"),
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> ItemDetail:
    """Retrieve full item details for an inventory item in caller's company."""
    item = erp_tools_service.get_item(company_id=current_user.company_id, query=q)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Item '{q}' not found in company inventory.",
        )
    return item


@router.get("/get-stock", response_model=StockResult)
def get_stock_endpoint(
    q: str = Query(..., min_length=1, description="Item ID, item number, or item name"),
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> StockResult:
    """Retrieve current stock recorded in Primot inventory."""
    stock = erp_tools_service.get_stock(company_id=current_user.company_id, query=q)
    if not stock:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Item '{q}' not found in company inventory.",
        )
    return stock


@router.get("/sales-summary", response_model=SummaryResult)
def sales_summary_endpoint(
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date (YYYY-MM-DD)"),
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> SummaryResult:
    """Summarize sales transactions for the caller's company."""
    return erp_tools_service.sales_summary(
        company_id=current_user.company_id,
        start_date=start_date,
        end_date=end_date,
    )


@router.get("/purchase-summary", response_model=SummaryResult)
def purchase_summary_endpoint(
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date (YYYY-MM-DD)"),
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> SummaryResult:
    """Summarize purchase transactions for the caller's company."""
    return erp_tools_service.purchase_summary(
        company_id=current_user.company_id,
        start_date=start_date,
        end_date=end_date,
    )


@router.get("/party-sales-total", response_model=PartySalesTotalResult)
def party_sales_total_endpoint(
    party: str = Query(..., min_length=1, description="Party ID or customer name"),
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> PartySalesTotalResult:
    """Calculate total billed sales for a specific party."""
    return erp_tools_service.party_sales_total(
        company_id=current_user.company_id,
        party_identifier=party,
    )

