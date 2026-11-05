from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..models import User, PracticeReportModel
from ..schemas import UserResponse, PracticeReportResponse, AdminCommentUpdate
from ..security import get_current_admin_user

router = APIRouter(prefix="/admin", tags=["Admin"])

# 1. [GET] /admin/users: 관리자 전용 전체 유저 목록 조회
@router.get("/users", response_model=List[UserResponse])
def get_all_users(
    db: Session = Depends(get_db),
    admin_user: User = Depends(get_current_admin_user)
):
    users = db.query(User).order_by(User.id.asc()).all()
    return users

# 2. [GET] /admin/users/{user_id}/reports: 특정 유저의 상황극 훈련 진행 데이터/리포트 조회
@router.get("/users/{user_id}/reports", response_model=List[PracticeReportResponse])
def get_user_reports(
    user_id: int,
    db: Session = Depends(get_db),
    admin_user: User = Depends(get_current_admin_user)
):
    target_user = db.query(User).filter(User.id == user_id).first()
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="해당 유저를 찾을 수 없습니다."
        )

    reports = db.query(PracticeReportModel)\
        .filter(PracticeReportModel.user_id == user_id)\
        .order_by(PracticeReportModel.date_time.desc())\
        .all()
    return reports

# 3. [DELETE] /admin/users/{user_id}: 특정 유저 회원 탈퇴/삭제
@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    admin_user: User = Depends(get_current_admin_user)
):
    if admin_user.id == user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="현재 진행 중인 본인 관리자 계정은 삭제할 수 없습니다."
        )

    target_user = db.query(User).filter(User.id == user_id).first()
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="해당 유저를 찾을 수 없습니다."
        )

    db.delete(target_user)
    db.commit()
    return None

# 4. [PUT] /admin/reports/{report_id}/comment: 관리자가 유저의 특정 훈련 리포트에 피드백 코멘트 등록/수정
@router.put("/reports/{report_id}/comment", response_model=PracticeReportResponse)
def update_report_admin_comment(
    report_id: int,
    comment_in: AdminCommentUpdate,
    db: Session = Depends(get_db),
    admin_user: User = Depends(get_current_admin_user)
):
    report = db.query(PracticeReportModel).filter(PracticeReportModel.id == report_id).first()
    if not report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="해당 리포트를 찾을 수 없습니다."
        )

    report.admin_comment = comment_in.admin_comment
    db.add(report)
    db.commit()
    db.refresh(report)
    return report
