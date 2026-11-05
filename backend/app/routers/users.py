from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

from ..database import get_db
from ..models import User, PracticeReportModel
from ..schemas import UserResponse, PracticeReportCreate, PracticeReportResponse
from ..security import get_current_user

router = APIRouter(prefix="/users", tags=["Users"])

# 1. [GET] /users/me: 현재 로그인한 유저 프로필 및 훈련 데이터 반환
@router.get("/me", response_model=UserResponse)
def get_my_profile(current_user: User = Depends(get_current_user)):
    return current_user

# 2. [POST] /users/me/reports: 상황극 훈련 결과 저장 및 유저 통계 자동 업데이트
@router.post("/me/reports", response_model=PracticeReportResponse, status_code=status.HTTP_201_CREATED)
def create_practice_report(
    report_in: PracticeReportCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # 1. 신규 리포트 DB 저장
    report_date = report_in.date_time if report_in.date_time else datetime.utcnow()
    dialogue_data = [msg.dict() for msg in report_in.dialogue_history]

    new_report = PracticeReportModel(
        user_id=current_user.id,
        scenario_id=report_in.scenario_id,
        scenario_title=report_in.scenario_title,
        industry=report_in.industry,
        date_time=report_date,
        score=report_in.score,
        feedback=report_in.feedback,
        dialogue_history=dialogue_data
    )
    db.add(new_report)
    db.commit()
    db.refresh(new_report)

    # 2. 유저 통계 데이터 자동 재계산 및 갱신 (영구 저장)
    all_reports = db.query(PracticeReportModel).filter(PracticeReportModel.user_id == current_user.id).all()

    current_user.total_sessions = len(all_reports)
    if all_reports:
        current_user.average_score = round(sum(r.score for r in all_reports) / len(all_reports), 1)

    # 80점 미만 시 취약 카테고리에 등록
    if report_in.score < 80:
        current_weaknesses = list(current_user.weakness_categories or [])
        if report_in.scenario_title not in current_weaknesses:
            current_weaknesses.append(report_in.scenario_title)
            current_user.weakness_categories = current_weaknesses

    db.add(current_user)
    db.commit()
    db.refresh(current_user)

    return new_report

# 3. [GET] /users/me/reports: 로그인한 유저의 과거 전체 훈련 리포트 목록 조회
@router.get("/me/reports", response_model=List[PracticeReportResponse])
def get_my_reports(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    reports = db.query(PracticeReportModel)\
        .filter(PracticeReportModel.user_id == current_user.id)\
        .order_by(PracticeReportModel.date_time.desc())\
        .all()
    return reports
