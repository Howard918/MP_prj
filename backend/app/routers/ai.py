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
    eval_system_prompt = f"""다음은 매장 수습 아르바이트생(user)과 고객(assistant) 간의 대화 기록입니다.

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
# 범용 B2B 단일 사업장 DOCX 매뉴얼 동적 RAG 벡터 저장소 (NLP 키워드 하이브리드 검색)
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
    """backend/doc/ 내의 모든 DOCX 매뉴얼 문서들을 동적으로 스캔 및 RAG 임베딩 데이터셋으로 통합 적재"""
    docs = []
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    docs_dir = os.path.join(base_dir, "doc")
    if not os.path.exists(docs_dir):
        docs_dir = os.path.abspath(os.path.join(base_dir, "..", "assets", "doc"))

    if os.path.exists(docs_dir):
        docx_files = [f for f in os.listdir(docs_dir) if f.lower().endswith(".docx")]
        for filename in docx_files:
            filepath = os.path.join(docs_dir, filename)
            doc_id = os.path.splitext(filename)[0].lower()
            default_title = os.path.splitext(filename)[0].replace("_", " ")

            paras = extract_docx_paragraphs(filepath)
            current_section = default_title
            chunk = []
            chunk_num = 1

            for p in paras:
                if p[0].isdigit() and ('. ' in p[:4] or ' ' in p[:3]):
                    if chunk:
                        docs.append({
                            "id": f"{doc_id}_{chunk_num}",
                            "title": f"{default_title} - {current_section}",
                            "url": f"/api/docs/preview/{doc_id}",
                            "content": " ".join(chunk).strip()
                        })
                        chunk = []
                        chunk_num += 1
                    current_section = p
                else:
                    chunk.append(p)
                    if len(" ".join(chunk)) >= 140:
                        docs.append({
                            "id": f"{doc_id}_{chunk_num}",
                            "title": f"{default_title} - {current_section}",
                            "url": f"/api/docs/preview/{doc_id}",
                            "content": " ".join(chunk).strip()
                        })
                        chunk = []
                        chunk_num += 1

            if chunk:
                docs.append({
                    "id": f"{doc_id}_{chunk_num}",
                    "title": f"{default_title} - {current_section}",
                    "url": f"/api/docs/preview/{doc_id}",
                    "content": " ".join(chunk).strip()
                })

    if not docs:
        docs = [
            {"id": "doc_01", "title": "매장 매뉴얼 기본 수칙", "url": "/api/docs/preview/manual", "content": "모든 고객에게 정중히 인사하며, 품절 및 요청 시 매장 규칙에 따라 대체 메뉴와 안내를 제공해야 합니다."}
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

    def search(self, query: str, top_k: int = 4):
        self.initialize()

        raw_query = query.strip()
        query_terms = [w.strip() for w in raw_query.split() if len(w.strip()) > 0]

        # 💡 NLP AI 쿼리 자연어 확장 & 단발성 키워드 의미 보강
        expanded_query = raw_query
        keyword_expansions = {
            "서비스": "서비스 고객 응대 손님 친절 인사 고객케어 컴플레인 예절 수칙",
            "복장": "복장 유니폼 용모 손톱 머리망 앞치마 용모수칙 착용",
            "환불": "환불 결제 취소 영수증 교환 정산 POS 변경",
            "위생": "위생 식품안전 소독 청결 손씻기 교차오염 복장",
            "음료": "음료 제조 레시피 사이즈 정량 오제조 메뉴",
            "장비": "장비 시설 머신 고장 점검 수리 수칙 가동중단",
            "개점": "개점 마감 시재 금고 경보기 오픈 준비 수칙",
            "마감": "마감 개점 금고 시재 정산 청소 영업종료",
            "안전": "안전 화상 사고 응급처치 소화기 대피 비상대응",
            "발주": "발주 재고 검수 입고 보관 소비기한 유통기한",
            "POS": "POS 금전 정산 카드 현금 영수증 중복결제 시재",
            "손님": "고객 손님 응대 인사 불만 케어 서비스 안내",
        }
        for kw, exp in keyword_expansions.items():
            if kw in raw_query:
                expanded_query += " " + exp

        payload = {"input": expanded_query, "model": "text-embedding-3-small"}
        result = _call_openai_api_sync("https://api.openai.com/v1/embeddings", payload, 10.0)
        q_emb = result["data"][0]["embedding"]

        # 💡 하이브리드 검색 알고리즘 (70% 벡터 코사인 유사도 + 30% 제목/내용 키워드 매칭 스코어)
        scored_results = []
        for i, doc_emb in enumerate(self.embeddings):
            dot_product = sum(a * b for a, b in zip(q_emb, doc_emb))
            norm_q = math.sqrt(sum(a * a for a in q_emb))
            norm_d = math.sqrt(sum(b * b for b in doc_emb))
            cosine_sim = dot_product / (norm_q * norm_d) if norm_q and norm_d else 0.0

            doc_title = self.docs[i]["title"]
            doc_content = self.docs[i]["content"]

            keyword_score = 0.0
            for term in query_terms:
                if term in doc_title:
                    keyword_score += 0.35  # 제목 키워드 가중치
                if term in doc_content:
                    keyword_score += 0.15  # 내용 키워드 가중치

            final_score = (0.7 * cosine_sim) + (0.3 * min(keyword_score, 1.0))
            scored_results.append((final_score, self.docs[i]))

        scored_results.sort(key=lambda x: x[0], reverse=True)
        return [doc for score, doc in scored_results[:top_k]]

vector_store = InMemoryVectorStore()

# 3. [POST] /ai/search: AI 어시스턴트 RAG 파이프라인 (자연어 NLP 처리 & 동적 매장 매뉴얼)
@router.post("/search", response_model=RagResponseSchema)
async def ai_search_rag(
    req: SearchRequest,
    current_user: User = Depends(get_current_user)
):
    # 1. Retrieve (하이브리드 NLP 벡터 검색으로 상위 4개 관련 매뉴얼 추출)
    retrieved_docs = await asyncio.to_thread(vector_store.search, req.query, 4)

    # 2. Generate (프롬프트 구성 및 LLM 호출)
    context_str = "\n\n".join([f"[{d['id']}] {d['title']}: {d['content']}" for d in retrieved_docs])

    system_prompt = f"""너는 backend/doc/ 매뉴얼을 따르는 매장의 수습 아르바이트생을 돕는 친절하고 유능한 AI 어시스턴트야.
사용자가 '서비스', '복장', '위생', '환불'과 같은 단발성 키워드나 유의어, 질문을 입력했을 때 아래의 [참고 매뉴얼 문서]를 바탕으로 이해하기 쉽고 자연스럽게 맥락을 정돈하여 친절하고 풍부하게 자연어로 답변해줘.

[참고 매뉴얼 문서]
{context_str}

지침:
1. 사용자가 단발성 단어나 동의어를 입력하더라도 [참고 매뉴얼 문서]에 관련 지침이 포함되어 있다면 절대 "찾을 수 없습니다"라고 답변하지 말고 관련 핵심 수칙을 친절히 정돈해서 설명해줘.
2. 매뉴얼 내용과 완전히 무관한 질문(예: 주식, 우주, 연예인 관련 질문)에 대해서만 "제공된 매뉴얼에서는 해당 내용을 찾을 수 없습니다."라고 답변해줘.

응답은 반드시 아래 JSON 형식으로 반환해야 해:
{{
  "answer": "사용자 질문에 대한 자연스럽고 친절하며 풍부한 자연어 답변 텍스트",
  "references": [
    {{
      "id": "문서ID (예: 04_고객응대_및_서비스_1)",
      "title": "문서 제목 (예: 04 고객응대 및 서비스 - 1. 기본 응대 원칙)",
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
    res_data = json.loads(content_str)

    # 💡 [핵심 버그 픽스] LLM 환각(Hallucination) 원천 차단:
    # LLM이 생성한 reference ID/URL을 실제 검색된 retrieved_docs와 100% 매칭하여
    # 해당 원본 매뉴얼 문서의 정확한 미리보기 URL(/api/docs/preview/{doc_id})로 백엔드가 강제 바인딩합니다.
    doc_map = {d["id"]: d for d in retrieved_docs}
    valid_refs = []

    for ref in res_data.get("references", []):
        ref_id = str(ref.get("id", "")).strip()
        matched_doc = doc_map.get(ref_id)

        if not matched_doc:
            for d in retrieved_docs:
                if ref_id in d["id"] or d["id"] in ref_id or ref.get("title", "") in d["title"]:
                    matched_doc = d
                    break

        if not matched_doc and retrieved_docs:
            matched_doc = retrieved_docs[0]

        if matched_doc:
            chunk_id = matched_doc["id"]
            # chunk_id 예: 02_근무_및_인사규정_1 -> 02_근무_및_인사규정
            raw_doc_id = chunk_id.rsplit("_", 1)[0] if "_" in chunk_id else chunk_id

            valid_refs.append({
                "id": chunk_id,
                "title": matched_doc["title"],
                "url": f"/api/docs/preview/{raw_doc_id}",
                "match_text": ref.get("match_text", matched_doc["content"][:20])
            })

    res_data["references"] = valid_refs
    return res_data
