import sys
import os
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import text

# backend 경로를 sys.path에 추가하여 어디서 실행하든 모듈 임포트 에러 방지
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.database import engine, Base, SessionLocal
from app.models import User, ScenarioModel
from app.security import get_password_hash
from app.routers import auth, users, admin, scenarios, ai

# 데이터베이스 테이블 생성
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="첫 근무 노트 - AI 상황극 훈련 앱 API Server",
    version="1.0.0",
    description="Flutter 앱 통신을 위한 FastAPI 백엔드 서버"
)

# CORS 미들웨어 설정 (Flutter 앱 웹/모바일 통신 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Flutter 웹 및 모바일 앱 CORS 허용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(admin.router)
app.include_router(scenarios.router)
app.include_router(ai.router)

# SQLite 데이터베이스 자동 마이그레이션 (기존 DB에 신규 컬럼 추가)
def migrate_db_schema():
    db: Session = SessionLocal()
    try:
        result = db.execute(text("PRAGMA table_info(practice_reports)"))
        columns = [row[1] for row in result.fetchall()]

        if "admin_comment" not in columns:
            db.execute(text("ALTER TABLE practice_reports ADD COLUMN admin_comment TEXT"))
            db.commit()
            print("DB Migration: 'admin_comment' column added to 'practice_reports' table successfully.")
    except Exception as e:
        print(f"DB Migration Note: {e}")
    finally:
        db.close()

# 서버 시동 시 초기 시드 데이터 생성 (정식 회원가입 및 DB로 전면 관리되므로 하드코딩 더미 유저 생성 삭제)
@app.on_event("startup")
def seed_initial_data():
    migrate_db_schema()  # DB 스키마 마이그레이션 우선 실행

    db: Session = SessionLocal()
    try:
        # 최초 시스템 관리자 계정이 전혀 없을 때만 기본 'admin' 계정 단 1개 생성 (비밀번호: admin123)
        if not db.query(User).filter(User.role == "admin").first():
            db.add(User(
                email="admin",
                hashed_password=get_password_hash("admin123"),
                name="매장 점주(관리자)",
                role="admin",
                total_sessions=0,
                weakness_categories=[],
                average_score=0.0
            ))

        # 초기 시나리오 시드 데이터 (최초 DB 생성 시에만 1회 등록)
        if db.query(ScenarioModel).count() == 0:
            initial_scenarios = [
                ScenarioModel(
                    id="cafe_out_of_stock_01",
                    industry="카페",
                    title="주문 재료 품절 및 변경 안내",
                    situation="고객이 시그니처 딸기 라떼를 주문했지만, 딸기 청 재고가 모두 소진되어 판매할 수 없는 상황입니다.",
                    expected_actions="[필수] 재고 소진 상황에 대한 정중한 사과\n[필수] 품절 사유 및 대체 유사 음료(자몽 라떼 등) 추천\n[선택] 음료 제공 지연 시 대기 안내 및 정중한 인사",
                    linked_rules="식품위생법 관련 지침; 매장 재고 관리 규칙",
                    reference_codes=["REF_01"],
                    is_published=True
                ),
                ScenarioModel(
                    id="store_expired_01",
                    industry="편의점",
                    title="유통기한 마감 임박 상품 문의 및 환불 안내",
                    situation="고객이 구매하려는 삼각김밥의 유통기한 마감 시각이 10분 남았다며 교환이나 할인을 요청하는 상황입니다.",
                    expected_actions="[필수] 유통기한 기준 및 판매 가능 시간 규정 안내\n[필수] 신선도 보장 및 최신 입고 상품 위치 정중 안내\n[선택] 영수증 지참 시 환불 규정 추가 설명",
                    linked_rules="유통기한 및 교환/환불 규정",
                    reference_codes=["REF_02"],
                    is_published=True
                )
            ]
            for sc in initial_scenarios:
                db.add(sc)

        db.commit()
    finally:
        db.close()

@app.get("/", tags=["Health"])
def root():
    return {
        "message": "첫 근무 노트 AI 상황극 훈련 백엔드 API 서버가 정상 실행 중입니다.",
        "docs_url": "/docs"
    }

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
