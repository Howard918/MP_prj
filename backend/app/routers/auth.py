from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import User
from ..schemas import UserCreate, UserLogin, UserResponse, Token
from ..security import get_password_hash, verify_password, create_access_token, get_current_user

router = APIRouter(prefix="/auth", tags=["Auth"])

# 1. [POST] /auth/register: 유저 회원가입
@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    # 이메일/아이디 중복 확인
    existing_user = db.query(User).filter(User.email == user_in.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="이미 등록된 아이디 또는 이메일입니다."
        )

    # 유저 생성 및 비밀번호 암호화
    hashed_pwd = get_password_hash(user_in.password)
    new_user = User(
        email=user_in.email,
        hashed_password=hashed_pwd,
        name=user_in.name,
        role=user_in.role if user_in.role in ["user", "admin"] else "user",
        weakness_categories=[]
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

# 2. [POST] /auth/login: 로그인 및 JWT 토큰 발급 (다중 기기 중복 로그인 제어)
@router.post("/login", response_model=Token)
def login(
    login_data: UserLogin,
    db: Session = Depends(get_db)
):
    email = login_data.email
    password = login_data.password

    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="이메일 또는 비밀번호가 올바르지 않습니다.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 다른 기기에서 이미 로그인되어 있고, force 플래그가 False인 경우 409 반환 (유저에게 의사 확인)
    if user.current_device_id and user.current_device_id != login_data.device_id and not login_data.force:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="현재 다른 기기에서 이 계정으로 로그인되어 있습니다.\n기존 기기의 접속을 해제하고 이 기기에서 새로 로그인하시겠습니까?"
        )

    # force = True이거나 최초 로그인/동일 기기인 경우 -> 새 기기 ID로 즉각 세션 갱신 및 토큰 즉시 발급!
    user.current_device_id = login_data.device_id
    user.pending_device_id = None
    db.add(user)
    db.commit()

    access_token = create_access_token(data={"sub": user.email, "role": user.role})
    return Token(access_token=access_token, token_type="bearer", device_id=login_data.device_id)

# 3. [POST] /auth/logout: 로그아웃 및 기기 세션 해제 (current_device_id = None 초기화)
@router.post("/logout", status_code=status.HTTP_200_OK)
def logout(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    current_user.current_device_id = None
    current_user.pending_device_id = None
    db.add(current_user)
    db.commit()
    return {"message": "정상적으로 로그아웃되었습니다."}
