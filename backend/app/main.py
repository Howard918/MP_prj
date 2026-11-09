import sys
import os
import uvicorn
import socket
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import text, inspect

# backend 경로를 sys.path에 추가하여 어디서 실행하든 모듈 임포트 에러 방지
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.database import engine, Base, SessionLocal
from app.models import User, ScenarioModel, ReferenceModel, CategoryModel
from app.security import get_password_hash
from app.routers import auth, users, admin, scenarios, cases, ai, docs

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
app.include_router(cases.router)
app.include_router(ai.router)
app.include_router(docs.router)

def get_active_local_ip() -> str:
    """현재 PC가 연결된 활성 Wi-Fi / AP의 실시간 IPv4 주소를 자동 감지합니다."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except Exception:
        try:
            return socket.gethostbyname(socket.gethostname())
        except Exception:
            return "127.0.0.1"

def update_flutter_api_config(active_ip: str):
    """Render 배포 고정 클라우드 주소 유지"""
    pass

# Cross-Database 멀티 DB 스키마 자동 마이그레이션 (SQLite & PostgreSQL 표준 호환)
def migrate_db_schema():
    db: Session = SessionLocal()
    try:
        inspector = inspect(engine)

        # 1. practice_reports 테이블 컬럼 검증
        if inspector.has_table("practice_reports"):
            pr_columns = [col["name"] for col in inspector.get_columns("practice_reports")]
            if "admin_comment" not in pr_columns:
                db.execute(text("ALTER TABLE practice_reports ADD COLUMN admin_comment TEXT"))
                db.commit()
            if "category" not in pr_columns:
                db.execute(text("ALTER TABLE practice_reports ADD COLUMN category TEXT"))
                db.commit()

        # 2. users 테이블 컬럼 검증
        if inspector.has_table("users"):
            user_columns = [col["name"] for col in inspector.get_columns("users")]
            if "current_device_id" not in user_columns:
                db.execute(text("ALTER TABLE users ADD COLUMN current_device_id TEXT"))
                db.commit()
            if "pending_device_id" not in user_columns:
                db.execute(text("ALTER TABLE users ADD COLUMN pending_device_id TEXT"))
                db.commit()

        # 3. scenarios 테이블 컬럼 검증
        if inspector.has_table("scenarios"):
            sc_columns = [col["name"] for col in inspector.get_columns("scenarios")]
            if "category" not in sc_columns:
                db.execute(text("ALTER TABLE scenarios ADD COLUMN category TEXT"))
                db.commit()

        # 4. field_cases 테이블 컬럼 검증
        if inspector.has_table("field_cases"):
            fc_columns = [col["name"] for col in inspector.get_columns("field_cases")]
            if "category" not in fc_columns:
                db.execute(text("ALTER TABLE field_cases ADD COLUMN category TEXT"))
                db.commit()

    except Exception as e:
        print(f"DB Migration Note: {e}")
    finally:
        db.close()

# 서버 시동 시 초기 시드 데이터 생성 및 AP 자동 IP 감지 배너 출력
@app.on_event("startup")
def seed_initial_data():
    active_ip = get_active_local_ip()
    update_flutter_api_config(active_ip)

    print("\n" + "=" * 65)
    print("🚀 첫 근무 노트 백엔드 API 서버가 활성화되었습니다!")
    print(f"📱 실기기(스마트폰 Wi-Fi/AP) 접속 주소: http://{active_ip}:8000")
    print(f"💻 안드로이드 에뮬레이터 접속 주소:   http://10.0.2.2:8000")
    print(f"🖥️ PC 로컬 웹/데스크톱 접속 주소:      http://localhost:8000")
    print("=" * 65 + "\n")

    migrate_db_schema()  # DB 스키마 마이그레이션 우선 실행
    docs.preload_all_pdf_caches()  # 💡 백그라운드에서 모든 docx 문서를 MS Word 원본 100% 동일 PDF로 사전 캐싱!

    db: Session = SessionLocal()
    try:
        # 서버 재구동 시 잔여 고스트 세션 자동 세척 (미해제 current_device_id 초기화)
        try:
            db.execute(text("UPDATE users SET current_device_id = NULL"))
            db.commit()
        except Exception:
            pass

        # 기본 시스템 관리자 계정('admin') 및 기본 수습생 계정('user') 자동 생성
        if not db.query(User).filter(User.email == "admin").first():
            db.add(User(
                email="admin",
                hashed_password=get_password_hash("admin123"),
                name="매장 점주(관리자)",
                role="admin",
                total_sessions=0,
                weakness_categories=[],
                average_score=0.0
            ))

        if not db.query(User).filter(User.email == "user").first():
            db.add(User(
                email="user",
                hashed_password=get_password_hash("user123"),
                name="수습 알바생",
                role="user",
                total_sessions=0,
                weakness_categories=[],
                average_score=0.0
            ))
        db.commit()

        # 기본 업무 카테고리 시드 데이터 자동 생성
        default_cats = ['음료/메뉴', '고객 서비스', '안전/비상대응', '위생/식품안전', 'POS/금전정산', '시설/장비관리']
        for cat_name in default_cats:
            if not db.query(CategoryModel).filter(CategoryModel.name == cat_name).first():
                db.add(CategoryModel(name=cat_name))
        db.commit()

        # 업무 카테고리 매핑 테이블
        category_mapping = {
            'c-01': '음료/메뉴', 'c-02': '음료/메뉴', 'r-01': '음료/메뉴', 'cafe_out_of_stock_01': '음료/메뉴',
            'c-03': '위생/식품안전', 'cv-02': '위생/식품안전', 'r-02': '위생/식품안전', 'r-03': '위생/식품안전', 'store_expired_01': '위생/식품안전',
            'c-04': '고객 서비스', 'cv-01': '고객 서비스', 'cv-04': '고객 서비스', 'r-05': '고객 서비스',
            'cv-05': '안전/비상대응', 'r-04': '안전/비상대응',
            'c-05': '시설/장비관리',
            'cv-03': 'POS/금전정산'
        }

        # 초기 시나리오 시드 데이터 및 카테고리 자동 최신화
        json_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "data", "scenarios.json"))
        if os.path.exists(json_path):
            try:
                with open(json_path, "r", encoding="utf-8") as f:
                    sc_data = json.load(f)
                for sc in sc_data:
                    existing = db.query(ScenarioModel).filter(ScenarioModel.id == sc["id"]).first()
                    cat = category_mapping.get(sc["id"], "고객 서비스")
                    if not existing:
                        db.add(ScenarioModel(
                            id=sc["id"],
                            category=cat,
                            industry="매장 운영",
                            title=sc.get("title", ""),
                            situation=sc.get("situation", ""),
                            expected_actions=sc.get("expectedActions", ""),
                            linked_rules=sc.get("linkedRules", ""),
                            reference_codes=sc.get("referenceCodes", []),
                            is_published=sc.get("isPublished", True)
                        ))
                    elif not existing.category:
                        existing.category = cat
                        db.add(existing)
                db.commit()
            except Exception as e:
                print(f"시나리오 시드 로드 예외: {e}")

        # 초기 법령/공식 근거 레퍼런스 시드 데이터 (assets/data/references.json 자동 로드)
        ref_json_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "data", "references.json"))
        if os.path.exists(ref_json_path):
            try:
                with open(ref_json_path, "r", encoding="utf-8") as f:
                    ref_data = json.load(f)
                for rf in ref_data:
                    existing = db.query(ReferenceModel).filter(ReferenceModel.code == rf["code"]).first()
                    if not existing:
                        db.add(ReferenceModel(
                            code=rf["code"],
                            name=rf.get("name", ""),
                            kind=rf.get("kind", ""),
                            scope=rf.get("scope", ""),
                            url=rf.get("url", "")
                        ))
                db.commit()
            except Exception as e:
                print(f"레퍼런스 시드 로드 예외: {e}")

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
