# Deploy Script Public Invoker Enforcement

**Date**: 2026-02-21
**Status**: Complete
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

Updated the Cloud Run deployment script to explicitly enforce public invoker access after deployment. This prevents IAM drift from breaking mobile API calls.

---

## Changes Made

### 1. Added explicit post-deploy invoker binding

**Files Created/Modified**:
- `backend/api/deploy_cloud_run.sh` - added `ENSURE_PUBLIC_INVOKER` env flag (default `1`) and a post-deploy `gcloud run services add-iam-policy-binding ... allUsers ... roles/run.invoker` step.

---

## Verification

```bash
bash -n backend/api/deploy_cloud_run.sh
```

- [x] Script syntax check passed.

---

## Next Steps

- Use `ENSURE_PUBLIC_INVOKER=0` only for environments that must remain private.
