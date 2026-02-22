# Cloud Run Invoker IAM Fix

**Date**: 2026-02-21
**Status**: Complete
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

Investigated repeated sign-in bootstrap failures in the iOS app after API deployment. Confirmed that requests to `/v1/bootstrap` were being rejected by Cloud Run IAM before reaching Flask.

---

## Problem Statement

The app showed "Signed in, but failed to load your account" after successful auth. Cloud Run request logs for revision `unstoppable-api-00010-jlh` showed `401` with text payload: "The request was not authorized to invoke this service", indicating missing public invoker access.

---

## Changes Made

### 1. Restored public invoker binding on Cloud Run service

**Commands**:
```bash
gcloud run services add-iam-policy-binding unstoppable-api \
  --region us-central1 \
  --member=allUsers \
  --role=roles/run.invoker

gcloud run services get-iam-policy unstoppable-api \
  --region us-central1 \
  --format=yaml
```

**Result**:
- IAM policy now includes:
  - `allUsers -> roles/run.invoker`

---

## Verification

- Confirmed pre-fix request logs contained Cloud Run IAM denial text for app user-agent calls.
- Confirmed post-fix service IAM policy includes public invoker binding.

---

## Next Steps

- Re-test iOS sign-in bootstrap flow end-to-end.
- Add deployment checklist item to verify Cloud Run invoker binding after each deploy.
