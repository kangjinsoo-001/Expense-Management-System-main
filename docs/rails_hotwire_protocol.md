# AI 지침: Rails Hotwire 기능 구현 및 검증 프로토콜

## 목표
요청된 기능을 Hotwire(Turbo, Stimulus) 패러다임에 맞춰 정확하게 구현하고, 생성된 코드의 정상 동작을 체계적으로 검증한다.

---

## Phase 1: 코드 생성 프로토콜 (Proactive Implementation)

### 1. 기능 분석 및 기술 선정 (Triage)
요청된 기능의 각 구성 요소를 분석하고 아래 기준에 따라 사용할 핵심 기술을 결정한다.

* **[A] Client-Side-Only Interaction? -> Stimulus**
    * 서버 데이터 요청 없이 순수하게 프론트엔드에서 상태를 변경하는가? (예: UI 요소 토글, 클립보드 복사, 간단한 계산)
    * 그렇다면, Stimulus Controller를 구현 대상으로 지정한다.

* **[B] Self-Contained Unit Replacement? -> Turbo Frame**
    * 페이지의 특정 '영역' 하나가 다른 내용(예: 폼, 결과)으로 대체되는가?
    * 그렇다면, `turbo_frame_tag`를 구현 대상으로 지정한다.

* **[C] Multi-Element or Broadcast Update? -> Turbo Stream**
    * 단일 요청에 대한 응답으로 페이지의 여러 독립적인 영역을 동시에 변경해야 하는가? (예: 댓글 작성 시, 댓글 목록과 댓글 카운터를 모두 업데이트)
    * 실시간 브로드캐스팅이 필요한가?
    * 그렇다면, Turbo Stream을 구현 대상으로 지정한다.

### 2. 코드 생성 지침

* **Stimulus Controller 생성 시:**
    * Controller 파일 생성: `app/javascript/controllers/[identifier]_controller.js`
    * Target 선언: `static targets = [ "targetNameOne", "targetNameTwo" ]`
    * View (HTML): `data-controller="identifier"` 속성을 컨트롤러의 최상위 요소에 추가한다.
    * View (HTML): Target 요소에 `data-identifier-target="targetNameOne"` 속성을 추가한다.
    * View (HTML): Action을 유발할 요소에 `data-action="event->identifier#method"` 속성을 정확한 문법으로 추가한다.
    * Controller (JS): 선언된 method를 구현한다. Target에 접근 시 `this.targetNameOneTarget`을 사용한다.

* **Turbo Frame 생성 시:**
    * ID 정의: 교체될 영역의 `id`를 `dom_id(resource)` 또는 `"[resource_name]_[id]"` 형식의 예측 가능한 고유 ID로 정의한다.
    * 초기 View 생성: `turbo_frame_tag`를 사용해 정의된 id로 영역을 감싼다. 이 프레임 내부에 액션을 유발하는 `link_to` 또는 `form_with`를 배치한다.
    * Controller Action 구현: 요청을 처리하고, 상태에 따라 `render`할 뷰를 결정한다.
    * 응답 View 생성: Controller가 `render`하는 뷰(예: `edit.html.erb`, `show.html.erb`) 내부에 반드시 원본과 동일한 `id`를 가진 `turbo_frame_tag`로 응답 컨텐츠를 감싼다.

* **Turbo Stream 생성 시:**
    * Target ID 식별: 변경이 필요한 모든 DOM 요소의 `id`를 명확히 식별한다.
    * Controller Action 구현: `respond_to` 블록을 사용해 `format.turbo_stream` 응답을 처리하도록 설정한다.
    * Stream View 생성: `[action_name].turbo_stream.erb` 파일을 생성한다.
    * Stream View 구현: `turbo_stream.append/prepend/replace/update/remove` 헬퍼를 사용한다. 첫 번째 인자(target)는 **반드시 1단계에서 식별한 DOM 요소의 id**와 일치해야 한다.

* **JavaScript 초기화 코드 생성 시:**
    * 모든 종류의 JS 초기화 코드는 `document.addEventListener('turbo:load', () => { ... });` 블록 내부에만 위치시킨다. `DOMContentLoaded`는 사용하지 않는다.

---

## Phase 2: 검증 및 디버깅 체크리스트 (Reactive Verification)
코드를 생성한 후 또는 문제가 발생했을 때 아래 순서를 반드시 따른다.

### Checklist A: 서버 측 검증
* [ ] **Rails Server Log 확인:**
    * `Processing by [Controller]#[Action] as ...` 라인을 확인한다.
    * 예상: `as TURBO_STREAM` (Stream 요청 시)
    * 예상: `as HTML` (Frame 요청 시)
    * `as JS` 또는 의도치 않은 `as HTML`이 기록된 경우, 요청 자체의 Accept 헤더 설정이 잘못되었음을 의미한다.
* [ ] **응답 상태 코드 확인:**
    * `Completed 200 OK`: 정상 처리.
    * `Completed 422 Unprocessable Entity`: 유효성 검사 실패. `render :edit` 등이 정상적으로 호출되었는지 확인.
    * `Completed 500 Internal Server Error`: 서버 로직 에러. 스택 트레이스를 분석한다.
    * `Redirected to ...`: Turbo 요청에 대한 리다이렉트는 의도된 동작인지 확인한다. 대부분의 경우 `render`가 적합하다.

### Checklist B: 클라이언트-서버 통신 검증 (Browser DevTools > Network)
* [ ] **요청(Request) 선택:** 액션을 유발하고 생성된 Fetch/XHR 요청을 선택한다.
* [ ] **응답 헤더(Response Headers) 확인:**
    * **Content-Type**이 예상과 일치하는가?
        * Stream 응답: `text/vnd.turbo-stream.html`
        * Frame 응답: `text/html`
* [ ] **응답 본문(Response Body) 확인:**
    * **Turbo Frame의 경우:**
        * [ ] 응답에 `<turbo-frame>` 태그가 포함되어 있는가?
        * [ ] 해당 태그의 `id` 속성값이 원본 페이지의 `<turbo-frame>` id와 정확히 일치하는가?
    * **Turbo Stream의 경우:**
        * [ ] 응답에 하나 이상의 `<turbo-stream>` 태그가 포함되어 있는가?
        * [ ] 각 태그의 `action` (`replace`, `append` 등)이 의도와 맞는가?
        * [ ] 각 태그의 `target` 속성값이 페이지에 **실제로 존재하는 DOM id**와 일치하는가?

### Checklist C: 프론트엔드 검증 (Browser DevTools > Console & Elements)
* [ ] **JavaScript Console 확인:**
    * [ ] `Uncaught Error`가 있는가?
    * [ ] Stimulus 관련 에러 (`Missing target`, `Controller not registered`)가 있는가?
    * [ ] 에러가 있다면, 스택 트레이스를 분석하여 원인(오타, 잘못된 target/action 등)을 파악한다.
* [ ] **Elements 탭 확인:**
    * **DOM 구조 검사:**
        * [ ] Turbo Frame/Stream의 `target id`가 올바른 요소에 오타 없이 적용되었는가?
        * [ ] Stimulus `data-controller` 식별자가 컨트롤러 파일명과 일치하는가? (`my_controller.js` -> `data-controller="my"`)
        * [ ] Stimulus `data-action` 속성의 문법(`event->controller#method`)이 정확한가?
        * [ ] Stimulus `data-[controller]-target` 속성값이 `static targets` 배열 내의 이름과 일치하는가?

---

### 프로토콜 종료 조건
모든 체크리스트 항목이 통과되면, 구현은 성공적으로 완료된 것으로 간주한다. 항목 중 하나라도 실패 시, 해당 항목의 지침에 따라 코드를 수정하고 처음부터 체크리스트를 다시 실행한다.