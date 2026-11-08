from sqlalchemy import Column, Integer, String, Float, JSON, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    name = Column(String, nullable=False)
    role = Column(String, default="user", nullable=False)  # "user" 또는 "admin"
    total_sessions = Column(Integer, default=0, nullable=False)
    weakness_categories = Column(JSON, default=list, nullable=True)  # 예: ["주문 재료 품절 대응", "환불 안내"]
    average_score = Column(Float, default=0.0, nullable=False)
    current_device_id = Column(String, nullable=True) # 다중 기기 중복 로그인 방지용 디바이스 식별자
    pending_device_id = Column(String, nullable=True) # 해제 대기 후 진입할 새 기기 식별자

    reports = relationship("PracticeReportModel", back_populates="user", cascade="all, delete-orphan")

class PracticeReportModel(Base):
    __tablename__ = "practice_reports"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    scenario_id = Column(String, nullable=False)
    scenario_title = Column(String, nullable=False)
    industry = Column(String, nullable=False)
    date_time = Column(DateTime, default=datetime.utcnow, nullable=False)
    score = Column(Integer, nullable=False)
    feedback = Column(String, nullable=False)
    admin_comment = Column(String, nullable=True)  # 관리자가 남긴 코멘트
    dialogue_history = Column(JSON, default=list, nullable=False)

    user = relationship("User", back_populates="reports")

class ScenarioModel(Base):
    __tablename__ = "scenarios"

    id = Column(String, primary_key=True, index=True)
    industry = Column(String, nullable=False)
    title = Column(String, nullable=False)
    situation = Column(String, nullable=False)
    expected_actions = Column(String, nullable=False)
    linked_rules = Column(String, default="", nullable=False)
    reference_codes = Column(JSON, default=list, nullable=True)
    is_published = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class FieldCaseModel(Base):
    __tablename__ = "field_cases"

    id = Column(String, primary_key=True, index=True)
    author_id = Column(String, nullable=False)
    author_name = Column(String, nullable=False)
    industry = Column(String, nullable=False)
    title = Column(String, nullable=False)
    situation = Column(String, nullable=False)
    response_details = Column(String, nullable=False)
    status = Column(String, default="pending", nullable=False)  # pending, approved, rejected
    is_converted_to_scenario = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class ReferenceModel(Base):
    __tablename__ = "references"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    code = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    kind = Column(String, nullable=False)
    scope = Column(String, nullable=False)
    url = Column(String, default="", nullable=False)
