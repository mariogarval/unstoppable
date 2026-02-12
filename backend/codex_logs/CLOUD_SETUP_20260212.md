# CLOUD SETUP Session

Session Date: 2026-02-12  
Branch Used: `add-flow-docs`  
Repository: `/Users/luisgalvez/Projects/unstoppable`

## Session Work Summary

This session established the backend foundation on Google Cloud for the Unstoppable app, then extended profile sync behavior and redeployed Cloud Run. Work included project initialization, Firestore setup, Python API scaffolding, endpoint smoke tests, profile schema expansion, and rollout of a new live revision.

## Change Summary

1. Added GCP initialization automation.
Summary: Created `scripts/init_gcp_project.sh` to create/reuse a project, set active project, link billing, and enable core APIs.

2. Updated backend implementation plan for Google Cloud.
Summary: Expanded `backend/IMPLEMENTATION_PLAN.md` with recommended GCP services, endpoint mapping, and rollout order.

3. Switched backend service scaffold to Python.
Summary: Replaced Node setup with Flask + Firestore in `backend/api/src/app.py`, plus Python dependencies and container configuration.

4. Added Cloud Run deployment helper.
Summary: Added `backend/api/deploy_cloud_run.sh` to deploy source builds to Cloud Run with env var controls for auth/dev mode.

5. Deployed and validated backend endpoints.
Summary: Deployed `unstoppable-api` to project `unstoppable-app-dev`, then tested `/v1/user/profile`, `/v1/routines/current`, `/v1/progress/daily`, and `/v1/bootstrap` successfully.

6. Provisioned Firestore database.
Summary: Created Firestore Native database in `us-central1` for `unstoppable-app-dev` after confirming `us-central` was invalid for Firestore location.

7. Expanded backend profile allowlist for onboarding metadata.
Summary: Updated `/Users/luisgalvez/Projects/unstoppable/backend/api/src/app.py` so `POST /v1/user/profile` accepts `termsOver16Accepted`, `termsMarketingAccepted`, and `paymentOption`.

8. Redeployed Cloud Run with updated backend code.
Summary: Ran `ALLOW_UNAUTHENTICATED=1 ALLOW_DEV_USER_HEADER=1 backend/api/deploy_cloud_run.sh unstoppable-app-dev`, resulting in revision `unstoppable-api-00002-m25` serving 100% traffic.

9. Captured new active service URL after redeploy.
Summary: Deployment returned `https://unstoppable-api-1094359674860.us-central1.run.app`, which was then used to realign app-side dev endpoint configuration.
