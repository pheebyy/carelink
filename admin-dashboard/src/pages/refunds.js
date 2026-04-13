import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Grid,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Chip,
  CircularProgress,
  Alert,
  Pagination,
  TablePagination,
} from '@mui/material';
import { collection, query, where, orderBy, getDocs, limit, startAfter } from 'firebase/firestore';
import { db, functions } from '../lib/firebase';
import { httpsCallable } from 'firebase/functions';
import StatCard from '../components/StatCard';
import { useState as useStateCallback } from 'react';

const RefundsPage = () => {
  const [refunds, setRefunds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [stats, setStats] = useState({
    totalRefunds: 0,
    pendingAmount: 0,
    completedAmount: 0,
    failedCount: 0,
  });
  const [statusFilter, setStatusFilter] = useState('');
  const [selectedRefund, setSelectedRefund] = useState(null);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [retryLoading, setRetryLoading] = useState(false);
  const [manualApprovalOpen, setManualApprovalOpen] = useState(false);
  const [approvalNote, setApprovalNote] = useState('');

  // Fetch refunds
  const fetchRefunds = async () => {
    try {
      setLoading(true);
      const listRefunds = httpsCallable(functions, 'listRefunds');
      const result = await listRefunds({ 
        status: statusFilter || undefined,
        limit: rowsPerPage,
      });

      setRefunds(result.data.refunds);

      // Calculate stats
      const pendingRefunds = result.data.refunds.filter(r => r.status === 'pending' || r.status === 'processing');
      const completedRefunds = result.data.refunds.filter(r => r.status === 'completed');
      const failedRefunds = result.data.refunds.filter(r => r.status === 'failed');

      setStats({
        totalRefunds: result.data.refunds.length,
        pendingAmount: pendingRefunds.reduce((sum, r) => sum + r.amount, 0),
        completedAmount: completedRefunds.reduce((sum, r) => sum + r.amount, 0),
        failedCount: failedRefunds.length,
      });

      setError(null);
    } catch (err) {
      console.error('Error fetching refunds:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchRefunds();
  }, [statusFilter, page, rowsPerPage]);

  const handleStatusFilter = (status) => {
    setStatusFilter(status);
    setPage(0);
  };

  const handleViewDetails = (refund) => {
    setSelectedRefund(refund);
    setDetailsOpen(true);
  };

  const handleRetryRefund = async () => {
    if (!selectedRefund) return;

    try {
      setRetryLoading(true);
      const retryFailedRefund = httpsCallable(functions, 'retryFailedRefund');
      await retryFailedRefund({ refundId: selectedRefund.id });

      alert('Refund retry initiated successfully');
      setDetailsOpen(false);
      fetchRefunds();
    } catch (err) {
      alert(`Error: ${err.message}`);
    } finally {
      setRetryLoading(false);
    }
  };

  const handleManualApproval = async () => {
    if (!selectedRefund) return;

    try {
      setRetryLoading(true);
      const manualRefundApproval = httpsCallable(functions, 'manualRefundApproval');
      await manualRefundApproval({
        refundId: selectedRefund.id,
        approvalNote: approvalNote,
      });

      alert('Refund manually approved successfully');
      setManualApprovalOpen(false);
      setApprovalNote('');
      setDetailsOpen(false);
      fetchRefunds();
    } catch (err) {
      alert(`Error: ${err.message}`);
    } finally {
      setRetryLoading(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'pending':
        return 'warning';
      case 'processing':
        return 'info';
      case 'completed':
        return 'success';
      case 'failed':
        return 'error';
      default:
        return 'default';
    }
  };

  return (
    <Box sx={{ p: 3 }}>
      <h1>💰 Refund Management</h1>

      {/* Stats Cards */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Refunds"
            value={stats.totalRefunds}
            color="#3f51b5"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Pending Amount"
            value={`KES ${stats.pendingAmount.toLocaleString()}`}
            color="#ff9800"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Completed Amount"
            value={`KES ${stats.completedAmount.toLocaleString()}`}
            color="#4caf50"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Failed Refunds"
            value={stats.failedCount}
            color="#f44336"
          />
        </Grid>
      </Grid>

      {/* Filter Buttons */}
      <Box sx={{ mb: 3, display: 'flex', gap: 1, flexWrap: 'wrap' }}>
        <Button
          variant={statusFilter === '' ? 'contained' : 'outlined'}
          onClick={() => handleStatusFilter('')}
        >
          All
        </Button>
        <Button
          variant={statusFilter === 'pending' ? 'contained' : 'outlined'}
          onClick={() => handleStatusFilter('pending')}
        >
          Pending
        </Button>
        <Button
          variant={statusFilter === 'processing' ? 'contained' : 'outlined'}
          onClick={() => handleStatusFilter('processing')}
        >
          Processing
        </Button>
        <Button
          variant={statusFilter === 'completed' ? 'contained' : 'outlined'}
          onClick={() => handleStatusFilter('completed')}
        >
          Completed
        </Button>
        <Button
          variant={statusFilter === 'failed' ? 'contained' : 'outlined'}
          onClick={() => handleStatusFilter('failed')}
        >
          Failed
        </Button>
      </Box>

      {error && <Alert severity="error">{error}</Alert>}

      {/* Refunds Table */}
      <TableContainer component={Paper}>
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 3 }}>
            <CircularProgress />
          </Box>
        ) : (
          <>
            <Table>
              <TableHead sx={{ backgroundColor: '#f5f5f5' }}>
                <TableRow>
                  <TableCell><strong>Refund ID</strong></TableCell>
                  <TableCell><strong>Job ID</strong></TableCell>
                  <TableCell align="right"><strong>Amount (KES)</strong></TableCell>
                  <TableCell><strong>Status</strong></TableCell>
                  <TableCell><strong>Reason</strong></TableCell>
                  <TableCell><strong>Created</strong></TableCell>
                  <TableCell align="center"><strong>Action</strong></TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {refunds.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7} align="center" sx={{ py: 3 }}>
                      No refunds found
                    </TableCell>
                  </TableRow>
                ) : (
                  refunds.map((refund) => (
                    <TableRow key={refund.id} hover>
                      <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                        {refund.refundId?.substring(0, 15)}...
                      </TableCell>
                      <TableCell>{refund.jobId?.substring(0, 12)}...</TableCell>
                      <TableCell align="right">
                        {refund.amount.toLocaleString()}
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={refund.status.toUpperCase()}
                          color={getStatusColor(refund.status)}
                          size="small"
                        />
                      </TableCell>
                      <TableCell>{refund.reason}</TableCell>
                      <TableCell>
                        {refund.createdAt?.toDate?.()?.toLocaleDateString() ||
                          new Date(refund.createdAt).toLocaleDateString()}
                      </TableCell>
                      <TableCell align="center">
                        <Button
                          size="small"
                          variant="outlined"
                          onClick={() => handleViewDetails(refund)}
                        >
                          View
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
            <TablePagination
              rowsPerPageOptions={[5, 10, 25, 50]}
              component="div"
              count={refunds.length}
              rowsPerPage={rowsPerPage}
              page={page}
              onPageChange={(e, newPage) => setPage(newPage)}
              onRowsPerPageChange={(e) => setRowsPerPage(parseInt(e.target.value, 10))}
            />
          </>
        )}
      </TableContainer>

      {/* Details Dialog */}
      <Dialog open={detailsOpen} onClose={() => setDetailsOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Refund Details</DialogTitle>
        <DialogContent>
          {selectedRefund && (
            <Box sx={{ mt: 2, display: 'flex', flexDirection: 'column', gap: 2 }}>
              <Box>
                <strong>Refund ID:</strong> {selectedRefund.refundId}
              </Box>
              <Box>
                <strong>Job ID:</strong> {selectedRefund.jobId}
              </Box>
              <Box>
                <strong>Amount:</strong> KES {selectedRefund.amount.toLocaleString()}
              </Box>
              <Box>
                <strong>Status:</strong>{' '}
                <Chip
                  label={selectedRefund.status.toUpperCase()}
                  color={getStatusColor(selectedRefund.status)}
                  size="small"
                />
              </Box>
              <Box>
                <strong>Reason:</strong> {selectedRefund.reason}
              </Box>
              <Box>
                <strong>Paystack Reference:</strong> {selectedRefund.paystackReference}
              </Box>
              {selectedRefund.refundReference && (
                <Box>
                  <strong>Refund Reference:</strong> {selectedRefund.refundReference}
                </Box>
              )}
              <Box>
                <strong>Created:</strong>{' '}
                {selectedRefund.createdAt?.toDate?.()?.toLocaleString() ||
                  new Date(selectedRefund.createdAt).toLocaleString()}
              </Box>
              {selectedRefund.failureReason && (
                <Alert severity="error">
                  <strong>Failure Reason:</strong> {selectedRefund.failureReason}
                </Alert>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          {selectedRefund?.status === 'failed' && selectedRefund?.attempts < selectedRefund?.maxAttempts && (
            <Button
              onClick={handleRetryRefund}
              color="warning"
              disabled={retryLoading}
            >
              {retryLoading ? <CircularProgress size={20} /> : 'Retry'}
            </Button>
          )}
          
          {selectedRefund?.status === 'failed' && (
            <Button
              onClick={() => setManualApprovalOpen(true)}
              color="success"
            >
              Manual Approval
            </Button>
          )}

          <Button onClick={() => setDetailsOpen(false)}>Close</Button>
        </DialogActions>
      </Dialog>

      {/* Manual Approval Dialog */}
      <Dialog open={manualApprovalOpen} onClose={() => setManualApprovalOpen(false)} fullWidth>
        <DialogTitle>Manually Approve Refund</DialogTitle>
        <DialogContent>
          <Box sx={{ mt: 2 }}>
            <Alert severity="warning" sx={{ mb: 2 }}>
              ⚠️ This will mark the refund as completed without verifying Paystack payment.
              Only use if you've manually processed the refund.
            </Alert>
            <TextField
              fullWidth
              label="Approval Note"
              placeholder="e.g., Manual bank transfer confirmed"
              value={approvalNote}
              onChange={(e) => setApprovalNote(e.target.value)}
              multiline
              rows={3}
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setManualApprovalOpen(false)}>Cancel</Button>
          <Button
            onClick={handleManualApproval}
            color="success"
            variant="contained"
            disabled={retryLoading || !approvalNote.trim()}
          >
            {retryLoading ? <CircularProgress size={20} /> : 'Approve'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default RefundsPage;
