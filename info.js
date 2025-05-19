require('dotenv').config();
const axios = require('axios');
const fs = require('fs').promises;
const retry = require('async-retry');

const BASE_URL = "https://mpc-api.planx.io/api/v1/telegram";
const HEADERS = {
    "accept": "application/json, text/plain, */*",
    "accept-encoding": "gzip, deflate, br, zstd",
    "accept-language": "en-US,en;q=0.9",
    "origin": "https://tg-wallet.planx.io",
    "priority": "u=1, i",
    "referer": "https://tg-wallet.planx.io/",
    "sec-ch-ua": '"Microsoft Edge";v="136", "Microsoft Edge WebView2";v="136", "Not.A/Brand";v="99", "Chromium";v="136"',
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": '"Windows"',
    "sec-fetch-dest": "empty",
    "sec-fetch-mode": "cors",
    "sec-fetch-site": "same-site",
    "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36 Edg/136.0.0.0",
};

const REQUEST_TIMEOUT = 10000;
const RETRY_ATTEMPTS = 3;
const RETRY_WAIT = 5000;
const TELEGRAM_MESSAGE_DELAY = 4000;

const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID;

console.log('TELEGRAM_BOT_TOKEN:', TELEGRAM_BOT_TOKEN);
console.log('TELEGRAM_CHAT_ID:', TELEGRAM_CHAT_ID);

if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) {
    console.error('Error: TELEGRAM_BOT_TOKEN atau TELEGRAM_CHAT_ID tidak ditemukan di .env');
    process.exit(1);
}

const TELEGRAM_API_URL = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
console.log('TELEGRAM_API_URL:', TELEGRAM_API_URL);

const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function sendToTelegram(message) {
    try {
        const payload = {
            chat_id: TELEGRAM_CHAT_ID,
            text: message,
            parse_mode: "Markdown"
        };
        const response = await retry(async () => {
            try {
                const res = await axios.post(TELEGRAM_API_URL, payload, { timeout: REQUEST_TIMEOUT });
                return res;
            } catch (error) {
                if (error.response && error.response.status === 429) {
                    const retryAfter = error.response.data.parameters?.retry_after * 1000 || 10000;
                    console.log(`Rate limit terdeteksi, menunggu ${retryAfter}ms...`);
                    await delay(retryAfter);
                    throw error;
                }
                throw error;
            }
        }, {
            retries: RETRY_ATTEMPTS,
            factor: 1,
            minTimeout: RETRY_WAIT,
            onRetry: (err, attempt) => console.log(`Mengirim ulang pesan ke Telegram (percobaan ${attempt}/${RETRY_ATTEMPTS})...`)
        });
        await delay(TELEGRAM_MESSAGE_DELAY);
        return response.data;
    } catch (error) {
        const errorMessage = `Gagal mengirim pesan ke Telegram: ${error.message}`;
        if (error.response) {
            console.log('Error Response:', error.response.data);
        }
        console.log(errorMessage);
        return { error: errorMessage };
    }
}

function encodeToPlanxHex(code) {
    const fullCode = `invite_${code}`;
    return Array.from(fullCode)
        .map(char => char.charCodeAt(0).toString(16).padStart(2, '0'))
        .join('');
}

function cleanToken(token) {
    if (!token) return null;
    const cleaned = token.replace(/^bearer\s*/i, '').trim();
    if ((cleaned.match(/\./g) || []).length < 2) return null;
    return cleaned;
}

async function readTokens(filePath = "data.txt") {
    try {
        const data = await fs.readFile(filePath, 'utf8');
        const tokens = [];
        const lines = data.split('\n').filter(line => line.trim() !== '');
        for (let [index, line] of lines.entries()) {
            const cleanedToken = cleanToken(line);
            if (cleanedToken) {
                tokens.push(cleanedToken);
            } else {
                const message = `❌ Token di baris ${index + 1} tidak valid: \`${line.trim()}\``;
                await sendToTelegram(message);
                console.log(`Token di baris ${index + 1} tidak valid: ${line.trim()}`);
            }
        }
        return { tokens, totalAccounts: lines.length };
    } catch (error) {
        const message = error.code === 'ENOENT' 
            ? `❌ File ${filePath} tidak ditemukan.` 
            : `❌ Error membaca file ${filePath}: \`${error.message}\``;
        await sendToTelegram(message);
        console.log(message);
        return { tokens: [], totalAccounts: 0 };
    }
}

async function getAsset(token) {
    const url = `${BASE_URL}/task/asset`;
    const headers = { ...HEADERS, token: `Bearer ${token}` };
    return await retry(async () => {
        const response = await axios.get(url, { headers, timeout: REQUEST_TIMEOUT });
        return response.data;
    }, {
        retries: RETRY_ATTEMPTS,
        factor: 1,
        minTimeout: RETRY_WAIT,
        onRetry: (err, attempt) => console.log(`Retrying request (attempt ${attempt}/${RETRY_ATTEMPTS})...`)
    });
}

async function getInfo(token) {
    const url = `${BASE_URL}/info`;
    const headers = { ...HEADERS, token: `Bearer ${token}` };
    return await retry(async () => {
        const response = await axios.get(url, { headers, timeout: REQUEST_TIMEOUT });
        return response.data;
    }, {
        retries: RETRY_ATTEMPTS,
        factor: 1,
        minTimeout: RETRY_WAIT,
        onRetry: (err, attempt) => console.log(`Retrying request (attempt ${attempt}/${RETRY_ATTEMPTS})...`)
    });
}

async function getInviteAsset(token) {
    const url = `${BASE_URL}/invite/asset`;
    const headers = { ...HEADERS, token: `Bearer ${token}` };
    return await retry(async () => {
        const response = await axios.get(url, { headers, timeout: REQUEST_TIMEOUT });
        return response.data;
    }, {
        retries: RETRY_ATTEMPTS,
        factor: 1,
        minTimeout: RETRY_WAIT,
        onRetry: (err, attempt) => console.log(`Retrying request (attempt ${attempt}/${RETRY_ATTEMPTS})...`)
    });
}

async function getWithdrawalAssets(token) {
    const url = `${BASE_URL}/withdrawal/assets`;
    const headers = { ...HEADERS, token: `Bearer ${token}` };
    return await retry(async () => {
        const response = await axios.get(url, { headers, timeout: REQUEST_TIMEOUT });
        return response.data;
    }, {
        retries: RETRY_ATTEMPTS,
        factor: 1,
        minTimeout: RETRY_WAIT,
        onRetry: (err, attempt) => console.log(`Retrying request (attempt ${attempt}/${RETRY_ATTEMPTS})...`)
    });
}

async function getWithdrawalHistory(token) {
    const url = `${BASE_URL}/withdrawal/history?page=1&size=10`;
    const headers = { ...HEADERS, token: `Bearer ${token}` };
    return await retry(async () => {
        const response = await axios.get(url, { headers, timeout: REQUEST_TIMEOUT });
        return response.data;
    }, {
        retries: RETRY_ATTEMPTS,
        factor: 1,
        minTimeout: RETRY_WAIT,
        onRetry: (err, attempt) => console.log(`Retrying request (attempt ${attempt}/${RETRY_ATTEMPTS})...`)
    });
}

async function processAccount(token, accountNumber) {
    let logMessage = `=== Akun ${accountNumber} ===\n`;
    let status = "Berhasil";
    let errorReason = "";
    let auditCount = 0;
    let pepeTotal = 0;

    if (!token) {
        logMessage += "❌ Token tidak valid atau kosong.\n";
        status = "Gagal";
        errorReason = "Token tidak valid atau kosong";
        await sendToTelegram(logMessage);
        console.log(`Akun ${accountNumber} ${status}: ${errorReason}`);
        return { auditCount, pepeTotal };
    }

    let infoResponse;
    try {
        const assetResponse = await getAsset(token);
        if (assetResponse.error) {
            logMessage += `❌ Error: ${assetResponse.error}\nRaw asset response:\n\`\`\`\n${JSON.stringify(assetResponse, null, 2)}\n\`\`\`\n`;
            status = "Gagal";
            errorReason = assetResponse.error;
        } else if (assetResponse.success && assetResponse.data) {
            const amount = assetResponse.data.amount || "Tidak tersedia";
            logMessage += `• PX: ${amount}\n`;
        } else {
            logMessage += `❌ Asset response tidak valid:\n\`\`\`\n${JSON.stringify(assetResponse, null, 2)}\n\`\`\`\n`;
            status = "Gagal";
            errorReason = "Asset response tidak valid";
        }
    } catch (error) {
        logMessage += `❌ Gagal mengambil data asset: ${error.message}\n`;
        status = "Gagal";
        errorReason = `Gagal mengambil data asset: ${error.message}`;
    }

    try {
        const withdrawalAssetsResponse = await getWithdrawalAssets(token);
        if (withdrawalAssetsResponse.error) {
            logMessage += `❌ Error: ${withdrawalAssetsResponse.error}\nRaw withdrawal assets response:\n\`\`\`\n${JSON.stringify(withdrawalAssetsResponse, null, 2)}\n\`\`\`\n`;
            status = "Gagal";
            errorReason = withdrawalAssetsResponse.error || errorReason;
        } else if (withdrawalAssetsResponse.success && withdrawalAssetsResponse.data) {
            const pepeAsset = withdrawalAssetsResponse.data.find(asset => asset.symbol === "PEPE");
            const pepeAmount = pepeAsset ? pepeAsset.amount : "Tidak tersedia";
            logMessage += `• PEPE: ${pepeAmount}\n`;
        } else {
            logMessage += `❌ Withdrawal assets response tidak valid:\n\`\`\`\n${JSON.stringify(withdrawalAssetsResponse, null, 2)}\n\`\`\`\n`;
            status = "Gagal";
            errorReason = "Withdrawal assets response tidak valid";
        }
    } catch (error) {
        logMessage += `❌ Gagal mengambil data withdrawal assets: ${error.message}\n`;
        status = "Gagal";
        errorReason = `Gagal mengambil data withdrawal assets: ${error.message}`;
    }

    try {
        infoResponse = await getInfo(token);
        if (infoResponse.error) {
            logMessage += `❌ Error: ${infoResponse.error}\nRaw info response:\n\`\`\`\n${JSON.stringify(infoResponse, null, 2)}\n\`\`\`\n`;
            status = "Gagal";
            errorReason = infoResponse.error || errorReason;
        } else if (infoResponse.success && infoResponse.data) {
            const nickName = infoResponse.data.nickName || "Tidak tersedia";
            const inviteCode = infoResponse.data.inviteCode || "Tidak tersedia";
            const hexInviteCode = inviteCode !== "Tidak tersedia" ? encodeToPlanxHex(inviteCode) : "Tidak tersedia";
            logMessage += `• Nickname: ${nickName}\n`;
            logMessage += `• Invite Code: https://t.me/PlanXWalletBot/PlanXWalletApp?startapp=${hexInviteCode}\n`;
        } else {
            logMessage += `❌ Info response tidak valid:\n\`\`\`\n${JSON.stringify(infoResponse, null, 2)}\n\`\`\`\n`;
            status = "Gagal";
            errorReason = "Info response tidak valid";
        }
    } catch (error) {
        logMessage += `❌ Gagal mengambil data info: ${error.message}\n`;
        status = "Gagal";
        errorReason = `Gagal mengambil data info: ${error.message}`;
    }

    try {
        const inviteAssetResponse = await getInviteAsset(token);
        if (inviteAssetResponse.error) {
            logMessage += `❌ Error: ${inviteAssetResponse.error}\nRaw invite asset response:\n\`\`\`\n${JSON.stringify(inviteAssetResponse, null, 2)}\n\`\`\`\n`;
            status = "Gagal";
            errorReason = inviteAssetResponse.error || errorReason;
        } else if (inviteAssetResponse.success && inviteAssetResponse.data) {
            const inviteCount = inviteAssetResponse.data.inviteCount || "Tidak tersedia";
            logMessage += `• Invite Count: ${inviteCount}\n`;
        } else {
            logMessage += `❌ Invite asset response tidak valid:\n\`\`\`\n${JSON.stringify(inviteAssetResponse, null, 2)}\n\`\`\`\n`;
            status = "Gagal";
            errorReason = "Invite asset response tidak valid";
        }
    } catch (error) {
        logMessage += `❌ Gagal mengambil data invite asset: ${error.message}\n`;
        status = "Gagal";
        errorReason = `Gagal mengambil data invite asset: ${error.message}`;
    }

    try {
        const withdrawalHistoryResponse = await getWithdrawalHistory(token);
        if (withdrawalHistoryResponse.error) {
            logMessage += `❌ Error: ${withdrawalHistoryResponse.error}\nRaw withdrawal history response:\n\`\`\`\n${JSON.stringify(withdrawalHistoryResponse, null, 2)}\n\`\`\`\n`;
            status = "Gagal";
            errorReason = withdrawalHistoryResponse.error || errorReason;
        } else if (withdrawalHistoryResponse.success && withdrawalHistoryResponse.data && withdrawalHistoryResponse.data.items) {
            const auditOrders = withdrawalHistoryResponse.data.items.filter(item => item.orderStatus === 4);
            if (auditOrders.length > 0) {
                auditCount = auditOrders.length;
                pepeTotal = auditOrders.reduce((sum, order) => {
                    try {
                        const amount = parseFloat(order.sourceAmount);
                        return isNaN(amount) ? sum : sum + amount;
                    } catch (e) {
                        console.log(`Error parsing sourceAmount ${order.sourceAmount}: ${e.message}`);
                        return sum;
                    }
                }, 0);
                logMessage += `• Status: Under Audit ${auditCount}\n`;
                if (auditOrders.length === 1) {
                    logMessage += `    PEPE ${auditOrders[0].sourceAmount}\n`;
                } else {
                    auditOrders.forEach((order, index) => {
                        logMessage += `    ${index + 1}. PEPE ${order.sourceAmount}\n`;
                    });
                }
            } else {
                logMessage += `• Status: Under Audit 0\n`;
            }
        } else {
            logMessage += `❌ Withdrawal history response tidak valid:\n\`\`\`\n${JSON.stringify(withdrawalHistoryResponse, null, 2)}\n\`\`\`\n`;
            status = "Gagal";
            errorReason = "Withdrawal history response tidak valid";
        }
    } catch (error) {
        logMessage += `❌ Gagal mengambil data withdrawal history: ${error.message}\n`;
        status = "Gagal";
        errorReason = `Gagal mengambil data withdrawal history: ${error.message}`;
    }

    if (infoResponse?.success && infoResponse.data) {
        logMessage += `• Non-Hex: ${infoResponse.data.inviteCode || "Tidak tersedia"}\n`;
    }

    await sendToTelegram(logMessage);
    console.log(`Akun ${accountNumber} ${status}${errorReason ? `: ${errorReason}` : ''}`);
    return { auditCount, pepeTotal };
}

async function main() {
    console.log(`
╔══════════════════════════════════════════════╗
║       🌟 PlanX Bot - Automated Tasks         ║
║   Automate your PlanX Wallet account tasks!  ║
║  Developed by: https://t.me/sentineldiscus   ║
╚══════════════════════════════════════════════╝
    `);

    const { tokens, totalAccounts } = await readTokens();
    if (!tokens.length && totalAccounts === 0) {
        const message = "❌ Tidak ada token yang ditemukan. Pastikan data.txt ada dan berisi token yang valid.";
        await sendToTelegram(message);
        console.log(message);
        return;
    }

    let totalAuditCount = 0;
    let totalPepe = 0;

    for (let [index, token] of tokens.entries()) {
        try {
            const { auditCount, pepeTotal } = await processAccount(token, index + 1);
            totalAuditCount += auditCount;
            totalPepe += pepeTotal;
        } catch (error) {
            const errorMessage = `❌ Error memproses akun ${index + 1}: \`${error.message}\``;
            await sendToTelegram(errorMessage);
            console.log(`Akun ${index + 1} Gagal: ${error.message}`);
        }
    }

    const summaryMessage = `
Jumlah Status Under Audit: ${totalAuditCount}
Jumlah PEPE Under Audit: ${totalPepe}
Total Akun: ${totalAccounts}
    `;
    await sendToTelegram(summaryMessage);
    console.log(summaryMessage);
}

main().catch(console.error);
