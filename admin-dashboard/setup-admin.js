#!/usr/bin/env node

/**
 * CareLink Admin Dashboard - Super Admin Initialization Script
 * 
 * Usage: node setup-admin.js
 * 
 * This script sets up the first super admin user by:
 * 1. Setting Firebase Auth custom claims
 * 2. Creating admin document in Firestore
 * 
 * Prerequisites:
 * - Firebase project initialized
 * - Service account key file downloaded
 * - Environment variables configured
 */

const admin = require('firebase-admin');
const readline = require('readline');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccountPath = process.env.FIREBASE_ADMIN_SDK_KEY || './firebase-admin-key.json';

try {
  const serviceAccount = require(path.resolve(serviceAccountPath));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('✅ Firebase Admin SDK initialized');
} catch (error) {
  console.error('❌ Error initializing Firebase Admin SDK:');
  console.error('   Make sure you have downloaded the service account key file');
  console.error('   Place it as: admin-dashboard/firebase-admin-key.json');
  console.error('   Or set FIREBASE_ADMIN_SDK_KEY environment variable');
  process.exit(1);
}

const auth = admin.auth();
const db = admin.firestore();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function question(prompt) {
  return new Promise((resolve) => {
    rl.question(prompt, (answer) => {
      resolve(answer);
    });
  });
}

async function setupAdmin() {
  console.log('\n🚀 CareLink Admin Dashboard - Super Admin Setup\n');

  try {
    // Get user email
    const email = await question('Enter admin email: ');
    
    if (!email || !email.includes('@')) {
      console.error('❌ Invalid email format');
      rl.close();
      process.exit(1);
    }

    // Verify user exists in Firebase Auth
    console.log('\n🔍 Checking if user exists in Firebase Auth...');
    let user;
    try {
      user = await auth.getUserByEmail(email);
      console.log(`✅ User found: ${user.uid}`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.error(`❌ User not found in Firebase Auth`);
        console.error('   Please create the user first in Firebase Console or via your app signup');
        rl.close();
        process.exit(1);
      }
      throw error;
    }

    // Confirm before proceeding
    const confirm = await question(`\n⚠️  About to make ${email} a super admin. Continue? (yes/no): `);
    if (confirm.toLowerCase() !== 'yes') {
      console.log('❌ Cancelled');
      rl.close();
      process.exit(0);
    }

    // Set custom claims
    console.log('\n🔐 Setting custom claims...');
    await auth.setCustomUserClaims(user.uid, {
      admin: true,
      admin_role: 'superadmin',
    });
    console.log('✅ Custom claims set');

    // Create admin document
    console.log('\n📄 Creating admin document...');
    const adminData = {
      uid: user.uid,
      email: email,
      name: user.displayName || 'Super Admin',
      role: 'superadmin',
      permissions: {
        canManageUsers: true,
        canVerifyCaregiver: true,
        canModerateJobs: true,
        canApprovePayouts: true,
        canManageDisputes: true,
        canViewAuditLog: true,
        canManageSiteSettings: true,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLogin: null,
    };

    await db.collection('admins').doc(user.uid).set(adminData);
    console.log('✅ Admin document created');

    console.log('\n✅ Super admin setup complete!\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`Email:     ${email}`);
    console.log(`Role:      Super Admin (👑)`);
    console.log(`UID:       ${user.uid}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('\n📝 Next steps:');
    console.log('1. npm run dev          (Start local dashboard)');
    console.log('2. Visit http://localhost:3000');
    console.log(`3. Log in with ${email} and your password\n`);

    rl.close();
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error setting up admin:');
    console.error(error.message);
    rl.close();
    process.exit(1);
  }
}

setupAdmin();
