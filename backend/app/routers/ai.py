from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional
import urllib.request
import urllib.error
import json
import asyncio
import math
import os
import zipfile
import xml.etree.ElementTree as ET

from ..config import settings
from ..schemas import ChatMessageSchema, SearchRequest, RagResponseSchema
from ..security import get_current_user
from ..models import User

router = APIRouter(prefix="/ai", tags=["AI Proxy"])

class ChatRequest(BaseModel):
    messages: List[ChatMessageSchema]
    temperature: Optional[float] = 0.7

class EvaluationRequest(BaseModel):
    messages: List[ChatMessageSchema]
    criteria: str

# 파이썬 표준 라이브러리(urllib)를 활용한 동기식 OpenAI API 호출 헬퍼
def _call_openai_api_sync(url: str, payload: dict, timeout_sec: float = 20.0) -> dict:
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

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=timeout_sec) as response:
            body = response.read().decode("utf-8")
            return json.loads(body)
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="ignore")
        raise HTTPException(status_code=e.code, detail=f"OpenAI API 에러: {err_body}")
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail=f"OpenAI API 통신 연결 실패: {str(e)}"
        )

# 1. [POST] /ai/chat: 백엔드에서 OpenAI Chat Completions 프록시 호출
@router.post("/chat")
async def ai_chat(req: ChatRequest, current_user: User = Depends(get_current_user)):
    payload = {
        "model": "gpt-4o-mini",
        "response_format": {"type": "json_object"},
        "messages": [m.model_dump() for m in req.messages],
        "temperature": req.temperature
    }
    result = await asyncio.to_thread(_call_openai_api_sync, "https://api.openai.com/v1/chat/completions", payload, 15.0)
    content_str = result["choices"][0]["message"]["content"]
    return json.loads(content_str)

# 2. [POST] /ai/evaluate: 백엔드에서 상황극 최종 평가 프록시 수행
@router.post("/evaluate")
async def ai_evaluate(req: EvaluationRequest, current_user: User = Depends(get_current_user)):
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

    payload = {
        "model": "gpt-4o-mini",
        "response_format": {"type": "json_object"},
        "messages": eval_messages
    }
    result = await asyncio.to_thread(_call_openai_api_sync, "https://api.openai.com/v1/chat/completions", payload, 20.0)
    content_str = result["choices"][0]["message"]["content"]
    return json.loads(content_str)


# -------------------------------------------------------------------------
# 원본 DOCX 문서 기반 RAG 파이프라인 전용 인메모리 벡터 저장소
# -------------------------------------------------------------------------
def extract_docx_paragraphs(docx_path: str) -> List[str]:
    """.docx 오픈포맷 파일 내의 단락(Paragraph) 텍스트를 파이썬 내장 zipfile로 직접 파싱"""
    paragraphs = []
    try:
        with zipfile.ZipFile(docx_path, 'r') as zf:
            if 'word/document.xml' in zf.namelist():
                xml_content = zf.read('word/document.xml')
                tree = ET.fromstring(xml_content)
                ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
                for p in tree.findall('.//w:p', ns):
                    texts = [node.text for node in p.findall('.//w:t', ns) if node.text]
                    if texts:
                        full_p = "".join(texts).strip()
                        if full_p:
                            paragraphs.append(full_p)
    except Exception as e:
        print(f"DOCX 텍스트 추출 예외: {e}")
    return paragraphs

def load_docs_from_docx_files() -> List[dict]:
    """backend/doc/ 내의 원본 DOCX 문서들을 자동으로 파싱하여 RAG 임베딩 데이터셋으로 구성"""
    docs = []
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    docs_dir = os.path.join(base_dir, "doc")
    if not os.path.exists(docs_dir):
        docs_dir = os.path.abspath(os.path.join(base_dir, "..", "assets", "doc"))

    doc_files = [
        ("cafe", "Cafe_Manual.docx", "카페 매장 매뉴얼"),
        ("convenience_store", "Convenience_Store_Manual.docx", "편의점 매장 매뉴얼"),
        ("restaurant", "Restaurant_Manual.docx", "식당 매장 매뉴얼"),
    ]

    for doc_id, filename, default_title in doc_files:
        filepath = os.path.join(docs_dir, filename)
        if os.path.exists(filepath):
            paras = extract_docx_paragraphs(filepath)
            chunk = []
            chunk_num = 1
            for p in paras:
                chunk.append(p)
                if len(" ".join(chunk)) >= 120: # 120자 내외 단위로 Chunking
                    chunk_text = " ".join(chunk).strip()
                    docs.append({
                        "id": f"{doc_id}_{chunk_num}",
                        "title": f"{default_title} ({chunk_num}항)",
                        "url": f"/api/docs/preview/{doc_id}",
                        "content": chunk_text
                    })
                    chunk = []
                    chunk_num += 1
            if chunk:
                chunk_text = " ".join(chunk).strip()
                docs.append({
                    "id": f"{doc_id}_{chunk_num}",
                    "title": f"{default_title} ({chunk_num}항)",
                    "url": f"/api/docs/preview/{doc_id}",
                    "content": chunk_text
                })

    if not docs:
        docs = [
            {"id": "doc_01", "title": "카페 매장 매뉴얼 1항", "url": "/api/docs/preview/cafe", "content": "모든 고객에게 정중히 인사하며, 품절 시 대체 메뉴를 제안해야 합니다."},
            {"id": "doc_02", "title": "편의점 매장 매뉴얼 1항", "url": "/api/docs/preview/convenience_store", "content": "주류 및 담배 결제 시 반드시 연령 확인을 진행해야 합니다."},
            {"id": "doc_03", "title": "식당 매장 매뉴얼 1항", "url": "/api/docs/preview/restaurant", "content": "알레르기 문의 시 원재료표를 확인하고 화상 발생 시 시원한 물로 식힙니다."}
        ]
    return docs

class InMemoryVectorStore:
    def __init__(self):
        self.docs = []
        self.embeddings = []
        self.initialized = False

    def initialize(self):
        if self.initialized: return
        self.docs = load_docs_from_docx_files()

        payload = {
            "input": [d["content"] for d in self.docs],
            "model": "text-embedding-3-small"
        }
        result = _call_openai_api_sync("https://api.openai.com/v1/embeddings", payload, 30.0)
        for item in result["data"]:
            self.embeddings.append(item["embedding"])
        self.initialized = True

    def search(self, query: str, top_k: int = 2):
        self.initialize()
        payload = {"input": query, "model": "text-embedding-3-small"}
        result = _call_openai_api_sync("https://api.openai.com/v1/embeddings", payload, 10.0)
        q_emb = result["data"][0]["embedding"]

        # Cosine Similarity (코사인 유사도 계산)
        scored_results = []
        for i, doc_emb in enumerate(self.embeddings):
            dot_product = sum(a * b for a, b in zip(q_emb, doc_emb))
            norm_q = math.sqrt(sum(a * a for a in q_emb))
            norm_d = math.sqrt(sum(b * b for b in doc_emb))
            sim = dot_product / (norm_q * norm_d) if norm_q and norm_d else 0.0
            scored_results.append((sim, self.docs[i]))

        scored_results.sort(key=lambda x: x[0], reverse=True)
        return [doc for sim, doc in scored_results[:top_k]]

vector_store = InMemoryVectorStore()

# 3. [POST] /ai/search: AI 어시스턴트 RAG 파이프라인 (원 원본 DOCX 문서 기반)
@router.post("/search", response_model=RagResponseSchema)
async def ai_search_rag(
    req: SearchRequest,
    current_user: User = Depends(get_current_user)
):
    # 1. Retrieve (백엔드 docx 매뉴얼 문서 대상 벡터 검색)
    retrieved_docs = await asyncio.to_thread(vector_store.search, req.query, 2)

    # 2. Generate (프롬프트 구성 및 LLM 호출)
    context_str = "\n\n".join([f"[{d['id']}] {d['title']}: {d['content']}" for d in retrieved_docs])

    system_prompt = f"""너는 매장 수습 아르바이트생을 돕는 친절한 AI 어시스턴트야.
아래의 [참고 매뉴얼 문서]만을 기반으로 사용자의 질문에 정확하고 간결하게 답변해줘.
만약 문서에 없는 내용이라면 "제공된 매뉴얼에서는 해당 내용을 찾을 수 없습니다."라고 답변해.

[참고 매뉴얼 문서]
{context_str}

응답은 반드시 아래 JSON 형식으로 반환해야 해:
{{
  "answer": "사용자 질문에 대한 자연스러운 답변 텍스트",
  "references": [
    {{
      "id": "문서ID (예: cafe_1)",
      "title": "문서 제목 (예: 카페 매장 매뉴얼 (1항))",
      "url": "문서 미리보기 URL (예: /api/docs/preview/cafe)",
      "match_text": "답변의 근거가 된 핵심 문구 (매뉴얼 내용 중 15자 내외 발췌)"
    }}
  ]
}}"""

    payload = {
        "model": "gpt-4o-mini",
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": req.query}
        ],
        "temperature": 0.3
    }

    result = await asyncio.to_thread(_call_openai_api_sync, "https://api.openai.com/v1/chat/completions", payload, 15.0)
    content_str = result["choices"][0]["message"]["content"]

    return json.loads(content_str)
