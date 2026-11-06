from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from ..database import get_db
from ..models import User, PracticeReportModel
from ..schemas import UserResponse, PracticeReportCreate, PracticeReportResponse
from ..security import get_current_user

router = APIRouter(prefix="/users", tags=["Users"])

# 다중 기기 로그인 중복 체크 종속성 함수 (하위 호환성을 위해 device_id를 선택적으로 허용)
def get_current_active_device_user(
    device_id: Optional[str] = None,
    current_user: User = Depends(get_current_user)
) -> User:
    # 기기 ID가 제공되었고, DB에 저장된 최신 기기 ID와 다를 경우에만 중복 로그인 차단
    if device_id and current_user.current_device_id and current_user.current_device_id != device_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="다른 기기에서 동일한 유저로 로그인이 감지되었습니다.\n현재 기기에서는 로그아웃되며, 계속 이용하시려면 다시 로그인해 주세요."
        )
    return current_user

# 1. [GET] /users/me: 현재 로그인한 유저 프로필 및 훈련 데이터 반환
@router.get("/me", response_model=UserResponse)
def get_my_profile(
    device_id: Optional[str] = None,
    current_user: User = Depends(get_current_user)
):
    # 명시적 의존성 주입을 통해 기기 일치 여부 검증
    active_user = get_current_active_device_user(device_id, current_user)
    return active_user

# 2. [POST] /users/me/reports: 상황극 훈련 결과 저장 및 유저 통계 자동 업데이트
@router.post("/me/reports", response_model=PracticeReportResponse, status_code=status.HTTP_201_CREATED)
def create_practice_report(
    report_in: PracticeReportCreate,
    device_id: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    active_user = get_current_active_device_user(device_id, current_user)

    # 1. 신규 리포트 DB 저장
    report_date = report_in.date_time if report_in.date_time else datetime.utcnow()
    dialogue_data = [msg.dict() for msg in report_in.dialogue_history]

    new_report = PracticeReportModel(
        user_id=active_user.id,
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
    all_reports = db.query(PracticeReportModel).filter(PracticeReportModel.user_id == active_user.id).all()

    active_user.total_sessions = len(all_reports)
    if all_reports:
        active_user.average_score = round(sum(r.score for r in all_reports) / len(all_reports), 1)

    # 80점 미만 시 취약 카테고리에 등록
    if report_in.score < 80:
        current_weaknesses = list(active_user.weakness_categories or [])
        if report_in.scenario_title not in current_weaknesses:
            current_weaknesses.append(report_in.scenario_title)
            active_user.weakness_categories = current_weaknesses

    db.add(active_user)
    db.commit()
    db.refresh(active_user)

    return new_report

# 3. [GET] /users/me/reports: 로그인한 유저의 과거 전체 훈련 리포트 목록 조회
@router.get("/me/reports", response_model=List[PracticeReportResponse])
def get_my_reports(
    device_id: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    active_user = get_current_active_device_user(device_id, current_user)

    reports = db.query(PracticeReportModel)\
        .filter(PracticeReportModel.user_id == active_user.id)\
        .order_by(PracticeReportModel.date_time.desc())\
        .all()
    return reports
