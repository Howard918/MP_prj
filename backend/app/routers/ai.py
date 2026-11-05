from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import httpx
import json

from ..config import settings
from ..schemas import ChatMessageSchema
from ..security import get_current_user
from ..models import User

router = APIRouter(prefix="/ai", tags=["AI Proxy"])

class ChatRequest(BaseModel):
    messages: List[ChatMessageSchema]
    temperature: Optional[float] = 0.7

class EvaluationRequest(BaseModel):
    messages: List[ChatMessageSchema]
    criteria: str

# 1. [POST] /ai/chat: 백엔드에서 OpenAI Chat Completions 프록시 호출
@router.post("/chat")
async def ai_chat(
    req: ChatRequest,
    current_user: User = Depends(get_current_user)
):
    api_key = settings.OPENAI_API_KEY.strip()
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="백엔드 서버에 OPENAI_API_KEY가 설정되지 않았습니다."
        )

    headers = {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": f"Bearer {api_key}"
    }

    payload = {
        "model": "gpt-4o-mini",
        "response_format": {"type": "json_object"},
        "messages": [m.model_dump() for m in req.messages],
        "temperature": req.temperature
    }

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post("https://api.openai.com/v1/chat/completions", headers=headers, json=payload)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail=f"OpenAI API 통신 연결 실패: {str(e)}"
        )

    if resp.status_code != 200:
        raise HTTPException(
            status_code=resp.status_code,
            detail=f"OpenAI API 호출 에러: {resp.text}"
        )

    data = resp.json()
    content_str = data["choices"][0]["message"]["content"]
    return json.loads(content_str)

# 2. [POST] /ai/evaluate: 백엔드에서 상황극 최종 평가 프록시 수행
@router.post("/evaluate")
async def ai_evaluate(
    req: EvaluationRequest,
    current_user: User = Depends(get_current_user)
):
    api_key = settings.OPENAI_API_KEY.strip()
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="백엔드 서버에 OPENAI_API_KEY가 설정되지 않았습니다."
        )

    eval_system_prompt = f"""다음은 아르바이트생(user)과 고객(assistant) 간의 대화 기록입니다.

[응대 조치 기준]
{req.criteria}

위 응대 조치 기준의 [필수] 항목과 [선택] 항목을 엄격히 구분하여 다음과 같이 평가를 진행하세요:

1. **점수 산정 규칙 (필수 항목 기준)**:
   - 아르바이트생이 [필수] 항목을 **모두 이행**했다면, 최고 점수 구간인 **90~100점**을 반드시 부여하세요.
   - [필수] 항목 중 하나라도 누락되거나 이행하지 않았다면 감점하세요.

2. **선택 항목 및 피드백 규칙 (선택 항목 기준)**:
   - [선택] 항목의 이행 여부는 점수 감점 요인으로 절대 사용하지 마세요.
   - [선택] 항목은 오직 피드백 코멘트에 '더 훌륭한 응대를 위한 팁' 또는 '추가 조치에 대한 칭찬 코멘트' 형태로만 작성하세요.

100점 만점의 점수와 피드백을 아래 JSON 형식으로 반환해 주세요.
형식: {{"score": 95, "feedback": "[필수 항목 이행] 필수 지침인 정중한 사과와 대체 메뉴 제안을 완벽히 이행하여 최고 점수를 부여합니다. (선택 조언: 고객에게 소요 시간을 미리 안내해 주시면 더욱 만족스러운 응대가 될 것입니다.)"}}"""

    eval_messages = [m.model_dump() for m in req.messages] + [{"role": "system", "content": eval_system_prompt}]

    headers = {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": f"Bearer {api_key}"
    }

    payload = {
        "model": "gpt-4o-mini",
        "response_format": {"type": "json_object"},
        "messages": eval_messages
    }

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post("https://api.openai.com/v1/chat/completions", headers=headers, json=payload)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail=f"OpenAI 평가 통신 연결 실패: {str(e)}"
        )

    if resp.status_code != 200:
        raise HTTPException(
            status_code=resp.status_code,
            detail=f"OpenAI 평가 API 호출 에러: {resp.text}"
        )

    data = resp.json()
    content_str = data["choices"][0]["message"]["content"]
    return json.loads(content_str)
