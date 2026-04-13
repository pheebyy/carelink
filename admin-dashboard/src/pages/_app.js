import React, { useEffect } from 'react';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import { AdminProvider, useAdmin } from '../context/AdminContext';
import { useRouter } from 'next/router';
import { CircularProgress, Box } from '@mui/material';
import Layout from '../components/Layout';

// Enhanced theme with professional SaaS design system
const theme = createTheme({
  palette: {
    primary: {
      main: '#4CAF50',
      light: '#66BB6A',
      dark: '#388E3C',
      contrastText: '#ffffff',
    },
    secondary: {
      main: '#45a049',
      light: '#66BB6A',
      dark: '#2E7D32',
      contrastText: '#ffffff',
    },
    success: {
      main: '#4CAF50',
      light: '#81C784',
      dark: '#2E7D32',
      lighter: 'rgba(76, 175, 80, 0.08)',
    },
    warning: {
      main: '#FFC107',
      light: '#FFD54F',
      dark: '#F57F17',
      lighter: 'rgba(255, 193, 7, 0.08)',
    },
    error: {
      main: '#F44336',
      light: '#EF5350',
      dark: '#C62828',
      lighter: 'rgba(244, 67, 54, 0.08)',
    },
    info: {
      main: '#2196F3',
      light: '#64B5F6',
      dark: '#1565C0',
      lighter: 'rgba(33, 150, 243, 0.08)',
    },
    background: {
      default: '#F8FAFB',
      paper: '#FFFFFF',
    },
    text: {
      primary: '#1A1A2E',
      secondary: '#6B7280',
      tertiary: '#9CA3AF',
    },
    divider: '#E5E7EB',
    action: {
      disabledBackground: 'rgba(0, 0, 0, 0.04)',
    },
  },
  typography: {
    fontFamily: [
      '-apple-system',
      'BlinkMacSystemFont',
      '"Segoe UI"',
      'Roboto',
      '"Helvetica Neue"',
      'Arial',
      'sans-serif',
    ].join(','),
    h1: {
      fontSize: '2.5rem',
      fontWeight: 700,
      letterSpacing: '-0.5px',
      color: '#1A1A2E',
    },
    h2: {
      fontSize: '2rem',
      fontWeight: 700,
      letterSpacing: '-0.3px',
      color: '#1A1A2E',
    },
    h3: {
      fontSize: '1.75rem',
      fontWeight: 700,
      letterSpacing: '-0.2px',
      color: '#1A1A2E',
    },
    h4: {
      fontSize: '1.5rem',
      fontWeight: 700,
      letterSpacing: '-0.15px',
      color: '#1A1A2E',
    },
    h5: {
      fontSize: '1.25rem',
      fontWeight: 600,
      letterSpacing: '-0.1px',
      color: '#1A1A2E',
    },
    h6: {
      fontSize: '1rem',
      fontWeight: 600,
      letterSpacing: '0px',
      color: '#1A1A2E',
    },
    body1: {
      fontSize: '1rem',
      lineHeight: 1.6,
      color: '#1A1A2E',
    },
    body2: {
      fontSize: '0.875rem',
      lineHeight: 1.5,
      color: '#6B7280',
    },
    caption: {
      fontSize: '0.75rem',
      lineHeight: 1.4,
      color: '#9CA3AF',
    },
    button: {
      textTransform: 'none',
      fontWeight: 600,
      fontSize: '0.95rem',
    },
  },
  spacing: 8,
  shape: {
    borderRadius: 8,
  },
  shadows: [
    'none',
    '0 1px 2px rgba(0, 0, 0, 0.05)',
    '0 1px 3px rgba(0, 0, 0, 0.08)',
    '0 2px 4px rgba(0, 0, 0, 0.08)',
    '0 4px 6px rgba(0, 0, 0, 0.1)',
    '0 4px 12px rgba(0, 0, 0, 0.1)',
    '0 8px 16px rgba(0, 0, 0, 0.12)',
    '0 12px 20px rgba(0, 0, 0, 0.15)',
    '0 16px 24px rgba(0, 0, 0, 0.15)',
    '0 20px 32px rgba(0, 0, 0, 0.2)',
    '0 24px 40px rgba(0, 0, 0, 0.2)',
    ...Array(12).fill('0 20px 40px rgba(0, 0, 0, 0.2)'),
  ],
  components: {
    MuiButton: {
      styleOverrides: {
        root: {
          borderRadius: 8,
          textTransform: 'none',
          fontWeight: 600,
          padding: '10px 16px',
          transition: 'all 0.2s ease-in-out',
          '&:hover': {
            transform: 'translateY(-2px)',
            boxShadow: '0 4px 12px rgba(0, 0, 0, 0.15)',
          },
          '&:active': {
            transform: 'translateY(0px)',
          },
        },
        contained: {
          boxShadow: '0 2px 4px rgba(0, 0, 0, 0.1)',
        },
        outlined: {
          borderWidth: 1.5,
        },
      },
      defaultProps: {
        disableElevation: false,
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: 12,
          border: '1px solid #E5E7EB',
          boxShadow: '0 1px 3px rgba(0, 0, 0, 0.08)',
          transition: 'all 0.2s ease-in-out',
          backgroundColor: '#FFFFFF',
          '&:hover': {
            boxShadow: '0 4px 12px rgba(0, 0, 0, 0.1)',
          },
        },
      },
    },
    MuiTextField: {
      styleOverrides: {
        root: {
          '& .MuiOutlinedInput-root': {
            borderRadius: 8,
            transition: 'all 0.2s ease-in-out',
            '&:hover .MuiOutlinedInput-notchedOutline': {
              borderColor: '#4CAF50',
              borderWidth: 2,
            },
            '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
              borderColor: '#4CAF50',
              borderWidth: 2,
              boxShadow: '0 0 0 4px rgba(76, 175, 80, 0.08)',
            },
          },
        },
      },
    },
    MuiPaper: {
      styleOverrides: {
        root: {
          backgroundImage: 'none',
        },
      },
    },
    MuiAppBar: {
      styleOverrides: {
        root: {
          boxShadow: '0 1px 3px rgba(0, 0, 0, 0.08)',
          borderBottom: '1px solid #E5E7EB',
        },
      },
    },
    MuiTableHead: {
      styleOverrides: {
        root: {
          backgroundColor: '#F3F4F6',
          borderBottom: '2px solid #E5E7EB',
          '& .MuiTableCell-head': {
            fontWeight: 700,
            color: '#1A1A2E',
            fontSize: '0.875rem',
            letterSpacing: '0.5px',
            textTransform: 'uppercase',
            padding: '12px 16px',
          },
        },
      },
    },
    MuiTableRow: {
      styleOverrides: {
        root: {
          transition: 'all 0.2s ease-in-out',
          '&:hover': {
            backgroundColor: '#F9FAFB',
          },
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: {
          borderColor: '#E5E7EB',
          padding: '12px 16px',
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          borderRadius: 6,
          fontWeight: 500,
          fontSize: '0.75rem',
        },
      },
    },
    MuiDialog: {
      styleOverrides: {
        paper: {
          borderRadius: 12,
          boxShadow: '0 20px 32px rgba(0, 0, 0, 0.15)',
        },
      },
    },
  },
});

function AppContent({ Component, pageProps }) {
  const router = useRouter();
  const { user, loading } = useAdmin();

  const isLoginPage = router.pathname === '/login';

  useEffect(() => {
    if (!loading && !user && !isLoginPage) {
      router.push('/login');
    }
  }, [user, loading, isLoginPage, router]);

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  if (isLoginPage || !user) {
    return <Component {...pageProps} />;
  }

  return (
    <Layout>
      <Component {...pageProps} />
    </Layout>
  );
}

export default function App({ Component, pageProps }) {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <AdminProvider>
        <AppContent Component={Component} pageProps={pageProps} />
      </AdminProvider>
    </ThemeProvider>
  );
}
