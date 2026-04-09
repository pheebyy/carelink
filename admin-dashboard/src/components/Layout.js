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
  Work as WorkIcon,
  Payment as PaymentIcon,
  GrainRoundedIcon,
  PendingActions as PendingActionsIcon,
  HistoryEduIcon,
  Settings as SettingsIcon,
  Logout as LogoutIcon,
} from '@mui/icons-material';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { auth } from '../lib/firebase';
import { signOut } from 'firebase/auth';
import { useAdmin } from '../context/AdminContext';

const DRAWER_WIDTH = 280;

const menuItems = [
  { label: 'Dashboard', href: '/dashboard', icon: DashboardIcon, permission: null },
  { label: 'Users', href: '/users', icon: PeopleIcon, permission: 'manageUsers' },
  { label: 'Jobs', href: '/jobs', icon: WorkIcon, permission: 'moderateJobs' },
  { label: 'Payments', href: '/payments', icon: PaymentIcon, permission: 'approvePayouts' },
  { label: 'Disputes', href: '/disputes', icon: PendingActionsIcon, permission: 'manageDisputes' },
  { label: 'Audit Logs', href: '/audit-logs', icon: HistoryEduIcon, permission: 'viewAuditLog' },
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
            backgroundColor: '#1a1a1a',
            color: 'white',
          },
        }}
      >
        <Box sx={{ p: 2 }}>
          <Typography variant="h6" sx={{ fontWeight: 'bold', mb: 1 }}>
            CareLink Admin
          </Typography>
          <Typography variant="caption" sx={{ color: 'rgba(255,255,255,0.7)' }}>
            Dashboard v1.0
          </Typography>
        </Box>
        <Divider />

        <List sx={{ pt: 2 }}>
          {visibleMenuItems.map((item) => {
            const isActive = router.pathname === item.href;
            const IconComponent = item.icon;

            return (
              <ListItem key={item.href} disablePadding>
                <Link href={item.href} passHref legacyBehavior>
                  <ListItemButton
                    selected={isActive}
                    sx={{
                      backgroundColor: isActive ? 'rgba(76, 175, 80, 0.2)' : 'transparent',
                      borderLeft: isActive ? '4px solid #4CAF50' : 'none',
                      '&:hover': {
                        backgroundColor: 'rgba(76, 175, 80, 0.1)',
                      },
                    }}
                  >
                    <ListItemIcon
                      sx={{
                        color: isActive ? '#4CAF50' : 'rgba(255,255,255,0.7)',
                      }}
                    >
                      <IconComponent />
                    </ListItemIcon>
                    <ListItemText primary={item.label} />
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
            backgroundColor: 'white',
            color: '#333',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
          }}
        >
          <Toolbar>
            <Box sx={{ flex: 1 }} />
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
              <Typography variant="body2" sx={{ color: '#666' }}>
                {adminRole === 'superadmin' ? '👑' : '👤'} {adminRole}
              </Typography>
              <Avatar
                onClick={handleMenuOpen}
                sx={{ cursor: 'pointer', width: 40, height: 40, backgroundColor: '#4CAF50' }}
                alt={user?.displayName || 'Admin'}
              >
                {user?.email?.charAt(0).toUpperCase()}
              </Avatar>
            </Box>

            <Menu
              anchorEl={anchorEl}
              open={Boolean(anchorEl)}
              onClose={handleMenuClose}
            >
              <MenuItem disabled>
                <Typography variant="body2">{user?.email}</Typography>
              </MenuItem>
              <Divider />
              <MenuItem onClick={handleLogout}>
                <LogoutIcon sx={{ mr: 1 }} /> Logout
              </MenuItem>
            </Menu>
          </Toolbar>
        </AppBar>

        {/* Page Content */}
        <Container
          maxWidth="xl"
          sx={{
            py: 3,
            minHeight: 'calc(100vh - 64px)',
            backgroundColor: '#f5f5f5',
          }}
        >
          {children}
        </Container>
      </Box>
    </Box>
  );
}
