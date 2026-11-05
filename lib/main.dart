import 'package:flutter/material.dart';

void main() => runApp(const FirstShiftApp());

class FirstShiftApp extends StatelessWidget {
  const FirstShiftApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '첫 근무 노트',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff146b59),
        surface: const Color(0xfffbfcfa),
      ),
      scaffoldBackgroundColor: const Color(0xfff4f7f4),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 15, height: 1.45),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xfff4f7f4),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 21,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: Color(0xff17231f),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffcbd5cf)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xff146b59), width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xffe3e9e4)),
        ),
      ),
      useMaterial3: true,
    ),
    home: const Dashboard(),
  );
}

/// Prototype data only: scenarios live in memory and reset when the app restarts.
class RoleplayScenario {
  RoleplayScenario({
    required this.id,
    required this.industry,
    required this.title,
    required this.situation,
    required this.expectedActions,
    required this.linkedRules,
    this.referenceCodes = const [],
    this.isPublished = false,
  });

  final String id;
  String industry;
  String title;
  String situation;
  String expectedActions;
  String linkedRules;
  List<String> referenceCodes;
  bool isPublished;
}

/// Curated source index transcribed from the user's reference file.
/// Law, official guidance, and store policy are intentionally labeled separately.
class OfficialReference {
  const OfficialReference(this.code, this.kind, this.name, this.url, this.scope);
  final String code;
  final String kind;
  final String name;
  final String url;
  final String scope;
}

const references = <OfficialReference>[
  OfficialReference('L-01', '법령', '근로기준법 제11조 적용 범위', 'https://www.law.go.kr/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1030687479', '5인 이상 원칙 및 4인 이하 일부 적용 조항'),
  OfficialReference('L-02', '법령', '근로기준법 시행령 별표 1', 'https://www.law.go.kr/법령별표서식/(근로기준법시행령,20251023,별표1)', '4명 이하 사업장 적용 조항 확인'),
  OfficialReference('L-03', '법령', '근로기준법 시행령 제7조의2', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lspttninfSeq=70859', '상시근로자 수 산정 방법'),
  OfficialReference('L-04', '공식 지침', '고용노동부 5인 미만 사업장 안내', 'https://www.moel.go.kr/news/cardinfo/view.do?bbs_seq=20220500493', '근로계약·최저임금·임금명세서·휴게 등'),
  OfficialReference('L-05', '공식 지침', '2026년 적용 최저임금 안내', 'https://www.moel.go.kr/news/enews/report/enewsView.do?news_seq=18144&pageUnit=10', '2026년 적용 자료. 연도 경과 후 재확인'),
  OfficialReference('L-06', '법령', '근로기준법 제17조 근로조건 명시', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?lsJoLnkSeq=1015677481', '임금·근로시간·휴일 등 명시'),
  OfficialReference('L-07', '법령', '근로기준법 제43조 임금 지급', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1029727925', '임금 지급 원칙'),
  OfficialReference('L-08', '법령', '근로기준법 제48조 임금대장·명세서', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1025590421', '임금대장 및 임금명세서'),
  OfficialReference('L-09', '법령', '근로기준법 제54조 휴게', 'https://www.law.go.kr/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1032636821', '2026-12-10 시행 예정 개정 규정은 시행일에 재확인'),
  OfficialReference('L-10', '법령', '근로기준법 제55조·시행령 제30조', 'https://www.law.go.kr/lsLinkCommonInfo.do?lsJoLnkSeq=1025589731', '유급휴일 요건 및 적용 범위 확인'),
  OfficialReference('L-11', '법령', '근로기준법 제18조 제3항', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1027161153', '주 15시간 미만 근로자 관련 예외'),
  OfficialReference('L-12', '법령', '근로자퇴직급여 보장법 제4조', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1030452207', '퇴직급여 요건과 예외 별도 확인'),
  OfficialReference('L-13', '공식 자료', '고용노동부 표준근로계약서·임금명세서', 'https://www.moel.go.kr/policy/policydata/view.do?bbs_seq=20230700845', '서식 참고'),
  OfficialReference('F-01', '법령', '식품위생법 제3조·제4조', 'https://www.law.go.kr/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1025448923', '위생적 취급, 위해 식품 금지'),
  OfficialReference('F-02', '법령', '식품위생법 제44조', 'https://www.law.go.kr/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1027675099', '영업자 준수사항 및 적용 범위 확인'),
  OfficialReference('F-03', '법령', '식품위생법 시행규칙 별표 1', 'https://www.law.go.kr/LSW/lsInfoP.do?lsiSeq=289161', '식품의 위생적 취급 기준'),
  OfficialReference('F-04', '법령', '식품위생법 시행규칙 별표 17', 'https://www.law.go.kr/lsBylInfoPLinkR.do?bylBrNo=00&bylCls=BE&bylNo=0017&lsNm=식품위생법시행규칙', '식품접객업 적용 여부 확인'),
  OfficialReference('F-05', '공식 지침', '식품안전나라 식중독 예방법', 'https://www.foodsafetykorea.go.kr/portal/board/boardDetail.do?bbs_no=bbs401&menu_no=4419&ntctxt_no=1068744', '손 씻기, 교차오염 예방'),
  OfficialReference('F-06', '공식 지침', '식약처 식중독 예방 6대 요령', 'https://mfds.go.kr/brd/m_827/view.do?seq=3609', '식품 보관·가열 안내 수치. 법정 기준과 구분'),
  OfficialReference('F-07', '법령', '어린이 식생활안전관리 특별법 제11조의2', 'https://www.law.go.kr/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1033104629', '알레르기 표시 대상 업소에 한해 확인'),
  OfficialReference('F-08', '법령', '어린이 식생활안전관리 특별법 시행령 제8조', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1033104679', '표시 대상 영업자 요건 확인'),
  OfficialReference('F-09', '법령', '산업안전보건법 제38조', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1020162873', '사업주의 안전조치'),
  OfficialReference('F-10', '법령', '산업안전보건법 제57조', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1029342309', '산업재해 기록·보고 요건 별도 확인'),
  OfficialReference('F-11', '공식 지침', '질병관리청 화상 안내', 'https://health.kdca.go.kr/healthinfo/biz/health/gnrlzHealthInfo/gnrlzHealthInfo/gnrlzHealthInfoView.do?cntnts_sn=6584', '화상 응급처치, 필요 시 119·의료기관'),
  OfficialReference('F-12', '공식 기준', '소비자분쟁해결기준 제2025-14호', 'https://www.law.go.kr/admRulInfoP.do?admRulSeq=2100000270136', '분쟁 품목·사실관계별 합의·권고 기준'),
  OfficialReference('F-13', '법령', '전자상거래법 제15조', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1029561795', '통신판매 해당 여부 확인'),
  OfficialReference('F-14', '법령', '개인정보 보호법 제15조·제16조', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1029334879', '개인정보 처리 근거·최소 수집'),
  OfficialReference('F-15', '법령', '개인정보 보호법 제21조', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1027063705', '개인정보 파기'),
  OfficialReference('F-16', '법령', '개인정보 보호법 제29조', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1029334811', '개인정보 안전조치'),
  OfficialReference('F-17', '공식 지침', 'KOSHA 음식·숙박업 안전실무길잡이', 'https://www.kosha.or.kr/ebook/fcatalog/include/monthly_detail.jsp?ccate=010Z0A0000&cimg=&sdir=549', '음식업 공정별 위험요인'),
  OfficialReference('F-18', '공식 지침', 'KOSHA 레스토랑·외식업 안전수칙', 'https://oshri.kosha.or.kr/kosha/data/activity_D.do?articleNo=257608&attachNo=139558&mode=download', '미끄러짐·절단·화상 예방'),
  OfficialReference('F-19', '공식 지침', 'KOSHA GUIDE G-68-2011 조리도구 안전지침', 'https://oshri.kosha.or.kr/kosha/intro/busanHeadquarters_A.do?articleNo=330285&attachNo=174516&mode=download', '조리도구 안전. 최신 유효성 재확인'),
  OfficialReference('CV-01', '법령', '청소년 보호법 제28조', 'https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1026189877', '주류·담배 판매 시 나이·본인 확인'),
  OfficialReference('CV-02', '법령', '담배사업법 제12조', 'https://www.law.go.kr/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1032975883', '담배의 판매 및 유통 체계'),
  OfficialReference('CV-03', '법령', '식품 등의 표시·광고에 관한 법률 제4조', 'https://www.law.go.kr/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1030102807', '취급 상품별 표시 기준 확인'),
  OfficialReference('POLICY', '매장 자체 규칙', '매장 자체 업무·서비스 절차', '', 'POS 확인, 주문 재확인, 보고·마감 절차. 법적 의무와 구분'),
];

const Map<String, List<String>> rulesByIndustry = {
  '카페': ['주문·수량·옵션 재확인', 'POS 내역 확인', '레시피·제조 순서 준수', '품절 안내 및 대체 메뉴 제안', '알레르기·교차접촉 확인', '불확실하면 매니저 보고', '불만·환불 절차 확인', '제조도구·시설 청결', '소비기한·보관 상태 확인', '고장 장비 사용 중단 및 보고', '사고 시 작업 중단·안전 확보', '마감 재고·청소·장비·POS 점검'],
  '편의점': ['결제 전 바코드·수량·금액 확인', '결제 오류 시 POS 확인', '주류·담배 신분증 확인', '나이 확인 불가 시 판매 보류', '식품 소비기한 확인', '기한 경과 상품 판매대 분리', '냉장·냉동 기준에 맞게 보관', '전자레인지·온장고 안전수칙', '재고·입고 문제 점주 보고', '택배 개인정보 보호', '교환·환불 및 온라인 주문 확인', '화재·정전·장비 고장 안전조치', '마감 진열·재고·청소·정산 확인'],
  '식당': ['주문·수량·옵션 재확인', '주문 변경사항 주방에 전달', '정해진 조리법 준수', '튀김기·화상·화재 예방', '육류 충분히 가열·식재료 구분', '소비기한·보관 상태 확인', '알레르기 확인·불확실 시 주방장 보고', '오주문 확인 후 적절한 조치', '불만·환불 절차 확인', '조리도구·식기 청결', '주방·홀 바닥 및 작업공간 청결', '포장·배달 메뉴와 수량 검수', '장비 고장·재료 부족 보고', '마감 보관·장비·청소·POS 확인'],
  '기타': ['매장 자체 운영 절차 확인'],
};

final List<RoleplayScenario> scenarioStore = [
  RoleplayScenario(
    id: 'c-01', industry: '카페', title: '주문 재료 품절',
    situation: '고객이 주문한 음료의 재료가 모두 소진되었습니다. 고객이 무엇을 선택할 수 있는지 묻습니다.',
    expectedActions: '재고를 확인하고 가능한 대체 메뉴를 안내합니다. 고객 동의 없이 주문을 바꾸지 않으며 환불·보상은 사실관계와 매장 절차를 확인합니다.',
    linkedRules: '품절 안내 및 대체 메뉴 제안', referenceCodes: ['POLICY', 'F-12'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'c-02', industry: '카페', title: '잘못 제조된 음료',
    situation: '고객이 주문한 아이스 음료가 뜨거운 음료로 나왔다고 알립니다.',
    expectedActions: '주문과 제공된 음료를 확인하고 사과합니다. 매장 절차에 따라 올바른 음료를 다시 준비하고 필요한 경우 매니저에게 알립니다.',
    linkedRules: '주문·수량·옵션 재확인; 오제조 확인 및 조치', referenceCodes: ['POLICY', 'F-12'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'c-03', industry: '카페', title: '알레르기 관련 문의',
    situation: '고객이 우유 알레르기가 있는데 음료를 마셔도 되는지 묻습니다.',
    expectedActions: '원재료와 제조 도구의 교차 접촉 가능성을 확인합니다. 확인할 수 없으면 안전하다고 단정하지 않고 매니저에게 확인해 불확실성을 안내합니다.',
    linkedRules: '알레르기·교차접촉 확인; 불확실하면 매니저 보고', referenceCodes: ['F-03', 'F-05', 'F-07', 'F-08'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'c-04', industry: '카페', title: '음료 불만 및 환불 요청',
    situation: '고객이 음료 맛에 불만을 제기하며 환불을 요청합니다.',
    expectedActions: '불만 내용과 제조 상태를 확인하고 매장 처리 절차를 안내합니다. 환불 여부를 일률적으로 약속하지 않고 필요하면 매니저에게 연결합니다.',
    linkedRules: '불만·환불 절차 확인', referenceCodes: ['F-12', 'POLICY'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'c-05', industry: '카페', title: '에스프레소 머신 고장',
    situation: '음료 제조 중 머신에서 이상한 소리와 냄새가 납니다.',
    expectedActions: '장비 사용을 중단하고 위험 구역을 통제한 뒤 매니저에게 보고합니다. 점검 전에는 재가동하지 않습니다.',
    linkedRules: '고장 장비 사용 중단 및 보고', referenceCodes: ['F-09', 'F-17', 'F-18', 'F-19'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'cv-01', industry: '편의점', title: '미성년자의 주류 구매',
    situation: '고객이 맥주를 구매하려 하지만 신분증을 제시하지 않거나 나이 확인이 어렵습니다.',
    expectedActions: '판매를 보류하고 나이와 본인 여부를 확인합니다. 확인할 수 없으면 판매하지 않고 점주에게 문의합니다.',
    linkedRules: '주류·담배 신분증 확인; 나이 확인 불가 시 판매 보류', referenceCodes: ['CV-01'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'cv-02', industry: '편의점', title: '소비기한이 지난 도시락',
    situation: '고객이 판매대에 소비기한이 지난 도시락이 있다고 알려줍니다.',
    expectedActions: '해당 상품을 판매하지 않도록 분리하고 같은 상품의 소비기한을 확인한 뒤 점주에게 보고합니다.',
    linkedRules: '식품 소비기한 확인; 기한 경과 상품 판매대 분리', referenceCodes: ['F-01', 'F-02', 'F-03', 'CV-03'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'cv-03', industry: '편의점', title: '카드 중복 결제 의심',
    situation: '고객은 카드에서 금액이 두 번 빠져나갔다고 말하지만 POS에는 승인 한 건만 표시됩니다.',
    expectedActions: 'POS 승인·취소 내역과 고객이 제시한 승인 내역을 함께 확인합니다. 해결이 어려우면 점주, 카드사 또는 결제대행사 절차로 연결합니다.',
    linkedRules: '결제 오류 시 POS 확인', referenceCodes: ['POLICY', 'F-12'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'cv-04', industry: '편의점', title: '택배 접수 정보 오류',
    situation: '택배 접수 후 고객이 주소를 잘못 입력했다며 수정해 달라고 요청합니다.',
    expectedActions: '택배 접수 상태와 수정 가능 여부를 택배사 절차에 따라 확인합니다. 주소와 연락처를 불필요하게 노출하거나 제3자에게 임의로 전달하지 않습니다.',
    linkedRules: '택배 개인정보 보호', referenceCodes: ['F-14', 'F-15', 'F-16'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'cv-05', industry: '편의점', title: '전자레인지 사용 중 불꽃',
    situation: '도시락을 데우던 중 용기에서 불꽃이 발생합니다.',
    expectedActions: '즉시 작동을 멈추고 안전을 확보합니다. 위험이 계속되면 접근을 통제하고 점주에게 보고하며, 전기·화재 위험은 시설 안전 절차와 119 기준을 따릅니다.',
    linkedRules: '전자레인지·온장고 안전수칙; 화재·정전·장비 고장 안전조치', referenceCodes: ['F-09'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'r-01', industry: '식당', title: '잘못된 음식 제공',
    situation: '고객은 등심돈까스를 주문했지만 치즈돈까스를 받았습니다.',
    expectedActions: '주문 내역을 확인하고 사과한 뒤 올바른 메뉴를 다시 조리하거나 매장 기준에 따른 조치를 안내합니다.',
    linkedRules: '오주문 확인 후 적절한 조치', referenceCodes: ['POLICY', 'F-12'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'r-02', industry: '식당', title: '음식 조리 상태 불만',
    situation: '고객이 돈까스 고기가 충분히 익지 않은 것 같다며 불만을 제기합니다.',
    expectedActions: '음식 제공·섭취를 중단하도록 안내하고 회수해 주방장에게 전달합니다. 조리 상태를 확인하고 안전한 재조리나 대체 등 필요한 조치를 합니다.',
    linkedRules: '육류 충분히 가열·식재료 구분; 불만·환불 절차 확인', referenceCodes: ['F-01', 'F-03', 'F-05', 'F-06'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'r-03', industry: '식당', title: '식재료 알레르기 문의',
    situation: '고객이 밀가루 또는 계란 알레르기가 있는데 돈까스를 먹어도 되는지 묻습니다.',
    expectedActions: '원재료, 소스, 튀김옷, 조리도구 공유 여부를 확인합니다. 확인되지 않으면 안전하다고 단정하지 말고 주방장에게 확인해 불확실성을 안내합니다.',
    linkedRules: '알레르기 확인·불확실 시 주방장 보고', referenceCodes: ['F-03', 'F-05', 'F-07', 'F-08'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'r-04', industry: '식당', title: '뜨거운 기름 화상 사고',
    situation: '돈까스를 튀기던 중 뜨거운 기름이 직원 손에 튀었습니다.',
    expectedActions: '위험 작업을 중지하고 안전한 곳으로 이동합니다. 화상 부위를 흐르는 찬물로 20분 이상 식히는 등 응급처치를 하고, 상태가 심하거나 불확실하면 119·의료기관에 연결한 뒤 매니저에게 보고합니다.',
    linkedRules: '튀김기·화상·화재 예방; 사고 시 작업 중단·안전 확보', referenceCodes: ['F-09', 'F-10', 'F-11', 'F-17', 'F-18', 'F-19'], isPublished: true,
  ),
  RoleplayScenario(
    id: 'r-05', industry: '식당', title: '배달 음식 누락',
    situation: '고객이 배달받은 돈까스에 소스가 빠졌다고 연락했습니다.',
    expectedActions: '주문과 포장 내역을 확인하고 사과합니다. 매장·배달 플랫폼 절차에 따라 누락품 재전달 등 적절한 조치를 안내하고 필요하면 매니저에게 연결합니다.',
    linkedRules: '포장·배달 메뉴와 수량 검수', referenceCodes: ['POLICY', 'F-12', 'F-13'], isPublished: true,
  ),
];

// Demo-only gate. Replace with server-side authentication before production use.
const String managerPassword = '0000';

Widget content(List<Widget> children) => Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 680),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: children,
    ),
  ),
);

Widget panel(String title, String description, IconData icon, VoidCallback onTap) => Card(
  clipBehavior: Clip.antiAlias,
  child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    minLeadingWidth: 44,
    leading: Icon(icon, size: 26),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(description)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  ),
);

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int tab = 0;
  bool adminUnlocked = false;
  String selectedIndustry = '전체';

  void open(Widget page) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => page),
  ).then((_) => setState(() {}));

  void startPractice(RoleplayScenario scenario) => open(Practice(scenario: scenario));

  Future<void> selectTab(int index) async {
    if (index != 4) {
      setState(() {
        tab = index;
        adminUnlocked = false;
      });
      return;
    }
    if (adminUnlocked) {
      setState(() => tab = index);
      return;
    }

    var enteredPassword = '';
    final authorized = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('관리자 비밀번호'),
        content: TextField(
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '비밀번호',
            hintText: '관리자 비밀번호를 입력하세요',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => enteredPassword = value,
          onSubmitted: (_) => Navigator.pop(
            dialogContext,
            enteredPassword == managerPassword,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              enteredPassword == managerPassword,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!mounted || authorized == null) return;
    if (authorized) {
      setState(() {
        adminUnlocked = true;
        tab = index;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 올바르지 않습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final published = scenarioStore.where((s) => s.isPublished).toList();
    final visibleScenarios = selectedIndustry == '전체'
        ? published
        : published.where((s) => s.industry == selectedIndustry).toList();
    final drafts = scenarioStore.where((s) => !s.isPublished).toList();
    final pages = <List<Widget>>[
      [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.waving_hand_outlined, size: 30, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(height: 14),
                Text('첫 근무, 차근차근 연습해요', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                const SizedBox(height: 8),
                Text('매장에서 만날 수 있는 상황을 골라 응대 순서를 익혀보세요.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => setState(() => tab = 1),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('상황 둘러보기'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('빠른 시작', style: Theme.of(context).textTheme.titleLarge),
        if (published.isNotEmpty)
          panel('추천 상황 · ${published.first.title}', published.first.situation, Icons.auto_awesome_outlined, () => startPractice(published.first)),
        const SizedBox(height: 12),
        panel('교육 리포트', '지난 연습 결과와 보완할 항목을 확인하세요.', Icons.insights, () => setState(() => tab = 2)),
        panel('매장 운영규칙', '매장 규칙과 현장 사례를 확인하세요.', Icons.storefront, () => setState(() => tab = 3)),
      ],
      [
        Text('어떤 상황을 연습할까요?', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('업종을 선택하면 관련 상황만 모아볼 수 있어요.'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final industry in ['전체', '카페', '편의점', '식당'])
              ChoiceChip(
                label: Text(industry),
                selected: selectedIndustry == industry,
                onSelected: (_) => setState(() => selectedIndustry = industry),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibleScenarios.isEmpty)
          const Card(child: ListTile(leading: Icon(Icons.search_off), title: Text('표시할 상황이 없습니다.'), subtitle: Text('다른 업종을 선택해 보세요.'))),
        for (final s in visibleScenarios)
          Card(
            child: ListTile(
              minVerticalPadding: 16,
              leading: CircleAvatar(child: Icon(_industryIcon(s.industry))),
              title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(s.situation, maxLines: 2, overflow: TextOverflow.ellipsis)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => startPractice(s),
            ),
          ),
      ],
      [
        const Chip(label: Text('예시 리포트')),
        panel('최근 연습 · 재료 소진', '80점 · 대체 메뉴 안내 완료', Icons.assignment, () => published.isNotEmpty ? startPractice(published.first) : null),
        panel('보완할 항목', '환불 요청 시 관리자 확인 절차', Icons.flag, () => published.isNotEmpty ? startPractice(published.first) : null),
      ],
      [
        panel('매장 운영규칙', '상황극에 연결할 규칙 예시를 확인하세요.', Icons.menu_book, () => open(const RulesPage())),
        panel('현장 사례 등록', '사례 등록 화면 예시', Icons.note_add, () => open(const CaseForm())),
      ],
      [
        const Chip(label: Text('관리자 전용 시안')),
        const Text('상황극 시나리오를 만들고 공개 상태를 관리합니다.'),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () => open(ScenarioForm(onSave: (_) => setState(() {}))), icon: const Icon(Icons.add), label: const Text('시나리오 만들기')),
        const SizedBox(height: 12),
        Text('시나리오 목록 (${scenarioStore.length})', style: Theme.of(context).textTheme.titleLarge),
        for (final s in scenarioStore) _adminScenarioCard(s),
        if (drafts.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('초안은 관리자 목록에만 표시되며 연습 목록에는 나타나지 않습니다.')),
      ],
    ];

    return Scaffold(
      appBar: AppBar(title: Text(['첫 근무 노트', '상황극', '교육 리포트', '운영규칙', '관리자'][tab])),
      body: content(pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: selectTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
          NavigationDestination(icon: Icon(Icons.chat_outlined), label: '상황극'),
          NavigationDestination(icon: Icon(Icons.insights), label: '리포트'),
          NavigationDestination(icon: Icon(Icons.storefront), label: '운영규칙'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), label: '관리자'),
        ],
      ),
    );
  }

  IconData _industryIcon(String industry) => switch (industry) {
    '카페' => Icons.local_cafe_outlined,
    '편의점' => Icons.storefront_outlined,
    '식당' => Icons.restaurant_outlined,
    _ => Icons.work_outline,
  };

  Widget _adminScenarioCard(RoleplayScenario scenario) => Card(
    child: ListTile(
      leading: Icon(scenario.isPublished ? Icons.public : Icons.edit_note),
      title: Text('${scenario.industry} · ${scenario.title}'),
      subtitle: Text('${scenario.isPublished ? '공개' : '초안'} · ${scenario.situation}', maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => open(ScenarioForm(existing: scenario, onSave: (updated) => setState(() {}))),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => setState(() {
          if (action == 'toggle') scenario.isPublished = !scenario.isPublished;
          if (action == 'delete') scenarioStore.removeWhere((s) => s.id == scenario.id);
        }),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'toggle', child: Text(scenario.isPublished ? '초안으로 변경' : '공개하기')),
          const PopupMenuItem(value: 'delete', child: Text('삭제')),
        ],
      ),
    ),
  );
}

class ScenarioForm extends StatefulWidget {
  const ScenarioForm({required this.onSave, this.existing, super.key});
  final RoleplayScenario? existing;
  final ValueChanged<RoleplayScenario> onSave;
  @override
  State<ScenarioForm> createState() => _ScenarioFormState();
}

class _ScenarioFormState extends State<ScenarioForm> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController situation;
  late final TextEditingController actions;
  late final TextEditingController rules;
  late String industry;
  late bool published;
  late Set<String> selectedReferences;
  late Set<String> selectedRules;
  static const industries = ['카페', '편의점', '식당', '기타'];

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    title = TextEditingController(text: s?.title ?? '');
    situation = TextEditingController(text: s?.situation ?? '');
    actions = TextEditingController(text: s?.expectedActions ?? '');
    rules = TextEditingController(text: s?.linkedRules ?? '');
    industry = s?.industry ?? industries.first;
    published = s?.isPublished ?? false;
    selectedReferences = {...?s?.referenceCodes};
    selectedRules = s == null ? <String>{} : (rulesByIndustry[s.industry] ?? const <String>[])
        .where((rule) => s.linkedRules.split('; ').contains(rule)).toSet();
  }

  @override
  void dispose() {
    title.dispose(); situation.dispose(); actions.dispose(); rules.dispose();
    super.dispose();
  }

  String? requiredText(String? value) => value == null || value.trim().isEmpty ? '필수 입력 항목입니다.' : null;

  void save({required bool publish}) {
    if (!formKey.currentState!.validate()) return;
    final scenario = widget.existing ?? RoleplayScenario(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      industry: industry, title: '', situation: '', expectedActions: '', linkedRules: '',
    );
    scenario
      ..industry = industry
      ..title = title.text.trim()
      ..situation = situation.text.trim()
      ..expectedActions = actions.text.trim()
      ..linkedRules = [
        ...selectedRules,
        if (rules.text.trim().isNotEmpty) rules.text.trim(),
      ].join('; ')
      ..referenceCodes = selectedReferences.toList()
      ..isPublished = publish;
    if (widget.existing == null) scenarioStore.add(scenario);
    widget.onSave(scenario);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(publish ? '시나리오를 저장하고 공개했습니다.' : '시나리오를 초안으로 저장했습니다.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.existing == null ? '시나리오 만들기' : '시나리오 수정')),
    body: Form(key: formKey, child: content([
      const Text('연습 상황의 기본 정보와 직원이 따라야 할 대응 기준을 입력하세요.'),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: industry,
        decoration: const InputDecoration(labelText: '업종 / 매장', border: OutlineInputBorder()),
        items: industries.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() {
          industry = v ?? industry;
          selectedRules.clear();
        }),
      ),
      const SizedBox(height: 12),
      TextFormField(controller: title, validator: requiredText, decoration: const InputDecoration(labelText: '상황 제목', hintText: '예: 결제 오류 문의', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextFormField(controller: situation, validator: requiredText, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '상황 / 고객 발화', hintText: '고객이 어떤 상황에서 무엇을 요청하나요?', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextFormField(controller: actions, validator: requiredText, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '기대 응대 / 조치', hintText: '직원이 확인하고 안내하거나 실행할 내용을 적습니다.', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      ExpansionTile(
        initiallyExpanded: selectedRules.isEmpty,
        title: Text('연결된 매장 운영규칙 (${selectedRules.length}개 선택)'),
        subtitle: const Text('레퍼런스에 정리된 업종별 운영규칙'),
        children: [
          for (final rule in rulesByIndustry[industry] ?? const <String>[])
            CheckboxListTile(
              dense: true,
              title: Text(rule),
              value: selectedRules.contains(rule),
              onChanged: (checked) => setState(() {
                if (checked == true) { selectedRules.add(rule); } else { selectedRules.remove(rule); }
              }),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextFormField(controller: rules, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '추가 매장 자체 규칙 (선택)', hintText: '위 목록에 없는 매장 고유 절차', border: OutlineInputBorder())),
          ),
        ],
      ),
      ExpansionTile(
        title: Text('근거 자료 연결 (${selectedReferences.length}개 선택)'),
        subtitle: const Text('법령·공식 지침·매장 자체 규칙을 구분해 연결합니다.'),
        children: [
          for (final ref in references)
            CheckboxListTile(
              dense: true,
              title: Text('${ref.code} · ${ref.name}'),
              subtitle: Text('${ref.kind} · ${ref.scope}'),
              value: selectedReferences.contains(ref.code),
              onChanged: (checked) => setState(() {
                if (checked == true) { selectedReferences.add(ref.code); } else { selectedReferences.remove(ref.code); }
              }),
            ),
        ],
      ),
      const SizedBox(height: 18),
      SwitchListTile(title: const Text('공개 상태'), subtitle: const Text('공개된 시나리오는 상황극 연습 목록에 표시됩니다.'), value: published, onChanged: (v) => setState(() => published = v)),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: () => save(publish: false), icon: const Icon(Icons.save_outlined), label: const Text('초안 저장')),
        FilledButton.icon(onPressed: () => save(publish: published), icon: Icon(published ? Icons.publish : Icons.save), label: Text(published ? '저장 및 공개' : '저장')),
      ]),
      const SizedBox(height: 12),
      const Text('법령 적용 대상은 영업신고 유형·사업장 규모 등 사실관계에 따라 달라질 수 있습니다. 법령·공식 지침과 매장 자체 절차를 구분해 검토하세요.'),
      const SizedBox(height: 8),
      const Text('현재 시안은 앱 실행 중에만 메모리에 보관됩니다.'),
    ])),
  );
}

class Practice extends StatefulWidget {
  const Practice({required this.scenario, super.key});
  final RoleplayScenario scenario;
  @override
  State<Practice> createState() => _PracticeState();
}

class _PracticeState extends State<Practice> {
  final input = TextEditingController();
  final replies = <String>[];
  bool voice = true;
  @override
  void dispose() { input.dispose(); super.dispose(); }
  void send(String reply) => setState(() { replies.add(reply); input.clear(); });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.scenario.title)),
    body: content([
      Chip(label: Text('${widget.scenario.industry} · 상황극')),
      Card(child: ListTile(title: const Text('고객'), subtitle: Text(widget.scenario.situation))),
      for (final reply in replies) ...[
        Card(child: ListTile(title: const Text('나'), subtitle: Text(reply))),
        const Card(child: ListTile(title: Text('고객'), subtitle: Text('알겠습니다. 다음에는 어떻게 하면 될까요?'))),
      ],
      Card(child: ListTile(leading: const Icon(Icons.rule), title: const Text('연결된 운영규칙'), subtitle: Text(widget.scenario.linkedRules))),
      if (widget.scenario.referenceCodes.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('참고 근거', style: Theme.of(context).textTheme.titleMedium),
        for (final code in widget.scenario.referenceCodes)
          if (references.any((r) => r.code == code))
            _ReferenceCard(reference: references.firstWhere((r) => r.code == code)),
      ],
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('예시 응답'), icon: Icon(Icons.chat_bubble_outline)),
          ButtonSegment(value: false, label: Text('직접 입력'), icon: Icon(Icons.keyboard)),
        ],
        selected: {voice},
        onSelectionChanged: (v) => setState(() => voice = v.single),
      ),
      const SizedBox(height: 12),
      if (voice)
        OutlinedButton.icon(
          onPressed: () => send('확인 후 안내해 드리겠습니다.'),
          icon: const Icon(Icons.short_text),
          label: const Text('예시 문장 넣기'),
        )
      else
        TextField(
          controller: input,
          minLines: 1,
          maxLines: 4,
          textInputAction: TextInputAction.send,
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) { if (v.trim().isNotEmpty) send(v.trim()); },
          decoration: InputDecoration(
            labelText: '고객에게 보낼 응답',
            hintText: '응답을 입력하세요',
            suffixIcon: IconButton(
              tooltip: '응답 보내기',
              onPressed: input.text.trim().isEmpty ? null : () => send(input.text.trim()),
              icon: const Icon(Icons.send),
            ),
          ),
        ),
      const SizedBox(height: 16),
      ExpansionTile(title: const Text('기대 응대 기준 보기'), children: [Padding(padding: const EdgeInsets.all(16), child: Text(widget.scenario.expectedActions))]),
      FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Result(scenario: widget.scenario))), child: const Text('연습 종료 및 결과 보기')),
    ]),
  );
}

class Result extends StatelessWidget {
  const Result({required this.scenario, super.key});
  final RoleplayScenario scenario;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('연습 결과')),
    body: content([
      const Chip(label: Text('예시 평가 · 실제 응답과 무관')),
      Text(scenario.title, style: Theme.of(context).textTheme.headlineSmall),
      const Text('80점', style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold)),
      Card(child: ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('고객 요청 확인'), subtitle: Text(scenario.expectedActions))),
      const Card(child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('실제 평가는 아직 연결되지 않았습니다.'))),
      const SizedBox(height: 16),
      FilledButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => Practice(scenario: scenario))), child: const Text('다시 연습')),
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('목록으로')),
    ]),
  );
}

class RulesPage extends StatelessWidget {
  const RulesPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('운영규칙 및 공식 근거')),
    body: content([
      const Text('레퍼런스 문서의 출처를 법령, 공식 지침, 매장 자체 규칙으로 나누어 표시합니다.'),
      const SizedBox(height: 8),
      const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('적용 범위 확인'), subtitle: Text('가상 매장 시연 자료입니다. 실제 의무는 영업신고 유형, 취급 품목, 사업장 규모 등 적용 조건을 확인해야 합니다. 운영 절차 자체를 법적 의무라고 표현하지 않습니다.'))),
      for (final ref in references) _ReferenceCard(reference: ref),
    ]),
  );
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.reference});
  final OfficialReference reference;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.menu_book_outlined),
      title: Text('${reference.code} · ${reference.name}'),
      subtitle: Text('${reference.kind}\n${reference.scope}${reference.url.isEmpty ? '' : '\n${reference.url}'}'),
      isThreeLine: true,
    ),
  );
}

class CaseForm extends StatelessWidget {
  const CaseForm({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('현장 사례 등록')), body: content([
    const TextField(decoration: InputDecoration(labelText: '상황 제목', border: OutlineInputBorder())),
    const SizedBox(height: 12), const TextField(maxLines: 4, decoration: InputDecoration(labelText: '발생 상황과 대응 결과', border: OutlineInputBorder())),
    const SizedBox(height: 12), FilledButton(onPressed: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('제출 화면 미리보기'), content: const Text('이 화면은 예시이며 현장 사례가 저장되지는 않습니다.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))])), child: const Text('검토 요청 미리보기')),
  ]));
}



