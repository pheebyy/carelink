import toast from 'react-hot-toast';

/**
 * Centralized toast notification utilities
 * Replaces alert() with better UX
 */

export const showSuccess = (message, options = {}) => {
  return toast.success(message, {
    duration: 4000,
    ...options,
  });
};

export const showError = (message, options = {}) => {
  return toast.error(message, {
    duration: 4000,
    ...options,
  });
};

export const showInfo = (message, options = {}) => {
  return toast((t) => (
    <div onClick={() => toast.dismiss(t.id)} style={{ cursor: 'pointer' }}>
      {message}
    </div>
  ), {
    duration: 4000,
    icon: 'ℹ️',
    ...options,
  });
};

export const showLoading = (message) => {
  return toast.loading(message);
};

export const updateToast = (toastId, message, type = 'success') => {
  const options = {
    duration: 4000,
  };

  switch (type) {
    case 'success':
      toast.success(message, { ...options, id: toastId });
      break;
    case 'error':
      toast.error(message, { ...options, id: toastId });
      break;
    default:
      toast(message, { ...options, id: toastId });
  }
};

export const dismissToast = (toastId) => {
  toast.dismiss(toastId);
};

export const dismissAllToasts = () => {
  toast.remove();
};
