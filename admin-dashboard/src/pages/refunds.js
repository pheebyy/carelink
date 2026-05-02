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
  CheckCircle as CheckCircleIcon,
  ErrorOutline as ErrorIcon,
  PendingActions as PendingIcon,
  Replay as RetryIcon,
} from '@mui/icons-material';
import { httpsCallable } from 'firebase/functions';
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
import { db, functions } from '../lib/firebase';
import { DataTable } from '../components/DataTable';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';
import { useAdmin } from '../context/AdminContext';
import { formatCurrency, formatDateTime } from '../lib/utils';
import { COLORS } from '../lib/themeConstants';
import { showError, showSuccess } from '../lib/toast';

const activeRefundStatuses = ['pending', 'processing'];

const getRefundAmount = (refund) => Number(refund.amount || 0);

export default function RefundsPage() {
  const { user, canPerform } = useAdmin();
  const canManageRefunds = canPerform('approvePayouts') || canPerform('manageDisputes');
  const [refunds, setRefunds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedRefund, setSelectedRefund] = useState(null);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [decisionOpen, setDecisionOpen] = useState(false);
  const [decisionType, setDecisionType] = useState('');
  const [decisionNote, setDecisionNote] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const refundsQuery = query(collection(db, 'refunds'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(
      refundsQuery,
      (snapshot) => {
        setRefunds(snapshot.docs.map((item) => ({ id: item.id, ...item.data() })));
        setLoading(false);
      },
      (error) => {
        console.error('Error loading refunds:', error);
        showError('Unable to load refunds: ' + error.message);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, []);

  const filteredRefunds = useMemo(() => {
    if (statusFilter === 'all') return refunds;
    if (statusFilter === 'active') {
      return refunds.filter((refund) => activeRefundStatuses.includes(refund.status));
    }
    return refunds.filter((refund) => refund.status === statusFilter);
  }, [refunds, statusFilter]);

  const stats = useMemo(() => {
    const active = refunds.filter((refund) => activeRefundStatuses.includes(refund.status));
    const completed = refunds.filter((refund) => refund.status === 'completed');
    const failed = refunds.filter((refund) => refund.status === 'failed');
    const rejected = refunds.filter((refund) => refund.status === 'rejected');

    return {
      total: refunds.length,
      activeCount: active.length,
      activeAmount: active.reduce((sum, refund) => sum + getRefundAmount(refund), 0),
      completedAmount: completed.reduce((sum, refund) => sum + getRefundAmount(refund), 0),
      failedCount: failed.length,
      rejectedCount: rejected.length,
    };
  }, [refunds]);

  const writeAuditLog = async (action, refund, details = {}) => {
    await addDoc(collection(db, 'auditLogs'), {
      adminId: user?.uid || 'unknown',
      action,
      details: {
        refundId: refund.id,
        transactionId: refund.transactionId || null,
        clientId: refund.clientId || null,
        amount: refund.amount || 0,
        ...details,
      },
      timestamp: serverTimestamp(),
    });
  };

  const notifyClient = async (refund, title, message) => {
    if (!refund.clientId) return;

    await addDoc(collection(db, 'notifications'), {
      userId: refund.clientId,
      type: 'refund_status',
      title,
      message,
      read: false,
      refundId: refund.id,
      transactionId: refund.transactionId || null,
      createdAt: serverTimestamp(),
    });
  };

  const openDecision = (refund, type) => {
    setSelectedRefund(refund);
    setDecisionType(type);
    setDecisionNote('');
    setDecisionOpen(true);
  };

  const closeDecision = () => {
    setDecisionOpen(false);
    setDecisionType('');
    setDecisionNote('');
  };

  const handleRetryRefund = async (refund) => {
    try {
      setSubmitting(true);
      const retryFailedRefund = httpsCallable(functions, 'retryFailedRefund');
      await retryFailedRefund({ refundId: refund.id });
      await writeAuditLog('retry_refund', refund);
      showSuccess('Refund retry initiated');
    } catch (error) {
      console.error('Error retrying refund:', error);
      showError('Error: ' + error.message);
    } finally {
      setSubmitting(false);
    }
  };

  const handleDecision = async () => {
    if (!selectedRefund || !decisionType) return;

    if (!decisionNote.trim()) {
      showError('Please add an admin note before continuing');
      return;
    }

    try {
      setSubmitting(true);

      if (decisionType === 'complete') {
        const manualRefundApproval = httpsCallable(functions, 'manualRefundApproval');
        await manualRefundApproval({
          refundId: selectedRefund.id,
          approvalNote: decisionNote,
        });
        await writeAuditLog('manual_refund_approval', selectedRefund, {
          note: decisionNote,
        });
        await notifyClient(
          selectedRefund,
          'Refund approved',
          `Your refund for ${formatCurrency(getRefundAmount(selectedRefund))} has been approved.`
        );
        showSuccess('Refund marked as completed');
      }

      if (decisionType === 'reject') {
        await updateDoc(doc(db, 'refunds', selectedRefund.id), {
          status: 'rejected',
          rejectionReason: decisionNote,
          rejectedAt: serverTimestamp(),
          rejectedBy: user?.uid || null,
          updatedAt: serverTimestamp(),
        });

        if (selectedRefund.transactionId) {
          await updateDoc(doc(db, 'transactions', selectedRefund.transactionId), {
            status: 'completed',
            refundRejectedAt: serverTimestamp(),
            refundRejectedBy: user?.uid || null,
            refundRejectedReason: decisionNote,
          });
        }

        await writeAuditLog('reject_refund', selectedRefund, {
          reason: decisionNote,
        });
        await notifyClient(
          selectedRefund,
          'Refund rejected',
          `Your refund request was rejected. Reason: ${decisionNote}`
        );
        showSuccess('Refund rejected');
      }

      closeDecision();
      setDetailsOpen(false);
      setSelectedRefund(null);
    } catch (error) {
      console.error('Error updating refund:', error);
      showError('Error: ' + error.message);
    } finally {
      setSubmitting(false);
    }
  };

  const columns = [
    {
      key: 'refundId',
      label: 'Refund',
      render: (value, row) => (
        <Box>
          <Typography variant="body2" sx={{ fontWeight: 700 }}>
            {(value || row.id).substring(0, 18)}
          </Typography>
          <Typography variant="caption" color="textSecondary">
            Tx: {row.transactionId || row.paystackReference || '-'}
          </Typography>
        </Box>
      ),
    },
    {
      key: 'clientId',
      label: 'Client',
      render: (value) => value || '-',
    },
    {
      key: 'amount',
      label: 'Amount',
      render: (value) => formatCurrency(Number(value || 0)),
    },
    {
      key: 'status',
      label: 'Status',
      render: (value) => <StatusBadge status={value || 'pending'} variant="soft" size="small" />,
    },
    {
      key: 'reason',
      label: 'Reason',
      render: (value) => (
        <Typography variant="body2" sx={{ maxWidth: 320 }}>
          {value || '-'}
        </Typography>
      ),
    },
    {
      key: 'createdAt',
      label: 'Created',
      render: (value) => formatDateTime(value),
    },
  ];

  if (!canManageRefunds) {
    return (
      <Card>
        <CardContent>
          <Typography color="error">
            You do not have permission to manage refunds.
          </Typography>
        </CardContent>
      </Card>
    );
  }

  return (
    <Box>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h3" sx={{ fontWeight: 700, color: COLORS.gray900 }}>
          Refund Management
        </Typography>
        <Typography variant="body2" sx={{ color: COLORS.gray600 }}>
          Review refund requests, retry failed refunds, and record manual outcomes.
        </Typography>
      </Box>

      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Refunds"
            value={stats.total}
            icon={PendingIcon}
            loading={loading}
            color={COLORS.info}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Active Amount"
            value={formatCurrency(stats.activeAmount)}
            subtitle={`${stats.activeCount} active requests`}
            icon={PendingIcon}
            loading={loading}
            color={COLORS.pending}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Completed Amount"
            value={formatCurrency(stats.completedAmount)}
            icon={CheckCircleIcon}
            loading={loading}
            color={COLORS.success}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Failed / Rejected"
            value={`${stats.failedCount} / ${stats.rejectedCount}`}
            icon={ErrorIcon}
            loading={loading}
            color={COLORS.error}
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
            sx={{ minWidth: 220 }}
          >
            <MenuItem value="all">All Statuses</MenuItem>
            <MenuItem value="active">Pending / Processing</MenuItem>
            <MenuItem value="pending">Pending</MenuItem>
            <MenuItem value="processing">Processing</MenuItem>
            <MenuItem value="completed">Completed</MenuItem>
            <MenuItem value="failed">Failed</MenuItem>
            <MenuItem value="rejected">Rejected</MenuItem>
          </TextField>
        </CardContent>
      </Card>

      <Card>
        <CardContent>
          <DataTable
            columns={columns}
            data={filteredRefunds}
            loading={loading}
            onRowClick={(refund) => {
              setSelectedRefund(refund);
              setDetailsOpen(true);
            }}
            emptyMessage="No refund records found"
          />
        </CardContent>
      </Card>

      <Dialog
        open={detailsOpen}
        onClose={() => setDetailsOpen(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>Refund Details</DialogTitle>
        <DialogContent>
          {selectedRefund && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
              <Box>
                <Typography variant="body2" color="textSecondary">Refund ID</Typography>
                <Typography variant="body1">{selectedRefund.refundId || selectedRefund.id}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">Transaction</Typography>
                <Typography variant="body1">
                  {selectedRefund.transactionId || selectedRefund.paystackReference || '-'}
                </Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">Amount</Typography>
                <Typography variant="h6">{formatCurrency(getRefundAmount(selectedRefund))}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">Status</Typography>
                <StatusBadge status={selectedRefund.status || 'pending'} variant="soft" />
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">Reason</Typography>
                <Typography variant="body2">{selectedRefund.reason || '-'}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">Created</Typography>
                <Typography variant="body2">{formatDateTime(selectedRefund.createdAt)}</Typography>
              </Box>
              {selectedRefund.refundReference && (
                <Box>
                  <Typography variant="body2" color="textSecondary">Refund Reference</Typography>
                  <Typography variant="body2">{selectedRefund.refundReference}</Typography>
                </Box>
              )}
              {selectedRefund.failureReason && (
                <Alert severity="error">
                  <strong>Failure:</strong> {selectedRefund.failureReason}
                </Alert>
              )}
              {selectedRefund.rejectionReason && (
                <Alert severity="warning">
                  <strong>Rejected:</strong> {selectedRefund.rejectionReason}
                </Alert>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          {selectedRefund?.status === 'failed' && (
            <Button
              startIcon={<RetryIcon />}
              onClick={() => handleRetryRefund(selectedRefund)}
              disabled={submitting}
            >
              Retry
            </Button>
          )}
          {selectedRefund && activeRefundStatuses.includes(selectedRefund.status) && (
            <>
              <Button
                color="error"
                onClick={() => openDecision(selectedRefund, 'reject')}
                disabled={submitting}
              >
                Reject
              </Button>
              <Button
                color="success"
                variant="contained"
                onClick={() => openDecision(selectedRefund, 'complete')}
                disabled={submitting}
              >
                Mark Complete
              </Button>
            </>
          )}
          <Button onClick={() => setDetailsOpen(false)}>Close</Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={decisionOpen}
        onClose={closeDecision}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>
          {decisionType === 'complete' ? 'Complete Refund' : 'Reject Refund'}
        </DialogTitle>
        <DialogContent>
          <Alert severity={decisionType === 'complete' ? 'warning' : 'info'} sx={{ mb: 2 }}>
            {decisionType === 'complete'
              ? 'Use this only after confirming the refund was processed outside the dashboard.'
              : 'Rejecting will return the linked transaction to completed status when a transaction id is available.'}
          </Alert>
          <Divider sx={{ mb: 2 }} />
          <TextField
            fullWidth
            multiline
            rows={4}
            label="Admin note"
            value={decisionNote}
            onChange={(event) => setDecisionNote(event.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={closeDecision}>Cancel</Button>
          <Button
            variant="contained"
            color={decisionType === 'complete' ? 'success' : 'error'}
            onClick={handleDecision}
            disabled={submitting || !decisionNote.trim()}
          >
            {submitting ? <CircularProgress size={20} /> : 'Confirm'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
