# Admin Dashboard - Quick Start Guide

## Complete Setup Steps (5-10 minutes)

### Step 1: Copy Admin Dashboard Files

The `admin-dashboard/` folder in your project contains the complete React dashboard. All files have been created.

### Step 2: Configure Firebase

In the Firebase Console:

1. **Enable Firestore** (if not already enabled)
   - Go to Firestore Database
   - Click "Create Database"
   - Start in production mode
   - Choose region (us-central1 or your closest)

2. **Enable Cloud Functions** (if not already enabled)
   - Go to Cloud Functions
   - Enable the API
   - Ensure billing is enabled

3. **Get Your Firebase Config**
   - Go to Project Settings → Your Apps
   - Copy Firebase config values

### Step 3: Setup Admin Dashboard Environment

```bash
cd admin-dashboard
cp .env.local.example .env.local
```

Edit `.env.local` and paste your Firebase config:
```
NEXT_PUBLIC_FIREBASE_API_KEY=<paste from Firebase Console>
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=<your-project>.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=<your-project>
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=<your-project>.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=<your-sender-id>
NEXT_PUBLIC_FIREBASE_APP_ID=<your-app-id>
```

### Step 4: Deploy Firestore Rules

**IMPORTANT**: Update your existing firestore.rules file in the parent directory with the new admin rules.

Copy from `admin-dashboard/firestore.rules` to `firestore.rules` (root level):

```bash
firebase deploy --only firestore:rules
```

### Step 5: Deploy Cloud Functions

```bash
cd admin-dashboard/functions
npm install
cd ..
firebase deploy --only functions
```

Wait for deployment to complete. You should see:
```
✔  Deploy complete!

Function URL (admin operations): https://us-central1-<project>.cloudfunctions.net/
```

### Step 6: Create First Super Admin

**Option A: Automated Script (Recommended ✅)**

1. Download your Firebase Admin SDK key:
   - Firebase Console → Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save as `firebase-admin-key.json` in the `admin-dashboard/` folder

2. Run the setup script:
   ```bash
   node setup-admin.js
   ```
   Follow the prompts to set up your first super admin.

See `ADMIN_SETUP.md` for detailed guidance and troubleshooting.

**Option B: Manual Setup (if script fails)**

If the automated script doesn't work, see `ADMIN_SETUP.md` for manual setup instructions via Firebase Console.

### Step 7: Install and Run Dashboard

```bash
npm install
npm run dev
```

Dashboard should open at `http://localhost:3000`

Try logging in with your admin email/password.

### Step 8: Deploy to Firebase Hosting

```bash
npm run build
firebase deploy --only hosting
```

Your dashboard will be live at: `https://<your-project>.web.app`

---

## Next Steps: Add More Admins

### Via Dashboard (Easiest - Recommended ✅):

1. Log in as super admin
2. Go to **Settings** page
3. Click **"Add New Admin"**
4. Enter admin email and select role (Moderator, Finance, or Support)
5. Click **"Create Admin"** (auto-creates admin document with correct permissions)

### Via Script (if needed):

Use the same `node setup-admin.js` script for additional admins - it will set them up with superadmin role by default.

Then go to Settings to adjust their permissions to Moderator/Finance/Support as needed.

---

## Admin Roles Overview

| Role | Users | Jobs | Payments | Disputes | Verify | Settings |
|------|-------|------|----------|----------|--------|----------|
| **Super Admin** | ✅ Full | ✅ Full | ✅ Full | ✅ Full | ✅ | ✅ |
| **Moderator** | ✅ Manage | ✅ Moderate | ❌ | ❌ | ✅ | ❌ |
| **Finance** | ❌ | ❌ | ✅ Full | ❌ | ❌ | ❌ |
| **Support** | ❌ | ❌ | ❌ | ✅ Resolve | ❌ | ❌ |

---

## Testing the Dashboard

### Test Super Admin Features:

1. ✅ Login with super admin account
2. ✅ Dashboard shows metrics
3. ✅ Navigate all pages (Users, Jobs, Payments, Disputes, Audit Logs)
4. ✅ Go to Settings → Add new moderator
5. ✅ Check audit logs - your action should be recorded

### Test Moderator Features:

1. ✅ Login with moderator account
2. ✅ Can access Users page
3. ✅ Can access Jobs page
4. ✅ Cannot access Payments page (should see 403 error)

### Test Permissions:

In Browser Console (while logged in as super admin):
```javascript
// Check your permissions
const { useAdmin } = window.__NEXT_DATA__.props.pageProps;
const admin = useAdmin();
console.log(admin.permissions);
```

---

## Troubleshooting

### Dashboard shows "Not an admin user" error

**Solution:**
1. Verify admin document exists in Firestore
2. Verify custom claims are set:
   ```bash
   firebase shell
   admin.auth().getUser('your-uid').then(user => console.log(user.customClaims));
   exit()
   ```
3. If custom claims missing, run Step 6 again
4. Sign out and back in

### "You do not have permission" errors

**Solution:**
1. Check admin permissions in Firestore dashboard
2. Verify role is set correctly (superadmin, moderator, etc.)
3. Check admin-dashboard Cloud Function logs: `firebase functions:log`
4. Redeploy rules: `firebase deploy --only firestore:rules`

### Cloud Functions not working

**Solution:**
1. Check functions deployed: `firebase functions:list`
2. Check logs: `firebase functions:log`
3. Verify billing enabled
4. Redeploy: `firebase deploy --only functions`

### Pages not loading data

**Solution:**
1. Check Firestore rules in console (Firestore → Rules tab)
2. Check browser console for errors
3. Verify collections exist in Firestore
4. Check user has permission for that action

---

## File Structure

```
admin-dashboard/
├── src/pages/
│   ├── _app.js              # App setup
│   ├── login.js             # Login page
│   ├── dashboard.js         # Main dashboard
│   ├── users.js             # User management
│   ├── jobs.js              # Job moderation
│   ├── payments.js          # Payment management
│   ├── disputes.js          # Dispute resolution
│   ├── audit-logs.js        # Audit logging
│   └── settings.js          # Admin settings
├── src/components/
│   ├── Layout.js            # Main layout
│   ├── StatCard.js          # Metrics
│   └── DataTable.js         # Data table
├── src/context/
│   └── AdminContext.js      # Auth context
├── src/lib/
│   ├── firebase.js          # Firebase setup
│   └── utils.js             # Utilities
├── functions/
│   └── index.js             # Cloud Functions
├── firestore.rules          # Security rules
├── firebase.json            # Firebase config
├── README.md                # Full documentation
└── package.json             # Dependencies
```

---

## Command Reference

```bash
# Development
npm run dev              # Start dev server (localhost:3000)

# Production
npm run build           # Build for production
npm start              # Start production server

# Deployment
firebase deploy         # Deploy everything (hosting + functions + rules)
firebase deploy --only hosting          # Deploy dashboard only
firebase deploy --only functions        # Deploy Cloud Functions only
firebase deploy --only firestore:rules  # Deploy security rules only

# Debugging
firebase shell         # Open Firebase shell
firebase functions:log # View Cloud Function logs
firebase logs read     # View app logs
```

---

## Next Phase: Integration Points

The admin dashboard is now ready to:

1. **Verify caregivers** - Process caregiver documents
2. **Moderate jobs** - Approve/reject job listings
3. **Monitor payments** - Track Paystack transactions
4. **Resolve disputes** - Make refund/accept rulings
5. **Track activity** - Full audit trail of admin actions

All operations are logged and role-based access is enforced at the database level.

---

Happy administrating! 🎉
