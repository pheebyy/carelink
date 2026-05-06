# CareLink

A comprehensive Flutter-based healthcare management platform connecting clients with professional caregivers. CareLink streamlines the process of finding, hiring, and managing healthcare services with features for job posting, bidding, care planning, real-time communication, and integrated payment processing.

## Features

### For Clients
- **Dashboard Overview**: View visits, payments, and care statistics at a glance
- **Care Plan Management**: Create, manage, and track personalized care plans
  - Medication schedules
  - Health goals and progress tracking
  - Appointment scheduling
  - Exercise and wellness routines
- **Job Posting**: Post healthcare jobs with detailed requirements and budget
- **Bid Review & Management**: Review, compare, and approve caregiver bids on posted jobs
- **Caregiver Discovery**: Search and filter qualified caregivers by specialty
- **Real-time Messaging**: Secure chat with caregivers and support staff
- **Visit Tracking**: Schedule, monitor, and manage upcoming visits
- **Payment Management**: Secure payment processing via Paystack with transaction history
- **Payment Disputes**: File and resolve payment disputes with full audit trail
- **AI Assistant**: Get intelligent help with care-related questions and recommendations

### For Caregivers
- **Job Browser**: Browse, filter, and apply for available healthcare jobs
- **Smart Bidding System**: Place competitive bids on jobs with custom proposals and estimated duration
- **7-Day Bid Expiration**: Automatic bid lifecycle management with real-time countdown
- **Dashboard**: Track available, pending, approved, and completed jobs
- **Profile Management**: Maintain professional profile with credentials and verification
- **Verification System**: Submit and track verification documents for professional credentials
- **Real-time Messaging**: Communicate with clients in real-time
- **Wallet Management**: Track earnings and request withdrawals
- **AI Assistant**: Get help optimizing job applications and career guidance

### Core Features
- **Secure Authentication**: Email/password authentication with email verification
- **Real-time Chat**: Firebase Firestore-powered instant messaging with read receipts
- **Push Notifications**: Stay updated on important events and job opportunities
- **Video/Voice Calls**: Integrated Jitsi Meet for video consultations
- **Payment Processing**: Secure Paystack integration for transactions
- **Admin Dashboard**: Comprehensive payment and dispute management tools
- **Analytics & Metrics**: Track key performance indicators and statistics
- **Modern UI**: Clean, Material Design 3 interface with responsive layout
- **Offline Support**: Continue working with limited connectivity

## Tech Stack

### Frontend
- **Flutter 3.0+**: Cross-platform mobile framework
- **Material Design 3**: Modern UI components and design system
- **State Management**: StatefulWidget with Streams and StreamBuilder

### Backend & Services
- **Firebase Core**: Application infrastructure
- **Firebase Auth**: User authentication and authorization with email verification
- **Cloud Firestore**: NoSQL real-time database with complex queries and transactions
- **Firebase Storage**: Secure file and media storage
- **Firebase Messaging**: Push notifications and cloud messaging
- **Jitsi Meet**: Video and voice calling infrastructure

### Payment & Integration
- **Paystack**: Payment processing and wallet management
- **SendGrid**: Email notifications and verification

### Additional Dependencies
- `cloud_firestore`: Real-time database operations
- `firebase_auth`: Authentication management
- `firebase_messaging`: Push notification handling
- `paystack_flutter`: Payment processing UI
- `flutter_dotenv`: Environment variable management
- `image_picker`: Profile photo and document uploads
- `flutter_svg`: SVG image rendering
- `url_launcher`: External link handling
- `intl`: Internationalization and date/time formatting

## Installation

### Prerequisites
- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- Android Studio or Xcode (for mobile development)
- Firebase account with Blaze plan (for Cloud Functions)
- Node.js 14+ (for Firebase CLI)
- Paystack account for payment processing

### Setup Steps

1. **Clone the repository**
```bash
git clone https://github.com/pheebyy/carelink.git
cd carelink
```

2. **Install Flutter dependencies**
```bash
flutter pub get
```

3. **Configure Firebase**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable Authentication (Email/Password)
   - Enable Firestore Database (start in test mode)
   - Enable Storage
   - Enable Cloud Messaging
   - Add Android and/or iOS apps to your Firebase project
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in the correct directories:
     - Android: `android/app/google-services.json`
     - iOS: `ios/Runner/GoogleService-Info.plist`

4. **Set up Firebase CLI**
```bash
npm install -g firebase-tools
firebase login
firebase use your-project-id
```

5. **Initialize FlutterFire**
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

6. **Create environment configuration**
Create `.env` file in the root directory:
```env
PAYSTACK_PUBLIC_KEY=your_paystack_public_key_here
SENDGRID_API_KEY=your_sendgrid_api_key_here
```

7. **Deploy Firestore security rules**
```bash
firebase deploy --only firestore:rules
```

8. **Deploy Firebase Cloud Functions** (optional, for bid expiration)
```bash
cd functions
npm install
firebase deploy --only functions
```

9. **Run the application**
```bash
flutter run
```

## Project Structure

```
carelink/
├── lib/
│   ├── main.dart                    # App entry point and setup
│   ├── app_router.dart              # Navigation and routing configuration
│   ├── firebase_options.dart        # Firebase initialization
│   ├── screens/                     # UI screens (30+ screens)
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── signup_screen.dart
│   │   │   └── role_loader_screen.dart
│   │   ├── client/
│   │   │   ├── client_dashboard.dart
│   │   │   ├── care_plan_screen.dart
│   │   │   ├── post_job_screen.dart
│   │   │   ├── search_caregivers_screen.dart
│   │   │   ├── payment_history_screen.dart
│   │   │   └── client_payment_screen.dart
│   │   ├── caregiver/
│   │   │   ├── caregiverdashboard.dart
│   │   │   ├── caregiver_search_screen.dart
│   │   │   ├── caregiver_wallet_screen.dart
│   │   │   └── all_jobs_screen.dart
│   │   ├── messaging/
│   │   │   ├── conversations_inbox_screen.dart
│   │   │   ├── conversations_chat_screen.dart
│   │   │   └── new_conversation_screen.dart
│   │   ├── admin/
│   │   │   ├── admin_dashboard.dart
│   │   │   └── payment_review_screen.dart
│   │   └── shared/
│   │       ├── profile_edit_screen.dart
│   │       ├── ai_assistant_screen.dart
│   │       └── notification_settings_screen.dart
│   ├── services/                    # Business logic and API services
│   │   ├── auth_service.dart        # Authentication
│   │   ├── firestore_service.dart   # Firestore database operations
│   │   ├── storage_service.dart     # Cloud Storage operations
│   │   ├── notification_service.dart# Push notifications
│   │   ├── payment_firestore_service.dart # Payment management
│   │   ├── paystack_service.dart    # Paystack integration
│   │   ├── ai_service.dart          # AI assistant integration
│   │   └── location_tracking_service.dart # Location features
│   ├── Models/                      # Data models
│   │   ├── message_model.dart
│   │   ├── Job_model.dart
│   │   ├── payment_model.dart
│   │   └── usermodel.dart
│   ├── widgets/                     # Reusable UI components
│   ├── config/                      # App configuration
│   ├── utils/                       # Utility functions and helpers
│   └── admin/                       # Admin-specific functionality
├── functions/                       # Firebase Cloud Functions
│   ├── index.js                     # Bid expiration automation
│   └── package.json
├── android/                         # Android native code
├── ios/                             # iOS native code
├── web/                             # Web platform (optional)
├── firestore.rules                  # Firestore security rules
├── storage.rules                    # Storage security rules
├── firebase.json                    # Firebase configuration
├── pubspec.yaml                     # Flutter dependencies
└── README.md                        # This file
```

## Key Features & Implementation

### 1. Authentication & User Roles
- Email/password authentication via Firebase Auth
- Role-based access control (Client, Caregiver, Admin)
- Email verification for new accounts
- Profile completion on first login

### 2. Job Management System
- Clients can post care jobs with detailed descriptions
- Real-time job listings for caregivers
- Advanced filtering and search capabilities
- Job status tracking (open, in-progress, completed)

### 3. Smart Bidding System
- Caregivers submit competitive bids on jobs
- Automatic 7-day bid expiration
- Real-time bid countdown display
- Bid withdrawal before expiration
- Client-side fallback for bid expiration

### 4. Payment Processing
- Integrated Paystack payment gateway
- Wallet management for both roles
- Secure transaction handling
- Payment history and receipts
- Dispute resolution workflow with audit trail
- Admin payment review and approval system

### 5. Real-time Communication
- Firebase Firestore-powered messaging
- Read receipts and delivery status
- Typing indicators (optional)
- Message search functionality
- Conversation history

### 6. Push Notifications
- Event-based notifications (new bids, job updates, payments)
- Firebase Cloud Messaging integration
- Notification preferences and settings

### 7. Care Planning
- Create and manage personalized care plans
- Medication schedules and reminders
- Health goals tracking
- Appointment scheduling
- Exercise and wellness routines

### 8. Admin Dashboard
- Comprehensive payment management
- Dispute review and resolution
- User management and moderation
- System analytics and reporting

## Security Features

- Firestore Security Rules with role-based access control
- Row-level security for sensitive data (payments, conversations)
- Email verification for account creation
- Secure password handling via Firebase Auth
- API key management via environment variables
- Immutable audit trails for payments

## API Integration

### Paystack
- Process payments securely
- Wallet top-up functionality
- Transaction history and reconciliation

### SendGrid (Optional)
- Verification email delivery
- Payment notifications
- User account updates

### Jitsi Meet
- Video consultation capability
- Embedded calling within conversations

## Firestore Database Structure

```
/users/{uid}
  - email, phone, displayName, role, profilePhoto, etc.
  - /visits, /payments, /carePlans (subcollections)

/conversations/{conversationId}
  - participantIds, lastMessage, lastMessageTime, etc.
  - /messages (subcollection)

/jobs/{jobId}
  - clientId, title, description, status, budget, etc.
  - /bids, /applications (subcollections)

/payments/{paymentId}
  - sender, recipient, amount, status, timestamp, etc.

/notifications/{notificationId}
  - userId, type, data, read, timestamp, etc.
```

## Deployment

### To Firebase Hosting (Web)
```bash
flutter build web
firebase deploy --only hosting
```

### To Android
```bash
flutter build apk --release
# or for App Bundle
flutter build appbundle --release
```

### To iOS
```bash
flutter build ios --release
```

## Troubleshooting

### Messages not loading
- Verify Firestore rules allow read access
- Check network connectivity
- Ensure user is authenticated
- Review browser/app console for errors

### Payments failing
- Verify Paystack API keys are correct
- Check payment amount is valid
- Ensure user has required permissions
- Review Paystack transaction logs

### Push notifications not working
- Verify Firebase Cloud Messaging is enabled
- Check notification permissions on device
- Ensure FCM token is being saved
- Review Firebase console for errors

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please open an issue on GitHub or contact the development team.

## Acknowledgments

- Flutter and Dart communities
- Firebase for backend infrastructure
- Paystack for payment processing
- Material Design 3 for UI components
│   │   └── ...
│   └── services/                    # Business logic
│       ├── firestore_service.dart   # Database operations
│       ├── auth_service.dart        # Authentication
│       └── ai_service.dart          # AI assistant
├── android/                         # Android-specific code
├── ios/                            # iOS-specific code
├── web/                            # Web-specific code
├── assets/                         # Images, fonts, etc.
├── firestore.rules                 # Firestore security rules
├── firebase.json                   # Firebase configuration
├── pubspec.yaml                    # Dependencies
└── .env                           # Environment variables
```

##  Security

### Firestore Security Rules
The application uses comprehensive Firestore security rules to protect user data:

- **Users**: Users can only read/write their own profile data
- **Care Plans**: Users can only manage their own care plans
- **Visits**: Clients can only access their own visits
- **Payments**: Clients can only view their own payment records
- **Jobs**: All authenticated users can view jobs; only owners can modify
- **Bids**: Caregivers can create bids; clients can approve/reject
- **Conversations**: Authenticated users can access their conversations
- **Messages**: Users can send/receive messages in their conversations

### Authentication
- Email/password authentication with email verification required
- Secure password requirements enforced
- Session management handled by Firebase Auth

##  Deployment

### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
firebase deploy --only hosting
```

##  App Features in Detail

### Care Plan Management
- Create personalized care plans with multiple types
- Set medication schedules with specific times
- Track health goals and progress
- Schedule appointments and exercises
- Mark tasks as completed
- Real-time synchronization across devices

### Bidding System
- Caregivers can place bids on open jobs
- Include custom proposals and estimated duration
- Clients review all bids in one place
- One-click approval process
- Automatic notification to winning bidder
- Rejected bids are updated automatically

### Messaging System
- Real-time one-on-one conversations
- Message history and timestamps
- User search functionality
- Unread message indicators
- Message notifications

### AI Assistant
- Context-aware responses about care services
- Quick action suggestions
- Help with common tasks
- Integration with app features

##  Configuration

### Firebase Configuration
Update `firebase_options.dart` with your Firebase project settings (auto-generated by FlutterFire CLI).

### Paystack Integration
Add your Paystack public key to the `.env` file:
```env
PAYSTACK_PUBLIC_KEY=pk_test_xxxxxxxxxxxxx
```

### App Theme
Customize app colors in `lib/main.dart`:
```dart
theme: ThemeData(
  primarySwatch: Colors.green,
  useMaterial3: true,
  // ... other theme settings
),
```

##  Known Issues

- Care plan ordering requires Firestore index (auto-created on first use)
- Message sorting uses client-side ordering to avoid complex Firestore queries
- Some deprecated Flutter APIs have been updated to latest standards

##  Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

##  License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

##  Author

- **Pheeby** - *Initial work* - [pheebyy](https://github.com/pheebyy)

##  Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Material Design for UI/UX guidelines
- Paystack for payment processing
- Brainwave team WISTEM project for being supportive




##  App Statistics

- **Screens**: 20+ screens
- **Collections**: 5 main Firestore collections
- **Subcollections**: 6 subcollections for organized data
- **Authentication Methods**: Email/Password with verification
- **Payment Methods**: Paystack integration
- **Real-time Features**: Messaging, notifications, data sync

---

**Built with Phoebe using Flutter**
