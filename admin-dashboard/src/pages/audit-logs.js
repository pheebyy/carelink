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
  MenuItem,
} from '@mui/material';
import { db } from '../lib/firebase';
import { collection, getDocs, query, orderBy, limit } from 'firebase/firestore';
import { DataTable } from '../components/DataTable';
import { formatDateTime } from '../lib/utils';

export default function AuditLogsPage() {
  const [logs, setLogs] = useState([]);
  const [filteredLogs, setFilteredLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionFilter, setActionFilter] = useState('all');
  const [adminFilter, setAdminFilter] = useState('all');
  const [selectedLog, setSelectedLog] = useState(null);
  const [openDetail, setOpenDetail] = useState(false);
  const [admins, setAdmins] = useState([]);

  useEffect(() => {
    const fetchLogs = async () => {
      try {
        const logsSnapshot = await getDocs(
          query(
            collection(db, 'auditLogs'),
            orderBy('timestamp', 'desc'),
            limit(1000)
          )
        );

        const logsList = logsSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        // Extract unique admins
        const uniqueAdmins = [...new Set(logsList.map((log) => log.adminId))];
        setAdmins(uniqueAdmins);
        setLogs(logsList);
      } catch (error) {
        console.error('Error fetching audit logs:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchLogs();
  }, []);

  useEffect(() => {
    let filtered = logs;

    if (actionFilter !== 'all') {
      filtered = filtered.filter((log) => log.action === actionFilter);
    }

    if (adminFilter !== 'all') {
      filtered = filtered.filter((log) => log.adminId === adminFilter);
    }

    setFilteredLogs(filtered);
  }, [logs, actionFilter, adminFilter]);

  const handleViewDetails = (log) => {
    setSelectedLog(log);
    setOpenDetail(true);
  };

  const handleExport = () => {
    const csv = [
      ['Timestamp', 'Admin', 'Action', 'Affected User', 'Details'],
      ...filteredLogs.map((log) => [
        formatDateTime(log.timestamp),
        log.adminId,
        log.action,
        log.affectedUserId || '-',
        JSON.stringify(log.details || {}),
      ]),
    ]
      .map((row) => row.map((cell) => `"${cell}"`).join(','))
      .join('\n');

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `audit-logs-${new Date().toISOString()}.csv`;
    a.click();
  };

  const columns = [
    {
      key: 'timestamp',
      label: 'Date & Time',
      render: (value) => formatDateTime(value),
    },
    {
      key: 'adminId',
      label: 'Admin',
      render: (value) => value?.substring(0, 12) + '...' || '-',
    },
    {
      key: 'action',
      label: 'Action',
      render: (value) => value?.replace(/_/g, ' ').toUpperCase() || '-',
    },
    {
      key: 'affectedUserId',
      label: 'Affected User',
      render: (value) => value?.substring(0, 8) + '...' || '-',
    },
    {
      key: 'details',
      label: 'Details',
      render: (value) => {
        const str = JSON.stringify(value || {});
        return str.substring(0, 50) + (str.length > 50 ? '...' : '');
      },
    },
  ];

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 'bold', mb: 3 }}>
        Audit Logs
      </Typography>

      {/* Filters */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                select
                fullWidth
                size="small"
                value={actionFilter}
                onChange={(e) => setActionFilter(e.target.value)}
              >
                <MenuItem value="all">All Actions</MenuItem>
                <MenuItem value="approved_user">User Approved</MenuItem>
                <MenuItem value="rejected_user">User Rejected</MenuItem>
                <MenuItem value="suspended_user">User Suspended</MenuItem>
                <MenuItem value="banned_user">User Banned</MenuItem>
                <MenuItem value="approved_job">Job Approved</MenuItem>
                <MenuItem value="rejected_job">Job Rejected</MenuItem>
                <MenuItem value="completed_payment">Payment Completed</MenuItem>
                <MenuItem value="resolved_dispute">Dispute Resolved</MenuItem>
              </TextField>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                select
                fullWidth
                size="small"
                value={adminFilter}
                onChange={(e) => setAdminFilter(e.target.value)}
              >
                <MenuItem value="all">All Admins</MenuItem>
                {admins.map((admin) => (
                  <MenuItem key={admin} value={admin}>
                    {admin.substring(0, 12)}...
                  </MenuItem>
                ))}
              </TextField>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <Button
                fullWidth
                variant="outlined"
                onClick={handleExport}
              >
                Export to CSV
              </Button>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Audit Logs Table */}
      <Card>
        <CardContent>
          <DataTable
            columns={columns}
            data={filteredLogs}
            loading={loading}
            onRowClick={handleViewDetails}
            emptyMessage="No audit logs found"
          />
        </CardContent>
      </Card>

      {/* Log Detail Dialog */}
      <Dialog open={openDetail} onClose={() => setOpenDetail(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Audit Log Details</DialogTitle>
        <DialogContent>
          {selectedLog && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 2 }}>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Timestamp
                </Typography>
                <Typography variant="body2">{formatDateTime(selectedLog.timestamp)}</Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Admin ID
                </Typography>
                <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                  {selectedLog.adminId}
                </Typography>
              </Box>
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Action
                </Typography>
                <Typography variant="body2">
                  {selectedLog.action?.replace(/_/g, ' ').toUpperCase()}
                </Typography>
              </Box>
              {selectedLog.affectedUserId && (
                <Box>
                  <Typography variant="body2" color="textSecondary">
                    Affected User
                  </Typography>
                  <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                    {selectedLog.affectedUserId}
                  </Typography>
                </Box>
              )}
              <Box>
                <Typography variant="body2" color="textSecondary">
                  Details
                </Typography>
                <Box
                  sx={{
                    p: 1.5,
                    backgroundColor: '#f5f5f5',
                    borderRadius: 1,
                    fontFamily: 'monospace',
                    fontSize: '0.85rem',
                    overflowX: 'auto',
                  }}
                >
                  <pre>{JSON.stringify(selectedLog.details, null, 2)}</pre>
                </Box>
              </Box>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDetail(false)}>Close</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
