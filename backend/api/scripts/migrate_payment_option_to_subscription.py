#!/usr/bin/env python3
"""Backfill users/{uid}/payments/subscription.paymentOption from profile data.

Usage examples:
  python scripts/migrate_payment_option_to_subscription.py --email user@example.com
  python scripts/migrate_payment_option_to_subscription.py --uid firebase-uid
  python scripts/migrate_payment_option_to_subscription.py --all
  python scripts/migrate_payment_option_to_subscription.py --all --apply
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Any, Iterable


def _normalize_email(raw: str) -> str:
    return raw.strip().lower()


def _coerce_payment_option(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    normalized = value.strip().lower()
    if not normalized:
        return None

    aliases = {
        "annual": "annual",
        "yearly": "annual",
        "year": "annual",
        "monthly": "monthly",
        "month": "monthly",
        "weekly": "weekly",
        "week": "weekly",
        "lifetime": "lifetime",
        "life": "lifetime",
    }
    return aliases.get(normalized, normalized)


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
        resolved_uid = uid.strip()
        if not resolved_uid:
            raise ValueError("--uid cannot be empty.")
        return resolved_uid

    if not email:
        raise ValueError("Either --email or --uid is required when --all is not set.")

    normalized_email = _normalize_email(email)
    alias_doc = db.collection("user_email_aliases").document(normalized_email).get()
    if not alias_doc.exists:
        raise ValueError(f"No email alias found for {normalized_email}.")

    alias_data = alias_doc.to_dict() or {}
    canonical_uid = alias_data.get("canonicalUserId")
    if not isinstance(canonical_uid, str) or not canonical_uid.strip():
        raise ValueError(f"Alias exists but canonicalUserId is missing for {normalized_email}.")

    return canonical_uid.strip()


def _iter_target_uids(db: Any, *, email: str | None, uid: str | None, all_users: bool) -> Iterable[str]:
    if all_users:
        docs = db.collection("users").stream()
        for doc in docs:
            raw_uid = str(doc.id).strip()
            if raw_uid:
                yield raw_uid
        return

    yield _resolve_uid(db, email=email, uid=uid)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Backfill paymentOption from users/{uid}/profile/self into users/{uid}/payments/subscription."
    )
    identity = parser.add_mutually_exclusive_group(required=True)
    identity.add_argument("--email", help="User email (resolved through user_email_aliases).")
    identity.add_argument("--uid", help="Canonical Firebase UID.")
    identity.add_argument("--all", action="store_true", help="Process all users in users/*.")
    parser.add_argument(
        "--project-id",
        default=os.getenv("GOOGLE_CLOUD_PROJECT", "").strip() or None,
        help="GCP project id (defaults to GOOGLE_CLOUD_PROJECT env var).",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply writes. Default is dry-run.",
    )
    args = parser.parse_args()

    dry_run = not args.apply
    db = _init_firestore(args.project_id)
    uids = sorted(set(_iter_target_uids(db, email=args.email, uid=args.uid, all_users=args.all)))

    if not uids:
        print("No users found to process.")
        return 0

    scanned = 0
    copied = 0
    skipped_existing = 0
    skipped_missing = 0
    conflicts = 0
    errors = 0

    action = "Would copy" if dry_run else "Copied"
    print(f"Mode: {'DRY-RUN' if dry_run else 'APPLY'}")
    print(f"Target users: {len(uids)}")

    from firebase_admin import firestore

    for uid in uids:
        scanned += 1
        user_ref = db.collection("users").document(uid)
        profile_ref = user_ref.collection("profile").document("self")
        subscription_ref = user_ref.collection("payments").document("subscription")

        try:
            profile_doc = profile_ref.get()
            subscription_doc = subscription_ref.get()
        except Exception as exc:  # pragma: no cover - defensive path
            errors += 1
            print(f"[ERROR] users/{uid}: failed to read docs: {exc}")
            continue

        profile_data = profile_doc.to_dict() if profile_doc.exists else {}
        subscription_data = subscription_doc.to_dict() if subscription_doc.exists else {}

        profile_option = _coerce_payment_option(profile_data.get("paymentOption"))
        subscription_option = _coerce_payment_option(subscription_data.get("paymentOption"))

        if subscription_option:
            skipped_existing += 1
            if profile_option and profile_option != subscription_option:
                conflicts += 1
                print(
                    f"[CONFLICT] users/{uid}: "
                    f"profile.paymentOption={profile_option} subscription.paymentOption={subscription_option}"
                )
            continue

        if not profile_option:
            skipped_missing += 1
            continue

        payload = {
            "paymentOption": profile_option,
            "provider": "profile_sync",
            "source": "profile_payment_option_migration",
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }

        if dry_run:
            copied += 1
            print(f"[DRY-RUN] {action} users/{uid}/payments/subscription.paymentOption={profile_option}")
            continue

        try:
            subscription_ref.set(payload, merge=True)
            copied += 1
            print(f"[OK] {action} users/{uid}/payments/subscription.paymentOption={profile_option}")
        except Exception as exc:  # pragma: no cover - defensive path
            errors += 1
            print(f"[ERROR] users/{uid}: failed to write subscription doc: {exc}")

    print("\nSummary")
    print(f"- scanned: {scanned}")
    print(f"- copied: {copied}")
    print(f"- skipped_existing: {skipped_existing}")
    print(f"- skipped_missing: {skipped_missing}")
    print(f"- conflicts: {conflicts}")
    print(f"- errors: {errors}")

    return 0 if errors == 0 else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(2)
