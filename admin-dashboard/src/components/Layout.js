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
  IconButton,
  useTheme,
  useMediaQuery,
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
  Menu as MenuIcon,
  Close as CloseIcon,
} from '@mui/icons-material';
// Removed duplicate import of useTheme, useMediaQuery, IconButton
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

// Drawer Content Component
function DrawerContent({ visibleMenuItems, router, onItemClick }) {
  return (
    <>
      <Box sx={{ p: { xs: 2, sm: 3 } }}>
        <Typography
          variant="h5"
          sx={{
            fontWeight: 700,
            mb: 0.5,
            letterSpacing: '-0.5px',
            fontSize: { xs: '1.25rem', sm: '1.5rem' },
            display: { xs: 'none', sm: 'block' },
            color: 'white',
          }}
        >
          CareLink
        </Typography>
        <Typography
          variant="caption"
          sx={{
            color: 'rgba(255,255,255,0.6)',
            display: { xs: 'none', sm: 'block' },
            marginTop: '4px',
            fontSize: { xs: '0.7rem', sm: '0.75rem' },
          }}
        >
          Admin Dashboard
        </Typography>
      </Box>
      <Divider sx={{ borderColor: 'rgba(255,255,255,0.1)' }} />

      <List sx={{ pt: 1, px: { xs: 0.5, sm: 1 } }}>
        {visibleMenuItems.map((item) => {
          const isActive = router.pathname === item.href;
          const IconComponent = item.icon;

          return (
            <ListItem key={item.href} disablePadding sx={{ mb: 0.5 }}>
              <Link href={item.href} passHref legacyBehavior>
                <ListItemButton
                  onClick={onItemClick}
                  selected={isActive}
                  sx={{
                    borderRadius: '8px',
                    backgroundColor: isActive ? 'rgba(76, 175, 80, 0.15)' : 'transparent',
                    borderLeft: isActive ? `4px solid ${COLORS.primary}` : '4px solid transparent',
                    mb: 0.5,
                    transition: TRANSITIONS.smooth,
                    px: { xs: 1, sm: 1.5 },
                    py: { xs: 0.75, sm: 1 },
                    minHeight: { xs: 48, sm: 56 },
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
                      minWidth: { xs: 36, sm: 40 },
                      transition: TRANSITIONS.fast,
                      justifyContent: 'center',
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
                        fontSize: { xs: '0.875rem', sm: '0.95rem' },
                        display: { xs: 'none', sm: 'block' },
                        whiteSpace: 'nowrap',
                      },
                    }}
                  />
                </ListItemButton>
              </Link>
            </ListItem>
          );
        })}
      </List>
    </>
  );
}

export default function Layout({ children }) {
  const router = useRouter();
  const { user, adminRole, canPerform } = useAdmin();
  const [anchorEl, setAnchorEl] = useState(null);
  const [mobileDrawerOpen, setMobileDrawerOpen] = useState(false);
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const isTablet = useMediaQuery(theme.breakpoints.down('lg'));

  const handleMenuOpen = (event) => {
    setAnchorEl(event.currentTarget);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
  };

  const handleDrawerToggle = () => {
    setMobileDrawerOpen(!mobileDrawerOpen);
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
      {/* Desktop Sidebar - Permanent */}
      {!isMobile && (
        <Drawer
          variant="permanent"
          sx={{
            width: DRAWER_WIDTH,
            flexShrink: 0,
            display: { xs: 'none', md: 'block' },
            '& .MuiDrawer-paper': {
              width: DRAWER_WIDTH,
              boxSizing: 'border-box',
              backgroundColor: COLORS.sidebar,
              color: 'white',
              borderRight: `1px solid rgba(0,0,0,0.2)`,
              mt: 0,
            },
          }}
        >
          <DrawerContent visibleMenuItems={visibleMenuItems} router={router} />
        </Drawer>
      )}

      {/* Mobile/Tablet Sidebar - Temporary */}
      {isMobile && (
        <Drawer
          variant="temporary"
          anchor="left"
          open={mobileDrawerOpen}
          onClose={handleDrawerToggle}
          ModalProps={{
            keepMounted: true,
          }}
          sx={{
            display: { xs: 'block', md: 'none' },
            width: DRAWER_WIDTH,
            '& .MuiDrawer-paper': {
              width: DRAWER_WIDTH,
              boxSizing: 'border-box',
              backgroundColor: COLORS.sidebar,
              color: 'white',
              borderRight: `1px solid rgba(0,0,0,0.2)`,
            },
          }}
        >
          <DrawerContent
            visibleMenuItems={visibleMenuItems}
            router={router}
            onItemClick={handleDrawerToggle}
          />
        </Drawer>
      )}

      {/* Main Content */}
      <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', width: '100%' }}>
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
          <Toolbar
            sx={{
              py: { xs: 1, sm: 1.5 },
              px: { xs: 1, sm: 2 },
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
            }}
          >
            {isMobile && (
              <IconButton
                color="inherit"
                aria-label="open drawer"
                onClick={handleDrawerToggle}
                sx={{ mr: 1, display: { xs: 'block', md: 'none' } }}
              >
                {mobileDrawerOpen ? <CloseIcon /> : <MenuIcon />}
              </IconButton>
            )}
            <Box sx={{ flex: 1 }} />
            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                gap: { xs: 1, sm: 2 },
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
                  fontSize: { xs: '0.75rem', sm: 'body2' },
                  whiteSpace: 'nowrap',
                }}
              >
                {adminRole === 'superadmin' ? '👑' : '👤'}
                <span style={{ textTransform: 'capitalize', display: { xs: 'none', sm: 'inline' } }}>
                  {adminRole}
                </span>
              </Typography>
              <Avatar
                onClick={handleMenuOpen}
                sx={{
                  cursor: 'pointer',
                  width: { xs: 36, sm: 40 },
                  height: { xs: 36, sm: 40 },
                  backgroundColor: COLORS.primary,
                  fontWeight: 600,
                  transition: TRANSITIONS.smooth,
                  '&:hover': {
                    backgroundColor: COLORS.primaryDark,
                    boxShadow: SHADOWS.md,
                  },
                  fontSize: { xs: '0.875rem', sm: '1rem' },
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
                <Typography variant="body2" sx={{ color: COLORS.gray600, fontSize: '0.8rem' }}>
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
                <LogoutIcon sx={{ mr: 1, fontSize: 18 }} />
                <Typography variant="body2">Logout</Typography>
              </MenuItem>
            </Menu>
          </Toolbar>
        </AppBar>

        {/* Page Content */}
        <Container
          maxWidth="xl"
          sx={{
            py: { xs: 2, sm: 3, md: 4 },
            px: { xs: 1.5, sm: 2, md: 3 },
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
