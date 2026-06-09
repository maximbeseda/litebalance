# Privacy Policy — LiteBalance

**Last updated:** 9 June 2026

LiteBalance ("the app", "we") is a personal finance tracker built with privacy in mind.
This policy explains what data the app handles and how. **Short version: your financial
data stays on your device. We don't run analytics, we don't show ads, and we don't sell
or share your data.**

## 1. Data we store

All your financial data — transactions, categories, accounts, amounts, currencies, notes,
subscriptions and settings — is stored **locally on your device** in an on-device SQLite
database, protected by your device's app sandbox (and the optional app lock below). This
data **never leaves your device** unless *you* explicitly enable an optional feature below.

We do **not** operate any server that receives or stores your personal financial data.

## 2. Optional Google account & Google Drive backup

If you choose to sign in with Google to back up your data:

- We request access only to your Google account's basic profile and to a private,
  app-specific Google Drive area.
- We use it **solely** to upload and download **your own backup file**. We do not read,
  list or access any of your other Google Drive files.
- The backup is stored in your personal Google Drive under your control. You can delete it
  at any time from the app or from Google Drive.
- This feature is **off by default** and used only when you sign in and enable it.

## 3. Local backups

You can export an encrypted local backup file (`.cfbak`). If you set a password, the file is
**encrypted** and can only be restored with that password. These files are created only on
your request and shared only where you choose to save/send them.

## 4. Exchange rates

To convert between currencies, the app fetches public exchange-rate data from a third-party
API ([Fawazahmed currency-api](https://github.com/fawazahmed0/exchange-api)). Only currency
codes (e.g. `USD`, `EUR`) are sent — **no personal or financial data** is transmitted.

## 5. Security: PIN & biometrics

- An optional PIN code can lock the app. It is stored only as a salted hash in the device's
  secure storage — never in plain text.
- Biometric unlock (fingerprint / Face ID) is handled entirely by your device's operating
  system. The app never receives or stores your biometric data.

## 6. Permissions

The app may request:

- **Internet** — to fetch exchange rates and (optionally) sync the Google Drive backup.
- **Biometric / device credentials** — for the optional app lock.
- **Storage / file access** — to import and export CSV / backup files you choose.
- **Vibration** — for haptic feedback.

## 7. Analytics, ads & tracking

None. The app contains **no analytics SDKs, no advertising, and no third-party trackers.**

## 8. Data retention & deletion

- You can erase all data at any time via **Settings → Clear all data**.
- Uninstalling the app removes the local database from your device.
- Any Google Drive backup you created can be deleted from the app or from Google Drive.

## 9. Children

LiteBalance is not directed at children under 13 and does not knowingly collect data from
them.

## 10. Changes to this policy

We may update this policy as the app evolves. Material changes will be reflected here with a
new "Last updated" date.

## 11. Contact

Questions about this policy? Contact: **[support email — to be added]**
