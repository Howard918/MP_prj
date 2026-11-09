from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base
from .config import settings

db_url = settings.DATABASE_URL
if db_url:
    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql+psycopg2://", 1)
    elif db_url.startswith("postgresql://") and not db_url.startswith("postgresql+"):
        db_url = db_url.replace("postgresql://", "postgresql+psycopg2://", 1)

connect_args = {"check_same_thread": False} if "sqlite" in db_url else {}

try:
    engine = create_engine(
        db_url,
        connect_args=connect_args,
        pool_pre_ping=True
    )
    # 💡 DB 접속 사전 검증 (접속 불가 시 서버 다운 방지)
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    print(f"Database connected successfully using: {db_url.split('@')[-1] if '@' in db_url else db_url}")
except Exception as e:
    print(f"⚠️ PostgreSQL DB 접속 실패 ({e}). 기본 SQLite DB(sqlite:///./sql_app.db)로 자동 안전 전환합니다.")
    db_url = "sqlite:///./sql_app.db"
    engine = create_engine(
        db_url,
        connect_args={"check_same_thread": False}
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# DB 세션 의존성 주입 (Dependency)
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
