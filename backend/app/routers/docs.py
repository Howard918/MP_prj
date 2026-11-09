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
import docx
from docx import Document
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib import colors
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

def convert_docx_to_pdf_native_win32(docx_path: str, pdf_path: str) -> bool:
    """Windows MS Word COM 공식 내장 엔진 기반 100% 원본 1:1 서식/폰트/레이아웃 동일 원본 PDF 출력 (임시 파일 원자적 세척 및 치환)"""
    if sys.platform != "win32":
        return False
    try:
        import pythoncom
        import win32com.client
        pythoncom.CoInitialize()
        word = None
        try:
            word = win32com.client.DispatchEx("Word.Application")
            word.Visible = False
            word.DisplayAlerts = 0  # wdAlertsNone

            abs_docx = os.path.abspath(docx_path)
            abs_pdf = os.path.abspath(pdf_path)
            tmp_pdf = abs_pdf + ".tmp.pdf"

            if os.path.exists(tmp_pdf):
                try:
                    os.remove(tmp_pdf)
                except Exception:
                    pass

            doc = word.Documents.Open(
                FileName=abs_docx,
                ReadOnly=True,
                ConfirmConversions=False,
                AddToRecentFiles=False
            )
            # 17 = wdFormatPDF (Microsoft Word 공식 내장 PDF 출력)
            doc.SaveAs(tmp_pdf, FileFormat=17)
            doc.Close(0)

            if os.path.exists(tmp_pdf) and os.path.getsize(tmp_pdf) > 2000:
                if os.path.exists(abs_pdf):
                    try:
                        os.remove(abs_pdf)
                    except Exception:
                        pass
                shutil.move(tmp_pdf, abs_pdf)
                return True
            return False
        finally:
            if word:
                try:
                    word.Quit(0)
                except Exception:
                    pass
            pythoncom.CoUninitialize()
    except Exception as e:
        print(f"MS Word Native PDF 변환 예외: {e}")
        return False

def render_pdf_with_reportlab(docx_path: str, pdf_path: str):
    """python-docx + reportlab 기반 단락 및 표 100% 보존 고해상도 한글 PDF 변환"""
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
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36
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
        fontSize=12,
        leading=17,
        textColor='#222222',
        spaceBefore=10,
        spaceAfter=6
    )
    body_style = ParagraphStyle(
        'DocxBody',
        parent=styles['Normal'],
        fontName=font_name,
        fontSize=9.5,
        leading=14.5,
        textColor='#333333',
        spaceAfter=5
    )
    cell_style = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName=font_name,
        fontSize=8.5,
        leading=12,
        textColor='#222222'
    )

    story = []
    for elem in doc.element.body:
        if elem.tag.endswith('p'):
            p = docx.text.paragraph.Paragraph(elem, doc)
            text = p.text.strip()
            if not text:
                continue
            safe_text = text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            if p.style.name.startswith('Heading 1') or '제목' in p.style.name or '매뉴얼' in text or '총칙' in text:
                story.append(Paragraph(safe_text, title_style))
            elif p.style.name.startswith('Heading') or (text[0].isdigit() and ('. ' in text[:4] or ' ' in text[:3])):
                story.append(Paragraph(safe_text, heading_style))
            else:
                story.append(Paragraph(safe_text, body_style))
            story.append(Spacer(1, 2))
        elif elem.tag.endswith('tbl'):
            table = docx.table.Table(elem, doc)
            table_data = []
            for row in table.rows:
                row_data = []
                for cell in row.cells:
                    cell_text = cell.text.strip().replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
                    row_data.append(Paragraph(cell_text, cell_style))
                table_data.append(row_data)
            if table_data:
                t = Table(table_data)
                t.setStyle(TableStyle([
                    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#e8eee9')),
                    ('TEXTCOLOR', (0, 0), (-1, 0), colors.HexColor('#146b59')),
                    ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                    ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                    ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#cccccc')),
                    ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#146b59')),
                    ('TOPPADDING', (0, 0), (-1, -1), 4),
                    ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                ]))
                story.append(t)
                story.append(Spacer(1, 8))

    pdf_doc.build(story)

async def render_pdf_from_docx(docx_path: str, pdf_path: str, doc_title: str):
    """1차: MS Word COM 원본 100% 동일 PDF 출력 -> 2차: ReportLab 한글 파서 -> 3차: LibreOffice"""
    # 1차 시도: Windows MS Word COM 직결 변환 (원본 .docx와 100% 동일한 서식/폰트/레이아웃 출력)
    if sys.platform == "win32":
        try:
            success = await asyncio.to_thread(convert_docx_to_pdf_native_win32, docx_path, pdf_path)
            if success and os.path.exists(pdf_path) and os.path.getsize(pdf_path) > 0:
                print(f"MS Word 원본 100% 동일 PDF 변환 성공: {pdf_path}")
                return
        except Exception as e:
            print(f"win32com 변환 생략: {e}")

    # 2차 시도: ReportLab 한글 PDF 파서
    try:
        await asyncio.to_thread(render_pdf_with_reportlab, docx_path, pdf_path)
        if os.path.exists(pdf_path) and os.path.getsize(pdf_path) > 0:
            print(f"ReportLab PDF 변환 성공: {pdf_path}")
            return
    except Exception as e:
        print(f"ReportLab PDF 렌더링 실패, 폴백 시도: {e}")

    # 3차 시도: LibreOffice --headless
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

def preload_all_pdf_caches():
    """서버 구동 시 backend/doc/ 내의 모든 .docx 파일을 MS Word 100% 원본 PDF로 사전 백그라운드 캐싱"""
    docs_dir = get_docs_dir()
    if not os.path.exists(docs_dir):
        return

    for filename in os.listdir(docs_dir):
        if filename.lower().endswith(".docx"):
            docx_path = os.path.join(docs_dir, filename)
            pdf_filename = f"{os.path.splitext(filename)[0]}.pdf"
            pdf_path = os.path.join(CACHE_DIR, pdf_filename)

            needs_conversion = True
            if os.path.exists(pdf_path):
                docx_mtime = os.path.getmtime(docx_path)
                pdf_mtime = os.path.getmtime(pdf_path)
                if pdf_mtime >= docx_mtime and os.path.getsize(pdf_path) > 2000:
                    needs_conversion = False

            if needs_conversion:
                try:
                    if sys.platform == "win32":
                        convert_docx_to_pdf_native_win32(docx_path, pdf_path)
                    else:
                        render_pdf_with_reportlab(docx_path, pdf_path)
                except Exception as e:
                    print(f"사전 PDF 캐싱 예외 ({filename}): {e}")

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
            detail=f"backend/doc/ 경로에서 요청한 문서({doc_id})에 해당되는 매뉴얼 원본(.docx)을 찾을 수 없습니다."
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
