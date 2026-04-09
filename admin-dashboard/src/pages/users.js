import React, { useEffect, useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  TextField,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Grid,
  Chip,
  Alert,
  MenuItem,
} from '@mui/material';
import { db } from '../lib/firebase';
import { collection, getDocs, query, where, updateDoc, doc } from 'firebase/firestore';
import { DataTable } from '../components/DataTable';
import { formatDate, formatCurrency, getStatusIcon, getStatusColor } from '../lib/utils';
import { useAdmin } from '../context/AdminContext';

export default function UsersPage() {
  const { canPerform } = useAdmin();
  const [users, setUsers] = useState([]);
  const [filteredUsers, setFilteredUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [roleFilter, setRoleFilter] = useState('all');
  const [selectedUser, setSelectedUser] = useState(null);
  const [openDetail, setOpenDetail] = useState(false);
  const [openAction, setOpenAction] = useState(false);
  const [actionType, setActionType] = useState('');
  const [actionReason, setActionReason] = useState('');

  useEffect(() => {
    const fetchUsers = async () => {
      try {
        const usersSnapshot = await getDocs(collection(db, 'users'));
        const usersList = usersSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
        setUsers(usersList);
      } catch (error) {
        console.error('Error fetching users:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchUsers();
  }, []);

  useEffect(() => {
    let filtered = users;

    // Search filter
    if (searchTerm) {
      filtered = filtered.filter(
        (u) =>
          u.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
          u.email?.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    // Status filter
    if (statusFilter !== 'all') {
      filtered = filtered.filter((u) => u.verificationStatus === statusFilter);
    }

    // Role filter
    if (roleFilter !== 'all') {
      filtered = filtered.filter((u) => u.role === roleFilter);
    }

    setFilteredUsers(filtered);
  }, [users, searchTerm, statusFilter, roleFilter]);

  const handleViewDetails = (user) => {
    setSelectedUser(user);
    setOpenDetail(true);
  };

  const handleAction = async () => {
    if (!selectedUser || !actionType) return;

    try {
      const userRef = doc(db, 'users', selectedUser.id);
      const updateData = {};

      if (actionType === 'verify') {
        updateData.verificationStatus = 'approved';
      } else if (actionType === 'reject') {
        updateData.verificationStatus = 'rejected';
        updateData.verificationNotes = actionReason;
      } else if (actionType === 'suspend') {
        updateData.status = 'suspended';
      } else if (actionType === 'ban') {
        updateData.status = 'banned';
      }

      await updateDoc(userRef, updateData);

      // Update local state
      setUsers(users.map((u) => (u.id === selectedUser.id ? { ...u, ...updateData } : u)));
      setOpenAction(false);
      setOpenDetail(false);
      setSelectedUser(null);
      setActionReason('');
      alert('Action completed successfully');
    } catch (error) {
      console.error('Error performing action:', error);
      alert('Error: ' + error.message);
    }
  };

  const columns = [
    {
      key: 'name',
      label: 'Name',
      render: (value, row) => (
        <Box sx={{ cursor: 'pointer', color: '#4CAF50' }}>
          {value || row.email?.split('@')[0]}
        </Box>
      ),
    },
    {
      key: 'email',
      label: 'Email',
    },
    {
      key: 'role',
      label: 'Role',
      render: (value) => (
        <Chip label={value} size="small" color={value === 'caregiver' ? 'primary' : 'secondary'} />
      ),
    },
    {
      key: 'verificationStatus',
      label: 'Verification',
      render: (value) => (
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <span>{getStatusIcon(value || 'pending')}</span>
          <Chip
            label={value || 'pending'}
            size="small"
            sx={{
              backgroundColor: getStatusColor(value || 'pending') + '20',
              color: getStatusColor(value || 'pending'),
            }}
          />
        </Box>
      ),
    },
    {
      key: 'createdAt',
      label: 'Joined',
      render: (value) => formatDate(value),
    },
    {
      key: 'rating',
      label: 'Rating',
      render: (value) => (value ? `⭐ ${value.toFixed(1)}` : '-'),
    },
  ];

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 'bold', mb: 3 }}>
        User Management
      </Typography>

      {/* Filters */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                fullWidth
                size="small"
                placeholder="Search by name or email..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                select
                fullWidth
                size="small"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
              >
                <MenuItem value="all">All Status</MenuItem>
                <MenuItem value="pending_verification">Pending Verification</MenuItem>
                <MenuItem value="approved">Approved</MenuItem>
                <MenuItem value="rejected">Rejected</MenuItem>
              </TextField>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                select
                fullWidth
                size="small"
                value={roleFilter}
                onChange={(e) => setRoleFilter(e.target.value)}
              >
                <MenuItem value="all">All Roles</MenuItem>
                <MenuItem value="caregiver">Caregivers</MenuItem>
                <MenuItem value="client">Clients</MenuItem>
              </TextField>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Users Table */}
      <Card>
        <CardContent>
          <DataTable
            columns={columns}
            data={filteredUsers}
            loading={loading}
            onRowClick={handleViewDetails}
            emptyMessage="No users found"
          />
        </CardContent>
      </Card>

      {/* User Detail Dialog */}
      <Dialog open={openDetail} onClose={() => setOpenDetail(false)} maxWidth="sm" fullWidth>
        <DialogTitle>User Details</DialogTitle>
        <DialogContent>
          {selectedUser && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 2 }}>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Name
                </Typography>
                <Typography variant="body1">{selectedUser.name || selectedUser.email}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Email
                </Typography>
                <Typography variant="body1">{selectedUser.email}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Role
                </Typography>
                <Chip label={selectedUser.role} size="small" />
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Verification Status
                </Typography>
                <Chip
                  label={selectedUser.verificationStatus || 'pending'}
                  size="small"
                  sx={{
                    backgroundColor: getStatusColor(selectedUser.verificationStatus || 'pending') + '20',
                    color: getStatusColor(selectedUser.verificationStatus || 'pending'),
                  }}
                />
              </Box>
              {selectedUser.verificationNotes && (
                <Box>
                  <Typography variant="body2" color="textSecondary">
                    Notes
                  </Typography>
                  <Typography variant="body2">{selectedUser.verificationNotes}</Typography>
                </Box>
              )}
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Joined
                </Typography>
                <Typography variant="body2">{formatDate(selectedUser.createdAt)}</Typography>
              </Box>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          {canPerform('verifyCaregiver') && selectedUser?.role === 'caregiver' && (
            <>
              <Button
                onClick={() => {
                  setActionType('verify');
                  setOpenAction(true);
                }}
                variant="contained"
                color="success"
              >
                Approve
              </Button>
              <Button
                onClick={() => {
                  setActionType('reject');
                  setOpenAction(true);
                }}
                color="error"
              >
                Reject
              </Button>
            </>
          )}
          {canPerform('manageUsers') && (
            <>
              <Button
                onClick={() => {
                  setActionType('suspend');
                  setOpenAction(true);
                }}
                color="warning"
              >
                Suspend
              </Button>
              <Button
                onClick={() => {
                  setActionType('ban');
                  setOpenAction(true);
                }}
                color="error"
              >
                Ban
              </Button>
            </>
          )}
          <Button onClick={() => setOpenDetail(false)}>Close</Button>
        </DialogActions>
      </Dialog>

      {/* Action Dialog */}
      <Dialog open={openAction} onClose={() => setOpenAction(false)} maxWidth="xs" fullWidth>
        <DialogTitle>Confirm Action</DialogTitle>
        <DialogContent>
          <Alert severity="warning" sx={{ mb: 2 }}>
            Are you sure you want to {actionType} this user?
          </Alert>
          {(actionType === 'reject' || actionType === 'suspend' || actionType === 'ban') && (
            <TextField
              fullWidth
              multiline
              rows={3}
              placeholder="Reason (optional)"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              sx={{ mt: 2 }}
            />
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenAction(false)}>Cancel</Button>
          <Button onClick={handleAction} variant="contained" color="primary">
            Confirm
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
