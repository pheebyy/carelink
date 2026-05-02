import React, { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Grid,
  MenuItem,
  TextField,
  Typography,
  CircularProgress,
  Divider,
} from '@mui/material';
import {
  Gavel as GavelIcon,
  PendingActions as PendingIcon,
  ReportProblem as ReportIcon,
  CheckCircle as CheckCircleIcon,
} from '@mui/icons-material';
import {
  addDoc,
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
} from 'firebase/firestore';
import { db } from '../lib/firebase';
import { DataTable } from '../components/DataTable';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';
import { useAdmin } from '../context/AdminContext';
import { formatCurrency, formatDateTime } from '../lib/utils';
import { COLORS } from '../lib/themeConstants';
import { showError, showSuccess } from '../lib/toast';

const openStatuses = ['pending', 'open', 'submitted', 'investigating', 'awaiting_user'];

const normalizeStatus = (status) => status || 'pending';

const getDisputeAmount = (dispute) => Number(dispute.amount || dispute.transactionAmount || 0);

export default function DisputesPage() {
  const { user, canPerform } = useAdmin();
  const canManageDisputes = canPerform('manageDisputes');
  const [disputes, setDisputes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('open');
  const [selectedDispute, setSelectedDispute] = useState(null);
  const [openDetail, setOpenDetail] = useState(false);
  const [openDecision, setOpenDecision] = useState(false);
  const [nextStatus, setNextStatus] = useState('');
  const [resolution, setResolution] = useState('');
  const [resolutionNotes, setResolutionNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const disputesQuery = query(collection(db, 'disputes'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(
      disputesQuery,
      (snapshot) => {
        setDisputes(snapshot.docs.map((item) => ({ id: item.id, ...item.data() })));
        setLoading(false);
      },
      (error) => {
        console.error('Error loading disputes:', error);
        showError('Unable to load disputes: ' + error.message);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, []);

  const filteredDisputes = useMemo(() => {
    if (statusFilter === 'all') return disputes;
    if (statusFilter === 'open') {
      return disputes.filter((dispute) => openStatuses.includes(normalizeStatus(dispute.status)));
    }
    return disputes.filter((dispute) => normalizeStatus(dispute.status) === statusFilter);
  }, [disputes, statusFilter]);

  const stats = useMemo(() => {
    const open = disputes.filter((dispute) => openStatuses.includes(normalizeStatus(dispute.status)));
    const investigating = disputes.filter(
      (dispute) => normalizeStatus(dispute.status) === 'investigating'
    );
    const resolved = disputes.filter((dispute) => normalizeStatus(dispute.status) === 'resolved');
    const rejected = disputes.filter((dispute) => normalizeStatus(dispute.status) === 'rejected');

    return {
      total: disputes.length,
      open: open.length,
      openAmount: open.reduce((sum, dispute) => sum + getDisputeAmount(dispute), 0),
      investigating: investigating.length,
      resolved: resolved.length,
      rejected: rejected.length,
    };
  }, [disputes]);

  const writeAuditLog = async (action, dispute, details = {}) => {
    await addDoc(collection(db, 'auditLogs'), {
      adminId: user?.uid || 'unknown',
      action,
      details: {
        disputeId: dispute.id,
        transactionId: dispute.transactionId || dispute.paymentReference || null,
        raisedBy: dispute.raisedBy || dispute.clientId || null,
        amount: getDisputeAmount(dispute),
        ...details,
      },
      timestamp: serverTimestamp(),
    });
  };

  const notifyParticipant = async (dispute, title, message) => {
    const userId = dispute.raisedBy || dispute.clientId;
    if (!userId) return;

    await addDoc(collection(db, 'notifications'), {
      userId,
      type: 'dispute_status',
      title,
      message,
      read: false,
      disputeId: dispute.id,
      transactionId: dispute.transactionId || dispute.paymentReference || null,
      createdAt: serverTimestamp(),
    });
  };

  const handleViewDetails = (dispute) => {
    setSelectedDispute(dispute);
    setOpenDetail(true);
  };

  const openStatusDecision = (status) => {
    setNextStatus(status);
    setResolution('');
    setResolutionNotes('');
    setOpenDecision(true);
  };

  const closeDecision = () => {
    setOpenDecision(false);
    setNextStatus('');
    setResolution('');
    setResolutionNotes('');
  };

  const handleUpdateDispute = async () => {
    if (!selectedDispute || !nextStatus) return;

    const isFinal = nextStatus === 'resolved' || nextStatus === 'rejected';
    if (isFinal && !resolutionNotes.trim()) {
      showError('Please add resolution notes before closing the dispute');
      return;
    }

    try {
      setSubmitting(true);
      const updateData = {
        status: nextStatus,
        updatedAt: serverTimestamp(),
        lastAdminNote: resolutionNotes,
        lastUpdatedBy: user?.uid || null,
      };

      if (nextStatus === 'investigating') {
        updateData.investigatingAt = serverTimestamp();
        updateData.investigatingBy = user?.uid || null;
      }

      if (nextStatus === 'awaiting_user') {
        updateData.awaitingUserAt = serverTimestamp();
      }

      if (isFinal) {
        updateData.resolution = resolution || nextStatus;
        updateData.resolutionNotes = resolutionNotes;
        updateData.resolvedAt = serverTimestamp();
        updateData.resolvedBy = user?.uid || null;
      }

      await updateDoc(doc(db, 'disputes', selectedDispute.id), updateData);

      if (nextStatus === 'resolved' && resolution === 'return_to_client') {
        await addDoc(collection(db, 'refunds'), {
          refundId: `refund_${selectedDispute.id}_${Date.now()}`,
          disputeId: selectedDispute.id,
          transactionId: selectedDispute.transactionId || selectedDispute.paymentReference || null,
          clientId: selectedDispute.raisedBy || selectedDispute.clientId || null,
          caregiverId: selectedDispute.raisedAgainst || selectedDispute.caregiverId || null,
          amount: getDisputeAmount(selectedDispute),
          currency: 'KES',
          reason: `Dispute resolved for client: ${resolutionNotes}`,
          status: 'pending',
          refundMethod: 'paystack',
          createdAt: serverTimestamp(),
          createdBy: user?.uid || null,
          attempts: 0,
          maxAttempts: 3,
        });
      }

      await writeAuditLog('update_dispute', selectedDispute, {
        status: nextStatus,
        resolution: resolution || null,
        notes: resolutionNotes,
      });
      await notifyParticipant(
        selectedDispute,
        'Dispute updated',
        isFinal
          ? `Your dispute has been ${nextStatus}. ${resolutionNotes}`
          : `Your dispute status is now ${nextStatus.replace(/_/g, ' ')}.`
      );

      showSuccess('Dispute updated successfully');
      closeDecision();
      setOpenDetail(false);
      setSelectedDispute(null);
    } catch (error) {
      console.error('Error updating dispute:', error);
      showError('Error: ' + error.message);
    } finally {
      setSubmitting(false);
    }
  };

  const columns = [
    {
      key: 'id',
      label: 'Case',
      render: (value, row) => (
        <Box>
          <Typography variant="body2" sx={{ fontWeight: 700 }}>
            CASE-{value.substring(0, 8).toUpperCase()}
          </Typography>
          <Typography variant="caption" color="textSecondary">
            Tx: {row.transactionId || row.paymentReference || '-'}
          </Typography>
        </Box>
      ),
    },
    {
      key: 'type',
      label: 'Type',
      render: (value) => <Chip label={value || 'payment'} size="small" />,
    },
    {
      key: 'amount',
      label: 'Amount',
      render: (value, row) => {
        const amount = value || row.transactionAmount;
        return amount ? formatCurrency(Number(amount)) : '-';
      },
    },
    {
      key: 'status',
      label: 'Status',
      render: (value) => (
        <StatusBadge status={normalizeStatus(value)} variant="soft" size="small" />
      ),
    },
    {
      key: 'reason',
      label: 'Reason',
      render: (value, row) => (
        <Typography variant="body2" sx={{ maxWidth: 320 }}>
          {value || row.description || row.details || '-'}
        </Typography>
      ),
    },
    {
      key: 'createdAt',
      label: 'Created',
      render: (value) => formatDateTime(value),
    },
  ];

  if (!canManageDisputes) {
    return (
      <Card>
        <CardContent>
          <Typography color="error">
            You do not have permission to manage disputes.
          </Typography>
        </CardContent>
      </Card>
    );
  }

  return (
    <Box>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h3" sx={{ fontWeight: 700, color: COLORS.gray900 }}>
          Dispute Resolution
        </Typography>
        <Typography variant="body2" sx={{ color: COLORS.gray600 }}>
          Investigate payment disputes, record decisions, and create refund follow-up.
        </Typography>
      </Box>

      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Open Cases"
            value={stats.open}
            subtitle={formatCurrency(stats.openAmount)}
            icon={ReportIcon}
            loading={loading}
            color={COLORS.pending}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Investigating"
            value={stats.investigating}
            icon={PendingIcon}
            loading={loading}
            color={COLORS.info}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Resolved"
            value={stats.resolved}
            icon={CheckCircleIcon}
            loading={loading}
            color={COLORS.success}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Cases"
            value={stats.total}
            subtitle={`${stats.rejected} rejected`}
            icon={GavelIcon}
            loading={loading}
            color={COLORS.primary}
          />
        </Grid>
      </Grid>

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <TextField
            select
            size="small"
            label="Status"
            value={statusFilter}
            onChange={(event) => setStatusFilter(event.target.value)}
            sx={{ minWidth: 240 }}
          >
            <MenuItem value="all">All Statuses</MenuItem>
            <MenuItem value="open">Open / Active</MenuItem>
            <MenuItem value="pending">Pending</MenuItem>
            <MenuItem value="investigating">Investigating</MenuItem>
            <MenuItem value="awaiting_user">Awaiting User</MenuItem>
            <MenuItem value="resolved">Resolved</MenuItem>
            <MenuItem value="rejected">Rejected</MenuItem>
          </TextField>
        </CardContent>
      </Card>

      <Card>
        <CardContent>
          <DataTable
            columns={columns}
            data={filteredDisputes}
            loading={loading}
            onRowClick={handleViewDetails}
            emptyMessage="No disputes found"
          />
        </CardContent>
      </Card>

      <Dialog open={openDetail} onClose={() => setOpenDetail(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Dispute Details</DialogTitle>
        <DialogContent>
          {selectedDispute && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
              <Box>
                <Typography variant="body2" color="textSecondary">Case ID</Typography>
                <Typography variant="body1">CASE-{selectedDispute.id.substring(0, 8).toUpperCase()}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">Raised By</Typography>
                <Typography variant="body2">
                  {selectedDispute.raisedBy || selectedDispute.clientId || 'Unknown'}
                </Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">Raised Against</Typography>
                <Typography variant="body2">
                  {selectedDispute.raisedAgainst || selectedDispute.caregiverId || 'Unknown'}
                </Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">Amount</Typography>
                <Typography variant="h6">{formatCurrency(getDisputeAmount(selectedDispute))}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">Status</Typography>
                <StatusBadge status={normalizeStatus(selectedDispute.status)} variant="soft" />
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">Details</Typography>
                <Typography variant="body2">
                  {selectedDispute.description || selectedDispute.details || selectedDispute.reason || '-'}
                </Typography>
              </Box>
              {selectedDispute.resolution && (
                <Alert severity={selectedDispute.status === 'rejected' ? 'warning' : 'success'}>
                  <strong>{selectedDispute.resolution}</strong>
                  <br />
                  {selectedDispute.resolutionNotes}
                </Alert>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          {selectedDispute && !['resolved', 'rejected'].includes(normalizeStatus(selectedDispute.status)) && (
            <>
              <Button onClick={() => openStatusDecision('investigating')}>
                Investigating
              </Button>
              <Button onClick={() => openStatusDecision('awaiting_user')}>
                Awaiting User
              </Button>
              <Button color="error" onClick={() => openStatusDecision('rejected')}>
                Reject
              </Button>
              <Button variant="contained" onClick={() => openStatusDecision('resolved')}>
                Resolve
              </Button>
            </>
          )}
          <Button onClick={() => setOpenDetail(false)}>Close</Button>
        </DialogActions>
      </Dialog>

      <Dialog open={openDecision} onClose={closeDecision} maxWidth="sm" fullWidth>
        <DialogTitle>Update Dispute</DialogTitle>
        <DialogContent>
          {nextStatus === 'resolved' && (
            <TextField
              select
              fullWidth
              label="Resolution"
              value={resolution}
              onChange={(event) => setResolution(event.target.value)}
              sx={{ mt: 1, mb: 2 }}
            >
              <MenuItem value="">Select resolution...</MenuItem>
              <MenuItem value="return_to_client">Return to Client / Create Refund</MenuItem>
              <MenuItem value="caregiver_keeps_payment">Caregiver Keeps Payment</MenuItem>
              <MenuItem value="split">Split Outcome</MenuItem>
              <MenuItem value="other">Other</MenuItem>
            </TextField>
          )}

          {nextStatus === 'resolved' && resolution === 'return_to_client' && (
            <Alert severity="info" sx={{ mb: 2 }}>
              Confirming this decision creates a pending refund record for finance review.
            </Alert>
          )}

          <Divider sx={{ mb: 2 }} />

          <TextField
            fullWidth
            multiline
            rows={4}
            label={nextStatus === 'resolved' || nextStatus === 'rejected' ? 'Resolution notes' : 'Admin note'}
            value={resolutionNotes}
            onChange={(event) => setResolutionNotes(event.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={closeDecision}>Cancel</Button>
          <Button
            onClick={handleUpdateDispute}
            variant="contained"
            disabled={submitting}
            color={nextStatus === 'rejected' ? 'error' : 'primary'}
          >
            {submitting ? <CircularProgress size={20} /> : 'Confirm'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
