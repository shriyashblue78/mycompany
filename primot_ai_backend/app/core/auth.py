import logging
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth
from app.core.firebase import get_firestore_client
from app.schemas.chat import AuthenticatedUser

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=True)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> AuthenticatedUser:
    """
    Verifies Firebase Bearer ID Token and retrieves users/{uid} from Firestore.
    
    Validation Rules (Matching Primot ERP Authentication Rules):
    1. Token must be valid, active, and signed by Firebase.
    2. Document users/{uid} must exist in Firestore.
    3. User status must be 'Active'.
    4. Super admin accounts ('super_admin') are rejected from standard tenant AI endpoints.
    5. User must have a valid non-empty 'companyId' associated with their tenant.
    """
    token = credentials.credentials
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Bearer authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 1. Verify Firebase ID Token
    try:
        decoded_token = auth.verify_id_token(token)
        uid = decoded_token.get("uid")
        if not uid:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token payload: missing UID.",
                headers={"WWW-Authenticate": "Bearer"},
            )
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token has expired.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except auth.InvalidIdTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logger.error("Token verification failure: %s", e)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 2. Retrieve users/{uid} document from Firestore
    try:
        db = get_firestore_client()
        user_doc_ref = db.collection("users").document(uid)
        user_doc = user_doc_ref.get()
    except Exception as e:
        logger.error("Failed to query user profile for uid %s: %s", uid, e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error retrieving user account profile.",
        )

    if not user_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User profile not registered in ERP database.",
        )

    data = user_doc.to_dict() or {}

    role = str(data.get("role", "")).strip()
    account_status = str(data.get("status", "Active")).strip()
    company_id = str(data.get("companyId", "")).strip()
    employee_id = str(data.get("employeeId", "")).strip()
    name = str(data.get("name", "")).strip()
    email = str(data.get("email", decoded_token.get("email", ""))).strip()

    # 3. Security Check: Reject super_admin from company-scoped AI operations
    if role.lower() == "super_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Super administrator accounts cannot access company tenant AI endpoints.",
        )

    # 4. Security Check: Reject Inactive or Suspended accounts
    if account_status.lower() != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account status is '{account_status}'. Only active accounts are permitted.",
        )

    # 5. Security Check: Company Membership Validation
    if not company_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User has no company membership configured.",
        )

    return AuthenticatedUser(
        uid=uid,
        company_id=company_id,
        employee_id=employee_id,
        role=role,
        name=name,
        email=email,
        status=account_status,
        department=data.get("department", ""),
        designation=data.get("designation", ""),
    )

