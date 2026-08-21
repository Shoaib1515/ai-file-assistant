# 📁 Complete Project File Structure & Code Breakdown: AI File Assistant

**Project Name:** AI File Assistant  
**Date:** August 20, 2026  
**Document Version:** 1.1.0  
**Target Stack:** Python (FastAPI), Flutter (Dart), SQLite / SQLAlchemy, Google Gemini AI API  

---

## 🌴 Directory Tree Overview

```text
ai_file_assistant/
├── backend/                             # Python FastAPI Server & AI Services
│   ├── app/
│   │   ├── api/                         # REST API Route Handlers
│   │   │   ├── analyze.py               # File Analysis Endpoint (/analyze)
│   │   │   ├── ask.py                   # Gemini AI Q&A Endpoint (/ask)
│   │   │   ├── edit.py                  # Direct Edit Suggest & Apply Endpoints (/suggest-edit, /apply-edit)
│   │   │   ├── file_actions.py          # DB-stored File Actions (/files/{file_id}/*)
│   │   │   ├── files.py                 # File Management Endpoints (/files, /download, /delete)
│   │   │   ├── auth.py                  # Authentication endpoints (/register, /login)
│   │   │   └── upload.py                # File Upload Endpoint (/upload)
│   │   ├── core/                        # System Configurations & Validators
│   │   │   ├── security.py              # JWT handling, password hashing
│   │   │   └── validation.py            # File size limit/type validators
│   │   ├── db/                          # Database Connections & Session Management
│   │   │   └── database.py              # SQLAlchemy connection, SessionLocal
│   │   ├── models/                      # SQLAlchemy Database Models
│   │   │   ├── file_record.py           # FileRecord ORM model
│   │   │   └── user.py                  # User ORM model
│   │   └── services/                    # Core Business & AI Logic
│   │       ├── ai_service.py            # Google Gemini Flash API Integration
│   │       ├── analyzer.py              # Missing values & Duplicate row detection
│   │       ├── editor.py                # Pandas DataFrame cell-editing & Excel builder
│   │       └── file_parser.py           # CSV/Excel parsing
│   ├── storage/                         # Local disk storage for uploaded datasets
│   ├── tests/                           # Backend Test Suite (pytest)
│   │   ├── conftest.py                  # Test fixtures & config
│   │   ├── test_ai_integration.py       # AI integration regression tests
│   │   ├── test_ai_service.py           # AI service unit tests
│   │   ├── test_analysis_api.py         # Analysis endpoint integration tests
│   │   ├── test_analyzer.py             # Analyzer unit tests
│   │   ├── test_auth.py                 # Auth unit tests
│   │   ├── test_edit_api.py             # Edit endpoint integration tests
│   │   ├── test_editor.py               # Editor unit tests
│   │   ├── test_error_handling.py       # Error handling regression tests
│   │   ├── test_files.py                # File management integration tests
│   │   ├── test_security_regression.py  # Authorization regression tests
│   │   └── test_upload.py               # Upload integration tests
│   ├── .env                             # Environment Variables (Configured)
│   ├── main.py                          # FastAPI Application Entry Point
│   └── requirements.txt                 # Python project dependencies
│
└── mobile_app/                          # Flutter Cross-Platform Client
    ├── lib/
    │   ├── models/                      # Dart Data Models
    │   │   ├── file_item.dart           # Primary File Data Model
    │   │   └── history_item.dart        # Activity history log data model
    │   ├── screens/                     # UI Application Screens
    │   │   ├── analyze_screen.dart      # Dataset issues & metrics dashboard
    │   │   ├── edit_screen.dart         # AI-assisted prompt editor screen
    │   │   ├── history_screen.dart      # Past uploaded files history view
    │   │   ├── home_screen.dart         # Main Dashboard & file upload screen
    │   │   ├── login_screen.dart        # Authentication entrance screen
    │   │   └── settings_screen.dart     # App settings
    │   ├── services/                    # Network API Client
    │   │   └── api_service.dart         # Centralized HTTP/JWT request service
    │   ├── theme/                       # Design System & Colors
    │   │   └── app_theme.dart           # Colors, Typography tokens
    │   ├── widgets/                     # Reusable UI Components
    │   │   ├── app_bottom_nav.dart      # Custom Bottom Navigation Bar
    │   │   ├── auth_wrapper.dart        # Session persistence wrapper
    │   │   ├── chat_assistant_fab.dart  # AI Chat Modal
    │   │   └── file_card.dart           # File Card with download/delete actions
    │   └── main.dart                    # Flutter App Entry Point
    ├── test/                            # Frontend Widget Tests
    │   └── auth_wrapper_test.dart       # Auth persistence tests
    └── pubspec.yaml                     # Flutter package manifest
```
