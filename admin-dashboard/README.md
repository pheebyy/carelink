# CareLink Admin Dashboard

A comprehensive web-based admin panel for managing the CareLink platform with role-based access control, real-time analytics, and comprehensive audit logging.

## Features

- **User Management**: Verify caregivers, manage users, suspend/ban accounts
- **Job Moderation**: Review, approve, or reject job listings
- **Payment Management**: Monitor transactions, approve/process payouts
- **Dispute Resolution**: Review and resolve disputes with custom rulings
- **Content Moderation**: Flag inappropriate content
- **Audit Logging**: Complete audit trail of all admin actions
- **Role-Based Access Control**: Super Admin, Moderator, Finance, Support roles
- **Real-time Analytics**: Dashboard with key metrics and activity feeds

## Prerequisites

- Node.js 18+ 
- npm or yarn
- Firebase project (with Firestore, Auth, Cloud Functions enabled)
- Firebase CLI installed: `npm install -g firebase-tools`

## Setup Instructions

### 1. Configure Environment Variables

Create `.env.local` in the admin-dashboard root:

```bash
cp .env.local.example .env.local
```

Fill in your Firebase credentials:

```
NEXT_PUBLIC_FIREBASE_API_KEY=<your-api-key>
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=<your-project>.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=<your-project>
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=<your-project>.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=<your-sender-id>
NEXT_PUBLIC_FIREBASE_APP_ID=<your-app-id>
```

### 2. Install Dependencies

```bash
npm install
cd functions && npm install && cd ..
```

### 3. Update Firestore Security Rules

Deploy the updated security rules to Firebase:

```bash
firebase deploy --only firestore:rules
```

The rules include:
- Admin collection with role-based access
- Audit logs collection for activity tracking
- Enhanced user/job/payment permissions for admins
- Dispute and other collections

### 4. Deploy Cloud Functions

Deploy the admin functions for sensitive operations:

```bash
firebase deploy --only functions
```

These functions handle:
- Creating/updating admin users (super admin only)
- Verifying/suspending/banning users
- Moderating jobs
- Processing payments
- Resolving disputes
- Audit logging

### 5. Set Up Initial Super Admin

Run this command to make the first user a super admin:

```bash
firebase auth:import out.json --hash-algo=scrypt --rounds=8 --mem-cost=14
```

Then manually set custom claims:

```bash
firebase shell
# In the shell:
admin.auth().setCustomUserClaims('USER_UID', { admin: true, admin_role: 'superadmin' }).then(() => {
  admin.firestore().collection('admins').doc('USER_UID').set({
    uid: 'USER_UID',
    email: 'admin@carelink.com',
    name: 'Admin Name',
    role: 'superadmin',
    permissions: {
      canManageUsers: true,
      canVerifyCaregiver: true,
      canModerateJobs: true,
      canApprovePayouts: true,
      canManageDisputes: true,
      canViewAuditLog: true,
      canManageSiteSettings: true
    },
    createdAt: new Date(),
    lastLogin: null
  });
}).then(() => console.log('Super admin created'));
exit()
```

### 6. Create Admin Document

For Firebase Console:
1. Go to Firestore
2. Create a collection called `admins`
3. Add document with UID and above data

### 7. Deploy to Firebase Hosting

```bash
npm run build
firebase deploy --only hosting
```

Your dashboard will be available at: `https://<your-project>.web.app`

## Usage

### Login

- Navigate to the dashboard
- Sign in with an admin email/password

### Dashboard

- View key metrics (users, jobs, revenue, pending approvals)
- See recent admin activity
- Quick action buttons for common tasks

### User Management

- Search/filter users by name, email, role, status
- Verify caregivers with their documents
- Suspend or ban users
- View complete user history and ratings

### Job Moderation

- Review job listings awaiting approval
- Approve/reject jobs
- Flag inappropriate content
- Delete spam submissions

### Payment Management

- Monitor all transactions
- Approve/reject pending payments
- Process payouts to caregivers
- Track commission fees

### Dispute Resolution

- View all disputes by status
- Review timeline of dispute activity
- Make rulings: refund, accept, split
- Track resolution history

### Audit Logs

- Search admin actions by admin, action type, date
- Export audit logs to CSV
- Track who did what and when

### Settings

- Manage admin users (super admin only)
- Update admin permissions
- View admin roles and access levels

## Admin Roles & Permissions

### Super Admin 👑
- Full platform access
- Can manage other admins
- Can change admin permissions
- Can access all features without restriction

### Moderator
- Verify caregivers
- Manage users (suspend/ban)
- Moderate jobs (approve/reject/delete)
- View audit logs
- Cannot access payments or disputes

### Finance
- Approve/process payouts
- Monitor payments
- Change commission settings
- View audit logs
- Cannot manage users or jobs

### Support
- Resolve disputes
- View dispute history
- Email users
- View audit logs
- Cannot manage users, jobs, or payments

## Architecture

```
admin-dashboard/
├── src/
│   ├── pages/              # Next.js pages (routes)
│   │   ├── _app.js         # App wrapper, theme, auth
│   │   ├── login.js        # Login page
│   │   ├── dashboard.js    # Main dashboard
│   │   ├── users.js        # User management
│   │   ├── jobs.js         # Job moderation
│   │   ├── payments.js     # Payment management
│   │   ├── disputes.js     # Dispute resolution
│   │   ├── audit-logs.js   # Audit logging
│   │   └── settings.js     # Admin settings
│   ├── components/         # Reusable React components
│   │   ├── Layout.js       # Main layout with sidebar
│   │   ├── StatCard.js     # Metric cards
│   │   └── DataTable.js    # Reusable table component
│   ├── context/            # React context
│   │   └── AdminContext.js # Admin auth & permissions
│   └── lib/                # Utilities
│       ├── firebase.js     # Firebase config & initialization
│       └── utils.js        # Helper functions (formatting, etc.)
├── functions/              # Firebase Cloud Functions
│   └── index.js           # Admin operations, audit logging
├── firestore.rules        # Firestore security rules
├── firebase.json          # Firebase config (hosting, functions)
├── next.config.js         # Next.js config
└── package.json           # Dependencies
```

## Firestore Collections

### admins
Stores admin user data with permissions
```
{
  uid: string,
  email: string,
  name: string,
  role: 'superadmin' | 'moderator' | 'finance' | 'support',
  permissions: {
    canManageUsers: boolean,
    canVerifyCaregiver: boolean,
    canModerateJobs: boolean,
    canApprovePayouts: boolean,
    canManageDisputes: boolean,
    canViewAuditLog: boolean,
    canManageSiteSettings: boolean
  },
  lastLogin: timestamp,
  createdAt: timestamp
}
```

### auditLogs
Tracks all admin actions
```
{
  adminId: string,
  action: string,
  affectedUserId: string (optional),
  affectedJobId: string (optional),
  details: object,
  timestamp: timestamp
}
```

### disputes (new)
Stores dispute cases
```
{
  caseId: string,
  type: 'payment' | 'review' | 'behavior',
  raisedBy: string,
  raisedAgainst: string,
  amount: number,
  description: string,
  status: 'pending' | 'resolved' | 'escalated',
  resolution: string,
  resolutionNotes: string,
  resolvedAt: timestamp,
  resolvedBy: string
}
```

## Security Considerations

1. **Role-Based Access Control**: Enforced at database level via Firestore rules
2. **Audit Logging**: Every admin action is logged with admin ID, timestamp, and details
3. **Cloud Functions**: Sensitive operations (approvals, payouts) only run via Cloud Functions, never client-side
4. **Custom Claims**: Admin roles stored in Firebase Auth custom claims
5. **Permissions Caching**: Permissions cached in context, validated on every action
6. **Session Security**: Auto-logout after 30 minutes of inactivity (optional - add later)

## Deployment Checklist

- [ ] Firebase project created
- [ ] Firestore and Auth enabled
- [ ] Cloud Functions enabled
- [ ] Billing enabled for Cloud Functions
- [ ] Environment variables configured
- [ ] Firestore rules deployed
- [ ] Cloud Functions deployed
- [ ] Firebase Hosting enabled
- [ ] First super admin created and verified
- [ ] Dashboard deployed and tested
- [ ] Admin login working
- [ ] At least one admin user created

## Troubleshooting

### "You do not have admin access"
- Check that admin document exists in Firestore
- Verify custom claims are set on user
- Try signing out and signing back in

### Cloud Functions not working
- Check functions are deployed: `firebase functions:list`
- Check logs: `firebase functions:log`
- Verify admin has correct permissions in Firestore

### Cannot see data in dashboard
- Check Firestore rules allow the action
- Verify admin has required permission
- Check browser console for errors

### Slow page loads
- Check Firestore indexes created
- Enable caching headers in firebase.json
- Build and test with `npm run build`

## Development

### Local Development

```bash
npm run dev
```

Visit `http://localhost:3000`

### Build for Production

```bash
npm run build
npm start
```

## Support

For issues or questions:
1. Check Firestore rules - most issues are permission-related
2. Check Cloud Function logs
3. Verify admin custom claims in Firebase Console
4. Check browser console for error details

## License

Proprietary - CareLink Platform
