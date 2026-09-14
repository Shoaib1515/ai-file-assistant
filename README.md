# 🤖 AI File Assistant

A modern, cross-platform mobile application and FastAPI backend that enables natural-language dataset analysis, AI-powered Q&A, autonomous 1-tap data cleaning/structuring, and safe cell-level dataset editing for CSV and Excel files using Google Gemini Flash AI.

---

## 🌟 Key Features

- ⚡ **1-Tap AI Auto-Structure & Cleaning**:
  - Automatically transforms messy, unstructured datasets into clean, standardized tables.
  - Fixes irregular headers (`user_first_name` / `userFirstName` ➔ `User First Name`).
  - Removes placeholder anomalies (`'N/A'`, `'null'`, `'-'`, `'?'`, `'none'`).
  - Intelligently coerces numeric types, standardizes ISO 8601 dates, trims whitespace, and eliminates duplicate rows.
  - Provides a **Before vs After health comparison modal** and 1-tap **Clean CSV Download**.

- 📊 **Intelligent Data Health Diagnostic**:
  - Calculates a 4-factor health score: **Completeness (40%)**, **Uniqueness (25%)**, **Consistency (20%)**, and **Cleanliness (15%)**.
  - Displays color-coded diagnostic badges (✨ Excellent `90-100%`, ⚠️ Good `70-89%`, 🔴 Needs Attention `<70%`).

- 🌙 **Full Dynamic Dark Mode**:
  - Seamless dark and light theme switching across all 5 screens (`Home`, `Analyze`, `Edit`, `History`, `Settings`) and widgets (`FileCard`, `AppBottomNav`, `ChatFab`).

- 💬 **Context-Aware AI Chatbot**:
  - Interactive dataset Q&A and instant insights powered by Google Gemini Flash AI.

- ✍️ **Interactive Spreadsheet Editor & Safe AI Editing**:
  - **Live Table Grid & Cell Tap-to-Edit**: Directly view dataset rows and tap any cell to edit via a popup dialog without writing prompts.
  - **Quick Search & Filter Bar**: Instant real-time search by row number, name, ID, or any value to isolate and edit specific records.
  - **Excel Sheet Selector Tabs**: Switch seamlessly between multiple worksheets (`Sheet1`, `Sales`, `Expenses`, etc.).
  - **Dual Save Options**: Choose between **Overwrite Original File (In-Place)** or **Save as New File (Export Copy)**.
  - **AI Suggestions & Bulk Actions**: Optional prompt-driven edits and 1-tap cleaning chips (Capitalize, Trim Spaces, Round Numbers).

- 📂 **Multi-Format & Persistent Storage**:
  - Supports `.csv` and `.xlsx`/`.xls` (including multi-sheet workbooks) up to 10MB.
  - SQLite/PostgreSQL metadata persistence with on-disk storage for instant re-analysis without re-uploading.

---

## 🛠️ Technology Stack

| Layer | Technology |
| :--- | :--- |
| **Backend Framework** | FastAPI (Python 3.10+) |
| **Data Cleaning Engine** | Pandas, NumPy, OpenPyXL, Autonomous Structurer |
| **AI Integration** | Google GenAI SDK (`google-genai` / `gemini-flash-latest`) |
| **Database & ORM** | SQLite / PostgreSQL + SQLAlchemy ORM |
| **Mobile Client** | Flutter / Dart (^3.12.2) |
| **UI Design System** | Material 3, Dynamic Theme Provider (Dark/Light) |
| **Automated Testing** | Pytest (47/47 tests passing - 100% green) |

---

## 🔌 API Endpoints Summary

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/auto-structure` | 1-Tap clean & structure uploaded file (Multipart) |
| `POST` | `/auto-structure/{file_id}` | 1-Tap clean & structure saved library file |
| `POST` | `/analyze` | Comprehensive data diagnostic & health scoring (Multi-sheet) |
| `GET` | `/files/{file_id}/preview` | Spreadsheet table preview rows & sheet names |
| `POST` | `/preview` | Direct uploaded file spreadsheet preview rows |
| `POST` | `/ask` | Contextual Gemini AI Q&A |
| `POST` | `/edit` | Cell-level AI dataset transformations |
| `GET` | `/files` | List user's stored dataset records |

---

## 🚀 Quick Start Guide

### 1. Backend Server Setup
```bash
cd backend

# Create & activate virtual environment
python -m venv venv
# On Windows:
.\venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start FastAPI server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
*Interactive Swagger documentation available at `http://localhost:8000/docs`*

### 2. Mobile App Setup
```bash
cd mobile_app

# Install Flutter dependencies
flutter pub get

# Launch mobile application
flutter run
```

---

## 🔒 Security & Quality Policies

- Maximum file upload limit: **10MB**.
- Gemini API retries: 3 attempts with exponential backoff on server rate limits.
- Header collision safety: Automatic disambiguation for duplicate columns.
- Test Coverage: 45 automated unit and integration tests passing.

---

*AI File Assistant Repository Documentation.*
