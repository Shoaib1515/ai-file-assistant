from sqlalchemy import Column, Integer, String, DateTime, JSON, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.database import Base

class FileRecord(Base):
    """
    Represents one uploaded file's metadata in the database, plus
    where its actual content is stored on disk (storage_path) so it
    can be re-analyzed or edited later without re-uploading.
    """
    __tablename__ = "files"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)
    filename = Column(String, nullable=False)
    storage_path = Column(String, nullable=True)
    total_rows = Column(Integer, nullable=True)
    total_columns = Column(Integer, nullable=True)
    missing_values = Column(JSON, nullable=True)
    uploaded_at = Column(DateTime, default=datetime.utcnow)
    owner = relationship("User", back_populates="files")