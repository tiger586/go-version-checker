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
    echo "ℹ️  系統目前未安裝 Go，將直接進行全新安裝。"
fi

# -----------------------------------------------------------------
# 4. 開始下載與安全更新流程
# -----------------------------------------------------------------
echo "🚀 準備更新 Go 至版本: ${TARGET_VERSION}..."
mkdir -p "${TMP_DIR}"

echo "📥 正在下載 ${FILENAME}..."
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

echo "📦 正在解壓縮並安全更新..."
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