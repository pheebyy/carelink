# CareLink 

A comprehensive Flutter-based healthcare management platform connecting clients with professional caregivers. CareLink streamlines the process of finding, hiring, and managing healthcare services with features for job posting, bidding, care planning, and real-time communication.

##  Features

### For Clients
- **Dashboard Overview**: View visits, payments, and care statistics at a glance
- **Care Plan Management**: Create, manage, and track personalized care plans
  - Medication schedules
  - Health goals
  - Appointments
  - Exercise routines
- **Job Posting**: Post healthcare jobs with detailed requirements
- **Bid Review**: Review and approve caregiver bids on posted jobs
- **Caregiver Search**: Find and connect with qualified caregivers
- **Real-time Messaging**: Chat with caregivers and support staff
- **Visit Tracking**: Schedule and monitor upcoming visits
- **Payment Management**: Track payments and transaction history
- **AI Assistant**: Get intelligent help with care-related questions

### For Caregivers
- **Job Browser**: Browse and apply for available healthcare jobs
- **Bidding System**: Place competitive bids on jobs with custom proposals
- **Dashboard**: Track available, pending, and total jobs
- **Profile Management**: Maintain professional profile and credentials
- **Messaging**: Communicate with clients in real-time
- **Premium Features**: Enhanced visibility and priority access (optional)
- **AI Assistant**: Get help with job applications and care guidance

### Core Features
-  **Firebase Authentication**: Secure email/password authentication with email verification
-  **Real-time Chat**: Firebase Firestore-powered instant messaging
-  **Push Notifications**: Stay updated on important events
-  **Analytics Dashboard**: Track key metrics and statistics
-  **Modern UI**: Clean, Material Design 3 interface
-  **Responsive Design**: Optimized for all screen sizes
-  **Offline Support**: Continue working with limited connectivity

##  Tech Stack

### Frontend
- **Flutter**: Cross-platform mobile framework
- **Material Design 3**: Modern UI components
- **State Management**: StatefulWidget with Streams

### Backend & Services
- **Firebase Core**: Application infrastructure
- **Firebase Auth**: User authentication and authorization
- **Cloud Firestore**: NoSQL database for real-time data
- **Firebase Storage**: File and media storage
- **Firebase Messaging**: Push notifications

### Additional Dependencies
- `flutter_dotenv`: Environment variable management
- `paystack_flutter`: Payment processing integration
- `intl`: Internationalization and date formatting
- `image_picker`: Profile photo uploads
- `flutter_svg`: SVG image support

##  Installation

### Prerequisites
- Flutter SDK (3.0 or higher)
- Dart SDK (3.0 or higher)
- Android Studio / Xcode (for mobile development)
- Firebase account
- Node.js (for Firebase CLI)

### Setup Steps

1. **Clone the repository**
```bash
git clone https://github.com/pheebyy/carelink.git
cd carelink
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure Firebase**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Add Android and/or iOS apps to your Firebase project
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in their respective directories:
     - Android: `android/app/google-services.json`
     - iOS: `ios/Runner/GoogleService-Info.plist`

4. **Set up Firebase CLI**
```bash
npm install -g firebase-tools
firebase login
```

5. **Initialize Firebase**
```bash
flutterfire configure
```

6. **Create environment file**
Create a `.env` file in the root directory:
```env
PAYSTACK_PUBLIC_KEY=your_paystack_public_key_here
```

7. **Deploy Firestore rules**
```bash
firebase deploy --only firestore:rules
```

8. **Run the app**
```bash
flutter run
```

##  Project Structure

```
carelink/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── firebase_options.dart        # Firebase configuration
│   ├── screens/                     # UI screens
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   ├── client_dashboard.dart
│   │   ├── caregiverdashboard.dart
│   │   ├── care_plan_screen.dart
│   │   ├── job_detail_screen.dart
│   │   ├── post_job_screen.dart
│   │   ├── search_caregivers_screen.dart
│   │   ├── conversations_inbox_screen.dart
│   │   ├── conversations_chat_screen.dart
│   │   ├── ai_assistant_screen.dart
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
