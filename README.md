# 🤖 AI File Assistant

A modern, cross-platform mobile application and FastAPI backend that enables natural-language dataset analysis, AI-powered Q&A, and safe cell-level dataset editing for CSV and Excel files using Google Gemini Flash AI.

---

## 🌟 Key Features

- 📂 **Multi-Format Dataset Upload**: Accepts `.csv` and `.xlsx`/`.xls` datasets up to 10MB.
- 📊 **Automated Health Diagnostic**: Instantly detects missing values per column and duplicate rows with capped sample previews.
- 💬 **Context-Aware AI Chatbot**: Interactive Q&A on dataset metrics powered by Google Gemini AI (`gemini-flash-latest`).
- ✍️ **AI-Assisted Safe Editing**: 
  - User submits natural language edit instructions (e.g. *"Format phone numbers with country code"*).
  - Gemini AI proposes JSON cell-level changes.
  - User reviews/approves changes before Pandas writes back updated `.xlsx` output.
- 💾 **Database & Disk Persistence**: Records dataset metadata in SQLite/SQLAlchemy and persists files on disk for session restore.
- 🔄 **Re-analysis Without Re-upload**: Full backend file-id endpoints (`/files/{file_id}/*`) for analyzing and editing stored files across app restarts.

---

## 🛠️ Technology Stack

| Layer | Technology |
| :--- | :--- |
| **Backend Framework** | FastAPI (Python 3.10+) |
| **Data Engine** | Pandas, NumPy, OpenPyXL |
| **AI Integration** | Google GenAI SDK (`google-genai` / `gemini-flash-latest`) |
| **Database** | SQLite + SQLAlchemy ORM |
| **Mobile Client** | Flutter / Dart (^3.12.2) |
| **UI Design System** | Material 3, Custom AppTheme, Custom Color Tokens |
| **Networking** | `http` Dart Package |

---

## 🚀 Quick Start Guide

### Prerequisites
- Python 3.10+
- Flutter SDK 3.12+
- Google Gemini API Key ([Get Key Here](https://aistudio.google.com/))

### 1. Backend Server Setup
```bash
cd backend

# Create & activate virtual environment
python -m venv venv
# On Windows:
.\venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment variables in .env
# DATABASE_URL=sqlite:///./sql_app.db
# GEMINI_API_KEY=your_actual_gemini_api_key

# Start FastAPI server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
*API documentation available at `http://localhost:8000/docs`*

### 2. Mobile App Setup
```bash
cd mobile_app

# Install dependencies
flutter pub get

# Configure backend IP address in lib/services/api_service.dart
# static const String baseUrl = "http://<YOUR_LOCAL_IP>:8000";

# Launch application
flutter run
```

---

## 📚 Complete Project Documentation Suite

All detailed project documentation files are ready:

- 📑 **[Project Handover Document](./project_handover_document.md)**: Architectural specifications, DB schemas, sequence diagrams, and environment setup.
- 📁 **[Project File Structure & Code Breakdown](./project_file_structure.md)**: Exhaustive breakdown of every backend python module and mobile screen.
- 📊 **[Master Project Status & Production Roadmap](./project_status_roadmap.md)**: Full completion scorecard (100% MVP functional), gap matrix, and release roadmap.

---

## 🔒 Security & Performance Policies

- Maximum file upload limit: **10MB**.
- Gemini API retries: 3 attempts with exponential backoff on server rate limits.
- Leading zeros preservation: Automated string casting in `editor.py` for numeric formatting.

---

*AI File Assistant Repository Documentation.*
