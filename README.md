# 🟢 NIM Chatter (NVIDIA Build LLM Client)

**NIM Chatter**는 NVIDIA Build (NIM) API를 활용하여 다양한 최신 LLM(Large Language Models)과 실시간 스트리밍 대화를 나눌 수 있는 **Flutter 기반 크로스플랫폼 채팅 클라이언트**입니다.

DeepSeek, Nemotron 등의 **생각 과정(Thought/Reasoning Process)**을 시각적으로 분리하여 접고 펼칠 수 있는 인터페이스와, **Isar DB** 기반의 로컬 대화 히스토리 관리 기능을 제공합니다.

---

## ✨ 주요 기능 (Key Features)

- ⚡ **실시간 SSE 스트리밍**: NVIDIA API 응답을 실시간 글자 단위로 출력하며, 중간에 생성을 즉시 멈출 수 있는 **[취소]** 기능 제공
- 🧠 **Thinking Process 지원**: `reasoning_content`를 자동 파싱하여 AI의 생각 과정(Reasoning)을 전용 접이식 카드로 분리 표시
- 💾 **로컬 히스토리 관리 (Isar DB)**: 첫 질문 등록 시 자동으로 세션을 생성하며, 사이드바(Drawer)에서 과거 대화 기록을 선택해 언제든 대화를 이어가거나 삭제 가능
- 🎨 **Markdown & 코드 하이라이팅**: AI 답변의 Markdown 양식 및 Code Block을 깔끔하고 읽기 쉽게 렌더링
- ⚙️ **다양한 모델 선택 & Custom ID**: 기본 탑재된 대표 모델 외에 직접 NVIDIA Build의 커스텀 모델 ID를 입력하여 사용 가능
- 🟢 **NVIDIA Green Theme**: 디스플레이 친화적인 다크 모드와 NVIDIA 시그니처 그리니시 UI 구성

---

## 🛠️ 기술 스택 (Tech Stack)

- **Framework**: [Flutter](https://flutter.dev/) (Desktop, Mobile)
- **Database**: [Isar DB](https://isar.dev/) (Local NoSQL Database)
- **Networking**: `http` (Server-Sent Events streaming parser)
- **UI & Markdown**: `flutter_markdown`, `material_design`

---

## 🚀 시작하기 (Getting Started)

### 1. 사전 준비 (Prerequisites)

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x 이상 권장)
- [NVIDIA Build API Key](https://build.nvidia.com) (`nvapi-`로 시작하는 무료 키 발급 가능)

### 2. 프로젝트 클론 및 패키지 설치

```bash
# 레포지토리 클론
git clone [https://github.com/Jwdev-k/NIMChatter.git](https://github.com/Jwdev-k/NIMChatter.git)
cd NIMChatter

# 패키지 설치
flutter pub get
```

### 3. Isar 코드 제너레이터 실행
Isar 데이터베이스 스키마 생성을 위해 코드 빌더를 실행합니다.
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 💡 사용 방법 (Usage Guide)
1. 앱 실행 후 상단의 ⚙️ [API 및 모델 **설정] 아이콘을 클릭합니다.**

2. build.nvidia.com에서 발급받은 NVIDIA API Key를 입력합니다.

3. 원하는 LLM 모델을 선택합니다 (필요 시 직접 입력 (Custom) 선택 후 모델 ID 작성).

4. 채팅창에 질문을 입력하면 실시간 대화가 시작되며, 좌측 메뉴(Drawer) 버튼을 통해 과거 히스토리를 확인 및 불러올 수 있습니다

## 📂 프로젝트 구조 (Project Structure)
```
lib/
├── main.dart             # 앱 엔트리포인트 및 ThemeData 설정
├── model/                # Isar DB 및 UI 데이터 모델
│   ├── ChatMessage.dart  # 화면 노출용 메세지 모델
│   ├── chat_session.dart # Isar Collection 스키마 정의
│   └── chat_session.g.dart (build_runner로 자동 생성됨)
├── service/
│   └── isar_service.dart # Isar DB CRUD 비즈니스 로직
└── view/
    └── ChatScreen.dart   # 메인 대화 화면, 스트리밍, 사이드 메뉴 UI
```
## 📄 라이선스 (License)
- 이 프로젝트는 MIT 라이선스를 따릅니다.
