'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import { auth, db } from '../lib/firebase';
import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc, setDoc } from 'firebase/firestore';

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
          const idTokenResult = await currentUser.getIdTokenResult(false);
          const adminRoleFromClaims = idTokenResult.claims.admin_role;
          const adminClaim = idTokenResult.claims.admin;

          // Quick check: if not admin in claims, reject immediately
          if (!adminClaim && !adminRoleFromClaims) {
            setError('Not an admin user');
            setUser(null);
            setLoading(false);
            auth.signOut();
            return;
          }

          // Fetch user status from Firestore
          const userDoc = await getDoc(doc(db, 'users', currentUser.uid));
          if (userDoc.exists()) {
            const userData = userDoc.data();
            if (userData.status === 'banned') {
              setError('Your account has been banned. Contact support.');
              setUser(null);
              setLoading(false);
              auth.signOut();
              return;
            }
            if (userData.status === 'suspended') {
              setError('Your account is suspended. Please contact support.');
              setUser(null);
              setLoading(false);
              auth.signOut();
              return;
            }
          }

          // Fetch admin document
          const adminDoc = await getDoc(doc(db, 'admins', currentUser.uid));
          if (adminDoc.exists() && (adminRoleFromClaims || adminClaim === true)) {
            const adminData = adminDoc.data();
            setUser(currentUser);
            setAdminRole(adminRoleFromClaims || adminData.role || 'admin');
            setPermissions(adminData.permissions || {});
            setError(null);
            setLoading(false);
          } else {
            // Try backward compatibility check
            const userDoc2 = await getDoc(doc(db, 'users', currentUser.uid));
            if (userDoc2.exists() && (userDoc2.data().role === 'admin' || adminClaim === true)) {
              // Create admin doc in background
              const adminData = {
                email: currentUser.email,
                role: adminRoleFromClaims || 'superadmin',
                permissions: {},
                migratedFrom: 'users',
                createdAt: new Date(),
              };
              await setDoc(doc(db, 'admins', currentUser.uid), adminData);
              setUser(currentUser);
              setAdminRole(adminRoleFromClaims || 'superadmin');
              setPermissions({});
              setError(null);
              setLoading(false);
            } else {
              setError('Not an admin user');
              setUser(null);
              setLoading(false);
              auth.signOut();
            }
          }
        } catch (err) {
          setError('Admin verification failed: ' + err.message);
          setUser(null);
          setLoading(false);
        }
      } else {
        setUser(null);
        setAdminRole(null);
        setPermissions({});
        setError(null);
        setLoading(false);
      }
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
