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
} from '@mui/material';
import { db } from '../lib/firebase';
import { collection, getDocs, updateDoc, doc, query, where } from 'firebase/firestore';
import { DataTable } from '../components/DataTable';
import { StatCard } from '../components/StatCard';
import { formatDate, formatCurrency, getStatusColor, getStatusIcon } from '../lib/utils';
import { Payment as PaymentIcon } from '@mui/icons-material';

export default function PaymentsPage() {
  const [payments, setPayments] = useState([]);
  const [filteredPayments, setFilteredPayments] = useState([]);
  const [stats, setStats] = useState({ total: 0, pending: 0, completed: 0, failed: 0 });
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedPayment, setSelectedPayment] = useState(null);
  const [openDetail, setOpenDetail] = useState(false);
  const [openAction, setOpenAction] = useState(false);
  const [actionType, setActionType] = useState('');

  useEffect(() => {
    const fetchPayments = async () => {
      try {
        const paymentsSnapshot = await getDocs(collection(db, 'payments'));
        const paymentsList = paymentsSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        const totalAmount = paymentsList.reduce((sum, p) => sum + (p.amount || 0), 0);
        const pending = paymentsList.filter((p) => p.status === 'pending').length;
        const completed = paymentsList.filter((p) => p.status === 'completed').length;
        const failed = paymentsList.filter((p) => p.status === 'failed').length;

        setPayments(paymentsList);
        setStats({
          total: totalAmount,
          pending,
          completed,
          failed,
        });
      } catch (error) {
        console.error('Error fetching payments:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchPayments();
  }, []);

  useEffect(() => {
    let filtered = payments;

    if (statusFilter !== 'all') {
      filtered = filtered.filter((p) => p.status === statusFilter);
    }

    setFilteredPayments(filtered);
  }, [payments, statusFilter]);

  const handleViewDetails = (payment) => {
    setSelectedPayment(payment);
    setOpenDetail(true);
  };

  const handleAction = async () => {
    if (!selectedPayment || !actionType) return;

    try {
      const paymentRef = doc(db, 'payments', selectedPayment.id);
      const updateData = { status: actionType, processedAt: new Date() };

      await updateDoc(paymentRef, updateData);
      setPayments(
        payments.map((p) => (p.id === selectedPayment.id ? { ...p, ...updateData } : p))
      );

      setOpenAction(false);
      setOpenDetail(false);
      setSelectedPayment(null);
      alert('Payment updated successfully');
    } catch (error) {
      console.error('Error updating payment:', error);
      alert('Error: ' + error.message);
    }
  };

  const columns = [
    {
      key: 'id',
      label: 'Transaction ID',
      render: (value) => value.substring(0, 8) + '...',
    },
    {
      key: 'amount',
      label: 'Amount',
      render: (value) => formatCurrency(value),
    },
    {
      key: 'type',
      label: 'Type',
      render: (value) => (
        <Chip
          label={value || 'bid'}
          size="small"
          color={value === 'bid' ? 'primary' : 'secondary'}
        />
      ),
    },
    {
      key: 'status',
      label: 'Status',
      render: (value) => (
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <span>{getStatusIcon(value)}</span>
          <Chip
            label={value}
            size="small"
            sx={{
              backgroundColor: getStatusColor(value) + '20',
              color: getStatusColor(value),
            }}
          />
        </Box>
      ),
    },
    {
      key: 'createdAt',
      label: 'Date',
      render: (value) => formatDate(value),
    },
  ];

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 'bold', mb: 3 }}>
        Payment Management
      </Typography>

      {/* Stats */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Revenue"
            value={formatCurrency(stats.total)}
            icon={PaymentIcon}
            loading={loading}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Pending"
            value={stats.pending}
            icon={PaymentIcon}
            loading={loading}
            color="#FF9800"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Completed"
            value={stats.completed}
            icon={PaymentIcon}
            loading={loading}
            color="#4CAF50"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Failed"
            value={stats.failed}
            icon={PaymentIcon}
            loading={loading}
            color="#F44336"
          />
        </Grid>
      </Grid>

      {/* Filters */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <TextField
            select
            fullWidth
            size="small"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            sx={{ maxWidth: 300 }}
          >
            <MenuItem value="all">All Status</MenuItem>
            <MenuItem value="pending">Pending</MenuItem>
            <MenuItem value="completed">Completed</MenuItem>
            <MenuItem value="failed">Failed</MenuItem>
            <MenuItem value="refunded">Refunded</MenuItem>
          </TextField>
        </CardContent>
      </Card>

      {/* Payments Table */}
      <Card>
        <CardContent>
          <DataTable
            columns={columns}
            data={filteredPayments}
            loading={loading}
            onRowClick={handleViewDetails}
            emptyMessage="No payments found"
          />
        </CardContent>
      </Card>

      {/* Payment Detail Dialog */}
      <Dialog open={openDetail} onClose={() => setOpenDetail(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Payment Details</DialogTitle>
        <DialogContent>
          {selectedPayment && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 2 }}>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Transaction ID
                </Typography>
                <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                  {selectedPayment.id}
                </Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Amount
                </Typography>
                <Typography variant="h6">{formatCurrency(selectedPayment.amount)}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Type
                </Typography>
                <Chip label={selectedPayment.type || 'bid'} size="small" />
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Status
                </Typography>
                <Chip
                  label={selectedPayment.status}
                  sx={{
                    backgroundColor: getStatusColor(selectedPayment.status) + '20',
                    color: getStatusColor(selectedPayment.status),
                  }}
                />
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Created
                </Typography>
                <Typography variant="body2">{formatDate(selectedPayment.createdAt)}</Typography>
              </Box>
              {selectedPayment.notes && (
                <Box>
                  <Typography variant="body2" color="textSecondary">
                    Notes
                  </Typography>
                  <Typography variant="body2">{selectedPayment.notes}</Typography>
                </Box>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          {selectedPayment?.status === 'pending' && (
            <>
              <Button
                onClick={() => {
                  setActionType('completed');
                  setOpenAction(true);
                }}
                variant="contained"
                color="success"
              >
                Complete
              </Button>
              <Button
                onClick={() => {
                  setActionType('failed');
                  setOpenAction(true);
                }}
                color="error"
              >
                Mark Failed
              </Button>
            </>
          )}
          {selectedPayment?.status === 'completed' && (
            <Button
              onClick={() => {
                setActionType('refunded');
                setOpenAction(true);
              }}
              color="warning"
            >
              Refund
            </Button>
          )}
          <Button onClick={() => setOpenDetail(false)}>Close</Button>
        </DialogActions>
      </Dialog>

      {/* Action Dialog */}
      <Dialog open={openAction} onClose={() => setOpenAction(false)} maxWidth="xs" fullWidth>
        <DialogTitle>Confirm Action</DialogTitle>
        <DialogContent>
          <Typography>
            Are you sure you want to mark this payment as {actionType}?
          </Typography>
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
