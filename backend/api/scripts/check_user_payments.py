#!/usr/bin/env python3
"""Inspect payment state and RevenueCat webhook events for a specific user.

Usage examples:
  python scripts/check_user_payments.py --email user@example.com
  python scripts/check_user_payments.py --uid firebase-uid
  python scripts/check_user_payments.py --email user@example.com --events-limit 100
  python scripts/check_user_payments.py --email user@example.com --show-event-payload
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
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


def _json_safe(value: Any) -> Any:
    if isinstance(value, dt.datetime):
        return value.isoformat()
    if isinstance(value, dt.date):
        return value.isoformat()
    if isinstance(value, dict):
        return {k: _json_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_json_safe(v) for v in value]
    if isinstance(value, tuple):
        return [_json_safe(v) for v in value]
    return value


def _event_sort_key(doc: Any) -> tuple[int, str, str]:
    data = doc.to_dict() or {}
    event_at = data.get("eventAt")
    if isinstance(event_at, dt.datetime):
        return (1, event_at.isoformat(), doc.id)
    return (0, "", doc.id)


def _print_json(obj: Any) -> None:
    print(json.dumps(_json_safe(obj), indent=2, sort_keys=True))


def _get_event_docs(db: Any, *, uid: str) -> list[Any]:
    from google.cloud.firestore_v1.base_query import FieldFilter

    events_ref = db.collection("payments").document("revenuecat").collection("events")
    by_app_user_id = list(events_ref.where(filter=FieldFilter("appUserId", "==", uid)).stream())
    by_raw_app_user_id = list(events_ref.where(filter=FieldFilter("rawAppUserId", "==", uid)).stream())

    deduped: dict[str, Any] = {doc.id: doc for doc in by_app_user_id}
    for doc in by_raw_app_user_id:
        deduped[doc.id] = doc

    docs = list(deduped.values())
    docs.sort(key=_event_sort_key, reverse=True)
    return docs


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Inspect users/{uid}/payments and payments/revenuecat/events for one user."
    )
    identity = parser.add_mutually_exclusive_group(required=True)
    identity.add_argument("--email", help="User email (resolved through user_email_aliases).")
    identity.add_argument("--uid", help="Canonical Firebase UID.")
    parser.add_argument(
        "--project-id",
        default=os.getenv("GOOGLE_CLOUD_PROJECT", "").strip() or None,
        help="GCP project id (defaults to GOOGLE_CLOUD_PROJECT env var).",
    )
    parser.add_argument(
        "--events-limit",
        type=int,
        default=50,
        help="Maximum number of webhook events to print (default: 50). Use 0 for all.",
    )
    parser.add_argument(
        "--show-event-payload",
        action="store_true",
        help="Print full webhook payload for each listed event.",
    )
    args = parser.parse_args()

    if args.events_limit < 0:
        raise ValueError("--events-limit cannot be negative.")

    db = _init_firestore(args.project_id)
    uid = _resolve_uid(db, email=args.email, uid=args.uid)
    user_ref = db.collection("users").document(uid)

    print(f"Target user uid: {uid}")
    print(f"User root: users/{uid}")

    print("\n=== Profile Doc (paymentOption focus) ===")
    profile_doc = user_ref.collection("profile").document("self").get()
    profile_path = f"users/{uid}/profile/self"
    print(f"Path: {profile_path}")
    print(f"Exists: {profile_doc.exists}")
    if profile_doc.exists:
        profile_data = profile_doc.to_dict() or {}
        profile_payment_option = profile_data.get("paymentOption")
        print(f"paymentOption: {_json_safe(profile_payment_option)}")

    print("\n=== Subscription Doc ===")
    subscription_doc = user_ref.collection("payments").document("subscription").get()
    subscription_path = f"users/{uid}/payments/subscription"
    print(f"Path: {subscription_path}")
    print(f"Exists: {subscription_doc.exists}")
    if subscription_doc.exists:
        _print_json(subscription_doc.to_dict() or {})

    print("\n=== Payments Subcollection Docs ===")
    payment_docs = list(user_ref.collection("payments").stream())
    print(f"Count: {len(payment_docs)}")
    if payment_docs:
        for doc in sorted(payment_docs, key=lambda d: d.id):
            print(f"- {doc.id}")
            _print_json(doc.to_dict() or {})

    print("\n=== RevenueCat Webhook Events ===")
    event_docs = _get_event_docs(db, uid=uid)
    total_events = len(event_docs)
    print(f"Total unique events (appUserId/rawAppUserId match): {total_events}")

    if total_events == 0:
        return 0

    limit = total_events if args.events_limit == 0 else min(total_events, args.events_limit)
    print(f"Showing: {limit}")
    for idx, doc in enumerate(event_docs[:limit], start=1):
        data = doc.to_dict() or {}
        print("---")
        print(f"{idx}. eventId={doc.id}")
        print(f"   eventType={data.get('eventType', '')}")
        print(f"   eventAt={_json_safe(data.get('eventAt', ''))}")
        print(f"   appUserId={data.get('appUserId', '')}")
        print(f"   rawAppUserId={data.get('rawAppUserId', '')}")
        print(f"   latest source fields: store={data.get('payload', {}).get('store', '')}")
        if args.show_event_payload:
            print("   payload:")
            _print_json(data.get("payload", {}))

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(2)
