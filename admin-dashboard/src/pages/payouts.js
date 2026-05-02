import React, { useState, useEffect } from 'react';
import {
  Container,
  Box,
  Paper,
  Grid,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Select,
  MenuItem,
  Chip,
  CircularProgress,
  Alert,
  LinearProgress,
} from '@mui/material';
import {
  LocalAtm as LocalAtmIcon,
  Check as CheckIcon,
  Pending as PendingIcon,
  Error as ErrorIcon,
} from '@mui/icons-material';
import { collection, onSnapshot, query, orderBy, limit, doc, getDoc } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { useAdmin } from '../context/AdminContext';
import Layout from '../components/Layout';
import StatCard from '../components/StatCard';
import { showSuccess, showError } from '../lib/toast';

const statusColors = {
  pending: '#ff9800',
  processing: '#2196f3',
  completed: '#4caf50',
  failed: '#f44336',
};

const statusIcons = {
  pending: <PendingIcon />,
  processing: <CircularProgress size={20} />,
  completed: <CheckIcon />,
  failed: <ErrorIcon />,
};

export default function PayoutsPage() {
  const { user, adminRole, hasPermission } = useAdmin();
  const [payoutBatches, setPayoutBatches] = useState([]);
  const [selectedBatch, setSelectedBatch] = useState(null);
  const [batchDetails, setBatchDetails] = useState(null);
  const [loading, setLoading] = useState(true);
  const [openDetails, setOpenDetails] = useState(false);
  const [stats, setStats] = useState({
    totalPayouts: 0,
    pendingAmount: 0,
    completedAmount: 0,
    averagePayout: 0,
  });

  const firebaseFunctions = require('firebase/functions');
  const { getFunctions, httpsCallable } = firebaseFunctions;
  const functions = getFunctions();

  // Set up real-time listener for payout batches
  useEffect(() => {
    const q = query(
      collection(db, 'payoutBatches'),
      orderBy('createdAt', 'desc'),
      limit(50)
    );

    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const batches = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
          createdAt: doc.data().createdAt?.toDate?.() || new Date(),
        }));

        setPayoutBatches(batches);

        // Calculate stats
        const pending = batches.filter((b) => b.status === 'pending');
        const completed = batches.filter((b) => b.status === 'completed');

        const pendingAmount = pending.reduce((sum, b) => sum + (b.totalAmount || 0), 0);
        const completedAmount = completed.reduce((sum, b) => sum + (b.totalAmount || 0), 0);

        setStats({
          totalPayouts: batches.length,
          pendingAmount,
          completedAmount,
          averagePayout: batches.length > 0 ?
            batches.reduce((sum, b) => sum + (b.totalAmount || 0), 0) / batches.length : 0,
        });
        setLoading(false);
      },
      (error) => {
        console.error('Error fetching payout batches:', error);
        setLoading(false);
      }
    );

    // Cleanup subscription on unmount
    return () => unsubscribe();
  }, []);

  const fetchBatchDetails = async (batchId) => {
    try {
      const getPayoutBatchDetails = httpsCallable(
        functions,
        'getPayoutBatchDetails'
      );

      const result = await getPayoutBatchDetails({ batchId });
      setBatchDetails(result.data);
      setSelectedBatch(batchId);
      setOpenDetails(true);
    } catch (error) {
      console.error('Error fetching batch details:', error);
      showError('Failed to fetch batch details');
    }
  };

  const approveBatch = async (batchId) => {
    if (!window.confirm('Approve this payout batch?')) return;

    try {
      const approvPayoutBatch = httpsCallable(
        functions,
        'approvPayoutBatch'
      );

      await approvPayoutBatch({ batchId });
      showSuccess('Batch approved!');
      setOpenDetails(false);
    } catch (error) {
      console.error('Error approving batch:', error);
      showError('Failed to approve batch');
    }
  };

  const completePayout = async (payoutId, batchId) => {
    const reference = window.prompt('Enter M-Pesa/Bank reference:');
    if (!reference) return;

    try {
      const completPayoutFn = httpsCallable(
        functions,
        'completePayout'
      );

      await completPayoutFn({
        payoutId,
        batchId,
        reference,
        method: 'mpesa',
      });

      alert('✅ Payout completed!');
      fetchBatchDetails(batchId);
      fetchPayoutBatches();
    } catch (error) {
      console.error('Error completing payout:', error);
      alert('Failed to complete payout');
    }
  };

  if (!hasPermission('canApprovePayouts')) {
    return (
      <Layout>
        <Container maxWidth="lg" sx={{ py: 4 }}>
          <Alert severity="warning">
            You don't have permission to view payouts. Contact admin.
          </Alert>
        </Container>
      </Layout>
    );
  }

  return (
    <Layout>
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Box sx={{ mb: 4 }}>
          <h1>💰 Payout Management</h1>
          <p>Manage and track automated caregiver payouts</p>
        </Box>

        {/* Stats Cards */}
        <Grid container spacing={3} sx={{ mb: 4 }}>
          <Grid item xs={12} sm={6} md={3}>
            <StatCard
              title="Pending Payouts"
              value={`KES ${stats.pendingAmount.toLocaleString()}`}
              icon={PendingIcon}
              color="#ff9800"
              loading={loading}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <StatCard
              title="Completed"
              value={`KES ${stats.completedAmount.toLocaleString()}`}
              icon={CheckIcon}
              color="#4caf50"
              loading={loading}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <StatCard
              title="Total Batches"
              value={stats.totalPayouts}
              icon={LocalAtmIcon}
              color="#2196f3"
              loading={loading}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <StatCard
              title="Average Payout"
              value={`KES ${stats.averagePayout.toLocaleString()}`}
              icon={LocalAtmIcon}
              color="#673ab7"
              loading={loading}
            />
          </Grid>
        </Grid>

        {/* Payout Batches Table */}
        <Paper>
          <TableContainer>
            <Table>
              <TableHead sx={{ backgroundColor: '#f5f5f5' }}>
                <TableRow>
                  <TableCell><strong>Batch ID</strong></TableCell>
                  <TableCell align="right"><strong>Amount (KES)</strong></TableCell>
                  <TableCell align="center"><strong>Payouts</strong></TableCell>
                  <TableCell align="center"><strong>Status</strong></TableCell>
                  <TableCell><strong>Created</strong></TableCell>
                  <TableCell align="center"><strong>Actions</strong></TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {loading ? (
                  <TableRow>
                    <TableCell colSpan={6} align="center">
                      <CircularProgress />
                    </TableCell>
                  </TableRow>
                ) : payoutBatches.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} align="center">
                      No payout batches found
                    </TableCell>
                  </TableRow>
                ) : (
                  payoutBatches.map((batch) => (
                    <TableRow
                      key={batch.id}
                      hover
                      sx={{ '&:hover': { backgroundColor: '#f9f9f9' } }}
                    >
                      <TableCell>
                        <code style={{ fontSize: '0.85em' }}>{batch.batchId}</code>
                      </TableCell>
                      <TableCell align="right">
                        <strong>{batch.totalAmount.toLocaleString()}</strong>
                      </TableCell>
                      <TableCell align="center">{batch.totalPayouts}</TableCell>
                      <TableCell align="center">
                        <Chip
                          icon={statusIcons[batch.status]}
                          label={batch.status.toUpperCase()}
                          size="small"
                          sx={{
                            backgroundColor: statusColors[batch.status],
                            color: 'white',
                          }}
                        />
                      </TableCell>
                      <TableCell>
                        {batch.createdAt.toLocaleDateString()} {batch.createdAt.toLocaleTimeString()}
                      </TableCell>
                      <TableCell align="center">
                        <Button
                          size="small"
                          variant="outlined"
                          onClick={() => fetchBatchDetails(batch.id)}
                        >
                          View
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </Paper>

        {/* Batch Details Dialog */}
        <Dialog open={openDetails} onClose={() => setOpenDetails(false)} maxWidth="md" fullWidth>
          <DialogTitle>
            Payout Batch Details: {selectedBatch}
          </DialogTitle>
          <DialogContent sx={{ pt: 2 }}>
            {batchDetails && (
              <>
                <Box sx={{ mb: 3 }}>
                  <strong>Status:</strong> {batchDetails.batch.status}
                  <LinearProgress
                    variant="determinate"
                    value={
                      batchDetails.batch.status === 'completed' ? 100 :
                      batchDetails.batch.status === 'processing' ? 50 : 25
                    }
                    sx={{ mt: 1 }}
                  />
                </Box>

                <h4>Individual Payouts</h4>
                <TableContainer component={Paper}>
                  <Table size="small">
                    <TableHead>
                      <TableRow sx={{ backgroundColor: '#f5f5f5' }}>
                        <TableCell><strong>Caregiver ID</strong></TableCell>
                        <TableCell align="right"><strong>Amount (KES)</strong></TableCell>
                        <TableCell align="center"><strong>Status</strong></TableCell>
                        <TableCell><strong>Transactions</strong></TableCell>
                        <TableCell align="center"><strong>Action</strong></TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {batchDetails.payouts.map((payout) => (
                        <TableRow key={payout.id}>
                          <TableCell>
                            <code>{payout.caregiverId.substring(0, 12)}...</code>
                          </TableCell>
                          <TableCell align="right">
                            {payout.netAmount.toLocaleString()}
                          </TableCell>
                          <TableCell align="center">
                            <Chip
                              size="small"
                              label={payout.status.toUpperCase()}
                              sx={{
                                backgroundColor: statusColors[payout.status],
                                color: 'white',
                              }}
                            />
                          </TableCell>
                          <TableCell>{payout.transactionCount}</TableCell>
                          <TableCell align="center">
                            {payout.status === 'processing' && (
                              <Button
                                size="small"
                                variant="contained"
                                color="success"
                                onClick={() => completePayout(payout.id, selectedBatch)}
                              >
                                Complete
                              </Button>
                            )}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              </>
            )}
          </DialogContent>
          <DialogActions>
            {batchDetails && batchDetails.batch.status === 'pending' && (
              <Button
                variant="contained"
                color="primary"
                onClick={() => approveBatch(selectedBatch)}
              >
                Approve Batch
              </Button>
            )}
            <Button onClick={() => setOpenDetails(false)}>Close</Button>
          </DialogActions>
        </Dialog>
      </Container>
    </Layout>
  );
}
