import asyncio
import unittest
from unittest.mock import MagicMock, patch
from fastapi import HTTPException
from firebase_admin import auth as fb_auth

from app.core.auth import get_current_user
from app.schemas.chat import ChatRequest, AuthenticatedUser
from app.api.routes.chat import chat_endpoint


class MockAuthCredentials:
    def __init__(self, token: str):
        self.credentials = token


class TestAuthAndChatLogic(unittest.TestCase):
    def test_missing_token(self):
        """Verify error when credentials token is empty."""
        creds = MockAuthCredentials(token="")
        with self.assertRaises(HTTPException) as ctx:
            asyncio.run(get_current_user(credentials=creds))
        self.assertEqual(ctx.exception.status_code, 401)
        self.assertIn("Missing Bearer authentication token", ctx.exception.detail)

    def test_invalid_token(self):
        """Verify malformed or invalid Bearer token is rejected."""
        creds = MockAuthCredentials(token="bad-token")
        with patch("firebase_admin.auth.verify_id_token", side_effect=fb_auth.InvalidIdTokenError("Invalid token")):
            with self.assertRaises(HTTPException) as ctx:
                asyncio.run(get_current_user(credentials=creds))
            self.assertEqual(ctx.exception.status_code, 401)
            self.assertIn("Invalid authentication token", ctx.exception.detail)

    def test_inactive_user_rejected(self):
        """Verify user with status != 'Active' is rejected with 403 Forbidden."""
        creds = MockAuthCredentials(token="valid-token")
        mock_decoded = {"uid": "user_inactive_123", "email": "inactive@example.com"}
        mock_user_data = {
            "uid": "user_inactive_123",
            "companyId": "COMP001",
            "role": "Employee",
            "status": "Inactive",
            "name": "Inactive User",
        }

        mock_doc = MagicMock()
        mock_doc.exists = True
        mock_doc.to_dict.return_value = mock_user_data

        mock_db = MagicMock()
        mock_db.collection().document().get.return_value = mock_doc

        with patch("firebase_admin.auth.verify_id_token", return_value=mock_decoded), \
             patch("app.core.auth.get_firestore_client", return_value=mock_db):
            with self.assertRaises(HTTPException) as ctx:
                asyncio.run(get_current_user(credentials=creds))
            self.assertEqual(ctx.exception.status_code, 403)
            self.assertIn("Inactive", ctx.exception.detail)

    def test_super_admin_rejected(self):
        """Verify super_admin role cannot access company tenant AI endpoints."""
        creds = MockAuthCredentials(token="valid-token")
        mock_decoded = {"uid": "super_admin_uid", "email": "admin@example.com"}
        mock_user_data = {
            "uid": "super_admin_uid",
            "companyId": "",
            "role": "super_admin",
            "status": "Active",
            "name": "Super Admin",
        }

        mock_doc = MagicMock()
        mock_doc.exists = True
        mock_doc.to_dict.return_value = mock_user_data

        mock_db = MagicMock()
        mock_db.collection().document().get.return_value = mock_doc

        with patch("firebase_admin.auth.verify_id_token", return_value=mock_decoded), \
             patch("app.core.auth.get_firestore_client", return_value=mock_db):
            with self.assertRaises(HTTPException) as ctx:
                asyncio.run(get_current_user(credentials=creds))
            self.assertEqual(ctx.exception.status_code, 403)
            self.assertIn("Super administrator", ctx.exception.detail)

    def test_missing_company_access_rejected(self):
        """Verify user without companyId is rejected."""
        creds = MockAuthCredentials(token="valid-token")
        mock_decoded = {"uid": "user_nocompany_uid", "email": "nocompany@example.com"}
        mock_user_data = {
            "uid": "user_nocompany_uid",
            "companyId": "",
            "role": "Employee",
            "status": "Active",
            "name": "Orphan User",
        }

        mock_doc = MagicMock()
        mock_doc.exists = True
        mock_doc.to_dict.return_value = mock_user_data

        mock_db = MagicMock()
        mock_db.collection().document().get.return_value = mock_doc

        with patch("firebase_admin.auth.verify_id_token", return_value=mock_decoded), \
             patch("app.core.auth.get_firestore_client", return_value=mock_db):
            with self.assertRaises(HTTPException) as ctx:
                asyncio.run(get_current_user(credentials=creds))
            self.assertEqual(ctx.exception.status_code, 403)
            self.assertIn("company membership", ctx.exception.detail)

    def test_valid_user_authentication_and_chat_response(self):
        """Verify valid authenticated user context resolves and receives safe response."""
        creds = MockAuthCredentials(token="valid-token")
        mock_decoded = {"uid": "valid_user_uid", "email": "owner@company.com"}
        mock_user_data = {
            "uid": "valid_user_uid",
            "companyId": "COMP_101",
            "employeeId": "EMP0001",
            "role": "Owner",
            "status": "Active",
            "name": "David Owner",
            "department": "Management",
            "designation": "Owner",
        }

        mock_doc = MagicMock()
        mock_doc.exists = True
        mock_doc.to_dict.return_value = mock_user_data

        mock_db = MagicMock()
        mock_db.collection().document().get.return_value = mock_doc

        with patch("firebase_admin.auth.verify_id_token", return_value=mock_decoded), \
             patch("app.core.auth.get_firestore_client", return_value=mock_db), \
             patch("app.api.routes.chat.chat_service.process_chat", return_value="Hello David Owner! Authenticated as Owner. Stock status retrieved."):
            authenticated_user = asyncio.run(get_current_user(credentials=creds))
            self.assertIsInstance(authenticated_user, AuthenticatedUser)
            self.assertEqual(authenticated_user.uid, "valid_user_uid")
            self.assertEqual(authenticated_user.company_id, "COMP_101")
            self.assertEqual(authenticated_user.role, "Owner")

            # Execute /chat endpoint logic
            request = ChatRequest(message="Check our inventory status")
            response = asyncio.run(chat_endpoint(request=request, current_user=authenticated_user))
            self.assertEqual(response.status, "success")
            self.assertIn("David Owner", response.reply)
            self.assertIn("Owner", response.reply)
            # Guarantee sensitive company ID or tokens are never exposed in user-facing message
            self.assertNotIn("COMP_101", response.reply)


if __name__ == "__main__":
    unittest.main()
