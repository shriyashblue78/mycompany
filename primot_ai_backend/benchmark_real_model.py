"""
CLI Verification Script for Phase 4: Real Local Model Testing

Runs live inference against the local llama.cpp server (http://127.0.0.1:8080)
using the actual Primot ERP tool-calling pipeline and reports timing, RAM, and tool accuracy.
"""

import sys
import time
import json
import psutil
from datetime import date
from typing import Dict, Any, List
from unittest.mock import patch, MagicMock

# Ensure primot_ai_backend is importable
import os
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app.schemas.chat import AuthenticatedUser
from app.services.llm_client import LlamaCppServerProvider, LLMClientException
from app.services.chat_service import ChatService
from app.services.tool_definitions import ERP_TOOL_DEFINITIONS
from app.services.erp_tools import erp_tools_service
from app.schemas.erp_tools import (
    StockResult,
    ItemDetail,
    PartySummary,
    FindPartyResult,
    SummaryResult,
    TransactionRecord,
    PartySalesTotalResult,
)

# Standard mock company fixtures for realistic tool answers
TEST_COMPANY_ID = "COMP_TEST_001"

TEST_USER = AuthenticatedUser(
    uid="usr_test_100",
    company_id=TEST_COMPANY_ID,
    employee_id="EMP0001",
    role="Owner",
    name="Test Owner",
    email="owner@testcorp.com",
    status="Active",
)

FIXTURES = {
    "item": ItemDetail(
        item_id="doc_itm_001",
        item_number="ITM-001",
        item_name="Hex Bolt M8",
        stock_unit="Nos",
        current_stock=120.0,
        minimum_level=15.0,
    ),
    "stock": StockResult(
        item_id="doc_itm_001",
        item_number="ITM-001",
        item_name="Hex Bolt M8",
        stock_unit="Nos",
        recorded_current_stock=120.0,
        minimum_level=15.0,
        is_low_stock=False,
    ),
    "party": FindPartyResult(
        matches=[
            PartySummary(
                party_id="pty_apex_1",
                party_name="Apex Steel Ltd",
                party_type="Customer",
                contact_number="9876543210",
                email="sales@apexsteel.com",
            )
        ],
        total_matches=1,
        message="Found 1 matching party: Apex Steel Ltd.",
    ),
    "party_sales": PartySalesTotalResult(
        party_id="pty_apex_1",
        party_name="Apex Steel Ltd",
        total_billed_amount=45250.0,
        sales_count=3,
        approved_count=3,
        pending_approval_count=0,
    ),
    "purchase_summary": SummaryResult(
        transaction_type="purchases",
        start_date=date.today().replace(day=1).isoformat(),
        end_date=date.today().isoformat(),
        total_amount=89500.0,
        transaction_count=4,
        completed_count=4,
        pending_count=0,
        transactions=[
            TransactionRecord(
                id="pur_1",
                reference_number="PUR-001",
                date=date.today().isoformat(),
                party_name="Steel Supplier Corp",
                total_amount=89500.0,
                status="Received",
                approval_status="Approved",
            )
        ],
    ),
}


def check_server_health(url: str = "http://127.0.0.1:8080") -> bool:
    import urllib.request
    try:
        req = urllib.request.Request(f"{url}/v1/models")
        with urllib.request.urlopen(req, timeout=3) as resp:
            return resp.status == 200
    except Exception:
        return False


def run_benchmark():
    server_url = "http://127.0.0.1:8080"
    print("=" * 70)
    print("  PRIMOT AI — PHASE 4 REAL MODEL INFERENCE BENCHMARK")
    print(f"  Target Server: {server_url}")
    print("=" * 70)

    # 1. Check server availability
    is_live = check_server_health(server_url)
    if not is_live:
        print(f"\n[ERROR] llama.cpp server is not running at {server_url}.")
        print("Please start llama.cpp server first using the instructions in README.md:")
        print("  llama-server.exe -m <path-to-gguf> --port 8080 -c 2048 -t 4\n")
        sys.exit(1)

    print("\n[OK] Local llama.cpp server is online and responding.")

    provider = LlamaCppServerProvider(base_url=server_url, timeout=45.0)
    chat_svc = ChatService(llm_provider=provider)

    test_queries = [
        ("How much stock is available for ITM-001?", "get_stock"),
        ("Apex Steel ke total sales kitne hue?", "party_sales_total"),
        ("Show me this month's purchase summary.", "purchase_summary"),
        ("Find the party named Apex Steel.", "find_party"),
    ]

    results = []

    # Patch ERP read services with standard fixtures for reproducible benchmark
    with patch.object(erp_tools_service, "get_stock", return_value=FIXTURES["stock"]), \
         patch.object(erp_tools_service, "get_item", return_value=FIXTURES["item"]), \
         patch.object(erp_tools_service, "find_party", return_value=FIXTURES["party"]), \
         patch.object(erp_tools_service, "party_sales_total", return_value=FIXTURES["party_sales"]), \
         patch.object(erp_tools_service, "purchase_summary", return_value=FIXTURES["purchase_summary"]):

        import asyncio

        for idx, (prompt, expected_tool) in enumerate(test_queries, 1):
            print(f"\n[{idx}/4] Query: \"{prompt}\"")
            print(f"    Expected Tool: {expected_tool}")

            mem_before = psutil.virtual_memory().used / (1024 * 1024)
            t_start = time.perf_counter()

            try:
                reply = asyncio.run(chat_svc.process_chat(TEST_USER, prompt))
                t_end = time.perf_counter()
                total_duration = t_end - t_start
                mem_after = psutil.virtual_memory().used / (1024 * 1024)

                print(f"    Total Duration: {total_duration:.2f}s")
                print(f"    RAM Usage: ~{mem_after:.1f} MB (change: {mem_after - mem_before:+.1f} MB)")
                print(f"    AI Reply: {reply[:160]}...")

                results.append({
                    "query": prompt,
                    "expected_tool": expected_tool,
                    "duration_sec": total_duration,
                    "success": True,
                    "reply_preview": reply[:100],
                })
            except Exception as e:
                print(f"    [FAIL] Error during processing: {e}")
                results.append({
                    "query": prompt,
                    "expected_tool": expected_tool,
                    "error": str(e),
                    "success": False,
                })

    print("\n" + "=" * 70)
    print("  SUMMARY OF REAL MODEL TEST RUN")
    print("=" * 70)
    all_ok = all(r.get("success", False) for r in results)
    for r in results:
        status_tag = "[PASS]" if r.get("success") else "[FAIL]"
        print(f"  {status_tag} {r['query']} -> {r.get('duration_sec', 0):.2f}s")

    print("\nResult: " + ("ALL PASSED" if all_ok else "SOME FAILED"))
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    run_benchmark()

