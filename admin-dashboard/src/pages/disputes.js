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
  Alert,
} from '@mui/material';
import { db } from '../lib/firebase';
import { collection, getDocs, updateDoc, doc } from 'firebase/firestore';
import { DataTable } from '../components/DataTable';
import { formatDate, getStatusColor, getStatusIcon } from '../lib/utils';

export default function DisputesPage() {
  const [disputes, setDisputes] = useState([]);
  const [filteredDisputes, setFilteredDisputes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedDispute, setSelectedDispute] = useState(null);
  const [openDetail, setOpenDetail] = useState(false);
  const [openResolution, setOpenResolution] = useState(false);
  const [resolution, setResolution] = useState('');
  const [resolutionNotes, setResolutionNotes] = useState('');

  useEffect(() => {
    const fetchDisputes = async () => {
      try {
        const disputesSnapshot = await getDocs(collection(db, 'disputes'));
        const disputesList = disputesSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
        setDisputes(disputesList);
      } catch (error) {
        console.error('Error fetching disputes:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchDisputes();
  }, []);

  useEffect(() => {
    let filtered = disputes;

    if (statusFilter !== 'all') {
      filtered = filtered.filter((d) => d.status === statusFilter);
    }

    setFilteredDisputes(filtered);
  }, [disputes, statusFilter]);

  const handleViewDetails = (dispute) => {
    setSelectedDispute(dispute);
    setOpenDetail(true);
  };

  const handleResolveDispute = async () => {
    if (!selectedDispute || !resolution) return;

    try {
      const disputeRef = doc(db, 'disputes', selectedDispute.id);
      const updateData = {
        status: 'resolved',
        resolution,
        resolutionNotes,
        resolvedAt: new Date(),
        resolvedBy: 'admin',
      };

      await updateDoc(disputeRef, updateData);
      setDisputes(
        disputes.map((d) => (d.id === selectedDispute.id ? { ...d, ...updateData } : d))
      );

      setOpenResolution(false);
      setOpenDetail(false);
      setSelectedDispute(null);
      setResolution('');
      setResolutionNotes('');
      alert('Dispute resolved successfully');
    } catch (error) {
      console.error('Error resolving dispute:', error);
      alert('Error: ' + error.message);
    }
  };

  const columns = [
    {
      key: 'id',
      label: 'Case ID',
      render: (value) => `CASE-${value.substring(0, 4).toUpperCase()}`,
    },
    {
      key: 'type',
      label: 'Type',
      render: (value) => (
        <Chip
          label={value || 'payment'}
          size="small"
          color={value === 'payment' ? 'error' : 'warning'}
        />
      ),
    },
    {
      key: 'amount',
      label: 'Amount',
      render: (value) => (value ? `KES ${value}` : '-'),
    },
    {
      key: 'status',
      label: 'Status',
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
      label: 'Created',
      render: (value) => formatDate(value),
    },
  ];

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 'bold', mb: 3 }}>
        Dispute Resolution
      </Typography>

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
            <MenuItem value="resolved">Resolved</MenuItem>
            <MenuItem value="escalated">Escalated</MenuItem>
          </TextField>
        </CardContent>
      </Card>

      {/* Disputes Table */}
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

      {/* Dispute Detail Dialog */}
      <Dialog open={openDetail} onClose={() => setOpenDetail(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Dispute Details</DialogTitle>
        <DialogContent>
          {selectedDispute && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 2 }}>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Case ID
                </Typography>
                <Typography variant="body1">
                  CASE-{selectedDispute.id.substring(0, 4).toUpperCase()}
                </Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Type
                </Typography>
                <Chip label={selectedDispute.type || 'payment'} size="small" />
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Raised By
                </Typography>
                <Typography variant="body2">{selectedDispute.raisedBy || 'Unknown'}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Raised Against
                </Typography>
                <Typography variant="body2">{selectedDispute.raisedAgainst || 'Unknown'}</Typography>
              </Box>
              {selectedDispute.amount && (
                <Box>
                  <Typography variant="body2" color="textSecondary">
                    Amount in Dispute
                  </Typography>
                  <Typography variant="h6">KES {selectedDispute.amount}</Typography>
                </Box>
              )}
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Description
                </Typography>
                <Typography variant="body2">{selectedDispute.description}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Status
                </Typography>
                <Chip label={selectedDispute.status} size="small" />
              </Box>
              {selectedDispute.resolution && (
                <Box sx={{ p: 1.5, backgroundColor: '#e8f5e9', borderRadius: 1 }}>
                  <Typography variant="body2" sx={{ fontWeight: 'bold', color: '#2e7d32' }}>
                    ✅ Resolution: {selectedDispute.resolution}
                  </Typography>
                  <Typography variant="caption" sx={{ color: '#2e7d32', mt: 0.5, display: 'block' }}>
                    {selectedDispute.resolutionNotes}
                  </Typography>
                </Box>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          {selectedDispute?.status === 'pending' && (
            <Button
              onClick={() => setOpenResolution(true)}
              variant="contained"
              color="primary"
            >
              Resolve
            </Button>
          )}
          <Button onClick={() => setOpenDetail(false)}>Close</Button>
        </DialogActions>
      </Dialog>

      {/* Resolution Dialog */}
      <Dialog open={openResolution} onClose={() => setOpenResolution(false)} maxWidth="xs" fullWidth>
        <DialogTitle>Resolve Dispute</DialogTitle>
        <DialogContent>
          <Alert severity="info" sx={{ mb: 2 }}>
            Amount in dispute: KES {selectedDispute?.amount}
          </Alert>

          <TextField
            select
            fullWidth
            label="Resolution"
            value={resolution}
            onChange={(e) => setResolution(e.target.value)}
            sx={{ mb: 2 }}
          >
            <MenuItem value="">Select resolution...</MenuItem>
            <MenuItem value="return_to_client">Return to Client (Refund)</MenuItem>
            <MenuItem value="accept_by_caregiver">Accept by Caregiver (Keep Payment)</MenuItem>
            <MenuItem value="split">Split (50/50)</MenuItem>
            <MenuItem value="other">Other</MenuItem>
          </TextField>

          <TextField
            fullWidth
            multiline
            rows={4}
            label="Resolution Notes"
            placeholder="Explain your decision..."
            value={resolutionNotes}
            onChange={(e) => setResolutionNotes(e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenResolution(false)}>Cancel</Button>
          <Button onClick={handleResolveDispute} variant="contained" color="primary">
            Confirm Resolution
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
