import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class DocumentPreviewScreen extends ConsumerStatefulWidget {
  final String docId;
  final String title;

  const DocumentPreviewScreen({
    super.key,
    required this.docId,
    required this.title,
  });

  @override
  ConsumerState<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends ConsumerState<DocumentPreviewScreen> {
  String? localPdfPath;
  bool isLoading = true;
  String? errorMessage;
  PdfViewerController? _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _fetchAndSavePdf();
  }

  @override
  void dispose() {
    // 백 내비게이션/제스처 시 SfPdfViewer가 디스포즈된 컨트롤러를 참조하지 않도록 Safe Post Frame Dispose 처리
    final controllerToDispose = _pdfViewerController;
    _pdfViewerController = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controllerToDispose?.dispose();
    });
    super.dispose();
  }

  Future<void> _fetchAndSavePdf() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final baseUrl = authService.baseUrl;
      final token = authService.accessToken;

      // 💡 URI 인코딩 안전 감싸기 (한글 파일명 및 특수문자 지원)
      final encodedDocId = Uri.encodeComponent(widget.docId.trim());
      final url = Uri.parse('$baseUrl/api/docs/preview/$encodedDocId');
      final response = await http.get(
        url,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${widget.docId}_preview.pdf');
        await file.writeAsBytes(bytes, flush: true);

        if (mounted) {
          setState(() {
            localPdfPath = file.path;
            isLoading = false;
          });
        }
      } else {
        throw Exception('문서를 불러올 수 없습니다. (응답 코드: ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'PDF 매뉴얼을 로드하는데 실패했습니다.\n네트워크 상태 및 서버 가동을 확인해 주세요.\n($e)';
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('문서 미리보기 오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAndSavePdf,
            tooltip: '새로고침',
          )
        ],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xff146b59)),
                  SizedBox(height: 16),
                  Text('PDF 매뉴얼을 불러오는 중입니다...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchAndSavePdf,
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 시도'),
                        )
                      ],
                    ),
                  ),
                )
              : SfPdfViewer.file(
                  File(localPdfPath!),
                  key: ValueKey(localPdfPath),
                  controller: _pdfViewerController,
                  onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                    if (mounted) {
                      setState(() {
                        errorMessage = 'PDF 문서 로딩 중 오류가 발생했습니다.\n${details.error} (${details.description})';
                      });
                    }
                  },
                ),
    );
  }
}
