require 'httparty'
require 'colorize'
require 'securerandom'
require 'json'
require 'uri'

# Banner
puts <<~BANNER
╔══════════════════════════════════════════════╗
║       🌟 PlanX TaskBot - Automated Tasks     ║
║   Automate your PlanX account tasks!         ║
║  Developed by: https://t.me/sentineldiscus   ║
╚══════════════════════════════════════════════╝
BANNER

# List of all task IDs and their descriptions
TASKS = {
  "m20250212173934013124700001" => "Daily Login",
  "m20250325174288367185100003" => "Lottery",
  "m20250212173935519374200019" => "Join the PlanX Community",
  "m20250212173935571986800022" => "Join the PlanX Channel",
  "m20250212173935594680500028" => "Follow PlanX on X",
  "m20250212173935584402900025" => "Join the PlanX Discord",
  "m20250212173935604389100031" => "Follow PlanX on TikTok",
  "m20250212173935613755700034" => "Follow PlanX on YouTube",
  "m20250214173952165258600005" => "Repost a PlanX'post on X",
  "m20250213173941632390600015" => "Comment a PlanX'post on X",
  "m20250213173941720460300018" => "Like a PlanX'post on X",
  "m20250214173952169399300006" => "Quote a PlanX' post and tag 3 of friends on X",
  "m20250213173941728955700021" => "Share the PlanX video from YouTube to X",
  "m20250213173941736560000024" => "Share the PlanX video from TikTok to X",
  "m20250213173941767785900027" => "Read the PlanX Medium article"
}

# Tasks to claim only (Daily Login and Lottery)
CLAIM_ONLY_TASKS = {
  "m20250212173934013124700001" => "Daily Login",
  "m20250325174288367185100003" => "Lottery"
}

# Tasks to process with call and claim in first iteration
CALL_TASKS = TASKS.reject { |k, _| CLAIM_ONLY_TASKS.key?(k) }

# Headers for the API requests
HEADERS = {
  'accept' => 'application/json, text/plain, */*',
  'accept-encoding' => 'gzip, deflate, br, zstd',
  'content-type' => 'application/json',
  'language' => 'id',
  'origin' => 'https://tg-wallet.planx.io',
  'referer' => 'https://tg-wallet.planx.io/',
  'sec-ch-ua' => '"Microsoft Edge";v="135", "Chromium";v="135", "Not-A.Brand";v="8"',
  'sec-ch-ua-mobile' => '?0',
  'sec-ch-ua-platform' => '"Windows"',
  'sec-fetch-dest' => 'empty',
  'sec-fetch-mode' => 'cors',
  'sec-fetch-site' => 'same-site',
  'user-agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36 Edg/135.0.0.0'
}

# Function to read tokens from data.txt
def read_tokens
  begin
    tokens = File.exist?('data.txt') ? File.readlines('data.txt').map(&:strip).reject(&:empty?) : []
    tokens.map { |token| token.downcase.start_with?('bearer ') ? token[7..-1].strip : token }
  rescue StandardError => e
    puts "Error: data.txt tidak ditemukan. Buat data.txt dengan daftar token.".red
    []
  end
end

# Function to read proxies from proxy.txt (optional)
def read_proxies
  return [] unless File.exist?('proxy.txt')
  begin
    File.readlines('proxy.txt').map(&:strip).reject(&:empty?)
  rescue StandardError => e
    puts "Error membaca proxy.txt: #{e.message}".red
    []
  end
end

# Function to parse and format proxy for HTTParty
def format_proxy(proxy)
  return nil if proxy.nil? || proxy.empty?

  # Tambahkan http:// jika tidak ada protokol
  proxy = "http://#{proxy}" unless proxy.include?('://')

  begin
    uri = URI.parse(proxy)
    unless uri.scheme && uri.host && uri.port
      puts "Format proxy tidak valid: #{proxy}".red
      return nil
    end

    proxy_options = {
      http_proxyaddr: uri.host,
      http_proxyport: uri.port
    }

    # Tambahkan autentikasi jika ada
    proxy_options[:http_proxyuser] = uri.user if uri.user
    proxy_options[:http_proxypass] = uri.password if uri.password

    puts "Parsed proxy: #{uri.host}:#{uri.port}#{uri.user ? " (user: #{uri.user})" : ''}".blue
    proxy_options
  rescue URI::InvalidURIError => e
    puts "Error parsing proxy #{proxy}: #{e.message}".red
    nil
  end
end

# Function to make a POST request to /call endpoint
def call_task(task_id, token, proxy = nil)
  url = 'https://mpc-api.planx.io/api/v1/telegram/task/call'
  headers = HEADERS.merge('token' => "Bearer #{token}")
  payload = { taskId: task_id }
  options = { headers: headers, body: payload.to_json, decompress: true }

  # Terapkan proxy jika ada
  options.merge!(proxy) if proxy

  begin
    response = HTTParty.post(url, options.merge(timeout: 10))
    if response.code == 200 && response.parsed_response.is_a?(Hash) && response.parsed_response['success']
      puts "Task #{TASKS[task_id]} berhasil".green
      true
    else
      puts "Task #{TASKS[task_id]} gagal".red
      false
    end
  rescue StandardError => e
    puts "Task #{TASKS[task_id]} gagal: #{e.message}".red
    false
  end
end

# Function to make a POST request to /claim endpoint
def claim_task(task_id, token, proxy = nil, task_list = TASKS)
  url = 'https://mpc-api.planx.io/api/v1/telegram/task/claim'
  headers = HEADERS.merge('token' => "Bearer #{token}")
  payload = { taskId: task_id }
  options = { headers: headers, body: payload.to_json, decompress: true }

  # Terapkan proxy jika ada
  options.merge!(proxy) if proxy

  begin
    response = HTTParty.post(url, options.merge(timeout: 10))
    if response.code == 200 && response.parsed_response.is_a?(Hash) && response.parsed_response['success']
      puts "Claim task #{task_list[task_id]} berhasil".green
      true
    else
      puts "Claim task #{task_list[task_id]} gagal".red
      false
    end
  rescue StandardError => e
    puts "Claim task #{task_list[task_id]} gagal: #{e.message}".red
    false
  end
end

# Main execution
def main
  iteration = 1
  loop do
    puts "\n--- Iterasi ke-#{iteration} dimulai ---".yellow

    # Step 1: Read tokens from data.txt
    tokens = read_tokens
    if tokens.empty?
      puts "Tidak ada token yang valid. Script berhenti.".red
      return
    end

    # Step 2: Read proxies from proxy.txt (if exists)
    proxies = read_proxies
    if proxies.any?
      puts "Ditemukan #{proxies.size} proxy.".blue
    else
      puts "Tidak ada proxy.txt, berjalan tanpa proxy.".blue
    end

    # Step 3: Process each account sequentially
    tokens.each_with_index do |token, i|
      puts "\nAkun #{i + 1}: Memulai...".yellow

      # Pilih proxy secara acak (jika ada)
      proxy = proxies.any? ? format_proxy(proxies.sample) : nil
      puts "Akun #{i + 1}: Menggunakan proxy #{proxy[:http_proxyaddr]}:#{proxy[:http_proxyport]}" if proxy

      if iteration == 1
        # Iterasi pertama: Proses tugas dengan call (kecuali Daily Login & Lottery), lalu claim semua
        puts "Akun #{i + 1}: Memproses CALL tasks...".yellow
        CALL_TASKS.each do |task_id, _|
          call_task(task_id, token, proxy)
          sleep 3
        end

        puts "Akun #{i + 1}: Menunggu 10 detik sebelum CLAIM...".yellow
        sleep 10

        puts "Akun #{i + 1}: Memproses CLAIM tasks...".yellow
        TASKS.each do |task_id, _|
          claim_task(task_id, token, proxy)
          sleep 3
        end
      else
        # Iterasi berikutnya: Hanya claim Daily Login dan Lottery
        puts "Akun #{i + 1}: Memproses CLAIM tasks (Daily Login & Lottery)...".yellow
        CLAIM_ONLY_TASKS.each do |task_id, _|
          claim_task(task_id, token, proxy, CLAIM_ONLY_TASKS)
          sleep 3
        end
      end

      # Delay before next account
      if i < tokens.size - 1
        puts "Akun #{i + 1}: Selesai. Menunggu 30 detik sebelum akun berikutnya...".yellow
        sleep 2
      end
    end

    puts "\nIterasi ke-#{iteration} selesai. Menunggu 3 jam untuk iterasi berikutnya...".yellow
    iteration += 1
    sleep 10800
  end
end

main if __FILE__ == $PROGRAM_NAME
