#!/usr/bin/env python3
"""Reset onboarding-related user data in Firestore.

This script removes onboarding/runtime user data while keeping identity aliases.
It deletes docs under users/{uid} for:
  - profile/*
  - routine/*
  - progress/*
  - stats/*
  - payments/*

Usage examples:
  python scripts/reset_user_onboarding.py --email user@example.com
  python scripts/reset_user_onboarding.py --uid firebase-uid
  python scripts/reset_user_onboarding.py --email user@example.com --dry-run
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Any

SUBCOLLECTIONS_TO_CLEAR = ("profile", "routine", "progress", "stats", "payments")
BATCH_SIZE = 200


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


def _delete_collection_docs(db: Any, collection_ref: Any, *, dry_run: bool) -> int:
    deleted = 0
    while True:
        docs = list(collection_ref.limit(BATCH_SIZE).stream())
        if not docs:
            break
        if dry_run:
            deleted += len(docs)
            break

        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        batch.commit()
        deleted += len(docs)
    return deleted


def main() -> int:
    parser = argparse.ArgumentParser(description="Reset onboarding-related data under users/{uid}.")
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
    user_ref = db.collection("users").document(uid)

    print(f"Target user uid: {uid}")
    print(f"Target root: {user_ref.path}")

    total_deleted = 0
    for name in SUBCOLLECTIONS_TO_CLEAR:
        col_ref = user_ref.collection(name)
        deleted = _delete_collection_docs(db, col_ref, dry_run=args.dry_run)
        total_deleted += deleted
        action = "Would delete" if args.dry_run else "Deleted"
        print(f"{action} {deleted} doc(s) in {col_ref.path}")

    if args.dry_run:
        print("Dry run: no changes applied.")
    else:
        print(f"Completed. Deleted {total_deleted} doc(s).")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(2)
