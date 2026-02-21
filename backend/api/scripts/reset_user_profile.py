#!/usr/bin/env python3
"""Reset only the profile document for a user in Firestore.

Usage examples:
  python scripts/reset_user_profile.py --email user@example.com
  python scripts/reset_user_profile.py --uid firebase-uid
  python scripts/reset_user_profile.py --email user@example.com --dry-run
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Any


def _normalize_email(raw: str) -> str:
    return raw.strip().lower()


def _init_firestore(project_id: str | None) -> Any:
    import firebase_admin
    from firebase_admin import credentials, firestore

    if not firebase_admin._apps:
        options: dict[str, Any] = {}
        if project_id:
            options["projectId"] = project_id
        firebase_admin.initialize_app(credentials.ApplicationDefault(), options or None)
    return firestore.client()


def _resolve_uid(db: Any, *, email: str | None, uid: str | None) -> str:
    if uid:
        resolved = uid.strip()
        if not resolved:
            raise ValueError("--uid cannot be empty.")
        return resolved

    if not email:
        raise ValueError("Either --email or --uid is required.")

    normalized_email = _normalize_email(email)
    alias_doc = db.collection("user_email_aliases").document(normalized_email).get()
    if not alias_doc.exists:
        raise ValueError(f"No email alias found for {normalized_email}.")

    alias_data = alias_doc.to_dict() or {}
    canonical_uid = alias_data.get("canonicalUserId")
    if not isinstance(canonical_uid, str) or not canonical_uid.strip():
        raise ValueError(f"Alias exists but canonicalUserId is missing for {normalized_email}.")

    return canonical_uid.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Reset users/{uid}/profile/self.")
    identity = parser.add_mutually_exclusive_group(required=True)
    identity.add_argument("--email", help="User email (resolved through user_email_aliases).")
    identity.add_argument("--uid", help="Canonical Firebase UID.")
    parser.add_argument(
        "--project-id",
        default=os.getenv("GOOGLE_CLOUD_PROJECT", "").strip() or None,
        help="GCP project id (defaults to GOOGLE_CLOUD_PROJECT env var).",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print actions without deleting.")
    args = parser.parse_args()

    db = _init_firestore(args.project_id)
    uid = _resolve_uid(db, email=args.email, uid=args.uid)

    profile_ref = db.collection("users").document(uid).collection("profile").document("self")
    print(f"Target user uid: {uid}")
    print(f"Target doc: {profile_ref.path}")

    if args.dry_run:
        print("Dry run: no changes applied.")
        return 0

    profile_ref.delete()
    print("Deleted profile document.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(2)
