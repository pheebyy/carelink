import React from 'react';
import { Chip, Box, Typography } from '@mui/material';
import { getStatusColor, getStatusIcon } from '../lib/themeConstants';
import { COLORS, TRANSITIONS } from '../lib/themeConstants';

/**
 * Professional status badge component
 * Replaces emoji indicators with custom icon styling
 */
export const StatusBadge = ({
  status,
  variant = 'filled',
  size = 'medium',
  label,
  icon: CustomIcon,
  onDelete,
  onClick,
}) => {
  const statusColor = getStatusColor(status);
  const statusIcon = getStatusIcon(status);

  const sizeMap = {
    small: { height: '22px', fontSize: '0.75rem', px: 1 },
    medium: { height: '28px', fontSize: '0.8rem', px: 1.5 },
    large: { height: '32px', fontSize: '0.9rem', px: 2 },
  };

  const styleMap = {
    filled: {
      backgroundColor: statusColor.lighter,
      color: statusColor.color,
      border: `1px solid ${statusColor.color}20`,
    },
    outlined: {
      backgroundColor: 'transparent',
      color: statusColor.color,
      border: `1.5px solid ${statusColor.color}`,
    },
    soft: {
      backgroundColor: statusColor.lighter,
      color: statusColor.color,
      border: 'none',
    },
  };

  return (
    <Box
      onClick={onClick}
      sx={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 0.5,
        ...sizeMap[size],
        ...styleMap[variant],
        borderRadius: '6px',
        padding: '0 12px',
        fontWeight: 500,
        transition: TRANSITIONS.fast,
        cursor: onClick ? 'pointer' : 'default',
        whiteSpace: 'nowrap',
        '&:hover': onClick ? {
          opacity: 0.8,
          transform: 'scale(1.02)',
        } : {},
      }}
    >
      <span style={{ fontSize: size === 'small' ? '0.8rem' : '0.95rem' }}>
        {CustomIcon ? <CustomIcon /> : statusIcon}
      </span>
      <span>{label || status}</span>
    </Box>
  );
};

/**
 * Render status badge for table cells
 * Usage: in table column definition: render: (value) => <StatusBadgeCell status={value} />
 */
export const StatusBadgeCell = ({ status, variant = 'soft' }) => (
  <StatusBadge status={status} variant={variant} size="small" />
);
