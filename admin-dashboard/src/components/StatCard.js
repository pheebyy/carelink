import React from 'react';
import {
  Card,
  CardContent,
  Typography,
  Box,
  Icon,
  CircularProgress,
} from '@mui/material';

export const StatCard = ({
  title,
  value,
  icon: IconComponent,
  color = '#4CAF50',
  loading = false,
  trend,
}) => {
  return (
    <Card sx={{ height: '100%' }}>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Box>
            <Typography color="textSecondary" gutterBottom>
              {title}
            </Typography>
            <Typography variant="h5" sx={{ fontWeight: 'bold', mt: 1 }}>
              {loading ? <CircularProgress size={24} /> : value}
            </Typography>
            {trend && (
              <Typography
                variant="caption"
                sx={{
                  color: trend > 0 ? '#4CAF50' : '#f44336',
                  mt: 0.5,
                  display: 'block',
                }}
              >
                {trend > 0 ? '↑' : '↓'} {Math.abs(trend)}% from last month
              </Typography>
            )}
          </Box>
          {IconComponent && (
            <Box
              sx={{
                backgroundColor: `${color}20`,
                borderRadius: '8px',
                p: 1.5,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <IconComponent sx={{ color, fontSize: 32 }} />
            </Box>
          )}
        </Box>
      </CardContent>
    </Card>
  );
};
