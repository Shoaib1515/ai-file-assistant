# 📁 Complete Project File Structure & Code Breakdown: AI File Assistant

**Project Name:** AI File Assistant  
**Date:** September 14, 2026  
**Document Version:** 1.2.0  
**Target Stack:** Python (FastAPI), Flutter (Dart), SQLite / PostgreSQL / SQLAlchemy, Google Gemini Flash AI  

---

## 🌴 Directory Tree Overview

```text
ai_file_assistant/
├── backend/                             # Python FastAPI Server & AI Services
│   ├── app/
│   │   ├── api/                         # REST API Route Handlers
│   │   │   ├── analyze.py               # File Analysis Endpoint (/analyze)
│   │   │   ├── ask.py                   # Gemini AI Q&A Endpoint (/ask)
│   │   │   ├── auth.py                  # Authentication endpoints (/register, /login)
│   │   │   ├── auto_structure.py        # 1-Tap Auto-Structure Endpoints (/auto-structure, /auto-structure/{id})
│   │   │   ├── edit.py                  # Direct Edit Suggest & Apply Endpoints (/suggest-edit, /apply-edit)
│   │   │   ├── file_actions.py          # DB-stored File Actions (/files/{file_id}/*)
│   │   │   ├── files.py                 # File Management Endpoints (/files, /download, /delete)
│   │   │   └── upload.py                # File Upload Endpoint (/upload)
│   │   ├── core/                        # System Configurations & Validators
│   │   │   ├── security.py              # JWT handling, password hashing
│   │   │   └── validation.py            # File size limit/type validators & bounded chunk readers
│   │   ├── db/                          # Database Connections & Session Management
│   │   │   └── database.py              # SQLAlchemy connection, SessionLocal
│   │   ├── models/                      # SQLAlchemy Database Models
│   │   │   ├── file_record.py           # FileRecord ORM model (with storage_path)
│   │   │   └── user.py                  # User ORM model
│   │   └── services/                    # Core Business & AI Logic
│   │       ├── ai_service.py            # Google Gemini Flash API Integration
│   │       ├── analyzer.py              # 4-Factor Data Health Score & anomaly detection
│   │       ├── auto_structurer.py       # Autonomous Header Normalization & Data Cleaning Engine
│   │       ├── editor.py                # Pandas DataFrame cell-editing & Excel builder
│   │       └── file_parser.py           # CSV/Excel parsing
│   ├── storage/                         # Local disk storage for uploaded datasets
│   ├── tests/                           # Backend Test Suite (pytest - 45/45 Passing)
│   │   ├── conftest.py                  # Test fixtures & config
│   │   ├── test_ai_integration.py       # AI integration regression tests
│   │   ├── test_ai_service.py           # AI service unit tests
│   │   ├── test_analysis_api.py         # Analysis endpoint integration tests
│   │   ├── test_analyzer.py             # Analyzer unit tests
│   │   ├── test_auth.py                 # Auth unit tests
│   │   ├── test_auto_structure.py       # 1-Tap Auto-Structure engine tests
│   │   ├── test_edit_api.py             # Edit endpoint integration tests
│   │   ├── test_editor.py               # Editor unit tests
│   │   ├── test_error_handling.py       # Error handling regression tests
│   │   ├── test_files.py                # File management integration tests
│   │   ├── test_messy_csv.py            # Messy dataset parsing & cleaning tests
│   │   ├── test_security_regression.py  # Authorization regression tests
│   │   └── test_upload.py               # Upload integration tests
│   ├── .env                             # Environment Variables
│   ├── main.py                          # FastAPI Application Entry Point & Router Registration
│   └── requirements.txt                 # Python project dependencies
│
└── mobile_app/                          # Flutter Cross-Platform Client
    ├── lib/
    │   ├── models/                      # Dart Data Models
    │   │   ├── file_item.dart           # Primary File Data Model
    │   │   └── history_item.dart        # Activity history log data model
    │   ├── screens/                     # UI Application Screens (All Dark/Light Adaptive)
    │   │   ├── analyze_screen.dart      # Dataset metrics, 1-Tap Auto-Structure modal & preview
    │   │   ├── edit_screen.dart         # AI-assisted prompt editor screen
    │   │   ├── history_screen.dart      # Past uploaded files history view
    │   │   ├── home_screen.dart         # Main Dashboard & file upload screen
    │   │   ├── login_screen.dart        # Authentication entrance screen
    │   │   └── settings_screen.dart     # App settings & global Dark Mode toggle
    │   ├── services/                    # Network API Client
    │   │   └── api_service.dart         # Centralized HTTP/JWT & Auto-Structure request service
    │   ├── theme/                       # Design System & Colors
    │   │   └── app_theme.dart           # Dynamic Theme Provider (Dark/Light tokens, typography)
    │   ├── widgets/                     # Reusable UI Components
    │   │   ├── app_bottom_nav.dart      # Custom Bottom Navigation Bar
    │   │   ├── auth_wrapper.dart        # Session persistence wrapper
    │   │   ├── chat_assistant_fab.dart  # AI Chat Floating Modal
    │   │   └── file_card.dart           # File Card with download/delete/analyze actions
    │   └── main.dart                    # Flutter App Entry Point
    ├── test/                            # Frontend Tests
    │   └── auth_wrapper_test.dart       # Auth persistence tests
    └── pubspec.yaml                     # Flutter package manifest
```

---

*AI File Assistant Complete Project File Structure & Architecture.*
