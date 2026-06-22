#!/usr/bin/env python3

import socket
from pathlib import Path
from PIL import Image

FPGA_IP = "192.168.1.128"
FPGA_PORT = 5678
LOCAL_PORT = 1234

IMAGE_PATH = "images/Landscape.jpg"
ORIGINAL_OUTPUT_IMAGE = "output/original_img.png"
OBTAINED_OUTPUT_IMAGE = "output/obtained_img.png"

IMAGE_WIDTH = 6000
IMAGE_HEIGHT = 4000

CHUNK_SIZE = 1024
TIMEOUT_SECONDS = 2.0

def image_to_bytes(image_path: str) -> bytes:
  image_path = Path(image_path)
  original_output_path = Path(ORIGINAL_OUTPUT_IMAGE)

  if not image_path.exists():
    raise FileNotFoundError(f"Image not found: {image_path}")
  
  if not original_output_path.exists():
    original_output_path.parent.mkdir(parents=True, exist_ok=True)


  img = Image.open(image_path)
  img = img.convert("L")
  img = img.resize((IMAGE_WIDTH, IMAGE_HEIGHT), Image.Resampling.LANCZOS)
  img.save(ORIGINAL_OUTPUT_IMAGE)

  return img.tobytes()

def bytes_to_image(data: bytes, output_path: str):
  expected_size = IMAGE_WIDTH * IMAGE_HEIGHT

  if len(data) != expected_size:
    raise ValueError(
      f"Invalid image byte size: {len(data)} bytes. "
      f"Expected {expected_size} bytes."
    )

  img = Image.frombytes("L", (IMAGE_WIDTH, IMAGE_HEIGHT), data)
  img.save(output_path)

def split_chunks(data: bytes, chunk_size: int):
  for offset in range(0, len(data), chunk_size):
    yield offset, data[offset:offset + chunk_size]

def main():
  tx_image_bytes = image_to_bytes(IMAGE_PATH)

  expected_size = IMAGE_WIDTH * IMAGE_HEIGHT

  if len(tx_image_bytes) != expected_size:
    raise RuntimeError(
      f"Invalid TX image size: {len(tx_image_bytes)} != {expected_size}"
    )

  print("Image Ethernet transfer test")
  print(f"FPGA address : {FPGA_IP}:{FPGA_PORT}")
  print(f"Local port   : {LOCAL_PORT}")
  print(f"Image size   : {IMAGE_WIDTH}x{IMAGE_HEIGHT}")
  print(f"Payload size : {len(tx_image_bytes)} bytes")
  print(f"Chunk size   : {CHUNK_SIZE} bytes")
  print(f"Saved original image as: {ORIGINAL_OUTPUT_IMAGE}\n")

  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  sock.settimeout(TIMEOUT_SECONDS)
  sock.bind(("", LOCAL_PORT))

  rx_image_bytes = bytearray()

  chunks = list(split_chunks(tx_image_bytes, CHUNK_SIZE))
  total_chunks = len(chunks)

  print(f"Sending {total_chunks} chunks...")

  try:
    for index, (offset, tx_chunk) in enumerate(chunks):
      sock.sendto(tx_chunk, (FPGA_IP, FPGA_PORT))

      print(
        f"\nSent chunk {index + 1:04d}/{total_chunks}: "
        f"offset={offset:06d}, size={len(tx_chunk)}"
      )

      try:
        rx_chunk, rx_address = sock.recvfrom(CHUNK_SIZE)

        print(
          f"Received chunk {index + 1:04d}/{total_chunks}: "
          f"from={rx_address[0]}:{rx_address[1]}, "
          f"size={len(rx_chunk)}"
        )

        rx_image_bytes.extend(rx_chunk)

      except socket.timeout:
        print(f"Timeout waiting for response chunk {index + 1}")
        break

  finally:
    sock.close()

  print("\n=================== RESULT ===========================")
  print(f"Received total: {len(rx_image_bytes)} bytes")

  if len(rx_image_bytes) >= expected_size:
    rx_image_bytes = rx_image_bytes[:expected_size]

    bytes_to_image(
      bytes(rx_image_bytes),
      OBTAINED_OUTPUT_IMAGE
    )

    print(f"Saved obtained image as: {OBTAINED_OUTPUT_IMAGE}")

    if bytes(rx_image_bytes) == tx_image_bytes:
      print("PASS: obtained image bytes match original image bytes")
    else:
      print("FAIL: obtained image bytes are different from original image bytes")

  else:
    print(
      "FAIL: not enough received data to rebuild image. "
      f"Expected {expected_size} bytes, got {len(rx_image_bytes)} bytes."
    )
  
  print("=========================================================")

if __name__ == "__main__":
  main()