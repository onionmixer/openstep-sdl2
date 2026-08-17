# gnfsd/NFS 재부팅 복구 중 `readdir` RPC 오류 기록

> **해결됨 (2026-08-17).** 원인은 gnfsd `nfs_readdir()`가 READDIR 요청의
> `count`를 무시하고 응답을 상수 7500B까지 채운 것(RFC 1094 위반).
> NeXTSTEP은 count=4096으로 요청하고 그보다 큰 응답을 디코드하지 못해
> `RPC: Can't decode result`가 났다. 큰 디렉터리(169·794엔트리)만
> 실패한 것도 이 때문. gnfsd가 이제 `count`를 지키도록 수정됐고(GrandCross
> 커밋 `d90121f`), 실기에서 `test/openstep`·`fontdata`·전체 13,516파일
> walk 모두 오류 0으로 확인. 진단·수정 전말은 GrandCross
> `nfsd/PLAN_readdir_count_fix.md`. **아래 우회(GCD archive)는 더 이상
> 불필요하나, 이력으로 남긴다.** (별개로, 조사 중 `make test`의
> `pkill -x gnfsd`가 프로덕션 gnfsd를 죽이던 버그도 수정됨 — 커밋 `3bd1a7b`.)

## 목적과 범위

이 문서는 SDL2/OpenStep port 자체의 결함과 분리된, 2026-08-16 재부팅
복구 중의 gnfsd/NFS 장애를 기록한다. 증상은 OPENSTEP에서 source tree를
읽어 private `/tmp/SDL20` build stage를 재생성하려 할 때 발생했다.

관련 장기 진단과 vnode-wedge 가설은 루트의
[`FIX_gnfsd.md`](../../FIX_gnfsd.md) 및 [`REPORT_gnfsd.md`](../../REPORT_gnfsd.md)에
있다. 이 문서는 그 자료를 대체하지 않으며, SDL2 재구축에 미친 실제
영향과 이번 세션의 우회 방법을 남긴다.

## 관측된 환경

- Linux host: `gnfsd`가 workspace root
  `/mnt/USERS/onion/DATA_ORIGN/Workspace/NeXT_DRIVER`를 export.
- OPENSTEP: root Telnet 세션으로 mount를 수행하고, GUI 실행용 `gcdsd`는
  console `Terminal.app`에서 별도로 실행.
- NFS mount: `/ndrv`, `hard,intr,timeo=30,retrans=5,noac`.
- host 검사: gnfsd PID와 UDP 111/2049 listener가 관측되었다. host의
  `udp_inerr`/`udp_rcvbuferr` 카운터는 이미 누적돼 있었으나, 이 값만으로
  이번 오류의 원인을 단정하지 않는다.

## 증상과 영향

OPENSTEP 재부팅 뒤 `/ndrv`를 새 mount하고 `stage-openstep.csh`를 실행하면
다음 오류가 반복됐다.

```
NFS readdir failed for server 192.168.1.16: RPC: Can't decode result
No match.
stage-openstep: OPENSTEP smoke test copy failed
```

오류는 stage가 `test/openstep/*`처럼 디렉터리를 열거하는 시점에 드러났다.
그 결과 `/tmp/SDL20/src`가 완전하게 만들어지지 않아 뒤따르는
`prepare-openstep-tree.csh` 및 Mesa build gate가 실행될 수 없었다. 이는
SDL2 Objective-C 컴파일, Mesa 3.4.2, GCD, 또는 AppKit 입력 변환의 실패가
아니다.

첫 mount가 wedge되어 `umount`되지 않은 경우 mount tool은 `/ndrv2`로
fallback했지만, `/ndrv2`에서도 같은 `readdir` decode 오류가 재현됐다.
따라서 이번 사례에서는 mountpoint 이름이나 attribute cache 옵션만으로
해결되지 않았다.

## 이번 세션의 조치와 결과

1. OPENSTEP 재부팅, gnfsd 재기동, console `gcdsd` 기동 뒤 `/ndrv`를
   `noac`으로 mount했다.
2. 동일 오류가 재현돼 source stage는 중단했다.
3. 재부팅 복구 시 wedge fallback을 지원하도록
   `stage-openstep.csh`가 source export path를 첫 인자로 받을 수 있게
   보완했고, release rebuild script도 `MOUNTPT`를 그 인자로 전달하도록
   바꿨다. 이 변경은 `/ndrv2` 같은 정상 fallback source를 사용할 수 있게
   하지만, server가 `readdir` 응답 자체를 잘못 만들 때의 해결책은 아니다.
4. NFS directory enumeration을 우회하기 위해 host에서 전체
   `openstep-sdl20` source를 gzip archive로 만들었다.

```
/tmp/openstep-sdl20-source.tar.gz
size: 12 MiB
sha256: c79f1c84319908c1fa47c32bcb85fc1ee653868071114332a9e70905d13feb4e
```

5. 이 archive는 GCD의 `nx.sh --put`으로 OPENSTEP에 전송됐고,
   `/tmp/SDL20-source-export`에 정상 추출됐다. 따라서 이후 SDL2/Mesa
   재구축은 해당 local source export를 stage의 입력으로 사용해 NFS
   `readdir` 경로를 완전히 피할 수 있다.

## 운영 지침

- `gnfsd=DOWN`이면 mount를 시도하지 않는다.
- mount 성공만으로 source tree의 신뢰성을 판단하지 않는다. 최소한
  `stage-openstep.csh`가 끝나고 필요한 test/openstep files가 생성됐는지
  확인한다.
- `/ndrv`가 busy/wedge이면 `tools/nx-mount.sh`의 `/ndrv2`, `/ndrv3`
  fallback을 사용하고, 그 경로를 `stage-openstep.csh` 첫 인자로 넘긴다.
- `readdir` decode 오류가 재발하면 반복 mount/build 대신 GCD archive
  전송 우회를 사용한다. malformed RPC 응답 상태에서 재시도만 하면
  타깃 source stage와 Telnet 세션이 불필요하게 손상·지연된다.
- 이 우회 archive는 `/tmp`에만 두며, 재부팅 뒤 다시 만들어 전송한다.
  read-only canonical source export를 수정하지 않는다.

## 후속 진단 항목

1. gnfsd의 `READDIR`/RPC encode 경로를 verbose request log와 함께
   조사해 `Can't decode result`의 malformed 응답을 재현한다.
2. host UDP receive-buffer drops, client retransmission, gnfsd request
   timing을 같은 시간축으로 수집한다. 누적 kernel counter만으로는
   인과관계를 주장하지 않는다.
3. OPENSTEP client에서 첫 mount 직후 작은 `ls`와 대형 tree walk를
   분리해 어떤 directory shape/request size가 오류를 유발하는지 확인한다.
4. 해결 전에는 SDL2 release rebuild 절차에 GCD source-archive fallback을
   문서화하거나 자동화한다.
