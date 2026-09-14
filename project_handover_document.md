# 📋 Project Handover Document: AI File Assistant

**Project Name:** AI File Assistant  
**Date:** September 14, 2026  
**Document Version:** 1.2.0  
**Technology Stack:** Python (FastAPI), Flutter (Dart), SQLite / PostgreSQL / SQLAlchemy, Google Gemini Flash AI  

---

## 1. Executive Summary

**AI File Assistant** is a comprehensive, production-grade cross-platform mobile and web solution for intelligent dataset diagnostics, autonomous 1-tap data structuring/cleaning, natural-language Q&A, and safe cell-level dataset modifications for `.csv` and `.xlsx`/`.xls` files.

The application combines a high-performance **FastAPI asynchronous backend** with an adaptive **Flutter Material 3 frontend**, featuring dynamic dark mode across all screens, autonomous regex-based dataset cleaning algorithms, and Google Gemini Flash AI.

---

## 2. Architecture & Tech Stack

### Technology Breakdown

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Backend Framework** | FastAPI (Python 3.10+) | Async RESTful API with automated Swagger docs |
| **Data Cleaning Engine** | Pandas, NumPy, OpenPyXL, Regex | 1-Tap Autonomous Header & Cell Cleaning |
| **Database & ORM** | SQLite / PostgreSQL + SQLAlchemy | User Auth, Dataset Metadata, and Session State |
| **AI Processing** | Google GenAI SDK (`gemini-flash-latest`) | Natural language Q&A and cell edit suggestion engine |
| **Mobile Client** | Flutter / Dart (^3.12.2) | Cross-platform UI (Android, iOS, Web, Desktop) |
| **Theme System** | Dynamic Theme Provider | Global Dark & Light mode persistence across all screens |
| **File Systems** | `dart:io` + `path_provider` + `FileSaver` | Local and cloud-ready file storage and export |

---

## 3. Implemented Features & Verification Status

| Feature | Description | Status | Verification |
| :--- | :--- | :--- | :--- |
| **User Authentication** | JWT auth, bcrypt hashing, session auto-login | Implemented | Verified via `test_auth.py` |
| **File Lifecycle Management** | Upload, storage persistence, list, re-analyze, delete | Implemented | Verified via `test_files.py` & `test_upload.py` |
| **1-Tap AI Auto-Structure Engine** | Cleans messy headers, removes placeholders, fixes types, dates, deduplicates | Implemented | Verified via `test_auto_structure.py` |
| **Data Health Score (4-Factor)** | Completeness (40%), Uniqueness (25%), Consistency (20%), Cleanliness (15%) | Implemented | Verified via `test_analyzer.py` |
| **AI Assistant (Context Chat)** | Gemini Flash Q&A with dataset summary injection | Implemented | Verified via `test_ai_service.py` |
| **AI-Assisted Safe Editing** | Prompt-driven cell edits with user review & XLSX export | Implemented | Verified via `test_edit_api.py` & `test_editor.py` |
| **Dynamic Dark Mode** | Global dark/light theme toggle across all 5 screens and widgets | Implemented | Flutter UI Verified |
| **Automated Test Suite** | 45 pytest tests (100% green) + clean Flutter analyze | Implemented | Verified (45/45 Passed) |

---

## 4. Environment Variables & Security

*   **`JWT_SECRET_KEY`**: **MANDATORY**. Secret key for generating and validating JSON Web Tokens.
*   **`GEMINI_API_KEY`**: **MANDATORY**. API key for Google Gemini Flash AI processing.
*   **`DATABASE_URL`**: **MANDATORY**. Database connection string (defaults to SQLite, ready for PostgreSQL).
*   **Security Controls**: 
    *   Strict file-size bounded chunk reading (10MB limit).
    *   Magic-byte and extension validation for uploaded files.
    *   Input sanitization to prevent CSV/Excel formula injection.

---

## 5. Development & Run Guide

### Running the Backend
```bash
cd backend
python -m venv venv
# Activate virtual environment
.\venv\Scripts\activate      # On Windows
# source venv/bin/activate   # On Linux/macOS

pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
*Swagger API Docs available at `http://localhost:8000/docs`*

### Running the Frontend
```bash
cd mobile_app
flutter pub get
flutter run
```

---

## 6. Production Deployment Checklist

1. **CORS Configuration**: Restrict `allow_origins` in `main.py` to production domains.
2. **Database Migration**: Switch `DATABASE_URL` from SQLite to managed PostgreSQL.
3. **Environment Secrets**: Store production API keys and JWT secrets in CI/CD / cloud secret managers.

---

*Handover Document prepared for AI File Assistant.*
