import React, { useEffect, useState } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  Button,
  LinearProgress,
  Divider,
} from '@mui/material';
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
import { StatusBadge } from '../components/StatusBadge';
import {
  TrendingUp as TrendingUpIcon,
  People as PeopleIcon,
  Work as WorkIcon,
  Payment as PaymentIcon,
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

export default function Dashboard() {
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalJobs: 0,
    totalRevenue: 0,
    pendingApprovals: 0,
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

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        // Fetch users count
        const usersSnapshot = await getDocs(collection(db, 'users'));
        const totalUsers = usersSnapshot.size;
        const pendingApprovalsCount = usersSnapshot.docs.filter(
          (doc) => doc.data().verificationStatus === 'pending_verification'
        ).length;

        // Fetch jobs count and details
        const jobsSnapshot = await getDocs(collection(db, 'jobs'));
        const totalJobs = jobsSnapshot.size;
        const activeJobs = jobsSnapshot.docs.filter(
          (doc) => doc.data().status === 'active'
        ).length;
        const completedJobs = jobsSnapshot.docs.filter(
          (doc) => doc.data().status === 'completed'
        ).length;

        // Fetch payments and calculate revenue
        const paymentsSnapshot = await getDocs(
          query(collection(db, 'payments'), where('status', '==', 'completed'))
        );
        const totalRevenue = paymentsSnapshot.docs.reduce(
          (sum, doc) => sum + (doc.data().amount || 0),
          0
        );

        // Payment status distribution
        const paymentStatusSnapshot = await getDocs(collection(db, 'payments'));
        const paymentCounts = {
          completed: 0,
          pending: 0,
          failed: 0,
        };
        paymentStatusSnapshot.docs.forEach((doc) => {
          const status = doc.data().status;
          if (paymentCounts.hasOwnProperty(status)) {
            paymentCounts[status]++;
          }
        });

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

        // Generate mock timeline data (in production, aggregate from Firestore)
        const timelineData = [
          { day: 'Mon', users: 45, jobs: 12, revenue: 2400 },
          { day: 'Tue', users: 52, jobs: 15, revenue: 2800 },
          { day: 'Wed', users: 48, jobs: 14, revenue: 2200 },
          { day: 'Thu', users: 61, jobs: 18, revenue: 2900 },
          { day: 'Fri', users: 55, jobs: 16, revenue: 2500 },
          { day: 'Sat', users: 67, jobs: 22, revenue: 3200 },
          { day: 'Sun', users: 58, jobs: 19, revenue: 2800 },
        ];

        setStats({
          totalUsers,
          totalJobs,
          totalRevenue,
          pendingApprovals: pendingApprovalsCount,
          completedJobs,
          activeJobs,
        });
        setRecentActivity(activity);
        setChartData({
          timeline: timelineData,
          distribution: [
            { name: 'Active', value: activeJobs, fill: COLORS.success },
            { name: 'Completed', value: completedJobs, fill: COLORS.info },
            { name: 'Pending', value: totalJobs - activeJobs - completedJobs, fill: COLORS.pending },
          ],
          paymentStatus: [
            { name: 'Completed', value: paymentCounts.completed, fill: COLORS.success },
            { name: 'Pending', value: paymentCounts.pending, fill: COLORS.pending },
            { name: 'Failed', value: paymentCounts.failed, fill: COLORS.error },
          ],
        });
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
            value={stats.pendingApprovals}
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
                  {chartData.paymentStatus.map((item) => (
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
                        value={(item.value / (chartData.paymentStatus[0].value + chartData.paymentStatus[1].value + chartData.paymentStatus[2].value)) * 100}
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
                  ))}
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
              Resolve Disputes
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
