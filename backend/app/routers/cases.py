from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import uuid
from datetime import datetime

from ..database import get_db
from ..models import User, FieldCaseModel
from ..schemas import FieldCaseCreate, FieldCaseResponse
from ..security import get_current_user, get_current_admin_user

router = APIRouter(prefix="/cases", tags=["Field Cases"])

# 1. [GET] /cases: 전체 현장 사례 목록 조회
@router.get("", response_model=List[FieldCaseResponse])
def get_cases(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 관리자는 전체 조회, 일반 유저는 본인이 작성한 사례만 조회하거나 정책에 따라 전체 공개 처리 가능
    if current_user.role == "admin":
        cases = db.query(FieldCaseModel).order_by(FieldCaseModel.created_at.desc()).all()
    else:
        cases = db.query(FieldCaseModel).filter(FieldCaseModel.author_id == str(current_user.id)).order_by(FieldCaseModel.created_at.desc()).all()
    return cases

# 2. [POST] /cases: 신규 현장 사례 제출 (수습생 유저)
@router.post("", response_model=FieldCaseResponse, status_code=status.HTTP_201_CREATED)
def create_case(
    case_in: FieldCaseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    case_id = case_in.id if case_in.id else str(uuid.uuid4())

    new_case = FieldCaseModel(
        id=case_id,
        author_id=str(current_user.id),
        author_name=current_user.name,
        industry=case_in.industry,
        title=case_in.title,
        situation=case_in.situation,
        response_details=case_in.response_details,
        status="pending",
        is_converted_to_scenario=False,
        created_at=datetime.utcnow()
    )
    db.add(new_case)
    db.commit()
    db.refresh(new_case)
    return new_case

# 3. [DELETE] /cases/{case_id}: 현장 사례 삭제 (관리자 및 본인만 가능)
@router.delete("/{case_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_case(
    case_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    case_record = db.query(FieldCaseModel).filter(FieldCaseModel.id == case_id).first()
    if not case_record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="현장 사례를 찾을 수 없습니다.")

    if current_user.role != "admin" and str(current_user.id) != case_record.author_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="삭제 권한이 없습니다.")

    db.delete(case_record)
    db.commit()
    return None

# 4. [PUT] /cases/{case_id}/convert: 관리자가 사례를 시나리오 변환 처리 완료로 마킹
@router.put("/{case_id}/convert", response_model=FieldCaseResponse)
def convert_case(
    case_id: str,
    db: Session = Depends(get_db),
    admin_user: User = Depends(get_current_admin_user)
):
    case_record = db.query(FieldCaseModel).filter(FieldCaseModel.id == case_id).first()
    if not case_record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="현장 사례를 찾을 수 없습니다.")

    case_record.status = "approved"
    case_record.is_converted_to_scenario = True
    db.add(case_record)
    db.commit()
    db.refresh(case_record)
    return case_record
