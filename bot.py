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
    "m20250212173935584402900025": "Daily Login",
    "m20250212173935594680500028": "Follow Twitter",
    "m20250212173935519374200019": "Join Telegram",
    "m20250212173935604389100031": "Share Post",
    "m20250212173935613755700034": "Invite Friend",
    "m20250212173935571986800022": "Watch Video",
    "m20250214173952165258600005": "Complete Survey",
    "m20250213173941632390600015": "Visit Website",
    "m20250213173941720460300018": "Like Post",
    "m20250214173952169399300006": "Comment Post",
    "m20250213173941728955700021": "Daily Check-in",
    "m20250213173941736560000024": "Play Game",
    "m20250213173941767785900027": "Submit Feedback",
    "m20250212173934013124700001": "Profile Setup"
}

CALL_URL = "https://mpc-api.planx.io/api/v1/telegram/task/call"
CLAIM_URL = "https://mpc-api.planx.io/api/v1/telegram/task/claim"

def decode_jwt_token(token: str) -> Tuple[Optional[str], Optional[str]]:
    """
    Decode JWT token untuk mendapatkan user_id dari payload.

    Args:
        token (str): Token JWT yang akan didecode.

    Returns:
        Tuple[Optional[str], Optional[str]]: (user_id, token) atau (None, None) jika gagal.
    """
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

def call_task(user_id: str, token: str, task_id: str, task_name: str) -> bool:
    """
    Melakukan panggilan tugas.

    Args:
        user_id (str): ID pengguna.
        token (str): Token autentikasi.
        task_id (str): ID tugas.
        task_name (str): Nama tugas.

    Returns:
        bool: True jika tugas berhasil, False jika gagal.
    """
    headers = BASE_HEADERS.copy()
    headers["token"] = token
    payload = {"taskId": task_id}
    
    logger.info(f"[{user_id}] Mengerjakan tugas: {task_name}")
    try:
        response = requests.post(CALL_URL, headers=headers, json=payload, timeout=10)
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

def claim_task(user_id: str, token: str, task_id: str, task_name: str) -> bool:
    """
    Mengklaim hadiah tugas.

    Args:
        user_id (str): ID pengguna.
        token (str): Token autentikasi.
        task_id (str): ID tugas.
        task_name (str): Nama tugas.

    Returns:
        bool: True jika klaim berhasil, False jika gagal.
    """
    headers = BASE_HEADERS.copy()
    headers["token"] = token
    payload = {"taskId": task_id}
    
    logger.info(f"[{user_id}] Mengklaim hadiah untuk tugas: {task_name}")
    try:
        response = requests.post(CLAIM_URL, headers=headers, json=payload, timeout=10)
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

def process_account(token: str) -> None:
    """
    Proses semua tugas untuk satu akun: call dulu semua, lalu claim.

    Args:
        token (str): Token autentikasi untuk akun.
    """
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
        
        # Tahap 1: Call semua tugas
        successful_tasks: List[Tuple[str, str]] = []
        for task_id, task_name in TASKS.items():
            if call_task(user_id, token, task_id, task_name):
                successful_tasks.append((task_id, task_name))
            time.sleep(2)  # Delay antar tugas
        
        # Tahap 2: Claim semua tugas yang berhasil
        if successful_tasks:
            logger.info(f"\n[{user_id}] Mulai mengklaim {len(successful_tasks)} tugas yang berhasil")
            for task_id, task_name in successful_tasks:
                claim_task(user_id, token, task_id, task_name)
                time.sleep(2)  # Delay antar klaim
        else:
            logger.warning(f"[{user_id}] Tidak ada tugas yang berhasil untuk diklaim")
        
        logger.info(f"Selesai memproses akun {user_id}\n")
    
    except Exception as e:
        logger.error(f"Error memproses akun: {e}", exc_info=True)

def wait_with_progress_bar(wait_time_seconds: int) -> None:
    """
    Menampilkan progress bar selama waktu tunggu.

    Args:
        wait_time_seconds (int): Waktu tunggu dalam detik.
    """
    with Progress(
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TimeRemainingColumn(),
        console=console
    ) as progress:
        task = progress.add_task("[cyan]Menunggu siklus berikutnya...", total=wait_time_seconds)
        elapsed = 0
        while elapsed < wait_time_seconds:
            time.sleep(1)  # Update setiap detik
            elapsed += 1
            progress.update(task, advance=1)

def main_loop(max_threads: int) -> None:
    """
    Main loop yang berjalan setiap 3 jam 10 menit.

    Args:
        max_threads (int): Jumlah maksimum thread untuk ThreadPoolExecutor.
    """
    while True:
        try:
            with open("data.txt", "r") as file:
                tokens = file.readlines()
            
            if not tokens:
                logger.warning("Tidak ada token di data.txt!")
                wait_with_progress_bar(190 * 60)  # 3 jam 10 menit
                continue
                
            logger.info(f"\nMulai proses untuk {len(tokens)} akun pada {time.ctime()} dengan {max_threads} threads")
            
            # Proses semua akun secara paralel dengan jumlah thread dari input
            with ThreadPoolExecutor(max_workers=max_threads) as executor:
                futures = [executor.submit(process_account, token) for token in tokens]
                for future in futures:
                    try:
                        future.result()  # Menunggu hasil dan menangani exception
                    except Exception as e:
                        logger.error(f"Error dalam thread: {e}", exc_info=True)
                
            logger.info(f"\nSelesai satu siklus.")
            wait_with_progress_bar(190 * 60)  # 3 jam 10 menit = 190 menit
            
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
    # Tampilkan header tabel dengan rich
    console.print("[bold cyan]╔══════════════════════════════════════════════╗[/bold cyan]")
    console.print("[bold cyan]║       🌟 PlanX BOT - Automated Rewards       ║[/bold cyan]")
    console.print("[bold cyan]║   Automate your PlanX task completion!       ║[/bold cyan]")
    console.print("[bold cyan]║  Developed by: https://t.me/sentineldiscus   ║[/bold cyan]")
    console.print("[bold cyan]╚══════════════════════════════════════════════╝[/bold cyan]")
    console.print("[bold green]Memulai program...[/bold green]")

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
        main_loop(max_threads)
    except KeyboardInterrupt:
        console.print("[bold red]Program dihentikan oleh pengguna melalui KeyboardInterrupt.[/bold red]")
    except Exception as e:
        logger.error(f"Error kritis di luar loop: {e}", exc_info=True)
