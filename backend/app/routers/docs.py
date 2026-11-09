import os
import sys
import shutil
import asyncio
import zipfile
import urllib.parse
import xml.etree.ElementTree as ET
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from ..security import get_current_user
from ..models import User

# 원본 DOCX 파싱 및 ReportLab 한글 PDF 렌더링 모듈
from docx import Document
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

router = APIRouter(prefix="/api/docs", tags=["Document Preview"])

# 캐시 및 원본 문서 디렉토리 경로 지정
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CACHE_DIR = os.path.join(BASE_DIR, "cache", "docs")

# backend/doc 디렉토리를 우선 탐색하고, 없으면 ../assets/doc 탐색
PRIMARY_DOCS_DIR = os.path.join(BASE_DIR, "doc")
SECONDARY_DOCS_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "assets", "doc"))

os.makedirs(CACHE_DIR, exist_ok=True)

def get_docs_dir() -> str:
    """우선순위에 따른 원본 DOCX 문서 디렉토리 반환 (backend/doc 우선)"""
    if os.path.exists(PRIMARY_DOCS_DIR) and os.listdir(PRIMARY_DOCS_DIR):
        return PRIMARY_DOCS_DIR
    return SECONDARY_DOCS_DIR

def find_libreoffice_executable() -> Optional[str]:
    """시스템 OS 환경에서 LibreOffice / soffice 실행 파일 경로를 탐색합니다."""
    for cmd in ["libreoffice", "soffice"]:
        path = shutil.which(cmd)
        if path:
            return f'"{path}"'

    if sys.platform == "win32":
        win_paths = [
            r"C:\Program Files\LibreOffice\program\soffice.exe",
            r"C:\Program Files (x86)\LibreOffice\program\soffice.exe",
        ]
        for p in win_paths:
            if os.path.exists(p):
                return f'"{p}"'
    return None

def render_pdf_with_reportlab(docx_path: str, pdf_path: str):
    """python-docx + reportlab 기반 100% 원본 DOCX -> 고해상도 한글 PDF 변환"""
    font_name = 'Helvetica'
    font_paths = [
        r'C:\Windows\Fonts\malgun.ttf',
        r'C:\Windows\Fonts\gulim.ttc',
        r'C:\Windows\Fonts\batang.ttc',
        '/usr/share/fonts/truetype/nanum/NanumGothic.ttf',
        '/Library/Fonts/AppleGothic.ttf',
    ]
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                pdfmetrics.registerFont(TTFont('KoreanFont', fp))
                font_name = 'KoreanFont'
                break
            except Exception:
                pass

    doc = Document(docx_path)
    pdf_doc = SimpleDocTemplate(
        pdf_path,
        pagesize=A4,
        rightMargin=40,
        leftMargin=40,
        topMargin=40,
        bottomMargin=40
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'DocxTitle',
        parent=styles['Heading1'],
        fontName=font_name,
        fontSize=16,
        leading=22,
        textColor='#146b59',
        spaceAfter=12
    )
    heading_style = ParagraphStyle(
        'DocxHeading',
        parent=styles['Heading2'],
        fontName=font_name,
        fontSize=12.5,
        leading=17,
        textColor='#222222',
        spaceBefore=10,
        spaceAfter=6
    )
    body_style = ParagraphStyle(
        'DocxBody',
        parent=styles['Normal'],
        fontName=font_name,
        fontSize=10,
        leading=15,
        textColor='#333333',
        spaceAfter=6
    )

    story = []
    for p in doc.paragraphs:
        text = p.text.strip()
        if not text:
            continue

        safe_text = text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

        if p.style.name.startswith('Heading 1') or '제목' in p.style.name or '매뉴얼' in text:
            story.append(Paragraph(safe_text, title_style))
        elif p.style.name.startswith('Heading') or (text[0].isdigit() and ('. ' in text[:4] or ' ' in text[:3])):
            story.append(Paragraph(safe_text, heading_style))
        else:
            story.append(Paragraph(safe_text, body_style))

        story.append(Spacer(1, 2))

    pdf_doc.build(story)

async def render_pdf_from_docx(docx_path: str, pdf_path: str, doc_title: str):
    """1차: docx2pdf (MS Word COM) -> 2차: reportlab (python-docx 100% 한글 PDF) -> 3차: LibreOffice"""
    if sys.platform == "win32":
        try:
            from docx2pdf import convert
            await asyncio.to_thread(convert, docx_path, pdf_path)
            if os.path.exists(pdf_path) and os.path.getsize(pdf_path) > 0:
                print(f"docx2pdf 성공: {pdf_path}")
                return
        except Exception as e:
            print(f"docx2pdf 변환 생략: {e}")

    try:
        await asyncio.to_thread(render_pdf_with_reportlab, docx_path, pdf_path)
        if os.path.exists(pdf_path) and os.path.getsize(pdf_path) > 0:
            print(f"ReportLab 변환 성공: {pdf_path}")
            return
    except Exception as e:
        print(f"ReportLab PDF 렌더링 실패: {e}")

    libreoffice_bin = find_libreoffice_executable()
    if libreoffice_bin:
        try:
            cmd = f'{libreoffice_bin} --headless --convert-to pdf "{docx_path}" --outdir "{CACHE_DIR}"'
            proc = await asyncio.create_subprocess_shell(
                cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await proc.communicate()
            converted_name = os.path.splitext(os.path.basename(docx_path))[0] + ".pdf"
            converted_path = os.path.join(CACHE_DIR, converted_name)
            if os.path.exists(converted_path):
                if converted_path != pdf_path:
                    if os.path.exists(pdf_path):
                        os.remove(pdf_path)
                    os.rename(converted_path, pdf_path)
                print(f"LibreOffice 변환 성공: {pdf_path}")
                return
        except Exception as e:
            print(f"LibreOffice 변환 중 예외: {e}")

# 1. [GET] /api/docs/preview/{doc_id}: backend/doc/ 내의 .docx 원본을 PDF로 동적 변환 및 캐싱 서빙 (동적 매뉴얼 검색)
@router.get("/preview/{doc_id}")
async def preview_document(
    doc_id: str,
    current_user: User = Depends(get_current_user)
):
    decoded_id = urllib.parse.unquote(doc_id).lower().replace(".docx", "").replace(".pdf", "").strip()
    clean_id = doc_id.lower().replace(".docx", "").replace(".pdf", "").strip()
    docs_dir = get_docs_dir()

    docx_path = None
    if os.path.exists(docs_dir):
        # 1차: 정확한 파일명/ID 완전 대조
        for f in os.listdir(docs_dir):
            if f.lower().endswith(".docx"):
                stem = os.path.splitext(f)[0].lower()
                if stem == decoded_id or stem == clean_id:
                    docx_path = os.path.join(docs_dir, f)
                    break

        # 2차: 파일명 상호 부분 포함 대조
        if not docx_path:
            for f in os.listdir(docs_dir):
                if f.lower().endswith(".docx"):
                    stem = os.path.splitext(f)[0].lower()
                    if decoded_id in stem or stem in decoded_id or clean_id in stem or stem in clean_id:
                        docx_path = os.path.join(docs_dir, f)
                        break

    if not docx_path or not os.path.exists(docx_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"backend/doc/ 경로에서 요청한 문서({doc_id})에 해당되는 매매뉴얼 원본(.docx)을 찾을 수 없습니다."
        )

    pdf_filename = f"{os.path.splitext(os.path.basename(docx_path))[0]}.pdf"
    pdf_path = os.path.join(CACHE_DIR, pdf_filename)

    needs_conversion = True
    if os.path.exists(pdf_path):
        docx_mtime = os.path.getmtime(docx_path)
        pdf_mtime = os.path.getmtime(pdf_path)
        if pdf_mtime >= docx_mtime and os.path.getsize(pdf_path) > 2000:
            needs_conversion = False

    if needs_conversion:
        await render_pdf_from_docx(docx_path, pdf_path, clean_id)

    return FileResponse(
        path=pdf_path,
        media_type="application/pdf",
        filename=os.path.basename(pdf_path)
    )

# 2. [GET] /api/docs/list: backend/doc/ 내의 모든 DOCX/PDF 매뉴얼 문서 목록 동적 수신 (모든 사용자 오픈 수신)
@router.get("/list")
async def list_documents():
    docs_dir = get_docs_dir()
    result = []
    if os.path.exists(docs_dir):
        for filename in sorted(os.listdir(docs_dir)):
            if filename.lower().endswith((".docx", ".pdf")):
                doc_id = os.path.splitext(filename)[0].lower()
                raw_title = os.path.splitext(filename)[0].replace("_", " ")

                title = raw_title
                filepath = os.path.join(docs_dir, filename)
                if filename.lower().endswith(".docx"):
                    try:
                        doc = Document(filepath)
                        for p in doc.paragraphs:
                            t = p.text.strip()
                            if t and len(t) > 3:
                                title = t[:45]
                                break
                    except Exception:
                        pass

                result.append({
                    "doc_id": doc_id,
                    "title": title,
                    "filename": filename,
                    "type": "매뉴얼 PDF 변환 문서"
                })
    return result
