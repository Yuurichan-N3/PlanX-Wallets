require 'httparty'
require 'time'
require 'json'
require 'colorize'
require 'concurrent'

# URL endpoint
URL = "https://mpc-api.planx.io/api/v1/telegram/task/claim"

# Header dasar ngek
BASE_HEADERS = {
  "accept" => "application/json, text/plain, */*",
  "content-type" => "application/json",
  "origin" => "https://tg-wallet.planx.io",
  "referer" => "https://tg-wallet.planx.io/",
  "user-agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36 Edg/134.0.0.0"
}

# Task IDs yang digunakan cuma Lottery dan claim 3 jam
TASK_IDS = [
  "m20250325174288367185100003",
  "m20250212173934013124700001"
]

def print_banner
  puts "╔══════════════════════════════════════════════╗".cyan
  puts "║       🌟 PlanX BOT - Automated Rewards       ║".cyan
  puts "║   Automate your PlanX task completion!       ║".cyan
  puts "║  Developed by: https://t.me/sentineldiscus   ║".cyan
  puts "╚══════════════════════════════════════════════╝".cyan
end

def load_accounts(file_path = "data.txt")
  accounts = []
  begin
    File.foreach(file_path) do |line|
      if line.downcase.include?('token:')
        token = line.split('token:')[1].strip
        accounts << token
      elsif line.include?('Bearer ')
        token = line.strip
        accounts << token if token.start_with?('Bearer ')
      end
    end
  rescue Errno::ENOENT
    puts "File data.txt tidak ditemukan!".cyan
    return []
  end
  accounts
end

def claim_task(token, task_id)
  headers = BASE_HEADERS.merge({"token" => token})
  payload = {"taskId" => task_id}
  
  begin
    response = HTTParty.post(
      URL,
      headers: headers,
      body: payload.to_json
    )
    
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    if response.code == 200
      puts "[#{timestamp}] Berhasil claim task #{task_id} - Response: #{response.body}".cyan
    else
      puts "[#{timestamp}] Gagal claim task #{task_id} - Status: #{response.code}".cyan
    end
  rescue StandardError => e
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    puts "[#{timestamp}] Error saat claim task #{task_id}: #{e.message}".cyan
  end
end

def process_account(token)
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  puts "[#{timestamp}] Memproses akun dengan token: #{token[0..19]}...".cyan
  
  TASK_IDS.each do |task_id|
    claim_task(token, task_id)
    sleep(2)
  end
end

def main
  print_banner
  
  # Buat thread pool dengan jumlah worker (misalnya 1)
  pool = Concurrent::ThreadPoolExecutor.new(max_threads: 1)
  
  loop do
    accounts = load_accounts
    
    if accounts.empty?
      puts "Tidak ada akun yang ditemukan. Pastikan file data.txt berisi token!".cyan
      break
    end
    
    # Proses akun secara paralel
    accounts.each_with_index do |token, idx|
      pool.post do
        timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        puts "\n[#{timestamp}] Memproses akun #{idx + 1}/#{accounts.length}".cyan
        process_account(token)
      end
    end
    
    # Tunggu semua thread selesai sebelum sleep
    pool.shutdown
    pool.wait_for_termination
    
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    puts "\n[#{timestamp}] Selesai satu siklus. Menunggu 190 menit...".cyan
    sleep(11400)
    
    # Buat pool baru untuk siklus berikutnya
    pool = Concurrent::ThreadPoolExecutor.new(max_threads: 5)
  end
  
  # Pastikan pool ditutup saat keluar dari loop
  pool.shutdown
end

if __FILE__ == $0
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  puts "[#{timestamp}] Script dimulai...".cyan
  main
end
