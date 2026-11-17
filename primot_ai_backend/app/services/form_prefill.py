"""
Form Prefill Service for Primot AI (Phase 8).
Validates module access, queries existing records within authenticated company scope,
normalizes form fields against strict allowlists, and constructs structured form actions.
"""

from typing import Any, Dict, List, Optional, Tuple
import logging
import re
from google.cloud import firestore

logger = logging.getLogger(__name__)

# Strict allowlists of modules and canonical routes
ALLOWED_FORM_MODULES = {
    "parties": {
        "title": "Party",
        "create_route": "/parties/add",
        "edit_route_template": "/parties/edit/{id}",
        "allowed_roles": ["Owner"],
        "collection": "parties",
        "mandatory_fields": ["partyName", "contactNumber", "state"],
        "field_allowlist": [
            "partyName",
            "partyType",
            "contactNumber",
            "contactPersonName",
            "email",
            "gstin",
            "address",
            "state",
            "vendorCode",
        ],
        "name_keys": ["partyName"],
    },
    "items": {
        "title": "Item",
        "create_route": "/inventory/add",
        "edit_route_template": "/inventory/edit/{id}",
        "allowed_roles": ["Owner", "HR", "Supervisor"],
        "collection": "inventory",
        "mandatory_fields": ["itemName", "partNumber", "process"],
        "field_allowlist": [
            "itemName",
            "category",
            "currentStock",
            "unit",
            "supplierName",
            "partNumber",
            "documentNumber",
            "process",
            "withMaterial",
        ],
        "name_keys": ["itemName", "partNumber"],
    },
    "employees": {
        "title": "Employee",
        "create_route": "/employees/add",
        "edit_route_template": "/employees/{id}/edit",
        "allowed_roles": ["Owner", "HR", "Supervisor"],
        "collection": "employees",
        "mandatory_fields": ["name", "email", "phone", "designation", "department", "role"],
        "field_allowlist": [
            "name",
            "email",
            "phone",
            "designation",
            "department",
            "role",
            "status",
            "panCardNumber",
            "aadhaarCardNumber",
            "permanentAddress",
            "currentAddress",
            "alternatePhone",
        ],
        "name_keys": ["name", "email", "employeeId"],
    },
    "sales": {
        "title": "Sales Entry",
        "create_route": "/sales/add",
        "edit_route_template": "/sales/edit/{id}",
        "allowed_roles": ["Owner", "Accountant"],
        "collection": "sales",
        "mandatory_fields": ["customerName", "customerPhone", "itemName", "quantity", "price"],
        "field_allowlist": [
            "customerName",
            "customerPhone",
            "itemName",
            "quantity",
            "price",
            "unit",
            "remarks",
            "invoiceNumber",
        ],
        "name_keys": ["customerName", "invoiceNumber", "itemName"],
    },
    "purchases": {
        "title": "Purchase Entry",
        "create_route": "/purchase/add",
        "edit_route_template": "/purchase/edit/{id}",
        "allowed_roles": ["Owner", "Accountant"],
        "collection": "purchases",
        "mandatory_fields": ["supplierName", "itemName", "quantity", "price"],
        "field_allowlist": [
            "supplierName",
            "supplierPhone",
            "itemName",
            "quantity",
            "price",
            "unit",
            "remarks",
            "invoiceNumber",
        ],
        "name_keys": ["supplierName", "invoiceNumber", "itemName"],
    },
}

# Synonyms for module mapping
MODULE_SYNONYMS: Dict[str, str] = {
    "party": "parties",
    "parties": "parties",
    "customer": "parties",
    "vendor": "parties",
    "supplier": "parties",
    "item": "items",
    "items": "items",
    "inventory": "items",
    "stock": "items",
    "product": "items",
    "employee": "employees",
    "employees": "employees",
    "staff": "employees",
    "worker": "employees",
    "sale": "sales",
    "sales": "sales",
    "billing": "sales",
    "invoice": "sales",
    "purchase": "purchases",
    "purchases": "purchases",
    "buy": "purchases",
}

# Unit normalizations
ALLOWED_UNITS = ["Nos", "Kg", "Litre", "Meter", "Box"]
UNIT_SYNONYMS: Dict[str, str] = {
    "nos": "Nos",
    "no": "Nos",
    "number": "Nos",
    "numbers": "Nos",
    "pcs": "Nos",
    "pieces": "Nos",
    "kg": "Kg",
    "kgs": "Kg",
    "kilogram": "Kg",
    "kilograms": "Kg",
    "litre": "Litre",
    "liter": "Litre",
    "litres": "Litre",
    "liters": "Litre",
    "l": "Litre",
    "meter": "Meter",
    "metre": "Meter",
    "meters": "Meter",
    "metres": "Meter",
    "m": "Meter",
    "box": "Box",
    "boxes": "Box",
}

# Category normalizations for inventory
ALLOWED_CATEGORIES = ["Raw Material", "Finished Goods", "Consumables", "Others"]
CATEGORY_SYNONYMS: Dict[str, str] = {
    "raw": "Raw Material",
    "raw material": "Raw Material",
    "raw materials": "Raw Material",
    "finished": "Finished Goods",
    "finished goods": "Finished Goods",
    "consumable": "Consumables",
    "consumables": "Consumables",
    "other": "Others",
    "others": "Others",
}

# Allowed Employee Dropdown Options
ALLOWED_DEPARTMENTS = [
    "Marketing",
    "Design",
    "Purchase",
    "Machining",
    "Assembly",
    "Quality",
    "Accountant",
    "General Employee",
]
DEPARTMENT_LOOKUP = {d.lower(): d for d in ALLOWED_DEPARTMENTS}

ALLOWED_ROLES = ["Employee", "HR", "Supervisor", "Accountant"]
ROLE_LOOKUP = {r.lower(): r for r in ALLOWED_ROLES}

ALLOWED_STATUSES = ["Active", "Inactive"]
STATUS_LOOKUP = {s.lower(): s for s in ALLOWED_STATUSES}


def normalize_department(dept_str: Optional[str]) -> Optional[str]:
    """Map natural language department string to exact ERP department."""
    if not dept_str:
        return None
    cleaned = dept_str.strip().lower()
    if cleaned in DEPARTMENT_LOOKUP:
        return DEPARTMENT_LOOKUP[cleaned]
    # Check if cleaned ends with 'dept' or 'department'
    for suffix in [" dept", " department"]:
        if cleaned.endswith(suffix):
            base = cleaned[: -len(suffix)].strip()
            if base in DEPARTMENT_LOOKUP:
                return DEPARTMENT_LOOKUP[base]
    return None


def normalize_role(role_str: Optional[str]) -> Optional[str]:
    """Map user role string to exact allowed system role (excluding Owner)."""
    if not role_str:
        return None
    cleaned = role_str.strip().lower()
    return ROLE_LOOKUP.get(cleaned)


def normalize_status(status_str: Optional[str]) -> Optional[str]:
    """Map status string to exact allowed status."""
    if not status_str:
        return None
    cleaned = status_str.strip().lower()
    return STATUS_LOOKUP.get(cleaned)
SUPPORTED_INDIAN_STATES = [
    "Andaman and Nicobar Islands",
    "Andhra Pradesh",
    "Arunachal Pradesh",
    "Assam",
    "Bihar",
    "Chandigarh",
    "Chhattisgarh",
    "Dadra and Nagar Haveli and Daman and Diu",
    "Delhi",
    "Goa",
    "Gujarat",
    "Haryana",
    "Himachal Pradesh",
    "Jammu and Kashmir",
    "Jharkhand",
    "Karnataka",
    "Kerala",
    "Ladakh",
    "Lakshadweep",
    "Madhya Pradesh",
    "Maharashtra",
    "Manipur",
    "Meghalaya",
    "Mizoram",
    "Nagaland",
    "Odisha",
    "Puducherry",
    "Punjab",
    "Rajasthan",
    "Sikkim",
    "Tamil Nadu",
    "Telangana",
    "Tripura",
    "Uttar Pradesh",
    "Uttarakhand",
    "West Bengal",
]
STATE_LOOKUP = {s.lower(): s for s in SUPPORTED_INDIAN_STATES}


def normalize_state(state_str: Optional[str]) -> Optional[str]:
    """
    Validate and normalize Indian state name.
    Never infer state from cities or arbitrary strings.
    Returns canonical state name if valid, else None.
    """
    if not state_str:
        return None
    cleaned = state_str.strip().lower()
    return STATE_LOOKUP.get(cleaned)


def normalize_module(module_str: str) -> Optional[str]:
    """Resolve user/model module string to canonical module key."""
    if not module_str:
        return None
    cleaned = module_str.strip().lower()
    return MODULE_SYNONYMS.get(cleaned)


def normalize_unit(unit_str: Optional[str]) -> Optional[str]:
    """Map user unit variations to canonical ERP units."""
    if not unit_str:
        return None
    cleaned = unit_str.strip().lower()
    return UNIT_SYNONYMS.get(cleaned, unit_str.capitalize())


def normalize_category(cat_str: Optional[str]) -> Optional[str]:
    """Map user category variations to canonical ERP inventory categories."""
    if not cat_str:
        return None
    cleaned = cat_str.strip().lower()
    return CATEGORY_SYNONYMS.get(cleaned)


class FormPrefillService:
    def __init__(self, db: Optional[firestore.Client] = None):
        self._db = db

    @property
    def db(self) -> firestore.Client:
        if self._db is None:
            from app.core.firebase import get_firestore_client
            self._db = get_firestore_client()
        return self._db

    def find_records_for_edit(
        self,
        company_id: str,
        collection_name: str,
        search_keys: List[str],
        query: str,
    ) -> List[Dict[str, Any]]:
        """
        Query company-scoped Firestore collection for matching records.
        Strictly enforces tenant boundary: /companies/{company_id}/{collection_name}
        """
        if not company_id:
            raise ValueError("Company ID must be provided by authenticated context.")

        query_clean = query.strip().lower()
        if not query_clean:
            return []

        coll_ref = self.db.collection("companies").document(company_id).collection(collection_name)
        docs = coll_ref.stream()

        matches = []
        for doc in docs:
            data = doc.to_dict() or {}
            doc_id = doc.id

            # Exact doc ID match
            if doc_id.lower() == query_clean:
                matches.append({"id": doc_id, "data": data})
                continue

            # Key search
            for k in search_keys:
                val = str(data.get(k, "")).strip().lower()
                if val and (query_clean == val or query_clean in val):
                    matches.append({"id": doc_id, "data": data})
                    break

        return matches

    def find_party_master(self, company_id: str, party_name: str) -> Optional[Dict[str, Any]]:
        """
        Query /companies/{company_id}/parties for a party by name.
        Enforces tenant boundary: /companies/{company_id}/parties
        """
        if not company_id or not party_name:
            return None
        clean_name = party_name.strip().lower()
        if not clean_name:
            return None
        try:
            coll_ref = self.db.collection("companies").document(company_id).collection("parties")
            docs = coll_ref.stream()
            for doc in docs:
                data = doc.to_dict() or {}
                p_name = str(data.get("partyName") or "").strip().lower()
                if p_name == clean_name or clean_name in p_name:
                    res = dict(data)
                    res["id"] = doc.id
                    return res
        except Exception as e:
            logger.warning("Error querying party master for %s: %s", party_name, e)
        return None

    def process_form_request(
        self,
        company_id: str,
        user_role: str,
        module: str,
        operation: str,
        raw_fields: Dict[str, Any],
        target_record: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Process a form prefill or edit request.
        Returns a dict with either:
          - "action": structured action dict
          - "error": refusal message
          - "need_clarification": message asking for specific details
        """
        canonical_mod = normalize_module(module)
        if not canonical_mod or canonical_mod not in ALLOWED_FORM_MODULES:
            return {
                "error": f"Form prefilling is not supported for module '{module}'. Supported modules: Parties, Items, Employees, Sales, Purchases."
            }

        mod_config = ALLOWED_FORM_MODULES[canonical_mod]

        # 1. Role Permission Guard
        if user_role not in mod_config["allowed_roles"]:
            allowed_roles_str = ", ".join(mod_config["allowed_roles"])
            return {
                "error": f"Access denied: Your role '{user_role}' is not authorized to create or edit {mod_config['title']} records. Required role: {allowed_roles_str}."
            }

        op = operation.strip().lower()
        if op not in ["create", "edit"]:
            return {"error": f"Unsupported operation '{operation}'. Supported operations: 'create', 'edit'."}

        # Field name alias mapping for common user/LLM naming variations
        FIELD_ALIASES = {
            "contact_person": "contactPersonName",
            "contact_person_name": "contactPersonName",
            "contactperson": "contactPersonName",
            "contactpersonname": "contactPersonName",
            "contact_name": "contactPersonName",
            "person": "contactPersonName",
            "contact_number": "contactNumber",
            "contactnumber": "contactNumber",
            "phone_number": "contactNumber",
            "phonenumber": "contactNumber",
            "phone": "contactNumber",
            "mobile": "contactNumber",
            "party_name": "partyName",
            "partyname": "partyName",
            "party_type": "partyType",
            "partytype": "partyType",
            "vendor_code": "vendorCode",
            "vendorcode": "vendorCode",
            "vendor_id": "vendorCode",
            "vendorid": "vendorCode",
            "customer": "customerName",
            "customer_name": "customerName",
            "customername": "customerName",
            "client": "customerName",
            "client_name": "customerName",
            "supplier": "supplierName",
            "supplier_name": "supplierName",
            "suppliername": "supplierName",
            "vendor": "supplierName",
            "vendor_name": "supplierName",
            "item": "itemName",
            "item_name": "itemName",
            "itemname": "itemName",
            "product": "itemName",
            "product_name": "itemName",
            "qty": "quantity",
            "rate": "price",
            "unit_price": "price",
            "unit_rate": "price",
            "cost": "price",
            "employee_name": "name",
            "employeename": "name",
            "emp_name": "name",
        }

        # Normalize incoming field names through alias mapping
        normalized_raw_fields: Dict[str, Any] = {}
        for k, v in (raw_fields or {}).items():
            canonical_key = FIELD_ALIASES.get(k.lower(), k)
            normalized_raw_fields[canonical_key] = v

        # Cross-module party field adaptation
        if canonical_mod == "sales":
            if not normalized_raw_fields.get("customerName"):
                for alt_k in ["customer", "partyName", "party", "supplierName", "supplier", "client", "client_name"]:
                    if normalized_raw_fields.get(alt_k):
                        normalized_raw_fields["customerName"] = normalized_raw_fields[alt_k]
                        break
            if not normalized_raw_fields.get("customerPhone"):
                for alt_ph in ["customer_phone", "contactNumber", "supplierPhone", "supplier_phone", "phone"]:
                    if normalized_raw_fields.get(alt_ph):
                        normalized_raw_fields["customerPhone"] = normalized_raw_fields[alt_ph]
                        break
            # Strictly never allow supplierName or supplierPhone in sales
            normalized_raw_fields.pop("supplierName", None)
            normalized_raw_fields.pop("supplierPhone", None)
        elif canonical_mod == "purchases" and "supplierName" not in normalized_raw_fields:
            if "partyName" in normalized_raw_fields:
                normalized_raw_fields["supplierName"] = normalized_raw_fields["partyName"]
            elif "party" in normalized_raw_fields:
                normalized_raw_fields["supplierName"] = normalized_raw_fields["party"]

        # 2. Sanitize and normalize input fields against strict allowlist
        sanitized_fields: Dict[str, Any] = {}
        for k, v in normalized_raw_fields.items():
            if k in mod_config["field_allowlist"] and v is not None:
                # Value normalization
                if k == "vendorCode":
                    # Vendor code must be an explicit code string, never a telephone number
                    v_str = str(v).strip()
                    if canonical_mod == "parties":
                        contact_num = str(normalized_raw_fields.get("contactNumber", "")).strip()
                        # If vendorCode matches contactNumber or looks purely like a 10-digit mobile phone, drop it
                        digits_only = re.sub(r"\D", "", v_str)
                        if (contact_num and v_str == contact_num) or (len(digits_only) == 10 and digits_only == v_str):
                            continue
                    v = v_str
                elif k == "contactPersonName":
                    v = str(v).strip()
                elif k == "state":
                    v = normalize_state(str(v))
                    if not v:
                        continue  # Never populate invalid or inferred non-state strings
                elif k == "partyType":
                    if str(v).strip().lower() in ["supplier", "vendor"]:
                        v = "Supplier"
                    else:
                        v = "Customer"
                elif k == "unit":
                    normalized_u = normalize_unit(str(v))
                    if not normalized_u:
                        continue
                    v = normalized_u
                elif k == "category":
                    normalized_c = normalize_category(str(v))
                    if not normalized_c:
                        continue
                    v = normalized_c
                elif k == "department":
                    normalized_d = normalize_department(str(v))
                    if not normalized_d:
                        continue
                    v = normalized_d
                elif k == "role":
                    normalized_r = normalize_role(str(v))
                    if not normalized_r:
                        continue
                    v = normalized_r
                elif k == "status":
                    normalized_s = normalize_status(str(v))
                    if not normalized_s:
                        continue
                    v = normalized_s
                elif k in ["quantity", "currentStock", "price"]:
                    try:
                        v = float(v)
                    except (ValueError, TypeError):
                        pass
                sanitized_fields[k] = v

        # Party Master detail reuse for sales customer
        if canonical_mod == "sales" and sanitized_fields.get("customerName"):
            cust_name = str(sanitized_fields["customerName"]).strip()
            party_doc = self.find_party_master(company_id, cust_name)
            if party_doc:
                if party_doc.get("partyName"):
                    sanitized_fields["customerName"] = party_doc["partyName"]
                if not sanitized_fields.get("customerPhone") and party_doc.get("contactNumber"):
                    sanitized_fields["customerPhone"] = str(party_doc["contactNumber"]).strip()

        # 3. Handle EDIT Operation
        if op == "edit":
            if not target_record or not target_record.strip():
                return {
                    "need_clarification": f"Please specify which {mod_config['title']} you would like to edit."
                }

            # Search existing record within tenant scope
            matches = self.find_records_for_edit(
                company_id=company_id,
                collection_name=mod_config["collection"],
                search_keys=mod_config["name_keys"],
                query=target_record,
            )

            if len(matches) == 0:
                return {
                    "need_clarification": f"No existing {mod_config['title']} record found matching '{target_record}'. Please verify the name or specify a valid record."
                }
            elif len(matches) > 1:
                # Ambiguous match: ask user to clarify
                match_labels = []
                for m in matches[:5]:
                    d = m["data"]
                    label = d.get("partyName") or d.get("itemName") or d.get("name") or m["id"]
                    match_labels.append(f"• {label} (ID: {m['id']})")
                matches_str = "\n".join(match_labels)
                return {
                    "need_clarification": f"Multiple {mod_config['title']} records match '{target_record}':\n{matches_str}\nPlease specify the exact record or ID you want to edit."
                }

            record = matches[0]
            record_id = record["id"]
            record_data = record["data"]
            record_title = (
                record_data.get("partyName")
                or record_data.get("itemName")
                or record_data.get("name")
                or target_record
            )

            edit_route = mod_config["edit_route_template"].format(id=record_id)

            return {
                "action": {
                    "action": "prefill_form",
                    "module": canonical_mod,
                    "operation": "edit",
                    "route": edit_route,
                    "record_id": record_id,
                    "record_title": record_title,
                    "fields": sanitized_fields,
                    "missing_fields": [],
                    "title": f"Review & Edit {mod_config['title']}",
                },
                "record_title": record_title,
            }

        # 4. Handle CREATE Operation
        # Check for missing mandatory fields
        missing_mandatory = []
        for mf in mod_config["mandatory_fields"]:
            if mf not in sanitized_fields or not str(sanitized_fields[mf]).strip():
                missing_mandatory.append(mf)

        record_title = (
            sanitized_fields.get("partyName")
            or sanitized_fields.get("itemName")
            or sanitized_fields.get("name")
            or sanitized_fields.get("customerName")
            or sanitized_fields.get("supplierName")
            or "New Entry"
        )

        return {
            "action": {
                "action": "prefill_form",
                "module": canonical_mod,
                "operation": "create",
                "route": mod_config["create_route"],
                "record_id": None,
                "record_title": record_title,
                "fields": sanitized_fields,
                "missing_fields": missing_mandatory,
                "title": f"Review & Create {mod_config['title']}",
            },
            "record_title": record_title,
            "missing_fields": missing_mandatory,
        }

