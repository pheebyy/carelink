import React, { useState } from 'react';
import {
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  TablePagination,
  Box,
  CircularProgress,
  Typography,
} from '@mui/material';
import { COLORS, SHADOWS, TRANSITIONS } from '../lib/themeConstants';

export const DataTable = ({
  columns,
  data,
  loading = false,
  rowsPerPageOptions = [10, 25, 50],
  onRowClick,
  emptyMessage = 'No data found',
}) => {
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(rowsPerPageOptions[0]);

  const handleChangePage = (event, newPage) => {
    setPage(newPage);
  };

  const handleChangeRowsPerPage = (event) => {
    setRowsPerPage(parseInt(event.target.value, 10));
    setPage(0);
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
        <CircularProgress sx={{ color: COLORS.primary }} />
      </Box>
    );
  }

  if (!data || data.length === 0) {
    return (
      <Paper
        sx={{
          borderRadius: '12px',
          border: `1px solid ${COLORS.divider}`,
          boxShadow: SHADOWS.xs,
        }}
      >
        <Box sx={{ p: 4, textAlign: 'center' }}>
          <Typography sx={{ color: COLORS.gray600, fontSize: '0.95rem' }}>
            {emptyMessage}
          </Typography>
        </Box>
      </Paper>
    );
  }

  const paginatedData = data.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage);

  return (
    <TableContainer
      component={Paper}
      sx={{
        borderRadius: '12px',
        border: `1px solid ${COLORS.divider}`,
        boxShadow: SHADOWS.xs,
      }}
    >
      <Table>
        <TableHead>
          <TableRow
            sx={{
              backgroundColor: COLORS.gray100,
              borderBottom: `2px solid ${COLORS.divider}`,
            }}
          >
            {columns.map((column) => (
              <TableCell
                key={column.key}
                sx={{
                  fontWeight: 700,
                  backgroundColor: COLORS.gray100,
                  color: COLORS.gray900,
                  fontSize: '0.875rem',
                  letterSpacing: '0.5px',
                  textTransform: 'uppercase',
                  padding: '14px 16px',
                  borderBottom: `2px solid ${COLORS.divider}`,
                }}
              >
                {column.label}
              </TableCell>
            ))}
          </TableRow>
        </TableHead>
        <TableBody>
          {paginatedData.map((row, idx) => (
            <TableRow
              key={row.id || idx}
              onClick={() => onRowClick && onRowClick(row)}
              sx={{
                cursor: onRowClick ? 'pointer' : 'default',
                transition: TRANSITIONS.fast,
                '&:hover': {
                  backgroundColor: COLORS.gray50,
                  boxShadow: onRowClick ? 'inset 0 0 0 1px ' + COLORS.divider : 'none',
                },
                '&:last-child td': {
                  borderBottom: `1px solid ${COLORS.divider}`,
                },
              }}
            >
              {columns.map((column) => (
                <TableCell
                  key={column.key}
                  sx={{
                    padding: '12px 16px',
                    borderColor: COLORS.divider,
                    color: COLORS.gray900,
                    fontSize: '0.9rem',
                  }}
                >
                  {column.render
                    ? column.render(row[column.key], row)
                    : row[column.key] || '—'}
                </TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
      </Table>
      <TablePagination
        rowsPerPageOptions={rowsPerPageOptions}
        component="div"
        count={data.length}
        rowsPerPage={rowsPerPage}
        page={page}
        onPageChange={handleChangePage}
        onRowsPerPageChange={handleChangeRowsPerPage}
        sx={{
          borderTop: `1px solid ${COLORS.divider}`,
          backgroundColor: COLORS.gray50,
          '& .MuiTablePagination-toolbar': {
            paddingRight: '16px',
          },
        }}
      />
    </TableContainer>
  );
};
