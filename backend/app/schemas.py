from pydantic import BaseModel, ConfigDict
from typing import List, Optional
from datetime import datetime

# 회원가입 요청 스키마 (이메일 및 아이디 겸용 지원)
class UserCreate(BaseModel):
    email: str  # 이메일 주소 또는 유저 아이디 (예: user, admin, user@example.com)
    password: str
    name: str
    role: Optional[str] = "user"  # "user" 또는 "admin"

# 로그인 요청 스키마
class UserLogin(BaseModel):
    email: str  # 이메일 주소 또는 유저 아이디
    password: str

# JWT 토큰 응답 스키마
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class TokenData(BaseModel):
    email: Optional[str] = None

# 대화 메시지 내역 스키마
class ChatMessageSchema(BaseModel):
    role: str
    content: str

# 훈련 연습 리포트 생성 스키마
class PracticeReportCreate(BaseModel):
    scenario_id: str
    scenario_title: str
    industry: str
    date_time: Optional[datetime] = None
    score: int
    feedback: str
    admin_comment: Optional[str] = None
    dialogue_history: List[ChatMessageSchema] = []

# 훈련 연습 리포트 응답 스키마
class PracticeReportResponse(BaseModel):
    id: int
    user_id: int
    scenario_id: str
    scenario_title: str
    industry: str
    date_time: datetime
    score: int
    feedback: str
    admin_comment: Optional[str] = None
    dialogue_history: List[ChatMessageSchema] = []

    model_config = ConfigDict(from_attributes=True)

# 관리자 리포트 코멘트 입력 스키마
class AdminCommentUpdate(BaseModel):
    admin_comment: str

# 시나리오 요청/응답 스키마
class ScenarioCreate(BaseModel):
    id: Optional[str] = None
    industry: str
    title: str
    situation: str
    expected_actions: str
    linked_rules: Optional[str] = ""
    reference_codes: Optional[List[str]] = []
    is_published: Optional[bool] = True

class ScenarioResponse(BaseModel):
    id: str
    industry: str
    title: str
    situation: str
    expected_actions: str
    linked_rules: str
    reference_codes: List[str] = []
    is_published: bool

    model_config = ConfigDict(from_attributes=True)

# 유저 프로필 응답 스키마 (Flutter 앱 호환)
class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    role: str
    total_sessions: int = 0
    weakness_categories: List[str] = []
    average_score: float = 0.0

    model_config = ConfigDict(from_attributes=True)
