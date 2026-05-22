from serial import serialutil
import argparse
import serial
import time
from PIL import Image


WIDTH = 320
HEIGHT = 240
BAUD = 115200

RETRY_DELAY = 0.3
UART_WRITE_CHUNK = 32
INTER_CHUNK_DELAY = 0.001

# ==========================================================
# PACKET FORMAT
# ==========================================================
#
#   HEADER : AA
#   DATA   : 256 bytes
#   CRC8   : 1 byte
#
# ==========================================================

HEADER = 0xAA

PACKET_DATA_SIZE = 256

ACK  = 0x06
NACK = 0x15

MAX_RETRY  = 10
ACK_TIMEOUT = 5.0


# ==========================================================
# RGB888 -> RGB565
# ==========================================================

def rgb888_to_rgb565(r, g, b):
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)


# ==========================================================
# CRC8
# POLY = 0x07
# INIT = 0xFF
# Must match Verilog crc8()
# ==========================================================

def crc8(data: bytes, init_crc=0xFF):

    crc = init_crc

    for byte in data:

        crc ^= byte

        for _ in range(8):

            if crc & 0x80:
                crc = ((crc << 1) & 0xFF) ^ 0x07
            else:
                crc = (crc << 1) & 0xFF

    return crc & 0xFF


# ==========================================================
# IMAGE -> RGB565 BYTES
# ==========================================================

def image_to_rgb565_bytes(img):

    raw = bytearray()

    for y in range(HEIGHT):
        for x in range(WIDTH):

            r, g, b = img.getpixel((x, y))

            rgb565 = rgb888_to_rgb565(r, g, b)

            raw.append((rgb565 >> 8) & 0xFF)
            raw.append(rgb565 & 0xFF)

    return raw


# ==========================================================
# BUILD PACKET
# FORMAT:
#   AA + 256 BYTE DATA + CRC8
# ==========================================================

def build_packet(data_chunk: bytes):

    if len(data_chunk) != PACKET_DATA_SIZE:
        raise ValueError("Data chunk must be exactly 256 bytes")

    crc = crc8(data_chunk)

    packet = bytearray()

    packet.append(HEADER)

    packet.extend(data_chunk)

    packet.append(crc)

    return packet, crc


# ==========================================================
# WAIT ACK/NACK
# ==========================================================

def wait_ack(ser):

    start = time.time()

    while (time.time() - start) < ACK_TIMEOUT:

        if ser.in_waiting > 0:

            resp = ser.read(1)

            if len(resp) == 1:
                return resp[0]

        time.sleep(0.01)

    return None


# ==========================================================
# SEND PACKET WITH RETRY
# ==========================================================

def send_packet_with_retry(
    ser,
    packet: bytes,
    packet_index: int,
    total_packets: int
):

    for attempt in range(1, MAX_RETRY + 1):

        print(
            f"[INFO] Packet {packet_index + 1}/{total_packets} "
            f"- Attempt {attempt}/{MAX_RETRY}"
        )

        # clear stale RX
        ser.reset_input_buffer()

        # Send in small chunks: avoids one-byte OS scheduling gaps, while
        # keeping the USB-UART FIFO from getting one large opaque burst.
        for offset in range(0, len(packet), UART_WRITE_CHUNK):
            ser.write(packet[offset:offset + UART_WRITE_CHUNK])
            ser.flush()
            time.sleep(INTER_CHUNK_DELAY)

        # wait response
        resp = wait_ack(ser)

        if resp == ACK:

            print(
                f"[INFO] Packet {packet_index + 1}/{total_packets}: ACK"
            )

            return True

        elif resp == NACK:

            print(
                f"[WARN] Packet {packet_index + 1}/{total_packets}: "
                f"NACK -> retry"
            )

            time.sleep(RETRY_DELAY)

        else:

            print(
                f"[WARN] Packet {packet_index + 1}/{total_packets}: "
                f"ACK timeout -> retry"
            )

            time.sleep(RETRY_DELAY)

    return False


# ==========================================================
# MAIN
# ==========================================================

def main():

    parser = argparse.ArgumentParser(
        description="UART image sender using CRC8 + ACK/NACK"
    )

    parser.add_argument(
        "--path",
        required=True,
        help="Image path"
    )

    parser.add_argument(
        "--port",
        required=True,
        help="UART port"
    )

    args = parser.parse_args()

    # ======================================================
    # LOAD IMAGE
    # ======================================================

    print(f"[INFO] Opening image: {args.path}")

    img = Image.open(args.path).convert("RGB")

    img = img.resize((WIDTH, HEIGHT))

    print(f"[INFO] Image resized to {WIDTH}x{HEIGHT}")

    raw_data = image_to_rgb565_bytes(img)

    total_bytes = len(raw_data)

    total_packets = total_bytes // PACKET_DATA_SIZE

    print(f"[INFO] Total bytes   : {total_bytes}")
    print(f"[INFO] Total packets : {total_packets}")

    # ======================================================
    # UART
    # ======================================================

    ser = serial.Serial(
        port=args.port,
        baudrate=BAUD,
        timeout=0.1,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE
    )

    print(f"[INFO] UART opened : {args.port}")
    print(f"[INFO] Baudrate    : {BAUD}")

    start_time = time.time()

    # ======================================================
    # SEND
    # ======================================================

    for packet_index in range(total_packets):

        start = packet_index * PACKET_DATA_SIZE
        end   = start + PACKET_DATA_SIZE

        data_chunk = raw_data[start:end]

        packet, crc = build_packet(data_chunk)

        print(
            f"[INFO] Build packet "
            f"{packet_index + 1}/{total_packets} "
            f"(CRC8 = 0x{crc:02X})"
        )

        ok = send_packet_with_retry(
            ser,
            packet,
            packet_index,
            total_packets
        )

        if not ok:

            print(
                f"[ERROR] Packet "
                f"{packet_index + 1}/{total_packets} failed"
            )

            ser.close()
            return

    # ======================================================
    # DONE
    # ======================================================

    elapsed = time.time() - start_time

    ser.close()

    print("[INFO] ====================================")
    print("[INFO] Transmission completed")
    print(f"[INFO] Total packets : {total_packets}")
    print(f"[INFO] Total bytes   : {total_bytes}")
    print(f"[INFO] Elapsed time  : {elapsed:.2f} s")
    print(f"[INFO] Throughput    : {total_bytes / elapsed:.2f} B/s")
    print("[INFO] ====================================")


if __name__ == "__main__":
    main()
