const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

// ======================== ADMIN USER MANAGEMENT ========================

/**
 * Create a new admin user
 * Callable from dashboard only by super admins
 */
exports.createAdmin = functions.https.onCall(async (data, context) => {
  // Verify caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  // Verify caller is super admin
  const callerToken = await auth.getUser(context.auth.uid);
  if (callerToken.customClaims?.admin_role !== 'superadmin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only super admins can create new admins'
    );
  }

  const { email, name, role } = data;

  if (!email || !role || !['superadmin', 'moderator', 'finance', 'support'].includes(role)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid email or role');
  }

  try {
    // Find user by email
    const user = await auth.getUserByEmail(email);

    // Create admin document
    await db.collection('admins').doc(user.uid).set({
      uid: user.uid,
      email,
      name: name || '',
      role,
      permissions: getDefaultPermissions(role),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: context.auth.uid,
    });

    // Set custom claims
    await auth.setCustomUserClaims(user.uid, {
      admin: true,
      admin_role: role,
    });

    // Log audit event
    await logAuditEvent(context.auth.uid, 'create_admin', {
      newAdminId: user.uid,
      email,
      role,
    });

    return { success: true, message: `Admin ${email} created with role ${role}` };
  } catch (error) {
    console.error('Error creating admin:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Update admin permissions
 */
exports.updateAdminPermissions = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const callerToken = await auth.getUser(context.auth.uid);
  if (callerToken.customClaims?.admin_role !== 'superadmin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only super admins can update admin permissions'
    );
  }

  const { adminId, permissions } = data;

  try {
    await db.collection('admins').doc(adminId).update({
      permissions,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: context.auth.uid,
    });

    await logAuditEvent(context.auth.uid, 'update_admin_permissions', {
      affectedAdminId: adminId,
      permissions,
    });

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ======================== USER MODERATION ========================

/**
 * Approve caregiver verification
 */
exports.verifyCaregiverUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  // Verify permission
  const adminDoc = await db.collection('admins').doc(context.auth.uid).get();
  if (!adminDoc.exists || !adminDoc.data().permissions.canVerifyCaregiver) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You do not have permission to verify caregivers'
    );
  }

  const { userId, approved, reason } = data;

  try {
    const updateData = {
      verificationStatus: approved ? 'approved' : 'rejected',
      verifiedBy: context.auth.uid,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (reason) {
      updateData.overallVerificationNotes = reason;
    }

    await db.collection('users').doc(userId).update(updateData);

    // Send notification to user
    await db.collection('notifications').add({
      userId,
      type: 'verification_status',
      title: approved ? 'Verification Approved!' : 'Verification Rejected',
      message: approved
        ? 'Your verification has been approved. You can now bid on jobs!'
        : `Your verification was rejected. ${reason || 'Please contact support for details.'}`,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send email notification
    try {
      console.log('📧 Sending verification result email...');
      const callable = functions.httpsCallable('sendVerificationResultEmail');
      const emailResult = await callable({
        caregiverId: userId,
        approved: approved,
        reason: reason,
      });
      console.log('✅ Verification result email sent:', emailResult.data);
    } catch (emailError) {
      console.warn('⚠️  Email notification could not be sent:', emailError.message);
      // Don't throw - email is not critical to verification
    }

    await logAuditEvent(context.auth.uid, 'verify_caregiver_user', {
      affectedUserId: userId,
      action: approved ? 'approved' : 'rejected',
      reason,
    });

    return { success: true, message: approved ? 'Caregiver verified successfully' : 'Caregiver verification rejected' };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Suspend or ban user
 */
exports.suspendBanUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const adminDoc = await db.collection('admins').doc(context.auth.uid).get();
  if (!adminDoc.exists || !adminDoc.data().permissions.canManageUsers) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You do not have permission to manage users'
    );
  }

  const { userId, action, reason } = data; // action: 'suspend' or 'ban'

  try {
    const updateData = {
      status: action === 'suspend' ? 'suspended' : 'banned',
      actionReason: reason || '',
      actionBy: context.auth.uid,
      actionAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('users').doc(userId).update(updateData);

    // If banning, disable auth user
    if (action === 'ban') {
      await auth.updateUser(userId, { disabled: true });
    }

    await logAuditEvent(context.auth.uid, `${action}_user`, {
      affectedUserId: userId,
      reason,
    });

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ======================== JOB MODERATION ========================

/**
 * Approve or reject job listing
 */
exports.moderateJob = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const adminDoc = await db.collection('admins').doc(context.auth.uid).get();
  if (!adminDoc.exists || !adminDoc.data().permissions.canModerateJobs) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You do not have permission to moderate jobs'
    );
  }

  const { jobId, action, reason } = data; // action: 'approve', 'reject', 'flag'

  try {
    const updateData = {
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
      moderatedBy: context.auth.uid,
    };

    if (action === 'approve') {
      updateData.status = 'open';
    } else if (action === 'reject') {
      updateData.status = 'rejected';
      updateData.rejectionReason = reason;
    } else if (action === 'flag') {
      updateData.flagged = true;
      updateData.flagReason = reason;
    }

    await db.collection('jobs').doc(jobId).update(updateData);

    await logAuditEvent(context.auth.uid, `${action}_job`, {
      affectedJobId: jobId,
      reason,
    });

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ======================== PAYMENT OPERATIONS ========================

/**
 * Approve or process payout
 */
exports.processPayout = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const adminDoc = await db.collection('admins').doc(context.auth.uid).get();
  if (!adminDoc.exists || !adminDoc.data().permissions.canApprovePayouts) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You do not have permission to process payouts'
    );
  }

  const { paymentId, action } = data; // action: 'approve', 'reject'

  try {
    await db.collection('payments').doc(paymentId).update({
      status: action === 'approve' ? 'completed' : 'failed',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      processedBy: context.auth.uid,
    });

    await logAuditEvent(context.auth.uid, `${action}_payout`, {
      affectedPaymentId: paymentId,
    });

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ======================== DISPUTE RESOLUTION ========================

/**
 * Resolve dispute with ruling
 */
exports.resolveDispute = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const adminDoc = await db.collection('admins').doc(context.auth.uid).get();
  if (!adminDoc.exists || !adminDoc.data().permissions.canManageDisputes) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You do not have permission to manage disputes'
    );
  }

  const { caseId, resolution, notes } = data;

  try {
    await db.collection('disputes').doc(caseId).update({
      status: 'resolved',
      resolution,
      resolutionNotes: notes,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      resolvedBy: context.auth.uid,
    });

    await logAuditEvent(context.auth.uid, 'resolve_dispute', {
      affectedCaseId: caseId,
      resolution,
    });

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ======================== HELPER FUNCTIONS ========================

/**
 * Log admin action to audit logs
 */
async function logAuditEvent(adminId, action, details) {
  try {
    await db.collection('auditLogs').add({
      adminId,
      action,
      details,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('Error logging audit event:', error);
  }
}

/**
 * Get default permissions for role
 */
function getDefaultPermissions(role) {
  const permissions = {
    canManageUsers: false,
    canVerifyCaregiver: false,
    canModerateJobs: false,
    canApprovePayouts: false,
    canManageDisputes: false,
    canViewAuditLog: false,
    canManageSiteSettings: false,
  };

  switch (role) {
    case 'moderator':
      permissions.canManageUsers = true;
      permissions.canVerifyCaregiver = true;
      permissions.canModerateJobs = true;
      permissions.canViewAuditLog = true;
      break;
    case 'finance':
      permissions.canApprovePayouts = true;
      permissions.canViewAuditLog = true;
      break;
    case 'support':
      permissions.canManageDisputes = true;
      permissions.canViewAuditLog = true;
      break;
  }

  return permissions;
}

// ======================== INITIALIZATION ========================

/**
 * Set admin claims on user creation (triggered by Auth)
 */
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
  // Check if user should be admin
  const adminDoc = await db.collection('admins').doc(user.uid).get();
  
  if (adminDoc.exists) {
    const adminRole = adminDoc.data().role;
    await auth.setCustomUserClaims(user.uid, {
      admin: true,
      admin_role: adminRole,
    });
  }
});

/**
 * Update user last login on token refresh
 */
exports.updateLastLogin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  try {
    await db.collection('admins').doc(context.auth.uid).update({
      lastLogin: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { success: true };
  } catch (error) {
    return { success: false }; // Fail silently
  }
});
