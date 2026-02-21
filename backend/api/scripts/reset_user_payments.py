#!/usr/bin/env python3
"""Reset payment/subscription data for a user in Firestore.

This script deletes documents under:
  - users/{uid}/payments/*
  - users/{uid}/profile/self.paymentOption

Optional:
  - payments/revenuecat/events/* for the same user id

Usage examples:
  python scripts/reset_user_payments.py --email user@example.com
  python scripts/reset_user_payments.py --uid firebase-uid
  python scripts/reset_user_payments.py --email user@example.com --clear-webhook-events
  python scripts/reset_user_payments.py --email user@example.com --dry-run
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Any

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


def _delete_revenuecat_event_docs(db: Any, *, uid: str, dry_run: bool) -> int:
    events_ref = db.collection("payments").document("revenuecat").collection("events")
    fields = ("appUserId", "rawAppUserId")

    if dry_run:
        ids: set[str] = set()
        for field in fields:
            for doc in events_ref.where(field, "==", uid).stream():
                ids.add(doc.id)
        return len(ids)

    deleted = 0
    for field in fields:
        while True:
            docs = list(events_ref.where(field, "==", uid).limit(BATCH_SIZE).stream())
            if not docs:
                break
            batch = db.batch()
            for doc in docs:
                batch.delete(doc.reference)
            batch.commit()
            deleted += len(docs)
    return deleted


def _reset_profile_payment_option(db: Any, *, uid: str, dry_run: bool) -> bool:
    from firebase_admin import firestore

    profile_ref = db.collection("users").document(uid).collection("profile").document("self")
    profile_doc = profile_ref.get()
    if not profile_doc.exists:
        return False

    profile_data = profile_doc.to_dict() or {}
    has_payment_option = "paymentOption" in profile_data
    if dry_run or not has_payment_option:
        return has_payment_option

    profile_ref.set(
        {
            "paymentOption": firestore.DELETE_FIELD,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Reset payment data under users/{uid}/payments.")
    identity = parser.add_mutually_exclusive_group(required=True)
    identity.add_argument("--email", help="User email (resolved through user_email_aliases).")
    identity.add_argument("--uid", help="Canonical Firebase UID.")
    parser.add_argument(
        "--project-id",
        default=os.getenv("GOOGLE_CLOUD_PROJECT", "").strip() or None,
        help="GCP project id (defaults to GOOGLE_CLOUD_PROJECT env var).",
    )
    parser.add_argument(
        "--clear-webhook-events",
        action="store_true",
        help="Also delete matching docs in payments/revenuecat/events by appUserId/rawAppUserId.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print actions without deleting.")
    args = parser.parse_args()

    db = _init_firestore(args.project_id)
    uid = _resolve_uid(db, email=args.email, uid=args.uid)
    payments_ref = db.collection("users").document(uid).collection("payments")
    payments_path = f"users/{uid}/payments"

    print(f"Target user uid: {uid}")
    print(f"Target root: {payments_path}")

    deleted_payments = _delete_collection_docs(db, payments_ref, dry_run=args.dry_run)
    action = "Would delete" if args.dry_run else "Deleted"
    print(f"{action} {deleted_payments} doc(s) in {payments_path}")

    profile_path = f"users/{uid}/profile/self"
    payment_option_reset = _reset_profile_payment_option(db, uid=uid, dry_run=args.dry_run)
    profile_action = "Would reset" if args.dry_run else "Reset"
    if payment_option_reset:
        print(f"{profile_action} paymentOption in {profile_path}")
    else:
        print(f"No paymentOption field found in {profile_path}")

    if args.clear_webhook_events:
        deleted_events = _delete_revenuecat_event_docs(db, uid=uid, dry_run=args.dry_run)
        print(f"{action} {deleted_events} doc(s) in payments/revenuecat/events for uid={uid}")

    if args.dry_run:
        print("Dry run: no changes applied.")
    else:
        print("Completed payment reset.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(2)
