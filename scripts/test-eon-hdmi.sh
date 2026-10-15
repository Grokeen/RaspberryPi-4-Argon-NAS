#!/usr/bin/env bash
# 작성: 2026-10-11 17:44:56 +09:00 / 설명 주석 보강: 2026-10-15 22:21:34 +09:00
# 연결 감지가 실패한 Pi 4의 HDMI 두 포트에 720p 시험 패턴을 잠시 강제 출력한다.
# 사용법: sudo bash test-eon-hdmi.sh [SECONDS] (기본 180초, 허용 1~300초)
# 종료 시 자동 감지를 복원하며 부팅 설정 변경이나 NAS 재시작은 수행하지 않는다.
# 소프트웨어 강제 연결 상태만으로 케이블·모듈 정상 여부를 판단할 수는 없다.
set -euo pipefail

# 숫자 형식과 범위를 확인하고 10진수로 변환해 010 같은 인수도 일관되게 처리한다.
duration=${1:-180}
if [[ ! $duration =~ ^[0-9]{1,3}$ ]]; then
    echo 'Duration must be an integer from 1 to 300 seconds.' >&2
    exit 2
fi
duration=$((10#$duration))
if (( duration < 1 || duration > 300 || EUID != 0 )); then
    echo 'Run as root with a duration from 1 to 300 seconds.' >&2
    exit 2
fi
# 출력 시험·상태 조회·시간 제한 도구가 모두 있어야 장치 상태 변경을 시작한다.
for command_name in kmstest kmsprint timeout; do
    command -v "$command_name" >/dev/null
done

shopt -s nullglob
# 같은 DRM 카드에 속한 HDMI-A-1·2가 모두 disconnected일 때만 시험한다.
# 이미 연결된 화면이나 예상과 다른 카드 구성이 있으면 그대로 종료한다.
connectors=(/sys/class/drm/card*-HDMI-A-[12])
if (( ${#connectors[@]} != 2 )); then
    echo 'Expected exactly two Pi HDMI connectors; no changes made.' >&2
    exit 1
fi
first_name=${connectors[0]##*/}
card_name=${first_name%%-HDMI-A-*}
for connector in "${connectors[@]}"; do
    name=${connector##*/}
    if [[ ${name%%-HDMI-A-*} != "$card_name" || $(cat "$connector/status") != disconnected ]]; then
        echo 'A display is connected or multiple cards were found; no changes made.' >&2
        exit 1
    fi
done

forced_connectors=()
restore_detection() {
    # 강제 상태를 적용하려던 포트만 자동 감지로 되돌리고 KMS 상태를 출력한다.
    for connector in "${forced_connectors[@]}"; do
        printf 'detect\n' > "$connector/status"
    done
    echo 'Automatic HDMI detection restored.'
    kmsprint
}
# 정상 종료와 오류 종료 모두 복원을 시도하고, 인터럽트·종료 신호도 EXIT 경로로 보낸다.
trap restore_detection EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

for connector in "${connectors[@]}"; do
    # 쓰기 전에 복원 목록에 넣어 도중에 한 포트 설정이 실패해도 복원 대상으로 남긴다.
    forced_connectors+=("$connector")
    printf 'on-digital\n' > "$connector/status"
done
# 시험 도구의 코어 덤프 생성을 막고, 두 포트를 같은 1280x720@60 모드로 제한 시간 동안 출력한다.
ulimit -c 0
echo "Testing both HDMI outputs at 1280x720@60 for up to $duration seconds."
echo 'The forced connected state is a test override, not proof of a healthy cable.'
if timeout --signal=TERM --kill-after=5s "${duration}s" kmstest \
    --device="/dev/dri/$card_name" --cea \
    -c HDMI-A-1 -r 1280x720@60 -c HDMI-A-2 -r 1280x720@60; then
    test_status=0
else
    test_status=$?
fi
if (( test_status == 124 )); then
    # timeout의 정상적인 시간 만료(124)는 예정된 시험 종료로 취급한다.
    # 그 밖의 도구 실패 코드는 호출자에게 그대로 전달한다.
    echo 'The bounded test window ended.'
    test_status=0
fi
exit "$test_status"
