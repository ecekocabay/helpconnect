# HelpConnect

**Cloud-Based Emergency Assistance Platform**

A cross-platform mobile application connecting individuals experiencing urgent situations with nearby community volunteers. Built with Flutter and AWS serverless architecture.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Technologies](#technologies)
- [Directory Structure](#directory-structure)
- [Installation](#installation)
- [Running the Application](#running-the-application)
- [AWS Lambda Functions & API Routes](#aws-lambda-functions--api-routes)
- [Database Schema](#database-schema)
- [Team Members](#team-members)

---

## Overview

HelpConnect bridges the gap between traditional emergency services and everyday community needs. Users can request help for non-life-threatening situations (medical assistance, missing pets, grocery help, etc.) and nearby volunteers can respond in real-time.

**Key Capabilities:**
- Dual-role system (Help Seeker / Volunteer)
- Proximity-based volunteer matching
- Real-time request lifecycle management
- Image attachments via S3
- Email notifications via SNS
- Admin dashboard for system management

---

## Features

| Role | Features |
|------|----------|
| **Help Seeker** | Create requests, upload images, review offers, accept volunteers, close requests |
| **Volunteer** | Browse nearby requests, filter by radius, offer help with ETA, track offer status |
| **Admin** | Initialize/reset database, backup to S3, modify records, view system summary |

---

## Technologies

### Frontend
| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.x | Cross-platform UI framework |
| Dart | 3.x | Programming language |
| Google Maps Flutter | Latest | Map integration |
| Amplify Flutter | Latest | AWS Cognito authentication |

### Backend (AWS)
| Service | Purpose |
|---------|---------|
| Amazon Cognito | User authentication & JWT tokens |
| Amazon DynamoDB | NoSQL database |
| Amazon S3 | Image storage & backups |
| Amazon API Gateway | REST API routing |
| AWS Lambda | Serverless compute (Python 3.9) |
| Amazon SNS | Email notifications |
| AWS IAM | Access control |

---

## Directory Structure

```
helpconnect/
├── lib/                          # Flutter source code
│   ├── main.dart                 # App entry point
│   ├── app.dart                  # MaterialApp configuration
│   ├── routes.dart               # Navigation routes
│   ├── theme.dart                # App theme
│   ├── models/                   # Data models
│   │   ├── emergency.dart
│   │   └── offer.dart
│   ├── screens/                  # UI screens
│   │   ├── auth/                 # Authentication screens
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── confirm_code_screen.dart
│   │   │   └── role_selection_screen.dart
│   │   ├── help_seeker/          # Help Seeker screens
│   │   │   ├── help_seeker_home_screen.dart
│   │   │   ├── create_request_screen.dart
│   │   │   ├── my_requests_screen.dart
│   │   │   └── request_detail_screen.dart
│   │   ├── volunteer/            # Volunteer screens
│   │   │   ├── volunteer_home_screen.dart
│   │   │   └── my_offers_screen.dart
│   │   ├── admin/                # Admin screens
│   │   │   └── admin_screen.dart
│   │   ├── profile/              # Profile screens
│   │   │   └── profile_screen.dart
│   │   └── boot/                 # Boot/splash screen
│   │       └── boot_screen.dart
│   ├── services/                 # Business logic
│   │   ├── api_client.dart       # API communication
│   │   ├── auth_service.dart     # Authentication
│   │   └── role_manager.dart     # Role persistence
│   └── widgets/                  # Reusable widgets
│       ├── app_bar_buttons.dart
│       └── emergency_card.dart
├── lib/backend/                  # Lambda function source code
│   ├── HelpConnectListEmergencies.py
│   ├── HelpConnectGetNearbyEmergencies.py
│   ├── HelpConnectCreateHelpRequest.py
│   ├── ... (24 Lambda functions)
│   └── AdminModify.py
├── ios/                          # iOS platform files
├── android/                      # Android platform files
├── web/                          # Web platform files
├── pubspec.yaml                  # Flutter dependencies
└── README.md                     # This file
```

---

## Installation

### Prerequisites

1. **Flutter SDK** (3.0 or higher)
   ```bash
   # macOS (using Homebrew)
   brew install flutter
   
   # Or download from https://docs.flutter.dev/get-started/install
   ```

2. **Dart SDK** (included with Flutter)

3. **IDE** (recommended)
   - VS Code with Flutter extension
   - Android Studio with Flutter plugin

4. **Platform Tools**
   - Xcode (for iOS development on macOS)
   - Android Studio (for Android development)
   - Chrome (for web development)

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/helpconnect.git
   cd helpconnect
   ```

2. **Verify Flutter installation**
   ```bash
   flutter doctor
   ```
   Ensure all required components show ✓

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Configure Amplify (AWS Cognito)**
   
   The `amplifyconfiguration.dart` file contains AWS Cognito settings. Ensure it includes:
   - User Pool ID
   - App Client ID
   - Region (eu-central-1)

5. **Configure Google Maps API Key**
   
   For iOS: Add key to `ios/Runner/AppDelegate.swift`
   
   For Android: Add key to `android/app/src/main/AndroidManifest.xml`

---

## Running the Application

### iOS Simulator
```bash
flutter run -d ios
```

### Android Emulator
```bash
flutter run -d android
```

### Web Browser
```bash
flutter run -d chrome
```

### All Available Devices
```bash
# List devices
flutter devices

# Run on specific device
flutter run -d <device_id>
```

### Build for Production

```bash
# iOS
flutter build ios --release

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Web
flutter build web --release
```

---

## AWS Lambda Functions & API Routes

### Core Request Operations

| Lambda Function | Method | Route | Purpose |
|-----------------|--------|-------|---------|
| HelpConnectListEmergencies.py | GET | `/emergencies` | List all open/in-progress requests |
| HelpConnectGetNearbyEmergencies.py | GET | `/emergencies/nearby` | Geospatial query by lat/lng |
| HelpConnectCreateHelpRequest.py | POST | `/help-requests` | Create new help request |
| HelpConnectGetHelpRequest.py | GET | `/help-requests/{id}` | Get single request details |
| HelpConnectCloseRequest.py | PATCH | `/help-requests/{id}/close` | Close a resolved request |
| HelpConnectListMyRequests.py | GET | `/my-requests` | List user's own requests |

### Offer Operations

| Lambda Function | Method | Route | Purpose |
|-----------------|--------|-------|---------|
| HelpConnectOfferHelp.py | POST | `/offers` | Submit volunteer offer |
| HelpConnectListOffers.py | GET | `/offers` | List offers for a request |
| HelpConnectGetMyOffers.py | GET | `/my-offers` | List volunteer's offers |
| HelpConnectAcceptOffer.py | POST | `/accept-offer` | Accept a volunteer offer |

### Image Operations

| Lambda Function | Method | Route | Purpose |
|-----------------|--------|-------|---------|
| HelpConnectGetUploadUrl.py | POST | `/images/upload-url` | Generate S3 pre-signed PUT URL |
| HelpConnectGetViewUrl.py | GET | `/images/view-url` | Generate S3 pre-signed GET URL |
| HelpConnectAttachRequestImage.py | POST | `/requests/{id}/images` | Link image to request |
| HelpConnectListRequestImages.py | GET | `/requests/{id}/images` | List images for request |
| HelpConnectDeleteRequestImage.py | DELETE | `/requests/{id}/images/{imageId}` | Delete image |

### Notification Operations

| Lambda Function | Method | Route | Purpose |
|-----------------|--------|-------|---------|
| HelpConnectGetNotificationSettings.py | GET | `/notification-settings` | Get user preferences |
| HelpConnectUpdateNotificationSettings.py | POST | `/notification-settings` | Update preferences |
| HelpConnectAutoSubscribeUser.py | Cognito Trigger | - | Auto-subscribe to SNS |
| HelpConnectEnsureNotificationSubscription.py | Internal | - | Ensure SNS subscription |

### Admin Operations

| Lambda Function | Method | Route | Purpose |
|-----------------|--------|-------|---------|
| AdminInitialize.py | POST | `/admin/initialize` | Initialize DynamoDB tables |
| AdminReset.py | POST | `/admin/reset` | Clear all data |
| AdminBackup.py | POST | `/admin/backup` | Export tables to S3 |
| AdminView.py | GET | `/admin/view` | View database summary |
| AdminModify.py | PATCH | `/admin/modify` | Modify specific records |

---

## Database Schema

### DynamoDB Tables

| Table | Partition Key | Sort Key | GSI |
|-------|--------------|----------|-----|
| HelpRequests | request_id | - | help_seeker_id-index |
| HelpOffers | request_id | offer_id | volunteer_id-index |
| HelpConnectRequestImages | request_id | image_id | - |
| NotificationSettings | user_id | - | - |

### Request Statuses

| Status | Description |
|--------|-------------|
| `OPEN` | Awaiting volunteer offers |
| `IN_PROGRESS` | Volunteer accepted, help ongoing |
| `CLOSED` | Request resolved |

---

## API Endpoints

**Base URL:** `https://g0ul86kc5m.execute-api.eu-central-1.amazonaws.com/prod`

**Admin API:** `https://75qmsmgsj2.execute-api.eu-central-1.amazonaws.com/prod`

All endpoints require JWT Authorization header:
```
Authorization: Bearer <cognito_access_token>
```

---

## Team Members

| Name | Role | Email | Student ID |
|------|------|-------|------------|
| **Ece Kocabay** | Backend Developer | ecekocabay1@gmail.com | 2591618 |
| **Noyan Saat** | Frontend Developer | noyansaat9@gmail.com | 2453504 |
| **Ali Saadettin Yaylagül** | AWS & UI Developer |aliyaylagıl@hotmail.com|2453637 |

### Responsibilities

- **Ece Kocabay:** All 24 AWS Lambda functions (Python backend logic)
- **Noyan Saat:** Help Seeker & Volunteer UI screens, widgets, API client integration
- **Ali Saadettin Yaylagül:** AWS service configurations, Authentication screens, Admin Dashboard UI

---

## License

This project was developed as part of **CNG 495 – Cloud Computing** course at METU NCC, Fall 2025.

---

## Acknowledgments

- Course Instructor and Teaching Assistants
- AWS Documentation
- Flutter Community