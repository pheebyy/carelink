import React, { useEffect, useState } from 'react';
import { Box, Grid, Card, CardContent, Typography, Chip, Button } from '@mui/material';
import { db } from '../lib/firebase';
import {
  collection,
  query,
  where,
  getDocs,
  collectionGroup,
  orderBy,
  limit,
} from 'firebase/firestore';
import { StatCard } from '../components/StatCard';
import { DataTable } from '../components/DataTable';
import {
  TrendingUp as TrendingUpIcon,
  People as PeopleIcon,
  Work as WorkIcon,
  Payment as PaymentIcon,
} from '@mui/icons-material';
import { formatCurrency, formatDateTime, getStatusIcon } from '../lib/utils';

export default function Dashboard() {
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalJobs: 0,
    totalRevenue: 0,
    pendingApprovals: 0,
  });
  const [recentActivity, setRecentActivity] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        // Fetch users count
        const usersSnapshot = await getDocs(collection(db, 'users'));
        const totalUsers = usersSnapshot.size;
        const pendingApprovalsCount = usersSnapshot.docs.filter(
          (doc) => doc.data().verificationStatus === 'pending_verification'
        ).length;

        // Fetch jobs count
        const jobsSnapshot = await getDocs(collection(db, 'jobs'));
        const totalJobs = jobsSnapshot.size;

        // Fetch payments and calculate revenue
        const paymentsSnapshot = await getDocs(
          query(collection(db, 'payments'), where('status', '==', 'completed'))
        );
        const totalRevenue = paymentsSnapshot.docs.reduce(
          (sum, doc) => sum + (doc.data().amount || 0),
          0
        );

        // Fetch recent audit logs
        const auditSnapshot = await getDocs(
          query(
            collection(db, 'auditLogs'),
            orderBy('timestamp', 'desc'),
            limit(10)
          )
        );
        const activity = auditSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        setStats({
          totalUsers,
          totalJobs,
          totalRevenue,
          pendingApprovals: pendingApprovalsCount,
        });
        setRecentActivity(activity);
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardData();
  }, []);

  const activityColumns = [
    {
      key: 'adminId',
      label: 'Admin',
      render: (value) => value?.substring(0, 8) || '-',
    },
    {
      key: 'action',
      label: 'Action',
      render: (value) => value?.replace(/_/g, ' ').toUpperCase() || '-',
    },
    {
      key: 'timestamp',
      label: 'Date & Time',
      render: (value) => formatDateTime(value),
    },
    {
      key: 'details',
      label: 'Details',
      render: (value) => JSON.stringify(value)?.substring(0, 50) || '-',
    },
  ];

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 'bold', mb: 3 }}>
        Dashboard
      </Typography>

      {/* Key Metrics */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Users"
            value={stats.totalUsers}
            icon={PeopleIcon}
            loading={loading}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Active Jobs"
            value={stats.totalJobs}
            icon={WorkIcon}
            loading={loading}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Revenue"
            value={formatCurrency(stats.totalRevenue)}
            icon={PaymentIcon}
            loading={loading}
            color="#2196F3"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Pending Approvals"
            value={stats.pendingApprovals}
            icon={TrendingUpIcon}
            loading={loading}
            color="#FF9800"
          />
        </Grid>
      </Grid>

      {/* Quick Actions */}
      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 'bold', mb: 2 }}>
            Quick Actions
          </Typography>
          <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
            <Button variant="contained" href="/users?filter=pending">
              Verify Caregivers ({stats.pendingApprovals})
            </Button>
            <Button variant="outlined" href="/jobs">
              Review Flagged Jobs
            </Button>
            <Button variant="outlined" href="/disputes">
              Resolve Disputes
            </Button>
            <Button variant="outlined" href="/payments">
              Manage Payouts
            </Button>
          </Box>
        </CardContent>
      </Card>

      {/* Recent Activity */}
      <Card>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 'bold', mb: 2 }}>
            Recent Activity
          </Typography>
          <DataTable
            columns={activityColumns}
            data={recentActivity}
            loading={loading}
            emptyMessage="No recent activity"
          />
        </CardContent>
      </Card>
    </Box>
  );
}
