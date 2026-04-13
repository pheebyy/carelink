/**
 * Centralized theme constants and utilities
 * Eliminates scattered color definitions across components
 */

export const COLORS = {
  // Brand primary
  primary: '#4CAF50',
  primaryLight: '#66BB6A',
  primaryDark: '#388E3C',

  // Neutrals
  white: '#FFFFFF',
  black: '#000000',
  gray50: '#F9FAFB',
  gray100: '#F3F4F6',
  gray200: '#E5E7EB',
  gray400: '#9CA3AF',
  gray600: '#6B7280',
  gray900: '#1A1A2E',

  // Status colors
  success: '#4CAF50',
  successLight: '#81C784',
  successLighter: 'rgba(76, 175, 80, 0.08)',

  pending: '#FFC107',
  pendingLight: '#FFD54F',
  pendingLighter: 'rgba(255, 193, 7, 0.08)',

  warning: '#FF9800',
  warningLight: '#FFB74D',
  warningLighter: 'rgba(255, 152, 0, 0.08)',

  error: '#F44336',
  errorLight: '#EF5350',
  errorLighter: 'rgba(244, 67, 54, 0.08)',

  info: '#2196F3',
  infoLight: '#64B5F6',
  infoLighter: 'rgba(33, 150, 243, 0.08)',

  // UI
  background: '#F8FAFB',
  surface: '#FFFFFF',
  divider: '#E5E7EB',
  sidebar: '#1a1a1a',
};

export const SHADOWS = {
  xs: '0 1px 2px rgba(0, 0, 0, 0.05)',
  sm: '0 1px 3px rgba(0, 0, 0, 0.08)',
  md: '0 2px 4px rgba(0, 0, 0, 0.08)',
  lg: '0 4px 6px rgba(0, 0, 0, 0.1)',
  xl: '0 8px 16px rgba(0, 0, 0, 0.12)',
  '2xl': '0 12px 20px rgba(0, 0, 0, 0.15)',
  '3xl': '0 20px 32px rgba(0, 0, 0, 0.2)',
};

export const SPACING = {
  xs: '4px',
  sm: '8px',
  md: '12px',
  lg: '16px',
  xl: '24px',
  '2xl': '32px',
};

export const BORDER_RADIUS = {
  sm: '4px',
  md: '8px',
  lg: '12px',
  xl: '16px',
};

export const TRANSITIONS = {
  fast: '0.15s ease-in-out',
  smooth: '0.25s ease-in-out',
  slow: '0.35s ease-in-out',
};

/**
 * Get status color based on status string
 * @param {string} status - Status value
 * @returns {object} { color, light, lighter, backgroundColor } colors
 */
export const getStatusColor = (status) => {
  const statusMap = {
    approved: { color: COLORS.success, light: COLORS.successLight, lighter: COLORS.successLighter },
    pending: { color: COLORS.pending, light: COLORS.pendingLight, lighter: COLORS.pendingLighter },
    rejected: { color: COLORS.error, light: COLORS.errorLight, lighter: COLORS.errorLighter },
    failed: { color: COLORS.error, light: COLORS.errorLight, lighter: COLORS.errorLighter },
    warning: { color: COLORS.warning, light: COLORS.warningLight, lighter: COLORS.warningLighter },
    completed: { color: COLORS.success, light: COLORS.successLight, lighter: COLORS.successLighter },
    active: { color: COLORS.success, light: COLORS.successLight, lighter: COLORS.successLighter },
    inactive: { color: COLORS.gray600, light: COLORS.gray400, lighter: 'rgba(107, 114, 128, 0.08)' },
    refunded: { color: COLORS.info, light: COLORS.infoLight, lighter: COLORS.infoLighter },
  };

  return statusMap[status?.toLowerCase()] || statusMap.pending;
};

/**
 * Get status icon based on status string
 * @param {string} status - Status value
 * @returns {string} Unicode icon or emoji
 */
export const getStatusIcon = (status) => {
  const iconMap = {
    approved: '✓',
    pending: '⏳',
    rejected: '✗',
    failed: '✗',
    warning: '⚠',
    completed: '✓',
    active: '●',
    inactive: '○',
    refunded: '↩',
  };

  return iconMap[status?.toLowerCase()] || '—';
};

/**
 * Typography scales for consistent sizing
 */
export const TYPOGRAPHY = {
  displayLarge: {
    fontSize: '2.5rem',
    fontWeight: 700,
    lineHeight: 1.2,
  },
  displayMedium: {
    fontSize: '2rem',
    fontWeight: 700,
    lineHeight: 1.3,
  },
  headlineSmall: {
    fontSize: '1.5rem',
    fontWeight: 700,
    lineHeight: 1.4,
  },
  titleMedium: {
    fontSize: '1.125rem',
    fontWeight: 600,
    lineHeight: 1.4,
  },
  titleSmall: {
    fontSize: '1rem',
    fontWeight: 600,
    lineHeight: 1.5,
  },
  bodyLarge: {
    fontSize: '1rem',
    fontWeight: 400,
    lineHeight: 1.6,
  },
  bodyMedium: {
    fontSize: '0.875rem',
    fontWeight: 400,
    lineHeight: 1.5,
  },
  bodySmall: {
    fontSize: '0.75rem',
    fontWeight: 400,
    lineHeight: 1.4,
  },
};
