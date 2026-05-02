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
  LinearProgress,
  Divider,
} from '@mui/material';
import { db } from '../lib/firebase';
import { collection, getDocs, query, where, updateDoc, doc } from 'firebase/firestore';
import { showSuccess, showError } from '../lib/toast';
import { DataTable } from '../components/DataTable';
import { StatusBadge } from '../components/StatusBadge';
import { StatCard } from '../components/StatCard';
import { formatDate, formatCurrency } from '../lib/utils';
import { useAdmin } from '../context/AdminContext';
import { COLORS, SHADOWS, TRANSITIONS } from '../lib/themeConstants';
import {
  People as PeopleIcon,
  VerifiedUser as VerifiedUserIcon,
  Warning as WarningIcon,
  TrendingUp as TrendingUpIcon,
} from '@mui/icons-material';

const isPendingVerification = (status) =>
  !status || status === 'pending' || status === 'pending_verification';

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
  const [stats, setStats] = useState({
    totalUsers: 0,
    caregivers: 0,
    clients: 0,
    verified: 0,
    pending: 0,
    rejected: 0,
  });

  useEffect(() => {
    const fetchUsers = async () => {
      try {
        const usersSnapshot = await getDocs(collection(db, 'users'));
        const usersList = usersSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
        
        // Calculate statistics
        const statsData = {
          totalUsers: usersList.length,
          caregivers: usersList.filter(u => u.role === 'caregiver').length,
          clients: usersList.filter(u => u.role === 'client').length,
          verified: usersList.filter(u => u.verificationStatus === 'approved').length,
          pending: usersList.filter(u => isPendingVerification(u.verificationStatus)).length,
          rejected: usersList.filter(u => u.verificationStatus === 'rejected').length,
        };
        
        setStats(statsData);
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
    if (statusFilter === 'pending') {
      filtered = filtered.filter((u) => isPendingVerification(u.verificationStatus));
    } else if (statusFilter !== 'all') {
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
      showSuccess('Action completed successfully');
    } catch (error) {
      console.error('Error performing action:', error);
      showError('Error: ' + error.message);
    }
  };

  const columns = [
    {
      key: 'name',
      label: 'Name',
      render: (value, row) => (
        <Box sx={{ cursor: 'pointer', fontWeight: 500, color: COLORS.gray900 }}>
          {value || row.email?.split('@')[0]}
        </Box>
      ),
    },
    {
      key: 'email',
      label: 'Email',
      render: (value) => (
        <Typography variant="body2" sx={{ color: COLORS.gray600 }}>
          {value}
        </Typography>
      ),
    },
    {
      key: 'role',
      label: 'Role',
      render: (value) => (
        <StatusBadge
          status={value === 'caregiver' ? 'active' : 'active'}
          label={value === 'caregiver' ? 'Caregiver' : 'Client'}
          variant="soft"
          size="small"
        />
      ),
    },
    {
      key: 'verificationStatus',
      label: 'Verification',
      render: (value) => <StatusBadge status={value || 'pending'} variant="soft" size="small" />,
    },
    {
      key: 'createdAt',
      label: 'Joined',
      render: (value) => formatDate(value),
    },
    {
      key: 'rating',
      label: 'Rating',
      render: (value) => (
        <Typography variant="body2" sx={{ fontWeight: 600, color: COLORS.primary }}>
          {value ? `⭐ ${value.toFixed(1)}` : '—'}
        </Typography>
      ),
    },
  ];

  return (
    <Box>
      {/* Page Header */}
      <Box sx={{ mb: 4 }}>
        <Typography
          variant="h3"
          sx={{
            fontWeight: 700,
            color: COLORS.gray900,
            mb: 0.5,
          }}
        >
          User Management
        </Typography>
        <Typography
          variant="body2"
          sx={{
            color: COLORS.gray600,
          }}
        >
          Manage caregivers, clients, and user verification status.
        </Typography>
      </Box>

      {/* Statistics Cards */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Users"
            value={stats.totalUsers}
            icon={PeopleIcon}
            loading={loading}
            color={COLORS.primary}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Verified Users"
            value={stats.verified}
            subtitle={`${Math.round((stats.verified / stats.totalUsers) * 100 || 0)}% verified`}
            icon={VerifiedUserIcon}
            loading={loading}
            color={COLORS.success}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Pending Verification"
            value={stats.pending}
            icon={WarningIcon}
            loading={loading}
            color={COLORS.pending}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Role Distribution"
            value={`${stats.caregivers}C / ${stats.clients}U`}
            subtitle="Caregivers / Clients"
            icon={TrendingUpIcon}
            loading={loading}
            color={COLORS.info}
          />
        </Grid>
      </Grid>

      {/* Filters */}
      <Card
        sx={{
          mb: 3,
          boxShadow: SHADOWS.sm,
          transition: TRANSITIONS.smooth,
        }}
      >
        <CardContent>
          <Typography
            variant="body2"
            sx={{
              fontWeight: 600,
              color: COLORS.gray900,
              mb: 2,
            }}
          >
            Filters
          </Typography>
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                fullWidth
                size="small"
                placeholder="Search by name or email..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                sx={{
                  '& .MuiOutlinedInput-root': {
                    borderRadius: '8px',
                  },
                }}
              />
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                select
                fullWidth
                size="small"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                sx={{
                  '& .MuiOutlinedInput-root': {
                    borderRadius: '8px',
                  },
                }}
              >
                <MenuItem value="all">All Status</MenuItem>
                <MenuItem value="pending">Pending</MenuItem>
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
                sx={{
                  '& .MuiOutlinedInput-root': {
                    borderRadius: '8px',
                  },
                }}
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
      <Card
        sx={{
          boxShadow: SHADOWS.sm,
          transition: TRANSITIONS.smooth,
          '&:hover': {
            boxShadow: SHADOWS.md,
          },
        }}
      >
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
        <DialogTitle sx={{ fontWeight: 700, color: COLORS.gray900 }}>User Details</DialogTitle>
        <Divider />
        <DialogContent>
          {selectedUser && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 2 }}>
              <Box>
                <Typography variant="body2" sx={{ fontWeight: 600, color: COLORS.gray600, mb: 0.5 }}>
                  Name
                </Typography>
                <Typography variant="body1" sx={{ color: COLORS.gray900 }}>
                  {selectedUser.name || selectedUser.email}
                </Typography>
              </Box>
              <Box>
                <Typography variant="body2" sx={{ fontWeight: 600, color: COLORS.gray600, mb: 0.5 }}>
                  Email
                </Typography>
                <Typography variant="body1" sx={{ color: COLORS.gray900 }}>
                  {selectedUser.email}
                </Typography>
              </Box>
              <Box>
                <Typography variant="body2" sx={{ fontWeight: 600, color: COLORS.gray600, mb: 0.5 }}>
                  Role
                </Typography>
                <StatusBadge
                  status={selectedUser.role === 'caregiver' ? 'active' : 'active'}
                  label={selectedUser.role === 'caregiver' ? 'Caregiver' : 'Client'}
                  variant="soft"
                />
              </Box>
              <Box>
                <Typography variant="body2" sx={{ fontWeight: 600, color: COLORS.gray600, mb: 0.5 }}>
                  Verification Status
                </Typography>
                <StatusBadge status={selectedUser.verificationStatus || 'pending'} variant="soft" />
              </Box>
              {selectedUser.verificationNotes && (
                <Box>
                  <Typography variant="body2" sx={{ fontWeight: 600, color: COLORS.gray600, mb: 0.5 }}>
                    Notes
                  </Typography>
                  <Typography variant="body2" sx={{ color: COLORS.gray600 }}>
                    {selectedUser.verificationNotes}
                  </Typography>
                </Box>
              )}
              <Box>
                <Typography variant="body2" sx={{ fontWeight: 600, color: COLORS.gray600, mb: 0.5 }}>
                  Joined
                </Typography>
                <Typography variant="body2" sx={{ color: COLORS.gray600 }}>
                  {formatDate(selectedUser.createdAt)}
                </Typography>
              </Box>
            </Box>
          )}
        </DialogContent>
        <Divider />
        <DialogActions sx={{ p: 2 }}>
          {canPerform('verifyCaregiver') && selectedUser?.role === 'caregiver' && (
            <>
              <Button
                onClick={() => {
                  setActionType('verify');
                  setOpenAction(true);
                }}
                variant="contained"
                sx={{ backgroundColor: COLORS.success }}
              >
                Approve
              </Button>
              <Button
                onClick={() => {
                  setActionType('reject');
                  setOpenAction(true);
                }}
                sx={{ color: COLORS.error }}
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
                sx={{ color: COLORS.warning }}
              >
                Suspend
              </Button>
              <Button
                onClick={() => {
                  setActionType('ban');
                  setOpenAction(true);
                }}
                sx={{ color: COLORS.error }}
              >
                Ban
              </Button>
            </>
          )}
          <Button onClick={() => setOpenDetail(false)} sx={{ color: COLORS.gray600 }}>
            Close
          </Button>
        </DialogActions>
      </Dialog>

      {/* Action Dialog */}
      <Dialog open={openAction} onClose={() => setOpenAction(false)} maxWidth="xs" fullWidth>
        <DialogTitle sx={{ fontWeight: 700, color: COLORS.gray900 }}>Confirm Action</DialogTitle>
        <Divider />
        <DialogContent sx={{ pt: 2 }}>
          <Alert severity="warning" sx={{ mb: 2, borderRadius: '8px' }}>
            Are you sure you want to <strong>{actionType}</strong> this user?
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
