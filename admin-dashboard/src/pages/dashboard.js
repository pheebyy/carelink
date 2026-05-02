import React, { useEffect, useState } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  Button,
  LinearProgress,
  Alert,
} from '@mui/material';
import { db } from '../lib/firebase';
import {
  collection,
  query,
  onSnapshot,
  orderBy,
  limit,
} from 'firebase/firestore';
import { StatCard } from '../components/StatCard';
import { DataTable } from '../components/DataTable';
import {
  People as PeopleIcon,
  Work as WorkIcon,
  CheckCircle as CheckCircleIcon,
  Warning as WarningIcon,
} from '@mui/icons-material';
import { formatCurrency, formatDateTime } from '../lib/utils';
import { COLORS, SHADOWS, TRANSITIONS } from '../lib/themeConstants';
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';

const isPendingVerification = (status) =>
  !status || status === 'pending' || status === 'pending_verification';

const isOpenDispute = (status) =>
  !status || ['pending', 'open', 'submitted', 'investigating', 'awaiting_user'].includes(status);

const isActiveRefund = (status) =>
  ['pending', 'processing'].includes(status);

const safePercent = (value, total) => {
  if (!total) return 0;
  return Math.min(100, Math.max(0, (value / total) * 100));
};

export default function Dashboard() {
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalJobs: 0,
    totalRevenue: 0,
    pendingApprovals: 0,
    openDisputes: 0,
    pendingRefunds: 0,
    completedJobs: 0,
    activeJobs: 0,
  });
  const [recentActivity, setRecentActivity] = useState([]);
  const [loading, setLoading] = useState(true);
  const [chartData, setChartData] = useState({
    timeline: [],
    distribution: [],
    paymentStatus: [],
  });
  const [dashboardError, setDashboardError] = useState('');

  useEffect(() => {
    // Set up real-time listeners for dashboard data
    const unsubscribers = [];
    const handleSnapshotError = (label) => (error) => {
      console.error(`Dashboard ${label} listener error:`, error);
      setDashboardError(
        `Some dashboard data could not be loaded (${label}). Check admin Firestore permissions.`
      );
      setLoading(false);
    };

    // Subscribe to users collection
    const usersUnsub = onSnapshot(
      collection(db, 'users'),
      (snapshot) => {
        const totalUsers = snapshot.size;
        const pendingApprovalsCount = snapshot.docs.filter(
          (doc) => isPendingVerification(doc.data().verificationStatus)
        ).length;

        setStats((prevStats) => ({
          ...prevStats,
          totalUsers,
          pendingApprovals: pendingApprovalsCount,
        }));
      },
      handleSnapshotError('users')
    );
    unsubscribers.push(usersUnsub);

    // Subscribe to jobs collection
    const jobsUnsub = onSnapshot(
      collection(db, 'jobs'),
      (snapshot) => {
        const totalJobs = snapshot.size;
        const activeJobs = snapshot.docs.filter(
          (doc) => doc.data().status === 'active'
        ).length;
        const completedJobs = snapshot.docs.filter(
          (doc) => doc.data().status === 'completed'
        ).length;

        setStats((prevStats) => ({
          ...prevStats,
          totalJobs,
          activeJobs,
          completedJobs,
        }));

        // Update chart distribution
        setChartData((prevData) => ({
          ...prevData,
          distribution: [
            { name: 'Active', value: activeJobs, fill: COLORS.success },
            { name: 'Completed', value: completedJobs, fill: COLORS.info },
            { name: 'Pending', value: Math.max(0, totalJobs - activeJobs - completedJobs), fill: COLORS.pending },
          ],
        }));
      },
      handleSnapshotError('jobs')
    );
    unsubscribers.push(jobsUnsub);

    // Subscribe to transactions collection used by the Flutter payment flow.
    const transactionsUnsub = onSnapshot(
      collection(db, 'transactions'),
      (snapshot) => {
        const totalRevenue = snapshot.docs
          .filter((doc) => doc.data().status === 'completed')
          .reduce((sum, doc) => {
            const data = doc.data();
            return sum + (data.platformFee || data.amount || 0);
          }, 0);

        const paymentCounts = {
          completed: 0,
          pending: 0,
          failed: 0,
          refunded: 0,
        };

        snapshot.docs.forEach((doc) => {
          const status = doc.data().status;
          if (Object.prototype.hasOwnProperty.call(paymentCounts, status)) {
            paymentCounts[status]++;
          }
        });

        setStats((prevStats) => ({
          ...prevStats,
          totalRevenue,
        }));

        setChartData((prevData) => ({
          ...prevData,
          paymentStatus: [
            { name: 'Completed', value: paymentCounts.completed, fill: COLORS.success },
            { name: 'Pending', value: paymentCounts.pending, fill: COLORS.pending },
            { name: 'Failed', value: paymentCounts.failed, fill: COLORS.error },
            { name: 'Refunded', value: paymentCounts.refunded, fill: COLORS.info },
          ],
        }));
      },
      handleSnapshotError('transactions')
    );
    unsubscribers.push(transactionsUnsub);

    const disputesUnsub = onSnapshot(
      collection(db, 'disputes'),
      (snapshot) => {
        const openDisputes = snapshot.docs.filter(
          (doc) => isOpenDispute(doc.data().status)
        ).length;

        setStats((prevStats) => ({
          ...prevStats,
          openDisputes,
        }));
      },
      handleSnapshotError('disputes')
    );
    unsubscribers.push(disputesUnsub);

    const refundsUnsub = onSnapshot(
      collection(db, 'refunds'),
      (snapshot) => {
        const pendingRefunds = snapshot.docs.filter(
          (doc) => isActiveRefund(doc.data().status)
        ).length;

        setStats((prevStats) => ({
          ...prevStats,
          pendingRefunds,
        }));
      },
      handleSnapshotError('refunds')
    );
    unsubscribers.push(refundsUnsub);

    // Subscribe to audit logs
    const auditUnsub = onSnapshot(
      query(
        collection(db, 'auditLogs'),
        orderBy('timestamp', 'desc'),
        limit(10)
      ),
      (snapshot) => {
        const activity = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
        setRecentActivity(activity);
      },
      handleSnapshotError('audit logs')
    );
    unsubscribers.push(auditUnsub);

    setLoading(false);

    // Cleanup all subscriptions on unmount
    return () => {
      unsubscribers.forEach((unsub) => unsub());
    };
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
  ];

  return (
    <Box sx={{ animation: 'fadeIn 0.3s ease-in-out' }}>
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
          Dashboard
        </Typography>
        <Typography
          variant="body2"
          sx={{
            color: COLORS.gray600,
          }}
        >
          Welcome back! Here's what's happening with your platform today.
        </Typography>
      </Box>

      {dashboardError && (
        <Alert severity="warning" sx={{ mb: 3 }}>
          {dashboardError}
        </Alert>
      )}

      {/* Key Performance Indicators */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Users"
            value={stats.totalUsers}
            icon={PeopleIcon}
            loading={loading}
            color={COLORS.success}
            trend={8}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Active Jobs"
            value={stats.activeJobs}
            subtitle={`of ${stats.totalJobs} total`}
            icon={WorkIcon}
            loading={loading}
            color={COLORS.primary}
            trend={12}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Revenue"
            value={formatCurrency(stats.totalRevenue)}
            icon={CheckCircleIcon}
            loading={loading}
            color={COLORS.success}
            trend={15}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Pending Items"
            value={stats.pendingApprovals + stats.openDisputes + stats.pendingRefunds}
            subtitle={`${stats.pendingApprovals} verifications, ${stats.openDisputes} disputes, ${stats.pendingRefunds} refunds`}
            icon={WarningIcon}
            loading={loading}
            color={COLORS.pending}
            trend={-3}
          />
        </Grid>
      </Grid>

      {/* Charts Section */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        {/* Revenue & Activity Timeline */}
        <Grid item xs={12} md={8}>
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
              <Typography
                variant="h6"
                sx={{
                  fontWeight: 700,
                  mb: 3,
                  color: COLORS.gray900,
                }}
              >
                7-Day Performance
              </Typography>
              {loading ? (
                <Box sx={{ height: 300, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <LinearProgress sx={{ width: '100%' }} />
                </Box>
              ) : (
                <ResponsiveContainer width="100%" height={300}>
                  <LineChart data={chartData.timeline}>
                    <CartesianGrid strokeDasharray="3 3" stroke={COLORS.divider} />
                    <XAxis dataKey="day" stroke={COLORS.gray600} />
                    <YAxis stroke={COLORS.gray600} />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: COLORS.surface,
                        border: `1px solid ${COLORS.divider}`,
                        borderRadius: '8px',
                      }}
                    />
                    <Legend />
                    <Line
                      type="monotone"
                      dataKey="revenue"
                      stroke={COLORS.success}
                      dot={{ fill: COLORS.success, r: 4 }}
                      strokeWidth={2}
                      name="Revenue ($)"
                    />
                    <Line
                      type="monotone"
                      dataKey="jobs"
                      stroke={COLORS.info}
                      dot={{ fill: COLORS.info, r: 4 }}
                      strokeWidth={2}
                      name="Jobs Completed"
                    />
                  </LineChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>
        </Grid>

        {/* Job Status Distribution */}
        <Grid item xs={12} sm={6} md={4}>
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
              <Typography
                variant="h6"
                sx={{
                  fontWeight: 700,
                  mb: 3,
                  color: COLORS.gray900,
                }}
              >
                Job Status
              </Typography>
              {loading ? (
                <Box sx={{ height: 300, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <LinearProgress sx={{ width: '100%' }} />
                </Box>
              ) : (
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={chartData.distribution}
                      cx="50%"
                      cy="50%"
                      labelLine={false}
                      label={({ name, value }) => `${name}: ${value}`}
                      outerRadius={80}
                      fill="#8884d8"
                      dataKey="value"
                    >
                      {chartData.distribution.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.fill} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>
        </Grid>

        {/* Payment Status */}
        <Grid item xs={12} sm={6} md={4}>
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
              <Typography
                variant="h6"
                sx={{
                  fontWeight: 700,
                  mb: 3,
                  color: COLORS.gray900,
                }}
              >
                Payment Status
              </Typography>
              {loading ? (
                <Box sx={{ height: 300, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <LinearProgress sx={{ width: '100%' }} />
                </Box>
              ) : (
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                  {chartData.paymentStatus.map((item) => {
                    const paymentTotal = chartData.paymentStatus.reduce(
                      (sum, status) => sum + status.value,
                      0
                    );
                    return (
                    <Box key={item.name}>
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                        <Typography variant="body2" sx={{ fontWeight: 600, color: COLORS.gray900 }}>
                          {item.name}
                        </Typography>
                        <Typography variant="body2" sx={{ fontWeight: 700, color: item.fill }}>
                          {item.value}
                        </Typography>
                      </Box>
                      <LinearProgress
                        variant="determinate"
                        value={safePercent(item.value, paymentTotal)}
                        sx={{
                          height: 8,
                          borderRadius: '4px',
                          backgroundColor: COLORS.gray200,
                          '& .MuiLinearProgress-bar': {
                            backgroundColor: item.fill,
                            borderRadius: '4px',
                          },
                        }}
                      />
                    </Box>
                    );
                  })}
                </Box>
              )}
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Quick Actions */}
      <Card
        sx={{
          mb: 4,
          background: `linear-gradient(135deg, ${COLORS.primary}15 0%, ${COLORS.primary}05 100%)`,
          border: `1px solid ${COLORS.primaryLight}30`,
          boxShadow: SHADOWS.sm,
        }}
      >
        <CardContent>
          <Typography
            variant="h6"
            sx={{
              fontWeight: 700,
              mb: 2,
              color: COLORS.gray900,
            }}
          >
            Quick Actions
          </Typography>
          <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
            <Button
              variant="contained"
              href="/users?filter=pending"
              sx={{
                bgColor: COLORS.primary,
                textTransform: 'none',
                fontWeight: 600,
              }}
            >
              Verify Caregivers ({stats.pendingApprovals})
            </Button>
            <Button
              variant="outlined"
              href="/jobs"
              sx={{
                textTransform: 'none',
                fontWeight: 600,
              }}
            >
              Review Jobs
            </Button>
            <Button
              variant="outlined"
              href="/disputes"
              sx={{
                textTransform: 'none',
                fontWeight: 600,
              }}
            >
              Resolve Disputes ({stats.openDisputes})
            </Button>
            <Button
              variant="outlined"
              href="/refunds"
              sx={{
                textTransform: 'none',
                fontWeight: 600,
              }}
            >
              Review Refunds ({stats.pendingRefunds})
            </Button>
            <Button
              variant="outlined"
              href="/payments"
              sx={{
                textTransform: 'none',
                fontWeight: 600,
              }}
            >
              Manage Payouts
            </Button>
          </Box>
        </CardContent>
      </Card>

      {/* Recent Activity */}
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
          <Typography
            variant="h6"
            sx={{
              fontWeight: 700,
              mb: 3,
              color: COLORS.gray900,
            }}
          >
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
