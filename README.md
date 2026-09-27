### [English](https://june3474.github.io/nimf-overlay/)

# nimf-overlay

[hamonikr/nimf](https://github.com/hamonikr/nimf)를 위한 Gentoo 오버레이입니다.

nimf는 기본적으로 GTK 3, Qt 6, Wayland를 지원합니다. GTK 2, GTK 4 같은 다른 입력 엔진은 USE 플래그로 선택적으로 추가할 수 있습니다. Gentoo가 더 이상 Qt 5를 제공하지 않기 때문에, Qt 5 플러그인은 격리된 SDK 이미지 컨테이너에서 버전별로 따로 빌드되어 제공됩니다.\
`nimf-settings`는 업스트림 소스(현재 GTK 3)를 기준으로 빌드됩니다.

## 이 오버레이는 왜 필요한가?

**2026-06-30**에 Qt 5 패키지가 Gentoo 소스 트리에서
마스킹되었습니다. 그 결과 이 날짜 이후 sync한 Gentoo 시스템에서는 nimf의
Qt 5 입력 모듈을 더 이상 빌드할 수 없게 되어, `nimf` 빌드 전체가 실패합니다.

하지만 Qt 5 애플리케이션은 여전히 사용되고 있고, nimf의 Qt 5 입력 모듈도
여전히 필요합니다. 이 오버레이는 2026-06-30 이후 Qt 5 자체를 설치할 수 없는
Gentoo 시스템에서도 nimf를 통해 Qt 5 애플리케이션에서 한글을 입력하고
사용할 수 있게 해주는 ebuild 몇 가지를 제공합니다.

## 설치

```bash
eselect repository add nimf-overlay git https://github.com/june3474/nimf-overlay.git
emaint sync -r nimf-overlay
emerge --ask app-i18n/nimf
```

기본 설정은 GTK 2/3/4, Qt 6, Wayland, Hangul, Qt 5 호환 플러그인을
빌드하여 설치합니다. `USE=-qt5`를 사용하면
Qt 5 플러그인은 설치되지 않습니다.

## Qt 5 지원: 왜 Qt 5 버전별로 플러그인이 필요한가?

Qt 5의 입력 플러그인은 Qt5Core/Qt5Gui에 대해 마이너 릴리즈 간
ABI 안정성이 보장되지 않는 방식으로 링크됩니다. Qt 5.11 헤더와
라이브러리로 빌드된 플러그인이 Qt 5.15에 링크된 애플리케이션 프로세스
안에서 올바르게 로드된다는 보장이 없으며, 그 반대도 마찬가지입니다 —
모든 5.x 마이너 버전에서 동작하는 단일 바이너리는 존재하지 않습니다.

이를 해결하기 위해 이 ebuild는 5.11부터 5.15까지 Qt 5 마이너 버전마다
`platforminputcontexts` 플러그인을 하나씩 빌드하여 설치합니다. 다만
시스템 전역 기본값으로는 한 번에 하나만 활성화할 수 있으므로, 애플리케이션이
어떤 것을 로드할지 `eselect`로 선택해야 합니다.

### eselect 사용법

```bash
eselect nimf-qt5 list
eselect nimf-qt5 show
eselect nimf-qt5 set 5.13
```

최초 설치 시에는 5.15(기본값)가 선택됩니다. 업그레이드 시에는 기존 선택이
유지됩니다. amd64는 5.11부터 5.15까지 제공하며, arm64는 5.15만 제공합니다.
전역 `QT_PLUGIN_PATH`는 필요하지 않습니다.

> 자체 Qt 플러그인 디렉터리를 사용하는 애플리케이션은
> `/usr/lib64/nimf/qt5/<minor>/platforminputcontexts/`
> 안의 해당 버전 파일로 링크를 걸어줘야 할 수도 있습니다.

## 그래픽 세션 환경 변수

그래픽 세션을 시작할 때 다음 값을 설정하면 GTK와 Qt 애플리케이션
모두 nimf를 통해 입력을 처리합니다:

```text
GTK_IM_MODULE=nimf
QT_IM_MODULE=nimf
XMODIFIERS=@im=nimf
```

## 자동화

매주 월요일 03:17 UTC(한국 시간 12:17)에 워크플로우가 hamonikr/nimf의
최신 stable 업스트림 릴리스를 확인하고, 소스와 Debian Bookworm 자산을
검증한 뒤, checksum으로 고정된 SDK에서 Qt 5.11–5.14를 빌드하고,
Bookworm 패키지에서 Qt 5.15.8을 추출하여 검증을 거친 PR을 엽니다. PR을
머지하면 해당 prerelease가 승격됩니다.

> 이 검사는 매주 실행되므로, 새 업스트림 릴리스가 나와도 **즉시 반영되지 않으며**,
> PR로 나타나기까지 일주일 이상 걸릴 수 있습니다.

부트스트랩 및 검증 명령은 [CONTRIBUTING.md](CONTRIBUTING.md)를
참고하세요.
