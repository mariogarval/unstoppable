import datetime as dt
import os
import secrets
from typing import Any

import firebase_admin
from firebase_admin import auth, credentials, firestore
from flask import Flask, jsonify, request
from google.api_core import exceptions as google_exceptions


_db: firestore.Client | None = None


def _ensure_firebase_initialized() -> None:
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.ApplicationDefault())


def _init_firestore_client() -> firestore.Client:
    _ensure_firebase_initialized()
    return firestore.client()


app = Flask(__name__)


def _get_db() -> firestore.Client:
    global _db
    if _db is None:
        _db = _init_firestore_client()
    return _db


def _json_safe(value: Any) -> Any:
    if isinstance(value, dict):
        return {k: _json_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_json_safe(v) for v in value]
    if isinstance(value, (dt.datetime, dt.date)):
        return value.isoformat()
    return value


def _json_body() -> dict[str, Any]:
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return {}
    return payload


def _parse_iso_datetime(value: str) -> dt.datetime | None:
    raw = value.strip()
    if not raw:
        return None
    normalized = raw.replace("Z", "+00:00")
    try:
        parsed = dt.datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def _parse_event_datetime(event: dict[str, Any], ms_key: str, iso_key: str) -> dt.datetime | None:
    ms_value = event.get(ms_key)
    if isinstance(ms_value, (int, float)):
        return dt.datetime.fromtimestamp(ms_value / 1000.0, tz=dt.timezone.utc)

    iso_value = event.get(iso_key)
    if isinstance(iso_value, str):
        return _parse_iso_datetime(iso_value)
    return None


def _coerce_firestore_datetime(value: Any) -> dt.datetime | None:
    if isinstance(value, dt.datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=dt.timezone.utc)
        return value.astimezone(dt.timezone.utc)
    if hasattr(value, "to_datetime"):
        converted = value.to_datetime()  # Firestore Timestamp
        if converted.tzinfo is None:
            return converted.replace(tzinfo=dt.timezone.utc)
        return converted.astimezone(dt.timezone.utc)
    return None


def _webhook_authorized() -> bool:
    expected = os.getenv("REVENUECAT_WEBHOOK_AUTH", "").strip()
    if not expected:
        return False
    provided = request.headers.get("Authorization", "")
    if not provided.startswith("Bearer "):
        return False
    token = provided.replace("Bearer ", "", 1).strip()
    return secrets.compare_digest(token, expected)


def _normalize_email(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    normalized = value.strip().lower()
    return normalized or None


def _non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _profile_completion(profile: dict[str, Any]) -> tuple[bool, list[str]]:
    missing: list[str] = []

    if not _non_empty_string(profile.get("nickname")):
        missing.append("nickname")
    if not isinstance(profile.get("notificationsEnabled"), bool):
        missing.append("notificationsEnabled")
    if profile.get("termsAccepted") is not True:
        missing.append("termsAccepted")
    if profile.get("termsOver16Accepted") is not True:
        missing.append("termsOver16Accepted")
    if not _non_empty_string(profile.get("paymentOption")):
        missing.append("paymentOption")

    return len(missing) == 0, missing


def _upsert_uid_alias(uid: str, canonical_user_id: str, email: str | None, provider: str) -> None:
    payload: dict[str, Any] = {
        "canonicalUserId": canonical_user_id,
        "lastSeenUid": uid,
        "lastSeenProvider": provider,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    if email:
        payload["email"] = email
    try:
        _get_db().collection("user_uid_aliases").document(uid).set(payload, merge=True)
    except google_exceptions.GoogleAPICallError:
        return


def _resolve_canonical_user_id(decoded: dict[str, Any]) -> str | None:
    raw_uid = decoded.get("uid")
    if not isinstance(raw_uid, str) or not raw_uid.strip():
        return None
    uid = raw_uid.strip()

    firebase_claim = decoded.get("firebase")
    provider = ""
    if isinstance(firebase_claim, dict):
        raw_provider = firebase_claim.get("sign_in_provider")
        if isinstance(raw_provider, str):
            provider = raw_provider.strip()

    email = _normalize_email(decoded.get("email"))
    email_verified = decoded.get("email_verified") is True
    if not email or not email_verified:
        _upsert_uid_alias(uid=uid, canonical_user_id=uid, email=email, provider=provider)
        return uid

    alias_ref = _get_db().collection("user_email_aliases").document(email)
    try:
        alias_ref.create(
            {
                "canonicalUserId": uid,
                "email": email,
                "firstSeenUid": uid,
                "lastSeenUid": uid,
                "lastSeenProvider": provider,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
        )
        canonical_user_id = uid
    except google_exceptions.AlreadyExists:
        try:
            alias_doc = alias_ref.get()
        except google_exceptions.GoogleAPICallError:
            _upsert_uid_alias(uid=uid, canonical_user_id=uid, email=email, provider=provider)
            return uid

        alias_data = alias_doc.to_dict() if alias_doc.exists else {}
        raw_canonical = alias_data.get("canonicalUserId")
        if isinstance(raw_canonical, str) and raw_canonical.strip():
            canonical_user_id = raw_canonical.strip()
        else:
            canonical_user_id = uid
    except google_exceptions.GoogleAPICallError:
        _upsert_uid_alias(uid=uid, canonical_user_id=uid, email=email, provider=provider)
        return uid

    try:
        alias_ref.set(
            {
                "canonicalUserId": canonical_user_id,
                "email": email,
                "lastSeenUid": uid,
                "lastSeenProvider": provider,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )
    except google_exceptions.GoogleAPICallError:
        pass

    _upsert_uid_alias(uid=uid, canonical_user_id=canonical_user_id, email=email, provider=provider)
    if canonical_user_id != uid:
        _upsert_uid_alias(
            uid=canonical_user_id,
            canonical_user_id=canonical_user_id,
            email=email,
            provider=provider,
        )
    return canonical_user_id


def _canonical_user_id_for_app_user_id(raw_user_id: str) -> str:
    user_id = raw_user_id.strip()
    if not user_id:
        return user_id

    try:
        alias_doc = _get_db().collection("user_uid_aliases").document(user_id).get()
    except google_exceptions.GoogleAPICallError:
        return user_id

    if not alias_doc.exists:
        return user_id

    alias_data = alias_doc.to_dict() or {}
    raw_canonical = alias_data.get("canonicalUserId")
    if isinstance(raw_canonical, str) and raw_canonical.strip():
        return raw_canonical.strip()
    return user_id


def _user_id_from_request() -> tuple[str | None, tuple[dict[str, str], int] | None]:
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        _ensure_firebase_initialized()
        token = auth_header.replace("Bearer ", "", 1).strip()
        try:
            decoded = auth.verify_id_token(token)
            user_id = _resolve_canonical_user_id(decoded)
            if not user_id:
                return None, ({"error": "Token missing uid claim."}, 401)
            return user_id, None
        except Exception:
            return None, ({"error": "Invalid auth token."}, 401)

    # Developer fallback for local testing before auth wiring is complete.
    if os.getenv("ALLOW_DEV_USER_HEADER", "0") == "1":
        dev_user = request.headers.get("X-User-Id", "").strip()
        if dev_user:
            return dev_user, None

    return None, (
        {"error": "Missing Authorization bearer token."},
        401,
    )


def _today_yyyy_mm_dd() -> str:
    return dt.datetime.now(dt.timezone.utc).date().isoformat()


@app.get("/healthz")
def healthz() -> tuple[dict[str, str], int]:
    return {"status": "ok"}, 200


@app.post("/v1/user/profile")
def upsert_user_profile() -> tuple[Any, int]:
    user_id, err = _user_id_from_request()
    if err:
        return err

    payload = _json_body()
    allowed_fields = {
        "nickname",
        "ageGroup",
        "gender",
        "notificationsEnabled",
        "termsAccepted",
        "termsOver16Accepted",
        "termsMarketingAccepted",
        "paymentOption",
    }
    profile_data = {k: payload[k] for k in allowed_fields if k in payload}
    profile_data["updatedAt"] = firestore.SERVER_TIMESTAMP

    db = _get_db()
    profile_ref = (
        db.collection("users")
        .document(user_id)
        .collection("profile")
        .document("self")
    )
    profile_ref.set(profile_data, merge=True)

    return jsonify({"ok": True, "userId": user_id}), 200


@app.put("/v1/routines/current")
def upsert_routine() -> tuple[Any, int]:
    user_id, err = _user_id_from_request()
    if err:
        return err

    payload = _json_body()
    tasks = payload.get("tasks", [])
    if tasks is not None and not isinstance(tasks, list):
        return jsonify({"error": "tasks must be an array."}), 400

    routine_data = {}
    if "routineTime" in payload:
        routine_data["routineTime"] = payload["routineTime"]
    if "tasks" in payload:
        routine_data["tasks"] = payload["tasks"]
    routine_data["updatedAt"] = firestore.SERVER_TIMESTAMP

    db = _get_db()
    routine_ref = (
        db.collection("users")
        .document(user_id)
        .collection("routine")
        .document("current")
    )
    routine_ref.set(routine_data, merge=True)

    return jsonify({"ok": True, "userId": user_id}), 200


@app.post("/v1/progress/daily")
def upsert_daily_progress() -> tuple[Any, int]:
    user_id, err = _user_id_from_request()
    if err:
        return err

    payload = _json_body()
    date_value = str(payload.get("date", _today_yyyy_mm_dd()))

    try:
        dt.date.fromisoformat(date_value)
    except ValueError:
        return jsonify({"error": "date must be yyyy-mm-dd."}), 400

    completed = payload.get("completed")
    total = payload.get("total")
    completed_task_ids = payload.get("completedTaskIds", [])

    if not isinstance(completed, int) or completed < 0:
        return jsonify({"error": "completed must be a non-negative integer."}), 400
    if not isinstance(total, int) or total < 0:
        return jsonify({"error": "total must be a non-negative integer."}), 400
    if not isinstance(completed_task_ids, list):
        return jsonify({"error": "completedTaskIds must be an array."}), 400

    progress_doc = {
        "date": date_value,
        "completed": completed,
        "total": total,
        "completedTaskIds": completed_task_ids,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    db = _get_db()
    progress_ref = (
        db.collection("users")
        .document(user_id)
        .collection("progress")
        .document(date_value)
    )
    progress_ref.set(progress_doc, merge=True)

    return jsonify({"ok": True, "userId": user_id, "date": date_value}), 200


@app.get("/v1/bootstrap")
def get_bootstrap() -> tuple[Any, int]:
    user_id, err = _user_id_from_request()
    if err:
        return err

    db = _get_db()
    user_ref = db.collection("users").document(user_id)
    profile_doc = user_ref.collection("profile").document("self").get()
    routine_doc = user_ref.collection("routine").document("current").get()
    streak_doc = user_ref.collection("stats").document("streak").get()
    today_doc = user_ref.collection("progress").document(_today_yyyy_mm_dd()).get()
    subscription_doc = user_ref.collection("payments").document("subscription").get()
    profile_data = profile_doc.to_dict() if profile_doc.exists else {}
    profile_complete, missing_profile_fields = _profile_completion(profile_data)

    response = {
        "userId": user_id,
        "profile": _json_safe(profile_data),
        "isProfileComplete": profile_complete,
        "profileCompletion": {
            "isComplete": profile_complete,
            "missingRequiredFields": missing_profile_fields,
        },
        "routine": _json_safe(routine_doc.to_dict() if routine_doc.exists else {}),
        "streak": _json_safe(streak_doc.to_dict() if streak_doc.exists else {}),
        "progress": {
            "today": _json_safe(today_doc.to_dict() if today_doc.exists else {}),
        },
        "subscription": _json_safe(subscription_doc.to_dict() if subscription_doc.exists else {}),
    }
    return jsonify(response), 200


@app.get("/v1/user/subscription")
def get_user_subscription() -> tuple[Any, int]:
    user_id, err = _user_id_from_request()
    if err:
        return err

    db = _get_db()
    subscription_doc = (
        db.collection("users")
        .document(user_id)
        .collection("payments")
        .document("subscription")
        .get()
    )
    return (
        jsonify(
            {
                "ok": True,
                "userId": user_id,
                "subscription": _json_safe(subscription_doc.to_dict() if subscription_doc.exists else {}),
            }
        ),
        200,
    )


@app.post("/v1/payments/subscription/snapshot")
def upsert_subscription_snapshot() -> tuple[Any, int]:
    user_id, err = _user_id_from_request()
    if err:
        return err

    payload = _json_body()
    allowed_fields = {
        "entitlementId",
        "entitlementIds",
        "isActive",
        "productId",
        "store",
        "periodType",
        "expirationAt",
        "gracePeriodExpiresAt",
    }
    snapshot: dict[str, Any] = {k: payload[k] for k in allowed_fields if k in payload}
    snapshot["provider"] = "revenuecat"
    snapshot["appUserId"] = user_id
    snapshot["source"] = "app_snapshot"
    snapshot["updatedAt"] = firestore.SERVER_TIMESTAMP

    if isinstance(snapshot.get("expirationAt"), str):
        parsed = _parse_iso_datetime(snapshot["expirationAt"])
        if parsed is not None:
            snapshot["expirationAt"] = parsed
    if isinstance(snapshot.get("gracePeriodExpiresAt"), str):
        parsed = _parse_iso_datetime(snapshot["gracePeriodExpiresAt"])
        if parsed is not None:
            snapshot["gracePeriodExpiresAt"] = parsed

    db = _get_db()
    (
        db.collection("users")
        .document(user_id)
        .collection("payments")
        .document("subscription")
        .set(snapshot, merge=True)
    )
    return jsonify({"ok": True, "userId": user_id}), 200


@app.post("/v1/payments/revenuecat/webhook")
def revenuecat_webhook() -> tuple[Any, int]:
    if not _webhook_authorized():
        return jsonify({"error": "Unauthorized webhook request."}), 401

    payload = _json_body()
    event = payload.get("event", payload)
    if not isinstance(event, dict):
        return jsonify({"error": "Invalid webhook payload."}), 400

    raw_event_id = event.get("id") or event.get("event_id")
    if not isinstance(raw_event_id, str) or not raw_event_id.strip():
        return jsonify({"error": "Missing event id."}), 400
    event_id = raw_event_id.strip()

    raw_event_type = event.get("type")
    event_type = str(raw_event_type).strip().upper() if raw_event_type else "UNKNOWN"

    raw_user_id = event.get("app_user_id")
    if not isinstance(raw_user_id, str) or not raw_user_id.strip():
        return jsonify({"error": "Missing app_user_id."}), 400
    app_user_id = raw_user_id.strip()
    canonical_app_user_id = _canonical_user_id_for_app_user_id(app_user_id)

    entitlement_ids: list[str] = []
    if isinstance(event.get("entitlement_ids"), list):
        entitlement_ids = [
            str(v).strip()
            for v in event.get("entitlement_ids", [])
            if isinstance(v, str) and v.strip()
        ]
    elif isinstance(event.get("entitlement_id"), str) and event["entitlement_id"].strip():
        entitlement_ids = [event["entitlement_id"].strip()]

    product_id = str(event.get("product_id", "")).strip()
    store = str(event.get("store", "")).strip()
    period_type = str(event.get("period_type", "")).strip()

    expiration_at = _parse_event_datetime(event, "expiration_at_ms", "expiration_at")
    grace_period_expires_at = _parse_event_datetime(
        event, "grace_period_expiration_at_ms", "grace_period_expiration_at"
    )
    event_at = _parse_event_datetime(event, "event_timestamp_ms", "event_timestamp")
    if event_at is None:
        event_at = _parse_event_datetime(event, "purchased_at_ms", "purchased_at")
    if event_at is None:
        event_at = dt.datetime.now(dt.timezone.utc)

    active_event_types = {"INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "PRODUCT_CHANGE"}
    inactive_event_types = {"EXPIRATION", "CANCELLATION", "BILLING_ISSUE"}

    if event_type in active_event_types:
        is_active = True
    elif event_type in inactive_event_types:
        is_active = False
    elif expiration_at is not None:
        is_active = expiration_at > dt.datetime.now(dt.timezone.utc)
    else:
        is_active = False

    db = _get_db()
    event_ref = db.collection("payments").document("revenuecat").collection("events").document(event_id)

    try:
        event_ref.create(
            {
                "provider": "revenuecat",
                "eventId": event_id,
                "eventType": event_type,
                "appUserId": canonical_app_user_id,
                "rawAppUserId": app_user_id,
                "eventAt": event_at,
                "receivedAt": firestore.SERVER_TIMESTAMP,
                "payload": event,
            }
        )
    except google_exceptions.AlreadyExists:
        return jsonify({"ok": True, "duplicate": True, "eventId": event_id}), 200

    subscription_ref = (
        db.collection("users")
        .document(canonical_app_user_id)
        .collection("payments")
        .document("subscription")
    )
    existing_doc = subscription_ref.get()
    existing_data = existing_doc.to_dict() if existing_doc.exists else {}
    existing_event_at = _coerce_firestore_datetime(existing_data.get("latestEventAt"))
    if existing_event_at is not None and event_at < existing_event_at:
        return jsonify({"ok": True, "ignoredOutOfOrder": True, "eventId": event_id}), 200

    entitlement_id = entitlement_ids[0] if entitlement_ids else ""
    normalized = {
        "provider": "revenuecat",
        "appUserId": canonical_app_user_id,
        "rawAppUserId": app_user_id,
        "entitlementId": entitlement_id,
        "entitlementIds": entitlement_ids,
        "isActive": is_active,
        "productId": product_id,
        "store": store,
        "periodType": period_type,
        "expirationAt": expiration_at,
        "gracePeriodExpiresAt": grace_period_expires_at,
        "latestEventAt": event_at,
        "latestEventType": event_type,
        "rawEventId": event_id,
        "source": "webhook",
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    subscription_ref.set(normalized, merge=True)

    return jsonify({"ok": True, "eventId": event_id}), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port, debug=False)
