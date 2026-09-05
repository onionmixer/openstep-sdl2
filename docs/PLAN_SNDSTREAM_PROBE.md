# snddriver_stream 이 Intel OPENSTEP 에서 동작하는가 — 탐침

## 왜

SDL 백엔드는 버퍼 하나를 `SNDStartPlaying` 사운드 하나로 넘긴다. 이 구조의
실측 한계:

```
여유(끊김 방지) = (AHEAD-1) x 버퍼      250 ms 는 되고 125 ms 는 안 됨 (측정)
지연(체감)      =  AHEAD    x 버퍼
=> 지연 = 여유 + 버퍼 하나.  여유 250 을 지키는 최소 지연은 freq/16 의 312 ms.
```

187 ms(freq/16, AHEAD 3)는 지연은 좋았으나 quake 에서 끊겼다(NFS 교란 제거
후에도). 끊김은 드라이버 위 — 정지 요청 64회 미만, FIFO 에러 0 — SoundKit
완료 통지 사슬의 지연 변동이다.

낮은 지연과 무끊김을 **둘 다** 가지려면 사운드 경계와 사운드마다의 완료
핸드셰이크 자체를 없애야 한다. SoundKit 아래층의 스트림 API 가 그것이다:

```
SDL 백엔드 (여기를 나중에 다시 씀)
  지금:  SNDStartPlaying  사운드 하나 = 버퍼 하나        performsound.h
  제안:  snddriver_stream_setup + start_writing 연속     snddriver_client.h
    soundd / IOAudio (NeXT, 소스 없음)
      IntelAC97 드라이버 (변경 없음)
```

**미확인 전제**: 이 API 는 NeXT 하드웨어(DSP 있는 68k) 시절 문서이고, 저장소에
쓰는 곳이 없다(OnionPlayer 도 `SNDStartPlaying`). Intel 의 IOAudio 위에서
`SNDDRIVER_STREAM_TO_SNDOUT_44` 가 열리는지부터 모른다. 이 탐침은 그것만
확인한다. **백엔드 재작성은 이 결과 뒤의 별개 계획이다.**

## 근거 — NeXT 3.3 Reference (미러에 있음)

`ref/openstep/nextdev-doc/.../16_Sound/DriverFunctions/DriverFunctions.rtf`
와 `SoundFunctions.rtf`. 헤더 추측이 아니라 문서로 확정한 것:

| 항목 | 문서가 말하는 것 |
|---|---|
| 포트 | `SNDAcquire(SND_ACCESS_OUT, prio, preempt, 0, NULL, NULL, &dev, &owner)`. `dev` 에 `PORT_NULL` 을 주면 만들어 준다. timeout/negFun/arg 는 **미사용** |
| 스트림 | `snddriver_stream_setup(dev, owner, SNDDRIVER_STREAM_TO_SNDOUT_44, sampleCount, 2, low, high, &protocol, &stream)`. `protocol` 은 `SNDDRIVER_DSP_PROTO_RAW` 로 초기화 |
| 버퍼 | `sampleCount` 가 **전송 버퍼(sound-out DMA 버퍼) 크기**를 정한다. 최대 `vm_page_size` 바이트. 관례는 `vm_page_size/2` 샘플 = 4096 → 8192 B. 개수는 `snddriver_set_sndout_bufcount(dev, owner, n)`, 기본 4 |
| 데이터 | "DAC 는 16-bit interleaved-stereo 를 기대한다", `sampleSize = 2`. 바이트 순서는 문서에 없음 — SDL 백엔드가 SoundKit 에 S16MSB 로 넘겨 동작하므로 **MSB** 로 시작하고 귀로 확인 |
| 쓰기 | `start_writing(stream, data, nsamples, tag, preempt, dealloc, msgStarted, msgCompleted, msgAborted, msgPaused, msgResumed, msgUnderrun, reply)`. sound-out 은 nsamples 임의. 큐잉 후 데이터는 **write-protect** 됨 — 완료 전 재사용 금지 |
| 언더런 | `msgUnderrun` = TRUE 면 드라이버가 못 따라갈 때 **메시지로 알려준다.** 추측이 아니라 세는 관측치 |
| 회신 | `port_allocate` 로 reply 포트 → `msg_receive` 루프 → `snddriver_reply_handler(msg, &handlers)` → `completed(arg, tag)` 등 |
| 정리 | `snddriver_stream_control(stream, 0, SNDDRIVER_ABORT_STREAM)` (tag 0 = 전부) → `SNDRelease` |
| low/highWater | 바이트 단위. 드라이버가 wired 로 유지하려는 최소/최대 — 페이징 정책이지 재생 흐름 제어가 아님 |

## 탐침이 답할 것 — 순서대로, 하나가 실패하면 거기서 멈춘다

1. `SNDAcquire(OUT)` 이 0 을 돌려주는가
2. `stream_setup(TO_SNDOUT_44, 4096, 2, ...)` 이 0 을 돌려주는가 — **Intel 에 이 경로가 있는가의 핵심**
3. 사인파를 `start_writing` 으로 계속 밀어 넣으면 소리가 나는가, 형식(MSB/스테레오)이 맞는가 — 귀
4. 60초 동안 `completed` 가 쓰기 수만큼 오고 `underrun` 이 0인가 — 카운터
5. **드라이버 카운터**: 정지 요청이 0 에 가까운가 (SoundKit 이 사운드 경계마다 하던 stop/start 가 사라지는가)
6. `set_sndout_bufcount` 로 2·4·8 을 주면 체감 지연이 따라 바뀌는가 — 지연 레버 확인

## 탐침 설계

`openstep-water1/tools/sndstream-probe.c` (C89, cc 2.7.2.1):

- 사인파 440 Hz, 44.1 kHz, 스테레오 16-bit **MSB**, 청크 = 4096 샘플(2048 프레임,
  46.4 ms) — 전송 버퍼와 같은 크기
- 청크 버퍼 **K개 링**(K = 4): 모두 먼저 `start_writing`, 이후 `completed(tag)`
  마다 그 슬롯을 다시 채워 다시 쓴다 → 항상 K−1 개가 큐에 있다. `dealloc = 0`,
  버퍼는 재사용 (write-protect 는 완료 후 풀림)
- `msgCompleted = 1`, `msgUnderrun = 1`, `msgAborted = 1`, 나머지 0
- 회신 루프에서 `completed` 간격을 `gettimeofday` 로 재 max/히스토그램(>50/100/150 ms)
- 인자: 초(기본 60), bufcount(기본 4 = 손대지 않음)
- 끝: ABORT → SNDRelease → 요약 출력 (쓴 청크 수, completed 수, underrun 수,
  기대 청크 수 대비 부족분 — tonectl 과 같은 지표)

링크: tonectl 과 같은 줄(`-framework SoundKit` 포함). `snddriver_*` 심볼이
거기 없으면 그 자체가 결과다.

## 위험

| 위험 | 대응 |
|---|---|
| `SNDAcquire` 가 사운드 자원을 독점해 다른 앱을 막음 | 프로세스 종료 시 포트 소멸로 풀림. 탐침은 60초 후 `SNDRelease` |
| 탐침이 죽어 소유권이 남음 | Mach 포트 죽음으로 회수. 그래도 다음 `SNDAcquire` 실패 시 재부팅 외 방법 없을 수 있음 — **게임·플레이어 안 켠 상태에서 실행** |
| 형식 오해(LSB/모노) | 잡음·반속으로 즉시 들림. 인자로 MSB/LSB 토글 |
| soundd 가 이 경로를 Intel 에서 안 지원 | 2번에서 에러로 끝남 — 그것이 답. 재작성 계획 폐기 |
| 완료 메시지 없이 큐만 소진 | underrun 메시지 또는 소리 끊김으로 관측. 60초 타임아웃 |

## 검증 지표

tonectl 과 같은 "기대 청크 수 대비 부족분" + `underrun` 메시지 수 +
드라이버 `deferred` (임계값-16 빌드는 다음 재부팅에 적용되므로 지금은 64 기준).
