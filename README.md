HelpConnect – Community Emergency Assistance Platform

HelpConnect is a cross-platform emergency assistance system connecting Help Seekers facing non-life-threatening emergencies with nearby Volunteers. It uses Flutter for the mobile/web application and AWS serverless technologies (API Gateway, Lambda, DynamoDB, S3, SNS, Cognito) for the backend.

PROJECT OVERVIEW

Help Seekers can create help requests such as urgent blood needs, missing pets, environmental issues, or daily support needs. They can view and track their requests and see any volunteer offers made.

Volunteers can browse all active emergencies, filter them by category or urgency, and offer help.

Admin users (to be completed in Stage 3) will manage users, requests, and system monitoring.

ARCHITECTURE

Frontend: Flutter, single codebase for iOS, Android, and Web. Role-based UI for different user types. Communicates with AWS backend through REST APIs.

Backend: AWS Lambda functions (Python) handle all logic. API Gateway exposes endpoints. DynamoDB stores help requests and offers. S3 stores uploaded request images. SNS will send notifications. Cognito will handle user authentication and roles.

REPOSITORY STRUCTURE

frontend – Flutter mobile/web project
backend – All Lambda Python code
docs – Proposal, progress report, final report, screenshots
README.md – Project description and instructions

HOW TO RUN

Clone the repository:
git clone https://github.com/ecekocabay/helpconnect.git

Run Flutter app:
cd frontend
flutter pub get
flutter run

Web version:
flutter run -d chrome

Deploy a Lambda:
Zip the function folder and upload to AWS → Lambda → Upload code

API ENDPOINTS

POST /help-requests – Create help request
GET /emergencies – List emergencies
GET /my-requests?helpSeekerId=ID – List user’s requests
POST /offers – Volunteer offer
GET /offers?requestId=ID – List volunteer offers

DYNAMODB TABLES

HelpRequests table: primary key request_id, secondary index help_seeker_id-index
HelpOffers table: primary key offer_id, secondary index request_id-index


MILESTONES

Completed and remaining milestones are documented in docs/progress_report.pdf.

TEAM

Frontend Lead: Noyan Saat
Backend Developer: Ece Kocabay
Cloud Engineer: Ali Saadettin Yaylagül

LICENSE

This project was developed for the CNG 495 Capstone Project (Fall 2025) at METU NCC and is intended for academic use.