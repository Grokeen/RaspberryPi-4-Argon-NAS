# RaspberryPi-4-Argon-NAS

Raspberry Pi 4와 Argon EON NAS의 저장장치·OMV 공유·HDMI 유지보수 소스 및 작업 기록입니다.

## 소스 안내

각 소스에 작성 시각, 사용법, 처리 순서와 대상 장치 확인 조건을 한국어 주석으로 적었습니다.

| 파일 | 역할 |
| --- | --- |
| [configure-data-share.py](scripts/configure-data-share.py) | OMV 데이터 볼륨의 SMB 공유와 계정 권한 설정 |
| [enable-eon-usb-compatibility.py](scripts/enable-eon-usb-compatibility.py) | 관찰된 EON 브리지 두 종류에 USB 저장장치 호환 설정 적용 |
| [initialize-empty-ssd.sh](scripts/initialize-empty-ssd.sh) | 승인된 빈 SSD의 장치 정보를 확인한 뒤 GPT·ext4 생성 |
| [recover-eon-without-failing-ssd.sh](scripts/recover-eon-without-failing-ssd.sh) | 분리해 둔 USB 컨트롤러 복구 및 문제 SSD 슬롯 임시 격리 |
| [test-eon-hdmi.sh](scripts/test-eon-hdmi.sh) | 제한 시간 동안 두 HDMI 포트 시험 출력 후 자동 감지 복원 |
| [55-eon-failing-ssd.rules](config/55-eon-failing-ssd.rules) | 관찰된 문제 SSD 슬롯의 udev 자동 격리 규칙 |

이 소스는 해당 NAS에서 확인한 OMV 환경·장치 식별자·경로를 전제로 합니다. 실행 조건과 시스템 변경 범위는 각 파일의 주석을 확인하세요. SSD 초기화와 HDMI 물리 연결 문제는 아직 해결되지 않았으며, 최신 장비 확인 결과는 2026-10-11 기록 기준입니다.

## 접속

```sh
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no ygreen0516@192.168.0.30
```

비밀번호는 저장소에 기록하지 않습니다. 로컬 접속 메모 `codexCode.md`는 Git 추적에서 제외합니다.

## 작업 기록

- [WORK_SUMMARY.md](WORK_SUMMARY.md): 작업 상태와 남은 항목
- [UPDATE.md](UPDATE.md): 날짜별 변경 내역과 검증 결과
- [OWERORDER.md](OWERORDER.md): 간단한 작업 보고와 테스트 방법
