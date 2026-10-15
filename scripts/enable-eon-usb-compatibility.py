#!/usr/bin/env python3
# 작성: 2026-10-11 18:06:20 +09:00 / 설명 주석 보강: 2026-10-15 22:21:34 +09:00
# 관찰된 Argon EON USB/SATA 브리지 두 종류에 UAS 대신 usb-storage를 쓰도록 설정한다.
# 사용법: sudo python3 enable-eon-usb-compatibility.py
# 대상은 1741:1156, 174e:1155이며 다른 부팅 인수와 USB quirk 플래그는 보존한다.
# 이 장비의 /boot/cmdline.txt 배치를 전제로 하며, 실행 즉시 설정 파일을 수정한다.
# 현재 드라이버에 설정값을 전달하지만, 장치 재연결이나 재부팅은 직접 수행하지 않는다.
import datetime
import os
from pathlib import Path
import shutil
import tempfile

# 부팅 설정과 sysfs 쓰기를 위해 root 권한을 확인하고, 원본을 root 전용 디렉터리에 백업한다.
if os.geteuid() != 0:
    raise SystemExit("Run as root.")
boot_file = Path("/boot/cmdline.txt")
runtime_file = Path("/sys/module/usb_storage/parameters/quirks")
backup = Path("/var/backups") / ("codex-eon-usb-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))
backup.mkdir(mode=0o700)
shutil.copy2(boot_file, backup / "cmdline.before.txt")
boot_text = boot_file.read_text()
# 커널 명령행은 한 줄이어야 하므로 예상과 다른 파일에는 설정을 덮어쓰지 않는다.
if len(boot_text.strip().splitlines()) != 1:
    raise SystemExit("Expected a single-line kernel command file.")
entries = {}


def collect(value):
    # vendor:product:flags 목록을 장치별로 합치고 중복 플래그만 제거한다.
    # 동일한 브리지의 부팅 설정과 실행 중 설정이 달라도 양쪽 플래그를 남긴다.
    for entry in filter(None, value.split(",")):
        vendor, product, flags = entry.split(":", 2)
        key = vendor.lower() + ":" + product.lower()
        entries[key] = "".join(dict.fromkeys(entries.get(key, "") + flags))


tokens = boot_text.split()
# 기존 부팅 인수와 현재 드라이버의 quirks를 먼저 수집한다.
for token in tokens:
    if token.startswith("usb-storage.quirks="):
        collect(token.split("=", 1)[1])
if runtime_file.exists():
    runtime_text = runtime_file.read_text().strip()
    (backup / "runtime-quirks.before.txt").write_text(runtime_text + "\n")
    collect(runtime_text)
# 'u'는 UAS 사용을 막는 플래그이다. 관찰된 브리지 ID에만 이 플래그를 추가한다.
for bridge in ("1741:1156", "174e:1155"):
    entries[bridge] = "".join(dict.fromkeys(entries.get(bridge, "") + "u"))
quirks = ",".join(key + ":" + flags for key, flags in entries.items())
tokens = [token for token in tokens if not token.startswith("usb-storage.quirks=")]
tokens.append("usb-storage.quirks=" + quirks)
# 같은 디렉터리의 임시 파일을 동기화하고 원본 권한을 복사한 뒤 원자적으로 교체한다.
# 기존 usb-storage.quirks 인수들은 위에서 합친 하나의 인수로 정리된다.
with tempfile.NamedTemporaryFile(mode="w", dir=boot_file.parent, prefix="cmdline-codex-", delete=False) as temporary:
    temporary.write(" ".join(tokens) + "\n")
    temporary.flush()
    os.fsync(temporary.fileno())
    temporary_name = temporary.name
os.chmod(temporary_name, boot_file.stat().st_mode & 0o777)
os.replace(temporary_name, boot_file)
# 실행 중인 드라이버에도 같은 값을 전달한다. 이미 연결된 장치의 드라이버 교체와는 별개다.
if runtime_file.exists():
    runtime_file.write_text(quirks)
print("Backup: " + str(backup))
print("EON USB compatibility quirks: " + quirks)
