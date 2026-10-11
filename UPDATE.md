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
