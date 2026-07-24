#!/usr/bin/env python
"""
Backend startup script for PhycoSense API
"""
import os
import sys
import logging

# Add backend directory to path
sys.path.insert(0, os.path.dirname(__file__))

from app.main import app
import uvicorn
import subprocess
import platform
import time
import socket

if __name__ == "__main__":
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    logger = logging.getLogger(__name__)
    logger.info("Starting PhycoSense Backend API Server...")
    
    def _is_port_free(host: str, port: int) -> bool:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            s.bind((host, port))
            s.close()
            return True
        except OSError:
            return False

    def _kill_process_using_port(port: int):
        if platform.system().lower() != "windows":
            return
        try:
            out = subprocess.check_output(f'netstat -ano | findstr :{port}', shell=True, text=True)
        except subprocess.CalledProcessError:
            return
        pids = set()
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 5 and parts[3].upper() == 'LISTENING':
                try:
                    pid = int(parts[-1])
                    pids.add(pid)
                except ValueError:
                    continue
        for pid in pids:
            try:
                logger.info(f"Killing process {pid} using port {port}")
                subprocess.check_call(['taskkill', '/PID', str(pid), '/F', '/T'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                logger.warning(f"Failed to kill process {pid}")

    host = "0.0.0.0"
    port = 8000

    # If port is occupied, attempt to free it (Windows only). This helps when
    # previous runs left a Python process bound to the port.
    if not _is_port_free(host, port):
        logger.info(f"Port {port} appears in use, attempting to free it...")
        _kill_process_using_port(port)
        # give OS a moment to release
        time.sleep(1)
        if not _is_port_free(host, port):
            logger.error(f"Port {port} is still in use after attempted cleanup. Aborting.")
            sys.exit(1)

    # Run server using the app object directly. This avoids uvicorn
    # re-importing the module which can cause duplicate processes on Windows.
    uvicorn.run(
        app,
        host=host,
        port=port,
        reload=False,
        log_level="info"
    )
