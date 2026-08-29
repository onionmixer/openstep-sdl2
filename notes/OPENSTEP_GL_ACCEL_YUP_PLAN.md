# GL 가속이 붙도록 Y_UP 요청을 걷어낸다 (2026-08-29, 코딩 전)

## 1. 사실

Matrox G450 드라이버는 OSMesa 문맥이 받은 버퍼를 비디오 메모리 표면으로
치환해 하드웨어로 그린다.  이 포트의 GL 백엔드는 그 치환이 붙는 자리를
정확히 쓴다 — `OSMesaCreateContext(OSMESA_ARGB, ...)` 와
`OSMesaMakeCurrent` — 그래서 `libGL.a` 대신 그 드라이버의 `libGL_mga.a` 로
링크하면 카드가 그려야 한다.

**그런데 붙었다가 곧바로 놓아진다.**  계측으로 확인:

```
CLAIM entered w=800 h=600 shifts=16/8/0 row=800
CLAIM TOOK IT            표면을 받았다
CLAIM released           그리고 돌려준다
```

원인은 한 줄이다.  `SDL_openstepvideo.m:2123` 이 `MakeCurrent` 직후

```c
OSMesaPixelStore(OSMESA_Y_UP, 0);
```

를 부르고, Mesa 쪽 가드가 그것을 보고 치환을 끝낸다(`osmesa.c:741`):

```c
if (OpenStepMesaAccelBoundTo(ctx)
    && (OpenStepMesaAccelStride() != ctx->rowlength || !ctx->yup))
        osmesa_leave_accel(ctx);
```

가속 경로는 행 순서를 뒤집지 못한다.  `yup = 0` 은 뒤집어 달라는 요구이므로,
틀린 그림을 그리느니 표면을 돌려준다 — **정당한 동작이다.**

## 2. 뒤집기는 이미 우리 쪽에 있다

`OPENSTEP_UpdateWindowFramebuffer` 가 present 비트맵으로 옮기며 **이미
행을 뒤집는다**:

```c
Uint8 *target = ... + ((window->h - 1 - y) * window->w + left) * 3;
```

그러므로 지금 그림이 바로 서는 이유는 **뒤집기가 두 번**이기 때문이다:
`Y_UP=0` 이 OSMesa 를 top-down 으로 만들고, 이 복사가 다시 뒤집는다.

## 3. 그러면 고치는 법은 요청을 빼고 복사를 곧게 하는 것

```
지금    Y_UP=0 (top-down) + 복사가 h-1-y   ->  present 는 bottom-up, 화면 정상
바꾼 뒤 Y_UP 요청 없음(기본 yup=1, bottom-up) + 복사가 straight
        source 행 p 가 곧 그림 행 (h-1-p) 이므로 present 행 p 에 그대로 들어간다
        ->  같은 화면, 그리고 치환이 살아남는다
```

**추가 비용이 없다.**  그 복사는 어차피 매 프레임 일어난다(32bpp -> 24bpp
변환이 그 자리에 있다).  바뀌는 것은 목적지 행 번호 계산 하나다.

## 4. 그러므로 바꾸는 것

```
GL 문맥을 바인딩할 때   OSMesaPixelStore(OSMESA_Y_UP, 0) 호출을 없앤다
present 복사            소스를 뒤집을지 말지를 인자로 받는다
GL swap                 뒤집지 않는다
2D(SDL_GetWindowSurface) 지금처럼 뒤집는다  -- SDL 표면은 top-down 이다
```

즉 **불리언 하나**가 두 경로를 가른다.

## 5. 위험

* **2D 경로를 건드리면 안 된다.**  이 포트의 시험 스위트가 통과 중이고 그
  경로가 거기 걸려 있다.  기본값은 지금 동작 그대로여야 한다.
* **그림이 뒤집히면 즉시 보인다** — 이 변경의 실패는 조용하지 않다.
* 드라이버가 없는 기계에서도 결과가 같아야 한다.  치환이 없으면 OSMesa 가
  소프트웨어로 bottom-up 을 쓰고, 곧은 복사가 그것을 옳게 낸다.

## 6. codex 에 물을 것

1. §3 의 산술이 맞나?  `yup=1` + 곧은 복사가 `yup=0` + 뒤집는 복사와 같은
   화면을 내나?
2. `OSMESA_Y_UP` 을 부르지 않는 것과 `OSMesaPixelStore(OSMESA_Y_UP, 1)` 을
   명시적으로 부르는 것 중 어느 쪽인가?  후자는 의도가 드러나지만 그
   호출도 같은 가드를 지나간다(`!ctx->yup` 이 거짓이므로 통과할 것이다)
3. 이 포트의 어느 시험이 GL 그림의 **방향**을 검사하나?  없다면 무엇으로
   회귀를 잡나 — 눈으로만인가?
4. `SDL_GetWindowSurface` 2D 경로와 GL 경로가 같은 `present_pixels` 를
   공유하는데, 한 창에서 둘을 섞어 쓰면 방향이 엇갈리나?
5. 빠뜨린 것

---

## 7. codex 교차검토 판정

| codex 주장 | 내 검증 | 결과 |
|---|---|---|
| §3 의 산술이 맞다 — `yup=1` + 곧은 복사와 `yup=0` + 뒤집는 복사가 같은 화면 | 두 방향으로 따져 같은 결론 | ✅ 일치 |
| **호출을 없애지 말고 `OSMESA_Y_UP, 1` 을 명시하라.**  `yup` 은 **문맥 상태**이지 바인드 상태가 아니라, 나중의 `MakeCurrent` 뒤에도 우리가 원하는 값을 다시 세워야 한다.  생성 기본값에 기대는 것과 다르다 | `osmesa.c:319` — `osmesa->yup = GL_TRUE` 는 **생성** 시점의 기본값이다 | ✅ **채택.  내 계획이 기본값에 기대고 있었다** |
| **방향을 검사하는 자동 시험이 없다** — GL 시험들은 창 전체를 한 색으로 지우거나 swap 전에 `glReadPixels` 를 쓴다.  둘 다 상하 반전을 못 본다 | 확인: `glReadPixels` 는 GL 좌표라 present 경로의 뒤집기를 지나간다.  방향을 보는 시험은 없다 | ✅ **사실.  시험을 새로 만든다** |
| 2D 와 GL 을 한 창에서 섞는 것은 **SDL 이 지원하지 않는 조합**이다 | `SDL_video.h:1341` — *"You may not combine this with 3D or the rendering API on this window."* | ✅ **사실** |
| 뒤집기를 **창에 저장된 상태로 두지 마라** — swap·문맥 전환·리사이즈를 건너며 낡는다.  **호출 인자**로 넘겨라 | 논리 | ✅ **채택** |
| SDL 콜백 서명을 지키고 내부 도우미를 따로 둬라 | 논리 | ✅ 채택 |
| 시험은 **양 축으로 비대칭**이어야 좌우 뒤바뀜까지 잡는다 | 논리 | ✅ 채택 |

## 8. 그러므로 만드는 것

```
OPENSTEP_PresentFramebuffer(..., SDL_bool reverse_rows)   내부 도우미
OPENSTEP_UpdateWindowFramebuffer(...)                      2D 래퍼, reverse = TRUE
OPENSTEP_GL_SwapWindow(...)                                reverse = FALSE
바인드 성공 직후                                            OSMesaPixelStore(OSMESA_Y_UP, 1)
```

그리고 **방향 회귀 시험**: 양 축으로 비대칭인 그림을 그리고 swap 한 뒤
present 비트맵의 네 모서리를 확인한다.  창 전체를 한 색으로 지우는 것으로는
아무것도 잡히지 않는다.
