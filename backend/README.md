# 첫 근무 노트 - FastAPI 백엔드 서버

Flutter 앱과 통신하여 유저 인증(JWT), 프로필 관리, 훈련 데이터 저장, 관리자 전용 유저 조회를 담당하는 FastAPI 백엔드 서버입니다.

---

## 🛠️ 기술 스택
- **프레임워크**: FastAPI
- **데이터베이스**: SQLite (SQLAlchemy 2.0 ORM)
- **인증**: JWT (PyJWT), bcrypt (`passlib`)
- **설정 및 스키마**: Pydantic v2, Pydantic-Settings

---

## 🚀 실행 방법

### 1. 가상환경 생성 및 의존성 설치
```bash
# backend 폴더로 이동
cd backend

# 가상환경 생성 (최초 1회)
python -m venv venv

# 가상환경 활성화
# Windows PowerShell:
.\venv\Scripts\Activate.ps1
# Mac/Linux:
source venv/bin/activate

# 필수 패키지 설치
pip install -r requirements.txt
```

### 2. 서버 실행
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

서버가 실행되면 브라우저에서 자동 생성된 Swagger API 문서를 확인하실 수 있습니다:
- **API 문서 (Swagger UI)**: `http://localhost:8000/docs`
- **대체 문서 (ReDoc)**: `http://localhost:8000/redoc`

---

## 🔑 초기 생성 테스트 계정 (DB Seed)
서버 시동 시 아래 테스트 계정이 자동으로 SQLite 데이터베이스에 생성됩니다:

| 분류 | 이메일 (ID) | 비밀번호 | 이름 | 역할 (Role) |
| :--- | :--- | :--- | :--- | :--- |
| **일반 유저** | `user@example.com` | `user123` | 수습 알바생 | `user` |
| **관리자** | `admin@example.com` | `admin123` | 매장 점주(관리자) | `admin` |

---

## 📡 주요 엔드포인트 요약

1. **`POST /auth/register`**: 회원가입 (이메일 중복 체크)
2. **`POST /auth/login`**: 로그인 (JWT 액세스 토큰 반환)
3. **`GET /users/me`**: 현재 로그인된 유저 프로필 및 훈련 정보 조회 (`Bearer Token` 필요)
4. **`GET /admin/users`**: 관리자 전용 전체 유저 목록 조회 (`admin` 권한 검증)
