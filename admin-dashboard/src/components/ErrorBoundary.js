import React from 'react';
import { Box, Button, Typography, Container } from '@mui/material';
import { Error as ErrorIcon } from '@mui/icons-material';

/**
 * Error Boundary Component
 * Catches errors and displays a user-friendly fallback UI
 */
export class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null,
    };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true };
  }

  componentDidCatch(error, errorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
    this.setState({
      error,
      errorInfo,
    });
  }

  handleReset = () => {
    this.setState({
      hasError: false,
      error: null,
      errorInfo: null,
    });
  };

  render() {
    if (this.state.hasError) {
      return (
        <Container maxWidth="sm">
          <Box
            sx={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              minHeight: '100vh',
              gap: 2,
            }}
          >
            <ErrorIcon
              sx={{
                fontSize: '4rem',
                color: 'error.main',
                mb: 2,
              }}
            />
            <Typography variant="h5" fontWeight="bold">
              Oops! Something went wrong
            </Typography>
            <Typography variant="body2" color="textSecondary" sx={{ textAlign: 'center' }}>
              {this.state.error?.message || 'An unexpected error occurred. Please try refreshing the page.'}
            </Typography>

            {process.env.NODE_ENV === 'development' && this.state.errorInfo && (
              <Box
                sx={{
                  mt: 3,
                  p: 2,
                  backgroundColor: 'grey.100',
                  borderRadius: 1,
                  maxWidth: '100%',
                  overflow: 'auto',
                  maxHeight: '200px',
                }}
              >
                <Typography variant="caption" component="pre" sx={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                  {this.state.errorInfo.componentStack}
                </Typography>
              </Box>
            )}

            <Button
              variant="contained"
              onClick={this.handleReset}
              sx={{ mt: 2 }}
            >
              Try Again
            </Button>
          </Box>
        </Container>
      );
    }

    return this.props.children;
  }
}
