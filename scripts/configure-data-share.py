#!/usr/bin/env python3
# 작성: 2026-10-11 18:00:36 +09:00 / 설명 주석 보강: 2026-10-15 22:21:34 +09:00
# OMV에 등록·마운트된 데이터 볼륨을 지정한 계정의 읽기/쓰기 SMB 공유로 구성한다.
# 사용법: sudo python3 configure-data-share.py MOUNT_UUID SHARE_NAME USERNAME [--full-access]
# MOUNT_UUID는 파일시스템 UUID가 아니라 OMV 마운트 설정 객체의 uuid이다.
# 기존 다른 계정의 권한은 유지하며, 비밀번호는 입력받거나 저장하지 않는다.
# --full-access는 선택한 공유 안에서 해당 계정에 Samba 관리자 파일 접근을 부여한다.
import argparse
import json
import os
import pwd
import re
import stat
import subprocess


def rpc(service, method, params):
    # OMV RPC의 매개변수를 JSON으로 전달하고, RPC 오류와 프로세스 실패를 확인한다.
    result = subprocess.run(
        ["omv-rpc", service, method, json.dumps(params)],
        text=True, capture_output=True,
    )
    value = json.loads(result.stdout)
    if isinstance(value, dict) and value.get("error"):
        raise RuntimeError(value["error"]["message"])
    result.check_returncode()
    return value


def objects(model):
    # OMV 설정 DB의 모델별 객체 목록을 읽는다. 설정 변경은 이 함수에서 수행하지 않는다.
    return json.loads(subprocess.check_output(
        ["omv-confdbadm", "read", model], text=True,
    ))


def main():
    # 공유 구성에는 root 권한과 실제로 존재하는 Linux 계정이 필요하다.
    parser = argparse.ArgumentParser()
    parser.add_argument("mount_uuid")
    parser.add_argument("name")
    parser.add_argument("username")
    parser.add_argument("--full-access", action="store_true")
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise RuntimeError("Run this script as root.")
    if not re.fullmatch(r"[a-z_][a-z0-9_-]*", args.username):
        raise ValueError("Invalid account name.")
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.name):
        raise ValueError("Invalid share name.")
    pwd.getpwnam(args.username)
    # OMV 마운트 객체를 찾아 숨김 볼륨·루트 경로·미마운트 경로를 거부한다.
    # 연결이 끊긴 데이터 디스크의 빈 마운트 디렉터리를 공유하지 않도록 장치도 확인한다.
    mount = next(m for m in objects("conf.system.filesystem.mountpoint")
                 if m["uuid"] == args.mount_uuid)
    if mount["hidden"] or os.path.realpath(mount["dir"]) == "/" or not os.path.ismount(mount["dir"]):
        raise RuntimeError("Expected an active data filesystem, not the system volume.")
    if not os.path.exists(mount["fsname"]) or not stat.S_ISBLK(os.stat(mount["fsname"]).st_mode):
        raise RuntimeError("The data disk is disconnected; no share changes made.")
    # 신규 객체 등록에 필요한 특수 UUID 값을 현재 OMV 설치 환경에서 조회한다.
    new_uuid = subprocess.check_output([
        "php", "-r",
        'require "/usr/share/php/openmediavault/autoloader.inc"; '
        'require "/usr/share/php/openmediavault/env.inc"; '
        'echo \\OMV\\Environment::get("OMV_CONFIGOBJECT_NEW_UUID");',
    ], text=True).strip()
    shared_folders = objects("conf.system.sharedfolder")
    folder = next((s for s in shared_folders if s["name"] == args.name), None)
    # 같은 이름의 공유는 재사용하되 다른 볼륨을 가리키면 중단한다.
    # 새 공유의 상대 경로 '/'는 위에서 확인한 데이터 볼륨의 최상위 경로를 뜻한다.
    if folder is None:
        folder = rpc("ShareMgmt", "set", {
            "uuid": new_uuid, "name": args.name, "mntentref": args.mount_uuid,
            "reldirpath": "/", "comment": "2026-10-11: NAS data disk", "mode": "775",
        })
    elif folder["mntentref"] != args.mount_uuid:
        raise RuntimeError("Existing share name belongs to another volume.")
    # 정수 권한이 있는 기존 항목을 보존하고 대상 사용자 및 동명 그룹만 perms=7로 갱신한다.
    # 동명 그룹이 없으면 그룹 항목은 추가하지 않는다. 기존 파일의 소유권은 바꾸지 않는다.
    privileges = rpc("ShareMgmt", "getPrivileges", {"uuid": folder["uuid"]})
    privileges = [{k: p[k] for k in ("type", "name", "perms")}
                  for p in privileges if isinstance(p["perms"], int)]
    for role in ("user", "group"):
        if role == "group":
            import grp
            try:
                grp.getgrnam(args.username)
            except KeyError:
                continue
        entry = next((p for p in privileges if p["type"] == role and p["name"] == args.username), None)
        if entry is None:
            entry = {"type": role, "name": args.username, "perms": 7}
            privileges.append(entry)
        entry["perms"] = 7
    rpc("ShareMgmt", "setPrivileges", {"uuid": folder["uuid"], "privileges": privileges})
    # 기존 SMB 내보내기를 재사용한다. 새로 만들 때는 첫 SMB 공유의 설정을 복사하므로
    # OMV에 SMB 공유가 하나 이상 등록되어 있어야 한다.
    shares = objects("conf.service.smb.share")
    smb_share = next((s for s in shares if s["sharedfolderref"] == folder["uuid"]), None)
    if smb_share is None:
        smb_share = dict(shares[0])
        smb_share.update(uuid=new_uuid, sharedfolderref=folder["uuid"], guest="no")
    smb_share.update(enable=True, browseable=True, readonly=False)
    if args.full_access:
        # 기존 admin users 목록에 대상 계정만 추가하고 다른 추가 옵션과 계정은 유지한다.
        lines = smb_share["extraoptions"].splitlines()
        admin_line = next((i for i, line in enumerate(lines)
                           if re.match(r"\s*admin\s+users\s*=", line, re.I)), None)
        if admin_line is None:
            lines.append("admin users = " + args.username)
        elif args.username not in lines[admin_line].split("=", 1)[1].split():
            lines[admin_line] += " " + args.username
        smb_share["extraoptions"] = "\n".join(lines)
    # OMV 설정 DB에 저장한 뒤 Samba 모듈을 적용하고 구성 결과를 JSON으로 출력한다.
    # read_write는 설정한 접근 모드이며 실제 클라이언트 파일 쓰기 검증 결과는 아니다.
    rpc("SMB", "setShare", smb_share)
    rpc("Config", "applyChanges", {"modules": ["samba"], "force": False})
    share_path = os.path.join(mount["dir"], folder["reldirpath"].lstrip("/"))
    print(json.dumps({"share": args.name, "path": share_path,
                      "username": args.username, "read_write": True,
                      "full_share_access": args.full_access}))


if __name__ == "__main__":
    main()
