'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import { auth, db } from '../lib/firebase';
import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';

const AdminContext = createContext();

export const AdminProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [adminRole, setAdminRole] = useState(null);
  const [permissions, setPermissions] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
      if (currentUser) {
        try {
          // Get admin document and custom claims
          const idTokenResult = await currentUser.getIdTokenResult(true);
          const adminRole = idTokenResult.claims.admin_role;
          const adminDoc = await getDoc(doc(db, 'admins', currentUser.uid));

          if (adminDoc.exists() && adminRole) {
            const adminData = adminDoc.data();
            setUser(currentUser);
            setAdminRole(adminRole);
            setPermissions(adminData.permissions || {});
          } else {
            setError('Not an admin user');
            await auth.signOut();
          }
        } catch (err) {
          setError(err.message);
          console.error('Admin verification error:', err);
        }
      } else {
        setUser(null);
        setAdminRole(null);
        setPermissions({});
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const hasPermission = (permission) => {
    return adminRole === 'superadmin' || permissions[permission] === true;
  };

  const canPerform = (action) => {
    const actionPermissionMap = {
      manageUsers: 'canManageUsers',
      verifyCaregiver: 'canVerifyCaregiver',
      moderateJobs: 'canModerateJobs',
      approvePayouts: 'canApprovePayouts',
      manageDisputes: 'canManageDisputes',
      viewAuditLog: 'canViewAuditLog',
      manageSiteSettings: 'canManageSiteSettings',
    };
    return hasPermission(actionPermissionMap[action]);
  };

  return (
    <AdminContext.Provider
      value={{
        user,
        adminRole,
        permissions,
        loading,
        error,
        hasPermission,
        canPerform,
      }}
    >
      {children}
    </AdminContext.Provider>
  );
};

export const useAdmin = () => {
  const context = useContext(AdminContext);
  if (!context) {
    throw new Error('useAdmin must be used within AdminProvider');
  }
  return context;
};
