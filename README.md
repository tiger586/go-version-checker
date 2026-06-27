# 🚀 Go 版本更新通知機器人（Telegram Bot）

一個輕量級 Go 服務，用來監控 Go 語言新版本發布，並透過 Telegram 即時通知。

本專案整合：

* Go 官方下載 API（版本來源）
* Go Release 網頁爬蟲（取得發布日期與資訊）
* Telegram 通知機制
* 本地紀錄檔避免重複通知
* 內建排程檢查（不需系統 cron）

---

## ✨ 功能特色

* 🔎 自動檢查最新 Go 版本
* 📅 解析官方 Release 頁面取得發布日期
* 🚨 發現新版本即時推送 Telegram
* 🧠 使用 **record.txt** 避免重複通知
* ⏰ 可透過 **.env** 設定檢查間隔
* 🐳 支援 Docker Compose 部署
* 🧩 內建排程（不依賴系統 cron）

---

## 📦 系統架構

```
Go Download API → 取得版本
        ↓
Go Release 頁面 → 取得發布日期
        ↓
與本地 record.txt 比對
        ↓
若有更新 → 發送 Telegram 通知
```

---

## ⚙️ 環境設定

建立 **.env** 檔案：

```env
BOT_TOKEN=你的Telegram Bot Token
CHAT_ID=你的Telegram Chat ID

# 分 時 日 月 星期
CRON_SCHEDULE=0 */6 * * *
```

---

### ⏱ 時間格式

|分| 時| 日| 月| 星期|
|--|--|--|--|--|
|0| */6| *| *| *|

> [!TIP]
>
> **這個意思是，每天這些時間執行**
>  
> 00:00  
> 06:00  
> 12:00  
> 18:00  

---

## 📁 專案結構

```
./
├── main.go
├── go.mod
├── record.txt
├── .env.example
├── .env
├── docker-compose.yml
├── go-upgrade.sh   # 自動更新 Go 的腳本
└── app/
    ├── .env
    ├── record.txt  # 紀錄檔
    └── gocheck     # 編譯後執行檔
```

---

## 🚀 執行流程

1. 從 Go 官方 API 取得最新版本：
   [https://go.dev/dl/?mode=json](https://go.dev/dl/?mode=json)

2. 從 Release 頁面取得版本資訊與日期：
   [https://go.dev/doc/devel/release](https://go.dev/doc/devel/release)

3. 與本地 **record.txt** 比對

4. 若版本不同：

   * 發送 Telegram 通知
   * 更新 record 檔案

---

## 🧪 Telegram 通知範例

```
🚀 發現新的 Go 版本：go1.26.3 (released 2026-05-07)
```

---

## 🏃 本地執行

### 1️⃣ 安裝依賴

```bash
go mod tidy
```

### 🛠️ 複製設定檔
```bash
cp .env.example .env
```

### ⚙️ 環境設定

編輯 **.env** 檔案：

```env
BOT_TOKEN=你的Telegram Bot Token
CHAT_ID=你的Telegram Chat ID

# 分 時 日 月 星期
CRON_SCHEDULE=0 */6 * * *
```

### 2️⃣ 執行程式

```bash
go run .
```

---

## 🐳 Docker 部署

### 📋 複製檔案

```bash
mkdir app
cp .env.example ./app/.env
cp record.txt ./app
```

### ⚙️ 環境設定

編輯 **./app/.env** 檔案：

```env
BOT_TOKEN=你的Telegram Bot Token
CHAT_ID=你的Telegram Chat ID

# 分 時 日 月 星期
CRON_SCHEDULE=0 */6 * * *
```

### 1️⃣ 編譯程式

```bash
go build -o app/gocheck .
```
或是 縮小編譯出來的二進位檔案體積（產物大小）
```bash
go build -ldflags "-s -w" -o app/gocheck .
```

### 2️⃣ 啟動服務

```bash
docker compose up -d
```

---

## 📄 docker-compose.yml

```yaml
services:
  gocheck:
    image: alpine:latest
    container_name: gocheck
    restart: always
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - ./app:/app
    working_dir: /app
    command: ./gocheck
```

---

## 🧠 設計說明

### 為什麼不使用系統的 cron？

本專案使用 go-co-op/gocron 套件：

* 更容易部署
* Docker 友善
* 不依賴系統排程
* 邏輯集中在程式內

---

### 為什麼使用雙來源？

| 來源            | 用途       |
| --------------- | -------- |
| Go Download API | 取得版本（穩定） |
| Release 頁面    | 取得發布日期     |

---

## 📊 執行流程圖

```
啟動程式
   ↓
排程檢查
   ↓
取得最新版本
   ↓
讀取 record.txt
   ↓
若版本不同 → 抓 release 資訊
   ↓
發送 Telegram
   ↓
更新 record.txt
   ↓
等待下一次檢查
```

---

## 🔐 安全提醒

* **.env** 請勿上傳到 GitHub
* **record.txt** 為本地狀態檔案
* Telegram Token 請妥善保管

---
## ✨ go-upgrade.sh 自動下載更新 Go，只適用於 Linux 系統  
使用方式：sudo ./go-upgrade.sh <版本號>  
例如：
```bash
sudo ./go-upgrade.sh 1.26.4
```

### 下載後執行：
```bash
wget https://raw.githubusercontent.com/tiger586/go-version-checker/main/go-upgrade.sh
chmod +x ./go-upgrade.sh
sudo ./go-upgrade.sh 1.26.4
```

### 直接執行腳本：
```bash
curl -fsSL https://raw.githubusercontent.com/tiger586/go-version-checker/main/go-upgrade.sh | sudo bash -s -- 1.26.4
```

> [!TIP] 未安裝過 Go 也會自動安裝，但是執行路徑需要手動設定
>
> **腳本有防呆機制，低於或等於目前的版本不會更新**
>

---

## 📜 授權

MIT License
