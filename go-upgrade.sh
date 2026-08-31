#!/bin/bash
# 自動下載更新 Go 版本（含版本偵測與比較）

set -u

# 檢查是否以 root (sudo) 權限執行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 錯誤：此腳本需要 root 權限，請使用 sudo 執行！"
    echo "範例：sudo $0 <版本號>"
    exit 1
fi

# 1. 檢查使用者有沒有輸入版本號
if [ -z "${1:-}" ]; then
    echo "❌ 錯誤：請指定 Go 的版本號！"
    echo "用法：sudo $0 <版本號>  (例如：sudo $0 1.27.0)"
    exit 1
fi

TARGET_VERSION=$1

# 偵測系統架構 (amd64/x86_64 或 arm64/aarch64)
ARCH_TYPE=$(uname -m)

# 轉換架構名稱以符合 Go 的官方命名
case "$ARCH_TYPE" in
    x86_64)  ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "不支援的架構: $ARCH_TYPE"; exit 1 ;;
esac

FILENAME="go${TARGET_VERSION}.linux-${ARCH}.tar.gz"
URL="https://go.dev/dl/${FILENAME}"
TMP_DIR="/tmp/go_update_$(date +%s)"

echo "🔍 正在檢查系統目前的 Go 版本..."

# 2. 偵測目前系統的 Go 版本
CURRENT_VERSION=""

# 直接檢查這個絕對路徑下有沒有 Go 的執行檔
if [ -x "/usr/local/go/bin/go" ]; then
    # 直接用絕對路徑去抓版本號
    CURRENT_VERSION=$(/usr/local/go/bin/go version | awk '{print $3}' | sed 's/go//')
fi

# 3. 版本比較邏輯
if [ -n "$CURRENT_VERSION" ]; then
    echo "💻 目前系統版本: ${CURRENT_VERSION}"
    echo "🎯 準備更新版本: ${TARGET_VERSION}"

    # 如果版本一模一樣，直接退出
    if [ "$CURRENT_VERSION" = "$TARGET_VERSION" ]; then
        echo "💡 系統目前的版本已經是 ${TARGET_VERSION}，無需更新！"
        exit 0
    fi

    # 使用 sort -V 來比較版本號大小
    # printf 把兩個版本號餵給 sort -V，排序後如果第一行是目標版本，代表目標版本比較舊
    OLDER_VERSION=$(printf '%s\n%s\n' "$TARGET_VERSION" "$CURRENT_VERSION" | sort -V | head -n 1)
    
    if [ "$OLDER_VERSION" = "$TARGET_VERSION" ]; then
        echo "⚠️  警告：你想安裝的版本 (${TARGET_VERSION}) 並沒有比目前系統的版本 (${CURRENT_VERSION}) 還新！"
        echo "🛑 腳本已自動中斷執行。"
        exit 0
    fi
    
    echo "✅ 檢查通過：目標版本較新，開始執行更新流程。"
else
    echo "ℹ️ 系統目前未安裝 Go，將直接進行全新安裝。"
fi

# -----------------------------------------------------------------
# 4. 開始下載與安全更新流程
# -----------------------------------------------------------------
echo "🚀 準備更新 Go 至版本: ${TARGET_VERSION}..."
mkdir -p "${TMP_DIR}"

echo "📥 正在下載 ..."
PWD_BAK=$(pwd)
cd "${TMP_DIR}"
wget -q --show-progress --progress=bar:force "${URL}"
# 雙重檢查：1. 檢查 wget 的結束狀態碼  2. 檢查檔案是否真的存在且大於 0 位元組 (-s)
if [ $? -ne 0 ] || [ ! -s "${FILENAME}" ]; then
    echo "❌ 錯誤：檔案下載失敗！請檢查版本號是否正確，或網路是否連通。"
    cd "${PWD_BAK}"
    rm -rf "${TMP_DIR}"
    exit 1    
fi
cd "${PWD_BAK}"

echo "📦 正在解壓縮並安裝更新..."
mkdir -p "${TMP_DIR}/go_extracted"
tar -C "${TMP_DIR}/go_extracted" -xzf "${TMP_DIR}/${FILENAME}"

if [ $? -eq 0 ]; then
    rm -rf /usr/local/go
    mv "${TMP_DIR}/go_extracted/go" /usr/local/go
    
    echo "✨ Go ${TARGET_VERSION} 更新成功！"
    echo "----------------------------------------"
    /usr/local/go/bin/go version
    echo "----------------------------------------"
else
    echo "❌ 更新失敗，解壓縮過程發生錯誤。"
fi

rm -rf "${TMP_DIR}"

# 自動設定路徑
# 1. 判斷目前使用的是哪一種 Shell，精準偵測「觸發 sudo 前」的原始 Shell
if [ -n "$SUDO_USER" ]; then
    # 方法 A：在 Linux/Mac 通用的 ps 溯源法（尋找父程序的 Shell 名稱）
    # $$ 是目前腳本 PID，$PPID 是 sudo 的 PID，我們再往上一層找就是原本的 Shell
    PARENT_PID=$(ps -o ppid= -p $PPID | tr -d ' ')
    ORIGINAL_SHELL_PATH=$(ps -o comm= -p $PARENT_PID | tr -d '-')
    CURRENT_SHELL=$(basename "$ORIGINAL_SHELL_PATH" 2>/dev/null)
    
    # 備用防錯：如果 ps 抓不到，則直接去系統資料庫讀取該使用者的預設 Shell
    if [ -z "$CURRENT_SHELL" ] || [ "$CURRENT_SHELL" = "sudo" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            CURRENT_SHELL=$(dscl . -read "/Users/$SUDO_USER" UserShell | awk '{print $2}' | xargs basename)
        else
            CURRENT_SHELL=$(getent passwd "$SUDO_USER" | cut -d: -f7 | xargs basename)
        fi
    fi
else
    # 如果不是用 sudo 執行的正常情況
    CURRENT_SHELL=$(basename "$SHELL" 2>/dev/null)
    if [ -z "$CURRENT_SHELL" ]; then
        CURRENT_SHELL=$(ps -p $$ -o comm= | tr -d '-')
    fi
fi

# ================= 修正核心：決定正確的家目錄 =================
# 如果是用 sudo 執行，則優先使用原本呼叫者的家目錄，否則才用目前的 $HOME
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(eval echo "~$SUDO_USER")
else
    USER_HOME="$HOME"
fi
# ============================================================

# 2. 根據 Shell 類型指定對應的設定檔（改用 $USER_HOME）
RC_FILE=""
case "$CURRENT_SHELL" in
    zsh)
        RC_FILE="$USER_HOME/.zshrc"
        ;;
    bash|sh)
        RC_FILE="$USER_HOME/.profile"
        ;;
    *)
        RC_FILE="$USER_HOME/.profile"
        ;;
esac

# 3. 定義要檢查與加入的環境變數內容
TARGET_LINE='export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin'

# 確保設定檔存在，若不存在則建立空檔案
touch "$RC_FILE"

# 4. 檢查檔案內是否已存在該設定
if fgrep -qxF "$TARGET_LINE" "$RC_FILE"; then
    # echo "💡 Go 路徑已存在於 $RC_FILE 中，無需設定。"
    echo ""
else
    # 5. 自動加入設定並提示使用者
    echo "" >> "$RC_FILE"
    echo "$TARGET_LINE" >> "$RC_FILE"
    
    # 修正：因為用 sudo 建立的檔案擁有者會變成 root，要把檔案權限還給原本的使用者
    if [ -n "$SUDO_USER" ]; then
        chown "$SUDO_USER" "$RC_FILE"
    fi

    echo "✅ 已將 Go 路徑加入至 $RC_FILE。"
    echo "💡 請執行 source $RC_FILE 或重開終端機以啟用設定。"
    echo ""
fi
