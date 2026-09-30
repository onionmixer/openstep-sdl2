# openstep.5 재패키징 계획 — SDL2 스트림 오디오 기본값, sdl2quake 1.4 동반

작성 2026-09-29.  코딩(버전 문자열·검사 추가) 전 계획이다.  codex 교차검토 판정표는 끝 절.

## 0. 확인한 사실 (이 세션에서 직접 연 것)

| # | 사실 | 근거 |
|---|---|---|
| F1 | 워킹트리 미커밋 변경 4 파일: 오디오 `SDL_openstepaudio.{h,m}`(NXPlayStream 경로, **기본값**; `SDL_OPENSTEP_AUDIO_API=sound` 로 옛 경로), 비디오 `SDL_openstepvideo.{h,m}`(소프트웨어 표면 present 가 바뀐 합집합 사각형만 displayRect) | `git diff --stat`, 오디오 `.m` 의 `if (e == NULL \|\| SDL_strcmp(e, "sound") != 0)` |
| F2 | 태그 `v2.32.10-openstep.4` 뒤 미릴리스 커밋 `4f19fc7`(데모가 설치된 Mesa 에 링크) | `git log` |
| F3 | 오디오 `.m` 은 22:28 실험본(`_w1stage/sdlstream`, 스트림 opt-in)과 **기본값 뒤집기 3 곳만** 다르다 | `diff` 출력 |
| F4 | 기본값 판은 water1 에서 돌았다: `API stream`, submitted/started/completed 1111, underruns 0, failed 0, timeouts 0 | `_w1stage/final/verify1.log` |
| F5 | **실기 `/LocalDeveloper/Libraries/libSDL2.a` 는 openstep.4 가 아니다**: 1,371,636 B(= `_w1stage/sdlstream/libSDL2-stream.a` 크기), 공개 openstep.4 는 1,361,752 B.  영수증은 openstep.4 그대로 — 손으로 덮어쓴 실험본 | nxrun `ls -l`/`sum`, 공개 자산 추출 |
| F6 | 공개된 sdl2quake 1.3 세 바이너리에는 `NXPlayStream`·`SDL_OPENSTEP_AUDIO_API` 문자열이 0 개, `SDL_OPENSTEP_AUDIO_REPORT` 1 개 — openstep.4 로 링크됐다(실험본 오염 없음) | python 바이트 검사 |
| F7 | SDL2 를 **패키지 안에** 싣는 것: SDL2 자신(Libraries·Demos 6 바이너리), sdl2quake 세 바이너리(정적 링크).  radeon DemosRDN·Matrox DemosMGA 의 SDL 티팟은 소스만, Mesa 는 무관, water1 은 패키지 없음, sdl12 는 별개 포트 | 각 빌더 grep |
| F8 | 소비자 링크 줄은 모두 이미 `-framework SoundKit` — 새 SoundKit 클래스 참조로 링크가 깨지지 않을 것(실기 링크로 확인할 것) | grep |
| F9 | 배포 문서(`release-docs/`)에 오디오 서술 없음; 버전 문자열은 `.info` 3 개·`release-packaging/OpenStepSDL2.info`·`release-docs/RELEASE-MANIFEST.txt`(Headers 페이로드)·README | `git grep openstep.4` |
| F10 | 실기 루트 90 % 사용, 여유 176 MB | `df` |

## 1. 범위

- **SDL2 `2.32.10-openstep.5`**: Libraries·Headers·Demos 세 패키지 모두(버전 동반).  Headers 는 공개 헤더 불변, 매니페스트 버전만.
- **sdl2quake 1.4**: `squake`·`glquake_g450`·`glquake_radeon` 을 설치된 openstep.5 로 재링크.  `sdl2quake-libre` 는 그대로(1.0).
- 제외: radeon 1.0·Matrox 1.4·Mesa(SDL2 바이너리 없음), water1(패키지 없음, 필요하면 재빌드만), sdl12.

## 2. 빌드 전 소스 편집 (페이로드라 먼저)

1. 버전 `2.32.10-openstep.4` → `.5`: `packaging/openstep/OpenStepSDL2{Libraries,Headers,Demos}.info`, `release-packaging/OpenStepSDL2.info`, `release-docs/RELEASE-MANIFEST.txt`.  README 의 "Latest release" 와 릴리스 노트는 **공개 단계에서**(페이로드 아님).
2. sdl2quake: `pkg/sdl2quake.info` Version 1.4, `README.md` 에 1.4 한 줄(README 는 페이로드 — 패키지 전에).
3. 게이트 추가(판별 문자열):
   - SDL2 빌드 뒤: 새 `libSDL2.a` 에 `SDL_OPENSTEP_AUDIO_API` 가 있어야 한다(없으면 옛 소스로 빌드된 것).
   - `pkg/build-sdl2quake-pkg.sh`: 세 바이너리 모두 `SDL_OPENSTEP_AUDIO_API` 를 담아야 한다 — 설치 prefix 가 openstep.4(또는 실험본 이전)면 거절.  실험본(F5)도 이 문자열을 담으므로 **이 게이트만으로는 실험본을 못 가른다** → 4 단계의 설치 확인이 그것을 맡는다.

## 3. A 단계 — SDL2 빌드·검증 (실기, 설치 없음)

1. `csh -f /ndrv/openstep-sdl20/build/stage-openstep.csh /ndrv` (워킹트리를 `/me/SDL20/src` 로)
1a. **`csh -f /me/SDL20/src/build/prepare-openstep-tree.csh`** — 빌드 트리(`/me/SDL20/build/SDL-2.32.10-openstep`)를 지우고 staged 소스로 다시 만든다.  컴파일 게이트는 staged 트리가 아니라 **빌드 트리의 src** 를 읽으므로(Q1) 이것을 빼면 옛 오디오·비디오 소스로 "새로" 컴파일된다.
1b. NFS 낡은 크기 함정: 빌드 트리의 `SDL_openstepaudio.{h,m}`·`SDL_openstepvideo.{h,m}` 와 바꾼 `.info`·매니페스트의 `wc -c` 를 호스트 값과 대조, 다르면 중단.
2. `csh -f /me/SDL20/src/packaging/openstep/build-split-packages.csh` — 전체 아카이브 재빌드(API 836 검사·i386 검사 포함) + 데모 6 개 + 세 패키지.  길어서 gcds 백그라운드 + done 파일.
3. `csh -f /me/SDL20/src/packaging/openstep/verify-package.csh`
4. 호스트 판정(python): 빌드 `libSDL2.a` 에 `SDL_OPENSTEP_AUDIO_API`·`NXPlayStream` 존재, 페이로드 `libSDL2.a` == 빌드 산출물, 세 `.info` 버전 openstep.5, 매니페스트 `port_revision=2.32.10-openstep.5`.
5. 실행 스모크(설치 전, 빌드 산출물에 링크): 소리 계측기(`test/openstep/sndcost.c`, 무음 재생)를 새 아카이브로 링크해 `SDL_OPENSTEP_AUDIO_REPORT=1` 로 두 팔 — 기본(`API stream`, underruns 0·failed 0·timeouts 0), `SDL_OPENSTEP_AUDIO_API=sound`(옛 경로 보고).  화면에 그리지 않는다.
6. `/me/packages/sdl2/` 교체, 옛 openstep.4 는 `/me/packages/old/sdl2-openstep.4/` 로 이동.

→ **사용자 설치 1 차**: SDL2 Libraries·Headers·Demos (openstep.5).

## 4. 설치 확인 (실기)

- 영수증 세 개 Version openstep.5.
- 설치된 `/LocalDeveloper/Libraries/libSDL2.a` 를 `/ndrv` 로 복사해 호스트 python 으로 **ar 멤버 단위** 대조(post_install 의 ranlib 때문에 전체 바이트는 다를 수 있다 — 심볼표 멤버 제외 전 멤버 동일이어야).  이것이 F5 실험본이 남아 있지 않다는 증거.

## 5. B 단계 — sdl2quake 1.4 (실기)

1. 사슬(새 스크립트, `rel1-quake-chain.sh` 틀): 사적 prefix 에 **설치된** `libSDL2.a`·`libGL.a` 복사 + Matrox 1.4 `libGL_mga.a`(`openstep-matrox-remade/build/mesa/`) + radeon `build/m1b/790662776/libGL_radeon.a`.
2. `squake` = `build-openstep-quake.sh`(1.3 은 1.2 바이트를 복사했었다 — 이번엔 재링크), `glquake` = `build-glquake.sh`, `glquake_radeon` = 같은 스크립트 `ACCEL=radeon`.
3. `build-sdl2quake-pkg.sh` → 기존 게이트(카드별 심볼) + 2-3 게이트.
4. 호스트: 세 바이너리 판별 문자열, 1.3 대비 라이브러리 멤버 이외 불변은 요구하지 않는다(재링크).
5. `/me/packages/quake/sdl2quake.pkg` 교체, 옛 것은 `/me/packages/old/quake-1.3/`.

→ **사용자 설치 2 차**: sdl2quake 1.4 (libre 는 그대로).

## 6. 설치 뒤 실행 시험

- `glquake_radeon +map start` 300 프레임(자가 실행 러너, 120 초 상한, 사용자 gcdsd — 화면에 그린다): judge_g50 PASS + 오디오 보고 `API stream`·underruns 0·failed 0.
- `squake` 짧은 실행: 오디오 보고 `API stream`.
- `glquake_g450`: G450 없음 — 링크·심볼 게이트까지(1.4 와 같은 조건).

## 7. 그 뒤 (사용자 승인 후)

SDL2: 커밋(변경 4 + 버전 + 계획) → 릴리스 노트 openstep.5 → push → 태그 `v2.32.10-openstep.5` → 자산 3 + SHA256SUMS → 재다운로드 대조.  Quake: 커밋 → subtree split → blob 검사 → push → v1.4 릴리스(`--target`).  메모리 갱신(F5 교훈 포함).

## 8. 위험

- R1 전체 아카이브 재빌드가 길다(nxrun 180 초 초과) → gcds 백그라운드.
- R2 디스크 176 MB — `/me/SDL20` 페이로드·dist 는 기존 것을 덮어쓴다(증가분 작음).  Quake 사적 prefix 는 `/tmp`.
- R3 사용자가 Headers 를 빼고 Libraries 만 설치하면 영수증 버전이 섞인다 → 세 개 모두 설치 안내.
- R4 스트림 경로의 장시간 안정성은 water1 1 회(F4)가 전부 — 6 절 GLQuake 시험이 두 번째 소비자.

## 9. codex 교차검토 판정 (gpt-6-astra, 한 호출 한 주장)

| # | codex 주장 | 내 검증 | 판정 |
|---|---|---|---|
| Q1 | stage → build-split-packages 만으로는 오디오·비디오 객체가 새로 컴파일되지만 **입력은 빌드 트리의 옛 소스**일 수 있다(PARTLY) | 연 줄: `build/compile-openstep-audio-bootstrap-gate.csh` 3–13(입력 `$build_root/src/audio/openstep/SDL_openstepaudio.m`), `compile-openstep-video-bootstrap-gate.csh` 5–20, `build-sdl2-openstep-release-archive.csh`·`build-sdl2-openstep-diagnostic-archive.csh`(prepare 호출 없음), `prepare-openstep-tree.csh`(빌드 트리 `rm -rf` 후 70–71·145–147 행에서 포트 오디오·비디오 복사).  워크스페이스 `tools/rebuild-openstep-sdl2-release-archive.sh` 도 stage 다음 prepare 를 부른다 | ✅ 채택 — 3 절 1a 추가 |
| Q2 | 부분 displayRect 는 맞다: `SDL_OpenStepView -isFlipped` YES, `drawRect:` 가 `[_bitmap drawInRect:[self bounds]]` 로 추가 뒤집기 없음, `reverse_rows` 는 비트맵 저장 행만 바꿔 표시 행 y ↔ 표면 행 y 대응을 보존, GL 경로는 rect 없이 전체 | 연 줄: 908–911(isFlipped YES), 935–960(drawRect), 1509–1519(view 생성), 2055–2062(행 방향 주석), 2107–2110(`drow`), 2694–2704(GL 경로 `NULL, 0, SDL_FALSE`) | ✅ 채택 — 변경 없음 |

## 10. A 단계 결과 (2026-09-29)

- 사슬 `test/openstep/rel5-phase-a.sh`: stage·prepare·staged 크기 대조(8 파일 호스트와 일치)·split(API 836, 전 멤버 i386)·verify PASS.  첫 실행의 스모크 링크 실패는 내 링크 줄에 `libGL.a` 가 빠진 것(SDL_Init 이 비디오 백엔드를 끌어온다) — `rel5-smoke.sh` 로 다시.
- 라이브러리 1,371,636 B, sum `34032 1340`, 빌드 산출물 == 페이로드(python).  `SDL_OPENSTEP_AUDIO_API` 1·`NXPlayStream` 4.  데모 6 개 모두 새 SDL2.
- Headers 페이로드는 공개 openstep.4 와 89 파일 중 `RELEASE-MANIFEST.txt` 하나만 다르다.
- 무음 스모크(설치 전, 빌드 산출물 링크): 기본 = `API stream`, submitted/started/completed 229, underruns 0·failed 0·timeouts 0, 갭 전부 <25 ms, 오디오 스레드 18; `SDL_OPENSTEP_AUDIO_API=sound` = 옛 경로 보고(228 버퍼, 갭 <25 ms).
- 배치: `/me/packages/sdl2/` 세 개 openstep.5(바이트 대조 PASS), 옛 판은 `/me/packages/old/sdl2-openstep.4/`.
- 도중에 워크스페이스 `_w1stage/` 가 외부에서 삭제됐다(이 작업이 한 일 아님).  SDL2 소스는 그 전후 크기·시각 불변(22:46) 확인.

## 11. 1 차 설치 확인과 B 단계 결과 (2026-09-29)

- 사용자 설치 뒤 영수증 세 개 openstep.5.  설치된 `libSDL2.a` 를 호스트로 복사해 ar 멤버 대조: `__.SYMDEF SORTED` 를 뺀 121 멤버가 이름·바이트·순서 모두 빌드 산출물과 동일(심볼표만 post_install 의 ranlib 로 다름) — 손으로 덮어썼던 실험본(F5)은 사라졌다.
- `openstep-quake/build/rel14-chain.sh`: 새 게이트가 1.3 바이너리를 **거절**(`squake is linked against an SDL2 older than openstep.5`) 한 뒤 세 엔진 재링크(squake 는 이번엔 소스에서) → 패키지 PASS, Version 1.4.  sum: squake `53258 2806`, glquake `54763 2856`, glquake_radeon `28802 2895`.
- 호스트(python): 파일 목록 1.3 과 동일, 세 바이너리 == 빌드 산출물, 전부 `SDL_OPENSTEP_AUDIO_API` 1·`NXPlayStream` 5, 훅 문자열 수는 1.3 과 같다(g450 MGA 203, radeon MGA 34·RDN 7 — radeon 쪽 MGA 문자열은 정의가 아니라 참조, 빌더의 `nm ... 'T _OSMGAMesaHook'` 게이트 0), README·LICENSE == 소스.
- 배치: `/me/packages/quake/sdl2quake.pkg` 1.4, 옛 1.3 은 `/me/packages/old/quake-1.3/`.  libre 1.0 그대로.

## 12. 2 차 설치 뒤 실행 시험 — **릴리스 보류 사유 발견** (2026-09-29)

설치 확인: 영수증 sdl2quake 1.4, 설치된 세 바이너리 sum == 빌드(`53258 2806`·`54763 2856`·`28802 2895`).

| 실행 | 결과 |
|---|---|
| `glquake_radeon` 300 프레임(me, 소리 켬) | 위임 0, 월드 15.3 ms(tick 기준), judge_g50 의 `296 vs 299` FAIL 은 G5-6 에 기록된 소리 켬 적재 중 무present 프레임(거절 아님).  오디오 `API stream`, 149 제출/완료, underrun 0·failed 0, 그러나 적재 중 refill gap ≥500 ms 2(최대 660), `queue seen empty 3`.  `RDN-A lost=1`(같은 부팅 앞 판정 0) = 알려진 CP 멈춤 1 회(radeon HANDOFF 미해결 1) |
| `squake` ~45 s | `API stream` 707 제출/완료, 갭 전부 <25 ms, underrun 0·failed 0 |
| 적재 갭 A/B(python 집계, 번갈아) | 1.3(openstep.4) 3 회: ≥500 ms 2·1·1, 최대 601·631·1406.  1.4(openstep.5) 3 회: 2·3·1, 최대 660·1210·830.  **둘 다 적재 때 끊긴다** — 게임의 프레임 전체 `SDL_LockAudio` 와 적재 I/O(기존 분석); openstep.5 가 고치지도 뚜렷이 악화시키지도 않는다(표본 작음) |
| **이상 종료 1 회** | `ab2-1`(me, 1.4): Sound Initialization 의 열고-닫기 뒤 게임용 재열기 **약 2 초 만에 프로세스 소멸**, 두 번째 장치의 오디오 보고 없음, stdout 꼬리 유실(신호형 종료 모양), 같은 순간 커널 `AS: replyStreamStatus returns -102` ×2(15:48:44 = 로그 시각 환산 일치).  코어 없음(`/usr/local/quake` 는 me 쓰기 불가).  같은 메시지는 이 부팅에서 22:29(다른 세션의 스트림 실험 때) 한 번 더 있다 |
| 반복 | root 6 회·me 6 회 모두 exit 0·300 tick.  **1.4 누계 16 회 중 1 회 이상 종료** |

**가설(코드 읽기, 미증명)**: `StreamClose`(445–498) 가 `owner = NULL` 을 잠금 안에서 쓰고 대리자를 release 한 뒤 `mutex_free(st_lock)`, 이어서 코어가 `h` 를 해제한다.  그런데 대리자 콜백(245–279)은 `h = owner` 를 **잠금 없이** 읽고 나서 `mutex_lock(h->st_lock)` 한다 — 읽은 직후 닫기가 끝나면 해제된 잠금·구조체를 쓴다.  또 `deactivate` 뒤 SoundKit 응답 스레드에 이미 들어 있던 콜백(`didStartBuffer` 는 `st_outstanding` 으로 기다리지 않는다)이 release 된 대리자에게 배달될 수 있다.  창은 "열고 바로 닫고 다시 여는" 순간 — Quake 의 S_Init 이 정확히 그 모양이다.

**결정 필요(사용자)**: 이 상태로 릴리스하지 않는다.  선택지는 7 절 전에 사용자에게.

## 13. 재현과 원인 (2026-09-29) — 12 절의 가설은 틀렸다

**12 절 가설(닫기-재열기 경합)은 재현되지 않았다**: `test/openstep/sndreopen.c`(열고·무음 재생·닫기 반복, LCG 일정)로 설치된 openstep.5 에서 200 회(0–300 ms, stream·sound 두 팔) + 500 회(0–20 ms, stream, 보고 켬) — 실패 0, 500 보고 모두 `freed 1`, 늦은 콜백 0(python 집계).  게다가 ab2-1 은 닫기 때가 아니라 **게임 장치가 돌기 시작한 뒤** 죽었다.

**재현**: root 로 `glquake_radeon` 30 회(`build/rel14-rep.sh stream 30`) — **3 회 이상 종료**(run 1: exit 255, run 2·19: `abort - core dumped`, 코어 둘 `_ndrv_scratch/sdl5/core-stream-{2,19}`), 셋 다 tick 2(= ab2-1 과 같은 자리: Quake Initialized 직후).  로그의 마지막 줄:
- run 19: `objc: FREED(id): message decodeReturnValueWithCoder: sent to freed object=0x4a5baf8`
- run 2: `objc: FREED(id): message addObject: sent to freed object=0x4c93ea8`

**원인(문서 근거 + 코드)**:
- Foundation `NSThread` 문서: "Do not interchange the use of the cthreads functions and NSThread objects within an application.  In particular, **do not use cthread_fork() to create a thread that executes an Objective-C message.**"  `isMultiThreaded` 는 `detachNewThreadSelector:` 로 만든 스레드가 있을 때만 YES.
- SDL 스레드는 `cthread_fork`(`port/openstep/src/thread/openstep/SDL_systhread.c:37`).  포트 어디에도 `NSThread`·`isMultiThreaded` 없음(grep 0).
- 스트림 경로는 SDL 오디오 스레드(cthread)에서 **버퍼마다** Objective-C 를 보낸다: `OPENSTEPAUDIO_StreamSubmit` 의 `[[NSAutoreleasePool alloc] init]`(393 행 부근)과 `playBuffer:size:tag:`.  비디오는 주 스레드에 프로그램 수명 풀(`SDL_openstepvideo.m:1384`)을 둔다.  단일 스레드 모드 Foundation 에서 두 스레드의 풀 생성·해제가 한 풀 스택에 섞이면 한쪽이 다른 쪽 풀을 해제하고 그 풀에 `addObject:` 를 보낸다 — 로그와 같은 모양.
- per-sound 경로는 libsound C(`SNDStartPlaying`)라 오디오 스레드에서 Objective-C 를 보내지 않는다 — 그래서 openstep.4·1.3 에서는 없었다(1.3 실행에서 이상 종료 0).

**결론**: 스트림 경로의 결함은 "닫기 경합"이 아니라 **cthread 에서 Objective-C 를 실행하는 것** 자체다.  water1 1 회(F4)·squake 1 회·sndcost·sndreopen 700 회가 멀쩡했던 것은 주 스레드가 그 순간 풀을 만지지 않았기 때문으로 본다(빈도 약 1/10, GLQuake 시작 직후에 몰림).

## 14. 수정 계획 — SoundKit 전담 NSThread (사용자 선택, 코딩 전)

**원칙**: 스트림 경로의 Objective-C 메시지(SoundKit 객체 생성·`activate`·`playBuffer:size:tag:`·`deactivate`·release, 그리고 `NSAutoreleasePool`)는 **`detachNewThreadSelector:toTarget:withObject:` 로 만든 NSThread 하나에서만** 보낸다.  SDL 오디오 스레드(cthread)와 호출 스레드는 C(cthreads `mutex_t`/`condition_t`)로 요청을 넘기고 결과를 기다린다.

1. **전역 상태**(파일 static, 해제 안 함): 요청 뮤텍스 `sk_lock`, 조건 `sk_req`·`sk_done`, 요청 칸 하나 `{op, h, slot, tag, result, pending, done}`, 작업 스레드 시작 여부.  뮤텍스·조건은 `OPENSTEPAUDIO_Init`(드라이버 등록, 한 번)에서 `mutex_alloc`/`condition_alloc` — 순수 C.
2. **작업 스레드**: 스트림 경로가 처음 열릴 때(`StreamOpen`, 호출 스레드) 한 번 `detachNewThreadSelector:` — 이 한 줄이 이 경로에서 호출 스레드가 보내는 유일한 Objective-C 이다(보통 주 스레드; 다른 cthread 에서 SDL 을 여는 앱은 이 한 번이 계약 밖이라는 것을 문서화).  작업 스레드는 시작하자마자 `SDL_SYS_SetThreadPriority(SDL_THREAD_PRIORITY_TIME_CRITICAL)`(오디오 스레드와 같은 사다리) 뒤 무한 루프: `sk_req` 대기 → 요청마다 `NSAutoreleasePool` 을 만들고 op 실행 → 풀 해제 → 결과 기록 → `sk_done` 신호.
3. **op 셋, 전부 동기 RPC**(요청자가 완료까지 기다림, 요청은 `sk_lock` 으로 한 번에 하나):
   - OPEN: 지금 `StreamOpen` 의 SoundKit 부분(NXSoundOut·NXSoundParameters·NXPlayStream·대리자·activate).  링 `vm_allocate` 등 C 부분은 호출 스레드에 그대로.
   - SUBMIT: `playBuffer:size:tag:` 하나.  태그 예약·링 복사·실패 되돌림은 SDL 오디오 스레드에 그대로(C).
   - CLOSE: `deactivate`, (완료가 다 돌아왔을 때만) `setDelegate:nil`·release 셋.
4. **대리자 콜백과 닫기의 수명**(12 절의 잠금 없는 `owner` 읽기 — 재현은 안 됐지만 같은 함수의 잠재 결함): 장치별 `st_lock` 을 **프로세스 전역, 해제하지 않는 잠금**으로 바꾸고, 콜백은 그 잠금 **안에서** `owner` 를 읽는다.  닫기는 그 잠금 안에서 `owner = NULL` 뒤에만 `h` 해제로 간다.  (장치별 잠금을 전역으로 합치는 것 = 제출·대기·콜백이 모두 한 잠금 — 경합은 버퍼당 몇 번이라 무시할 만하다.)
5. per-sound 경로·비디오는 손대지 않는다.

**검증 계획**
- 빌드: stage → prepare → split → verify(A 단계 사슬 그대로).  호스트: 빌드 `libSDL2.a` 의 `nm` 에 `_objc_msgSend` 호출 위치를 셀 수는 없으니, 대신 **소스 규칙**: 스트림 경로에서 Objective-C 메시지 식(`[` … `]`)이 작업 스레드 함수와 첫 detach 한 줄 밖에 없음을 python 으로 검사(`SDL_openstepaudio.m` 의 스트림 함수들 범위).
- 설치 전(빌드 산출물 링크): `sndcost` 두 팔, `sndreopen` 500 회(0–20 ms) — 기존과 같은 결과(갭·underrun·freed) 이어야.
- 설치 후(사용자 SDL2·Quake 재설치): **GLQuake 60 회 root**(기준선 30 회 중 3 회 이상 종료).  0/60 이면 p=0.1 가정에서 우연일 확률 0.9^60(python 으로 계산해 기록).  + me 로 몇 회, squake 1 회, 오디오 보고(갭·underrun·failed) 비교.
- 실패하면: 선택지 2(기본값을 per-sound 로)로 물러난다.

### 14.1 codex 교차검토 (gpt-6-astra, 한 호출 한 주장)

| # | codex 주장 | 내 검증 | 판정 |
|---|---|---|---|
| Q3 | 스트림 경로의 Objective-C 식 전부와 실행 스레드: `StreamOpen` 298–353(호출 스레드), `StreamSubmit` 393–396(**SDL 오디오 스레드**, 버퍼마다), `StreamClose` 448–497(닫는 스레드, SDL 은 오디오 스레드를 먼저 join), 대리자 세 메서드엔 없음; per-sound 의 Play/Wait 에는 Objective-C 0(`SNDStartPlaying` 709, `SNDWait` 202) | python 으로 같은 파일의 메시지 식을 함수별로 뽑아 298·308·314·325·326·329·332–337·340·343·346·347·349·352·393·394·396·448·462·465·469·475·479·483·496 — codex 목록과 일치.  `SDL_audio.c` 699(ThreadInit)·770/778/788(Play/Wait)·1206 join → 1224 CloseDevice·1434(OpenDevice)·1556(스레드 생성)·1675–1677 원문 확인 | ✅ |
| Q4 | 현 코드에서 SoundKit 호출 지점에 `st_lock` 을 쥔 스레드가 없다(HOLDS) — 작업 스레드로 옮기고 잠금을 전역으로 합쳐도 `st_lock` 경유 교착은 안 생긴다(경계를 지키는 한) | 잠금/해제 20 줄 원문(366/373, 381/390, 398/403, 417/419, 421/424, 453/455, 472/474, 대리자 250/252·261/269·276/278) 확인, 사이에 메시지 식 없음.  `SDL_audio.c` 의 `mixer_lock` 은 앱 콜백만 감싸고 Play/Wait 전에 푼다(RunAudio 732–738 부근) | ✅ — **구현 규칙으로 고정**: 전역 스트림 잠금을 쥔 채 작업 스레드를 기다리지 않는다 |

### 14.2 구현 세부 (codex 뒤, 내가 추가로 정한 것)

- **SDL 오류는 스레드별이다**: 작업 스레드에서 `SDL_SetError` 하면 요청자가 못 본다 → 작업 스레드는 정적 문자열·코드만 돌려주고 요청자가 `SDL_SetError`.
- **대리자는 해제하지 않는다**(열 때마다 객체 하나 누수): `setDelegate:nil` 뒤에도 응답 스레드가 이미 집어 든 대리자 포인터로 메시지를 보낼 수 있다 — 해제된 대리자로 가면 이번과 같은 FREED 충돌.  `owner = NULL` 을 전역 잠금 안에서 쓰고, 대리자는 영구.
- `OPENSTEPAUDIO_Init` 은 `SDL_AudioInit` 마다 다시 불릴 수 있다 → 전역 뮤텍스·조건은 NULL 일 때만 만든다(해제하지 않음, 작업 스레드는 프로세스 수명).
- 조건 대기는 `while (조건) condition_wait` — 작업 스레드가 아직 기다리기 전에 온 신호도 잃지 않는다.

### 14.3 구현 (2026-09-29, 실기 빌드 전)

- `SDL_openstepaudio.m`: 대리자~`StreamClose` 구간(편집 전 237–498 행)을 교체.  전역 `openstep_stream_lock`(장치별 `st_lock` 대체)·요청 칸 `openstep_sk`(+ `openstep_sk_lock`·`openstep_sk_req`·`openstep_sk_done`), SoundKit 스레드 클래스 `OPENSTEPAudioSoundKitThread`(시작 때 `SDL_SYS_SetThreadPriority(TIME_CRITICAL)`, 요청마다 풀), 작업 함수 `SkOpen`·`SkSubmit`·`SkClose`, 요청자 `SkStart`(한 번 detach)·`SkCall`(동기 RPC).  `OPENSTEPAUDIO_Init` 에서 잠금·조건을 NULL 일 때만 생성.  대리자는 해제하지 않고 `owner = NULL`(전역 잠금 안).  `#import <Foundation/Foundation.h>`, `../../thread/SDL_systhread.h` 추가.
- 헤더: `st_lock` 제거, 주석 갱신.
- 편집 전 사본: 세션 스크래치 `sk-pre/`.
- **호스트 소스 규칙(python)**: 메시지 식 22 개가 전부 `SkOpen` 11·`SkSubmit` 1·`SkClose` 4·`run:` 2·`SkStart` 4 안 — 밖 0.  `Sk{Open,Submit,Close}` 호출은 `run:` 안(442·445·449 행)에만, `SkCall` 셋(560·601·669 행)은 모두 스트림 잠금 밖.

### 14.4 수정본 빌드·설치 전 시험 (2026-09-30, 실기 재부팅 뒤)

- A 단계 사슬(크기 대조표를 새 소스로 갱신, 스모크는 따로): stage·prepare·크기 일치·split(API 836, i386)·verify PASS.  오디오 컴파일 경고 0, 링크 경고는 v1 과 같은 libm `pow.o` 6 줄.
- 라이브러리 sum `49484 1344`, 빌드 == 페이로드.  v1 대비 122 멤버 중 **`m38.o`(오디오) 하나만** 다르고 `OPENSTEPAudioSoundKitThread`·`detachNewThreadSelector`·`condition_wait` 를 담는다(python ar 대조).
- 설치 전 시험(빌드 산출물 링크): sndcost 스트림 229 제출/완료·underrun 0·failed 0, sound 팔 정상.  sndreopen 스트림 500 회(0–20 ms)·200 회(0–300 ms), sound 200 회 — 실패 0, 전부 `freed 1`, 늦은 콜백 0, `FREED` 메시지 0.
- 배치: `/me/packages/sdl2/` 수정본, 첫 openstep.5 는 `/me/packages/old/sdl2-openstep.5-v1/`.
- SDL2 재설치 확인: 영수증 셋 openstep.5, 설치된 `libSDL2.a` 121 멤버 == 수정본 빌드(python).
- sdl2quake 게이트를 강화: 판별 문자열을 `SDL_OPENSTEP_AUDIO_API` 에서 **`OPENSTEPAudioSoundKitThread`** 로 — 첫 openstep.5 도 스위치 이름은 가졌으므로 그것으로는 결함판을 못 가른다.  사슬의 음성 시험이 설치돼 있던 첫 1.4 바이너리를 거절(`... SoundKit-thread backend`) 한 뒤 재링크 PASS.  sum squake `32333 2807`, glquake `53595 2857`, glquake_radeon `46365 2896`.  세 바이너리 모두 SoundKit 스레드 표지 4, 훅 문자열 수는 이전과 같음, README == 소스.
- 배치: `/me/packages/quake/sdl2quake.pkg`(새 1.4), 첫 1.4 는 `/me/packages/old/quake-1.4-v1/`.

## 15. 수정본 설치 뒤 GLQuake 60 회 (root, 2026-09-30)

설치 확인: 영수증 1.4, 세 바이너리 sum == 새 빌드.  `build/rel14-rep.sh stream 60` → **60/60 exit 0·300 tick, `FREED` 메시지 0, `API stream` 60, underrun 0, failed 0.**  수정 전 root 30 회 중 3 회 이상 종료 대비: p=3/30 에서 0/60 일 확률 0.0018, Fisher 단측(30 중 3 vs 60 중 0) 0.035(python).  **충돌은 고쳐졌다.**

**그러나 적재 중 소리가 더 자주 비었다** (python 집계, 같은 하네스·root, 수정 전 = `prefix-fix/rep-stream-*-root.log` 중 끝까지 돈 27 회):

| | 수정 전(첫 openstep.5) | 수정 후 |
|---|---|---|
| queue seen empty / 회 | 평균 2.93, 중앙 3, 최대 6 | **평균 6.77, 중앙 6, 최대 18** (Mann-Whitney p = 1.9e-11) |
| 최악 refill gap | 중앙 1040 ms, 최대 1371 | 중앙 1310 ms, 최대 1460 (p = 0.030) |
| ≥500 ms 갭 / 회 | 1.59 | 1.53 |
| 최악 제출 시간 | 중앙 676 ms | 중앙 154 ms |

`queue seen empty` 는 PlayDevice 가 불릴 때 우리 버퍼가 하나도 걸려 있지 않은 경우(장치가 말랐다, 955 행).  제출 한 건의 최악은 짧아졌는데 마르는 횟수는 늘었다 — 제출이 **느려진** 것이 아니라 **늦게 도는** 쪽(작업 스레드가 제때 스케줄되지 않음)을 의심한다.  작업 스레드의 우선순위는 `SDL_SYS_SetThreadPriority(TIME_CRITICAL)` = base + 10 (최대 캡) 인데 NSThread 의 base 가 무엇인지, 올리기가 성공했는지는 **재지 않았다**.

**다음(사용자 결정 전 제안)**: 계측부터 — 작업 스레드 시작 때 base/current/max 우선순위와 올리기 결과, SUBMIT 요청의 대기 시간 분포(요청→완료)를 보고에 추가해 원인을 잰 뒤 고친다.

## 16. 계측 계획 (사용자 승인 2026-09-30, 코딩 전)

목적: 15 절의 "마르는 횟수 2 배" 가 어디서 오는지 재는 것 — 고치기 전.  동작은 바꾸지 않는다(시각 읽기와 계수만, 전부 C).  보고는 기존처럼 `SDL_OPENSTEP_AUDIO_REPORT` 가 있을 때만.

- **M1 작업 스레드 우선순위**: `run:` 첫머리에서 `SDL_SYS_SetThreadPriority` 전·후의 base/cur/max(`thread_info` BASIC·SCHED, 기존 `OPENSTEPAUDIO_CpuUs` 와 같은 호출)와 그 반환값을 전역에 남긴다.
- **M2 응답 스레드 우선순위**: 대리자 `didCompleteBuffer:` 가 처음 불릴 때(잠금 안 플래그) 그 스레드의 base/cur/max 를 한 번 남긴다 — 완료 통지가 늦으면 `st_outstanding` 도 늦게 준다.
- **M3 SUBMIT 요청의 시간 분해**: 요청자가 신호 직전 `t_post`·완료 확인 직후 `t_done`, 작업 스레드가 요청을 집은 직후 `t_pick`·풀 해제 직후 `t_end`(요청 칸에 기록, 기존 `OPENSTEPAUDIO_Now`, µs).  장치별로 깨움(pick−post)·실행(end−pick)·전체(done−post) 세 히스토그램(<1, <5, <25, <100, <250, ≥250 ms)과 최대, 전체 ≥25 ms 인 것 16 건까지 (열린 뒤 시각, 버퍼 번호, 깨움, 실행).
- **M4 마를 때의 기록**: `st_empty` 가 셀 때마다 16 건까지 (열린 뒤 시각, 버퍼 번호, 직전 refill gap) — 마름이 적재 구간에 몰리는지, 직전에 긴 SUBMIT 이 있었는지 대조용.
- 비용: 버퍼당 `gettimeofday` 4 회(4.6 µs, 기존 주석의 실측) — 무시.

판정: 같은 60 회(root) 를 다시 돌려 (a) 작업 스레드가 오디오 스레드(18)와 같은 우선순위로 도는가 (b) 마름 직전에 SUBMIT 의 깨움 지연이 긴가 (c) 아니면 SUBMIT 은 짧고 다른 곳(대기·완료 통지)인가를 가른다.

### 16.1 codex 교차검토와 계측 계획 수정

| # | codex 주장 | 내 검증 | 판정 |
|---|---|---|---|
| Q5 | 계획(M1–M4)으로는 부족하다(DOES NOT HOLD): (1) `SkCall` 이 요청을 올리기 **전** 잠금·busy 대기(503–506)를 post→done 분해가 놓친다, (2) `StreamWait`(5 ms 폴링)와 slot 대기 루프의 경과 시간은 어디서도 재지 않는다, (3) 기존 refill gap 은 `t_wait_ret`(1035–1036, `StreamWait` **뒤**) → 다음 PlayDevice 진입(916·938)이라 대기를 뺀다, (4) `st_empty` 는 진입 때 관찰(954–958)이라 그 호출의 제출은 원인이 될 수 없고 직전 주기를 봐야 한다.  권고: 버퍼마다 단계 표지를 단 시각 트레이스 | 503–516·912–940·1026–1040 원문 열어 확인: 네 항목 모두 사실 | ✅ 채택 — M3·M4 를 아래 트레이스로 대체 |

**수정된 계측(M1·M2 는 그대로)**:
- **버퍼 트레이스**: 장치마다 2,048 칸 링(열 때 한 번 할당, C).  칸 하나 = PlayDevice 한 번: 진입 시각, 진입 때 `st_outstanding`·`st_completed`, 직전 `t_wait_ret`, SkCall 진입·게시·집음·실행끝·완료 확인 시각, slot 대기 시작·끝, StreamWait 시작·끝·폴링 수.  모두 열린 뒤 µs.
- **완료 트레이스**: 장치마다 2,048 칸 — `didCompleteBuffer:` 가 들어온 시각과 태그(응답 스레드, 잠금 안).  완료가 DMA 속도로 고르게 오는지, 몰려 오는지.
- 출력: `SDL_OPENSTEP_AUDIO_TRACE=<경로>` 가 있을 때만, 닫을 때 `<경로>.<pid>.<n>` 텍스트로(C stdio, 닫는 스레드).  분석은 호스트 python.  없으면 링도 할당하지 않는다.

## 17. 계측 결과 (2026-09-30, 계측판을 설치 없이 glquake_radeon 에 링크, root 30 회)

`test/openstep/rel5-trace-run.sh 30` — 30/30 정상, 트레이스 60 개(장치당: 탐색 열기 + 게임).  python 분석(게임 장치 30 개, PlayDevice 1,925 행, 버퍼 62.5 ms = 11,024 B @ 44.1 kHz 스테레오, ahead 6).

- **우선순위(M1·M2)**: SoundKit 스레드 base 8 → 요청 rc 0 → base/cur **18**(오디오 스레드와 같다).  SoundKit 응답 스레드 base/cur **8**(max 18) — 완료 통지는 우선순위 8 에서 온다.
- **단계별(ms, 중앙/p90/p99/최대)**: refill gap(직전 WaitDevice 복귀→PlayDevice 진입) 4.5/118/1171/1459; slot 대기 ≈0; SkCall 게시 전 ≈0; **깨움(게시→집음) 0.02/3.5/15.4/20**; 실행(playBuffer) 0.33/3.0/385/390; **되돌림(실행끝→요청자 완료 확인) 3.5/18.8/22.1/22.5**; StreamWait 0.01/80/99/102.
- **마름 205 건의 직전 주기 분류**: 직전 playBuffer 실행 >100 ms 35, gap >375 ms 62, gap 150–375 ms 59, 나머지 49.  나머지는 **연속된 행**(예: 121·122·123·124·126 행, 직전 out 0)으로, 주기 100–140 ms 동안 버퍼 하나씩만 들어간다 — 버퍼(62.5 ms)보다 주기가 길어 회복하지 못한다.

**해석(가설, 다음 단계에서 검증)**: 마름의 직접 원인은 앱 쪽 긴 gap — GLQuake 가 프레임 내내 `SDL_LockAudio` 를 쥐어(`openstep-quake/port/openstep/gl_vidsdl.c:625–647`, 캐시 이동 충돌을 막으려는 의도된 잠금) 오디오 콜백이 프레임 사이 틈에만 들어간다.  수정 전(첫 openstep.5)은 오디오 스레드가 playBuffer 를 직접 불러(0.3 ms) 곧바로 다음 콜백을 노렸지만, 수정 후에는 **제출마다 작업 스레드 왕복(되돌림 중앙 3.5 ms, p90 18.8 ms)** 을 기다리는 동안 프레임 사이 틈이 닫혀 프레임당 버퍼 하나로 떨어진다 — 마름이 2 배가 된 까닭으로 본다.

## 18. 수정 계획 2 — SUBMIT 을 비동기로 (코딩 전)

- OPEN·CLOSE 는 지금처럼 동기.  **SUBMIT 은 요청을 FIFO 에 넣고 바로 돌아온다**(오디오 스레드는 작업 스레드를 기다리지 않는다).  FIFO 는 `OPENSTEP_AUDIO_QUEUE_SLOTS` 칸 이상(태그 예약이 이미 그 수로 막는다) — 순서는 태그 순서 그대로.
- 작업 스레드는 FIFO 를 순서대로 비운다.  playBuffer 실패는 작업 스레드가 처리: 잠금 안에서 그 슬롯 예약 되돌림, `playfailures` 증가, 실패 표시 — `StreamFail`(= `SDL_SetError` + `SDL_OpenedAudioDeviceDisconnected`)은 **오디오 스레드가** 다음 PlayDevice/WaitDevice 에서 그 표시를 보고 부른다(SDL 오류 상태는 스레드별, 연결 끊김 통지는 오디오 스레드에서 하던 대로).
- CLOSE 는 같은 FIFO 뒤에 줄 서므로 앞선 SUBMIT 이 다 실행된 뒤 실행된다; 닫기의 "outstanding 이 0 이 될 때까지 기다림"은 그대로.
- 판정: 같은 트레이스 30 회로 마름 수를 수정 전(첫 openstep.5, 평균 2.93) 이하로, 되돌림 대기 0.  그다음 60 회로 충돌 0 재확인.

### 18.1 codex 교차검토와 설계 보강

| # | codex 주장 | 내 검증 | 판정 |
|---|---|---|---|
| Q6 | (DOES NOT HOLD) 링·mixbuf 소유권은 성립(예약 뒤 복사, 완료된 태그만 해제, SkSubmit 은 링만 읽음).  그러나 추가 의존: ① PlayDevice 가 제출 직후 한 번 `RaiseHelpers`(첫 소리가 시작된 뒤를 전제), ② SkCall 이 끝난 뒤 읽는 트레이스(pick/end/done) — 비동기에선 원래 행에 넘겨야, ③ 제출 시간 기록·보고가 대기 포함에서 넣기만으로 의미가 바뀜, ④ Wait/Close 의 2 초 기한이 대기열 실행을 포함하게 됨, ⑤ 수명: 동기 CLOSE 가 앞선 SUBMIT 처리(부기 포함) 뒤에 확인되어야 하는 장벽 | 172–178(RaiseHelpers 주석: 첫 소리 뒤 libsound 응답 스레드), 1088–1097(제출 직후 한 번), 888(`raise_helpers` 는 환경변수로만 켜짐, 기본 꺼짐), 1101–1106(제출 시간 기록) 원문 확인 | ⚖️ 채택: ① 스트림 경로에서는 `RaiseHelpers` 를 부르지 않는다(대상이 libsound per-sound 의 응답 스레드); ② 작업 스레드가 요청에 실린 행 포인터에 pick/end 를 직접 쓴다(행은 CloseDevice 의 장벽 뒤에 해제); ③ 보고의 스트림 안내 줄에 "제출 시간은 넣기만" 명시; ④ 기한은 그대로(보수적); ⑤ 작업 스레드는 FIFO 를 한 번에 하나씩 끝까지 처리 — CLOSE 는 앞선 SUBMIT 의 부기까지 끝난 뒤에만 실행 |

**구현 형태**: 요청 칸 하나 → FIFO(32 칸, 순번).  요청마다 순번을 받고, 작업 스레드는 끝낸 요청의 순번을 `done_seq` 로 올린 뒤 broadcast.  동기 요청(OPEN·CLOSE)은 자기 순번이 끝날 때까지 기다리며 결과는 요청자의 지역 구조체로 받는다(여러 장치가 동시에 열고 닫아도 섞이지 않게).  SUBMIT 성공 시 `st_submitted`, 실패 시 예약 되돌림·`playfailures`·`st_async_fail` 을 **작업 스레드가 스트림 잠금 안에서** 기록; 오디오 스레드는 다음 StreamSubmit/StreamWait 에서 `st_async_fail` 을 보고 `StreamFail`.

## 19. 비동기 SUBMIT 결과 (2026-09-30)

- 빌드(A 단계) PASS, 오디오 컴파일 경고 0.  빌드 == 페이로드, 동기판(fix1) 대비 `m38.o` 하나만 다름(트레이스·"queueing only" 문자열 포함).
- 트레이스 30 회(설치 없이 링크, root): 30/30 정상, `FREED` 0, underrun 0, failed 0.  **마름(queue seen empty) 평균 2.7(중앙 3, 최대 4)** — 동기판 6.83(중앙 5.5, 최대 14) 대비 Mann-Whitney p = 5.2e-10, 수정 전(첫 openstep.5) 2.93 과는 차이 없음(p = 0.58).  → 17 절 가설(작업 스레드 왕복 대기가 프레임 사이 틈을 놓치게 함) 확인.
- 설치 전 시험: sndcost 스트림 제출==완료·underrun 0; sndreopen 스트림 500+200·sound 200 — 실패 0, 전부 `freed 1`, 늦은 콜백 0, `FREED` 0.
- 배치: `/me/packages/sdl2/` 비동기판, 동기판은 `/me/packages/old/sdl2-openstep.5-fix1/`.
- 트레이스 기능(`SDL_OPENSTEP_AUDIO_TRACE`)은 켜지 않으면 아무것도 할당하지 않는 진단 기능으로 남긴다.
- SDL2 재설치(비동기판) 확인: 영수증 셋 openstep.5, 설치된 `libSDL2.a` 121 멤버 == 비동기 빌드.
- sdl2quake 게이트를 다시 좁힘: 판별 문자열 **`the queueing only`**(비동기판 보고 문구, fix1·v1 에는 없음 — python 확인).  음성 시험이 설치돼 있던 fix1 링크 바이너리를 거절한 뒤 재링크 PASS.  sum squake `08244 2807`, glquake `53237 2865`, glquake_radeon `36520 2896`; 세 바이너리 == 빌드, 표지 1, 훅 문자열 수 이전과 같음, README·LICENSE == 소스.
- 배치: `/me/packages/quake/sdl2quake.pkg`(비동기판 링크 1.4), fix1 판은 `/me/packages/old/quake-1.4-fix1/`.

## 20. 최종 설치 시험 (2026-09-30, 비동기판 SDL2 + 재링크 sdl2quake 1.4 설치 뒤)

- 설치 확인: 영수증 sdl2quake 1.4, 세 바이너리 sum == 빌드.
- **GLQuake root 60 회**: 60/60 exit 0·300 tick, `FREED` 0, underrun 0, failed 0, `API stream` 60.  queue seen empty 평균 **2.82**(중앙 3, 최대 5) — 첫 openstep.5(2.93)와 차이 없음(p = 0.91), fix1(6.77)보다 적음(p = 3.8e-19).  최악 갭 중앙 1221 ms(적재 중, 게임의 프레임 잠금 — 모든 판 공통).  충돌: 트레이스 30 + 60 = 90 회 0; 수정 전 비율 3/30 에서 90 회 연속 0 일 확률 7.6e-5.
- **me 6 회**: 전부 정상, 제출==시작==완료, 마름 2–3, `FREED` 0.  (첫 시도는 root 가 남긴 `/tmp/glq-self.log` 를 me 가 못 만들어 게임이 돌지 않았다 — tick 300 은 root 의 옛 로그를 읽은 값이라 무효로 버렸다.  파일을 지우고 다시.)
- **squake(me, ~45 s)**: 709 제출/완료, 마름 0, 최악 갭 1 ms.
- 판정: **릴리스 조건 충족**.  남은 것: 커밋·릴리스 노트·push·태그·자산(사용자 승인 뒤).

## 21. 화면이 멈춘다 (2026-09-30, 사용자 발견) — 원인은 radeon 드라이버, SDL2 아님

**사용자 관찰**: 소리는 정상인데 GLQuake(radeon) 창이 Quake 로딩 콘솔(`"PRINTSCREEN" isn't a valid key`)에서 더 진행되지 않는다.  **20 절까지의 판정은 소리·프레임 수만 봤고 그림을 보지 않았다 — 무효**(메모리 규칙 "계수기가 예라도 그림이 안다" 위반).

| 실행 | 바이너리(안의 SDL2) | 화면 |
|---|---|---|
| A | 설치 1.4 (openstep.5), 스트림 | 멈춤 |
| B | 같은 것, `SDL_OPENSTEP_AUDIO_API=sound`(NSThread 없음) | 멈춤 |
| C | 1.3 공개판 (**openstep.4**) | 멈춤 |
| D | 재부팅 직후 설치 1.4 | 멈춤 |
| E | 공개 전 G5 개발판 (**openstep.4**) | 멈춤 |
| F | `glquake_sw`(stock Mesa, AppKit 경로) | **나옴**(느림) |
| G1·G2 | radeon teapot(카드 clear 1 회) 뒤 설치 1.4 | **G2 나옴**(G1 은 사용자가 못 봄) |

판별 문자열(python): C·E·F 에는 openstep.5 표지(`SDL_OPENSTEP_AUDIO_API`) 0 — 정적 링크라 설치된 SDL2 와 무관하게 openstep.4 코드로 돈다.  A–E 의 radeon 계수는 모두 `RDN-P rects=2212 covered=139868 busy=1`(첫 openstep.5·REL1 과 같음) — 블릿은 매번 "성공".

**원인**: `openstep-radeon9250/OSRDNDisplay/OSRDNDisplay_reloc.tproj/osrdn_cp.m` `cpPresent` 의 블릿 13 워드는 WAIT·GMC·SRC/DST_PITCH_OFFSET·SRC_X_Y/DST_X_Y/WIDTH_HEIGHT·WAIT 뿐 — **잘라내기(`DEFAULT_SC_BOTTOM_RIGHT`)와 방향(`DP_CNTL`)을 쓰지 않는다**.  이 둘을 쓰는 것은 clear(G3d, "RADEONEngineRestore 처럼")뿐인데, CP 기동 6 단계의 `reset` 이 엔진을 리셋한다.  부팅 뒤 카드에서 clear 를 안 한 클라이언트(GLQuake 는 clear 0 — judge_g50 "clears per frame 0.00")의 블릿은 화면에 닿지 않는다.  G5 측정·REL1 최종 점검은 같은 부팅에서 teapot 을 먼저 돌려 가려졌다.  **공개된 radeon 1.0 의 결함** — 부팅 뒤 GLQuake 를 바로 띄우는 사용이 정확히 걸린다.  (정정: 직전의 "CP 복구 뒤 유실" 가설은 틀렸다 — 방아쇠는 드문 복구가 아니라 매 부팅의 기동 `reset`.)

**SDL2·sdl2quake 에 대한 결론**: 이 증상은 openstep.4 바이너리(C·E)에서도 같으므로 openstep.5 변경 탓이 아니다.  다만 openstep.5 의 **부분 화면 갱신 변경**(다른 세션)은 소프트웨어 화면 경로라 GLQuake 로는 검증되지 않았다 — squake 로 따로 그림 확인한다(22 절).

## 22. squake 그림 확인 (2026-09-30)

설치 1.4 의 `squake`(소프트웨어 표면, openstep.5 의 부분 화면 갱신 변경 경로)를 30 초 띄움(`test/openstep/rel5-screen-sq.sh`) — **사용자 확인: 화면 정상**(게임 화면 진행).  openstep.5 의 비디오 변경은 소프트웨어 경로에서 그림으로 확인됐다.

**사용자 지시(2026-09-30)**: CP·radeon 문제 때문에 Quake 를 고치지 않는다 — Quake 는 Matrox·radeon 둘 다에서 그대로 돌아야 한다.  → 21 절의 결함은 **radeon 드라이버에서** 고친다(present 블릿이 잘라내기·방향 상태를 스스로 설정).  SDL2 openstep.5·sdl2quake 1.4 는 이 결함과 무관.

## 23. 릴리스 형태 (2026-09-30)

- **SDL2 2.32.10-openstep.5** = 19 절의 비동기판(`m38.o` 만 fix1 과 다름, 트레이스 진단 포함).  자산은 `/me/SDL20/sdl2-dist` 의 세 `.pkg` 를 실기에서 tar, 호스트에서 `gzip -9 -n`(`release-assets/openstep.5/`, 무시 대상).  Libraries 의 `libSDL2.a` == 설치·시험한 비동기 빌드(python).
- **sdl2quake 1.4** = 비동기판에 링크한 세 바이너리(설치·60 회 시험한 것) + README·`.info` 가 radeon 요구를 1.1 로(페이로드 문구만 — 바이너리 바이트 동일, python 대조).
- **radeon 1.1** = present 블릿이 2D 상태를 싣는 드라이버(`openstep-radeon9250/docs/REL2_PRESENT_STATE_PLAN.md`), 라이브러리·데모는 1.0 그대로.
- 세 개를 함께 공개(사용자 결정 2 번).
