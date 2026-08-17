# OPENSTEP SDL2 / Mesa 3.4.2 릴리즈·Installer 패키지 계획

작성일: 2026-08-17
상태: **계획 승인 전 — 원격 저장소와 배포 파일은 아직 만들지 않음**

## 1. 목표와 비목표

이번 릴리즈는 각 제품을 Library와 Headers/Examples라는 두 설치 단위로
나눈다.

| 구성 | GitHub 저장소 식별자 | 제품/Installer 표시명 | 기준 버전 | 역할 |
| --- | --- | --- | --- | --- |
| SDL | `openstep-sdl2` | OPENSTEP SDL2 | SDL `2.32.10` | 표준 SDL2 정적 라이브러리와 헤더 |
| Mesa | `opennstep-mesa342` | OPENSTEP Mesa 3.4.2 (Intel i486) | Mesa `3.4.2` | Intel i486 전용 GL 1.2/GLU/OSMesa 정적 라이브러리와 헤더 |

`opennstep-mesa342`는 요청에 적힌 원격 저장소 철자를 그대로 쓴다. 문서와
Installer 화면의 제품명은 혼동을 피하기 위해 **OPENSTEP Mesa 3.4.2**로
표기한다. 저장소 소유자와 공개 범위는 아직 정해지지 않았으므로, 실제 `gh`
생성 직전의 승인 항목이다.

목표는 OPENSTEP 4.2 i486에서 Installer.app으로 설치·삭제 가능한 개발자용
정적 라이브러리 패키지와, 그 패키지를 재현하는 두 독립 소스 저장소를
배포하는 것이다. SDL2 패키지는 Mesa를 포함하지 않으며 Mesa 패키지는 SDL2를
포함하지 않는다.

이 단계의 비목표는 다음과 같다.

- `/NextDeveloper`의 OS 제공 파일을 바꾸거나 덮어쓰지 않는다.
- 동적 라이브러리, X11/GLX, LLVM, 최신 Mesa, GLES/EGL/Vulkan을 추가하지 않는다.
- SDL2 API를 OPENSTEP 전용으로 확장하지 않는다.
- 아직 공개되지 않은 패키지를 원격 저장소 또는 GitHub Release에 올리지 않는다.

## 2. 확정된 기술 기준선

| 항목 | 고정값 | 릴리즈에서 확인할 사실 |
| --- | --- | --- |
| 대상 OS/CPU | OPENSTEP 4.2, i486 | 대상 `cc -m486`, `ar`, `ranlib`로 빌드·소비 가능 |
| SDL | upstream `release-2.32.10`, commit `5d249570393f7a37e037abf22cd6012a4cc56a71` | 최종 `libSDL2.a`의 공개 API 836개 |
| Mesa | Mesa `3.4.2`, 원본 tar SHA-256 `b02b5f77321175820b9955b07979d9f8c5d52e146eecc719844380ef2849ddd6` | `make CC='cc -m486' openstep`, `libGL.a`, `libGLU.a`, OSMesa 포함 |
| GL 범위 | Mesa software OpenGL 1.2 fixed function | GL 1.1/1.2 경로만; `libGL.a` 안의 OSMesa 사용 |
| SDL GL 의존 | 선택적 소비자 의존 | 2D SDL 프로그램은 Mesa 없이 링크 가능하고, `SDL_WINDOW_OPENGL` 소비자는 Mesa 패키지를 같은 prefix에 설치해 `-lGL -lm` 추가 |

Mesa 3.4.2는 `README.OpenStep`이 명시한 OPENSTEP 4.2 `make openstep` 정적
빌드 경로를 사용한다. 현재 실제 빌드는 `libGL.a` 안에 `osmesa.o`를 포함하며
별도의 `libOSMesa.a`를 만들지 않는다. 이 릴리즈의 archive members는 i386
Mach-O만 포함하는 Intel i486 전용이며 fat/multi-architecture package가 아니다.

## 3. 설치 계약: 공용 prefix, 충돌 없는 두 패키지

### 3.1 기본 설치 위치

두 패키지는 모두 다음 Installer 정책을 쓴다.

```text
DefaultLocation  /LocalDeveloper
Relocatable      YES
Application      NO
UseUserMask      NO
```

즉 Installer가 기본으로 제시하는 위치는 `/LocalDeveloper`지만, 사용자는
다른 빈 개발 prefix를 선택할 수 있다. 두 패키지를 함께 쓸 때는 **반드시 같은
prefix**를 선택한다. 현재 실기에는 `/LocalDeveloper`가 존재하지 않으므로
OS 소유 트리를 오염시키지 않고 새로 만들 수 있다. `/NextDeveloper`에는
설치하지 않는다.

payload manifest는 일반 파일만을 계약으로 기록한다. 다만 대상 `package`가
만든 실제 이진 BOM에는 상위 디렉터리 record도 나타날 수 있으므로, 어느 한
패키지를 삭제했을 때 공유 `Headers`, `Libraries`, `Documentation` 디렉터리와
다른 패키지 파일이 보존되는지는 추측하지 않고 P3의 실제 Installer 삭제 시험으로
판정한다.

### 3.2 Mesa payload 계약

`OpenStepMesa342.pkg`가 선택한 prefix 아래에 만드는 내용은 다음으로
한정한다.

```text
Headers/GL/gl.h
Headers/GL/glu.h
Headers/GL/osmesa.h
Libraries/libGL.a                 # OSMesa 포함
Libraries/libGLU.a
Documentation/OpenStep-Mesa-3.4.2/
    README.OPENSTEP
    COPYRIGHT
    PORT-NOTES.md
    LINKING.md
```

GLX/X11 전용 헤더나 Mesa의 데모·GLUT·드라이버는 이 i486 OPENSTEP 패키지의
공개 계약에 넣지 않는다. 헤더 목록은 패키지 빌드 전에 `include/GL/`의 실제
의존성과 독립 컴파일 시험으로 확정한다. `LINKING.md`는 다음의 정확한 규칙을
제시한다.

```text
cc -m486 -I<prefix>/Headers program.c -L<prefix>/Libraries -lGL -lm ...
# GLU를 사용하는 프로그램만 -lGLU를 추가
```

### 3.3 SDL payload 계약

`OpenStepSDL2.pkg`는 같은 prefix 아래에 다음을 설치한다.

```text
Headers/SDL2/SDL*.h
Headers/SDL2/begin_code.h
Headers/SDL2/close_code.h
Libraries/libSDL2.a
Documentation/OpenStep-SDL2-2.32.10/
    README.OPENSTEP
    API-COVERAGE.md
    PORT-NOTES.md
    LINKING.md
    LICENSE.txt
```

공개 헤더는 upstream SDL2 헤더 전체 중 OPENSTEP 전처리 결과와 836-심볼
매니페스트가 요구하는 집합이다. 사용자 프로그램은
`#include <SDL2/SDL.h>`와 `-I<prefix>/Headers`를 사용한다.

2D 소비자 링크 예시는 `libSDL2.a` 뒤에 OPENSTEP 프레임워크와 `-lm`을 둔다.
SDL OpenGL 소비자는 여기에 Mesa의 `-L<prefix>/Libraries -lGL -lm`을 더한다.
패키지 문서는 정적 라이브러리의 **링크 순서**와 `-framework AppKit`,
`Foundation`, `SoundKit`의 필요 여부를 대상 컴파일 시험에서 얻은 실제 명령으로
기록한다. SDL 패키지가 Mesa 파일을 중복 설치하거나, Mesa가 SDL 파일을 의존하는
구조는 만들지 않는다.

## 4. 저장소 분리 원칙

현재 `openstep-sdl20/`에는 SDL 포트와 Mesa 검증 재료가 함께 있다. 새 저장소는
이 작업 디렉터리의 dirty 상태를 그대로 push하지 않고, 아래의 export manifest로
깨끗하게 구성한다. 사이트 전용 설정, IP/계정, `/tmp` 로그, 대상 바이너리와
화면 캡처는 어떤 저장소에도 들어가지 않는다.

```text
openstep-sdl2/
  README.md  LICENSE.txt  NOTICE_OPENSTEP_PORT.md  CHANGELOG.md
  upstream/SDL-2.32.10/              # 또는 검증된 source tar + fetch manifest
  port/openstep/  build/  test/
  packaging/openstep/
    payload-manifest.txt  OpenStepSDL2.info  build-package.csh
    verify-package.csh  release-manifest.txt
  docs/  evidence/release/

opennstep-mesa342/
  README.md  CHANGELOG.md  NOTICE.md
  upstream/Mesa-3.4.2/               # 또는 검증된 source tar + fetch manifest
  port/openstep/  build/  test/
  packaging/openstep/
    payload-manifest.txt  OpenStepMesa342.info  build-package.csh
    verify-package.csh  release-manifest.txt
  docs/  evidence/release/
```

두 upstream snapshot은 새 저장소에 그대로 보관한다. 2026-08-17에 SDL tree는
공식 `release-2.32.10` commit과, Mesa tree는 SHA-256이 확인된 공식 3.4.2
tarball과 각각 재귀 비교해 일치했다. 두 tree 모두 단일 파일이 4 MB 이하이므로
GitHub의 단일 파일 한도에 걸리지 않는다. 상세 검증 기록은
`release-packaging/UPSTREAM_PROVENANCE.md`에 둔다. 이 방식으로 offline target
rebuild와 tag의 source 재현성을 함께 보장한다.

## 5. Installer 산출물 형식

OPENSTEP의 실제 `/NextAdmin/Installer.app/package`를 대상에서 사용한다.
이 도구는 payload root와 `.info`에서 다음 파일 패키지를 생성한다.

```text
OpenStepSDL2.pkg/
  OpenStepSDL2.tar.Z
  OpenStepSDL2.bom
  OpenStepSDL2.info
  OpenStepSDL2.sizes

OpenStepMesa342.pkg/
  OpenStepMesa342.tar.Z
  OpenStepMesa342.bom
  OpenStepMesa342.info
  OpenStepMesa342.sizes
```

`.pkg`는 Workspace에서 여는 디렉터리이므로 GitHub Release에는 디렉터리
자체가 아니라 한 단계 감싼 다음 파일을 올린다.

```text
OpenStep-SDL2-2.32.10-openstep.1-i486.pkg.tar.gz
OpenStep-Mesa-3.4.2-openstep.1-i486.pkg.tar.gz
SHA256SUMS
```

사용자는 outer tarball을 푼 뒤 나온 `.pkg`를 Workspace에서 연다. 내부
`.tar.Z`는 Installer가 관리하는 payload이며 별도로 풀지 않는다. `package`
도구가 생성한 BOM과 sizes를 수작업으로 수정하지 않는다. 100자를 넘는 path가
나오는 경우에만 `LongFileNames YES`와 `package -B`를 함께 사용한다.

초기 버전은 원칙적으로 설치/삭제 hook을 최소화한다. 단, Mesa 정적 archive는
OPENSTEP `ar` 색인이 archive pathname을 보존해 Installer extraction 뒤 stale
상태가 되는 실측 문제가 있다. 따라서 Mesa package는 archive를 설치한 prefix에서
`ranlib`하는 짧은 `post_install` hook을 필수로 포함한다. 그 밖의 hook은 실제
문제가 확인될 때까지 추가하지 않는다.

## 6. 라이선스와 릴리즈 메타데이터

릴리즈 전에 각 payload와 source archive를 라이선스 inventory로 검사한다.

| 구성 | 배포 조치 |
| --- | --- |
| SDL2 | upstream `LICENSE.txt`를 source와 payload 문서에 넣고, OPENSTEP 변경본임을 `NOTICE_OPENSTEP_PORT.md`와 README에 명확히 표시 |
| Mesa core/OSMesa | Mesa `docs/COPYRIGHT`의 XFree86 계열 고지와 원저작권을 포함 |
| Mesa GLU | `docs/COPYRIGHT`가 지시하는 GNU LGPL 고지 및 해당 원문을 포함하는지 inventory에서 검증 |
| 포트 코드/빌드 스크립트 | 각 새 파일에 저작권·라이선스 표기를 추가하고 upstream 파일과 변경 파일을 혼동하지 않음 |

Mesa README에는 Mesa가 OpenGL 상표의 licensed implementation이 아니라는
upstream 고지를 유지한다. GitHub Release notes에는 지원 범위(OpenGL 1.2,
software OSMesa, i486/OPENSTEP 4.2), 제외 범위(X11/GLX, GLES/EGL/Vulkan,
하드웨어 가속)를 명시한다.

각 Release에는 다음을 반드시 첨부한다.

- `.pkg.tar.gz` 파일과 `SHA256SUMS` (파일명·크기·해시)
- source tarball과 source SHA-256
- upstream 버전/commit-or-tar-hash, 포트 revision, 대상 compiler 정보를 적은
  `release-manifest.txt`
- 재현 빌드 명령, 링크 예제, 설치·삭제 절차, 알려진 제한을 담은 README
- 자동/실기 테스트의 명령·결과를 담은 텍스트 evidence

서명은 사용 가능한 신뢰할 수 있는 GPG/minisign 키가 확인된 경우에만 추가하며,
확인 전에는 서명되었다고 주장하지 않는다.

## 7. 실행 단계와 게이트

### P0 — 릴리즈 계약 확정

1. GitHub owner와 `public`/`private`를 확정한다.
2. 위 설치 prefix, 패키지 표시명, artifact 이름, version scheme을 확정한다.
3. `opennstep-mesa342` 철자가 의도된 원격 식별자인지 마지막으로 확인한다.
4. 검증된 full upstream snapshot과 port overlay의 분리를 유지한다.
5. 두 payload manifest를 작성하고, 각각에 다른 프로젝트 파일이 섞이지
   않음을 host-side 검사로 고정한다.

**통과 기준:** 설치되는 파일의 정확한 목록, 라이선스 목록, 삭제 시 보존돼야 할
공유 디렉터리, 소비자 링크 명령이 문서와 manifest에서 하나로 일치한다.

### P1 — Mesa 저장소와 패키지 구현

1. Mesa 3.4.2 pristine source와 OpenStep build scripts/test를 새 저장소
   구조로 추출한다.
2. 깨끗한 target stage에서 `make CC='cc -m486' openstep`을 실행한다.
3. `libGL.a`, `libGLU.a`, `osmesa.o`, 공개 GL/GLU/OSMesa headers를
   manifest대로 payload root에 복사한다.
4. 대상 `package`로 `OpenStepMesa342.pkg`를 생성한다.
5. archive listing, BOM, sizes, file mode, source/payload SHA-256을 검증한다.

**통과 기준:** Mesa OSMesa smoke, context matrix, MesaView와 header/link 소비자
검증이 clean build와 Installer payload 모두에서 통과한다.

### P2 — SDL 저장소와 패키지 구현

1. SDL upstream/overlay/build/test를 독립 저장소로 추출하고 Mesa source·binary
   중복을 제거한다. Mesa는 문서화된 optional dependency로만 참조한다.
2. clean stage에서 release archive를 재생성하고 target
   `check-final-api-manifest.csh`의 836 심볼 검증을 수행한다.
3. manifest의 공개 헤더와 `libSDL2.a`, 문서/라이선스만 payload root에 넣는다.
4. 대상 `package`로 `OpenStepSDL2.pkg`를 생성하고 P1과 같은 구조 검사를 한다.

**통과 기준:** SDL의 전체 final-archive regression, 2D/오디오/타이머/스레드,
AppKit 창·입력, software renderer, 그리고 Mesa가 설치된 prefix에서 GL 1.2
window/lifecycle 및 보존된 upstream SDL 2.0.0 `testgl2` 소비자가 통과한다.

### P3 — 실제 Installer 설치·삭제 검증

실기에서 매 회차 비어 있는 시험 prefix를 사용한다. 예:
`/tmp/OPENSTEP-PKG-SMOKE`.

1. Mesa `.pkg`를 Installer.app으로 설치한다.
2. 설치된 Mesa headers/static archives만 사용해 OSMesa/GLU 소비자를 새로
   컴파일·실행한다.
3. SDL `.pkg`를 **같은** prefix에 설치한다.
4. 설치된 파일만 사용해 2D SDL consumer와 Mesa-backed SDL GL consumer를
   새로 컴파일·실행한다. 빌드 stage나 `/tmp/SDL20`의 헤더/라이브러리를
   include/link path에 넣지 않는다.
5. SDL package 삭제 후 Mesa 소비자가 계속 동작하고 Mesa files가 남는지
   확인한다.
6. Mesa package 삭제 후 시험 prefix에 BOM이 기록한 파일이 남지 않는지
   확인한다. 시험 prefix 밖의 `/NextDeveloper`, `/NextLibrary`는 전후
   manifest/hash 비교로 불변임을 확인한다.

**통과 기준:** Installer의 install/delete 로그가 성공이고, two-package
공존·순서별 삭제·clean consumer build가 모두 통과한다. 이 게이트 전에는
GitHub Release asset을 만들지 않는다.

### P4 — 재현성과 릴리즈 후보(RC)

1. 새 target-private stage에서, 이전 object/archive를 재사용하지 않고 Mesa와
   SDL package를 각각 다시 만든다.
2. 두 번 생성한 payload manifest, archive member list, package BOM을 비교한다.
   생성 시각처럼 불가피하게 달라지는 metadata는 별도 정규화 규칙으로
   명시하고, 코드·headers·libraries의 SHA-256은 일치해야 한다.
3. 각 RC에 `2.32.10-openstep.1-rcN`, `3.4.2-openstep.1-rcN`을 부여하고
   evidence를 고정한다.

**통과 기준:** clean rebuild, payload 검증, P3 Installer smoke, checksum
manifest가 모두 PASS이며 알려진 제한이 README/Release notes와 일치한다.

### P5 — GitHub 원격 저장소·태그·Release

이 단계의 `gh` 작업은 사용자가 지정한 대로 **샌드박스 밖에서만** 수행한다.
외부 상태를 만드는 순서는 다음으로 고정한다.

1. 각 local repo가 clean이고 secret scan, license inventory, `git diff --check`,
   source/payload manifest 검사를 통과했는지 확인한다.
2. 확인된 owner/visibility로 두 repository를 생성한다. 예시는 다음과 같지만
   `$OWNER`와 공개 여부는 P0 승인값을 쓴다.

   ```sh
   gh repo create "$OWNER/openstep-sdl2" --SOURCE-VISIBILITY --source ./openstep-sdl2 --remote origin --push
   gh repo create "$OWNER/opennstep-mesa342" --SOURCE-VISIBILITY --source ./opennstep-mesa342 --remote origin --push
   ```

   여기서 `--SOURCE-VISIBILITY`는 실제 명령에서는 `--public` 또는
   `--private` 하나로 치환한다.
3. upstream+port release tag를 생성·push한다.

   ```text
   openstep-sdl2:       v2.32.10-openstep.1
   opennstep-mesa342:   v3.4.2-openstep.1
   ```

4. tag commit에서 만든 `.pkg.tar.gz`, source archive, checksums,
   release manifest, evidence를 `gh release create`로 upload한다.
5. 깨끗한 별도 clone에서 Release asset의 checksum을 확인하고, package를
   OPENSTEP 시험 prefix에 다시 설치해 P3의 핵심 consumer를 재실행한다.

**통과 기준:** GitHub tag가 source manifest와 일치하고, uploaded asset의
checksum이 release notes의 값과 일치하며, 다운로드한 asset으로 실제
Installer 재설치가 성공한다.

## 8. 위험 요소와 중단 기준

| 위험 | 예방/대응 | 중단 기준 |
| --- | --- | --- |
| 다른 GL/SDL 파일 덮어쓰기 | `/NextDeveloper` 금지, relocatable `/LocalDeveloper`, install preflight | 기존 `libGL.a`, `libGLU.a`, `libSDL2.a`가 선택 prefix에 있으면 덮어쓰지 않고 중단 |
| SDL 정적 GL 링크 누락 | Mesa 없이 2D, Mesa 포함 GL consumer를 분리 시험 | 설치된 라이브러리만으로 GL consumer 링크/실행 실패 |
| package metadata/BOM 오류 | target `package`만으로 생성, archive/BOM/sizes 검사 | BOM과 payload, files/modes, Installer delete 결과가 불일치 |
| 재현 불가 source | upstream hash, port patch manifest, clean target rebuild | tag에서 재빌드한 lib/header hash 또는 API manifest 불일치 |
| 라이선스 누락 | release 전 license inventory를 필수 gate로 설정 | payload/source/release asset 중 하나라도 필요한 notice가 없음 |
| 원격 저장소 오생성/정보 유출 | clean export, secret scan, `gh` 외부 실행 직전 owner/visibility 재확인 | owner, repository name, visibility 중 하나라도 미확정 |

## 9. 다음 작업 순서

다음 구현 작업은 P0의 export manifest와 Installer `.info` 초안을 만드는
것이다. 원격 저장소 생성은 그 뒤, 두 payload가 실제로 Installer에서
설치·삭제되는 P3까지 통과한 RC에 한정한다.

### 참고

- 대상 `/NextAdmin/Installer.app/package`의 실제 사용법과 생성 구조를
  2026-08-17 실기에서 확인했다.
- Installer package specification: <https://www.nextop.de/NeXTstep_3.3_Developer_Documentation/Concepts/Installer.htmld/index.html>
- Mesa 3.4.2의 OPENSTEP build 근거: `upstream/Mesa-3.4.2/docs/README.OpenStep`
