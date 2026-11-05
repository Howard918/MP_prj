from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid

from ..database import get_db
from ..models import User, ScenarioModel
from ..schemas import ScenarioCreate, ScenarioResponse
from ..security import get_current_user, get_current_admin_user

router = APIRouter(prefix="/scenarios", tags=["Scenarios"])

# 1. [GET] /scenarios: 시나리오 목록 조회 (공개/비공개 전체 또는 필터)
@router.get("", response_model=List[ScenarioResponse])
def get_scenarios(
    db: Session = Depends(get_db)
):
    scenarios = db.query(ScenarioModel).all()
    return scenarios

# 2. [POST] /scenarios: 신규 시나리오 생성 (관리자 전용)
@router.post("", response_model=ScenarioResponse, status_code=status.HTTP_201_CREATED)
def create_scenario(
    scenario_in: ScenarioCreate,
    db: Session = Depends(get_db),
    admin_user: User = Depends(get_current_admin_user)
):
    scenario_id = scenario_in.id if scenario_in.id else str(uuid.uuid4())

    new_scenario = ScenarioModel(
        id=scenario_id,
        industry=scenario_in.industry,
        title=scenario_in.title,
        situation=scenario_in.situation,
        expected_actions=scenario_in.expected_actions,
        linked_rules=scenario_in.linked_rules if scenario_in.linked_rules else "",
        reference_codes=scenario_in.reference_codes if scenario_in.reference_codes else [],
        is_published=scenario_in.is_published if scenario_in.is_published is not None else True
    )
    db.add(new_scenario)
    db.commit()
    db.refresh(new_scenario)
    return new_scenario

# 3. [PUT] /scenarios/{scenario_id}: 시나리오 수정 및 업서트 (관리자 전용)
@router.put("/{scenario_id}", response_model=ScenarioResponse)
def update_scenario(
    scenario_id: str,
    scenario_in: ScenarioCreate,
    db: Session = Depends(get_db),
    admin_user: User = Depends(get_current_admin_user)
):
    scenario = db.query(ScenarioModel).filter(ScenarioModel.id == scenario_id).first()
    # 기존 DB에 시나리오가 없던 기본 시나리오인 경우 생성(Upsert) 처리
    if not scenario:
        scenario = ScenarioModel(id=scenario_id)

    scenario.industry = scenario_in.industry
    scenario.title = scenario_in.title
    scenario.situation = scenario_in.situation
    scenario.expected_actions = scenario_in.expected_actions
    scenario.linked_rules = scenario_in.linked_rules if scenario_in.linked_rules is not None else ""
    scenario.reference_codes = scenario_in.reference_codes if scenario_in.reference_codes is not None else []
    scenario.is_published = scenario_in.is_published if scenario_in.is_published is not None else True

    db.add(scenario)
    db.commit()
    db.refresh(scenario)
    return scenario

# 4. [DELETE] /scenarios/{scenario_id}: 시나리오 삭제 (관리자 전용)
@router.delete("/{scenario_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_scenario(
    scenario_id: str,
    db: Session = Depends(get_db),
    admin_user: User = Depends(get_current_admin_user)
):
    scenario = db.query(ScenarioModel).filter(ScenarioModel.id == scenario_id).first()
    if not scenario:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="시나리오를 찾을 수 없습니다.")

    db.delete(scenario)
    db.commit()
    return None
