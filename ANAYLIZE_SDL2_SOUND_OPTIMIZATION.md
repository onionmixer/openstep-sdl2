# SDL2(OPENSTEP 포트) 사운드 끊김 — 원인과 고칠 곳

2026-09-08 코드·바이너리 분석, 2026-09-09 **실기 측정으로 확정**.
측정 원자료와 절차는 `docs/measurements/README.md`, 프로그램은
`test/openstep/sndslack.c`.  계산은 전부 python 으로 했다.

**전제(사용자):** 고치는 곳은 SDL2 포트 내부뿐이다.  SDL2 를 쓰는 앱(glquake,
water1)은 손대지 않는다.  앱 변경이 필요한 안은 §5 에 "제외"로만 적는다.

---

## 0. 결론

백엔드는 자기가 가진 여유를 **250 ms 로 알고 있다**(`SDL_openstepaudio.h:11`
의 주석 그대로).  실측 여유는 **85~90 ms** 다.  2.8배 낙관이었다.

여유가 그것뿐인 이유는 커널에 있다.  IOAudio 는 재생 지점보다 **서술자 몇 개
앞서** 데이터를 섞어 두고, 섞을 것이 모자라면 **정지하지 않고 무음으로
채운다**.  그래서

    실제 여유 = (AHEAD-1) x 버퍼  -  C,      C = 160~165 ms (실측)

이고, C 는 커널의 선행분과 통지 사슬이다.  버퍼 크기와 무관한 상수라 다른
구성도 예측하며, 그 예측을 다시 실측으로 확인했다(§2.3).

**게임에서 끊기는 이유**: glquake 의 프레임은 165~176 ms 인데 여유는 85~90 ms
다.  한 프레임만큼 늦으면 그 자리에서 무음이 낀다.  튜닝의 문제가 아니라
구조다.

**고칠 수 있다.**  실기에서 검증한 것 둘:

| 구성 | 지연 | 실측 여유 | 176 ms 프레임 |
|---|---|---|---|
| 지금 (freq/8, AHEAD 3) | 375 ms | 85~90 | 못 견딤 |
| + A1 (첫 버퍼만 서술자 2개로) | 375 ms | 120~140 | 못 견딤 |
| freq/8 AHEAD 4 | 500 ms | 180~220 | 견딤 |
| **freq/16 + AHEAD 6 + 프라이머 8192 B** | **375 ms (지금과 같음)** | **220~280** | **견딤** |

마지막 줄이 답이다 — **지연을 늘리지 않고 여유를 두 배로.**

그 구성을 실기에 넣고 다시 재니 **끊김이 줄었지만 남았다** (사용자: "아직 조금
끊김은 있지만 많이 개선됐네요").  남은 것의 성격은 여유 부족과 다르다:
water1 에서 `gap 127 ms / cpu 30 ms` 가 **연속 12회** 나온다.  127 ms 는 버퍼
주기의 정확히 2배이고, 그동안 이 스레드는 CPU 를 30 ms 밖에 안 썼다.  즉
**일이 많아서 늦은 것이 아니라 돌지 못한 것**이다.  같은 순간 사용자가 들은
것은 오프닝 음악 위에 타이핑 효과음이 겹치는 장면이고, quake 에서는 총소리다.

돌지 못한 이유의 후보는 둘뿐이고, 둘 다 SDL2 포트 안에 있다:

1. **뮤텍스.**  이 포트의 `SDL_LockMutex` 는 cthreads `mutex_lock` 이다.
   이 시스템 libsys 의 `mutex_spin_limit` 은 **0** 이라, 경합하면 스핀 없이
   곧바로 `while (1) { ...; cthread_yield(); }` 에 들어간다.  `cthread_yield`
   는 `swtch_pri(0)` = **자기 우선순위를 낮추는** 양보다.  락이 풀릴 때까지
   무한히 돌면서 자기를 계속 낮춘다.
2. **우선순위.**  `SDL_SYS_SetThreadPriority` 가 **빈 스텁**이었다
   (`return SDL_Unsupported()`).  상류 `SDL_audio.c:691` 이 믹싱 스레드에
   `TIME_CRITICAL` 을 요청하는데 이 포트에서는 아무 일도 안 했다.  NeXT Mach
   의 기본 정책은 timesharing 이고, 문서가 "a thread's priority gets lower as
   it runs (it ages)" 라고 명시한다.

둘 다 고쳤고, 어느 쪽이 원인인지 **실기가 답했다 (2026-09-09, water1 4판)**:

| 판 | 뮤텍스 / 우선순위 | ≥100 ms 갭 | 최악 갭 | 오디오 스레드 락 대기 | 공급 부족 |
|---|---|---|---|---|---|
| 0 | yield / off (대조군) | 13 | 452 ms | 61 ms (최악 0) | 2.69 s = 3.9% |
| 1 | **block** / off | 32 | 240 ms | 239 ms (최악 120) | 3.56 s = 4.5% |
| 2 | yield / **on** | — | — | — | **크래시 (§2.6)** |
| 3 | **block** / **on** | **0** | **51 ms** | 68 ms (최악 0) | **0.03 s = 0.0%** |

그리고 **quake 는 원인이 다르다** (§2.7): 같은 계측기가 거기서는 반대 값을 냈다
— 최악 갭 3180 ms 와 최악 락 대기 3177 ms 가 **같은 수**이고, 오디오 스레드가
재생시간의 **69.5%** 를 락을 기다리며 보낸다.  quake 포트가 프레임 전체를 잠그는
것은 의도된 절충이고(zone/cache 가 스레드 안전하지 않다), **SDL2 안에서는 못
고친다.**  water1 은 고쳐졌고 quake 는 못 고친다 — 두 문장 다 실측이다.

**water1 의 답은 우선순위다.**  대조군에서 오디오 스레드가 SDL 뮤텍스를 기다린 시간은
12,254회 통틀어 **61 ms**, 공급 부족 2.69 s 의 **2.3%** 밖에 안 된다.  락이
아니었다 — 스레드가 그냥 안 돌았던 것이다.  `SDL_SYS_SetThreadPriority` 가 빈
스텁이라 base 10 에서 timesharing aging 으로 5까지 내려가 있었고, 우선순위를
18(이 시스템의 `max_priority`)로 올리자 **≥100 ms 갭이 13 → 0, 최악 452 → 51 ms**
가 됐다.

---

## 1. 확정 사실

### 1.1 SDL2 포트 (소스)

| 사실 | 위치 |
|---|---|
| 장치를 44100/22050 외에는 44100 으로 강제, S16MSB, 채널 1~2 | `audio/openstep/SDL_openstepaudio.m:36-42` |
| 버퍼 = `freq/8` 프레임(125 ms), `QUEUE_AHEAD 3`, `QUEUE_SLOTS 8` | `:48`, `SDL_openstepaudio.h:10-14` |
| 버퍼마다 `SNDSoundStruct` 를 malloc+memcpy 해 `SNDStartPlaying(…,0,0,NULL,NULL)` | `:91-108` |
| `WaitDevice` = 큐가 3이면 가장 오래된 태그를 `SNDWait` | `:121-126` |
| `underruns` 카운터는 **구조상 발화할 수 없다**(count 는 2~3만 오간다) | `:81-89` |
| ~~`SDL_SYS_SetThreadPriority` 가 `SDL_Unsupported()`~~ → **구현함**(B2).  상류 `SDL_audio.c:691` 이 믹싱 스레드에 `TIME_CRITICAL` 을 요청하는데 예전에는 무시됐다 | `thread/openstep/SDL_systhread.c` |
| ~~`SDL_mutex` = cthreads 뮤텍스(블로킹 아님)~~ → **조건변수로 교체**(B1), `SDL_OPENSTEP_MUTEX=yield` 로 되돌릴 수 있다 | `thread/openstep/SDL_sysmutex.c` |
| 소프트웨어 present 는 메인 스레드가 32→24 bpp 변환 후 `[view displayRect:]` | `video/openstep/SDL_openstepvideo.m:2066-2110` |

SDL 코어는 `mixer_lock` 을 **앱 콜백 동안만** 잡고(`SDL_audio.c:731-738`),
푼 뒤에 형식 변환과 `PlayDevice`→`WaitDevice` 를 한다(741-789).

### 1.2 libsound / cthreads (`ref/openstep/workspace/libsys.bin`, IDA)

| 함수 | 한 일 |
|---|---|
| `SNDStartPlaying` → `start_performance` | 큐에 넣고 **즉시** `initiate_performance` |
| `initiate_performance` | 같은 owner·같은 모드면 그 스트림에 곧바로 `snddriver_stream_start_writing`.  `3*pending_count > 15` 를 **시작 전에** 검사하므로 동시에 시작된 사운드는 **최대 6개** |
| `perform_reply_thread` | libsound 가 `cthread_fork` 한 배경 스레드.  `msg_receive` 타임아웃 500 ms, 10회 연속 무응답이면 포기(= 오디오가 죽었을 때 관측되는 5.3초) |
| `performance_started` / `performance_ended` | `q_lock` 을 푼 뒤 **그 배경 스레드에서** `beginFun`/`endFun` 호출 |
| `terminate_performance` | 뒤에 시작된 사운드가 없으면 `SNDRelease` — 드라이버가 보는 이음매 |
| `SNDWait(tag)` | `condition_wait(q_changed)` 로 그 태그가 사라질 때까지 |
| `mutex_wait_lock` (`0x5090c10`) | `mutex_spin_limit` **= 0** 이므로 스핀 없이 곧바로 `while(1){ …; cthread_yield(); }` — **무한**, 그리고 `cthread_yield` = `swtch_pri(0)` 이라 회전마다 자기 우선순위를 낮춘다 |
| `condition_wait` (`0x5090258`) | `condition_spin_limit` = 0, `condition_yield_limit` **= 7** → 7회 `swtch_pri(0)` 뒤 `msg_receive` 로 **진짜 블록**.  깨어나면 `mutex_try_lock`, 실패 시 `mutex_wait_lock`.  대기자 등록이 뮤텍스 해제보다 **앞선다**(lost wakeup 없음) |
| `cthread_fork` | 노는 커널 스레드를 **재사용**한다(새 스레드가 아닐 수 있다) |

전역 값은 추측이 아니라 바이너리에서 읽었다: `mutex_spin_limit` `0x4010198` = 0,
`condition_spin_limit` `0x40101ac` = 0, `condition_yield_limit` `0x40101b0` = 7.

### 1.3 커널 IOAudio (`ref/openstep/ps2/mach_kernel`, IDA) — 카드와 무관한 공통층

| 함수 | 한 일 |
|---|---|
| `-[AudioChannel initOnDevice:read:]` (0x1b7914) | DMA 64 KiB(EISA면 128), **서술자 = `page_size` = 8192 B**.  `setDMASize:`/`setDescriptorSize:` 의 xref 는 이 함수뿐 — 유저 공간에서 못 바꾼다 |
| `-[IOAudio _attemptToStartDMAForChannel:…]` (0x1b4db8) | 시작할 때 `enqueueDescriptor` 가 성공하는 동안 최대 `dmaCount>>1`=**4개**를 섞고 `startDMA`.  **첫 region 이 짧으면 그만큼만** |
| `-[IOAudio _interruptOccurred]` → `_attemptToStopDMAForChannel:` | 인터럽트마다 하나 회수 + 하나 섞음 → **선행 개수는 시작 때 값으로 고정** |
| `-[AudioStream mixBuffer:…]` (0x1b8f64) | 모자라면 나머지를 `clearForMix`(무음)로 채우고 서술자는 그대로 나간다.  **정지가 아니라서 드라이버 카운터에 안 잡힌다** |
| `-[AudioChannel dequeueDescriptor]` → `dmaCompleteDescriptor:` | 큐 머리를 회수하며 region 의 마지막 서술자면 `completed` |

**서로 다른 드라이버가 이 기하를 확인해 준다.** EMU10K1 의 부팅 로그가
`createDMABuffer: numBytes 65536 … 8 pages of 8192`,
`startDMA: … frag 8192: 16384 frames in 8 fragments` 를 찍는다 — AC'97 에서
잰 값과 같다.

### 1.4 실기 측정 (2026-09-09) — `docs/measurements/`

| 잰 것 | 값 |
|---|---|
| 완료 통지가 재생 시각인가 | **그렇다**.  250/500/1000/2000 ms 사운드의 Start→Wait 이 기울기 1.03 |
| 서술자 크기 | **8192 B = 46.44 ms**.  완료 간격이 2d(92.7 ms, 30.7%)와 3d(139.4 ms, 69.3%) 두 값뿐이고, 비율이 `T/d=2.6914` 가 강제하는 30.9/69.1% 와 **0.17%포인트** 차이 |
| 여유 (지금 설정) | **85~90 ms** (85 깨끗, 90 부터 무음) |
| 여유 (AHEAD 4) | 180~220 ms |
| 여유 (프라이머 16384 B) | 120~140 ms |
| 여유 (`freq/16 AHEAD 6` + 프라이머 8192 B) | **220~280 ms** |
| 상수 C | **160~165 ms** (A1 이면 110~130) |
| EMU10K1 의 추가 양자화 | 10.7 ms (타이머 구동 드라이버라서.  격자 적합 잔차 0.083 ms) |

---

## 2. 메커니즘

### 2.1 왜 여유에 뺄셈이 있나

SDL 이 `SNDWait(N-1)` 에서 돌아온 순간, 커널은 이미 그 뒤 L 개 서술자를
섞어 두었다.  그러므로 region 큐에 `(AHEAD-1) x 버퍼`가 있어도 **믹서가
새 데이터를 필요로 하는 시점은 그보다 L x 46.44 ms 앞이다.**

    여유 = (AHEAD-1) x 버퍼 - L x 46.44 - (위상 항)

사운드 길이가 서술자의 정수배가 아니므로(5512 프레임 = 2.6914 서술자) 위상이
매 반복 달라지고, 그래서 여유는 하나의 값이 아니라 **범위**다.  실측 문턱이
85~90 ms 로 좁게 나온 것은 위상이 평균되기 때문이다.

### 2.2 무음은 정지가 아니다

믹서가 모자라면 그 서술자의 나머지를 무음으로 채우고 DMA 는 계속 돈다.
그래서 (a) 드라이버의 정지 카운터에 안 잡히고, (b) 개별 완료 간격도 여전히
2d/3d 라 국소적으로 안 보이며, (c) **3d 간격의 비율이 올라가는 것**으로만
드러난다.  측정은 그래서 "소비된 서술자 수 − 공급한 오디오"로 센다 — 정수라
시계 표류에 면역이다.

### 2.3 상수 C 는 구성을 가로질러 예측한다

`freq/8` 에서 잰 C 로 `freq/16` 을 예측하고, 그 구성을 직접 쟀다.  네 예측이
모두 맞았다:

| 구성 | 예측 | stall | 실측 |
|---|---|---|---|
| freq/16 AHEAD 6, 기본 | 여유 150 | 160 | 굶음 (20.7 ms/회) |
| freq/16 AHEAD 6, A1 | 여유 195 | 160 | 안 굶음 |
| freq/16 AHEAD 6, A1 | 여유 195 | 220 | 굶음 (3.3) |
| freq/16 AHEAD 3, 기본 | 여유 **−37** | 100 | 굶음 (41.4) |

마지막 줄이 **openstep.3 이 freq/16 로 갔다가 되돌린 이유**다.  그 릴리즈는
"메인 스레드가 놀아도 3.7 % 마른다"를 관측하고 설명하지 못했다.  여유가 음수면
설명이 필요 없다.

### 2.4 왜 mp3 는 되고 게임은 안 되나

OnionPlayer 는 0.25 s 청크를 4개 앞서 큐잉한다(`PlaybackEngine.m:32`) — 여유
750−C ≈ 590 ms.  자릿수가 다르다.  그리고 게임의 프레임은 여유보다 길다.

---

### 2.5 여유를 키운 뒤에 남은 것 — 스레드가 돌지 못한다

여유(A1+A2) 가 220~280 ms 가 된 뒤에도 남은 끊김은 다른 메커니즘이다.
백엔드에 넣은 계측이 갭마다 **그 스레드 자신의 CPU 시간**을 함께 찍는다.

    water1  : gap 127 ms / cpu 30 ms   x 12 회 연속 (41.7~46.2 s)
              worst submit 233 ms,  base priority 10, current 7
    glquake : 최악 갭 3077 ms, >=250 ms 22 회, 실행시간의 28.9% 이상이 무음

`gap >> cpu` 는 "일이 많았다"가 아니라 "돌지 못했다"이다.  그리고 127 ms 는
버퍼 주기(63.5 ms)의 정확히 2배 — 공급이 수요의 절반으로 떨어져 여유가 몇
버퍼 만에 마르는, 사용자가 "탁~탁탁탁" 이라고 적은 그 모양이다.

**두 게임이 오디오 락을 어떻게 잡는가** (전수 grep 확인):

| | 락 지점 | 모양 |
|---|---|---|
| water1 | `engine/src/common/sound.c:200-221` `sound_sfx_note()` / `sound_sfx_keyoff()` | **타이핑 한 글자마다** `SDL_LockAudioDevice` 2회 |
| glquake | `port/openstep/gl_vidsdl.c:625,647` `GL_BeginRendering`/`GL_EndRendering` | **프레임 전체**를 감싼다 (`SDL_GL_SwapWindow` 뒤에 unlock) |

quake 에는 효과음별 락이 **없다**(`SDL_LockAudio` 는 이 한 곳뿐).  총소리에서
확실히 끊기는 것은 총격이 그 프레임을 길게 만들고, 프레임 전체를 감싼 락이
그동안 오디오 스레드를 잡아두기 때문이다.  **트리거만 다르고 갇히는 경로는
같다.**

**갇히는 경로** (`libsys.bin` IDA, 값은 실제 바이너리에서 읽음):

    mutex_lock(m)  ->  mutex_try_lock 실패  ->  mutex_wait_lock(m)
    mutex_spin_limit = 0   =>  스핀 0회
    while (1) { if (!m->lock && mutex_try_lock(m)) break; cthread_yield(); }
    cthread_yield()  =  swtch_pri(0)     <-- 자기 우선순위를 낮춘다

락이 풀린 뒤에도 이 스레드는 낮아진 채로 **다시 스케줄되기를 기다려야** 한다.
락 보유 시간 위에 그 재스케줄 지연이 얹힌다.

대조군: **Linux 에서는 문제가 없다** (사용자 확인).  pthread 뮤텍스는 futex 로
블록하고 우선순위를 깎지 않으며, SDL2 의 `SDL_SetThreadPriority` 도 동작한다.
다만 CPU 속도·변환 비용·백엔드 주기가 모두 다르므로 이것은 개연성 증거이지
증명이 아니다.  **결정적 대조는 같은 실기에서 뮤텍스만 바꾼 A/B** 이고, 그것을
한 빌드 안에 넣었다(§3 B).

**아직 증명되지 않은 것**: `base 10 / current 7` 은 `swtch_pri` 의 증거가
아니다.  OPENSTEP 문서(`Concepts.rtf`)가 timesharing 의 aging 을 명시하므로
평범한 노화로도 같은 숫자가 나온다.  그래서 판별자를 따로 넣었다 — **오디오
스레드의 SDL 뮤텍스 획득 대기시간**을 직접 재서 로그에 찍는다.
갭 ≈ 락 대기면 뮤텍스, 갭 ≫ 락 대기면 스케줄러다.


### 2.6 판별 결과 (2026-09-09, water1, 4판) — 뮤텍스가 아니라 스케줄러였다

`snd-ab.sh` 로 같은 빌드에서 네 판.  같은 장면(오프닝, 타이핑 효과음 포함)을
플레이하고 메뉴로 정상 종료.  계산은 python.

    버퍼 주기 62.5 ms (2756 프레임 @ 44100)

| 판 | bufs | ≥100 ms | ≥100/1000버퍼 | 최악 | 락 대기 합/최악 | base/current | 공급 부족 추정 |
|---|---|---|---|---|---|---|---|
| 0 yield/off | 1103 | 13 | 11.8 | 452 ms | 61 ms / 0 ms | 10 / **5** | 2.69 s (3.9%) |
| 1 block/off | 1258 | 32 | 25.4 | 240 ms | 239 ms / **120 ms** | 10 / 8 | 3.56 s (4.5%) |
| 2 yield/on | — | — | — | — | — | — | **크래시** |
| 3 block/on | 1239 | **0** | **0.0** | **51 ms** | 68 ms / 0 ms | **18** / 14 | **0.03 s (0.0%)** |

("공급 부족"은 버킷 중앙값으로 잡은 추정치다 — 정확한 합이 아니라 크기 비교용.)

**§2.5 의 후보 1(뮤텍스)은 내 판별자가 기각했다.**  대조군에서 오디오 스레드의
SDL 뮤텍스 대기는 12,254회 통틀어 **61 ms**, 최악 **0 ms** 다.  공급 부족
2.69 s 의 **2.3%** 밖에 설명하지 못한다.  물리적으로도 앞뒤가 맞는다: water1 은
글자마다 락을 잡지만 그 임계구역은 `fmdrv_sfx_note()` 하나로 짧다.  락을 오래
쥔 것이 아니라 **오디오 스레드가 스케줄되지 못한 것**이다.

**후보 2(우선순위)가 원인이다.**  대조군의 `current 5` 가 그 증거다 — base 10
에서 timesharing aging 으로 절반까지 내려갔다.  base 를 18 로 올리자 aging
후에도 14 로, 메인 스레드(10)보다 위에 남는다.  결과는 ≥100 ms 갭 **13 → 0**.

**블로킹 뮤텍스만 넣으면 오히려 나빠진다** (판 1: 13 → 32).  이유도 측정에
나온다: 락 대기 최악이 0 → **120 ms** 로 늘었다.  yield 는 락이 풀리는 순간
낚아채지만, 블로킹은 7회 양보 후 `msg_receive` 로 자고 깨어나야 한다 — 낮은
우선순위에서는 그 깨어남이 늦다.  다만 긴 꼬리는 사라졌다(≥375 ms 3회 → 0,
최악 452 → 240).  **우선순위와 함께면 그 비용이 사라진다** (판 3: 대기 68 ms,
최악 0 ms).

즉 **B2 가 고치고, B1 은 B2 가 있을 때만 공짜다.**  B1 이 단독으로 기여하는
바는 이 측정으로는 알 수 없다 — 판 2 가 크래시해서 "우선순위만" 팔이 비었다.

**증거 보존 상태 (2026-09-09 확인).**  네 판의 로그를
`docs/measurements/ab/` 로 복사해 두었다.  다만 **판 0 의 로그는 위 표의
1103-버퍼 실행이 아니다** — 같은 이름으로 나중에(05:16) 36-버퍼짜리 짧은
실행이 덮어썼다(quake 판 0 을 돌리기 직전).  판 0 의 숫자는 이 문서의 표에만
남아 있고 원본 로그로는 더 이상 뒷받침되지 않는다.  판 1·3 과 quake 두 판의
로그는 온전하다.  실기의 준비된 소스는 host 작업 트리와 **바이트 동일**
(`sum` 일치, 다섯 파일)이므로 측정된 빌드 = 현재 트리다.

### 2.6.1 판 2 의 크래시 (미해결)

    arm 2: SDL_OPENSTEP_MUTEX=yield SDL_OPENSTEP_THREAD_PRIORITY=on
    sound_init: want 49716Hz fmt=0x8010 ch=2 samples=1024 / have (same)
    <그 뒤 아무 출력 없이> 11030 memory fault

core 파일은 남지 않았다.  **원인은 아직 모른다.**  단정하지 않고, 아는 것만
적는다:

- 판 2 는 내가 **미리 진단용이라고 적어 둔** 조합이다: 우선순위 18 짜리
  오디오 스레드가 우선순위 10 짜리 락 보유자를 **무한 yield 루프**로 기다린다.
  OPENSTEP 에는 우선순위 상속이 없다.
- 출하 기본값인 판 3 은 같은 우선순위로 1239 버퍼(약 78초)를 정상 종료했다.
- water1 에는 락 밖에서 드라이버 상태를 바꾸는 곳이 있다:
  `sound_load_music()` 이 락 안에서는 `fmdrv_stop(0)` 만 하고, **락 밖에서**
  `free(s_music_buf)` → `malloc` → `fread` → `fmdrv_register_music()` 을 한다
  (`engine/src/common/sound.c:104-148`).  안전성 근거는 "`fmdrv_stop(0)` 가
  `s_playing=false` 로 만든다"는 주석뿐이다.  오디오 스레드가 제때 도는 순간
  창이 열릴 수 있는 모양이지만, **이것이 그 크래시였다는 증거는 없다.**

재현·진단 방법은 §4 에 적어 두었다.  이 항목이 닫히기 전에는 **판 2 를 출하
후보로 고려하지 않는다** (원래도 아니었다).


### 2.7 quake 는 water1 과 원인이 다르다 (2026-09-09 실측)

같은 판별자를 quake 에 대고 재니 **정반대 그림**이 나왔다.

| run | bufs | 오디오 | ≥100 ms/1000 | 최악 갭 | **락 대기 합** | 재생시간 대비 | 획득당 평균 |
|---|---|---|---|---|---|---|---|
| quake 0 yield/off | 445 | 27.8 s | 78.7 | 3180 ms | **19.3 s** | **69.5%** | 7.2 ms |
| quake 3 block/on | 311 | 19.4 s | 109.3 | 3421 ms | **21.2 s** | **108.9%** | 11.2 ms |
| water1 0 yield/off | 1103 | 68.9 s | 11.8 | 452 ms | 0.06 s | 0.1% | 0.0 ms |
| water1 3 block/on | 1239 | 77.4 s | 0.0 | 51 ms | 0.07 s | 0.1% | 0.0 ms |

**최악 갭과 최악 락 대기가 같은 수다:**

    quake 0 : 갭 3180 ms   락 3177 ms   차 3 ms
    quake 3 : 갭 3421 ms   락 3419 ms   차 2 ms
    water1 0: 갭  452 ms   락    0 ms   차 452 ms

water1 에서는 갭이 락과 **무관**했고, quake 에서는 갭이 **곧 락**이다.  추론이
아니라 같은 계측기가 두 게임에서 반대 값을 냈다.  quake 의 오디오 스레드는
재생시간의 **69.5%** 를 `mixer_lock` 을 기다리며 보낸다 (판 3 은 108.9% — 100%
를 넘는 것은 그만큼이 무음이었다는 뜻이다: 만든 오디오 19.4 s 보다 기다린
21.2 s 가 길다).

**락은 실수가 아니라 의도된 절충이다.**  `port/openstep/gl_vidsdl.c:611-647` 이
직접 그렇게 적어 놓았다:

> Quake's zone and cache are not thread-safe and cannot be made so from the
> port, so the callback is held off while the frame runs.  The cost is that a
> frame longer than the audio buffer is a gap in the sound; the alternative is
> a renderer reading freed memory.

전수 확인: quake 에서 오디오 락을 잡는 곳은 이 한 쌍뿐이고(`SDL_LockAudio` 625,
`SDL_UnlockAudio` 647), `SDL_LockAudioDevice`·`SDL_ClearQueuedAudio` 는 쓰지
않는다.  `SDL_UnlockAudio` 는 `SDL_GL_SwapWindow` **뒤**에 있으므로 락은
프레임 전체 + 화면 전송을 덮는다.

**그래서 quake 는 SDL2 안에서 못 고친다.**
- **B2(우선순위)는 원리적으로 무력하다.**  얻을 수 없는 락은 우선순위가
  높아도 못 얻는다.  실측이 그대로다(≥100 ms 78.7 → 109.3, 개선 없음).
- **B1(블로킹)도 도움이 안 된다.**  획득당 평균 대기가 7.2 → 11.2 ms 로
  늘었다 — 프레임 내내 잡혀 있는 락에서는 "풀리는 즉시 낚아채는" yield 쪽이
  깨어나야 하는 블로킹보다 낫다.
- **버퍼를 늘려도 안 된다.**  3초짜리 보유를 큐로 덮으려면 지연이 3초여야
  한다.  게임에서 쓸 수 없다.

`SDL_LockAudio` 의 계약은 "내가 쥔 동안 콜백은 돌지 않는다"이다.  SDL2 가 그
계약을 어기지 않고 할 수 있는 것은 없다.  **앱 제약(§5)을 만족시킬 수 없는
사례이고, 그 사실을 숨기지 않고 여기 적는다.**

앱 쪽 해법은 참고로만: 락을 프레임 전체가 아니라 zone/cache 를 실제로 건드리는
구간에만 두거나(주석이 말하는 use-after-free 는 그 구간의 문제다), 사운드
데이터를 cache 밖에 두는 것.  둘 다 quake 의 일이지 SDL2 의 일이 아니다.


## 3. 고칠 곳 — SDL2 내부 한정

### A1 — 프라이머: 첫 region 을 서술자 하나로 (실기 검증됨, 지연 비용 0)

**첫 `PlayDevice` 한 번만**, 실제 버퍼를 보내기 직전에 **8192 바이트(서술자
하나) 무음**을 먼저 보낸다.  커널은 DMA 를 시작할 때 그 region 만 보고
선행분을 정하므로 L 이 가장 작아진다.

실측(같은 기하에서 프라이머만 바꿈):

| 프라이머 | 여유 |
|---|---|
| 없음 (첫 버퍼가 첫 region) | 85~90 ms |
| 16384 B (서술자 2개) | 120~140 ms |
| **8192 B (서술자 1개)** | `freq/16 AHEAD 6` 에서 **220~280 ms** |

`OpenDevice` 가 아니라 첫 `PlayDevice` 에 두는 이유: 장치는 일시정지 상태로
열리고, `OpenDevice` 에서 보내면 프라이머가 다 재생돼 DMA 가 멈춘 뒤 다음
region 으로 선행분이 다시 정해진다.  첫 `PlayDevice` 에서는 실제 버퍼가 바로
뒤따르므로 큐가 빌 틈이 없다.

퇴행 위험: 시작 시 무음 46 ms 가 한 번 붙는다(장치를 열 때 한 번뿐).

### A2 — 큐 기하 (실기 검증됨)

여유 = 지연 − 버퍼 − C 이므로 **같은 지연에서는 버퍼가 작을수록 여유가 크다.**

| 구성 | 지연 | 실측 여유 |
|---|---|---|
| `freq/8 AHEAD 4` | 500 ms | 180~220 |
| **`freq/16 AHEAD 6` + 프라이머 8192** | **375 ms** | **220~280** |
| 4096프레임 AHEAD 4 (서술자 정수배) | 371 ms | 160 미만 |

`QUEUE_SLOTS` 는 8 이고, 프라이머를 같은 FIFO 에 넣으면 최대 동시 미회수는
**6**(python 으로 확인)이라 들어간다.  libsound 의 동시 시작 상한이 6 이므로
AHEAD 는 6 으로 둔다 — 7 이면 일곱째가 배경 스레드 스케줄에 걸린다.

### B — 뮤텍스와 우선순위 (구현 완료, 실기 판별 대기)

여유가 한 프레임보다 작은 동안에는 우선순위로 못 구한다 — 그래서 A 가 먼저였고,
A 는 끝났다.  A 뒤에 남은 것이 §2.5 이고, 그 두 후보를 **함께 넣되 각각 끌 수
있게** 했다.  둘 다 SDL2 포트 내부이고 앱은 손대지 않는다.

**B1 — 블로킹 뮤텍스** (`port/openstep/src/thread/openstep/SDL_sysmutex.c`)

cthreads 뮤텍스를 짧게만 잡는 guard 로 강등하고, 락 자체는 조건변수로 기다린다:

    mutex_lock(guard);
    while (held) condition_wait(avail, guard);   /* 대기자 등록이 guard 해제보다 앞선다 */
    held = 1;
    mutex_unlock(guard);

이건 내 발명이 아니라 **NeXT 가 문서화한 패턴**이다.  MachKit `NXLock` 문서:
"If a region of code is in use, an NXLock waits using the `condition_wait()`
function, so the thread doesn't busy-wait", unlock 은 "using
`condition_signal()` to signal the next party".
(`NXConditionLock`/`NXRecursiveLock`/`NXSpinLock` 도 같은 계열이다.)

한계를 정직하게: `condition_wait` 도 무한하지는 않을 뿐 양보를 한다 — libsys
에서 `condition_spin_limit=0`, **`condition_yield_limit=7`** 이라 7회
`swtch_pri(0)` 뒤에 `msg_receive` 로 진짜 블록한다.  **7 은 유한하고 지금의
루프는 무한하다**, 그 차이가 전부다.

`SDL_TryLockMutex` 는 논리 락을 절대 기다리지 않는다(guard 만 잠깐 잡고
`held` 를 보고 바로 `SDL_MUTEX_TIMEDOUT`).  재귀·소유자 규약은 그대로다.
`SDL_syscond.c` 는 네이티브 뮤텍스를 건드리지 않고 `SDL_LockMutex`/
`SDL_UnlockMutex` 만 쓰므로(전수 확인) 조건변수 handshake 도 그대로다.

    SDL_OPENSTEP_MUTEX=yield     <- 예전 동작(대조군)

**B2 — 스레드 우선순위** (`.../SDL_systhread.c`)

`SDL_SYS_SetThreadPriority` 를 구현했다.  `thread_info(THREAD_SCHED_INFO)` 로
`base_priority` 와 `max_priority` 를 읽고, `base + boost` 를 `max` 로 클램프한
뒤 `cthread_priority(cthread_self(), want, FALSE)`.  클램프가 필요한 이유:
`cthread_priority` 는 최대치를 넘겨 요청하면 **실패**하고, 최대치를 올리는 것은
수퍼유저만 할 수 있다(문서).  `LOW` 는 내리고 `NORMAL` 은 손대지 않는다.

    SDL_OPENSTEP_THREAD_PRIORITY=off   <- 예전 동작(대조군)
    SDL_OPENSTEP_PRIORITY_BOOST=<n>    <- 기본 10, 재빌드 없이 sweep

**B3 — 판별 계측** (`SDL_openstepmutex_c.h`, 백엔드 `ThreadInit`)

뮤텍스 코드가 **오디오 콜백 스레드 한 개**에 대해서만 획득 횟수·총 대기·최악
대기를 센다.  `CloseDevice` 의 보고에 한 줄 붙는다:

    OPENSTEP audio: SDL mutexes block; 1234 acquisitions took 87 ms in total, worst 41 ms
    OPENSTEP audio: this thread base priority 20, current 17, max 31, depressed 0

`depressed` 는 `THREAD_SCHED_INFO` 의 필드다.  self-sampling 이라 깨어난 뒤까지
남은 depression 만 보이므로 **0 이 부재의 증거는 아니다** — 참고치로만 읽는다.
판정은 총 대기시간과 갭의 비교로 한다.

**스모크 테스트 (2026-09-09, 실기, `test/openstep/sdlaudioprio.c`)** — 게임 없이
무음 5초.  두 팔이 실제로 다르게 동작하는지, 우선순위가 실제로 올라가는지를
게임 네 판을 돌리기 전에 확인한 것:

    arm 0 (yield, off) : base priority 10, current 10, max 18, depressed 0
                         SDL mutexes yield; 85 acquisitions took 0 ms
    arm 3 (block, on)  : base priority 18, current 18, max 18, depressed 0
                         SDL mutexes block; 85 acquisitions took 0 ms
    둘 다: 84 buffers, 갭 전부 <25 ms, worst submit 3 ms

읽은 것:
- **`max_priority` = 18** 이다.  boost 10 은 10+10=20 을 요청하고 18 로
  클램프된다 — 클램프가 없었으면 `cthread_priority` 가 실패했을 것이다.
- 우선순위 인상이 **실제로 걸린다**(10 → 18).  메인 스레드는 10 이므로 오디오
  스레드가 그 위에 선다.
- 경합이 없으면 락 대기는 **0 ms** 다.  게임에서 이 숫자가 커진다면 그것이
  경합의 직접 증거가 된다.

**판 2 의 위험**: 우선순위만 올리고 뮤텍스는 yield 로 두면, 18 짜리 오디오
스레드가 10 짜리 락 보유자를 기다리며 도는 모양이 된다.  OPENSTEP 에는
우선순위 상속이 없다.  `cthread_yield` 가 `swtch_pri(0)` 로 자기를 낮추므로
완전한 라이브록은 아니지만, **판 2 는 진단용이지 출하 후보가 아니다.**

### C — 계측 (다음에 필요해지면)

`beginFun`/`endFun` 시각으로 사운드마다 실제 재생 길이를 재면 무음 서술자를
직접 셀 수 있다.  지금은 `sndslack` 이 밖에서 같은 것을 세므로 급하지 않다.

### D — libsound 우회 (구조 변경, 미검증)

`docs/PLAN_SNDSTREAM_PROBE.md`.  배경 스레드 홉과 6개 상한과 이음매가
없어지지만 **커널 선행분은 그대로**다.  지연을 200 ms 아래로 내리고 싶을 때만.

---

## 4. 순서

1. **A1 + A2** — 완료·실기 반영·재측정 끝.  여유 220~280 ms, 지연 그대로 375 ms.
2. **B1 + B2 + B3** — 완료·실기 반영.  **water1 4판 A/B 로 판정 끝**(§2.6):
   원인은 **우선순위(B2)**, 뮤텍스(B1)는 단독으로는 손해·우선순위와 함께면 공짜.
3. **남은 것 — 아래 셋.**

### 4.1 quake — 쟀다, 그리고 SDL2 밖이다 (§2.7)

예측대로였다: 락 대기가 water1(0.06 s)과 달리 **19.3 s** 로 나왔고 최악 갭과
최악 락 대기가 3 ms 차이다.  B1·B2 어느 쪽도 도움이 안 된다.  **닫는다** —
남은 것은 quake 의 일이지 SDL2 의 일이 아니다.

### 4.2 판 2 의 크래시 — 일회성으로 두고 닫음 (2026-09-09 결정, §2.6.1)

**사용자 결정: 재현은 당분간 하지 않는다.  일회성으로 보고, B1(블로킹
뮤텍스)은 유지한다.**  판 2 는 애초에 출하 후보가 아니었고 판 3 이 측정된
유일한 좋은 구성이므로, 이 결정으로 출하 구성은 바뀌지 않는다.  재현이
필요해지면 `test/openstep/snd-crash.sh` 가 준비돼 있다(coredump 제한을 풀고
판 2 를 돌린다 — csh 기본 `coredumpsize` 가 0 이라 첫 크래시에 core 가 없었다):

    csh -c 'limit coredumpsize unlimited; sh /usr/local/nxbuild/snd-ab.sh 2 water1'

두 번 다 멀쩡하면 일회성으로 기록하고 닫고, 재현되면 core 를 gdb 로 본다.

### 4.3 기본값은 판 3 으로 둔다 — 확정

근거를 정직하게: B1(블로킹)이 **단독으로 도움이 된 측정은 하나도 없다**.
water1 에서 단독으로는 손해(≥100 ms 11.8 → 25.4/1000), quake 에서는 획득당
대기가 7.2 → 11.2 ms.  유일한 이점은 water1 의 긴 꼬리(≥375 ms 3회 → 0).

그런데도 기본값을 판 3(둘 다 켬)으로 두는 이유는 하나다: **판 3 이 실제로 측정된
유일한 좋은 구성**이기 때문이다.  "우선순위만"(판 2)은 측정이 없고, 그 조합이
한 번 크래시했다.  측정되지 않은 구성을 기본값으로 출하하지 않는다.
§4.2 는 재현 없이 닫혔고(사용자 결정), B1 은 **유지**한다.

## 5. 제외 — 앱 변경이 필요해서

- water1 이 44100 을 직접 요구하게(리샘플러 제거) — 앱.  CPU 로는 무의미하다.
- quake 의 `S_PaintChannels` 를 콜백 밖으로 — 앱.
- 앱이 `SDL_LockAudio` 를 덜 잡게 — 앱.  **glquake 는 여기에 걸린다**: §2.7 의
  실측이 그 락이 원인임을 확정했고, SDL2 안에는 손댈 곳이 없다.  이 제약을
  만족시킬 수 없는 유일한 사례다.  **이 줄의 예전 내용은 틀렸다**(§6):
  quake 는 프레임 전체를 잠그고(`gl_vidsdl.c:625,647`), water1 은 타이핑 한
  글자마다 잠근다(`sound.c:200-221`).  둘 다 락 경합의 실제 발생원이지만,
  고치는 것은 앱이므로 여기 남는다.  SDL2 쪽에서 할 수 있는 것은 **경합했을 때
  오디오 스레드가 치르는 값을 줄이는 것**이고 그것이 §3 B 다.

---

## 6. 틀렸던 것 (기록)

| 가정 | 어디에 | 실제 |
|---|---|---|
| "여유 = (AHEAD−1)×버퍼" | `SDL_openstepaudio.h:11` | 거기서 C=160~165 ms 를 빼야 한다 (실측) |
| "SDL underrun 카운터 0 = 안 마름" | 예전 판정 | 그 카운터는 구조상 발화 불가 |
| "드라이버 카운터가 조용 = 안 마름" | AC97 Stage 9 | 무음 패딩은 정지가 아니라 안 보인다 |
| "오디오 스레드가 CPU 를 안 잃으니 우선순위는 무의미" | 커밋 `ad60237` | 여유가 250 인 줄 알고 내린 결론이었다 |
| (이 문서 1판) "매 반복 D 만큼 재우면 여유를 잰다" | v1 계획 | **판별력 0.** slack 111 이든 250 이든 같은 결과가 나온다(시뮬레이션으로 확인).  고립 stall 로 바꿨다 |
| (이 문서 2판) "여유는 111 ms" | §2 | 위상 범위이고, 실측은 85~90 |
| (측정 중) "stall 직후 간격이 길면 굶은 것" | 1차 검출기 | **stall 자체가 그 간격에 들어 있다.** 프래그먼트 수 셈으로 바꿨다 |
| (히스토그램 판독) "여유 250 ms 초과 35회/4회" | §2.5 초판 | 라벨이 한 칸 밀렸다.  그건 **≥150 ms** 였고, ≥250 ms 는 glquake 22 · water1 3 (codex 6차가 지적, 재확인함) |
| "콜백당 락 수요가 두 배가 된다" | A2 검토 | 변환 스트림이 있으면 콜백 크기는 **앱의** `callbackspec.size` 다.  기하 변경은 락 수요를 늘리지 않았다 (codex 4차, 재확인함) |
| "quake 는 오디오 락을 안 잡는다" | §5 | `snd_sdl.c` 만 읽고 내린 결론이었다.  **`gl_vidsdl.c:625,647` 이 프레임 전체를 잠근다** (codex 가 찾음, 소스로 확인) |
| "base 10 / current 7 이 `swtch_pri` 의 증거" | 뮤텍스 계획 1판 | `Concepts.rtf` 가 timesharing 의 aging 을 명시한다 — 평범한 노화로도 같은 숫자다.  인과는 **아직 증명되지 않았고**, 판별자를 따로 넣었다 (codex 7차, 문서로 확인) |
| "quake 는 초당 1프레임쯤" | 갭 분석 | 사용자 정정: "opengl 기준으로 초당 1프레임이 훨씬 넘습니다" |
| "cthreads 뮤텍스가 오디오 스레드를 굶긴다" | §2.5 (이 문서 3판) | **틀렸다.** 대조군에서 락 대기는 12,254회에 61 ms, 공급 부족의 2.3% 다.  원인은 우선순위 스텁이었다.  ‑ 내가 만든 판별자가 내 가설을 기각했다 |
| "블로킹 뮤텍스가 개선일 것" | B1 | 단독으로는 **악화**(≥100 ms 갭 13 → 32).  yield 는 락이 풀리자마자 낚아채고 블로킹은 깨어나야 하는데, 낮은 우선순위에서는 그게 늦다 |

---

## 7. 아직 모르는 것

1. **게임이 오디오 스레드를 실제로 얼마나 늦추는가.**  여유는 이제 알지만
   수요는 모른다.  C(계측)가 답한다.
2. AC'97·ES1371 에서도 C 가 같은가.  기하는 커널 것이라 같아야 하지만 안 쟀다.
3. `msgUnderrun`(D 경로)이 무음 패딩을 세는가.
4. cthreads 가 1:1 인가 — B2 의 전제.  (`struct cthread` 에 `real_thread`
   필드가 있고 `cthread_priority` 가 그것을 쓰므로 정황은 1:1 이지만, 안 쟀다.)
5. WindowServer 의 스케줄링 우선순위.
6. **§2.5 의 두 후보 중 어느 것인가.**  판별 실험이 §4 의 표다.
7. ~~`max_priority` 의 실제 값~~ — **18 이다**(실측).  boost 10 은 클램프되어
   base 10 → 18 이 된다.
8. 우선순위를 올렸을 때 **락 보유자(메인 스레드)를 굶기지 않는가.**  OPENSTEP
   에는 우선순위 상속이 없다.  B1(블로킹)이 함께 들어가야 안전한 이유이고,
   판 2(우선순위만)를 따로 재는 이유다.

---

## 8. 어떻게 쟀나

`test/openstep/sndslack.c` + `docs/measurements/README.md`.
요약: SoundKit 만 쓰는 프로그램이 SDL 백엔드의 제출 루프를 그대로 흉내내고,
41 버퍼마다 한 번 stall 을 넣어 굶겼는지를 **소비된 서술자 수**로 센다.
stall 없는 60초 실행의 오검출은 479 간격 중 0.8 서술자(잡음 바닥).

`test/openstep/openstep-sdl-scale-teapot.c` 는 아직 안 돌린 재현 예제다 —
같은 오디오에 화면(AppKit / Matrox / 없음)을 붙여 video 경합을 가른다.

---

## 9. codex 교차검토 (gpt-6-astra)

두 차례 받았고, 두 번 다 설계를 실제로 바꿨다.

**1차(분석 문서)** — 12건 중: 상한이 5가 아니라 6, 선행분이 "항상 4"가 아니라
시작 때 결정(→ 이것이 A1 이 됐다), `task_priority` 안 폐기, SDL 루프 서술 정정,
계측 방식 재설계.  기각한 것 하나: `snddriver_set_sndout_buf*` 가 레버라는
주장 — 커널 xref 로 IOAudio 에 닿지 않음을 확인했다.

**2차(측정 계획)** — 핵심 지적 하나가 v1 설계를 죽였다: "매 반복 재우기는
처리량 한계를 재지 여유를 재지 않는다."  시뮬레이션으로 확인했고 그 말이
맞았다.  또 "완료가 서술자에 양자화되면 잔차 잡음이 46 ms 에 이른다"도 맞아서,
잔차 대신 서술자 수 셈으로 갔다.  "AHEAD 3 대 4 에서 160 ms 이분법" 제안은
채택했고 그것이 첫 결정적 측정이 됐다.

**3차(구현 계획)** — 일곱 건 중 셋을 채택했다.

| codex 주장 | 내 검증 | 판정 |
|---|---|---|
| 프라이머를 같은 FIFO 에 넣으면 최대 동시 미회수는 7이 아니라 **6**, 8칸으로 충분 | 루프를 python 으로 돌려 확인(2,3,4,5,5,… 최대 6) | ✅ 채택 |
| `mixer_lock` 은 **콜백만** 감싸고 제출은 그 밖이다 — 메인 스레드가 잠금을 쥐는 것은 sndslack 의 stall 과 같지 않다 | `SDL_audio.c:731-745` 직접 확인.  맞다.  검증 도구 계획에서 그 방법을 뺐다 | ✅ 채택 |
| 기하가 형식에 의존한다 — 22050·모노에서는 서술자 길이가 달라 계산이 무너진다 | 22050 모노면 서술자가 185.8 ms(계산 확인).  **장치를 44100 스테레오로 고정**해 측정한 구성과 출하 구성을 일치시켰다 | ✅ 채택 |
| 프라이머 실패·재개방·일시정지 처리를 명시하라 | 플래그를 시도 **전에** 세우고, 프라이머를 같은 FIFO 에 넣어 기존 회수 경로가 처리하게 했다.  일시정지 중에도 코어가 무음을 제출하므로 프라이머는 정상 동작한다(`SDL_audio.c:733`) | ✅ 채택 |
| 수요(오디오 스레드가 실제로 얼마나 늦는가)를 안 재고 여유를 정하는 것 | 맞다.  다만 프라이머 2048 로 여유가 **220~280 ms** 가 되어 프레임 176 ms 와 여유가 생겼다 — 겹치던 구간이 사라졌다 | ⚖️ 부분채택 |
| 우선순위를 먼저 재라 | 여유가 프레임보다 작을 때는 못 구한다는 것이 이번 측정의 결론이다.  A 뒤로 미룬다 | ⏭️ 보류 |

**4~6차(측정 판독)** — 두 건이 내 오독을 잡았다: 히스토그램 라벨이 한 칸
밀린 것(≥150 을 ≥250 으로 읽었다)과, 기하 변경이 콜백당 락 수요를 두 배로
만든다는 내 산수가 틀렸다는 것(변환 스트림이 있으면 콜백 크기는 앱의
`callbackspec.size` 다).  둘 다 소스로 확인하고 정정했다.  같은 회차에
codex 가 "glquake 히스토그램 합이 484" 라고 한 것은 **틀렸다** — 474 이고,
버퍼 475 개와 맞는다.

**7차(뮤텍스 계획)** — 여섯 건.  이번에는 **codex 가 내 인과 증명을 죽였다.**

| codex 주장 | 내 검증 | 판정 |
|---|---|---|
| timesharing 은 실행하면서 우선순위를 낮춘다.  10→7 은 `swtch_pri` 를 지목하지 않는다 | `Concepts.rtf` L636 원문: "a thread's priority gets lower as it runs (it ages)" | ✅ **채택.**  내 증명이 틀렸다 |
| `THREAD_SCHED_INFO` 에 `depressed`/`depress_priority` 가 있다 | `mach/thread_info.h:137-151` | ✅ 사실.  계측을 그쪽으로 옮겼다 |
| `condition_wait` 도 `swtch_pri(0)` 를 부른다, `condition_yield_limit=7` | libsys `0x5090258` 디컴파일, 전역 `0x40101b0` = 7, `0x40101ac` = 0 | ✅ 사실 |
| 따라서 "블로킹은 반복 양보를 없애지 못하고 한정할 뿐" | `mutex_wait_lock`(`0x5090c10`) 대조: `mutex_spin_limit` = **0**, 그 뒤가 **무한** yield 루프 | ⚖️ 부분채택.  맞지만 7 대 ∞ 의 차이가 요점이다 |
| 대기자 등록이 뮤텍스 해제보다 앞서므로 lost wakeup 창이 닫힌다 | 같은 디컴파일에서 확인.  그래도 `while (held)` 재검사는 유지 | ✅ 채택 |
| TryLock 이 블로킹하면 SDL 규약 위반 | 논리 락은 절대 기다리지 않게 짰다(guard 만 잠깐) | ✅ 채택 |
| `SDL_syscond.c` 는 네이티브 뮤텍스를 안 건드린다 | 전수 grep: 전부 `SDL_LockMutex`/`SDL_UnlockMutex` | ✅ 사실 |
| Linux 비교는 개연성 증거일 뿐, 결정적 대조는 실기 A/B | — | ✅ 채택.  한 빌드에 환경변수 A/B 를 넣었다 |
| `PlayDevice` 는 mixer_lock 밖이라 233 ms 는 별도 귀속이 필요 | `SDL_audio.c:731-745` 재확인 | ✅ 사실 |

codex 가 맞은 것과 내가 맞은 것이 둘 다 있었다.  채택은 전부 직접 검증한 뒤에
했고, 검증 방법은 각 항목에 적어 두었다.  **codex 를 근거로 쓴 항목은 하나도
없다** — 근거는 전부 소스·바이너리·문서 원문이다.

---

## 10. OPENSTEP 자신의 답 — MachKit 잠금 클래스

이 포트를 쓰기 전에 확인했어야 할 것: OPENSTEP 문서에는 뮤텍스 예제가 **따로
있다**.  `NextDev/Conversion/3.3_Reference/GeneralRef/09_MachKit/Classes/` 에
`NXLock` · `NXConditionLock` · `NXRecursiveLock` · `NXSpinLock` 네 개.

`NXLock.rtf` 원문:

> An NXLock is used to protect regions of code that can consume long periods
> of time, such as disk I/O or heavy computations. ... If a region of code is
> in use, an NXLock waits using the `condition_wait()` function, so the
> thread doesn't busy-wait.
>
> **lock** — Waits until the lock isn't in use, using `condition_wait()` if
> necessary, then grabs the lock.
> **unlock** — Releases the lock, using `condition_signal()` to signal the
> next party that the lock is available.

`NXSpinLock` 이 따로 있다는 사실 자체가 설계 의도를 말한다: 스핀은 **짧은**
구역용으로 따로 마련해 두고, 오래 걸리는 구역의 기본은 `condition_wait` 이다.
cthreads 의 맨 `mutex_lock` 은 그 둘 중 어느 쪽도 아니다 — 무한히 스핀하되
매 회전마다 자기 우선순위를 낮추는, 가장 나쁜 조합이다.

`Concepts.rtf` 도 같은 곳을 가리킨다: "Another way of protecting critical
regions and synchronizing threads is to use the Mach Kit's locking classes."

B1 은 그래서 MachKit 을 링크하지 않고 **그 클래스가 하는 일을 그대로** 한다
(SDL2 는 Objective-C 런타임과 AppKit 의존을 스레드 계층에 들이지 않는다).

---

## 11. 더 남은 개선 후보 — 선입견 없는 재조사 (2026-09-09)

codex(gpt-6-astra)에게 "이미 한 것(A1·A2·B1·B2)을 빼고, 선입견 없이 무엇이
더 가능한가"를 묻고, 그와 **병렬로** 소스를 직접 읽었다.  아래는 두 결과를
대조한 뒤 **직접 검증한 것만** 적은 것이다.  codex 를 근거로 쓴 항목은 없다.

### 11.1 판정표 — codex 주장 7건 + 내 후보 3건

| # | 주장 | 내 검증 | 판정 |
|---|---|---|---|
| c1 | **스핀락 fallback 이 타이머 락으로 재귀한다** | `SDL_spinlock.c:172-182`: 32회 pause 뒤 `SDL_Delay(0)`.  포트 `SDL_systimer.c:114`: `SDL_Delay` 가 먼저 `SDL_GetTicks64()` → `:54` `SDL_AtomicLock(&openstep_ticks_lock)`.  `SDL_GetPerformanceCounter`(`:96`)도 같은 락.  **`SDL_Delay(0)` 은 `elapsed >= 0` 이라 `select` 없이 즉시 반환** — 양보가 전혀 없다 | ✅ **채택 — 1순위** (§11.2) |
| c2 | 버퍼당 malloc+memcpy 를 풀로 바꾸라; 그리고 **판 3 의 `worst submit 399 ms` 는 갭 히스토그램 밖**이다 | `SDL_openstepaudio.m:180,192,107` 확인.  `spent`(`:262`)는 PlayDevice 안, `gap` 은 WaitDevice→PlayDevice — **서로 다른 구간**.  즉 "≥100 ms 갭 0" 은 399 ms 의 제출 지연을 덮지 않는다.  `ab-3-water1.log:3` 그대로 | ✅ 채택 (내 후보 ①과 같음).  399 ms 는 **언제** 났는지 모른다 — 계측 보강이 먼저 |
| c3 | 리샘플러가 put 마다 **위상을 잃는다** | `SDL_audiocvt.c:215` `outframes` 를 호출마다 floor, `:221` `srcindex` 를 0부터, `:974` 래퍼는 표본 이력만 넘긴다.  python: water1 은 put 마다 908.327 → 908, **7.4 µs 씩 48.55 Hz 로** 시간축이 끊긴다 (360 ppm) | ✅ 사실.  **끊김 원인은 아니다**(코어가 콜백을 더 부른다).  음질 후보 — 호스트에서 시험 가능 |
| c4 | 리샘플러 패딩이 과하다 (578 프레임 = 11.6 ms 지연) | `ResamplerPadding`(`:184-197`)이 `SAMPLES_PER_ZERO_CROSSING`(512) 기준.  탭은 좌우 5개뿐 | ✅ 사실.  이득 11.5 ms — 375 ms 앞에서는 작다.  후순위 |
| c5 | 리샘플러 산술 최적화 (출력 프레임마다 64비트 나눗셈·나머지) | `:222` `((Sint64)i) * inrate % outrate` — cc 2.7.2.1 은 `__moddi3` 호출.  비용은 **측정 전엔 모른다** | ⚖️ 부분채택 — `sndcost` 로 먼저 잰다 |
| c6 | 계측 자체의 비용 (버퍼당 `thread_info` 4회, 획득당 카운터 2회) | 사실.  python: 카운터 읽기만 ~0.16% CPU | ⏭️ 작다.  단, **c1 의 노출을 늘린다**(락 읽기 횟수) |
| c7 | 데이터큐 락/복사 제거 | 사실이나 측정된 락 대기가 68 ms/78 s 다 | ⏭️ 이득 없음 |
| c* | **문서 모델의 불일치**: `C=110~130` 이면 freq/16 예측은 182~202 인데 실측은 220~280 | python 으로 확인.  역산하면 C = 32~92.  "C 는 상수" 는 **프라이머 없는** 경우에만 검증된 말이다 | ✅ 채택 — §0·§2 의 서술을 좁혀야 한다 |
| ① | (내 것) 버퍼당 malloc/free/memcpy 제거 — 슬롯 8개를 미리 잡고 `GetDeviceBuf` 가 그 안을 준다 | `SDL_audio.c:755-771`: GetDeviceBuf 는 직전 WaitDevice **뒤**에 불리므로 그때 `count <= 6`, 슬롯 8이면 반환 슬롯은 항상 회수된 것 | ✅ 안전.  malloc 락(cthreads, 무한 yield 계열) 노출도 없앤다 |
| ② | (내 것) `SNDWait` → `condition_wait` 가 대기마다 **최대 7회 `swtch_pri(0)`** 로 오디오 스레드를 스스로 낮춘다.  Mach 포트 `msg_receive` 로 진짜 블록하게 | libsound 디컴파일(§1.2) 그대로.  단 완료 통지 사슬(libsound 배경 스레드)은 그대로다 | ⚖️ 후보 — 실측(depressed 관측)이 먼저 |
| ③ | (내 것) libsound 배경 스레드(`perform_reply_thread`)의 우선순위 — 우리 스레드는 18 로 올렸지만 그 앞 사슬은 10 그대로일 것 | 누구도 잰 적 없다.  `sndcost` 가 `task_threads()` 로 답한다 | ⚖️ 측정 후 결정 |

**codex 가 놓친 것**: ①의 안전 조건(호출 순서), ②, ③.  **내가 놓친 것**:
c1(가장 큰 것), c3, c*.

### 11.2 1순위 — `SDL_Delay(0)` 이 타이머 락으로 되돌아온다

메커니즘, 전부 소스에서:

    SDL_AtomicLock(lock)            32회 pause 뒤
      SDL_Delay(0)                  포트: 먼저 SDL_GetTicks64()
        OpenStep_GetElapsedMicroseconds()
          SDL_AtomicLock(&openstep_ticks_lock)   <- 이것이 경합 중인 그 락이면
            32회 pause 뒤 SDL_Delay(0) ...       <- 재귀, 양보 없음

`SDL_Delay(0)` 은 `elapsed >= 0` 이 즉시 참이라 `select` 를 부르지 않는다.
어느 단계도 CPU 를 놓지 않으므로, 락 보유자(메인 스레드)가 **임계구역 안에서
선점된 채**로 있는 동안 오디오 스레드는 재귀만 쌓는다.  한 단계가 마이크로초
단위이므로 **1 ms 안에 수백 단계** — cthread 스택이 64 KB 면 약 400 단계에서
넘친다.  증상은 **출력 없는 memory fault** 다.

노출은 우리가 만든 것이다: 백엔드가 버퍼마다 4번, 뮤텍스 계측이 획득마다 2번
`SDL_GetPerformanceCounter` 를 부르고, water1 은 메인 스레드에서 `SDL_GetTicks`
를 63곳에서 부른다.  그리고 **B2 가 상황을 바꿨다** — 오디오 스레드가 18 이면
깨어날 때마다 메인(10)을 **그 자리에서** 선점한다.  임계구역 안에서 선점될
확률이 B2 전보다 높아졌다.

**판 2 의 크래시가 이것이었다는 증거는 없다.**  판 3 도 같은 노출을 갖고
78초를 버텼다.  다만 "출력 없는 memory fault" 라는 증상과, 판 2·3 에서만
노출이 커진다는 점은 맞아떨어진다 — **가설로 기록한다.**  고칠 이유는 그
가설과 무관하다: 재귀는 어느 앱에서든 성립하는 잠재 크래시다.

고치는 곳은 포트 안, 두 줄이면 된다: `SDL_Delay` 가 `milliseconds == 0`
이면 타이머를 건드리지 않고 **진짜 양보**(`thread_switch` 로 depress, 또는
`cthread_yield`)를 한 뒤 반환한다.  그러면 코어의 스핀락 fallback 이 처음
의도한 "양보"가 되고, 재귀 경로가 사라진다.  코어 `SDL_spinlock.c` 는 손대지
않는다.

### 11.3 순위

| 순위 | 후보 | 성격 | 이득 | 확인 방법 |
|---|---|---|---|---|
| 1 | **§11.2 `SDL_Delay(0)` 재귀 제거** | 잠재 크래시 | 안정성 | 소스로 이미 확정.  포트 안 두 줄 |
| 2 | 계측 보강: `worst submit` 의 **시각**을 남긴다 (long gap 처럼) | 계측 | 399 ms 의 정체 | 실기 water1 1판 |
| 3 | ① 버퍼 풀 + 무복사 `GetDeviceBuf` | CPU·malloc 락 노출 | 버퍼당 malloc/free 1쌍 + 11 KB 복사 제거 | `sndcost` 전후 |
| 4 | `sndcost` 로 **변환 경로 비용**과 **libsound 배경 스레드 우선순위** 측정 (③, c5 의 전제) | 측정 | 방향 결정 | 실기 3회 × 22초, 무음 |
| 5 | ② `SNDWait` 대신 포트 대기 | 우선순위 하락 제거 | `depressed` 관측이 답 | 실기 |
| 6 | c3 리샘플러 위상 유지 | 음질 | 48.55 Hz 위상 끊김 제거 | **호스트에서** 사인파 비교 |
| 7 | c4 패딩 축소 | 지연 11.5 ms | 작다 | 호스트 |
| — | c* 문서의 C 서술 수정 | 정확성 | — | python 으로 확인 완료 |

**게임의 끊김에 대한 정직한 상태**: 판 3 에서 water1 의 갭은 전부 100 ms
아래이지만, **제출 지연 399 ms 가 히스토그램 밖에 한 번 있다.**  그것이
시작 시점(프라이머 + 첫 스트림 시작)이면 무해하고, 정상 재생 중이면 여유
220~280 을 넘는 실제 지연이다.  순위 2 가 그것을 가른다.  quake 는 §2.7
그대로 SDL2 밖이다.

`test/openstep/sndcost.c` 가 순위 4 의 도구다 (변환 비용 = 무음 콜백에서의
task CPU, 스레드 목록 = `task_threads`).  아직 안 돌렸다.

### 11.4 `sndcost` 실측 (2026-09-09, 무음 22초 × 3, 판 3 기본값)

| 요청 rate | 스트림 | 전 스레드 CPU 합 | 몫 |
|---|---|---|---|
| 44100 | 없음 | 0.190 s | **0.9%** — 백엔드 자체(버퍼당 malloc+memcpy+SNDStartPlaying+SNDWait+계측) |
| 49716 (water1) | 있음 | 0.570 s | **2.6%** → 변환 경로 ≈ 1.7% |
| 11025 (quake) | 있음 | 0.460 s | 2.1% → 변환 경로 ≈ 1.2% |

(`TASK_BASIC_INFO` 의 시간은 이 커널에서 스레드가 살아 있는 동안 0 이다 —
스레드별 `THREAD_BASIC_INFO` 를 합산했다.  프로그램 주석에 적어 두었다.)

읽은 것:

- **리샘플러는 싸다.**  sinc 5탭 + 프레임당 64비트 `%` 를 다 합쳐 1.7%.
  c5(산술 최적화)와 "빠른 리샘플러" 는 **기각** — 얻을 것이 없다.  water1 의
  `gap 127 / cpu 30 ms` 는 앱의 OPL 합성이었다.
- 후보 ①(무복사 풀)의 CPU 이득은 0.9% 의 일부다.  남는 가치는 malloc 락
  노출 제거뿐 — **후순위로 내린다.**
- **libsound 배경 스레드(thread 2)는 base 10 / cur 10** 이다.  세 번 다.
  완료 통지 사슬(커널 → 이 스레드의 `msg_receive` → `condition_signal` →
  우리 `SNDWait`)의 한가운데가 메인 스레드와 **같은 우선순위**로 경쟁한다.
  우리 스레드를 18 로 올린 것은 사슬의 마지막 고리만 올린 것이다 — **후보 ③
  을 승격**한다.  실험 설계: `sndslack` 이 그 스레드를 `thread_priority()` 로
  18 에 올린 채 고립 stall 시험을 다시 하면, 여유가 늘어나는 만큼이 C 안의
  통지 지연이다.
- `worst submit` 은 부팅 뒤 **첫 실행에서만** 70~87 ms 이고 이후는 3~6 ms.
  판 3 의 399 ms 도 시작 비용일 가능성이 커졌지만, **시각을 남기는 계측**
  없이는 단정하지 않는다(순위 2 그대로).
- 스레드는 셋뿐이다: 메인, SDL 오디오, libsound.  타이머 스레드 없음.

### 11.5 1순위 적용 (2026-09-09)

`port/openstep/src/timer/SDL_systimer.c`: `SDL_Delay(0)` 은 타이머를 건드리지
않고 `cthread_yield()` 한 뒤 반환한다.  코어 `SDL_spinlock.c` 는 그대로다.
실기 재빌드 `rc=0`(`drive.csh`).  첫 시도는 `#include <cthreads.h>` 로
실패했다 — 이 시스템에서는 `<mach/cthreads.h>` 다(다른 두 스레드 파일과 같이).

**같이 넣은 계측(§11.8 순위 1)**: `worst submit` 이 **언제, 몇 번째 버퍼에서**
났는지 함께 남긴다(`play_max_when`, `play_max_nbuf`).  갭 히스토그램은
WaitDevice 반환 → PlayDevice 진입 구간이고 `play` 는 제출 그 자체라 서로
다른 구간이므로, "≥100 ms 갭 0" 이 판 3 의 `worst submit 399 ms` 를 덮지
않는다.  2번째 버퍼의 399 ms 는 장치 시작이고 900번째의 399 ms 는 여유가
못 흡수하는 지연이다 — 두 단어가 그것을 가른다.

두 변경을 한 빌드에 넣고 게임을 재링크했다(`rc=0`).

**설치 단계를 빼먹어 한 판을 버렸다.**  `relink.sh` 는 water1 에 SDL 접두사로
`/LocalDeveloper` 를 넘기는데(glquake 에는 `/me/SDL20/build/...` 를 넘긴다),
새 라이브러리는 빌드 디렉터리에만 있었다.  그래서 water1 은 04:17 짜리 옛
사본으로 링크됐고, 보고에 새 계측 줄이 없는 것으로 드러났다.  판별법은
`strings libSDL2.a | grep -c 'buffer %u'` — 설치본 0, 새 것 1.  설치하고
다시 재링크한 뒤 **바이너리가 그 문자열을 담은 것까지** 확인했다.
빌드 성공은 설치의 증거가 아니다.  스모크는
`test/openstep/snd-smoke.sh` — 무음이라 사람이 들을 필요가 없고, 라이브러리가
여전히 열리고 우선순위 18 에 도달하고 두 뮤텍스 팔이 다르게 동작하는지만
본다.  게임 판정은 사용자가 직접 플레이해야 하므로 별도다.

### 11.6 후보 ③ 기각 — libsound 배경 스레드의 우선순위는 C 안에 없다

`sndslack` mode 2, 출하 기하(2756 프레임, AHEAD 6, 프라이머 2048 프레임),
41버퍼마다 stall, 60초씩.  세 팔:

- **c** 기준선 — 다른 부하 없음
- **a** 오늘의 SDL — 제출자 18, libsound 10, 우선순위 10 짜리 도는 부하 하나
- **b** 후보 ③ — 제출자와 **libsound 둘 다 18**, 같은 부하

우선순위 인상이 실제로 걸린 것을 로그로 확인했다(`self -> 18: kr 0`,
`thread 1 -> 18: kr 0`).  분석은 `docs/measurements/slack_excess.py`
(끼워 넣은 무음을 서술자 정수 개수로 센다; 기존 자료로 검산했다 —
`m2-a3` 13.0 굶음 / `m2-a4` 0.3 견딤, 알려진 답과 일치).

| stall | c 기준선 | a 오늘 | b 후보③ |
|---|---|---|---|
| 200 ms | +4.8 | −3.2 | −3.2 |
| 240 ms | −0.2 | −1.2 | −0.2 |
| 280 ms | **+16.0** | **+16.0** | **+17.0** |

**a 와 b 가 구별되지 않는다.**  세 stall 모두에서 차이가 잡음 폭(±3 서술자,
950 구간 기준) 안이다.  **후보 ③ 기각** — 사슬 한가운데의 우선순위를 올려도
여유가 늘지 않는다.  C 는 커널 선행분이지 배경 스레드의 스케줄이 아니다.

부수적으로 여유의 상한이 좁혀졌다: **240 은 견디고 280 은 굶는다**(세 팔
모두).  §1.4 의 220~280 과 맞고, 그 범위를 240~280 으로 줄인다.

(`c` 가 200 에서 한 번 +4.8 을 낸 것은 240 이 견딘 것과 어긋난다 —
단조롭지 않으므로 그 값은 잡음으로 읽는다.  음수 excess 는 이 통계의
편향이다: 판정은 +16 처럼 잡음의 다섯 배 이상일 때만 한다.)

### 11.7 c3 확정 — 청크 리샘플링은 왜곡이 아니라 **누적 밀림**이다

`test/openstep/resamp_chunk_test.c` (호스트).  SDL 자신의
`SDL_ResampleAudio` 를 잘라 와 1 kHz 사인을 water1 모양(49716 → 44100,
put 1024프레임 × 200)으로 한 번에/쪼개서 통과시켰다.

    single pass: 181665 frames    chunked: 181600    ideal 181665.460
    frames lost by chunking: 65   (0.325 per put = 358 ppm)

전역 RMS 는 0.99 로 "완전히 깨진" 것처럼 보이지만 **아니다.**  구간마다
이상적 사인에 정수 시프트를 허용하면:

| 출력 구간 | 최적 시프트 | 그때의 RMS |
|---|---|---|
| 0 | +177 | 0.046 |
| 22050 | +185 | 0.046 |
| 44100 | +193 | 0.049 |
| 66150 | −196 (감김) | 0.047 |
| … | 단조 진행 | … |

시프트가 **단조롭게 걷는다** — 표본은 맞고 위치만 밀린다.  정렬 후 남는
0.046(−26.7 dB)이 put 경계마다 위상이 0 으로 되돌아가는 몫이고, 그것이
48.55 Hz 로 반복된다.

그러므로 c3 은 **음질·피치 결함이지 끊김의 원인이 아니다**(코어가 콜백을 더
불러 표본 수는 채운다).  크기: 358 ppm 의 느린 피치 오차 + −26.7 dB 의
경계 잔차.  고치려면 스트림 리샘플러가 put 사이에 유리수 위상과 남은
분수 출력을 넘겨야 한다 — 상류 코어 변경이라 별건이다.

### 11.8 남은 순위 (11.3 갱신)

| 순위 | 후보 | 상태 |
|---|---|---|
| ~~1~~ | `SDL_Delay(0)` 재귀 | **완료** (§11.5), 게임 재링크·스모크 남음 |
| 1 | 계측: `worst submit` 의 **시각**을 남긴다 | 판 3 의 399 ms 가 시작 비용인지 가른다 |
| 2 | ① 버퍼 풀 + 무복사 `GetDeviceBuf` | 이득은 0.9% 의 일부 — malloc 락 노출 제거가 주목적 |
| 3 | ② `SNDWait` 대신 포트 대기 | 대기마다 최대 7회 `swtch_pri(0)`.  아직 안 쟀다 |
| 4 | c3 위상 유지 | 음질.  크기 확정(§11.7).  상류 변경 |
| 5 | c4 패딩 축소 (11.5 ms) | 작다 |
| — | c5 리샘플러 산술, ③ libsound 우선순위, c7 데이터큐 | **기각** (§11.4, §11.6) |

### 11.9 스모크 (2026-09-09, 무음, `test/openstep/snd-smoke.sh`)

새 라이브러리로 `sndcost` 세 rate + `sdlaudioprio` 두 뮤텍스 팔.

| 확인 | 결과 |
|---|---|
| 장치 열림·재생·닫힘 | 228 / 228 / 229 버퍼 |
| 갭 히스토그램 | **전부 첫 버킷(<25 ms)**, 최악 0~1 ms |
| 우선순위 | base 18, max 18 (한가할 때) |
| 두 뮤텍스 팔 | `block` / `yield` 로 갈림 |
| **새 계측** | `worst submit 9 ms at 4.558 s (buffer 78)` — 동작 |
| 변환 비용 | 0.3% / 2.7% / 2.0% (§11.4 와 일치) |

계측이 의도대로 갈라 준다: 44100 에서 buffer 78, 49716 에서 buffer 30,
11025 에서 buffer 1.

**한 번 16 이 나왔다가 18 로 돌아왔다.**  빌드·재링크 직후 기계가 붐빌 때
돈 스모크에서 다섯 판 모두 `base 16` 이었고(=`base_priority` 가 6 으로
읽혔다), 한가할 때 다시 재니 boost 10·12 와 두 팔 모두 18 이었다.
회귀가 아니라 **읽는 시점의 부하**다.  `SDL_SYS_SetThreadPriority` 는
그때의 `base_priority` 에 boost 를 더하므로, 부하 중에는 낮은 값에서
출발한다.  기능 요건(메인 10 보다 위)은 16 에서도 지켜진다.

**libsound 배경 스레드의 `swtch_pri` 를 처음 직접 봤다**: `sndcost` 의
스레드 표에서 `thread 2: base 0 cur 0 depressed 1`.  §11.6 이 그 스레드를
18 로 올려도 여유가 늘지 않음을 보였으므로, 관측은 흥미롭지만 지렛대는
아니다.

### 11.10 판 3 water1 — `worst submit` 은 시작 비용이 **아니었다** (2026-09-09)

`SDL_Delay(0)` 수정본을 **실제로 설치한 뒤**(§11.5 의 함정을 되풀이하지
않도록 `water1` 바이너리 안에서 문자열을 확인함) 한 판.

```
1071 buffers of 2756 frames, 6 queued; worst wait 99 ms, worst submit 405 ms at 12.931 s (buffer 202)
this thread base priority 18, current 10, max 18, depressed 0
SDL mutexes block; 11899 acquisitions took 60 ms in total, worst 0 ms
refill gap ms  <25:1064 <50:6 <100:0 <150:0 <250:0 <375:0 <500:0 >=500:0   worst 33 ms
underruns 0, no memory faults
```

**갭 쪽은 정리됐다.** 100 ms 이상 갭 0회, 최악 33 ms.  수정 전 같은 게임의
최악 갭은 189 ms 였고 100 ms 이상이 1회 있었다.  뮤텍스 대기는 11,899회
합계 60 ms, 최악 0 ms — B1 은 비용이 아니다.

**남은 것은 제출 자체다.** `buffer 202`, 재생 시작 12.931 초.  한 자리 수
버퍼면 장치 시작 비용이라 무해했겠지만 202번째는 재생 한복판이고,
405 ms 는 실측 여유 240~280 ms 를 넘는다.  §11.8 의 1순위 계측이 답한
질문이 이것이고, 답은 "시작 비용이 아니다" 다.

`worst wait 99 ms` 가 하나를 지운다: `SNDWait` 는 `DrainOne` 안에만 있고
그 최댓값이 99 ms 이므로, 405 ms 중 **최소 306 ms 는 `SNDWait` 밖**이다.

남은 후보는 `OPENSTEPAUDIO_Enqueue` 안의 셋이고, 둘 다 **cthreads 뮤텍스**
— 우리가 SDL 뮤텍스에서 고친 그 병리(`mutex_spin_limit=0`, 무한
`swtch_pri(0)`)를 그대로 가진 남의 락이다.

| 구간 | 왜 후보인가 |
|---|---|
| `SDL_malloc` 11 KB | cthreads malloc 은 뮤텍스를 쥔다.  water1 은 자기 스레드에서 `free`/`malloc`/`fread` 로 음악을 다시 읽는다(§2.6.1) — 12.9 초는 그럴 만한 시점 |
| `SNDStartPlaying` | libsound 의 큐 락.  배경 스레드가 `performance_started`/`ended` 동안 쥔다 |
| `SDL_memcpy` 11 KB | 1 ms 남짓.  대조군으로만 잰다 |

그래서 제출을 넷으로 쪼개 계측했다(`play_parts`, `part_max`,
`play_max_cpu`).  us 단위로 남기는 이유는 `copy` 가 ms 로 반올림하면
0 이 되어 대조군이 사라지기 때문이다.  같은 구간의 **프로세서 시간**도
함께 남긴다: 일하느라 걸린 시간은 CPU 를 쓰고, 안 돌던 시간은 안 쓴다.

```
worst submit = drain %u + malloc %u + copy %u + start %u us, %u us of it on processor
worst ever drain %u, malloc %u, copy %u, start %u us
```

**빌드는 설치가 아니다 — 두 번째 사례.**  `relink.sh` 는
`/usr/local/nxbuild/bin/glquake` 를 만드는데 `snd-ab.sh` 는
`/usr/local/quake/glquake` 를 실행한다.  후자는 04:20 에 멈춰 있었고,
그 사이의 quake 팔은 전부 **옛 라이브러리**를 잰 것이다(water1 은 §11.5
에서 이미 고쳐 두어 무사했다).  `relink.sh` 에 복사를 추가했다.

### 11.11 제출 400 ms 의 정체 — **전부 `SNDStartPlaying` 안**, CPU 0 (2026-09-09)

```
1262 buffers of 2756 frames, 6 queued; worst wait 418 ms, worst submit 394 ms at 73.169 s (buffer 1156)
worst submit = drain 5 + malloc 56 + copy 10 + start 394246 us, 0 us of it on processor
worst ever   drain 7,  malloc 470,  copy 425,  start 394246 us
this thread base priority 18, current 15, max 18, depressed 0
SDL mutexes block; 14021 acquisitions took 68 ms in total, worst 0 ms
refill gap ms  <25:1232 <50:26 <100:3 <150:0 <250:0 <375:0 <500:0 >=500:0   worst 96 ms
underruns 0, no memory faults
```

| 구간 | 최악 제출에서 | 전 구간 최댓값 |
|---|---|---|
| `drain` (`SNDWait`) | 5 us | 7 us |
| `malloc` 11 KB | 56 us | 470 us |
| `copy` 11 KB | 10 us | 425 us |
| **`SNDStartPlaying`** | **394,246 us (99.98%)** | 394,246 us |

**후보 ①(버퍼 풀 + 무복사 `GetDeviceBuf`)은 끊김 대책으로 죽었다.**
malloc 과 memcpy 를 통째로 없애도 회수할 수 있는 최댓값은 **0.9 ms**(470+425 us)
이고, 최악 제출에서는 **66 us** 다.  §11.8 의 2순위를 내린다.
(CPU 절감으로서의 가치는 §11.4 그대로 — 0.9% 의 일부.)

**그리고 그 394 ms 동안 이 스레드는 프로세서를 1 us 도 쓰지 않았다.**
cthreads 뮤텍스의 무한 `cthread_yield` 루프였다면 `swtch_pri` 시스템콜이
계속 돌아 system time 이 쌓인다.  0 은 **진짜 블록**을 가리킨다.
*단서*: 이 커널의 스레드 시간이 틱 표본이라면 매번 즉시 양보하는 루프는
표본에 안 잡힐 수 있다.  0 은 강한 정황이지 아직 증명은 아니다.

**같은 판에서 `SNDWait` 도 418 ms 를 블록했다.** 큐에는 6개 = 375 ms 뿐이므로
418 ms 를 기다렸다면 그 사이 커널은 최소 43 ms 를 무음으로 채웠다.
`drain` 최댓값이 7 us 인 것과 합치면 그 418 ms 는 `WaitDevice` 쪽이다.

#### 유력 가설 — libsound `perform_reply_thread` 의 500 ms

§1.2 에 IDA 로 적어 둔 두 값이 이 숫자와 맞물린다:

- `perform_reply_thread` 는 `msg_receive` **타임아웃 500 ms** 로 돈다.
- `initiate_performance` 는 시작 **전에** `3*pending_count > 15` 를 보므로
  동시에 시작되는 사운드는 **최대 6개**.

우리는 `QUEUE_AHEAD` **6** 으로 돌고 있다 — 정확히 그 경계다.  우리 `count`
는 `SNDWait` 가 돌아올 때 줄고, libsound 의 `pending_count` 는 **그 배경
스레드가** 종료를 처리할 때 준다.  둘이 하나만 어긋나도 제출은 경계에 걸린다.
그리고 394 ms 와 418 ms 는 둘 다 **500 ms 미만**이다 — "타임아웃 창 안
어딘가에서 시작해 타임아웃에서 풀렸다" 와 모양이 같다.

확인해야 할 것(다음 단계):

1. `start_performance` 가 경계에서 **블록하는지** 아니면 돌아가는지 —
   `ref/openstep/workspace/libsys.bin` 에서 직접 읽는다.  값이 싼 수정
   (`QUEUE_AHEAD` 를 5 로)과 큰 수정(D 안: libsound 우회)을 가르는 지점이다.
2. 400 ms급 사건의 **빈도**.  지금은 판마다 1회로 보인다(§11.10 은 12.9 초,
   여기는 73.2 초).  판마다 1회면 이것은 결함이지만 "자주 끊긴다" 의 주범은
   아니다 — 갭 히스토그램이 이미 깨끗하다는 것과 함께 봐야 한다.

**바뀐 순위**

| 순위 | 후보 | 상태 |
|---|---|---|
| 1 | `start_performance` 경계 확인 → `QUEUE_AHEAD` 또는 D 안 | 이번 실측이 지목 |
| 2 | ② `SNDWait` 대체 | 418 ms 를 봤다.  같은 뿌리일 가능성 |
| 3 | c3 위상 유지 | 음질 |
| 4 | c4 패딩 축소 | 작다 |
| — | ① 버퍼 풀 | **끊김 대책으로 기각**(위) |

## 12. water1 의 OPL 엔진 — CPU 하나로 감당되는가 (2026-09-09)

사용자 질문: "OPENSTEP 은 CPU 를 1개밖에 쓰지 못하니 water1 의 OPL 엔진에
개선 여지가 있지 않겠나."  `hostinfo` 가 그 전제를 확인해 준다 —
*"Kernel configured for a single processor only. 1 processor is physically
available."*  그리고 **아무도 이 비용을 잰 적이 없다.**

계측기: `openstep-water1/tools/oplbench.c` (+ `build-oplbench.sh`).
게임과 **같은 플래그**(`-m486 -O`)로 같은 소스를 빌드해, 층마다 자기 칩으로
1,024,000 샘플(20.6초)을 돌리고 스레드 CPU 시간을 잰다.  이 커널의 스레드
시간은 **10 ms 틱 표본**이라 (실측: 모든 값이 10000 us 의 배수) 20.6초
구간에서 분해능은 0.0098 us/샘플이다.

### 12.1 실측 — 음악은 단일 CPU 의 27%를 먹는다

| 층 | us/샘플 | CPU 한 개의 |
|---|---|---|
| `OPL3_GenerateStream` 묶음 호출 | 5.029 | 25.00% |
| `OPL3_GenerateResampled` 샘플마다 | 5.010 | 24.91% |
| `OPL3_Generate` (리샘플러 없이) | 4.932 | 24.52% |
| `OPL3_Generate4Ch` (핵심) | 4.932 | 24.52% |
| 같은 것, 아무 것도 안 눌린 칩 | 4.658 | 23.16% |
| `fmdrv_generate_samples`, **곡 없음** | 5.107 | **25.39%** |
| `fmdrv_generate_samples`, **실제 곡** | 5.518 | **27.43%** |

- 44100 장치 버퍼 하나(62.5 ms)를 채우는 데 콜백 3.03회, **OPL CPU 17.1 ms**.
- 리샘플러·래퍼는 다 합쳐 0.078~0.098 us/샘플 = **0.4~0.5 포인트**.  작다.
- 키 온/오프 차이는 0.274 us/샘플.  Nuked 는 소리가 나든 말든 슬롯을 돈다.

### 12.2 가장 큰 것 — 두 번째 뱅크는 이 게임에서 죽어 있다

`fmdrv` 의 `opl_write` 는 `uint8_t reg` 를 받고(`fmdrv.c:81`), `OPL3_WriteReg`
는 `high = (reg >> 8) & 1` 로 뱅크를 고른다.  **high 는 영원히 0** 이다 —
슬롯 18~35 와 채널 9~17 은 한 번도 쓰이지 않고, 키도 안 눌리고, 출력이 0 이다.
`0x105`(NEW 비트)도 high=1 이라 닿을 수 없으니 OPL3 모드도 못 켠다.
그런데 Nuked 는 **샘플마다 36 슬롯 전부와 18 채널 믹스를 두 번** 돈다.

**내가 놓친 것, codex 가 잡은 것.**  슬롯을 그냥 건너뛰면 안 된다:
`OPL3_PhaseGenerate` 의 마지막 두 줄(`opl3.c:633-634`)이 칩 공용 노이즈
LFSR 을 **슬롯마다 무조건** 한 칸 돌린다.  36회가 18회가 되면 리듬 슬롯
13(hh)/16(sd)/17(tc) 이 읽는 `noise & 1` 이 달라진다 — water1 은 리듬 모드를
쓴다.  내 첫 실험의 **체크섬이 실제로 어긋났다**(2056467700 vs 2479303268).
건너뛴 자리에 LFSR 18회를 넣자 체크섬이 일치했다.  순서도 안전하다:
노이즈를 읽는 슬롯은 전부 뱅크 0 이고, 뱅크 0 은 첫 건너뛴 슬롯보다 먼저
처리된다(`opl3.c:1124-1187`).

**A/B 실측** (같은 벤치마크·같은 플래그·같은 곡, `opl3.c` 만 다름):

| 층 | 원본 | 뱅크0 전용 | 절감 |
|---|---|---|---|
| `core` | 24.52% | 12.67% | 11.85 포인트 (48.3%) |
| `fmdrv` (곡 없음) | 25.39% | 13.06% | 12.33 포인트 (48.6%) |
| **`song` (실제 곡)** | **27.43%** | **15.63%** | **11.80 포인트 (43.0%)** |
| 체크섬 1,024,000 샘플 | 2056467700 | **2056467700** | **비트 단위 동일** |

장치 버퍼당 OPL CPU 17.1 ms → **9.8 ms**.

### 12.3 두 번째 — 음악이 멎어도 신시사이저는 계속 돈다

`fmdrv_tick` 은 `if (!s_playing) return;` 로 빠지지만(`fmdrv.c:1378`),
`fmdrv_generate_samples` 에는 아무 게이트가 없어 프레임마다 에뮬레이터를
돌린다(`fmdrv.c:1587-1610`).  그리고 `sound_stop_music`/`_immediate` 는
장치를 **일시정지하지 않는다**(`sound.c:179-190`) — `fmdrv_stop` 만 부른다.

즉 **음악이 꺼져 있는 동안에도 CPU 의 25.4% 가 무음 합성에 들어간다.**
(`fmdrv` 행이 정확히 그 상태다.)  `s_playing == false` 만으로는 부족하다:
SFX 는 OPL 채널 4 에서 따로 울고, 릴리스 꼬리도 남는다.  게이트는
"울리는 슬롯이 하나도 없고 SFX 도 없을 때" 여야 한다.

### 12.4 codex 병렬검토 판정 (2건, 계획 단계)

| 주장 | 검증 | 판정 |
|---|---|---|
| 뱅크1 제거가 최대 이득, 코어의 35~45% | 실측 A/B | ✅ **채택**, 실제로는 **48%** |
| 제거 시 노이즈 LFSR 18회를 보존해야 | `opl3.c:633-634` 확인 + 체크섬 불일치 재현 | ✅ **채택 — 내가 틀렸다** |
| 음악 정지 중에도 합성이 돈다 | `fmdrv.c:1587`, `sound.c:179` 확인 | ✅ **채택** |
| `OPL3_Generate` 로 리샘플러 우회가 1순위 | 실측 0.078 us/샘플 = **0.39 포인트** | ⚖️ **부분** — 맞지만 작다.  순위는 4위 |
| 44100 을 요청하면 SDL 변환이 없어진다 | 장치는 `AUDIO_S16MSB`(`SDL_openstepaudio.m`), 앱은 `S16SYS`(LSB) → **바이트 순서만으로 변환 스트림은 남는다** | ✅ **채택** — "44100 으로 맞추기" 안은 죽었다 |
| 44100 을 요청해도 칩은 여전히 초당 49716 스텝 | `rateratio` 계산 확인 | ✅ **채택** |
| 명령 파서가 꼬리재귀(`fmdrv.c:766`, `828`) → 스파이크 | 소스 확인.  cc 2.7.2.1 은 꼬리호출 최적화를 하지 않는다 | ⚖️ **부분** — 실재하나 깊이는 미측정 |
| `inst[15] == 0` 이면 비브라토가 스케일되지 않는다(`fmdrv.c:1069-1077`) | 코드 확인 — 원본 `IMUL/IDIV` 는 0 을 낼 것.  근거 문서 `FIX_FMDRV_PORT` 는 저장소에 없다 | ⚖️ **미결** — 원본 바이너리 대조 필요 |
| 즉시 key-off→key-on 쌍이 리트리거를 잃는다 | 기전은 맞으나 실기 OPL2 도 같을 수 있다 | ⏭️ **미검증** |
| 내 벤치마크의 `core` 행이 체크섬 일을 더 한다 | 소스 확인 — 사실 | ✅ **채택**, `core` 는 표시보다 조금 싸다 |
| 곡 인자 생략 시 0 → `fmdrv_play_song` 이 거절 | 실행에는 1 을 줬다 | ⏭️ 무해 |

### 12.5 순위 (전부 **water1 변경**이므로 §5 대상 — 사용자 결정 필요)

| 순위 | 항목 | 이득 | 위험 |
|---|---|---|---|
| 1 | 뱅크0 전용 렌더러 (+ LFSR 18회 보존) | **-11.8 포인트** | 낮음 — 체크섬 동일 확인됨 |
| 2 | 무음일 때 합성 정지 | 무음 구간 **-25 포인트** | 중 — SFX·릴리스 꼬리 판정 필요 |
| 3 | 명령 파서를 반복문으로 | 스파이크 | 낮음 |
| 4 | `OPL3_Generate` 직접 호출 | -0.39 포인트 | 낮음 (샘플 1개 지연이 생겨 비트 동일은 아님) |
| 5 | PIT 누산기를 32비트로 | 미측정, 작음 | 낮음 |
| — | 44100 요청으로 SDL 변환 제거 | **불가** — 바이트 순서가 남는다 | — |


### 12.6 적용 (2026-09-09) — 음악 합성 비용이 절반이 됐다

계획·검토·검증 절차는 `openstep-water1/docs/PLAN_OPL_COST.md`.
**게이트는 "비트 단위로 같은 오디오"** 였고, 통과했다.

| | 원본 | 수정본 | |
|---|---|---|---|
| `core` (`OPL3_Generate4Ch`) | 23.89% | 12.67% | −11.22 포인트 (−47.0%) |
| `fmdrv` (음악 **정지** 중) | 24.37% | 12.87% | −11.51 포인트 (−47.2%) |
| **`song` (실제 곡)** | **26.36%** | **15.29%** | **−11.07 포인트 (−42.0%)** |
| 62.5 ms 장치 버퍼당 OPL CPU | 16.5 ms | **9.6 ms** | |
| 체크섬 (1,024,000 샘플, 이중) | `2056467700 682112323` | **같음** | |

**적용한 것 (전부 `openstep-water1`)**

1. **뱅크 0 전용 렌더러** — `opl3_chip::opl2_only`.  `OPL3_Reset` 이 세우고
   상위 뱅크 쓰기가 영구히 내린다.  0 = 전체 처리이므로 리셋을 거치지 않은
   칩은 상류와 똑같이 동작한다.  건너뛴 18 슬롯의 **노이즈 LFSR 18회는
   그대로 돈다**.  QUIRK 를 끈 구성에서도 맞게 썼다.
2. **등배율 리샘플러 우회** — `rateratio == 1<<RSM_FRAC` 이고
   `samplecnt` 가 정상 상태일 때, 한 샘플 지연을 **그대로 재현**하고
   곱셈 8 + 정수 나눗셈 4 를 없앤다.  저장 순서까지 스톡과 같게 두어
   `buf4 == chip->samples` 별칭에서도 동일하다.
3. **PIT 누산기 32비트** — 누산기와 임계값 둘 다.  경계는 파이썬으로 재확인:
   임계 203,636,736, 뺄셈 직전 최댓값 204,829,917 < 2³¹.
4. **명령 파서 경계 검사** — 아래 §12.7.

**하지 않은 것**: 무음 게이트(§9.1 에서 기각), 파서 재귀 제거(최대 깊이 5).

**검증 범위**: 실제 곡 23개(main 1–16, opening 1–3, ending 1·2·3·20) ×
5단계(재생 / 음악 위 SFX / 페이드 / 즉시 정지 / 무음) + 직접 에뮬레이터
시험 6종(리듬 전면, 무음 후 스네어 단독, 릴리스 잔향, **뱅크1 지연 활성화**,
44100 Hz, 리셋 직후 8샘플).  133줄 전부 일치.

**설치 증거**: 컴파일러가 냈다.  `UINT64_C(0xfffffffff)` 경고의 줄 번호가
`opl3.c:1240` → **`opl3.c:1298`** 로 옮겨갔고, 오브젝트가 재컴파일됐다.
(바이너리 크기는 우연히 같았다 — 크기는 증거가 아니다.)

### 12.7 하네스가 원본의 크래시를 찾았다

`oplbench conform data/OMDATA.BIN 9` → **Memory fault**.
`fmdrv_play_song` 은 10바이트 항목이 **파일** 안에 들어가기만 하면 통과시키는데
(`fmdrv.c:1480`), OMDATA 는 곡이 8개인 5,517바이트다.  9번을 요청하면 음악
데이터를 곡 표로 읽어 그럴듯한 오프셋을 얻고, 명령 인출에는 범위 검사가
전혀 없으므로(`fmdrv.c:545`, `:781`) 파서가 버퍼 밖으로 걸어나간다.

두 명령 처리기 진입에 `data_ptr` 범위 검사를 넣어 채널을 비활성화한다.
범위 안 데이터에서는 절대 발화하지 않는다 — conform 표가 그대로인 것이 그
증거다.  **완전한 수리는 아니다**: 파일 끝에 걸친 명령의 피연산자 1~2바이트
초과 읽기는 남는다.  근본 수리는 곡 개수 검증이고 별건이다.

### 12.8 실기 확인 (2026-09-09) — 콜백 경로는 정리됐고, 남은 것은 libsound 하나

```
1247 buffers of 2756 frames, 6 queued; worst wait 94 ms, worst submit 399 ms at 77.111 s (buffer 1219)
worst submit = drain 5 + malloc 251 + copy 22 + start 399564 us, 0 us of it on processor
worst ever   drain 43, malloc 854, copy 85, start 399564 us
this thread base priority 18, current 17, max 18, depressed 0
SDL mutexes block; 13853 acquisitions took 68 ms in total, worst 0 ms
refill gap ms  <25:1245 <50:0 <100:1 <150:0 <250:0 <375:0 <500:0 >=500:0   worst 55 ms
underruns 0, no memory faults
```

| 리필 갭 | OPL 원본 | OPL 절반 |
|---|---|---|
| 25 ms 초과 | 30회 / 1262 (2.38%) | **2회 / 1247 (0.16%)** |
| 최악 | 96 ms | **55 ms** |

사용자 청취: *"전반적으로 꽤 괜찮은 상황"*, 다만 *"가끔 disk load 가 걸릴
때는 조금 끊기는 느낌"*.

**남은 결함은 하나로 좁혀졌다.**  세 판 연속 같은 모양이다:

| 판 | worst submit | 위치 | 어디서 | CPU |
|---|---|---|---|---|
| §11.10 | 405 ms | buffer 202 / 12.9 s | — (분해 전) | — |
| §11.11 | 394 ms | buffer 1156 / 73.2 s | `SNDStartPlaying` 99.98% | 0 us |
| 여기 | 399 ms | buffer 1219 / 77.1 s | `SNDStartPlaying` 99.99% | 0 us |

셋 다 **500 ms 미만**이고 전부 `SNDStartPlaying` 안이며 프로세서 시간이 0 이다.
`perform_reply_thread` 의 `msg_receive` 타임아웃이 500 ms 이고(§1.2),
그 스레드는 우선순위 0 에서 관측됐다(§11.9).  "타임아웃 창 안에서 시작해
타임아웃에서 풀렸다" 와 모양이 같고, 디스크 부하가 우선순위 0 스레드를
굶긴다는 사용자 관찰과도 맞는다.

**계측의 구멍**: 지금은 **최댓값 하나만** 남긴다.  판마다 1회인지 수십 회인지
알 수 없는데, 사용자는 "가끔"이라고 한다.  다음 판에서 갈리게 하려면
제출 시간의 **히스토그램**과, 느린 제출 시점의 **큐 깊이**가 필요하다.
큐 깊이가 필요한 이유: `initiate_performance` 는 `3*pending_count > 15` 로
동시 시작을 6개로 제한하는데 우리는 `QUEUE_AHEAD` **6** 으로 정확히 그
경계에서 돈다(§11.11).

### 12.9 결정적 실측 — 400 ms 는 판마다 1회가 아니라 **197회**였다 (2026-09-09)

계측을 최댓값에서 히스토그램으로 바꾸자 그림이 완전히 달라졌다.

```
1351 buffers; worst wait 99 ms, worst submit 508 ms at 25.879 s (buffer 403)
unpaused (first song) at 13.615 s, buffer 207
submit ms  <0.5:279  <1:667  <2:135  <5:11  <25:62 <100:177 <250:7 >=250:13
SNDWait ms  <25:270  <50:659 <62:53  <75:110 <100:255 <150:0 <250:0 >=250:0
197 slow submission(s) over 25 ms
refill gap ms  <25:1348 <50:2  나머지 0,  worst 33 ms
underruns 0, no memory faults
```

| 사실 | 값 | 무엇을 뜻하나 |
|---|---|---|
| 25 ms 초과 제출 | **197 / 1351 = 14.6%** | "판마다 1회" 는 **최댓값만 남기던 계측의 착시**였다 |
| 그 중 100 ms 초과 | 20회 | |
| 250 ms 초과 | 13회 | 여유(240~280 ms)를 넘는 것들 |
| 느린 제출의 원인 | **16건 전부 `SNDStartPlaying` 100%** | 우리 코드가 아니다 |
| 그때 큐 보유량 | **16건 전부 5** | 우리는 **항상 여섯 번째 사운드를 시작**한다 |
| `SNDWait` | 100 ms 초과 **0회** | 대기 경로는 멀쩡하다.  멈추는 것은 시작뿐 |
| 리필 갭 | 최악 33 ms, 25 ms 초과 2회 | **콜백 경로는 이제 문제가 아니다** |

**앱은 무죄다.**  첫 음악은 13.615 초에 시작하는데(장치가 그때까지
PAUSED 라 앱 콜백이 **아예 호출되지 않는다**), 느린 제출은
0.655 / 1.509 / 5.255 / 5.803 / 8.839 / 9.468 / 12.584 / 13.183 초 —
**콜백이 돌기도 전에 이미 300 ms 대가 여덟 번** 있었다.  OPL 도, 변환도,
뮤텍스도 아니다.

**사용자 청취와 일치한다.**  "첫 음악 시작할 때" → 13.183 s 에 420 ms.
"종료화면 불러올 때" → 25.3~28.9 초에 408·508·43·121·44·43·172 ms 가
연달아.  디스크가 도는 구간이다.

#### 가설과 그것을 가르는 실험

`initiate_performance` 는 시작 **전에** `3*pending_count > 15` 를 본다 —
동시에 시작된 사운드가 6개면 일곱 번째는 거절되고 배경 스레드를 기다린다
(§1.2).  우리 `QUEUE_AHEAD` 는 **6**, 큐 보유량은 항상 **5**, 즉 매번
여섯 번째를 시작한다.  **정확히 경계 위에서 돈다.**  libsound 의
`pending_count` 는 그 배경 스레드가 종료를 처리할 때 줄고, 그 스레드는
**base priority 0** 에서 관측됐다(§11.9).  디스크가 돌면 우선순위 0 스레드가
굶는다 — 사용자 관찰과 맞는다.

25~100 ms 가 177건으로 가장 많다는 점이 500 ms 타임아웃 가설보다 이쪽을
지지한다: 타임아웃이라면 값이 500 근처에 몰려야 한다.

**독립적인 두 스위치를 넣었다** (기본값은 지금 그대로):

| 환경변수 | 무엇 | 무엇을 가르나 |
|---|---|---|
| `SDL_OPENSTEP_QUEUE_AHEAD` (기본 6) | 큐에 유지할 사운드 수 | **5** 로 내리면 경계에서 한 칸 물러난다.  이것만으로 멎으면 원인은 **승인 검사** |
| `SDL_OPENSTEP_HELPER_PRIORITY` (기본 0) | 첫 제출 뒤 한 번, 이 태스크에서 **base priority 0** 인 스레드를 max 로 | 이것만으로 멎으면 원인은 **그 스레드가 안 돌던 것**.  0 만 골라 올리므로 게임 메인 스레드(10)는 건드리지 않는다 |

`ahead 5` 의 대가: 지연 375 → 312 ms, 여유 (5−1)×62.5 = 250 − C ≈ 178~218 ms.
지금 최악 리필 갭이 33 ms 이므로 감당 범위로 보인다.

### 12.10 `QUEUE_AHEAD` 5 — 적용은 됐고, 큰 정체는 안 없어졌다 (2026-09-09)

```
queue ahead 5, helper priority off (0 raised)
512 buffers; worst wait 94 ms, worst submit 490 ms at 24.101 s (buffer 363)
unpaused (first song) at 13.093 s, buffer 191
submit ms  <0.5:70  <1:326  <2:62  <5:6  <25:15 <100:14 <250:7 >=250:12
33 slow submission(s) over 25 ms
refill gap ms  <25:511  나머지 0,  worst 15 ms
```

`queue held` 이 16건 전부 **4** 로 바뀌었다 — 스위치는 확실히 먹었다.
그런데 330 / 336 / 361 / 270 / 295 / 291 / 388 / 405 / 334 / 369 / **490** ms 가
그대로 나온다.  사용자 청취도 *"이전과 버벅이는 포인트가 비슷하다"*.

**승인 검사 가설이 약해졌다.**  보유 4 에서 시작하면 `3*4 = 12`, 상한 15 에
한 칸 여유가 있다.  libsound 가 회수 못 한 완료를 하나 더 세도 15 로 아직
`> 15` 가 아니다.  둘이 밀려야 걸리는데 그렇게 자주 일어날 일이 아니다.

**비율 비교는 불가능하다 — 내 계측의 한계다.**  두 판의 길이가 다르고
(84.4초 vs 32.0초), 느린 제출 표가 **16칸에서 잘린다**.  겹치는 0~29초
구간에서 두 판 모두 16건에서 끊겼으므로 비율을 비교할 수 없다.
슬롯을 64로 늘리고 실행 길이를 리포트에 넣어야 한다.

**확실해진 것 하나**: 리필 갭 최악 **15 ms**, 512개 전부 25 ms 미만.
콜백 경로는 이제 완전히 무죄다.

**게임을 더 태우지 않는다.**  조건은 벤치에서 재현할 수 있다 —
`sndslack` 에 mode 4 를 넣었다: 백엔드와 같은 기하(2756 프레임)로 무음을
제출하며 **`SNDStartPlaying` 을 매 호출 계측**하고, `SNDSLACK_DISK=<dir>`
로 디렉터리를 통째로 반복해 읽는 스레드를 띄운다.  네 팔(디스크 없음 /
디스크 / 디스크+ahead 5 / 디스크+배경 스레드 승격)을 사람 없이 돌린다.

부수 발견: 이 libc 에는 **`putenv` 가 없다**(`openstep-missing-shell-tools`
계열).  전역 플래그로 우회했다.

### 12.11 벤치 재현 시도 — 디스크도, 큐 고갈도 아니다 (2026-09-09)

게임을 더 태우지 않기 위해 `sndslack` 에 mode 4 를 넣었다: 백엔드와 같은
기하(2756 프레임, 44100, 무음)로 제출하며 **`SNDStartPlaying` 을 매 호출
계측**하고, `SNDSLACK_DISK=<dir>` 로 디렉터리를 통째로 반복해 읽는 스레드를
띄운다.  전부 사람 없이 돈다.

| 팔 (30초) | 25 ms 초과 | 최악 |
|---|---|---|
| ahead 6, 디스크 없음 | **0 / 484** | — |
| ahead 6, `/usr/lib` 반복 읽기 | 1 / 483 (0.2%) | 60 ms |
| ahead 5, 디스크 | **0 / 483** | — |
| ahead 6, 디스크, **모든 스레드 18 로 승격** | **7 / 465 (1.5%)** | **986 ms** |

**디스크 부하만으로는 재현되지 않는다.**  게임은 14.6%, 벤치는 0.2%.
같은 기하인데 두 자릿수 차이다.

큐 고갈 가설도 기각했다.  mode 2 로 정체를 주입해:

| 주입 | 큐(375 ms)가 비는가 | 25 ms 초과 제출 |
|---|---|---|
| 100 ms × 20회마다 | 아니오 | 1 / 645 (0.2%) |
| **500 ms** × 20회마다 | **예** | **0 / 544** |

큐를 완전히 비워도 다음 `SNDStartPlaying` 은 빨랐다.  libsound 가 장치를
놓았다 다시 잡는 "이음매" 는 원인이 아니다.

**남은 차이는 우선순위다.**  네 팔 중 유일하게 정체가 난 팔이 스레드를
**18** 로 올린 팔이고, 게임의 오디오 스레드도 18 이다 — 우리가 B2 로 넣은
값이다.  다만 그 팔은 *모든* 스레드를 올렸으므로 깨끗한 시험이 아니다.
`SNDSLACK_BOOST_SELF_ONLY=1` 로 **제출 스레드만** 올려 게임과 같은 모양으로
(오디오 18, libsound 응답 스레드 0) 다시 네 팔:

| 팔 (30초, ahead 6) | 25 ms 초과 | 최악 |
|---|---|---|
| 우선순위 10, 디스크 | 0 / 484 | — |
| **우선순위 18, 디스크** | 1 / 484 (0.2%) | 60 ms |
| 우선순위 18, 무부하 | 0 / 484 | — |
| 우선순위 12, 디스크 | 1 / 480 (0.2%) | 334 ms |

**우선순위만으로도 재현되지 않는다.**  986 ms 가 났던 팔은 *모든* 스레드를
올린 팔이었고, 제출 스레드만 올리면 정상이다.

#### 재현 실패 자체가 결과다

| | 25 ms 초과 비율 |
|---|---|
| **게임 (ahead 6)** | **14.58%** |
| **게임 (ahead 5)** | **6.45%** |
| 벤치, 어떤 팔이든 | **0.00 ~ 0.21%** |

같은 기하·같은 라이브러리·같은 기계인데 두 자릿수 차이다.  기각된 것:
**디스크 부하**, **큐 고갈**, **오디오 스레드 우선순위**, **승인 경계**.

남은 차이는 게임에만 있는 것들이다 — **윈도서버 왕복**(소프트웨어 present 가
메인 스레드에서 32→24 bpp 변환 후 `[view displayRect:]`,
`SDL_openstepvideo.m:2094`), 디스플레이 드라이버의 VRAM 블릿, AppKit 이벤트
루프.  `sndslack` 에는 창이 없다.  그래픽 경로가 커널에서 사운드 응답을
밀어내는지는 **아직 안 쟀다**.

세 팔 모두에서 **초반 1초 안쪽에 큰 정체 하나**가 공통으로 보인다
(0.640 / 0.871 / 1.494 초).  게임의 0.655 / 1.179 / 1.509 와 같은 자리다.
장치를 막 세운 직후의 무언가이며, 이것만은 벤치에서 재현된다.

#### 그래서 무엇을 할 것인가

구조적 해법은 이미 후보에 있다 — **D 안: libsound 우회.**  제출마다
`SNDStartPlaying` 을 부르지 않고 `snddriver_*` 스트림 하나에 써 넣으면
정체가 나는 그 호출 자체가 사라진다.  초당 16회의 노출이 0 이 된다.
크기가 크므로 별도 계획이 필요하다.

부수 발견: 이 libc 에는 `putenv` 가 없다.  그리고 **`SDL_OPENSTEP_HELPER_PRIORITY`
는 켜지 말 것** — 벤치에서 986 ms 를 만들었다.  기본값 off 로 둔다.

### 12.12 원인 확인 — **디스크 I/O 가 `SNDStartPlaying` 을 막는다** (2026-09-09)

사용자 가설: *"그리기가 문제가 아니라 그리기 위해 HDD 에서 데이터를 로딩할
때 음악이 멈추는 것 아닌가."*  **맞았다.  그리고 §12.11 의 디스크 팔은
틀린 시험이었다.**

`/usr/lib` 를 반복해서 읽으면 첫 패스 이후로는 **전부 버퍼 캐시**에서
나온다 — 기계는 메모리를 복사했을 뿐 디스크를 돌리지 않았다.  raw 디바이스
(`/dev/rhd0a`)는 캐시를 타지 않으므로 순차 읽기가 진짜 헤드 이동이다.
읽기 전용이며 아무 것도 쓰지 않는다.

| 부하 | 25 ms 초과 제출 |
|---|---|
| 디렉터리 반복 읽기 (캐시) | 1 / 483 = **0.2%** |
| **raw 디스크 순차 읽기** | **25 / 642 = 3.9%** |

값이 26.2 / 26.3 / 26.5 / 52.1 / 52.4 / 53.1 / 53.6 / 185.1 ms — **26 ms
배수 근처**에 몰린다.  드라이버의 어떤 양자로 보인다.

이것으로 세 가지 체감이 한꺼번에 설명된다: "첫 음악 시작할 때"(곡 로딩),
"종료화면 불러올 때"(그래픽 로딩), "가끔 디스크 부하 걸릴 때".

기각된 다른 후보들도 함께 정리한다.

| 후보 | 시험 | 25 ms 초과 |
|---|---|---|
| 부하 없음 | | 0 / 484 |
| 캐시된 파일 읽기 | | 1 / 483 |
| 큐 고갈 (500 ms 정체 주입) | | 0 / 544 |
| 오디오 스레드 우선순위 18 | | 1 / 484 |
| **그리기** (25 fps 전체화면 소프트 present) | `sndgfxload` | **0 / 632** |
| 포크된 스레드 + 18 + 그리기 | | 4 / 633 (900 ms 1건) |
| **raw 디스크 읽기** | | **25 / 642** |

`gcds` 로 콘솔 세션에서 돌리므로 GUI 프로그램도 사람 없이 실행된다
(telnet 은 `DPS Error: Can't connect to server`).

#### 우리가 할 수 있는 것 — 손잡이는 하나, 방향은 둘

디스크를 빠르게 만들 수는 없다.  libsound 는 **동시에 시작된 사운드를 6개**
로 제한하므로 큐에 더 담으려면 **사운드를 길게** 하는 수밖에 없다.  그리고
같은 손잡이가 정체가 나는 호출의 **횟수**도 줄인다.

| 버퍼 × 6 | 지연 | 여유 (C=32~72) | `SNDStartPlaying` 호출 |
|---|---|---|---|
| **62 ms (현재)** | 375 ms | 240~280 ms | 16 /초 |
| 83 ms | 500 ms | 345~385 ms | 12 /초 |
| 100 ms | 600 ms | 428~468 ms | 10 /초 |
| 125 ms | 750 ms | 553~593 ms | 8 /초 |

게임에서 관측된 정체는 최대 508 ms 였다.  여유를 350~470 ms 로 올리면
거의 다 흡수된다.  **대가는 지연**이고, 지연은 효과음이 화면보다 늦는
것으로 나타난다 — water1(전략)은 견디지만 glquake 는 아프다.

`SDL_OPENSTEP_BUFFER_MS` 를 넣었다(기본값은 62 ms 그대로).

**`ahead` 는 6 이 최적이다.**  고정된 지연에서 여유는 `(ahead-1)/ahead` 에
비례하므로 클수록 좋고, 호출 횟수는 `ahead` 와 무관하게 버퍼 길이만으로
정해진다.  그러니 손잡이는 버퍼 길이 하나뿐이고, 양쪽 이득(여유·호출 감소)이
같은 방향으로 움직인다.  §12.10 에서 `ahead` 를 5 로 내려 본 것은 이 관점에서
**여유만 깎고 호출은 그대로 둔** 잘못된 방향이었다.

#### 순차 비교는 무효였다 — 디스크는 상수가 아니다

첫 시도는 62 → 83 → 100 → 62 순으로 40초씩 돌렸다.  **같은 62 ms 대조군이
36/642(5.6%)와 0/644(0.0%)로 갈렸다.**  부하가 회차마다 다르므로 순서대로
비교하면 아무 것도 말할 수 없다.  62/83/100 을 **번갈아 3라운드** 돌려
드리프트가 모든 팔에 똑같이 걸리게 다시 잰다.

그리고 로그가 자기 조건을 잘못 적고 있었다: mode 4 의 요약 줄이
`SNDSLACK_DISK` 만 보고 `SNDSLACK_RAW` 는 안 봐서, raw 부하로 돌린 판이
`disk off` 라고 인쇄됐다.  둘 다 적도록 고쳤다.

### 12.13 닫는 정리 (2026-09-09)

사용자 판정: **62 ms 가 훨씬 낫다.  그 상태에서 잠시 끊기는 것을 빼면 꽤
깔끔하다.  오프닝에서 한 번, 종료 후 종료화면 로딩에서 한 번.**

이 지점을 `2.32.10-openstep.4` 로 릴리스한다.

#### 남긴 것

| | |
|---|---|
| `SDL_Delay(0)` 재귀 | 스핀락 대체 경로가 타이머 락을 다시 잡던 것.  스택 소진 |
| 프라이머 + `freq/16` × 6 | 같은 지연 375 ms, 여유 85~90 → **220~280 ms** |
| 블로킹 뮤텍스 | 무한 `cthread_yield` 대신 `condition_wait` |
| 오디오 스레드 우선순위 18 | 스텁이던 `SDL_SYS_SetThreadPriority` 구현 |
| 사운드 버퍼 풀 | 초당 16회 malloc/free 제거.  제출 안 malloc 854 → 19 us |
| 계측 (기본 꺼짐) | `SDL_OPENSTEP_AUDIO_REPORT=1` |

#### 재고 버린 것 — 다시 시도하지 않도록

| 안 | 결과 |
|---|---|
| `QUEUE_AHEAD` 6 → 5 | 큰 정체 그대로.  여유만 깎는 방향이었다 |
| 버퍼 83 / 100 ms | 정체 빈도 동일, 지연만 늘어 **귀로 더 나쁨** |
| libsound 배경 스레드 승격 | **훨씬 나쁨** — 한 제출에 986 ms |
| 무음 시 합성 정지 (water1) | 비트 동일 실패 — 감쇠 오퍼레이터가 −1, 안 눌린 하이햇 위상이 스네어를 정함 |
| water1 데이터 프리로드 | 끊긴 **뒤** 회복이 더 나빠짐(귀 판정), 4초 연속 정체 |
| 백엔드 더티 사각형 present | 좌표 미검증 상태라 되돌림.  §12.14 |

#### 남은 결함과, 왜 여기서 못 고치는가

제출의 약 5%가 300~500 ms, 전부 `SNDStartPlaying` 안, CPU 0.
**진짜(캐시 안 탄) 디스크 읽기**가 있을 때만 재현된다 — raw 디바이스나
무작위 오프셋 파일 읽기.  캐시된 읽기·그리기·큐 고갈·우선순위로는 재현
안 된다.  제출은 out-of-line Mach 메시지라 디스크 읽기가 잡고 있는 경로를
지난다.  버퍼마다 libsound 를 부르지 않는 것 말고는 방법이 없고, 그건
다른 라이브러리다.

#### 내가 틀렸던 계측 (같은 함정을 다시 밟지 않도록)

1. **최댓값만 남겨 197건을 1건으로 봤다.**  세 판 연속 "판마다 400 ms 한
   번" 이라고 보고했는데, 히스토그램을 넣자 1351건 중 197건이었다.
2. **`task_info(TASK_EVENTS_INFO)` 가 이 커널에서 `kr 4` 로 실패**하는데
   실패를 0 으로 채워 "페이징 0" 을 한 라운드 내내 믿었다.  64 MB 를
   만지는 프로그램으로 확인했다.  `TASK_BASIC_INFO` 의 CPU 시간도 같다.
3. **벤치가 캐시 때문에 판정관이 못 된다.**  유휴 뒤 첫 실행만 발화하고
   이후는 조용해진다.  "5/5 라운드 재현" 이 6분 뒤 "15라운드 중 2" 가
   됐다.  짧은 A/B 라운드로는 아무 것도 못 가른다.
4. **디렉터리 반복 읽기는 디스크 부하가 아니다.**  두 번째 패스부터 전부
   버퍼 캐시다.  사용자가 짚어 준 뒤에야 raw 디바이스로 바꿨다.
5. **거울 좌표는 시간으로 안 잡힌다.**  §12.14.

### 12.14 화면 출력 — 잰 것과, 되돌린 것

사용자 질문: *"water1 에서 화면 출력 기준으로 개선할 부분은 없을까."*

`sndgfxload` 로 640×400 한 프레임을 분해했다:

| 단계 | ms |
|---|---|
| 서피스에 1 MB 쓰기 | 1.1 |
| 32→24 변환 | 5.4 |
| **`[view displayRect:]` (윈도서버)** | **32.5** |
| water1 의 텍스처 경로 추가분 | +3.1 |
| 합계 | 42.1 |

**윈도서버가 83%**, 그리고 비용은 **면적에 비례**한다: 640×400 38.9 ms,
×200 20.2, ×100 10.4, ×40 4.7 — 행당 0.095 ms + 고정 1 ms.

`OPENSTEP_PresentFramebuffer` 는 손상 사각형을 변환해 놓고
`displayRect:[view bounds]` 로 **창 전체를 다시 그린다** — 계산한 손상을
버린다.  고쳐서 재니 같은 640×400 창에서 40행 밴드가 **5.3 ms**, 전체가
38.9 ms.  **7.3배**다.

**그러나 되돌렸다.**  뷰가 `isFlipped == YES` 이고 표시 비트맵은 bottom-up
이라 두 번 뒤집힌다.  내 첫 구현은 아래에서 위로 가정해 손상 밴드를 거울
위치로 선언했고, 고친 뒤에도 실기에서 **밴드가 보이지 않았다**.  좌표가
틀리면 시간은 똑같이 나오므로(면적이 같다) 어떤 계측도 이걸 못 잡는다.
검증되지 않은 좌표를 릴리스에 넣지 않는다.

그리고 water1 은 어차피 `SDL_UpdateTexture(NULL)` → `RenderCopy(NULL)` 로
**매 프레임 전체 화면**을 내므로, 백엔드만 고쳐서는 이득이 없다.  앱이
바뀐 행만 내야 하고, 그건 원본 프로젝트에서 시작할 일이다.  기록만 남긴다.
