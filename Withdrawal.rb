require 'httparty'
require 'jwt'
require 'json'
require 'colorize'

# URL Endpoint
URL = "https://mpc-api.planx.io/api/v1/telegram/withdrawal"

# Header
HEADERS = {
  "accept" => "application/json, text/plain, */*",
  "accept-encoding" => "gzip, deflate, br, zstd",
  "accept-language" => "id-ID,id;q=0.9,ja-ID;q=0.8,ja;q=0.7,en-ID;q=0.6,en;q=0.5,en-US;q=0.4",
  "content-type" => "application/json",
  "language" => "id",
  "origin" => "https://tg-wallet.planx.io",
  "priority" => "u=1, i",
  "referer" => "https://tg-wallet.planx.io/",
  "sec-ch-ua" => '"Chromium";v="130", "Mises";v="130", "Not?A_Brand";v="99"',
  "sec-ch-ua-mobile" => "?1",
  "sec-ch-ua-platform" => '"Android"',
  "sec-fetch-dest" => "empty",
  "sec-fetch-mode" => "cors",
  "sec-fetch-site" => "same-site",
  "user-agent" => "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36"
}

# Payload
PAYLOAD = { withdrawalType: 1 }

def read_tokens(file_path)
  begin
    File.exist?(file_path) ? File.readlines(file_path).map(&:strip).reject(&:empty?) : []
  rescue StandardError => e
    puts "ファイル data.txt が見つかりません！: #{e.message}".red
    []
  end
end

def valid_jwt?(token)
  # JWTは3つのセグメント（ヘッダー、ペイロード、署名）をピリオドで区切る
  segments = token.split('.')
  segments.length == 3 && segments.all? { |seg| seg.match?(/^[A-Za-z0-9\-_=]+$/) }
end

def decode_token(token)
  begin
    # トークンから "Bearer " を削除し、余分なスペースや改行を削除
    clean_token = token.sub(/^Bearer\s+/i, '').strip
    # トークンが空、短すぎる、またはJWT形式でない場合をチェック
    return "不明" if clean_token.empty? || clean_token.length < 10 || !valid_jwt?(clean_token)

    # JWTデコード（署名検証なし）
    decoded = JWT.decode(clean_token, nil, false, { algorithm: 'none' })
    decoded[0]["username"] || "不明"
  rescue JWT::DecodeError => e
    puts "トークンのデコードエラー: #{e.message} (トークン: #{token})".red
    "不明"
  rescue StandardError => e
    puts "トークンの処理エラー: #{e.message} (トークン: #{token})".red
    "不明"
  end
end

def make_withdrawal(token, username)
  begin
    # ヘッダーにトークンを追加
    headers = HEADERS.merge({ "token" => token })

    # POSTリクエストを送信
    response = HTTParty.post(URL, headers: headers, body: PAYLOAD.to_json)
    
    # レスポンスボディをJSONとして解析
    begin
      response_json = JSON.parse(response.body)
      success = response_json["success"] || false
    rescue JSON::ParserError
      # レスポンスが有効なJSONでない場合、失敗とみなす
      success = false
    end
    
    if success
      puts "[成功] アカウント #{username} の引き出しが成功しました！".green
      return true
    else
      puts "[失敗] アカウント #{username} の引き出しが失敗しました。".red
      return false
    end
  rescue StandardError => e
    puts "[エラー] アカウント #{username} でエラーが発生しました: #{e.message}".red
    return false
  end
end

def main
  # バナーをライトシアンで表示
  banner = <<-BANNER
╔══════════════════════════════════════════════╗
║       🌟 WITHDRAWAL BOT - Auto Withdraw      ║
║   Automate your Telegram wallet withdrawals! ║
║  Developed by: https://t.me/sentineldiscus   ║
╚══════════════════════════════════════════════╝
  BANNER
  puts banner.light_cyan

  tokens = read_tokens("data.txt")
  if tokens.empty?
    puts "data.txt にトークンが見つかりませんでした。"
    return
  end

  success_count = 0
  total_count = tokens.length

  tokens.each do |token|
    username = decode_token(token)
    success_count += 1 if make_withdrawal(token, username)
  end

  puts "\n完了！成功: #{success_count}/#{total_count}"
end

main if __FILE__ == $PROGRAM_NAME
