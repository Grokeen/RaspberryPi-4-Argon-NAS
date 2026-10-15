#!/usr/bin/env bash
# 작성: 2026-10-11 17:56:36 +09:00 / 설명 주석 보강: 2026-10-15 22:21:34 +09:00
# 사용자가 비어 있음을 확인하고 초기화를 승인한 SSD에 GPT와 ext4를 생성한다.
# 사용법: sudo bash initialize-empty-ssd.sh BY_ID_PATH SIZE_BYTES 'MODEL' --confirmed-empty
# SIZE_BYTES와 MODEL은 승인한 장치의 정확한 바이트 용량·모델 문자열이다.
# 파티션, 마운트, 기존 시그니처, 시스템 디스크가 발견되면 쓰기 전에 중단한다.
# 아래 검사는 대상 확인 절차이며, SSD가 실제로 고장 없이 쓰이는지 보장하지 않는다.
set -euo pipefail

# root 권한, 네 인수, 명시적 확인 플래그를 모두 요구한다.
if (( EUID != 0 || $# != 4 )) || [[ $4 != --confirmed-empty ]]; then
    echo 'Usage: sudo bash initialize-empty-ssd.sh BY_ID_PATH SIZE_BYTES MODEL --confirmed-empty' >&2
    exit 2
fi
[[ $1 == /dev/disk/by-id/* ]] || { echo 'Use a stable disk by-id path.' >&2; exit 2; }
# /dev/sdX는 재연결 때 바뀔 수 있으므로 by-id를 해석한 실제 장치로 용량·모델을 대조한다.
# lsblk 모델의 밑줄을 공백으로 바꾸고 앞뒤·중복 공백을 정리한 값을 인수와 비교한다.
target_disk=$(readlink -e -- "$1")
[[ -b $target_disk && $2 =~ ^[0-9]+$ ]] || exit 2
actual_size=$(blockdev --getsize64 "$target_disk")
actual_model=$(lsblk -dn -o MODEL "$target_disk" | tr '_' ' ' | xargs)
[[ $actual_size == "$2" && $actual_model == "$3" ]] || {
    echo 'Disk size or model does not match the approved target.' >&2; exit 1;
}
# 루트 파일시스템의 상위 장치 목록과 비교해 운영체제가 있는 디스크를 제외한다.
root_source=$(findmnt -n -o SOURCE /)
root_ancestors=$(lsblk -snrpo NAME "$root_source")
if grep -Fxq "$target_disk" <<< "$root_ancestors"; then
    echo 'Refusing the system disk.' >&2; exit 1
fi
# 디스크 아래 파티션이 있거나 어느 하위 장치든 마운트되어 있으면 초기화를 거부한다.
[[ $(lsblk -nr -o TYPE "$target_disk") == disk ]] || {
    echo 'Existing partitions found; refusing initialization.' >&2; exit 1;
}
if lsblk -nr -o MOUNTPOINT "$target_disk" | grep -q '[^[:space:]]'; then
    echo 'Mounted device found; refusing initialization.' >&2; exit 1
fi
# wipefs의 조회 모드로 파일시스템·파티션 테이블 시그니처만 확인하고 지우지는 않는다.
if [[ -n $(wipefs --no-act --noheadings --output TYPE "$target_disk") ]]; then
    echo 'An existing signature was found; refusing initialization.' >&2; exit 1
fi

echo "Initializing approved empty SSD: $target_disk ($actual_size bytes, $actual_model)."
# 여기부터 실제 디스크 쓰기: GPT와 2048번 섹터에서 시작하는 Linux 파티션 하나를 만든다.
# 기존 시그니처 자동 삭제는 허용하지 않는다. 쓰기 실패 시 set -e에 따라 후속 단계가 중단된다.
printf 'label: gpt\nstart=2048, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4\n' | \
    sfdisk --lock --wipe never --wipe-partitions never "$target_disk"
udevadm settle --timeout=15
# 새 파티션이 정확히 하나이고 승인한 디스크 소속인지 다시 확인한 뒤 파일시스템을 만든다.
mapfile -t partitions < <(lsblk -nrpo NAME,TYPE "$target_disk" | awk '$2 == "part" {print $1}')
[[ ${#partitions[@]} == 1 ]] || { echo 'Expected one new partition.' >&2; exit 1; }
partition=${partitions[0]}
[[ $(lsblk -no PKNAME "$partition") == "${target_disk##*/}" ]] || exit 1
# 초기 포맷의 discard 요청을 생략하고 고정 레이블을 붙인 다음 UUID 등 결과를 출력한다.
mkfs.ext4 -E nodiscard -L EONSSD120 "$partition"
blkid "$partition"
