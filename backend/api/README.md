# Unstoppable Backend API (Python)

Cloud Run service implemented with `Flask` + `firebase-admin` (Firestore).

## Endpoints

- `POST /v1/user/profile`
- `PUT /v1/routines/current`
- `POST /v1/progress/daily`
- `GET /v1/bootstrap`
- `GET /v1/user/subscription`
- `POST /v1/payments/subscription/snapshot`
- `POST /v1/payments/revenuecat/webhook`
- `GET /healthz`

## Auth

Production:
- Send `Authorization: Bearer <Firebase ID token>`.
- Backend resolves a canonical user record by verified token email (`user_email_aliases`), so Google/Apple sign-ins with the same verified email map to one Firestore user profile/routine/progress entry.

Local development fallback:
- Set `ALLOW_DEV_USER_HEADER=1`.
- Send `X-User-Id: some-user-id`.

Bootstrap profile completion:
- `GET /v1/bootstrap` now includes:
  - `isProfileComplete` (boolean)
  - `profileCompletion.isComplete` (boolean)
  - `profileCompletion.missingRequiredFields` (array)

RevenueCat webhook auth:
- Set `REVENUECAT_WEBHOOK_AUTH=<shared-secret>`.
- Send webhook header `Authorization: Bearer <shared-secret>`.

## Local run

```bash
cd backend/api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export GOOGLE_CLOUD_PROJECT=unstoppable-app-dev
export ALLOW_DEV_USER_HEADER=1
export REVENUECAT_WEBHOOK_AUTH=dev-webhook-secret
python src/app.py
```

## Deploy to Cloud Run

```bash
chmod +x backend/api/deploy_cloud_run.sh
backend/api/deploy_cloud_run.sh unstoppable-app-dev
```

Optional unauthenticated deploy for quick smoke tests:

```bash
ALLOW_UNAUTHENTICATED=1 backend/api/deploy_cloud_run.sh unstoppable-app-dev
```
