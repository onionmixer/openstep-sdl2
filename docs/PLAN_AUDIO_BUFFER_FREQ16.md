# SDL 백엔드 버퍼를 freq/8 에서 freq/16 으로

## 왜

AC97 드라이버 조사(Stage 9~11)로 끊김과 밀림은 해결됐고, 남은 것은 **일정한
지연 ~0.5 s** 다. 그 지연의 가장 큰 항은 드라이버가 아니라 이 백엔드의 큐다:

| 버퍼 | 프레임 | 바이트 | 버퍼 1개 | 큐 (AHEAD 3) | 최악 위상 예비 (AHEAD−1) |
|---|---|---|---|---|---|
| freq/8  | 5512 | 22048 B | 125.0 ms | 375.0 ms | **250.0 ms** |
| freq/16 | 2756 | 11024 B |  62.5 ms | 187.5 ms | **125.0 ms** |

`QUEUE_AHEAD` 는 3 그대로 두고 버퍼만 반으로 줄이면 큐 지연이 375 → 187 ms.
`OpenDevice` 의 주석이 이미 이 절충을 적어두었다: "freq/8 with QUEUE_AHEAD 3
holds 250 ms against a frame-long SDL_LockAudio". 이 변경은 그 예비를
**125 ms** 로 줄인다.

그 예비가 지켜주는 것은 정확히는 "메인 스레드가 `mixer_lock` 을 쥐는 시간"이
아니라 **생산 전체 지연**이다: `SDL_RunAudio` 는 콜백을 `mixer_lock` 안에서
돌리고(731-738) 그 뒤 `PlayDevice`→`WaitDevice` 를 부른다(786-789). 최악 위상은
`SNDWait` 복귀 직후 다음 `SDL_LockMutex` 직전이고, 그때 남은 두 요청(FCFS,
`performsound.h:37`)이 재생되는 동안 콜백·리샘플·`SNDStartPlaying`·재스케줄이
전부 끝나야 한다. 즉 lock 허용 시간 N 은 `125 ms − (그 나머지)` 이고, 그
나머지는 **미측정**이다. 그래서 tonectl 에 lock 유지 sweep 이 필요하다 — 지금의
tonectl 은 CPU·디스크만 걸고 `SDL_LockAudioDevice` 는 잡지 않는다.

## 여유가 있다는 근거 — 실측

`openstep-water1/tools/audio-control-tone.c`(tonectl): water1 과 같은 사양
(49716 Hz, 스테레오, 1024 프레임)으로 90초씩:

| 조건 | 콜백 부족 | 마른 시간 |
|---|---|---|
| 부하 없음 | 0.11 % | 99 ms |
| CPU 부하 | 0.11 % | 95 ms |
| CPU + 디스크 (초당 1,269회 읽기) | 0.11 % | 95 ms |

부하를 걸어도 오디오 스레드가 밀리지 않았다 — **단, 이것은 125 ms 버퍼로 잰
것이다.** 62.5 ms 버퍼에서는 스레드가 2배 자주 깨어나야 하고, 한 번의 정지가
125 ms 를 넘으면 큐가 마른다. 그래서 검증 1번이 tonectl 재실행이다.

## 고칠 것 — 상수 하나

`port/openstep/src/audio/openstep/SDL_openstepaudio.m:48`:

```c
_this->spec.samples = (Uint16)(_this->spec.freq / 8);    /* 지금 */
_this->spec.samples = (Uint16)(_this->spec.freq / 16);   /* 변경 */
```

그리고 43-47행 주석의 숫자를 새 값으로 고친다. `OPENSTEP_AUDIO_QUEUE_AHEAD` 는
3 유지.

water1 의 콜백 비율: 장치 버퍼 5512 → 2756 프레임이므로 앱 콜백(1024 @49716)
6.07 → 3.03 회/버퍼. SoundKit 에는 초당 8 → 16 개의 사운드
(`SNDStartPlaying`), 각 11,024 B.

## 무엇을 다시 빌드해야 하나 — 이것이 실제 비용

SDL 은 **정적 아카이브**다. 바꾸면 그것을 링크한 모든 것을 다시 링크해야 한다:

| 소비자 | SDL 위치 | 재링크 |
|---|---|---|
| water1 | `/LocalDeveloper/Libraries/libSDL2.a` (.pkg 설치본) | 필요 + pkg 재설치 또는 직접 복사 |
| quake (build-openstep-quake, build-glquake) | `/me/SDL20/build/SDL-2.32.10-openstep/libSDL2.a` | 필요 |
| OnionPlayer | SDL 안 씀 | 무관 |

SDL 재빌드 흐름: `stage-openstep.csh`(**/ndrv NFS 에서** `/me/SDL20` 로 복사)
→ `prepare-openstep-tree.csh` → 게이트들 → `build-sdl2-openstep-release-archive.csh`
→ `/me/SDL20/build/.../libSDL2.a`. **`/ndrv` 가 지금 마운트돼 있지 않다**, 그리고
마운트 순서 규칙(mount 먼저, gcdsd 나중, 어기면 EBUSY)이 있으므로 gcdsd 재시작이
따라올 수 있다. 재부팅은 필요 없다.

지름길(오디오 백엔드 오브젝트 하나만 교체해 `ar` 로 재삽입)은 택하지 않는다 —
release 스크립트가 OPENSTEP `ar` 의 인덱스/경로명 함정을 명시하고 있다.

## 단계 — 한 번에 /16 으로 가지 않는다

codex 권고를 채택한다: **freq/10 → 검증 → freq/16.** /10 은 예비 200 ms, 10
req/s 로 /8 과 /16 의 중간이며, 실패해도 어느 쪽 가정이 틀렸는지 알 수 있다.
최종 목표는 사용자가 요청한 /16 이다.

## 검증 순서

1. **tonectl 재실행** (새 SDL 로 재링크) — 부하 0/1/2 에서 부족분이 여전히
   0.1 % 대인가. 그리고 **새 모드 3: 메인 스레드가 `SDL_LockAudioDevice` 를
   N ms(20/50/80/120) 씩 주기적으로 쥔다** — 예비가 실제로 몇 ms 의 lock 을
   견디는지 sweep. 아니면 여기서 멈춘다
2. quake 재링크 → 청감: 지연이 줄었는가, 끊김이 돌아오지 않았는가
3. 드라이버 카운터(`executed`) — 16/s 사운드 경계에서 마른 사건이 늘지 않았는가
4. water1 재링크 → 같은 판정

## 위험

| 위험 | 대응 |
|---|---|
| 예비 125 ms 를 넘는 메인 스레드 정지 | tonectl 가 먼저 잡는다. 실기에서 정지 원인은 디스크·렌더링이며 실측 0.11 % |
| SoundKit 부하 2배 (16 sounds/s) | 각 사운드가 절반 크기라 바이트/s 는 같다. 드라이버 stop/start 는 큐가 마를 때만 |
| 끊김이 돌아온다 | 상수 하나라 되돌리기는 재빌드 한 번. 중간값은 freq/10 (100 ms 버퍼, 예비 200 ms, 10 req/s) 또는 freq/12 (83.3 ms, 예비 166.7 ms). **앞서 적었던 'freq/12 = 94 ms' 는 오산이었다** |
| /ndrv 마운트가 gcdsd 와 충돌 | 마운트 순서 규칙대로. 실기 상태 변경이므로 **사용자 허가 후** |

## codex 검토 판정 (계획 단계, 코딩 전)

| 주장 | 검증 | 판정 |
|---|---|---|
| freq/12 는 94 ms 가 아니라 83.3 ms | python 재계산 | ✅ **채택 — 내 오산** |
| 예비 125 ms 는 lock 시간이 아니라 생산 전체 지연의 상한 | SDL_audio.c 731-789 (앞서 직접 읽음) | ✅ 채택 — 표현 정정 |
| tonectl 은 mixer_lock 을 재지 않는다 | audio-control-tone.c 직접 작성 — 사실 | ✅ 채택 — lock sweep 모드 추가 |
| /10 → /16 단계적으로 | 판단 | ✅ 채택 |
| have.samples 는 1024 유지 (allowed_changes 0) | 이번 세션 실측 `have == want` | ✅ 사실 |
| quake 는 11025/S16/stereo/512 요청, MSB 거부 후 재오픈 | `snd_dma.c:66-67`, `snd_sdl.c:82-83, 98-110` 직접 확인 | ✅ 사실 — quake 의 `shm->samples` 는 불변, SoundKit 경계만 8→16/s |
| stage-openstep.csh 는 $1 로 NFS 없이 가능 | 직접 확인함 | ✅ 사실 (다만 소비자 quake/water1 소스 문제는 별개) |
| SoundKit 사운드당 고정비는 저장소로 확인 불가 | 사실 | ⚖️ 미확정 — 실측으로 판정 |
