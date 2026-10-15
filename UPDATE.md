# Update Log

## 2026-10-11 17:04:34 +09:00

### SSH access recovery
- Confirmed the Raspberry Pi at `192.168.0.30` was reachable from the workstation; TCP ports `22`, `139`, and `445` responded.
- Reviewed the Pi SSH logs. Login attempts were denied because account `ygreen0516` was not a member of an SSH-allowed group (`AllowGroups`).
- On the Pi console, added the account to the existing `ssh` group with `sudo usermod -aG ssh ygreen0516`.
- Verified the account's supplementary groups included `ssh`, then reloaded the SSH service with `sudo systemctl reload ssh`.
- The user confirmed SSH login succeeded after these changes.

### Verification and remaining work
- Verified the group membership with `id ygreen0516` and the service reload through the SSH journal.
- No application source code was changed.
- Static IP configuration was not performed. The Pi continues to use `192.168.0.30`; no persistent network configuration was changed or verified.
- Credentials and token values were not copied into this log.

## 2026-10-11 17:09:24 +09:00 — 고정 IP 원격 확인 및 검증

### 작업 결과
- `codexCode.md`의 접속 정보와 기본 규칙을 읽고, 작업 PC에서 `ygreen0516@192.168.0.30`으로 SSH 접속했습니다.
- 장비는 `yongroknas`, Raspbian GNU/Linux 11 (bullseye), OpenMediaVault `6.4.9-1`입니다. 네트워크는 Netplan `0.101-4`와 `systemd-networkd`가 관리하고 있습니다.
- **이미 영구 고정 IPv4 설정이 저장되어 있고 실제 인터페이스에도 적용되어 있음을 확인했습니다.** 주소를 새로 변경하거나 DHCP 설정을 고정 IP로 전환한 작업은 없으며, 기존 설정을 유지했습니다.

| 항목 | 확인한 값 |
| --- | --- |
| 인터페이스 | `eth0` |
| IPv4 주소 | `192.168.0.30/24` |
| 서브넷 마스크 | `255.255.255.0` |
| 기본 게이트웨이 | `192.168.0.1` |
| DNS | `8.8.8.8` |
| OpenMediaVault IPv4 방식 | `method: static` |
| Netplan IPv4 DHCP | `dhcp4: no` |
| SSH | `ssh ygreen0516@192.168.0.30` |
| SMB 공유 | `\\192.168.0.30` |
| NAS 관리 화면 | `http://192.168.0.30:28/` |

- `172.17.0.1`은 Docker 내부 브리지 `docker0`의 주소이며, NAS의 LAN 접속 주소는 `192.168.0.30`입니다.

### 설정 확인 및 백업
- OMV 설정 DB: `sudo omv-confdbadm read --prettify conf.system.network.interface`에서 `eth0`의 `method`, 주소, 게이트웨이, DNS를 확인했습니다.
- 영구 설정 파일: `/etc/netplan/10-openmediavault-default.yaml`, `/etc/netplan/20-openmediavault-eth0.yaml`을 확인했습니다. 후자에 `192.168.0.30/24`, 기본 경로, DNS, `dhcp4: no`가 저장되어 있습니다.
- 적용된 networkd 설정: `/run/systemd/network/10-netplan-eth0.network`에서 `Address=192.168.0.30/24`, `Gateway=192.168.0.1`, `DNS=8.8.8.8`, `DHCP=ipv6`를 확인했습니다.
- Pi 백업 디렉터리: `/var/backups/codex-network-20261011-170826` (root 소유, 디렉터리 권한 `700`). Netplan 디렉터리, 적용된 `.network` 파일, OMV 네트워크 인터페이스 JSON을 보관했습니다.
- `sudo netplan --debug generate`를 실행해 `Configuration is valid`, 종료 코드 `0`을 확인했습니다. 실행 전후 두 YAML 파일과 적용된 `.network` 파일의 SHA-256이 동일했습니다.
- 이미 일치하는 설정이 적용되어 있어 `netplan apply`, 네트워크 서비스 재시작, 장비 재부팅은 실행하지 않았습니다. 재부팅 후 접속 시험은 수행하지 않았으며, 영구 설정 파일과 서비스 자동 시작 설정으로 지속성을 확인했습니다.

### 검증 결과
| 검사 | 결과 |
| --- | --- |
| 기존 세션과 별개의 새 SSH 접속 | 로그인 및 명령 실행 성공, 종료 코드 `0` |
| `ip -4 addr show dev eth0` | `192.168.0.30/24`, 유효 기간 `forever` |
| `ip -4 route show default` | `default via 192.168.0.1 dev eth0 proto static` |
| `resolvectl dns eth0` | `8.8.8.8` |
| `systemctl is-enabled systemd-networkd systemd-resolved` | 둘 다 `enabled` |
| `systemctl is-active ssh smbd systemd-networkd systemd-resolved` | 모두 `active` |
| `ping -c 3 -W 2 192.168.0.1` | 3회 응답, 패킷 손실 `0%` |
| `getent ahostsv4 deb.debian.org` | IPv4 DNS 조회 성공 |
| 작업 PC → Pi TCP `22`, `139`, `445` | 모두 연결 성공 |
| `http://192.168.0.30:28/` | HTTP `200`, nginx, OpenMediaVault 화면 응답 |

- SMB 검증은 서비스 상태와 TCP 연결 확인까지 수행했으며, 공유 폴더의 파일 읽기·쓰기 시험은 수행하지 않았습니다.
- 기본 HTTP/HTTPS 포트 `80`/`443`은 응답하지 않았고, 실제 관리 화면 포트 `28`로 정상 응답을 확인했습니다.

### 기록 및 배포 범위
- 로컬 수정 문서: `UPDATE.md`, `OWERORDER.md`.
- Pi 문서 사본 위치: `/home/ygreen0516/codex-worklog/UPDATE.md`, `/home/ygreen0516/codex-worklog/OWERORDER.md`. 전송 후 로컬 파일과 SHA-256이 일치하는지 확인했습니다.
- 애플리케이션 소스 변경이 없어 프로그램 빌드·컴파일 대상은 없습니다. 네트워크 설정 생성 검증과 실제 접속 검증을 수행했습니다.
- GitHub 반영 대상은 위 두 작업 문서이며, 접속 비밀번호나 토큰은 기록하지 않았습니다.

### 설정 관리 참고
- OMV가 관리하는 네트워크 설정은 OMV 관리 화면의 네트워크 인터페이스 설정을 기준으로 유지합니다. 관련 설명: [OpenMediaVault 네트워크 문서](https://docs.openmediavault.org/en/latest/administration/general/network.html).
- `netplan generate`는 설정을 생성하며 실행 중인 네트워크에 적용하는 명령은 아닙니다. 관련 설명: [Netplan generate 공식 문서](https://netplan.readthedocs.io/en/latest/netplan-generate/).

## 2026-10-11 17:36:07 +09:00 — HDMI 신호 없음 원격 진단

### 증상과 접속
- 사용자는 HDMI 모듈 연결 후 모니터에 **신호 없음**이 표시된다고 설명했습니다. 모듈의 정확한 모델과 연결한 포트는 아직 확인되지 않았습니다.
- 최초 SSH 접속 시도는 사용자 재부팅 중에 시간 초과되었습니다. 부팅 후 `192.168.0.30`으로 SSH 재접속해 진단했습니다.
- 재부팅 후에도 `eth0`의 주소가 `192.168.0.30/24`로 유지되었습니다. SSH, Samba, nginx 서비스가 실행 중인 것을 확인했습니다.
- 이 항목의 일시는 작업 PC의 Asia/Seoul 기준입니다. Pi의 재부팅 직후 시각은 보정 중이어서 부팅 로그의 시각과 차이가 있습니다.

### 확인한 증거
| 검사 | 결과 |
| --- | --- |
| 모델 | Raspberry Pi 4 Model B Rev 1.2 |
| `/boot/config.txt` | `dtoverlay=vc4-kms-v3d`, `max_framebuffers=2`; 활성화된 HDMI 강제 차단 설정 없음 |
| `/boot/cmdline.txt` | `console=tty1`; HDMI 출력을 끄거나 해상도를 강제하는 `video=` 옵션 없음 |
| `/sys/class/drm/card1-HDMI-A-1` | `status=disconnected`, `enabled=disabled`, EDID `0`바이트, 표시 모드 없음 |
| `/sys/class/drm/card1-HDMI-A-2` | `status=disconnected`, `enabled=disabled`, EDID `0`바이트, 표시 모드 없음 |
| `sudo kmsprint` | 두 HDMI 커넥터 모두 `disconnected` |
| 커널 로그 | `vc4`와 두 `vc4-hdmi` 드라이버 초기화 성공; `Cannot find any crtc or sizes` 기록 |
| `sudo vclog --msg` | HDMI0/HDMI1 모두 `EDID error reading EDID block 0`, `EDID giving up on reading EDID block 0` 기록 |
| `sudo vcgencmd get_throttled` | `throttled=0x0`: 현재 부팅에서 보고된 저전압/스로틀링 플래그 없음 |
| 부팅 대상 | `multi-user.target`, 그래픽 display-manager 비활성 |

### 판단
- **현재 확인된 직접 원인은 디스플레이 연결 감지 및 EDID 읽기 실패입니다.** Pi가 유효한 HDMI 모니터를 인식하지 못해 출력 모드를 활성화하지 못하고 있습니다.
- Linux KMS로 전환하기 전의 펌웨어에서도 EDID 읽기가 실패했습니다. 따라서 그래픽 데스크톱 유무보다 모듈 접촉, HDMI 케이블, 모니터 입력·전원, HDMI 포트 등 연결 경로를 우선 확인해야 합니다.
- **HDMI 모듈 불량을 확정한 것은 아닙니다.** 모듈을 우회한 직결 시험과 케이블/포트 교차 시험이 필요합니다.
- 설정 파일 수정, 강제 해상도 설정, 그래픽 드라이버 변경, 추가 재부팅은 수행하지 않았습니다.

### 현장 확인 순서
1. 모니터 전원을 켜고 실제 케이블이 연결된 HDMI 입력을 선택합니다. 정상 동작이 확인된 HDMI 케이블로 교체해 봅니다.
2. 확장 보드의 다른 HDMI 출력 포트로 옮겨 연결한 뒤, 아래 진단 명령으로 `connected`로 바뀌는지 확인합니다.
3. 모듈을 다시 장착할 때는 Pi를 정상 종료하고 전원을 분리한 후, Pi와 모듈 사이의 micro-HDMI 접속부가 제대로 맞물렸는지 확인합니다.
4. 모듈을 우회하여 모니터를 Pi 본체의 micro-HDMI에 직접 연결합니다. 직결에서는 정상인데 모듈을 거치면 실패할 경우, 모듈 또는 모듈 접속부 문제로 범위를 좁힐 수 있습니다.
5. 직결도 실패하면 다른 케이블·모니터 입력·Pi HDMI 포트로 비교합니다. 이 결과를 확인한 후 필요할 경우 KMS 강제 모드 시험을 검토합니다.

재확인 명령:
```sh
sudo kmsprint
for connector in /sys/class/drm/card*-HDMI-A-*; do
  echo "$connector"
  cat "$connector/status" "$connector/enabled"
  wc -c < "$connector/edid"
  cat "$connector/modes"
done
sudo vclog --msg 2>&1 | grep -Ei 'hdmi|edid|hpd'
```

### 기록 및 참고
- 진단 내역을 `UPDATE.md`, `OWERORDER.md`에 추가합니다. 프로그램 소스 변경과 빌드·컴파일 대상은 없습니다.
- [Raspberry Pi 공식 HDMI 진단 문서](https://pip-assets.raspberrypi.com/categories/1259-audio-camera-and-display/documents/RP-004341-WP/Troubleshooting-KMS-HDMI-output)는 케이블·포트·모니터 입력과 EDID 확인을 안내합니다.
- [Argon 제조사 포럼의 HDMI 확장 보드 점검 안내](https://forum.argon40.com/t/hdmi-daughter-board-does-not-produce-video/489)에도 장착 상태와 양쪽 출력 포트 확인이 제시되어 있습니다. 이 사례만으로 현재 모듈 불량을 판정하지 않습니다.

## 2026-10-11 18:16:19 +09:00 — 웹 관리자·SMB 권한 및 EON 저장장치 작업 (진행 중)

### 완료한 권한 변경
- `ygreen0516`은 Linux에서 이미 `(ALL) NOPASSWD: ALL` sudo 권한을 가지고 있었으나, OMV 웹 관리자 그룹에는 포함되어 있지 않았습니다.
- `/etc/group`, `/etc/gshadow` 및 변경 전 그룹 정보를 `/var/backups/codex-access-20261011-173449`에 백업하고 `sudo usermod -aG openmediavault-admin ygreen0516`을 적용했습니다. 기존 그룹은 유지되었습니다.
- 웹 로그인 RPC는 변경 전 `role=user`, 변경 후 `role=admin`을 반환했습니다. 관리자 전용 `UserMgmt.getSettings` 요청도 성공했습니다.
- 사용자가 로그아웃·재로그인 후 시스템·저장소·서비스·사용자 메뉴가 나타나는 것을 확인했습니다.
- 연결된 브라우저 자동화 세션이 없어 웹 RPC와 사용자 확인으로 검증했습니다.

### Windows SMB 접근 변경 및 검증
- 기존 `KYRNAS1`, `KYRNAS2` 공유에서 사용자 및 같은 이름의 그룹이 `perms=0`(접근 금지)로 설정되어 있었습니다.
- OMV `ShareMgmt.setPrivilegesByRole`로 `ygreen0516` 사용자와 해당 그룹을 `perms=7`(읽기/쓰기)로 변경했습니다. 다른 계정의 권한은 유지했습니다.
- Samba 비밀번호를 사용자가 요청한 기존 로그인 정보와 일치하도록 동기화했습니다. 비밀번호·해시·세션 쿠키는 이 문서와 소스에 기록하지 않습니다.
- `Config.applyChanges`로 Samba 설정 적용에 성공했고, 생성된 설정의 허용 사용자 및 쓰기 목록에 대상 계정이 포함된 것을 확인했습니다.
- Windows의 기존 `Z:` IP 연결은 다른 자격정보를 사용하여 명시적 재접속 시 오류 `1219`를 반환했습니다. 기존 연결 교체 명령은 자동 승인 검토에서 차단되었으며 세부 사유는 제공되지 않았습니다. 기존 `Z:` 연결은 변경하지 않았습니다.
- 대체 호스트명 `\\yongroknas\KYRNAS1`, `\\yongroknas\KYRNAS2`로 명시적 계정 인증에 성공했습니다. Windows에서 새 임시 파일을 만들고 쓰기·읽기를 검증했습니다. `CreateNew`와 `DeleteOnClose`로 기존 파일을 건드리지 않고 검증 파일만 자동 정리했습니다.
- **위 SMB 검증은 아래 USB 장애 발생 전의 결과입니다. 현재는 저장장치 복구를 위해 SMB 서비스를 중지한 상태입니다.**

### 연결 디스크 조사 및 마운트 작업
| 장치(조사 당시) | 용량·모델 | 파일시스템 및 상태 |
| --- | --- | --- |
| `/dev/sda1` | 500GB WDC HDD | 기존 ext3. OMV 등록 및 마운트 성공. `KYRNAS3` 공유 객체 생성 후 USB 장애로 설정·검증 미완료 |
| `/dev/sdb1` | 128GB PHINOCOM SSD | 기존 ext4, `KYRNAS2`. 여유 공간 약 139MB, 사용률 100% 표시 |
| `/dev/sdd1` | 6TB Seagate HDD | 기존 NTFS, `KYRNAS1`. USB 재인식 후 장치명은 `/dev/sde1`로 변경됨 |
| `/dev/sdc` | 120GB SATAFIRM S11 SSD | 파티션·파일시스템 없음. 사용자 초기화 승인 후 GPT 생성 시도, 쓰기 정지로 ext4 생성 미완료 |
| `/dev/mmcblk0` | 32GB microSD | Pi 운영체제. 데이터 공유/초기화 대상에서 제외 |

- 기존 ext3·ext4·NTFS 데이터 디스크는 포맷하지 않았습니다. HDD의 기존 swap 파티션도 공유하지 않았습니다.
- 500GB 파일시스템 UUID: `7b9fae1d-b8cd-4dab-ba88-07ad011915bc`; 새 OMV 마운트 객체: `aee27ee9-92c4-4215-af9d-960d62da4b80`.
- 새 `KYRNAS3` 공유 객체: `f873789d-04a9-4d13-bd07-5f1f9a3be99c`. 최종 SMB 내보내기와 읽기/쓰기 시험은 아직 완료되지 않았습니다.
- 설정 및 Samba DB 백업: `/var/backups/codex-storage-20261011-175153` (root 전용). 백업 내용은 GitHub에 업로드하지 않습니다.

### USB 장애, 호환 설정 및 검사
- 사용자가 USB 연결·전원을 건드리지 않았다고 확인했습니다. 커널 로그에는 SSD 쓰기 명령과 UAS 명령 시간 초과, 장치 리셋, USB 허브/네 디스크 동시 연결 해제, 입출력 오류가 기록되었습니다.
- 실제 EON SATA 브리지 ID는 `1741:1156`, `174e:1155`입니다. 이 두 ID에 한해 `usb-storage.quirks=1741:1156:u,174e:1155:u`를 부팅 명령행과 실행 중인 드라이버 설정에 적용했습니다.
- 부팅 설정 백업: `/var/backups/codex-eon-usb-20261011-180827/cmdline.before.txt`. 기존 root 파티션 인수와 네트워크 설정은 유지했습니다.
- USB 컨트롤러를 재인식시키자 네 디스크가 돌아왔고, 두 브리지 모두 `Driver=usb-storage`로 확인되었습니다. 이는 복구 시점의 인식 결과이며 장기 안정성 검증을 의미하지 않습니다.
- 읽기 전용 `e2fsck -fn`으로 128GB ext4 검사 종료 코드 `0`, `ntfsfix -n`으로 6TB NTFS 검사 종료 코드 `0`을 확인했습니다.
- 500GB ext3의 읽기 전용 전체 검사는 USB 재정리 시 중단되어 종료 코드 `32`였습니다. 검사 완료나 파일시스템 정상 판정으로 기록하지 않습니다.
- 승인된 빈 120GB SSD만 by-id 경로·용량·모델·마운트/시그니처 부재를 재검증하여 초기화를 시도했습니다. UAS 중 최초 시도는 실패(종료 코드 `1`), 기본 USB 저장장치 드라이버에서도 재시도 쓰기가 정지하여 종료했습니다(종료 코드 `143`). ext4 생성은 실행 단계에 도달하지 못했습니다.
- 따라서 UAS 호환 설정만으로 문제가 해결되었다고 판단하지 않습니다. 120GB SSD와 EON의 SATA/전원 연결 경로를 분리해서 확인해야 합니다. SMART의 `PASSED` 표시만으로 실제 쓰기 가능성을 판정하지 않습니다.

### HDMI 후속 시험
- 사용자는 케이스를 Argon EON NAS 장비로 설명했습니다.
- `scripts/test-eon-hdmi.sh`로 두 포트에 1280×720 @60Hz 패턴을 임시 출력했고 KMS의 활성 CRTC와 프레임버퍼를 확인했습니다. 강제 `connected` 표시는 실제 연결 감지 성공과 구분했습니다.
- 사용자는 시험 중에도 **신호 없음**이라고 확인했습니다. 시험 후 자동 감지 상태로 복원하고 출력 패턴을 종료했습니다. HDMI 부팅 설정은 변경하지 않았습니다.
- HDMI 화면 복구는 미완료이며, 모듈 우회 직결·케이블·포트 비교 시험이 필요합니다.

### 현재 운영 상태와 남은 작업
- 저장장치 입출력 오류 후 SMB와 디스크를 사용하는 Portainer 컨테이너를 중지했습니다. 기존 데이터 파일시스템을 분리하고 USB 컨트롤러를 재정리했습니다. SSH와 OMV 웹 서비스는 실행 중입니다.
- 120GB SSD만 물리적으로 분리하는 현장 시험 가능 여부를 사용자에게 요청한 상태입니다. 저장장치 복구 후 마운트·공유 및 Windows 읽기/쓰기 검증을 다시 수행해야 합니다.
- 로컬 추가 소스: `scripts/test-eon-hdmi.sh`, `scripts/initialize-empty-ssd.sh`, `scripts/configure-data-share.py`, `scripts/enable-eon-usb-compatibility.py`. Bash 구문 검사와 Python 컴파일 검사를 수행하고 Pi에 복사했습니다.
- 사용자 요청에 따라 **모든 작업 완료 후 최종 GitHub 반영**을 진행합니다. 이 진행 기록과 신규 소스는 아직 최종 배포하지 않았습니다.
- 참고: [OMV 사용자 권한](https://docs.openmediavault.org/en/8.x/administration/users.html), [Linux USB quirks](https://www.kernel.org/doc/html/v4.15/admin-guide/kernel-parameters.html?highlight=usb-storage.quirks), [EON UAS 관련 제조사 포럼](https://forum.argon40.com/t/raid-not-working-with-uas/913).

## 2026-10-11 18:32:02 +09:00 — 데이터 디스크 3개 및 Windows 공유 복구

### 최신 운영 상태
- 초기화 쓰기가 반복해서 멈추는 120GB SSD의 EON 브리지 `1741:1156` LUN 0을 이번 부팅에서만 `offline`으로 격리했습니다. 해당 장치를 포맷 완료 또는 정상 활성화로 처리하지 않습니다.
- `scripts/recover-eon-without-failing-ssd.sh`로 USB 컨트롤러를 복구하고, 격리된 SSD를 제외한 기존 세 디스크를 다시 인식시켰습니다. 일시 정지한 udev 실행 큐도 재개했습니다.
- 500GB ext3와 128GB ext4에 `e2fsck -p`를 실행해 저널 복구 후 `clean`, 종료 코드 `0`을 확인했습니다. 이는 앞서 중단된 강제 읽기 전용 전체 검사와 별개의 결과입니다.
- 기존 ext3·ext4·NTFS 볼륨 3개를 영구 OMV 마운트 설정으로 다시 마운트했습니다. 모두 읽기/쓰기 모드입니다.
- **SMB, SSH, OMV nginx, Docker 서비스를 재개하여 모두 `active`임을 확인했습니다.**

| Windows 공유 | 대상 | 마운트/공유 상태 | 남은 공간(확인 당시) |
| --- | --- | --- | --- |
| `\\192.168.0.30\KYRNAS1` | 6TB Seagate NTFS의 기존 `KYRNAS1` 폴더 | 읽기/쓰기 정상 | 약 5.4TB |
| `\\192.168.0.30\KYRNAS2` | 128GB PHINOCOM ext4의 기존 `KYRNAS2` 폴더 | 읽기/쓰기 정상 | 약 139MB, 100% 사용 표시 |
| `\\192.168.0.30\KYRNAS3` | 500GB WDC ext3 볼륨 | 읽기/쓰기 정상 | 약 18GB, 97% 사용 표시 |

### 권한과 최종 검증
- 세 공유 모두 `ygreen0516` 사용자와 해당 그룹의 OMV 권한을 읽기/쓰기(`7`)로 설정했습니다.
- 사용자가 요청한 전체 파일 접근 권한을 위해 각 공유의 `admin users = ygreen0516`를 OMV SMB 설정에 등록했습니다. 해당 계정은 선택된 공유 안에서 관리자 파일 작업을 수행할 수 있습니다. 다른 계정의 공유 권한과 기존 파일 소유권을 일괄 변경하지 않았습니다.
- Windows 자격 증명 관리자의 `yongroknas`, `192.168.0.30` 대상에 요청한 NAS 계정 정보를 저장했습니다. 기존 `Z:` 매핑을 제거하지 않고 IP 경로 접근 문제를 해결했습니다.
- Windows에서 **IP 주소를 사용한 세 공유 모두** 새 임시 파일 생성·쓰기·읽기를 검증했습니다. `CreateNew`/`DeleteOnClose`로 검증 파일만 자동 정리했습니다. 호스트명 경로 세 개도 같은 검증을 통과했습니다.
- `testparm` 종료 코드 `0`, OMV 웹 HTTP `200`을 확인했습니다.
- 저장장치 변경으로 발생한 `sharedfolders`, `systemd`, `collectd`, `monit`, `quota`, `avahi` 모듈 설정을 적용했습니다. 종료 코드 `0`, OMV 미적용 모듈 목록 `[]`를 확인했습니다.
- 중지했던 Portainer 컨테이너의 재시작 중 기존 Docker 네트워크 엔드포인트 충돌이 발생했습니다. 해당 컨테이너의 네트워크 연결을 정리하고, 재마운트된 Docker 데이터 경로를 정상적으로 다시 열도록 Docker 서비스를 재시작했습니다. `portainerce-nginx-1`이 `running`으로 복구되었습니다. 컨테이너와 볼륨 데이터는 삭제하지 않았습니다.
- NAS root/boot microSD와 네트워크 주소는 유지했습니다. 프로그램 신규 소스의 Bash 구문 검사와 Python 컴파일 검사 및 원격 사본 SHA-256 비교를 수행했습니다.

### 여전히 미완료인 항목
- **120GB SSD:** 초기화 승인 상태이지만 실제 쓰기 요청이 멈춰 ext4 생성·마운트·공유를 완료하지 못했습니다. SSD 자체 또는 해당 SATA 슬롯/연결 경로의 물리적 분리 시험이 필요합니다.
- SSD 격리는 **현재 부팅에만 적용**됩니다. 재부팅하면 장치가 다시 인식될 수 있으므로, 정상 종료 후 문제 SSD만 분리한 상태에서 나머지 디스크를 확인해야 합니다.
- **HDMI:** 두 포트 강제 720p 출력에도 사용자 화면이 신호 없음입니다. EON 확장 보드를 우회한 Pi 직결, 케이블, 모니터 입력 비교가 필요합니다.
- **최종 GitHub 반영:** 전체 작업 완료 후 업로드하라는 요청에 따라 현재 신규 소스와 후속 보고서는 로컬 및 Pi에 보관하며, 최종 업로드는 대기합니다. 이미 반영된 이전 고정 IP/HDMI 진단 문서 커밋은 유지합니다.

## 2026-10-11 18:52:05 +09:00 — 물리 분리가 어려운 SSD의 자동 격리 규칙

- 사용자가 지금 120GB SSD를 물리적으로 분리할 수 없다고 답변했습니다. 정상인 세 디스크의 서비스를 유지하고, SSD 초기화·물리 점검은 미완료로 유지합니다.
- 로컬 `config/55-eon-failing-ssd.rules`를 먼저 작성한 후 Pi의 `/etc/udev/rules.d/55-eon-failing-ssd.rules`에 설치했습니다. 부팅 및 장치 변경 이벤트에서 문제 슬롯을 격리하도록 설정했습니다.
- 대상 조건은 EON 브리지 `1741:1156`, SCSI LUN `0`, 용량 `234441648` 섹터(120GB)입니다. `/dev/sdc` 같은 변동 가능한 장치 이름으로 규칙을 작성하지 않았습니다.
- 규칙은 해당 장치의 SCSI 상태를 `offline`으로 설정하고, `UDEV_DISABLE_PERSISTENT_STORAGE_RULES_FLAG=1`로 ATA/파일시스템 자동 탐색을 건너뛰며 `UDISKS_IGNORE=1`을 지정합니다. 이 규칙은 관찰된 슬롯과 용량에 대한 격리 정책이며 SSD 불량을 확정하거나 하드웨어를 수리하는 작업은 아닙니다.
- 설치 전 상태 및 테스트 로그 보관 위치: `/var/backups/codex-eon-quarantine-20261011-184820` (root 전용).
- 초기 규칙 시험에서 SCSI 상태 속성이 줄바꿈을 요구해 쓰기 오류가 나타났습니다. 설치된 udev 247 설명서와 커널 동작에 맞춰 `e"offline\n"`을 사용하도록 수정한 뒤 재시험에서 규칙 오류가 없음을 확인했습니다.

| udev add 이벤트 시험 | 종료 코드 | 격리 규칙 매칭 | 상태 |
| --- | --- | --- | --- |
| 문제 120GB SSD (`sdc`) | `0` | 예 | `offline` |
| 정상 500GB HDD (`sda`) | `0` | 아니오 | `running` |
| 정상 128GB SSD (`sdb`) | `0` | 아니오 | `running` |
| 정상 6TB HDD (`sde`) | `0` | 아니오 | `running` |
| 운영체제 microSD (`mmcblk0`) | `0` | 아니오 | 격리 대상 아님 |

- 규칙 재로드 후 **해당 SSD에만** 실제 change 이벤트를 적용했습니다. 종료 코드 `0`, `EON_SSD_QUARANTINED=1`, 자동 탐색 생략 플래그 및 `offline` 상태를 확인했습니다.
- 로컬 규칙, Pi 작업 사본, 설치된 규칙의 SHA-256이 모두 일치했습니다.
- 적용 후에도 SMB·SSH·OMV nginx·Docker는 모두 `active`, 기존 Portainer 컨테이너는 실행 중입니다. 세 데이터 볼륨은 읽기/쓰기 모드로 마운트되어 있습니다.
- Windows에서 IP 주소 경로의 `KYRNAS1`, `KYRNAS2`, `KYRNAS3` 임시 파일 쓰기·읽기를 재검증했고 모두 통과했습니다.
- **실제 재부팅 시험은 하지 않았습니다.** 부팅 시 add 이벤트를 처리하는 영구 규칙을 설치하고 해당 이벤트 매칭을 검사했으며, 재부팅 후 결과를 검증한 것으로 기록하지 않습니다.
- SSD/해당 슬롯을 수리하거나 교체하여 다시 사용하려면 이 격리 규칙을 해제한 상태에서 점검해야 합니다. 현재는 추가 초기화·쓰기 시험을 진행하지 않습니다.
- HDMI 화면 복구와 SSD 활성화가 남아 있으므로, 전체 완료 후 GitHub에 반영하라는 요청에 따라 최종 업로드는 계속 대기합니다.

## 2026-10-15 22:24:18 +09:00 — 소스 설명 주석 보강 및 GitHub 반영 정리

### 변경 내역
- 현재 소스에 설명 주석을 달고 Git에 올려 달라는 최신 요청에 따라, 기존 업로드 대기 방침을 이번 소스·작업 기록 반영 요청으로 갱신했습니다. SSD·HDMI 미완료 항목은 그대로 기록합니다.
- `scripts/configure-data-share.py`: OMV 마운트 객체 UUID, 대상 볼륨 확인, 기존 권한 보존, SMB 설정 재사용, 선택적 관리자 접근과 설정 적용 흐름을 한국어로 설명했습니다.
- `scripts/enable-eon-usb-compatibility.py`: 장치 ID 범위, 백업, 기존 quirk 병합, UAS 제외 플래그, 부팅 파일 교체와 실행 중 설정의 차이를 설명했습니다.
- `scripts/initialize-empty-ssd.sh`: 인수, by-id·용량·모델 확인, 시스템 디스크·기존 데이터 제외, 실제 파티션/파일시스템 생성 지점을 설명했습니다.
- `scripts/recover-eon-without-failing-ssd.sh`: 장비별 전제 조건, udev 큐 정지·재개, 컨트롤러 연결과 일시적인 SSD 슬롯 격리를 설명했습니다.
- `scripts/test-eon-hdmi.sh`: 시간 제한, DRM 포트 확인, 강제 출력, 종료·신호 처리 시 자동 감지 복원과 시험 결과의 의미를 설명했습니다.
- `config/55-eon-failing-ssd.rules`: 브리지·LUN·용량 조합의 매칭 범위, sysfs 상태 쓰기, udev/UDisks 플래그와 교체 장치에도 규칙이 적용되는 조건을 설명했습니다.
- 소스 6개 모두 기존 작성 시각을 유지하고 이번 설명 주석 보강 시각을 추가했습니다. 실행 코드와 설정 값은 바꾸지 않았습니다.
- `README.md`에 소스 안내와 작업 기록 링크를 추가하고 접속 비밀번호를 제거했습니다. `.gitignore`로 로컬 접속 메모 `codexCode.md` 및 Python 캐시를 제외하고, `.gitattributes`로 Pi용 소스의 LF 줄바꿈을 유지합니다.
- 기존 미커밋 소스·설정 및 관련 작업 기록을 이번 반영 범위에 포함합니다. 자격정보 메모와 NAS의 비공개 백업은 포함하지 않습니다.

### 검증 결과와 범위
- Python 2개: 로컬 Python의 `compile(..., 'exec')` 구문 검사 통과. 수정 전후 AST 및 주석을 제외한 실행 토큰이 일치했습니다.
- Bash 3개: Git Bash의 `bash -n` 구문 검사 통과. 수정 전후 주석·빈 줄을 제외한 실행 행이 일치했습니다.
- udev 규칙 1개: 수정 전후 주석·빈 줄을 제외한 규칙 행이 일치했습니다. 이번에는 실제 udev 이벤트를 재실행하지 않았습니다.
- Bash·udev 파일의 LF 줄바꿈 및 `git diff --check` 검사를 통과했습니다.
- 이번 작업은 로컬 소스 설명과 저장소 반영입니다. NAS에서 초기화·장치 복구·HDMI 출력·재부팅을 다시 수행하지 않았으며 장비의 최신 상태를 재검증한 것으로 해석하지 않습니다.
