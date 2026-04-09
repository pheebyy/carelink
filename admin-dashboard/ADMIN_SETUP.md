# Firebase Admin Setup Guide

This guide helps you set up the Firebase Admin SDK and create your first super admin for the CareLink Admin Dashboard.

## Step 1: Download Firebase Admin Key

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your CareLink project
3. Click ⚙️ **Project Settings** (top left)
4. Click **Service Accounts** tab
5. Click **Generate New Private Key**
6. Save the JSON file as `firebase-admin-key.json` in the `admin-dashboard/` folder

```bash
admin-dashboard/
├── firebase-admin-key.json  (← Place it HERE)
├── setup-admin.js
├── package.json
└── ...
```

⚠️ **SECURITY WARNING**: This file contains sensitive credentials. **Never commit to git!**

## Step 2: Create Super Admin

From the `admin-dashboard/` folder, run:

```bash
node setup-admin.js
```

The script will:
1. ✅ Verify your Firebase Admin SDK setup
2. ✅ Ask for admin email
3. ✅ Check if user exists in Firebase Auth
4. ✅ Set custom claims (admin: true, admin_role: superadmin)
5. ✅ Create admin document in Firestore
6. ✅ Display confirmation with next steps

### Example Session

```
PS> node setup-admin.js

🚀 CareLink Admin Dashboard - Super Admin Setup

Enter admin email: admin@carelink.app
🔍 Checking if user exists in Firebase Auth...
✅ User found: abc123xyz

⚠️  About to make admin@carelink.app a super admin. Continue? (yes/no): yes
🔐 Setting custom claims...
✅ Custom claims set
📄 Creating admin document...
✅ Admin document created

✅ Super admin setup complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Email:     admin@carelink.app
Role:      Super Admin (👑)
UID:       abc123xyz
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 Next steps:
1. npm run dev          (Start local dashboard)
2. Visit http://localhost:3000
3. Log in with admin@carelink.app and your password
```

## Step 3: Test Dashboard

```bash
npm run dev
```

Open http://localhost:3000 and log in with your admin credentials.

## Troubleshooting

### Error: "Cannot find module 'firebase-admin'"

Run: `npm install` (in admin-dashboard folder)

### Error: "firebase-admin-key.json not found"

Make sure the key file is in the `admin-dashboard/` folder, not elsewhere.

### Error: "User not found in Firebase Auth"

The email must already exist as a Firebase Auth user:
- Sign up through the mobile app, OR
- Create manually in [Firebase Console](https://console.firebase.google.com) → Authentication tab

### Error: "Permission denied"

Make sure Firebase service account has these roles:
- Editor (or at least Firebase Admin, Authentication Admin, Firestore Admin)

## Alternative: Manual Setup via Firebase Console

If the script doesn't work, you can set it up manually:

### 1. Set Custom Claims
Use Firebase Extensions → Firebase CLI Shell (if available) or create a Cloud Function:

```javascript
// Cloud Function to set admin claims
exports.makeAdmin = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  
  await admin.auth().setCustomUserClaims(data.uid, {
    admin: true,
    admin_role: 'superadmin'
  });
  
  return { success: true };
});
```

### 2. Create Admin Document
In [Firestore Console](https://console.firebase.google.com) → Firestore:

**Collection**: `admins`  
**Document ID**: (use the admin user's UID)

**Document data**:
```json
{
  "uid": "user-uid-here",
  "email": "admin@carelink.app",
  "name": "Admin Name",
  "role": "superadmin",
  "permissions": {
    "canManageUsers": true,
    "canVerifyCaregiver": true,
    "canModerateJobs": true,
    "canApprovePayouts": true,
    "canManageDisputes": true,
    "canViewAuditLog": true,
    "canManageSiteSettings": true
  },
  "createdAt": (server timestamp),
  "lastLogin": null
}
```

## Setting `.gitignore`

Add to `.gitignore` to prevent accidentally pushing secrets:

```bash
# Firebase Admin SDK key (NEVER commit!)
firebase-admin-key.json
*.json.example

# Environment variables
.env.local
.env*.local

# Dependencies
node_modules/
.next/

# Build output
out/
.next/

# IDE
.vscode/
.idea/
*.swp
```

Done! You now have a super admin account. 🎉
