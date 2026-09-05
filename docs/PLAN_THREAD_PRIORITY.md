# SDL_SYS_SetThreadPriority 를 실제로 구현한다

## 왜

SDL 코어는 오디오 스레드를 만든 직후 최고 우선순위를 요청한다:

```c
/* upstream/SDL-2.32.10/src/audio/SDL_audio.c:691 */
SDL_SetThreadPriority(SDL_THREAD_PRIORITY_TIME_CRITICAL);
```

이 포팅은 그 요청을 버린다:

```c
/* port/openstep/src/thread/openstep/SDL_systhread.c */
int SDL_SYS_SetThreadPriority(SDL_ThreadPriority priority)
{
    (void)priority;
    return SDL_Unsupported();
}
```

실측으로 확인했다 (`test/openstep/openstep-thread-priority-probe.c`):

```
main     policy=1 base=10 max=18 cur=10
cthread  policy=1 base=10 max=18 cur=10      <- SDL 오디오 스레드가 될 것
```

**완전히 같다.** 단일 프로세서에서 게임 메인 스레드가 화면을 그리고 디스크를
읽는 동안 오디오 스레드에는 아무 우위가 없다.

이것이 water1 의 끊김과 어떻게 이어지는지는
`openstep-water1/docs/PLAN_AUDIO_DEADLINE.md` 에 있다. 요약하면: 커널 AC97
드라이버 쪽 이음매를 없애도(정지의 54.7% 가 하드웨어에 도달하지 않게 만들었다)
끊김은 그대로였고, 남은 카운터가 **파이프라인이 46 ms 넘게 마르는 사건이
1.95 초에 한 번** 일어난다고 말한다. 없는 오디오는 드라이버가 만들 수 없다.

## 측정으로 확정한 것 (추측 없음)

### 허용 범위

```
ask  0 -> KERN_SUCCESS   base=0
ask  5 -> KERN_SUCCESS   base=5
ask 10 -> KERN_SUCCESS   base=10
ask 12 -> KERN_SUCCESS   base=12
ask 18 -> KERN_SUCCESS   base=18
ask 25 -> KERN_FAILURE   (거절)
ask 31 -> KERN_FAILURE   (거절)
```

검사는 `priority <= max_priority` 다. 루트로 실행해도 `max_priority`(18)를
넘지 못하고, 그 아래로는 자유롭다.

### 방향 — 큰 수가 높은 우선순위

Mach 문헌은 두 규약을 다 쓰므로 재는 수밖에 없었다. 두 스레드를 각각 다른
우선순위로 4초간 돌려 반복 횟수를 셌다
(`test/openstep/openstep-thread-priority-direction.c`):

| 실행 | main | child | 결과 |
|---|---|---|---|
| A | 0 (18.1%) | 18 (81.9%) | 18 이 이김 |
| B | 18 (78.8%) | 0 (21.2%) | 18 이 이김 |
| C | 10 (54.7%) | 10 (45.3%) | 대조군 — 내재 편향 없음 |

A 와 B 에서 18 이 자리를 바꿔가며 이겼으므로, 이긴 것은 스레드 역할이 아니라
번호다. **큰 수 = 높은 우선순위.** 반대로 매핑했다면 오디오 스레드가 가장 먼저
굶는 스레드가 됐을 것이다.

### 실제로 쓸 조합의 효과

메인을 10 에 두고 상대를 바꿔가며 (3초):

| 상대 | 메인 % | 상대 % | 배수 |
|---|---|---|---|
| 9 | 54.7 | 45.3 | 0.83x |
| 10 | 54.7 | 45.3 | 0.83x |
| 12 | 45.5 | 54.5 | 1.20x |
| 14 | 35.3 | 64.7 | 1.84x |
| 18 | 27.8 | 72.2 | 2.60x |

두 가지가 중요하다.

1. **9 와 10 은 구분되지 않는다** (둘 다 45.3%, 대조군과 같은 값). 아래에서
   NORMAL 을 `max/2`=9 로 매핑하는데, 그것이 의미 있는 강등이 아님을 주장이
   아니라 측정으로 확인한 셈이다.
2. **18 에서도 메인이 27.8% 를 계속 받는다.** Mach 는 절대 선점이 아니라
   가중치로 동작한다 — 오디오를 천장까지 올려도 게임이 멈추지 않는다. 이건
   안전 측면에서 이 계획의 전제다.

### `SDL_SetThreadPriority` 호출처 전수 (표본 아님)

"오디오 스레드에만 건다"고 먼저 썼는데, 전수로 세어보니 근거가 달랐다.
후보는 여섯이고 다섯을 각각 다른 이유로 제외해야 한다.

| 호출처 | 값 | 이 포팅에서 |
|---|---|---|
| `SDL_audio.c:691` | TIME_CRITICAL | **도달함** — 재생 오디오 스레드 |
| `SDL_audio.c:823` | HIGH | 도달 안 함 — `SDL_assert(device->iscapture)` 이고, 이 백엔드는 capture 를 `SDL_Unsupported()` 로 거절한다 (`SDL_openstepaudio.m:33`) |
| `SDL_hidapi_rumble.c:64` | HIGH | 도달 안 함 — 이 포팅은 `src/hidapi/SDL_hidapi.c` 만 컴파일한다 (`build/compile-sdl-hidapi-fallback-gate.csh:14`). joystick/hidapi 는 빌드에 없다 |
| alsa / pulseaudio / coreaudio | LOW/HIGH | 도달 안 함 — 해당 백엔드가 없다 |

즉 결론("재생 오디오 스레드 하나")은 유지되지만, 그것은 **다섯 개를 각각
확인해 제외한 결과**이지 자명한 사실이 아니었다. quake 와 OnionPlayer 도 같은
경로를 타므로 영향은 "오디오 스레드가 우선순위를 얻는다" 하나뿐이다.

### 시계 (같은 probe 에서)

```
gettimeofday 최소 관측 step   5 us
호출 비용                     4.598 us
```

125 ms 마감을 재기에 충분하고, 초당 125회 호출해도 0.057% CPU 다. 나중에
계측을 붙이더라도 오염이 문제되지 않는다는 근거다.

## 고칠 것

`port/openstep/src/thread/openstep/SDL_systhread.c` 의
`SDL_SYS_SetThreadPriority` 를 구현한다.

```c
int SDL_SYS_SetThreadPriority(SDL_ThreadPriority priority)
{
    struct thread_sched_info	si;
    unsigned int		cnt = THREAD_SCHED_INFO_COUNT;
    thread_t			th  = (thread_t)thread_self();
    int				want;

    if (thread_info(th, THREAD_SCHED_INFO, (thread_info_t)&si, &cnt)
	    != KERN_SUCCESS)
	return SDL_SetError("...");

    switch (priority) {
    case SDL_THREAD_PRIORITY_LOW:           want = si.max_priority / 4;      break;
    case SDL_THREAD_PRIORITY_HIGH:          want = (si.max_priority * 3) / 4; break;
    case SDL_THREAD_PRIORITY_TIME_CRITICAL: want = si.max_priority;          break;
    default:                                want = si.max_priority / 2;      break;
    }

    if (thread_priority(th, want, FALSE) != KERN_SUCCESS)
	return SDL_SetError("...");
    return 0;
}
```

### 왜 `max_priority` 를 기준으로 잡나

상수 10/18 을 박아넣지 않는 이유는, 그 값이 이 머신에서 관측된 것이지 규약이
아니기 때문이다. `max_priority` 는 커널이 이 스레드에 대해 말해주는 실제
천장이므로, 다른 설치본에서 천장이 다르면 매핑이 따라간다.

`set_max` 는 `FALSE` 다. `TRUE` 로 천장 자체를 올리려면 processor set 포트가
필요하고, 그건 이 계획의 범위 밖이다. 그리고 필요도 없다 — 18 로 이미
2.60배다.

### NORMAL 이 `max/2` 인 것에 대해

측정된 기본 base 는 10 이고 `max/2` 는 9 다. 위 표에서 9 와 10 이 구분되지
않으므로 실질적 강등이 아니다. 원래 base 를 기억해뒀다가 복원하는 설계도
가능하지만, 그건 "첫 호출이 아직 손대지 않은 스레드에서 온다"는 가정을 숨은
상태로 들고 다닌다. 숨은 상태보다 측정된 근사가 낫다.

## 검증

1. **호스트 문법 검사** — 이 파일은 타깃에서만 컴파일된다. 빌드 전에
   헤더 경로와 C89 적합성을 확인한다.
2. **probe 재실행** — SDL 을 다시 빌드한 뒤 water1 을 띄우고, 오디오 스레드의
   `base_priority` 가 실제로 18 인지 확인한다. "구현했다"는 "적용됐다"가 아니다.
3. **객관적 A/B** — 귀가 아니라 드라이버 카운터로 판정한다. Stage 9 가 남긴
   `executed` 가 현재 **0.51 /s** 다. 이것이 떨어지면 마른 구간이 줄어든 것이고,
   안 떨어지면 이 가설도 틀린 것이다.
4. **청감** — 마지막에.

## 위험

| 위험 | 대응 |
|---|---|
| 오디오 스레드가 게임을 굶긴다 | 실측: 18 대 10 에서도 메인이 27.8% 를 받는다. 절대 선점이 아니다 |
| 다른 프로젝트(quake, OnionPlayer)가 이 SDL 을 쓴다 | 호출처를 전수로 확인했다 -- 아래 표. 이 포팅에서 도달 가능한 것은 재생 오디오 스레드 하나뿐이다 |
| `thread_info`/`thread_priority` 가 다른 설치본에서 실패 | 실패하면 `SDL_SetError` 로 돌려주고, SDL 코어는 그 반환값을 무시하므로 현행과 같아진다 |
| 방향을 반대로 매핑 | 양방향 + 대조군으로 측정 완료 |

## 이번에 하지 않을 것

- **오디오 스레드 계측 코드** — 이 가설이 맞으면 필요 없다. 틀리면 그때 붙인다.
- **`thread_max_priority` 로 천장 올리기** — processor set 포트가 필요하고,
  18 로 충분하다는 것이 측정됐다.
- **메인 스레드 낮추기** — 오디오를 올리는 것으로 충분하다. 두 개를 동시에
  바꾸면 어느 쪽이 효과를 냈는지 알 수 없다.
