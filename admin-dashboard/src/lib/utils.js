import { format, formatDistanceToNow } from 'date-fns';

export const formatCurrency = (amount) => {
  return new Intl.NumberFormat('en-KE', {
    style: 'currency',
    currency: 'KES',
  }).format(amount);
};

export const formatDate = (date) => {
  if (!date) return '-';
  const dateObj = date.toDate ? date.toDate() : new Date(date);
  return format(dateObj, 'MMM dd, yyyy');
};

export const formatDateTime = (date) => {
  if (!date) return '-';
  const dateObj = date.toDate ? date.toDate() : new Date(date);
  return format(dateObj, 'MMM dd, yyyy HH:mm');
};

export const formatTimeAgo = (date) => {
  if (!date) return '-';
  const dateObj = date.toDate ? date.toDate() : new Date(date);
  return formatDistanceToNow(dateObj, { addSuffix: true });
};

export const getStatusColor = (status) => {
  const colors = {
    active: '#4CAF50',
    pending: '#FFC107',
    suspended: '#FF9800',
    banned: '#F44336',
    approved: '#4CAF50',
    rejected: '#F44336',
    completed: '#4CAF50',
    failed: '#F44336',
    refunded: '#9C27B0',
    open: '#4CAF50',
    closed: '#757575',
  };
  return colors[status] || '#757575';
};

export const getStatusIcon = (status) => {
  const icons = {
    active: '🟢',
    pending: '🟡',
    suspended: '⏸️',
    banned: '🔴',
    approved: '✅',
    rejected: '❌',
    completed: '✅',
    failed: '❌',
    refunded: '↩️',
    open: '🟢',
    closed: '⚫',
  };
  return icons[status] || '•';
};

export const truncate = (text, length = 50) => {
  if (!text) return '-';
  return text.length > length ? text.substring(0, length) + '...' : text;
};

export const validateEmail = (email) => {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
};

export const calculateMetrics = (data) => {
  if (!data || !Array.isArray(data)) return { total: 0, average: 0 };
  const total = data.reduce((sum, item) => sum + (item.amount || 0), 0);
  const average = data.length > 0 ? total / data.length : 0;
  return { total, average, count: data.length };
};
