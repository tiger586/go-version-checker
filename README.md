# 🚀 Go 版本更新通知機器人（Telegram Bot）

一個輕量級 Go 服務，用來監控 Go 語言新版本發布，並透過 Telegram 即時通知。

本專案整合：

* Go 官方下載 API（版本來源）
* Go Release 網頁爬蟲（取得發布日期與資訊）
* Telegram 通知機制
* 本地紀錄檔避免重複通知
* 內建定時檢查（不需 cron）

---

## ✨ 功能特色

* 🔎 自動檢查最新 Go 版本
* 📅 解析官方 Release 頁面取得發布日期
* 🚨 發現新版本即時推送 Telegram
* 🧠 使用 **record.txt** 避免重複通知
* ⏰ 可透過 **.env** 設定檢查間隔
* 🐳 支援 Docker Compose 部署
* 🧩 內建 ticker 排程（不依賴 cron）

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
CHECK_INTERVAL=6h

BOT_TOKEN=你的Telegram Bot Token
CHAT_ID=你的Telegram Chat ID
```

---

### ⏱ 支援時間格式

| 格式    | 說明   |
| ----- | ---- |
| **10s** | 10 秒 |
| **5m**  | 5 分鐘 |
| **6h**  | 6 小時 |
| **24h** | 1 天  |

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
CHECK_INTERVAL=6h

BOT_TOKEN=你的Telegram Bot Token
CHAT_ID=你的Telegram Chat ID
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
CHECK_INTERVAL=6h

BOT_TOKEN=你的Telegram Bot Token
CHAT_ID=你的Telegram Chat ID
```

### 1️⃣ 編譯程式

```bash
go build -o app/gocheck .
```

### 2️⃣ 啟動服務

```bash
docker-compose up -d
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

### 為什麼不使用 cron？

本專案使用 Go 內建 ticker：

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
定時檢查
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

## 📜 授權

MIT License
