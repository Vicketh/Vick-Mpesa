# Daraja Capability Matrix

Last reviewed: September 2026  
Source: https://developer.safaricom.co.ke/APIs

This document records what Safaricom Daraja officially provides and what Vick Mpesa
implements. Do not implement any capability marked NOT AVAILABLE or REQUIRES ONBOARDING
without first completing the required Safaricom approval process.

---

## API Availability

| Feature | Daraja API | Sandbox | Production | Vick Mpesa Status |
|---------|-----------|---------|------------|-------------------|
| STK Push (customer-initiated payment) | Lipa Na M-Pesa Online | ✅ Available | ✅ Available | ✅ Implemented |
| STK Push query (check status) | M-Pesa Express Query | ✅ Available | ✅ Available | 🔲 Planned |
| C2B Register URL | C2B API | ✅ Available | ✅ Available | 🔲 Planned |
| C2B Simulate | C2B API | ✅ Sandbox only | ❌ N/A | 🔲 Planned |
| B2C (disbursements) | B2C API | ✅ Available | ⚠️ Requires approval | 🔬 Research |
| B2B | B2B API | ✅ Available | ⚠️ Requires approval | 🔬 Research |
| Account Balance | Account Balance API | ✅ Available | ⚠️ Requires approval | 🔬 Research |
| Transaction Status | Transaction Status API | ✅ Available | ✅ Available | 🔲 Planned |
| Reversal | Reversal API | ✅ Available | ⚠️ Requires approval | 🔬 Research |
| Pochi La Biashara | BusinessToPochi API | ✅ Available | ⚠️ Requires approval | 🔬 Research |
| Pull Transactions | Pull Transactions API | ✅ Available | ⚠️ Requires approval | 🔬 Research |
| M-PESA Statement | No public API | ❌ N/A | ❌ N/A | ❌ Not available |
| Real-time balance | No public API | ❌ N/A | ❌ N/A | ❌ Not available |

---

## Status Key

| Symbol | Meaning |
|--------|---------|
| ✅ Implemented | Built and tested in Vick Mpesa |
| 🔲 Planned | Will be built in a future milestone |
| 🔬 Research | Needs investigation before committing |
| ⚠️ Requires approval | Needs Safaricom production onboarding |
| ❌ Not available | No official API exists |

---

## STK Push — Current Implementation

**Endpoint:** `POST /mpesa/stkpush/v1/processrequest`  
**Auth:** OAuth 2.0 client credentials  
**Sandbox shortcode:** 174379  
**Sandbox passkey:** Available from Daraja portal under "Lipa Na M-Pesa"

Flow:
1. Backend obtains OAuth token
2. Backend sends STK Push request to Daraja
3. Daraja sends USSD prompt to customer's phone
4. Customer enters PIN on their phone
5. Daraja sends callback to our backend
6. Backend updates transaction status
7. Mobile polls transaction status

**Important:** A successful STK Push request (HTTP 200, ResponseCode 0) only means
Daraja accepted the request. It does NOT mean the customer completed the payment.
The callback is the authoritative confirmation.

---

## Pull Transactions API — Research Notes

The Pull Transactions API allows registered organizations to pull C2B transactions.
Requirements:
- Must be a registered Safaricom business
- Must complete production onboarding
- Transactions must be to your registered shortcode

This API does NOT provide a general M-PESA transaction history for individual users.
It cannot be used to show a user their personal M-PESA statement.

---

## Account Balance — Research Notes

The Account Balance API queries the balance of a business shortcode/till.
It does NOT query an individual customer's M-PESA wallet balance.
There is no official Daraja API to retrieve a customer's personal M-PESA balance.

---

## What Vick Mpesa Will Never Claim

- Personal M-PESA wallet balance (no API exists)
- Complete personal transaction history (no API exists)
- Transactions not initiated through Vick Mpesa
