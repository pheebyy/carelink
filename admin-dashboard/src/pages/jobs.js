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
  MenuItem,
  Divider,
  LinearProgress,
} from '@mui/material';
import { db } from '../lib/firebase';
import { collection, getDocs, updateDoc, doc } from 'firebase/firestore';
import { DataTable } from '../components/DataTable';
import { StatusBadge } from '../components/StatusBadge';
import { StatCard } from '../components/StatCard';
import { formatDate, formatCurrency } from '../lib/utils';
import { COLORS, SHADOWS, TRANSITIONS } from '../lib/themeConstants';
import {
  Work as WorkIcon,
  PublishedWithChanges as ApprovedIcon,
  Flag as FlagIcon,
  TrendingUp as TrendingUpIcon,
} from '@mui/icons-material';

export default function JobsPage() {
  const [jobs, setJobs] = useState([]);
  const [filteredJobs, setFilteredJobs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedJob, setSelectedJob] = useState(null);
  const [openDetail, setOpenDetail] = useState(false);
  const [openAction, setOpenAction] = useState(false);
  const [actionType, setActionType] = useState('');
  const [rejectionReason, setRejectionReason] = useState('');
  const [stats, setStats] = useState({
    totalJobs: 0,
    active: 0,
    pending: 0,
    completed: 0,
    flagged: 0,
  });

  useEffect(() => {
    const fetchJobs = async () => {
      try {
        const jobsSnapshot = await getDocs(collection(db, 'jobs'));
        const jobsList = jobsSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
        
        // Calculate statistics
        const statsData = {
          totalJobs: jobsList.length,
          active: jobsList.filter(j => j.status === 'active' || j.status === 'open').length,
          pending: jobsList.filter(j => j.status === 'pending').length,
          completed: jobsList.filter(j => j.status === 'completed').length,
          flagged: jobsList.filter(j => j.flagged).length,
        };
        
        setStats(statsData);
        setJobs(jobsList);
      } catch (error) {
        console.error('Error fetching jobs:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchJobs();
  }, []);

  useEffect(() => {
    let filtered = jobs;

    if (searchTerm) {
      filtered = filtered.filter(
        (j) =>
          j.title?.toLowerCase().includes(searchTerm.toLowerCase()) ||
          j.description?.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    if (statusFilter !== 'all') {
      filtered = filtered.filter((j) => j.status === statusFilter);
    }

    setFilteredJobs(filtered);
  }, [jobs, statusFilter, searchTerm]);

  const handleViewDetails = (job) => {
    setSelectedJob(job);
    setOpenDetail(true);
  };

  const handleAction = async () => {
    if (!selectedJob || !actionType) return;

    try {
      const jobRef = doc(db, 'jobs', selectedJob.id);
      const updateData = {};

      if (actionType === 'approve') {
        updateData.status = 'open';
        updateData.approvedBy = 'admin';
        updateData.approvedAt = new Date();
      } else if (actionType === 'reject') {
        updateData.status = 'rejected';
        updateData.rejectionReason = rejectionReason;
      } else if (actionType === 'flag') {
        updateData.flagged = true;
        updateData.flagReason = rejectionReason;
      } else if (actionType === 'delete') {
        updateData.deleted = true;
        updateData.deletedBy = 'admin';
      }

      await updateDoc(jobRef, updateData);

      setJobs(jobs.map((j) => (j.id === selectedJob.id ? { ...j, ...updateData } : j)));
      setOpenAction(false);
      setOpenDetail(false);
      setSelectedJob(null);
      setRejectionReason('');
      alert('Action completed successfully');
    } catch (error) {
      console.error('Error performing action:', error);
      alert('Error: ' + error.message);
    }
  };

  const columns = [
    {
      key: 'title',
      label: 'Job Title',
      render: (value) => (
        <Typography sx={{ cursor: 'pointer', color: COLORS.primary, fontWeight: 500 }}>
          {value || 'Untitled'}
        </Typography>
      ),
    },
    {
      key: 'budget',
      label: 'Budget',
      render: (value) => (
        <Typography sx={{ fontWeight: 600, color: COLORS.primary }}>
          KES {value?.toLocaleString() || '0'}
        </Typography>
      ),
    },
    {
      key: 'status',
      label: 'Status',
      render: (value) => <StatusBadge status={value || 'pending'} variant="soft" size="small" />,
    },
    {
      key: 'flagged',
      label: 'Flagged',
      render: (value) => (value ? <StatusBadge status="warning" label="Flagged" variant="soft" size="small" /> : '—'),
    },
    {
      key: 'applicants',
      label: 'Applicants',
      render: (value) => (
        <Typography sx={{ fontWeight: 600, color: COLORS.gray900 }}>
          {value || '0'}
        </Typography>
      ),
    },
    {
      key: 'createdAt',
      label: 'Posted',
      render: (value) => formatDate(value),
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
          Job Moderation
        </Typography>
        <Typography
          variant="body2"
          sx={{
            color: COLORS.gray600,
          }}
        >
          Review, approve, and manage job postings on the platform.
        </Typography>
      </Box>

      {/* Statistics Cards */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Jobs"
            value={stats.totalJobs}
            icon={WorkIcon}
            loading={loading}
            color={COLORS.primary}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Active Jobs"
            value={stats.active}
            icon={ApprovedIcon}
            loading={loading}
            color={COLORS.success}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Pending Review"
            value={stats.pending}
            icon={WorkIcon}
            loading={loading}
            color={COLORS.pending}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Flagged"
            value={stats.flagged}
            icon={FlagIcon}
            loading={loading}
            color={COLORS.error}
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
                placeholder="Search jobs..."
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
                <MenuItem value="pending">Pending Approval</MenuItem>
                <MenuItem value="open">Active</MenuItem>
                <MenuItem value="rejected">Rejected</MenuItem>
                <MenuItem value="completed">Completed</MenuItem>
              </TextField>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Jobs Table */}
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
            data={filteredJobs}
            loading={loading}
            onRowClick={handleViewDetails}
            emptyMessage="No jobs found"
          />
        </CardContent>
      </Card>

      {/* Job Detail Dialog */}
      <Dialog open={openDetail} onClose={() => setOpenDetail(false)} maxWidth="sm" fullWidth>
        <DialogTitle sx={{ fontWeight: 700, color: COLORS.gray900 }}>Job Details</DialogTitle>
        <Divider />
        <DialogContent sx={{ pt: 2 }}>
          {selectedJob && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              <Box>
                <Typography variant="body2" sx={{ fontWeight: 600, color: COLORS.gray600, mb: 0.5 }}>
                  Title
                </Typography>
                <Typography variant="body1">{selectedJob.title}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Description
                </Typography>
                <Typography variant="body2">{selectedJob.description}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Budget
                </Typography>
                <Typography variant="body1">KES {selectedJob.budget?.toLocaleString()}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Status
                </Typography>
                <Chip label={selectedJob.status} size="small" />
              </Box>
              {selectedJob.flagged && (
                <Box sx={{ p: 1.5, backgroundColor: '#ffebee', borderRadius: 1 }}>
                  <Typography variant="caption" sx={{ fontWeight: 'bold', color: '#c62828' }}>
                    ⚠️ FLAGGED
                  </Typography>
                  <Typography variant="body2" sx={{ color: '#c62828', mt: 0.5 }}>
                    {selectedJob.flagReason}
                  </Typography>
                </Box>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          {selectedJob?.status === 'pending' && (
            <>
              <Button
                onClick={() => {
                  setActionType('approve');
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
          <Button
            onClick={() => {
              setActionType('flag');
              setOpenAction(true);
            }}
            color="warning"
          >
            Flag
          </Button>
          <Button
            onClick={() => {
              setActionType('delete');
              setOpenAction(true);
            }}
            color="error"
          >
            Delete
          </Button>
          <Button onClick={() => setOpenDetail(false)}>Close</Button>
        </DialogActions>
      </Dialog>

      {/* Action Dialog */}
      <Dialog open={openAction} onClose={() => setOpenAction(false)} maxWidth="xs" fullWidth>
        <DialogTitle>Confirm Action</DialogTitle>
        <DialogContent>
          <Typography sx={{ mb: 2 }}>Are you sure you want to {actionType} this job?</Typography>
          {['reject', 'flag', 'delete'].includes(actionType) && (
            <TextField
              fullWidth
              multiline
              rows={3}
              placeholder="Reason"
              value={rejectionReason}
              onChange={(e) => setRejectionReason(e.target.value)}
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
