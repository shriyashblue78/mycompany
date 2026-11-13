import os
import logging
from typing import Optional
import firebase_admin
from firebase_admin import credentials, firestore, auth
from app.core.config import settings

logger = logging.getLogger(__name__)

_firebase_app: Optional[firebase_admin.App] = None


def initialize_firebase() -> firebase_admin.App:
    """
    Initializes Firebase Admin SDK using either explicit service account credentials
    or application default credentials.
    """
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app

    if len(firebase_admin._apps) > 0:
        _firebase_app = firebase_admin.get_app()
        return _firebase_app

    try:
        cred_path = settings.FIREBASE_CREDENTIALS_PATH
        if cred_path and os.path.exists(cred_path):
            logger.info("Initializing Firebase with credentials file: %s", cred_path)
            cred = credentials.Certificate(cred_path)
            _firebase_app = firebase_admin.initialize_app(
                cred,
                {"projectId": settings.FIREBASE_PROJECT_ID}
            )
        else:
            logger.info(
                "Initializing Firebase with default credentials for project: %s",
                settings.FIREBASE_PROJECT_ID,
            )
            # Falls back to Google Application Default Credentials
            _firebase_app = firebase_admin.initialize_app(
                options={"projectId": settings.FIREBASE_PROJECT_ID}
            )
        return _firebase_app
    except Exception as exc:
        logger.warning(
            "Firebase Admin initialization deferred or failed: %s. "
            "Ensure credentials or FIREBASE_PROJECT_ID are set before running live queries.",
            exc,
        )
        raise


def get_firestore_client():
    """Returns Firestore client instance."""
    initialize_firebase()
    return firestore.client()

