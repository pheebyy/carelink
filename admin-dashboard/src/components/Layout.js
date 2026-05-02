import React, { useState } from 'react';
import {
  Box,
  Drawer,
  AppBar,
  Toolbar,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Avatar,
  Menu,
  MenuItem,
  Divider,
  Typography,
  Container,
} from '@mui/material';
import {
  Dashboard as DashboardIcon,
  People as PeopleIcon,
  VerifiedUser as VerifiedUserIcon,
  Work as WorkIcon,
  Payment as PaymentIcon,
  PendingActions as PendingActionsIcon,
  History as HistoryIcon,
  Settings as SettingsIcon,
  Logout as LogoutIcon,
} from '@mui/icons-material';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { auth } from '../lib/firebase';
import { signOut } from 'firebase/auth';
import { useAdmin } from '../context/AdminContext';
import { COLORS, SHADOWS, TRANSITIONS } from '../lib/themeConstants';

const DRAWER_WIDTH = 280;

const menuItems = [
  { label: 'Dashboard', href: '/dashboard', icon: DashboardIcon, permission: null },
  { label: 'Users', href: '/users', icon: PeopleIcon, permission: 'manageUsers' },
  { label: 'Verification', href: '/verification', icon: VerifiedUserIcon, permission: 'verifyCaregiver' },
  { label: 'Jobs', href: '/jobs', icon: WorkIcon, permission: 'moderateJobs' },
  { label: 'Payments', href: '/payments', icon: PaymentIcon, permission: 'approvePayouts' },
  { label: 'Refunds', href: '/refunds', icon: PaymentIcon, permission: 'approvePayouts' },
  { label: 'Disputes', href: '/disputes', icon: PendingActionsIcon, permission: 'manageDisputes' },
  { label: 'Audit Logs', href: '/audit-logs', icon: HistoryIcon, permission: 'viewAuditLog' },
  { label: 'Settings', href: '/settings', icon: SettingsIcon, permission: 'manageSiteSettings' },
];

export default function Layout({ children }) {
  const router = useRouter();
  const { user, adminRole, canPerform } = useAdmin();
  const [anchorEl, setAnchorEl] = useState(null);

  const handleMenuOpen = (event) => {
    setAnchorEl(event.currentTarget);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
  };

  const handleLogout = async () => {
    await signOut(auth);
    router.push('/login');
  };

  const visibleMenuItems = menuItems.filter(
    (item) => !item.permission || canPerform(item.permission)
  );

  return (
    <Box sx={{ display: 'flex' }}>
      {/* Sidebar */}
      <Drawer
        variant="permanent"
        sx={{
          width: DRAWER_WIDTH,
          flexShrink: 0,
          '& .MuiDrawer-paper': {
            width: DRAWER_WIDTH,
            boxSizing: 'border-box',
            backgroundColor: COLORS.sidebar,
            color: 'white',
            borderRight: `1px solid rgba(0,0,0,0.2)`,
          },
        }}
      >
        <Box sx={{ p: 3 }}>
          <Typography
            variant="h5"
            sx={{
              fontWeight: 700,
              mb: 0.5,
              letterSpacing: '-0.5px',
            }}
          >
            CareLink
          </Typography>
          <Typography
            variant="caption"
            sx={{
              color: 'rgba(255,255,255,0.6)',
              display: 'block',
              marginTop: '4px',
            }}
          >
            Admin Dashboard
          </Typography>
        </Box>
        <Divider sx={{ borderColor: 'rgba(255,255,255,0.1)' }} />

        <List sx={{ pt: 1 }}>
          {visibleMenuItems.map((item) => {
            const isActive = router.pathname === item.href;
            const IconComponent = item.icon;

            return (
              <ListItem key={item.href} disablePadding sx={{ mb: 0.5, px: 1 }}>
                <Link href={item.href} passHref legacyBehavior>
                  <ListItemButton
                    selected={isActive}
                    sx={{
                      borderRadius: '8px',
                      backgroundColor: isActive ? 'rgba(76, 175, 80, 0.15)' : 'transparent',
                      borderLeft: isActive ? `4px solid ${COLORS.primary}` : '4px solid transparent',
                      mb: 0.5,
                      transition: TRANSITIONS.smooth,
                      '&:hover': {
                        backgroundColor: 'rgba(76, 175, 80, 0.1)',
                      },
                      '&.Mui-selected': {
                        backgroundColor: 'rgba(76, 175, 80, 0.15)',
                        '&:hover': {
                          backgroundColor: 'rgba(76, 175, 80, 0.2)',
                        },
                      },
                    }}
                  >
                    <ListItemIcon
                      sx={{
                        color: isActive ? COLORS.primary : 'rgba(255,255,255,0.6)',
                        minWidth: 40,
                        transition: TRANSITIONS.fast,
                      }}
                    >
                      <IconComponent fontSize="small" />
                    </ListItemIcon>
                    <ListItemText
                      primary={item.label}
                      primaryTypographyProps={{
                        variant: 'body2',
                        sx: {
                          fontWeight: isActive ? 600 : 500,
                          fontSize: '0.95rem',
                        },
                      }}
                    />
                  </ListItemButton>
                </Link>
              </ListItem>
            );
          })}
        </List>
      </Drawer>

      {/* Main Content */}
      <Box sx={{ flex: 1 }}>
        {/* Top Bar */}
        <AppBar
          position="static"
          sx={{
            backgroundColor: COLORS.surface,
            color: COLORS.gray900,
            boxShadow: SHADOWS.xs,
            borderBottom: `1px solid ${COLORS.divider}`,
          }}
        >
          <Toolbar sx={{ py: 1.5 }}>
            <Box sx={{ flex: 1 }} />
            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                gap: 2,
              }}
            >
              <Typography
                variant="body2"
                sx={{
                  color: COLORS.gray600,
                  fontWeight: 500,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 0.5,
                }}
              >
                {adminRole === 'superadmin' ? '👑' : '👤'}
                <span style={{ textTransform: 'capitalize' }}>{adminRole}</span>
              </Typography>
              <Avatar
                onClick={handleMenuOpen}
                sx={{
                  cursor: 'pointer',
                  width: 40,
                  height: 40,
                  backgroundColor: COLORS.primary,
                  fontWeight: 600,
                  transition: TRANSITIONS.smooth,
                  '&:hover': {
                    backgroundColor: COLORS.primaryDark,
                    boxShadow: SHADOWS.md,
                  },
                }}
                alt={user?.displayName || 'Admin'}
              >
                {user?.email?.charAt(0).toUpperCase()}
              </Avatar>
            </Box>

            <Menu
              anchorEl={anchorEl}
              open={Boolean(anchorEl)}
              onClose={handleMenuClose}
              PaperProps={{
                sx: {
                  borderRadius: '8px',
                  boxShadow: SHADOWS.xl,
                },
              }}
            >
              <MenuItem disabled>
                <Typography variant="body2" sx={{ color: COLORS.gray600 }}>
                  {user?.email}
                </Typography>
              </MenuItem>
              <Divider sx={{ my: 1 }} />
              <MenuItem
                onClick={handleLogout}
                sx={{
                  color: COLORS.error,
                  '&:hover': {
                    backgroundColor: COLORS.errorLighter,
                  },
                }}
              >
                <LogoutIcon sx={{ mr: 1, fontSize: 20 }} />
                <Typography variant="body2">Logout</Typography>
              </MenuItem>
            </Menu>
          </Toolbar>
        </AppBar>

        {/* Page Content */}
        <Container
          maxWidth="xl"
          sx={{
            py: 4,
            minHeight: 'calc(100vh - 64px)',
            backgroundColor: COLORS.background,
          }}
        >
          {children}
        </Container>
      </Box>
    </Box>
  );
}
