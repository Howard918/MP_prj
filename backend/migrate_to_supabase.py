import os
import sys
import sqlite3
import json
import subprocess
from datetime import datetime

# 💡 파이썬 실행 환경에 psycopg2-binary 패키지가 없을 경우 스크립트 내부에서 자동 즉시 설치
def auto_install_deps():
    try:
        import psycopg2
    except ImportError:
        print("🔧 파이썬 실행 환경에 psycopg2-binary 패키지를 자동 설치하고 있습니다...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary"])
            print("✅ psycopg2-binary 자동 설치 완료!")
        except Exception as e:
            print(f"⚠️ 패키지 자동 설치 안내: {sys.executable} -m pip install psycopg2-binary")

auto_install_deps()

from sqlalchemy import create_engine, text

# backend 경로 추가
backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.config import settings
from app.models import Base

def run_migration(target_db_url=None):
    local_db_path = os.path.join(backend_dir, "sql_app.db")
    if not os.path.exists(local_db_path):
        print(f"❌ 로컬 PC DB 파일({local_db_path})을 찾을 수 없습니다.")
        return

    db_url = target_db_url if target_db_url else settings.DATABASE_URL
    if not db_url or "sqlite" in db_url:
        print("⚠️ DATABASE_URL 환경변수가 Supabase 주소로 설정되지 않았습니다.")
        print("사용법: python migrate_to_supabase.py postgresql://postgres.xxx:비밀번호@aws-0-ap-northeast-1.pooler.supabase.com:6543/postgres")
        return

    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql+psycopg2://", 1)
    elif db_url.startswith("postgresql://") and not db_url.startswith("postgresql+"):
        db_url = db_url.replace("postgresql://", "postgresql+psycopg2://", 1)

    print(f"🚀 Supabase PostgreSQL DB 연결 시도 중...\nTarget: {db_url.split('@')[-1] if '@' in db_url else db_url}")

    try:
        engine = create_engine(db_url, pool_pre_ping=True)
        Base.metadata.create_all(bind=engine)
    except Exception as e:
        print(f"❌ Supabase DB 연결 실패: {e}")
        return

    local_conn = sqlite3.connect(local_db_path)
    local_conn.row_factory = sqlite3.Row
    local_cursor = local_conn.cursor()

    tables = ["categories", "users", "scenarios", "field_cases", "practice_reports", "references"]

    for table in tables:
        try:
            # SQL 예약어("references" 등) 및 테이블명 큰따옴표 이스케이프 처리
            local_cursor.execute(f'SELECT * FROM "{table}"')
            rows = local_cursor.fetchall()
            if not rows:
                print(f"  [{table}] 로컬 PC에 데이터가 없습니다.")
                continue

            col_names = list(rows[0].keys())
            cols_str = ", ".join([f'"{c}"' for c in col_names])
            val_placeholders = ", ".join([f":{col}" for col in col_names])

            insert_sql = text(f'INSERT INTO "{table}" ({cols_str}) VALUES ({val_placeholders}) ON CONFLICT DO NOTHING')

            count = 0
            with engine.begin() as pg_conn:
                # users 테이블 이전 시 기존 단일 admin 계정을 세척하고 수습생(user)과 관리자(admin) 2개 계정을 깔끔히 재등록
                if table == "users":
                    try:
                        pg_conn.execute(text('DELETE FROM "practice_reports"'))
                        pg_conn.execute(text('DELETE FROM "users"'))
                    except Exception:
                        pass

                for row in rows:
                    row_dict = dict(row)

                    # 💡 1. Boolean 변환 (SQLite 정수 0/1 -> 파이썬 True/False)
                    if "is_published" in row_dict and row_dict["is_published"] is not None:
                        row_dict["is_published"] = bool(row_dict["is_published"])
                    if "is_converted_to_scenario" in row_dict and row_dict["is_converted_to_scenario"] is not None:
                        row_dict["is_converted_to_scenario"] = bool(row_dict["is_converted_to_scenario"])

                    # 💡 2. PostgreSQL JSON 칼럼 규격화 (json.dumps 문자열 포매팅)
                    for json_col in ["reference_codes", "weakness_categories", "dialogue_history"]:
                        if json_col in row_dict:
                            val = row_dict[json_col]
                            if val is None:
                                row_dict[json_col] = "[]"
                            elif isinstance(val, (list, dict)):
                                row_dict[json_col] = json.dumps(val, ensure_ascii=False)
                            elif isinstance(val, str):
                                v_str = val.strip()
                                if v_str.startswith("[") or v_str.startswith("{"):
                                    try:
                                        parsed = json.loads(v_str)
                                        row_dict[json_col] = json.dumps(parsed, ensure_ascii=False)
                                    except Exception:
                                        row_dict[json_col] = "[]"
                                else:
                                    row_dict[json_col] = json.dumps([v_str] if v_str else [], ensure_ascii=False)

                    pg_conn.execute(insert_sql, row_dict)
                    count += 1

            print(f"  ✅ [{table}] {count}개 데이터 Supabase 이전 성공!")
        except Exception as e:
            print(f"  ⚠️ [{table}] 마이그레이션 예외: {e}")

    print("\n🎉 로컬 PC DB 데이터가 Supabase PostgreSQL로 성공적으로 이전 업로드되었습니다!")

if __name__ == "__main__":
    url_arg = sys.argv[1] if len(sys.argv) > 1 else None
    run_migration(url_arg)
