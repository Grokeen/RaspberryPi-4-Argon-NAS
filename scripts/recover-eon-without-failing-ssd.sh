#!/usr/bin/env bash
# 작성: 2026-10-11 18:16:19 +09:00 / 설명 주석 보강: 2026-10-15 22:21:34 +09:00
# USB 시간 초과 후 분리해 둔 EON 컨트롤러를 다시 연결하고 문제 SSD 슬롯만 임시 격리한다.
# 사용법: sudo bash recover-eon-without-failing-ssd.sh
# 이 장비에서 관찰한 PCI 주소 0000:01:00.0, 브리지 1741:1156의 LUN 0을 전제로 한다.
# 실행 전에 데이터 볼륨을 해제하고 SMB 및 해당 디스크를 사용하는 서비스를 중지해야 한다.
# 이 스크립트는 SMB·OMV 경로 마운트·컨트롤러 분리 상태를 검사한다.
# 격리는 현재 연결에만 적용된다. 영구 격리는 별도 udev 규칙이 담당하며 하드웨어 수리는 아니다.
set -euo pipefail
(( EUID == 0 )) || { echo 'Run as root.' >&2; exit 2; }
# 복구 중 공유나 데이터 볼륨이 사용되지 않도록 알려진 서비스와 마운트 경로를 점검한다.
if systemctl is-active --quiet smbd; then
    echo 'Stop SMB before recovery.' >&2; exit 1
fi
if findmnt -rn -o TARGET | grep -q '^/srv/dev-disk-by-uuid-'; then
    echo 'Unmount the affected data volumes before recovery.' >&2; exit 1
fi
# 이미 드라이버에 연결된 컨트롤러에는 중복 bind를 시도하지 않는다.
if [[ -e /sys/bus/pci/devices/0000:01:00.0/driver ]]; then
    echo 'Expected the previously detached USB controller; no changes made.' >&2; exit 1
fi
# 장치가 나타나자마자 자동 탐색이 SSD를 건드리지 않도록 udev 작업 실행을 잠시 멈춘다.
# 실패로 종료해도 EXIT 트랩에서 큐를 재개하도록 등록한 다음 컨트롤러를 연결한다.
trap 'udevadm control --start-exec-queue' EXIT
udevadm control --stop-exec-queue
printf '0000:01:00.0' > /sys/bus/pci/drivers/xhci_hcd/bind
isolated=false
shopt -s nullglob
# 장치 생성 대기 간격은 0.05초이며 최대 200회 확인한다(탐색에 걸리는 시간은 별도).
# 브리지 ID와 SCSI LUN 경로로 슬롯을 찾아 장치 이름 변경에 영향을 받지 않도록 한다.
for (( attempt=0; attempt<200; attempt++ )); do
    for bridge in /sys/bus/usb/devices/*; do
        [[ -f $bridge/idVendor && -f $bridge/idProduct ]] || continue
        [[ $(cat "$bridge/idVendor") == 1741 && $(cat "$bridge/idProduct") == 1156 ]] || continue
        bridge_path=$(readlink -f "$bridge")
        for state_file in "$bridge_path"/*/host*/target*/*:0:0:0/state; do
            # 이 슬롯의 SCSI 상태를 offline으로 바꿔 이후 I/O가 정상 디스크 복구를 막지 않게 한다.
            printf 'offline\n' > "$state_file"
            echo "Temporarily isolated failing SSD slot: $state_file"
            isolated=true
        done
    done
    $isolated && break
    sleep 0.05
done
$isolated || { echo 'SSD slot not found; recovery needs physical inspection.' >&2; exit 1; }
# 격리 후 udev 처리를 재개하고 현재 USB·블록 장치 상태만 출력한다.
# 데이터 볼륨 재마운트와 서비스 재시작은 이 스크립트에서 수행하지 않는다.
udevadm control --start-exec-queue
udevadm settle --timeout=20
lsusb -t
lsblk -e 1,7 -o NAME,SIZE,MODEL,FSTYPE,MOUNTPOINT
