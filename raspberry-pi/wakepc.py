#!/usr/bin/env python3
"""Wake-on-LAN の Magic Packet を LAN 内にブロードキャスト送信する。

使い方:
    python3 wakepc.py AA:BB:CC:DD:EE:FF
    python3 wakepc.py AA:BB:CC:DD:EE:FF --broadcast 192.168.0.255

MAC アドレスは引数、または環境変数 WAKEPC_MAC で指定する。
"""

import argparse
import os
import re
import socket
import sys

MAC_PATTERN = re.compile(r"^[0-9A-Fa-f]{2}([:-]?)[0-9A-Fa-f]{2}(\1[0-9A-Fa-f]{2}){4}$")


def parse_mac(mac: str) -> bytes:
    """'AA:BB:CC:DD:EE:FF' / 'AA-BB-...' / 'AABBCC...' 形式を 6 バイトに変換する。"""
    mac = mac.strip()
    if not MAC_PATTERN.match(mac):
        raise ValueError(f"MAC アドレスの形式が正しくありません: {mac!r}")
    return bytes.fromhex(re.sub(r"[:-]", "", mac))


def build_magic_packet(mac: bytes) -> bytes:
    """Magic Packet = 0xFF × 6 + MAC アドレス × 16（計 102 バイト）。"""
    if len(mac) != 6:
        raise ValueError("MAC アドレスは 6 バイトである必要があります")
    return b"\xff" * 6 + mac * 16


def send_magic_packet(packet: bytes, broadcast: str, port: int) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(packet, (broadcast, port))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Wake-on-LAN Magic Packet を送信する")
    parser.add_argument("mac", nargs="?", default=os.environ.get("WAKEPC_MAC"),
                        help="起動する PC の MAC アドレス（省略時は環境変数 WAKEPC_MAC）")
    parser.add_argument("--broadcast", default=os.environ.get("WAKEPC_BROADCAST", "255.255.255.255"),
                        help="送信先ブロードキャストアドレス（例: 192.168.0.255）")
    parser.add_argument("--port", type=int, default=9, help="送信先 UDP ポート（既定: 9）")
    args = parser.parse_args(argv)

    if not args.mac:
        parser.error("MAC アドレスを引数か環境変数 WAKEPC_MAC で指定してください")

    try:
        packet = build_magic_packet(parse_mac(args.mac))
    except ValueError as e:
        parser.error(str(e))

    send_magic_packet(packet, args.broadcast, args.port)
    print("sent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
