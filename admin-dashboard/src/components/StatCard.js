import React from 'react';
import {
  Card,
  CardContent,
  Typography,
  Box,
  CircularProgress,
} from '@mui/material';
import { COLORS, SHADOWS, TRANSITIONS } from '../lib/themeConstants';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import TrendingDownIcon from '@mui/icons-material/TrendingDown';

export const StatCard = ({
  title,
  value,
  icon: IconComponent,
  color = COLORS.primary,
  loading = false,
  trend,
  subtitle,
}) => {
  const iconBackgroundColor = (() => {
    // map color to lighter variant
    const colorMap = {
      [COLORS.primary]: 'rgba(76, 175, 80, 0.1)',
      [COLORS.success]: 'rgba(76, 175, 80, 0.1)',
      [COLORS.error]: 'rgba(244, 67, 54, 0.1)',
      [COLORS.pending]: 'rgba(255, 193, 7, 0.1)',
      [COLORS.info]: 'rgba(33, 150, 243, 0.1)',
      [COLORS.warning]: 'rgba(255, 152, 0, 0.1)',
    };
    return colorMap[color] || 'rgba(76, 175, 80, 0.1)';
  })();

  return (
    <Card
      sx={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        transition: TRANSITIONS.smooth,
        position: 'relative',
        overflow: 'hidden',
        '&::before': {
          content: '""',
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          height: '4px',
          backgroundColor: color,
        },
        '&:hover': {
          boxShadow: SHADOWS.lg,
          transform: 'translateY(-2px)',
        },
      }}
    >
      <CardContent sx={{ flex: 1 }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <Box sx={{ flex: 1 }}>
            <Typography
              variant="body2"
              sx={{
                color: COLORS.gray600,
                fontWeight: 500,
                fontSize: '0.875rem',
                letterSpacing: '0.3px',
                mb: 1,
              }}
            >
              {title}
            </Typography>

            <Box sx={{ display: 'flex', alignItems: 'baseline', gap: 1, mb: 1.5 }}>
              {loading ? (
                <CircularProgress size={24} sx={{ color: color }} />
              ) : (
                <Typography
                  variant="h4"
                  sx={{
                    fontWeight: 700,
                    color: COLORS.gray900,
                    letterSpacing: '-0.5px',
                  }}
                >
                  {value}
                </Typography>
              )}
            </Box>

            {subtitle && (
              <Typography
                variant="caption"
                sx={{
                  color: COLORS.gray600,
                  display: 'block',
                  mb: 0.5,
                }}
              >
                {subtitle}
              </Typography>
            )}

            {trend !== undefined && (
              <Box
                sx={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 0.5,
                  mt: 1,
                }}
              >
                {trend > 0 ? (
                  <TrendingUpIcon sx={{ fontSize: '1rem', color: COLORS.success }} />
                ) : (
                  <TrendingDownIcon sx={{ fontSize: '1rem', color: COLORS.error }} />
                )}
                <Typography
                  variant="caption"
                  sx={{
                    color: trend > 0 ? COLORS.success : COLORS.error,
                    fontWeight: 600,
                  }}
                >
                  {Math.abs(trend)}% from last month
                </Typography>
              </Box>
            )}
          </Box>

          {IconComponent && (
            <Box
              sx={{
                backgroundColor: iconBackgroundColor,
                borderRadius: '12px',
                p: 1.5,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                minWidth: '56px',
                height: '56px',
                ml: 2,
              }}
            >
              <IconComponent
                sx={{
                  color: color,
                  fontSize: 28,
                }}
              />
            </Box>
          )}
        </Box>
      </CardContent>
    </Card>
  );
};
