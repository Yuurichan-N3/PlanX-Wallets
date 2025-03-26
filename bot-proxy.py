import requests
import json
import time
import base64
from concurrent.futures import ThreadPoolExecutor
from rich.console import Console
from rich.logging import RichHandler
from rich.progress import Progress, TextColumn, BarColumn, TimeRemainingColumn
import logging
from typing import Tuple, Optional, List, Dict
import random
import socks
import socket
import sys

# Inisialisasi console untuk output rich
console = Console()

# Konfigurasi logging dengan RichHandler
logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    datefmt="[%Y-%m-%d %H:%M:%S]",
    handlers=[RichHandler(rich_tracebacks=True, console=console)]
)
logger = logging.getLogger("TaskBot")

BASE_HEADERS = {
    "accept": "application/json, text/plain, */*",
    "accept-encoding": "gzip, deflate, br, zstd",
    "accept-language": "en-US,en;q=0.9",
    "cache-control": "no-cache",
    "content-type": "application/json",
    "origin": "https://tg-wallet.planx.io",
    "pragma": "no-cache",
    "priority": "u=1, i",
    "referer": "https://tg-wallet.planx.io/",
    "sec-ch-ua": '"Chromium";v="133", "Microsoft Edge WebView2";v="133", "Not(A:Brand";v="99", "Microsoft Edge";v="133"',
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": '"Windows"',
    "sec-fetch-dest": "empty",
    "sec-fetch-mode": "cors",
    "sec-fetch-site": "same-site",
    "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36 Edg/133.0.0.0"
}

TASKS = {
    "m20250212173934013124700001": "Daily Login",
    "m20250325174288367185100003": "Lottery",
    "m20250212173935519374200019": "Join the PlanX Community",
    "m20250212173935571986800022": "Join the PlanX Channel",
    "m20250212173935594680500028": "Follow PlanX on X",
    "m20250212173935584402900025": "Join the PlanX Discord",
    "m20250212173935604389100031": "Follow PlanX on TikTok",
    "m20250212173935613755700034": "Follow PlanX on YouTube",
    "m20250214173952165258600005": "Repost a PlanX'post on X",
    "m20250213173941632390600015": "Comment a PlanX'post on X",
    "m20250213173941720460300018": "Like a PlanX'post on X",
    "m20250214173952169399300006": "Quote a PlanX' post and tag 3 of friends on X",
    "m20250213173941728955700021": "Share the PlanX video from YouTube to X",
    "m20250213173941736560000024": "Share the PlanX video from TikTok to X",
    "m20250213173941767785900027": "Read the PlanX Medium article",
    "m20250212173935456044700010": "Invite 1 friend",
    "m20250212173935470203200013": "Invite 5 friends",
    "m20250212173935480395100016": "Invite 10 friends"
}

CALL_URL = "https://mpc-api.planx.io/api/v1/telegram/task/call"
CLAIM_URL = "https://mpc-api.planx.io/api/v1/telegram/task/claim"
TEST_URL = "https://www.google.com"  # URL untuk tes koneksi proxy

class ProxyManager:
    def __init__(self):
        self.proxies = self.load_and_test_proxies()
        self.current_proxy_index = 0

    def load_and_test_proxies(self) -> List[Dict[str, str]]:
        """Memuat dan menguji proxy dari file proxy.txt, lalu hapus yang mati"""
        try:
            with open("proxy.txt", "r") as file:
                lines = [line.strip() for line in file.readlines() if line.strip()]
                if not lines:
                    logger.error("proxy.txt kosong! Proxy diperlukan untuk menjalankan program.")
                    sys.exit(1)
                
                proxies = []
                for line in lines:
                    proxy = self.parse_proxy(line)
                    if proxy:
                        proxies.append(proxy)
                
                if not proxies:
                    logger.error("Tidak ada proxy valid di proxy.txt! Program memerlukan setidaknya satu proxy.")
                    sys.exit(1)
                
                # Tes setiap proxy dan filter yang hidup
                logger.info("Menguji koneksi proxy...")
                alive_proxies = []
                for proxy in proxies:
                    if self.test_proxy(proxy):
                        alive_proxies.append(proxy)
                    else:
                        logger.warning(f"Proxy {proxy['host']}:{proxy['port']} mati, akan dihapus dari daftar.")
                
                if not alive_proxies:
                    logger.error("Semua proxy mati! Program memerlukan setidaknya satu proxy yang aktif.")
                    sys.exit(1)
                
                # Tulis ulang proxy.txt hanya dengan proxy yang hidup
                with open("proxy.txt", "w") as file:
                    for proxy in alive_proxies:
                        line = self.format_proxy_line(proxy)
                        file.write(f"{line}\n")
                
                logger.info(f"Berhasil memuat {len(alive_proxies)} proxy aktif dari proxy.txt")
                return alive_proxies
        except FileNotFoundError:
            logger.error("File proxy.txt tidak ditemukan! Proxy wajib untuk menjalankan program.")
            sys.exit(1)

    def parse_proxy(self, line: str) -> Optional[Dict[str, str]]:
        """Parsing berbagai format proxy"""
        try:
            protocol = "http"  # Default protocol jika tidak disebutkan
            username = None
            password = None
            host = None
            port = None

            if "://" in line:
                parts = line.split("://")
                protocol = parts[0].lower()
                if protocol not in ["http", "https", "socks4", "socks5"]:
                    protocol = "http"
                rest = parts[1]
            else:
                rest = line

            if "@" in rest:
                auth, host_port = rest.split("@")
                username, password = auth.split(":")
                host, port = host_port.split(":")
            else:
                host, port = rest.split(":")

            proxy = {
                "protocol": protocol,
                "host": host,
                "port": int(port)
            }
            if username and password:
                proxy["username"] = username
                proxy["password"] = password
            
            return proxy
        except Exception as e:
            logger.warning(f"Format proxy tidak valid: {line} - {e}")
            return None

    def format_proxy_line(self, proxy: Dict[str, str]) -> str:
        """Mengformat proxy kembali ke string untuk ditulis ke file"""
        line = f"{proxy['protocol']}://"
        if "username" in proxy:
            line += f"{proxy['username']}:{proxy['password']}@"
        line += f"{proxy['host']}:{proxy['port']}"
        return line

    def test_proxy(self, proxy: Dict[str, str]) -> bool:
        """Menguji apakah proxy aktif dengan mencoba koneksi ke URL tes"""
        try:
            session = requests.Session()
            if proxy["protocol"] in ["socks4", "socks5"]:
                socks_type = socks.SOCKS4 if proxy["protocol"] == "socks4" else socks.SOCKS5
                socks.set_default_proxy(
                    socks_type,
                    proxy["host"],
                    proxy["port"],
                    username=proxy.get("username"),
                    password=proxy.get("password")
                )
                socket.socket = socks.socksocket
            else:
                session.proxies = self.setup_proxy(proxy)
            
            response = session.get(TEST_URL, timeout=10)
            socks.set_default_proxy()  # Reset proxy SOCKS setelah tes
            return response.status_code == 200
        except Exception as e:
            logger.debug(f"Tes proxy {proxy['host']}:{proxy['port']} gagal: {e}")
            return False

    def get_next_proxy(self) -> Dict[str, str]:
        """Mendapatkan proxy berikutnya dengan rotasi"""
        proxy = self.proxies[self.current_proxy_index]
        self.current_proxy_index = (self.current_proxy_index + 1) % len(self.proxies)
        return proxy

    def setup_proxy(self, proxy: Dict[str, str]) -> Dict[str, str]:
        """Mengatur proxy untuk requests"""
        proxy_url = f"{proxy['protocol']}://"
        if "username" in proxy:
            proxy_url += f"{proxy['username']}:{proxy['password']}@"
        proxy_url += f"{proxy['host']}:{proxy['port']}"
        return {
            "http": proxy_url,
            "https": proxy_url
        }

def decode_jwt_token(token: str) -> Tuple[Optional[str], Optional[str]]:
    try:
        parts = token.split('.')
        if len(parts) != 3:
            logger.error("Token JWT tidak valid, harus terdiri dari 3 bagian")
            return None, None
        
        payload = parts[1]
        decoded_payload = base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)).decode('utf-8')
        payload_data = json.loads(decoded_payload)
        
        user_id = payload_data.get("user_id")
        if not user_id:
            logger.error("user_id tidak ditemukan di payload token")
            return None, None
        
        return user_id, token
    except Exception as e:
        logger.error(f"Error decoding token: {e}", exc_info=True)
        return None, None

def call_task(user_id: str, token: str, task_id: str, task_name: str, proxy_manager: ProxyManager) -> bool:
    headers = BASE_HEADERS.copy()
    headers["token"] = token
    payload = {"taskId": task_id}
    
    proxy = proxy_manager.get_next_proxy()
    proxy_str = f"{proxy['protocol']}://{proxy['host']}:{proxy['port']}"
    logger.info(f"[{user_id}] Mengerjakan tugas: {task_name} dengan proxy: {proxy_str}")
    
    try:
        session = requests.Session()
        if proxy["protocol"] in ["socks4", "socks5"]:
            socks_type = socks.SOCKS4 if proxy["protocol"] == "socks4" else socks.SOCKS5
            socks.set_default_proxy(
                socks_type,
                proxy["host"],
                proxy["port"],
                username=proxy.get("username"),
                password=proxy.get("password")
            )
            socket.socket = socks.socksocket
        else:
            session.proxies = proxy_manager.setup_proxy(proxy)
                
        response = session.post(CALL_URL, headers=headers, json=payload, timeout=60)
        data = response.json()
        
        if response.status_code == 200 and data.get("success", False):
            logger.info(f"[{user_id}] Tugas {task_name} berhasil dikerjakan")
            return True
        else:
            logger.warning(f"[{user_id}] Gagal mengerjakan tugas {task_name} - Code: {data.get('code', response.status_code)}, Msg: {data.get('msg', 'Unknown error')}")
            return False
    except requests.RequestException as e:
        logger.error(f"[{user_id}] Error saat mengerjakan tugas {task_name}: {e}", exc_info=True)
        return False
    finally:
        if proxy["protocol"] in ["socks4", "socks5"]:
            socks.set_default_proxy()

def claim_task(user_id: str, token: str, task_id: str, task_name: str, proxy_manager: ProxyManager) -> bool:
    headers = BASE_HEADERS.copy()
    headers["token"] = token
    payload = {"taskId": task_id}
    
    proxy = proxy_manager.get_next_proxy()
    proxy_str = f"{proxy['protocol']}://{proxy['host']}:{proxy['port']}"
    logger.info(f"[{user_id}] Mengklaim hadiah untuk tugas: {task_name} dengan proxy: {proxy_str}")
    
    try:
        session = requests.Session()
        if proxy["protocol"] in ["socks4", "socks5"]:
            socks_type = socks.SOCKS4 if proxy["protocol"] == "socks4" else socks.SOCKS5
            socks.set_default_proxy(
                socks_type,
                proxy["host"],
                proxy["port"],
                username=proxy.get("username"),
                password=proxy.get("password")
            )
            socket.socket = socks.socksocket
        else:
            session.proxies = proxy_manager.setup_proxy(proxy)
                
        response = session.post(CLAIM_URL, headers=headers, json=payload, timeout=60)
        data = response.json()
        
        if response.status_code == 200 and data.get("success", False):
            logger.info(f"[{user_id}] Hadiah untuk tugas {task_name} berhasil diklaim")
            return True
        else:
            code = data.get('code', response.status_code)
            msg = data.get('msg', 'Unknown error')
            if code == 1015:
                logger.warning(f"[{user_id}] Tugas {task_name} sudah pernah diklaim sebelumnya")
            else:
                logger.warning(f"[{user_id}] Gagal mengklaim hadiah {task_name} - Code: {code}, Msg: {msg}")
            return False
    except requests.RequestException as e:
        logger.error(f"[{user_id}] Error saat mengklaim hadiah {task_name}: {e}", exc_info=True)
        return False
    finally:
        if proxy["protocol"] in ["socks4", "socks5"]:
            socks.set_default_proxy()

def process_account(token: str, proxy_manager: ProxyManager) -> None:
    try:
        token = token.strip()
        if not token or not token.startswith("Bearer "):
            logger.error(f"Token tidak valid: {token}")
            return
        
        user_id, token = decode_jwt_token(token)
        if not user_id or not token:
            logger.error(f"Gagal memproses token: {token}")
            return
            
        logger.info(f"\nMemproses akun dengan ID: {user_id}")
        
        successful_tasks: List[Tuple[str, str]] = []
        for task_id, task_name in TASKS.items():
            if call_task(user_id, token, task_id, task_name, proxy_manager):
                successful_tasks.append((task_id, task_name))
            time.sleep(2)
        
        if successful_tasks:
            logger.info(f"\n[{user_id}] Mulai mengklaim {len(successful_tasks)} tugas yang berhasil")
            for task_id, task_name in successful_tasks:
                claim_task(user_id, token, task_id, task_name, proxy_manager)
                time.sleep(2)
        else:
            logger.warning(f"[{user_id}] Tidak ada tugas yang berhasil untuk diklaim")
        
        logger.info(f"Selesai memproses akun {user_id}\n")
    
    except Exception as e:
        logger.error(f"Error memproses akun: {e}", exc_info=True)

def wait_with_progress_bar(wait_time_seconds: int) -> None:
    with Progress(
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TimeRemainingColumn(),
        console=console
    ) as progress:
        task = progress.add_task("[cyan]Menunggu siklus berikutnya...", total=wait_time_seconds)
        elapsed = 0
        while elapsed < wait_time_seconds:
            time.sleep(1)
            elapsed += 1
            progress.update(task, advance=1)

def main_loop(max_threads: int, proxy_manager: ProxyManager) -> None:
    while True:
        try:
            with open("data.txt", "r") as file:
                tokens = file.readlines()
            
            if not tokens:
                logger.warning("Tidak ada token di data.txt!")
                wait_with_progress_bar(190 * 60)
                continue
                
            logger.info(f"\nMulai proses untuk {len(tokens)} akun pada {time.ctime()} dengan {max_threads} threads")
            
            with ThreadPoolExecutor(max_workers=max_threads) as executor:
                futures = [executor.submit(process_account, token, proxy_manager) for token in tokens]
                for future in futures:
                    try:
                        future.result()
                    except Exception as e:
                        logger.error(f"Error dalam thread: {e}", exc_info=True)
                
            logger.info(f"\nSelesai satu siklus.")
            wait_with_progress_bar(190 * 60)
            
        except FileNotFoundError:
            logger.error("File data.txt tidak ditemukan! Melanjutkan loop setelah delay...")
            wait_with_progress_bar(190 * 60)
        except KeyboardInterrupt:
            logger.warning("Program dihentikan oleh pengguna (KeyboardInterrupt), melanjutkan loop...")
            wait_with_progress_bar(190 * 60)
        except Exception as e:
            logger.error(f"Error di main loop: {e}", exc_info=True)
            wait_with_progress_bar(190 * 60)

if __name__ == "__main__":
    console.print("[bold cyan]╔══════════════════════════════════════════════╗[/bold cyan]")
    console.print("[bold cyan]║       🌟 PlanX BOT - Automated Rewards       ║[/bold cyan]")
    console.print("[bold cyan]║   Automate your PlanX task completion!       ║[/bold cyan]")
    console.print("[bold cyan]║  Developed by: https://t.me/sentineldiscus   ║[/bold cyan]")
    console.print("[bold cyan]╚══════════════════════════════════════════════╝[/bold cyan]")
    console.print("[bold green]Memulai program...[/bold green]")

    # Inisialisasi ProxyManager (akan berhenti jika proxy.txt tidak ada atau semua proxy mati)
    proxy_manager = ProxyManager()

    while True:
        try:
            max_threads = int(console.input("[bold yellow]Masukkan jumlah threads yang diinginkan: [/bold yellow]"))
            if max_threads <= 0:
                console.print("[bold red]Jumlah threads harus lebih dari 0![/bold red]")
                continue
            break
        except ValueError:
            console.print("[bold red]Masukkan angka yang valid![/bold red]")
    
    console.print(f"[bold green]Program akan berjalan dengan {max_threads} threads[/bold green]")
    try:
        main_loop(max_threads, proxy_manager)
    except KeyboardInterrupt:
        console.print("[bold red]Program dihentikan oleh pengguna melalui KeyboardInterrupt.[/bold red]")
    except Exception as e:
        logger.error(f"Error kritis di luar loop: {e}", exc_info=True)