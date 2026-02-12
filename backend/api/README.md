# Unstoppable Backend API (Python)

Cloud Run service implemented with `Flask` + `firebase-admin` (Firestore).

## Endpoints

- `POST /v1/user/profile`
- `PUT /v1/routines/current`
- `POST /v1/progress/daily`
- `GET /v1/bootstrap`
- `GET /healthz`

## Auth

Production:
- Send `Authorization: Bearer <Firebase ID token>`.

Local development fallback:
- Set `ALLOW_DEV_USER_HEADER=1`.
- Send `X-User-Id: some-user-id`.

## Local run

```bash
cd backend/api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export GOOGLE_CLOUD_PROJECT=unstoppable-app-dev
export ALLOW_DEV_USER_HEADER=1
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
