import React, { useEffect, useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  TextField,
  Button,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Grid,
  FormControlLabel,
  Checkbox,
  Paper,
} from '@mui/material';
import { db } from '../lib/firebase';
import { collection, getDocs, updateDoc, doc } from 'firebase/firestore';
import { useAdmin } from '../context/AdminContext';

export default function SettingsPage() {
  const { adminRole } = useAdmin();
  const [admins, setAdmins] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedAdmin, setSelectedAdmin] = useState(null);
  const [openDialog, setOpenDialog] = useState(false);
  const [permissions, setPermissions] = useState({});
  const [newAdminEmail, setNewAdminEmail] = useState('');
  const [newAdminRole, setNewAdminRole] = useState('moderator');

  const availableRoles = [
    { id: 'moderator', label: 'Moderator', description: 'Can verify users and moderate jobs' },
    { id: 'finance', label: 'Finance', description: 'Can manage payments and payouts' },
    { id: 'support', label: 'Support', description: 'Can resolve disputes and support users' },
  ];

  const permissionsList = [
    { key: 'canManageUsers', label: 'Manage Users (verify, suspend, ban)' },
    { key: 'canVerifyCaregiver', label: 'Verify Caregivers' },
    { key: 'canModerateJobs', label: 'Moderate Jobs (approve, reject, delete)' },
    { key: 'canApprovePayouts', label: 'Approve & Manage Payouts' },
    { key: 'canManageDisputes', label: 'Manage Disputes' },
    { key: 'canViewAuditLog', label: 'View Audit Logs' },
    { key: 'canManageSiteSettings', label: 'Manage Site Settings' },
  ];

  useEffect(() => {
    if (adminRole !== 'superadmin') {
      console.error('Only superadmins can access settings');
      return;
    }

    const fetchAdmins = async () => {
      try {
        const adminsSnapshot = await getDocs(collection(db, 'admins'));
        const adminsList = adminsSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
        setAdmins(adminsList);
      } catch (error) {
        console.error('Error fetching admins:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchAdmins();
  }, [adminRole]);

  const handleEditAdmin = (admin) => {
    setSelectedAdmin(admin);
    setPermissions(admin.permissions || {});
    setOpenDialog(true);
  };

  const handleSavePermissions = async () => {
    if (!selectedAdmin) return;

    try {
      const adminRef = doc(db, 'admins', selectedAdmin.id);
      await updateDoc(adminRef, {
        permissions,
        updatedAt: new Date(),
      });

      setAdmins(
        admins.map((a) =>
          a.id === selectedAdmin.id ? { ...a, permissions } : a
        )
      );

      setOpenDialog(false);
      setSelectedAdmin(null);
      alert('Permissions updated successfully');
    } catch (error) {
      console.error('Error updating permissions:', error);
      alert('Error: ' + error.message);
    }
  };

  const handlePermissionChange = (permissionKey) => {
    setPermissions({
      ...permissions,
      [permissionKey]: !permissions[permissionKey],
    });
  };

  if (adminRole !== 'superadmin') {
    return (
      <Box>
        <Typography variant="h4" sx={{ fontWeight: 'bold', mb: 3 }}>
          Settings
        </Typography>
        <Card>
          <CardContent>
            <Typography color="error">
              🔒 Only super admins can access this page
            </Typography>
          </CardContent>
        </Card>
      </Box>
    );
  }

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 'bold', mb: 3 }}>
        Admin Settings
      </Typography>

      {/* Admin Roles Overview */}
      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 'bold', mb: 2 }}>
            Admin Roles & Permissions
          </Typography>
          <Grid container spacing={2}>
            {availableRoles.map((role) => (
              <Grid item xs={12} md={4} key={role.id}>
                <Card sx={{ backgroundColor: '#f9f9f9' }}>
                  <CardContent>
                    <Typography variant="subtitle1" sx={{ fontWeight: 'bold' }}>
                      {role.label}
                    </Typography>
                    <Typography variant="caption" color="textSecondary">
                      {role.description}
                    </Typography>
                  </CardContent>
                </Card>
              </Grid>
            ))}
          </Grid>
        </CardContent>
      </Card>

      {/* Admin Users List */}
      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 'bold', mb: 2 }}>
            Admin Users
          </Typography>
          <TableContainer component={Paper}>
            <Table>
              <TableHead sx={{ backgroundColor: '#f5f5f5' }}>
                <TableRow>
                  <TableCell sx={{ fontWeight: 'bold' }}>Email</TableCell>
                  <TableCell sx={{ fontWeight: 'bold' }}>Name</TableCell>
                  <TableCell sx={{ fontWeight: 'bold' }}>Role</TableCell>
                  <TableCell sx={{ fontWeight: 'bold' }}>Last Login</TableCell>
                  <TableCell sx={{ fontWeight: 'bold' }} align="right">
                    Actions
                  </TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {admins.map((admin) => (
                  <TableRow key={admin.id}>
                    <TableCell>{admin.email}</TableCell>
                    <TableCell>{admin.name || '-'}</TableCell>
                    <TableCell>
                      <Box
                        sx={{
                          display: 'inline-block',
                          px: 1.5,
                          py: 0.5,
                          backgroundColor: admin.role === 'superadmin' ? '#ffd700' : '#e0e0e0',
                          borderRadius: '4px',
                          fontSize: '0.85rem',
                          fontWeight: 'bold',
                        }}
                      >
                        {admin.role === 'superadmin' ? '👑 ' : ''}{admin.role}
                      </Box>
                    </TableCell>
                    <TableCell>
                      {admin.lastLogin
                        ? new Date(admin.lastLogin).toLocaleDateString()
                        : 'Never'}
                    </TableCell>
                    <TableCell align="right">
                      {admin.role !== 'superadmin' && (
                        <Button
                          size="small"
                          onClick={() => handleEditAdmin(admin)}
                          variant="outlined"
                        >
                          Edit Permissions
                        </Button>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </CardContent>
      </Card>

      {/* Add New Admin */}
      <Card>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 'bold', mb: 2 }}>
            Add New Admin
          </Typography>
          <Typography variant="caption" color="textSecondary" sx={{ display: 'block', mb: 2 }}>
            Note: User must exist in Firebase Auth first
          </Typography>
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Email"
                value={newAdminEmail}
                onChange={(e) => setNewAdminEmail(e.target.value)}
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                select
                fullWidth
                label="Role"
                value={newAdminRole}
                onChange={(e) => setNewAdminRole(e.target.value)}
              >
                {availableRoles.map((role) => (
                  <option key={role.id} value={role.id}>
                    {role.label}
                  </option>
                ))}
              </TextField>
            </Grid>
            <Grid item xs={12}>
              <Button variant="contained">
                Add Admin (Requires Cloud Function)
              </Button>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Edit Permissions Dialog */}
      <Dialog open={openDialog} onClose={() => setOpenDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Edit Admin Permissions</DialogTitle>
        <DialogContent>
          {selectedAdmin && (
            <Box sx={{ pt: 2 }}>
              <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                {selectedAdmin.email}
              </Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                {permissionsList.map((perm) => (
                  <FormControlLabel
                    key={perm.key}
                    control={
                      <Checkbox
                        checked={permissions[perm.key] || false}
                        onChange={() => handlePermissionChange(perm.key)}
                      />
                    }
                    label={perm.label}
                  />
                ))}
              </Box>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDialog(false)}>Cancel</Button>
          <Button onClick={handleSavePermissions} variant="contained" color="primary">
            Save Changes
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
