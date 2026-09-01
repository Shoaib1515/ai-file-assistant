import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv, find_dotenv

# Load environment variables from .env file.
dotenv_path = find_dotenv()
if not dotenv_path:
    dotenv_path = os.path.join(os.path.dirname(__file__), "..", "..", ".env")
load_dotenv(dotenv_path)

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./sql_app.db")
connect_args = {"check_same_thread": False} if "sqlite" in DATABASE_URL else {}
engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """
    Provides a database session for a single request, and always
    closes it afterward — even if an error occurs.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()