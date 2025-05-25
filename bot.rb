require 'httparty'
require 'colorize'
require 'securerandom'
require 'json'
require 'uri'
require 'jwt'
require 'digest'
require 'fileutils'

puts <<~BANNER
╔══════════════════════════════════════════════╗
║       🌟 PlanX TaskBot - Automated Tasks     ║
║   Automate your PlanX account tasks!         ║
║  Developed by: https://t.me/sentineldiscus   ║
╚══════════════════════════════════════════════╝
BANNER

TASKS = {
  "m20250212173934013124700001" => "Daily Login",
  "m20250325174288367185100003" => "Lottery",
  "m20250522174789949352000045" => "I am not a robot",
  "m20250521174781856608400042" => "Earn 1.7% Daily with USDX in Xwallet!",
  "m20250521174780862795300039" => "Earn TON for completing simple tasks",
  "m20250521174779954000200036" => "Join RewardsHQ and win cash prizes",
  "m20250521174779685918100032" => "Search BTC wallets with RootBTC",
  "m20250521174779639447100029" => "Join TAPX & Earn Rewards",
  "m20250521174779307171300025" => "Play & Earn Your $1000",
  "m20250520174772991278700024" => "Play Merge Pals and Earn Rewards",
  "m20250520174770655580300018" => "Play Valor Quest and Earn Rewards",
  "m20250520174770687133400021" => "Explore Funton.ai TG Mini App and Earn Rewards",
  "m20250520174770621353700015" => "Post Short Videos and Earn Like TikTok",
  "m20250516174736524661500009" => "Mine for free and win $300",
  "m20250515174730236703400006" => "Start Rolling - Play DiceSwap & Win TON",
  "m20250515174729364086600003" => "Launch TapCoinsBot",
  "m20250513174712786995700006" => "Play Miner to win $300",
  "m20250513174712489462800003" => "Let's earn $WTON and WONTON collections together",
  "m20250424174548205765500003" => "Earn USDT Daily",
  "m20250212173935146770000006" => "Create Wallet",
  "m20250507174660749235200006" => "Visit the PlanX Official Website",
  "m20250507174659651577000003" => "Play Startai, Claim 100 USDT",
  "m20250505174642807898300003" => "Play Simple and get $SMPL",
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

CLAIM_ONLY_TASKS = {
  "m20250212173934013124700001" => "Daily Login",
  "m20250325174288367185100003" => "Lottery"
}

CALL_TASKS = TASKS.reject { |k, _| CLAIM_ONLY_TASKS.key?(k) }

DEFAULT_USER_AGENTS_AND_PLATFORMS = [
  {
    user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
    platform: "Windows"
  },
  {
    user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
    platform: "macOS"
  },
  {
    user_agent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
    platform: "Linux"
  },
  {
    user_agent: "Mozilla/5.0 (Linux; Android 14; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Mobile Safari/537.36",
    platform: "Android"
  },
  {
    user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
    platform: "iOS"
  }
]

HEADERS = {
  'accept' => 'application/json, text/plain, */*',
  'accept-encoding' => 'identity',
  'content-type' => 'application/json',
  'language' => 'id',
  'origin' => 'https://tg-wallet.planx.io',
  'referer' => 'https://tg-wallet.planx.io/'
}

USE_PROXY = false

def generate_fp(token, user_agent)
  timestamp = Time.now.to_i.to_s
  screen_resolution = "1920x1080"
  timezone = "Asia/Jakarta"
  input = "#{token}:#{user_agent}:#{screen_resolution}:#{timezone}:#{timestamp}"
  Digest::MD5.hexdigest(input)
end

def read_or_generate_fps(tokens, user_agents)
  FileUtils.mkdir_p('HEADERS')
  fp_file = 'HEADERS/fp.json'
  fps = []
  if File.exist?(fp_file)
    begin
      fps = JSON.parse(File.read(fp_file))
    rescue StandardError => e
      puts "Error reading #{fp_file}: #{e.message}".red
    end
  end
  tokens.each_with_index do |token, i|
    fps[i] ||= generate_fp(token, user_agents[i])
  end
  begin
    File.write(fp_file, JSON.pretty_generate(fps))
  rescue StandardError => e
    puts "Error saving #{fp_file}: #{e.message}".red
  end
  fps
end

def read_or_generate_user_agents_and_platforms(token_count)
  FileUtils.mkdir_p('HEADERS')
  ua_file = 'HEADERS/useragent.json'
  platform_file = 'HEADERS/platform.json'
  user_agents = []
  platforms = []
  if File.exist?(ua_file) && File.exist?(platform_file)
    begin
      user_agents = JSON.parse(File.read(ua_file))
      platforms = JSON.parse(File.read(platform_file))
    rescue StandardError => e
      puts "Error reading #{ua_file} or #{platform_file}: #{e.message}".red
    end
  end
  while user_agents.size < token_count
    pair = DEFAULT_USER_AGENTS_AND_PLATFORMS[user_agents.size % DEFAULT_USER_AGENTS_AND_PLATFORMS.size]
    user_agents << pair[:user_agent]
    platforms << pair[:platform]
  end
  begin
    File.write(ua_file, JSON.pretty_generate(user_agents))
    File.write(platform_file, JSON.pretty_generate(platforms))
  rescue StandardError => e
    puts "Error saving #{ua_file} or #{platform_file}: #{e.message}".red
  end
  [user_agents, platforms]
end

def decode_token(token)
  begin
    decoded = JWT.decode(token, nil, false)
    decoded[0]['username'] || 'Unknown'
  rescue StandardError => e
    puts "Error decoding token: #{e.message}".red
    'Unknown'
  end
end

def read_tokens
  begin
    tokens = File.exist?('data.txt') ? File.readlines('data.txt').map(&:strip).reject(&:empty?) : []
    tokens.map do |token|
      token = token[7..-1].strip if token.downcase.start_with?('bearer ')
      if token.empty?
        puts "Empty token detected".red
        nil
      else
        token
      end
    end.compact
  rescue StandardError => e
    puts "Error: data.txt not found or unreadable: #{e.message}".red
    []
  end
end

def read_proxies
  return [] unless USE_PROXY && File.exist?('proxy.txt')
  begin
    File.readlines('proxy.txt').map(&:strip).reject(&:empty?)
  rescue StandardError => e
    puts "Error reading proxy.txt: #{e.message}".red
    []
  end
end

def format_proxy(proxy)
  return nil if proxy.nil? || proxy.empty?
  proxy = "http://#{proxy}" unless proxy.include?('://')
  begin
    uri = URI.parse(proxy)
    unless uri.scheme && uri.host && uri.port
      puts "Invalid proxy format: #{proxy}".red
      return nil
    end
    proxy_options = {
      http_proxyaddr: uri.host,
      http_proxyport: uri.port
    }
    proxy_options[:http_proxyuser] = uri.user if uri.user
    proxy_options[:http_proxypass] = uri.password if uri.password
    proxy_options
  rescue URI::InvalidURIError => e
    puts "Error parsing proxy #{proxy}: #{e.message}".red
    nil
  end
end

def check_task_status(token, fp, user_agent, platform, proxy = nil)
  url = 'https://mpc-api.planx.io/api/v1/telegram/task/list'
  headers = HEADERS.merge(
    'token' => "Bearer #{token}",
    'fp' => fp,
    'user-agent' => user_agent
  )
  options = { headers: headers }
  options.merge!(proxy) if proxy
  begin
    response = HTTParty.get(url, options.merge(timeout: 10))
    parsed_response = JSON.parse(response.body) rescue nil
    if response.code == 200 && parsed_response && parsed_response['success']
      parsed_response['data'] || []
    else
      puts "Failed to fetch task status".red
      []
    end
  rescue StandardError => e
    puts "Failed to fetch task status: #{e.message}".red
    []
  end
end

def call_task(task_id, token, fp, user_agent, platform, proxy = nil)
  url = 'https://mpc-api.planx.io/api/v1/telegram/task/call'
  headers = HEADERS.merge(
    'token' => "Bearer #{token}",
    'fp' => fp,
    'user-agent' => user_agent
  )
  payload = { taskId: task_id }
  options = { headers: headers, body: payload.to_json }
  options.merge!(proxy) if proxy
  begin
    response = HTTParty.post(url, options.merge(timeout: 10))
    parsed_response = JSON.parse(response.body) rescue nil
    if response.code == 200 && parsed_response && parsed_response['success']
      puts "Task #{TASKS[task_id]} succeeded".green
      true
    elsif response.code == 200 && parsed_response && parsed_response['msg'] == 'Frequent access, please try again later'
      puts "Task #{TASKS[task_id]} rate limited. Waiting 15 seconds...".yellow
      sleep 15
      false
    elsif response.code == 406 || (parsed_response && parsed_response['code'] == 406)
      puts "Task #{TASKS[task_id]} already completed".blue
      true
    else
      error_message = parsed_response&.[]('msg')
      if error_message && !error_message.empty?
        puts "Task #{TASKS[task_id]} failed: #{error_message}".red
      else
        puts "Task #{TASKS[task_id]} failed".red
      end
      false
    end
  rescue StandardError => e
    puts "Task #{TASKS[task_id]} failed: #{e.message}".red
    false
  end
end

def claim_task(task_id, token, fp, user_agent, platform, proxy = nil, task_list = TASKS)
  url = 'https://mpc-api.planx.io/api/v1/telegram/task/claim'
  headers = HEADERS.merge(
    'token' => "Bearer #{token}",
    'fp' => fp,
    'user-agent' => user_agent
  )
  payload = { taskId: task_id }
  options = { headers: headers, body: payload.to_json }
  options.merge!(proxy) if proxy
  begin
    response = HTTParty.post(url, options.merge(timeout: 10))
    parsed_response = JSON.parse(response.body) rescue nil
    if response.code == 200 && parsed_response && parsed_response['success']
      puts "Claim task #{task_list[task_id]} succeeded".green
      true
    elsif response.code == 200 && parsed_response && parsed_response['msg'] == 'Frequent access, please try again later'
      puts "Claim task #{task_list[task_id]} rate limited. Waiting 15 seconds...".yellow
      sleep 15
      false
    elsif response.code == 406 || (parsed_response && parsed_response['code'] == 406)
      puts "Task #{task_list[task_id]} already claimed".blue
      true
    else
      error_message = parsed_response&.[]('msg')
      if error_message && !error_message.empty?
        puts "Claim task #{task_list[task_id]} failed: #{error_message}".red
      else
        puts "Claim task #{task_list[task_id]} failed".red
      end
      false
    end
  rescue StandardError => e
    puts "Claim task #{task_list[task_id]} failed: #{e.message}".red
    false
  end
end

def main
  puts "Starting PlanX TaskBot...".yellow
  iteration = 1
  loop do
    tokens = read_tokens
    if tokens.empty?
      puts "No valid tokens found. Script stopped.".red
      return
    end
    user_agents, platforms = read_or_generate_user_agents_and_platforms(tokens.size)
    if user_agents.size < tokens.size || platforms.size < tokens.size
      puts "Insufficient user-agents or platforms for all tokens. Script stopped.".red
      return
    end
    fps = read_or_generate_fps(tokens, user_agents)
    if fps.size < tokens.size
      puts "Insufficient FPs for all tokens. Script stopped.".red
      return
    end
    proxies = read_proxies
    tokens.each_with_index do |token, i|
      username = decode_token(token)
      puts "\nAccount #{username}: Starting...".yellow
      fp = fps[i]
      user_agent = user_agents[i]
      platform = platforms[i]
      proxy = proxies.any? ? format_proxy(proxies.sample) : nil
      puts "Account #{username}: Using FP #{fp}".blue
      puts "Account #{username}: Using User-Agent #{user_agent}".blue
      puts "Account #{username}: Using Platform #{platform}".blue
      puts "Account #{username}: Using proxy #{proxy[:http_proxyaddr]}:#{proxy[:http_proxyport]}" if proxy
      puts "Account #{username}: Checking task status...".yellow
      task_statuses = check_task_status(token, fp, user_agent, platform, proxy)
      if iteration == 1
        puts "Account #{username}: Processing CALL tasks...".yellow
        CALL_TASKS.each do |task_id, _|
          task_status = task_statuses.find { |t| t['taskId'] == task_id }
          if task_status && task_status['completed']
            puts "Task #{TASKS[task_id]} already completed, skipping call".blue
            next
          end
          call_task(task_id, token, fp, user_agent, platform, proxy)
          sleep 0
        end
        puts "Account #{username}: Waiting 30 seconds before CLAIM...".yellow
        sleep 30
        puts "Account #{username}: Processing CLAIM tasks...".yellow
        TASKS.each do |task_id, _|
          task_status = task_statuses.find { |t| t['taskId'] == task_id }
          if task_status && task_status['claimed']
            puts "Task #{TASKS[task_id]} already claimed, skipping claim".blue
            next
          end
          claim_task(task_id, token, fp, user_agent, platform, proxy)
          sleep 0
        end
      else
        puts "Account #{username}: Processing CLAIM tasks (Daily Login & Lottery)...".yellow
        CLAIM_ONLY_TASKS.each do |task_id, _|
          task_status = task_statuses.find { |t| t['taskId'] == task_id }
          if task_status && task_status['claimed']
            puts "Task #{CLAIM_ONLY_TASKS[task_id]} already claimed, skipping claim".blue
            next
          end
          claim_task(task_id, token, fp, user_agent, platform, proxy, CLAIM_ONLY_TASKS)
          sleep 5
        end
      end
      if i < tokens.size - 1
        puts "Account #{username}: Done. Waiting 3 seconds before next account...".yellow
        sleep 3
      end
    end
    iteration += 1
    puts "All accounts processed. Waiting 3 hours before next iteration...".yellow
    sleep 10800
  end
end

main if __FILE__ == $PROGRAM_NAME
