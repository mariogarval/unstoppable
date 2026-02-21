# Unstoppable Backend API (Python)

Cloud Run service implemented with `Flask` + `firebase-admin` (Firestore).

## Troubleshooting

Detailed backend + app auth troubleshooting runbook:
- `backend/api/API_RUNBOOK.md`

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
- Effective `paymentOption` for completion is resolved from:
  - primary: `users/{uid}/payments/subscription.paymentOption`
  - fallback: `users/{uid}/profile/self.paymentOption`
- `POST /v1/user/profile` with `paymentOption` writes canonical subscription value and profile mirror.
- `POST /v1/payments/subscription/snapshot` and RevenueCat webhook sync also backfill `users/{uid}/profile/self.paymentOption` when it can be inferred.

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

Poetry (Python 3.12):

```bash
cd backend/api
poetry env use python3.12
poetry install
poetry run python src/app.py
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

## User Reset Scripts

Reset only profile data (`users/{uid}/profile/self`):

```bash
cd backend/api
source .venv/bin/activate
export GOOGLE_CLOUD_PROJECT=unstoppable-app-dev
python scripts/reset_user_profile.py --email your-email@example.com
```

Inspect payment/subscription state and RevenueCat webhook events:

```bash
cd backend/api
source .venv/bin/activate
export GOOGLE_CLOUD_PROJECT=unstoppable-app-dev
python scripts/check_user_payments.py --email your-email@example.com
```

Reset payment/subscription status (`users/{uid}/payments/*`) and clear `users/{uid}/profile/self.paymentOption`:

```bash
cd backend/api
source .venv/bin/activate
export GOOGLE_CLOUD_PROJECT=unstoppable-app-dev
python scripts/reset_user_payments.py --email your-email@example.com
```

Optional: also clear RevenueCat webhook event docs for that user (`payments/revenuecat/events/*`):

```bash
python scripts/reset_user_payments.py --email your-email@example.com --clear-webhook-events
```

Reset full onboarding-related user data (`profile`, `routine`, `progress`, `stats`, `payments` subcollections):

```bash
cd backend/api
source .venv/bin/activate
export GOOGLE_CLOUD_PROJECT=unstoppable-app-dev
python scripts/reset_user_onboarding.py --email your-email@example.com
```

Dry run:

```bash
python scripts/reset_user_profile.py --email your-email@example.com --dry-run
python scripts/reset_user_payments.py --email your-email@example.com --dry-run
python scripts/reset_user_onboarding.py --email your-email@example.com --dry-run
```

Backfill canonical `paymentOption` in `users/{uid}/payments/subscription` from existing profile values:

```bash
cd backend/api
source .venv/bin/activate
export GOOGLE_CLOUD_PROJECT=unstoppable-app-dev
python scripts/migrate_payment_option_to_subscription.py --all
python scripts/migrate_payment_option_to_subscription.py --all --apply
```
