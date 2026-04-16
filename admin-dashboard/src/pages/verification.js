import React, { useEffect, useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Tabs,
  Tab,
  TextField,
  Paper,
  Grid,
  FormControlLabel,
  Checkbox,
  Modal,
  CircularProgress,
  Chip,
} from '@mui/material';
import { db } from '../lib/firebase';
import { collection, getDocs, updateDoc, doc } from 'firebase/firestore';
import { useAdmin } from '../context/AdminContext';

function a11yProps(index) {
  return {
    id: `verification-tab-${index}`,
    'aria-controls': `verification-tabpanel-${index}`,
  };
}

function TabPanel(props) {
  const { children, value, index, ...other } = props;
  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`verification-tabpanel-${index}`}
      aria-labelledby={`verification-tab-${index}`}
      {...other}
    >
      {value === index && <Box sx={{ p: 3 }}>{children}</Box>}
    </div>
  );
}

export default function VerificationPage() {
  const { adminRole } = useAdmin();
  const [tabValue, setTabValue] = useState(0);
  const [caregivers, setCaregivers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openVerifyDialog, setOpenVerifyDialog] = useState(false);
  const [selectedCaregiver, setSelectedCaregiver] = useState(null);
  const [documentVerifications, setDocumentVerifications] = useState({});
  const [verificationNotes, setVerificationNotes] = useState({});
  const [rejectionNotes, setRejectionNotes] = useState('');
  const [showRejectDialog, setShowRejectDialog] = useState(false);
  const [imagePreviewUrl, setImagePreviewUrl] = useState(null);
  const [showImageModal, setShowImageModal] = useState(false);

  useEffect(() => {
    if (adminRole !== 'superadmin') {
      console.error('Only superadmins can access verification');
      return;
    }

    const fetchCaregivers = async () => {
      try {
        const usersSnapshot = await getDocs(collection(db, 'users'));
        const caregiversList = usersSnapshot.docs
          .map((doc) => ({
            id: doc.id,
            ...doc.data(),
          }))
          .filter((user) => user.role === 'caregiver');

        setCaregivers(caregiversList);
      } catch (error) {
        console.error('Error fetching caregivers:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchCaregivers();
  }, [adminRole]);

  const handleVerifyDocument = (documentType, verifiedAgainst) => {
    setDocumentVerifications((prev) => ({
      ...prev,
      [documentType]: {
        ...prev[documentType],
        verified: !prev[documentType]?.verified,
        verifiedAgainst:
          prev[documentType]?.verified === false ? verifiedAgainst : null,
      },
    }));
  };

  const handleOpenVerifyDialog = (caregiver) => {
    setSelectedCaregiver(caregiver);
    setDocumentVerifications({});
    setVerificationNotes({});
    setOpenVerifyDialog(true);
  };

  const handleApproveAll = async () => {
    if (!selectedCaregiver) return;

    // Check if all documents are verified
    const hasAllVerifications = selectedCaregiver.verificationDocuments?.every(
      (doc) => documentVerifications[doc.documentType]?.verified
    );

    if (!hasAllVerifications) {
      alert('Please verify all documents before approving');
      return;
    }

    try {
      const updatedDocuments = selectedCaregiver.verificationDocuments.map(
        (doc) => ({
          ...doc,
          status: 'approved',
          verifiedAgainst:
            documentVerifications[doc.documentType]?.verifiedAgainst || '',
          verificationNotes: verificationNotes[doc.documentType] || '',
          verificationDate: new Date().toISOString(),
          verificationMethod: 'manual_board_lookup',
        })
      );

      const caregiverRef = doc(db, 'users', selectedCaregiver.id);
      await updateDoc(caregiverRef, {
        verificationDocuments: updatedDocuments,
        verificationStatus: 'approved',
        verificationApprovedAt: new Date(),
        verificationApprovedBy: 'admin_uid', // TODO: Get actual admin UID from context
        updatedAt: new Date(),
      });

      setCaregivers(
        caregivers.map((c) =>
          c.id === selectedCaregiver.id
            ? {
                ...c,
                verificationDocuments: updatedDocuments,
                verificationStatus: 'approved',
              }
            : c
        )
      );

      setOpenVerifyDialog(false);
      setSelectedCaregiver(null);
      alert('Caregiver approved successfully!');
    } catch (error) {
      console.error('Error approving caregiver:', error);
      alert('Error: ' + error.message);
    }
  };

  const handleReject = async () => {
    if (!selectedCaregiver || !rejectionNotes.trim()) {
      alert('Please provide rejection notes');
      return;
    }

    try {
      const updatedDocuments = selectedCaregiver.verificationDocuments.map(
        (doc) => ({
          ...doc,
          status: 'rejected',
        })
      );

      const caregiverRef = doc(db, 'users', selectedCaregiver.id);
      await updateDoc(caregiverRef, {
        verificationDocuments: updatedDocuments,
        verificationStatus: 'rejected',
        overallVerificationNotes: rejectionNotes,
        updatedAt: new Date(),
      });

      setCaregivers(
        caregivers.map((c) =>
          c.id === selectedCaregiver.id
            ? {
                ...c,
                verificationDocuments: updatedDocuments,
                verificationStatus: 'rejected',
              }
            : c
        )
      );

      setShowRejectDialog(false);
      setOpenVerifyDialog(false);
      setSelectedCaregiver(null);
      setRejectionNotes('');
      alert('Caregiver rejected successfully!');
    } catch (error) {
      console.error('Error rejecting caregiver:', error);
      alert('Error: ' + error.message);
    }
  };

  const getFilteredCaregivers = () => {
    switch (tabValue) {
      case 0: // Pending
        return caregivers.filter(
          (c) => c.verificationStatus === 'pending' || !c.verificationStatus
        );
      case 1: // Approved
        return caregivers.filter((c) => c.verificationStatus === 'approved');
      case 2: // Rejected
        return caregivers.filter((c) => c.verificationStatus === 'rejected');
      default:
        return [];
    }
  };

  const filteredCaregivers = getFilteredCaregivers();

  if (adminRole !== 'superadmin') {
    return (
      <Box>
        <Typography variant="h4" sx={{ fontWeight: 'bold', mb: 3 }}>
          Verification
        </Typography>
        <Card>
          <CardContent>
            <Typography color="error">
              🔒 Only super admins can access this page
            </Typography>
          </CardContent>
        </Card>
      </Box>
    );
  }

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 'bold', mb: 3 }}>
        Caregiver Verification Management
      </Typography>

      <Card>
        <CardContent>
          <Tabs
            value={tabValue}
            onChange={(e, newValue) => setTabValue(newValue)}
            aria-label="verification tabs"
            sx={{ borderBottom: 1, borderColor: 'divider', mb: 3 }}
          >
            <Tab
              label={`Pending (${caregivers.filter((c) => c.verificationStatus === 'pending' || !c.verificationStatus).length})`}
              {...a11yProps(0)}
            />
            <Tab
              label={`Approved (${caregivers.filter((c) => c.verificationStatus === 'approved').length})`}
              {...a11yProps(1)}
            />
            <Tab
              label={`Rejected (${caregivers.filter((c) => c.verificationStatus === 'rejected').length})`}
              {...a11yProps(2)}
            />
          </Tabs>

          <TabPanel value={tabValue} index={0}>
            {filteredCaregivers.length === 0 ? (
              <Typography color="textSecondary">
                No pending verifications
              </Typography>
            ) : (
              <TableContainer component={Paper}>
                <Table>
                  <TableHead sx={{ backgroundColor: '#f5f5f5' }}>
                    <TableRow>
                      <TableCell sx={{ fontWeight: 'bold' }}>Name</TableCell>
                      <TableCell sx={{ fontWeight: 'bold' }}>Email</TableCell>
                      <TableCell sx={{ fontWeight: 'bold' }}>Phone</TableCell>
                      <TableCell sx={{ fontWeight: 'bold' }}>
                        Submitted
                      </TableCell>
                      <TableCell sx={{ fontWeight: 'bold' }} align="right">
                        Actions
                      </TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {filteredCaregivers.map((caregiver) => (
                      <TableRow key={caregiver.id}>
                        <TableCell>{caregiver.name || '-'}</TableCell>
                        <TableCell>{caregiver.email}</TableCell>
                        <TableCell>{caregiver.phone || '-'}</TableCell>
                        <TableCell>
                          {caregiver.verificationSubmittedAt
                            ? new Date(
                                caregiver.verificationSubmittedAt.toDate?.() ||
                                  caregiver.verificationSubmittedAt
                              ).toLocaleDateString()
                            : '-'}
                        </TableCell>
                        <TableCell align="right">
                          <Button
                            size="small"
                            variant="contained"
                            onClick={() => handleOpenVerifyDialog(caregiver)}
                          >
                            Review Documents
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            )}
          </TabPanel>

          <TabPanel value={tabValue} index={1}>
            {filteredCaregivers.length === 0 ? (
              <Typography color="textSecondary">
                No approved caregivers
              </Typography>
            ) : (
              <TableContainer component={Paper}>
                <Table>
                  <TableHead sx={{ backgroundColor: '#f5f5f5' }}>
                    <TableRow>
                      <TableCell sx={{ fontWeight: 'bold' }}>Name</TableCell>
                      <TableCell sx={{ fontWeight: 'bold' }}>Email</TableCell>
                      <TableCell sx={{ fontWeight: 'bold' }}>
                        Approved Date
                      </TableCell>
                      <TableCell sx={{ fontWeight: 'bold' }} align="right">
                        Status
                      </TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {filteredCaregivers.map((caregiver) => (
                      <TableRow key={caregiver.id}>
                        <TableCell>{caregiver.name || '-'}</TableCell>
                        <TableCell>{caregiver.email}</TableCell>
                        <TableCell>
                          {caregiver.verificationApprovedAt
                            ? new Date(
                                caregiver.verificationApprovedAt.toDate?.() ||
                                  caregiver.verificationApprovedAt
                              ).toLocaleDateString()
                            : '-'}
                        </TableCell>
                        <TableCell align="right">
                          <Chip
                            label="✓ Verified"
                            color="success"
                            variant="outlined"
                          />
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            )}
          </TabPanel>

          <TabPanel value={tabValue} index={2}>
            {filteredCaregivers.length === 0 ? (
              <Typography color="textSecondary">
                No rejected caregivers
              </Typography>
            ) : (
              <TableContainer component={Paper}>
                <Table>
                  <TableHead sx={{ backgroundColor: '#f5f5f5' }}>
                    <TableRow>
                      <TableCell sx={{ fontWeight: 'bold' }}>Name</TableCell>
                      <TableCell sx={{ fontWeight: 'bold' }}>Email</TableCell>
                      <TableCell sx={{ fontWeight: 'bold' }}>
                        Rejection Reason
                      </TableCell>
                      <TableCell sx={{ fontWeight: 'bold' }} align="right">
                        Status
                      </TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {filteredCaregivers.map((caregiver) => (
                      <TableRow key={caregiver.id}>
                        <TableCell>{caregiver.name || '-'}</TableCell>
                        <TableCell>{caregiver.email}</TableCell>
                        <TableCell>
                          {caregiver.overallVerificationNotes || '-'}
                        </TableCell>
                        <TableCell align="right">
                          <Chip
                            label="✗ Rejected"
                            color="error"
                            variant="outlined"
                          />
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            )}
          </TabPanel>
        </CardContent>
      </Card>

      {/* Document Verification Dialog */}
      <Dialog
        open={openVerifyDialog}
        onClose={() => setOpenVerifyDialog(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>Review Caregiver Documents</DialogTitle>
        <DialogContent>
          {selectedCaregiver && (
            <Box sx={{ mt: 2 }}>
              <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                {selectedCaregiver.name} ({selectedCaregiver.email})
              </Typography>

              {selectedCaregiver.verificationDocuments?.length > 0 ? (
                <Grid container spacing={2}>
                  {selectedCaregiver.verificationDocuments.map((doc, idx) => (
                    <Grid item xs={12} key={idx}>
                      <Card sx={{ p: 2, backgroundColor: '#fafafa' }}>
                        <Grid container spacing={2}>
                          <Grid item xs={12} sm={3}>
                            <Button
                              variant="outlined"
                              size="small"
                              onClick={() => {
                                setImagePreviewUrl(doc.storageUrl);
                                setShowImageModal(true);
                              }}
                              sx={{ width: '100%' }}
                            >
                              📄 View Document
                            </Button>
                          </Grid>
                          <Grid item xs={12} sm={9}>
                            <Box>
                              <Typography variant="subtitle2">
                                {doc.documentType}
                              </Typography>
                              <Typography variant="body2" color="textSecondary">
                                Value: {doc.documentValue}
                              </Typography>
                              <Typography variant="caption" color="textSecondary">
                                Uploaded:{' '}
                                {new Date(
                                  doc.uploadedAt.toDate?.() || doc.uploadedAt
                                ).toLocaleDateString()}
                              </Typography>
                            </Box>
                          </Grid>
                        </Grid>

                        {/* Verification Form */}
                        <Box sx={{ mt: 2, pt: 2, borderTop: '1px solid #ddd' }}>
                          <TextField
                            select
                            fullWidth
                            size="small"
                            label="Verified Against"
                            value={
                              documentVerifications[doc.documentType]
                                ?.verifiedAgainst || ''
                            }
                            onChange={(e) =>
                              handleVerifyDocument(
                                doc.documentType,
                                e.target.value
                              )
                            }
                            sx={{ mb: 2 }}
                            SelectProps={{
                              native: true,
                            }}
                          >
                            <option value="">Select Board...</option>
                            <option value="KNC Registry">KNC Registry</option>
                            <option value="National ID Database">
                              National ID Database
                            </option>
                            <option value="Passport Office">
                              Passport Office
                            </option>
                            <option value="Other">Other</option>
                          </TextField>

                          <TextField
                            fullWidth
                            size="small"
                            label="Verification Notes"
                            placeholder="e.g., License #12345 confirmed active on KNC board"
                            multiline
                            rows={2}
                            value={verificationNotes[doc.documentType] || ''}
                            onChange={(e) =>
                              setVerificationNotes((prev) => ({
                                ...prev,
                                [doc.documentType]: e.target.value,
                              }))
                            }
                            sx={{ mb: 2 }}
                          />

                          <FormControlLabel
                            control={
                              <Checkbox
                                checked={
                                  documentVerifications[doc.documentType]
                                    ?.verified || false
                                }
                                onChange={() =>
                                  setDocumentVerifications((prev) => ({
                                    ...prev,
                                    [doc.documentType]: {
                                      ...prev[doc.documentType],
                                      verified: !prev[doc.documentType]
                                        ?.verified,
                                    },
                                  }))
                                }
                              />
                            }
                            label="✓ Document Verified"
                          />
                        </Box>
                      </Card>
                    </Grid>
                  ))}
                </Grid>
              ) : (
                <Typography color="textSecondary">
                  No documents submitted
                </Typography>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenVerifyDialog(false)}>Cancel</Button>
          <Button
            onClick={() => setShowRejectDialog(true)}
            color="error"
            variant="outlined"
          >
            Reject
          </Button>
          <Button onClick={handleApproveAll} variant="contained" color="success">
            Approve All
          </Button>
        </DialogActions>
      </Dialog>

      {/* Rejection Dialog */}
      <Dialog
        open={showRejectDialog}
        onClose={() => setShowRejectDialog(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>Reject Caregiver</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            label="Rejection Reason"
            placeholder="Explain why you are rejecting this caregiver's verification..."
            multiline
            rows={4}
            value={rejectionNotes}
            onChange={(e) => setRejectionNotes(e.target.value)}
            sx={{ mt: 2 }}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setShowRejectDialog(false)}>Cancel</Button>
          <Button onClick={handleReject} variant="contained" color="error">
            Confirm Rejection
          </Button>
        </DialogActions>
      </Dialog>

      {/* Image Preview Modal */}
      <Modal
        open={showImageModal}
        onClose={() => setShowImageModal(false)}
        sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center' }}
      >
        <Box
          sx={{
            maxWidth: '80vw',
            maxHeight: '80vh',
            backgroundColor: 'white',
            p: 2,
            borderRadius: 1,
          }}
        >
          {imagePreviewUrl && (
            <img
              src={imagePreviewUrl}
              alt="Document"
              style={{ maxWidth: '100%', maxHeight: '100%' }}
            />
          )}
        </Box>
      </Modal>
    </Box>
  );
}
