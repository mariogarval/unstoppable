import datetime as dt
import os
from typing import Any

import firebase_admin
from firebase_admin import auth, credentials, firestore
from flask import Flask, jsonify, request


_db: firestore.Client | None = None


def _init_firestore_client() -> firestore.Client:
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.ApplicationDefault())
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


def _user_id_from_request() -> tuple[str | None, tuple[dict[str, str], int] | None]:
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header.replace("Bearer ", "", 1).strip()
        try:
            decoded = auth.verify_id_token(token)
            user_id = decoded.get("uid")
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

    response = {
        "userId": user_id,
        "profile": _json_safe(profile_doc.to_dict() if profile_doc.exists else {}),
        "routine": _json_safe(routine_doc.to_dict() if routine_doc.exists else {}),
        "streak": _json_safe(streak_doc.to_dict() if streak_doc.exists else {}),
        "progress": {
            "today": _json_safe(today_doc.to_dict() if today_doc.exists else {}),
        },
    }
    return jsonify(response), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port, debug=False)
