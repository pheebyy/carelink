import React, { useEffect, useState, useRef, useCallback } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  Button,
  LinearProgress,
  Alert,
  Skeleton,
  Chip,
} from '@mui/material';
import { db } from '../lib/firebase';
import {
  collection,
  query,
  onSnapshot,
  orderBy,
  limit,
  where,
  Timestamp,
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

// ---------------------------------------------------------------------------
// Status helpers
// ---------------------------------------------------------------------------
const isPendingVerification = (status) =>
  !status || status === 'pending' || status === 'pending_verification';

const isOpenDispute = (status) =>
  !status ||
  ['pending', 'open', 'submitted', 'investigating', 'awaiting_user'].includes(status);

const isActiveRefund = (status) => ['pending', 'processing'].includes(status);

const safePercent = (value, total) => {
  if (!total) return 0;
  return Math.min(100, Math.max(0, (value / total) * 100));
};

// ---------------------------------------------------------------------------
// Build a 7-day timeline skeleton so the chart always has an x-axis to show.
// Actual values are filled in once transaction data arrives.
// ---------------------------------------------------------------------------
const buildTimelineSkeleton = () => {
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    days.push({
      day: d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' }),
      date: d.toDateString(),
      revenue: 0,
      jobs: 0,
    });
  }
  return days;
};

// ---------------------------------------------------------------------------
// Custom tooltip for the LineChart
// ---------------------------------------------------------------------------
const CustomTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <Box
      sx={{
        background: COLORS.surface,
        border: `1px solid ${COLORS.divider}`,
        borderRadius: '8px',
        p: 1.5,
        boxShadow: SHADOWS.sm,
      }}
    >
      <Typography variant="caption" sx={{ color: COLORS.gray600, display: 'block', mb: 0.5 }}>
        {label}
      </Typography>
      {payload.map((entry) => (
        <Typography
          key={entry.name}
          variant="body2"
          sx={{ color: entry.stroke, fontWeight: 600 }}
        >
          {entry.name}:{' '}
          {entry.name.toLowerCase().includes('revenue')
            ? formatCurrency(entry.value)
            : entry.value}
        </Typography>
      ))}
    </Box>
  );
};


const ChartSkeleton = ({ height = 300 }) => (
  <Box sx={{ height, display: 'flex', alignItems: 'flex-end', gap: 1, px: 1 }}>
    {[60, 80, 45, 90, 70, 85, 55].map((h, i) => (
      <Skeleton
        key={i}
        variant="rectangular"
        width="100%"
        height={`${h}%`}
        sx={{ borderRadius: 1 }}
      />
    ))}
  </Box>
);

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------
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

  // Track which collections have finished their first snapshot
  const [loaded, setLoaded] = useState({
    users: false,
    jobs: false,
    transactions: false,
    disputes: false,
    refunds: false,
    auditLogs: false,
  });

  const [recentActivity, setRecentActivity] = useState([]);
  const [chartData, setChartData] = useState({
    timeline: buildTimelineSkeleton(),
    distribution: [],
    paymentStatus: [],
  });
  const [errors, setErrors] = useState([]);

  // Prevent state updates after unmount
  const isMounted = useRef(true);
  useEffect(() => {
    isMounted.current = true;
    return () => { isMounted.current = false; };
  }, []);

  const markLoaded = useCallback((key) => {
    if (!isMounted.current) return;
    setLoaded((prev) => ({ ...prev, [key]: true }));
  }, []);

  const addError = useCallback((msg) => {
    if (!isMounted.current) return;
    setErrors((prev) => (prev.includes(msg) ? prev : [...prev, msg]));
  }, []);

  const isFullyLoaded = Object.values(loaded).every(Boolean);

  // ---------------------------------------------------------------------------
  // Real-time listeners
  // ---------------------------------------------------------------------------
  useEffect(() => {
    const unsubs = [];

    // -- Users --
    unsubs.push(
      onSnapshot(
        query(collection(db, 'users'), limit(500)),
        (snap) => {
          if (!isMounted.current) return;
          const pendingApprovals = snap.docs.filter((d) =>
            isPendingVerification(d.data().verificationStatus)
          ).length;
          setStats((prev) => ({ ...prev, totalUsers: snap.size, pendingApprovals }));
          markLoaded('users');
        },
        (err) => {
          console.error('Dashboard users listener:', err);
          addError('Unable to load user data.');
          markLoaded('users');
        }
      )
    );

    // -- Jobs --
    unsubs.push(
      onSnapshot(
        query(collection(db, 'jobs'), limit(500)),
        (snap) => {
          if (!isMounted.current) return;
          const activeJobs = snap.docs.filter((d) => d.data().status === 'active').length;
          const completedJobs = snap.docs.filter((d) => d.data().status === 'completed').length;

          setStats((prev) => ({
            ...prev,
            totalJobs: snap.size,
            activeJobs,
            completedJobs,
          }));

          setChartData((prev) => ({
            ...prev,
            distribution: [
              { name: 'Active', value: activeJobs, fill: COLORS.success },
              { name: 'Completed', value: completedJobs, fill: COLORS.info },
              {
                name: 'Pending',
                value: Math.max(0, snap.size - activeJobs - completedJobs),
                fill: COLORS.pending,
              },
            ],
          }));

          // Populate the "jobs" line in the 7-day timeline from completedAt timestamps
          setChartData((prev) => {
            const timeline = prev.timeline.map((day) => ({ ...day }));
            snap.docs.forEach((d) => {
              const data = d.data();
              if (data.status !== 'completed' || !data.completedAt) return;
              const ts =
                data.completedAt instanceof Timestamp
                  ? data.completedAt.toDate()
                  : new Date(data.completedAt);
              const dateStr = ts.toDateString();
              const slot = timeline.find((t) => t.date === dateStr);
              if (slot) slot.jobs += 1;
            });
            return { ...prev, timeline };
          });

          markLoaded('jobs');
        },
        (err) => {
          console.error('Dashboard jobs listener:', err);
          addError('Unable to load job data. Check Firestore permissions.');
          markLoaded('jobs');
        }
      )
    );

    // -- Transactions --
    unsubs.push(
      onSnapshot(
        query(collection(db, 'transactions'), limit(500)),
        (snap) => {
          if (!isMounted.current) return;

          const paymentCounts = { completed: 0, pending: 0, failed: 0, refunded: 0 };
          let totalRevenue = 0;

          // Build 7-day revenue timeline
          const timelineRevenue = {};

          snap.docs.forEach((d) => {
            const data = d.data();
            const status = data.status;

            if (Object.prototype.hasOwnProperty.call(paymentCounts, status)) {
              paymentCounts[status]++;
            }

            if (status === 'completed') {
              totalRevenue += data.platformFee || data.amount || 0;

              // Map to timeline day
              const raw = data.completedAt || data.createdAt;
              if (raw) {
                const ts = raw instanceof Timestamp ? raw.toDate() : new Date(raw);
                const dateStr = ts.toDateString();
                timelineRevenue[dateStr] =
                  (timelineRevenue[dateStr] || 0) + (data.platformFee || data.amount || 0);
              }
            }
          });

          setStats((prev) => ({ ...prev, totalRevenue }));

          setChartData((prev) => {
            const timeline = prev.timeline.map((day) => ({
              ...day,
              revenue: timelineRevenue[day.date] || day.revenue,
            }));

            return {
              ...prev,
              timeline,
              paymentStatus: [
                { name: 'Completed', value: paymentCounts.completed, fill: COLORS.success },
                { name: 'Pending', value: paymentCounts.pending, fill: COLORS.pending },
                { name: 'Failed', value: paymentCounts.failed, fill: COLORS.error },
                { name: 'Refunded', value: paymentCounts.refunded, fill: COLORS.info },
              ],
            };
          });

          markLoaded('transactions');
        },
        (err) => {
          console.error('Dashboard transactions listener:', err);
          addError('Unable to load transaction data. Check Firestore permissions.');
          markLoaded('transactions');
        }
      )
    );

    // -- Disputes (collection may not exist yet — handle gracefully) --
    unsubs.push(
      onSnapshot(
        query(collection(db, 'disputes'), limit(500)),
        (snap) => {
          if (!isMounted.current) return;
          const openDisputes = snap.docs.filter((d) => isOpenDispute(d.data().status)).length;
          setStats((prev) => ({ ...prev, openDisputes }));
          markLoaded('disputes');
        },
        (err) => {
          console.error('Dashboard disputes listener:', err);
          // Non-fatal — disputes collection may simply not exist yet
          markLoaded('disputes');
        }
      )
    );

    // -- Refunds --
    unsubs.push(
      onSnapshot(
        query(collection(db, 'refunds'), limit(500)),
        (snap) => {
          if (!isMounted.current) return;
          const pendingRefunds = snap.docs.filter((d) => isActiveRefund(d.data().status)).length;
          setStats((prev) => ({ ...prev, pendingRefunds }));
          markLoaded('refunds');
        },
        (err) => {
          console.error('Dashboard refunds listener:', err);
          markLoaded('refunds');
        }
      )
    );

    // -- Audit logs  (your Firestore uses 'audit_logs', not 'auditLogs') --
    unsubs.push(
      onSnapshot(
        query(collection(db, 'audit_logs'), orderBy('timestamp', 'desc'), limit(10)),
        (snap) => {
          if (!isMounted.current) return;
          setRecentActivity(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
          markLoaded('auditLogs');
        },
        (err) => {
          console.error('Dashboard audit_logs listener:', err);
          addError('Unable to load recent activity. Check Firestore permissions.');
          markLoaded('auditLogs');
        }
      )
    );

    return () => unsubs.forEach((u) => u());
  }, [markLoaded, addError]);

  // ---------------------------------------------------------------------------
  // Derived values
  // ---------------------------------------------------------------------------
  const pendingTotal = stats.pendingApprovals + stats.openDisputes + stats.pendingRefunds;

  // Compute payment total once — not inside render loop
  const paymentTotal = chartData.paymentStatus.reduce((sum, s) => sum + s.value, 0);

  // ---------------------------------------------------------------------------
  // Table columns
  // ---------------------------------------------------------------------------
  const activityColumns = [
    {
      key: 'adminId',
      label: 'Admin',
      render: (value) => (
        <Typography
          variant="body2"
          sx={{
            fontFamily: 'monospace',
            backgroundColor: COLORS.gray200,
            px: 1,
            py: 0.25,
            borderRadius: 1,
            display: 'inline-block',
          }}
        >
          {value?.substring(0, 8) || '-'}
        </Typography>
      ),
    },
    {
      key: 'action',
      label: 'Action',
      render: (value) => {
        const label = value?.replace(/_/g, ' ') || '-';
        const isDestructive = ['delete', 'ban', 'reject'].some((k) =>
          value?.toLowerCase().includes(k)
        );
        return (
          <Chip
            label={label.toUpperCase()}
            size="small"
            sx={{
              backgroundColor: isDestructive
                ? `${COLORS.error}18`
                : `${COLORS.success}18`,
              color: isDestructive ? COLORS.error : COLORS.success,
              fontWeight: 600,
              fontSize: '0.7rem',
            }}
          />
        );
      },
    },
    {
      key: 'timestamp',
      label: 'Date & Time',
      render: (value) => (
        <Typography variant="body2" sx={{ color: COLORS.gray600 }}>
          {formatDateTime(value)}
        </Typography>
      ),
    },
  ];

  // ---------------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------------
  return (
    <Box sx={{ animation: 'fadeIn 0.3s ease-in-out' }}>
      {/* Header */}
      <Box sx={{ mb: { xs: 2, sm: 3, md: 4 } }}>
        <Typography
          variant="h3"
          sx={{
            fontWeight: 700,
            color: COLORS.gray900,
            mb: 0.5,
            fontSize: { xs: '1.5rem', sm: '2rem', md: '2.5rem' },
          }}
        >
          Dashboard
        </Typography>
        <Typography variant="body2" sx={{ color: COLORS.gray600 }}>
          Welcome back! Here's what's happening with your platform today.
        </Typography>
      </Box>

      {/* Errors */}
      {errors.map((err) => (
        <Alert
          key={err}
          severity="warning"
          onClose={() => setErrors((prev) => prev.filter((e) => e !== err))}
          sx={{ mb: 2 }}
        >
          {err}
        </Alert>
      ))}

      {/* KPI Cards */}
      <Grid container spacing={{ xs: 2, md: 3 }} sx={{ mb: { xs: 2, sm: 3, md: 4 } }}>
        {[
          {
            title: 'Total Users',
            value: stats.totalUsers,
            icon: PeopleIcon,
            color: COLORS.success,
            loadKey: 'users',
          },
          {
            title: 'Active Jobs',
            value: stats.activeJobs,
            subtitle: `of ${stats.totalJobs} total`,
            icon: WorkIcon,
            color: COLORS.primary,
            loadKey: 'jobs',
          },
          {
            title: 'Total Revenue',
            value: formatCurrency(stats.totalRevenue),
            icon: CheckCircleIcon,
            color: COLORS.success,
            loadKey: 'transactions',
          },
          {
            title: 'Pending Items',
            value: pendingTotal,
            subtitle: `${stats.pendingApprovals} verifications · ${stats.openDisputes} disputes · ${stats.pendingRefunds} refunds`,
            icon: WarningIcon,
            color: COLORS.pending,
            loadKey: 'users',
          },
        ].map((card) => (
          <Grid item xs={12} sm={6} md={3} key={card.title}>
            <StatCard {...card} loading={!loaded[card.loadKey]} />
          </Grid>
        ))}
      </Grid>

      {/* Charts */}
      <Grid container spacing={{ xs: 2, md: 3 }} sx={{ mb: { xs: 2, sm: 3, md: 4 } }}>

        {/* 7-Day Performance Line Chart */}
        <Grid item xs={12} md={8}>
          <Card sx={{ boxShadow: SHADOWS.sm, '&:hover': { boxShadow: SHADOWS.md }, transition: TRANSITIONS.smooth }}>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: 700, mb: 3, color: COLORS.gray900 }}>
                7-Day Performance
              </Typography>
              {!loaded.transactions ? (
                <ChartSkeleton height={300} />
              ) : (
                <ResponsiveContainer width="100%" height={300}>
                  <LineChart data={chartData.timeline}>
                    <CartesianGrid strokeDasharray="3 3" stroke={COLORS.divider} />
                    <XAxis
                      dataKey="day"
                      stroke={COLORS.gray600}
                      tick={{ fontSize: 11 }}
                    />
                    <YAxis stroke={COLORS.gray600} tick={{ fontSize: 11 }} />
                    <Tooltip content={<CustomTooltip />} />
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

        {/* Job Status Pie */}
        <Grid item xs={12} sm={6} md={4}>
          <Card sx={{ boxShadow: SHADOWS.sm, '&:hover': { boxShadow: SHADOWS.md }, transition: TRANSITIONS.smooth }}>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: 700, mb: 3, color: COLORS.gray900 }}>
                Job Status
              </Typography>
              {!loaded.jobs ? (
                <ChartSkeleton height={300} />
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
                      dataKey="value"
                    >
                      {chartData.distribution.map((entry, i) => (
                        <Cell key={`cell-${i}`} fill={entry.fill} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>
        </Grid>

        {/* Payment Status Progress Bars */}
        <Grid item xs={12} sm={6} md={4}>
          <Card sx={{ boxShadow: SHADOWS.sm, '&:hover': { boxShadow: SHADOWS.md }, transition: TRANSITIONS.smooth }}>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: 700, mb: 3, color: COLORS.gray900 }}>
                Payment Status
              </Typography>
              {!loaded.transactions ? (
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                  {[1, 2, 3, 4].map((i) => (
                    <Box key={i}>
                      <Skeleton width="40%" height={20} sx={{ mb: 0.5 }} />
                      <Skeleton variant="rectangular" height={8} sx={{ borderRadius: 1 }} />
                    </Box>
                  ))}
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
                          {paymentTotal > 0 && (
                            <Typography
                              component="span"
                              variant="caption"
                              sx={{ color: COLORS.gray600, ml: 0.5 }}
                            >
                              ({Math.round(safePercent(item.value, paymentTotal))}%)
                            </Typography>
                          )}
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
          <Typography variant="h6" sx={{ fontWeight: 700, mb: 2, color: COLORS.gray900 }}>
            Quick Actions
          </Typography>
          <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
            {[
              {
                label: `Verify Caregivers (${stats.pendingApprovals})`,
                href: '/users?filter=pending',
                variant: 'contained',
                show: true,
              },
              {
                label: 'Review Jobs',
                href: '/jobs',
                variant: 'outlined',
                show: true,
              },
              {
                label: `Resolve Disputes (${stats.openDisputes})`,
                href: '/disputes',
                variant: 'outlined',
                show: true,
              },
              {
                label: `Review Refunds (${stats.pendingRefunds})`,
                href: '/refunds',
                variant: 'outlined',
                show: true,
              },
              {
                label: 'Manage Payouts',
                href: '/payments',
                variant: 'outlined',
                show: true,
              },
            ].map(({ label, href, variant }) => (
              <Button
                key={href}
                variant={variant}
                href={href}
                sx={{
                  textTransform: 'none',
                  fontWeight: 600,
                  ...(variant === 'contained' && { backgroundColor: COLORS.primary }),
                }}
              >
                {label}
              </Button>
            ))}
          </Box>
        </CardContent>
      </Card>

      {/* Recent Activity */}
      <Card sx={{ boxShadow: SHADOWS.sm, '&:hover': { boxShadow: SHADOWS.md }, transition: TRANSITIONS.smooth }}>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 700, mb: 3, color: COLORS.gray900 }}>
            Recent Activity
          </Typography>
          <DataTable
            columns={activityColumns}
            data={recentActivity}
            loading={!loaded.auditLogs}
            emptyMessage="No recent activity"
          />
        </CardContent>
      </Card>
    </Box>
  );
}