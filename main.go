package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/PuerkitoBio/goquery"
	"github.com/go-co-op/gocron/v2"
	"github.com/joho/godotenv"
)

const (
	recordFile = "record.txt"
	apiURL     = "https://go.dev/dl/?mode=json"
)

var (
	botToken      string
	chatID        string
	checkInterval time.Duration
)

type Release struct {
	Version string `json:"version"`
	Stable  bool   `json:"stable"`
}

type ReleaseInfo struct {
	Version string
	Date    string
}

func main() {
	err := godotenv.Load()
	if err != nil {
		fmt.Println("載入 .env 失敗")
		return
	}

	botToken = os.Getenv("BOT_TOKEN")
	chatID = os.Getenv("CHAT_ID")

	if botToken == "" || chatID == "" {
		fmt.Println("BOT_TOKEN 或 CHAT_ID 未設定")
		return
	}

	schedule := os.Getenv("CRON_SCHEDULE")
	if schedule == "" {
		schedule = "0 */6 * * *"
	}

	s, err := gocron.NewScheduler()
	if err != nil {
		panic(err)
	}

	_, err = s.NewJob(
		gocron.CronJob(
			schedule,
			false,
		),
		gocron.NewTask(
			checkVersion,
		),
	)

	if err != nil {
		panic(err)
	}

	s.Start()

	fmt.Println("排程啟動:", schedule)

	// 啟動時先檢查一次
	checkVersion()

	// graceful shutdown
	// 建立 signal channel
	sigChan := make(chan os.Signal, 1)

	// 監聽 Ctrl+C / docker stop
	signal.Notify(
		sigChan,
		os.Interrupt,
		syscall.SIGTERM,
	)

	// 阻塞等待 signal
	sig := <-sigChan

	fmt.Println("收到關閉訊號:", sig)

	// 建立 timeout context
	shutdownCtx, cancel := context.WithTimeout(
		context.Background(),
		10*time.Second,
	)
	defer cancel()

	done := make(chan struct{})

	go func() {
		defer close(done)

		err = s.Shutdown()
		if err != nil {
			fmt.Println("scheduler shutdown error:", err)
		}
	}()

	select {
	case <-done:
		fmt.Println("程式已安全關閉")

	case <-shutdownCtx.Done():
		fmt.Println("shutdown timeout")
	}
}

func checkVersion() {
	now := time.Now()
	fmt.Println("排程檢查:", now.Format("2006-01-02 15:04:05 -07:00")) // now.Format(time.RFC3339))

	latestVersion, err := getLatestGoVersion()
	if err != nil {
		fmt.Println("取得最新版本失敗:", err)
		return
	}

	recordedVersion, err := readRecordedVersion()
	if err != nil {
		fmt.Println("讀取紀錄檔失敗:", err)
		return
	}

	// fmt.Println("最新版本:", latestVersion)
	fmt.Println("紀錄版本:", recordedVersion)

	// 比降是否有新版本
	if latestVersion != recordedVersion {
		// 查詢 Release 網頁
		info, err := getReleaseInfo(latestVersion)
		if err != nil {
			fmt.Println(err)
			return
		}

		// fmt.Println("發現新版本")
		fmt.Println("🚀 發現新的 Go 版本：", info)

		err = sendTelegramMessage(
			fmt.Sprintf(
				"🚀 發現新的 Go 版本：%s",
				// latestVersion,
				info,
			),
		)

		if err != nil {
			fmt.Println("Telegram 發送失敗:", err)
			return
		}

		err = writeRecordedVersion(latestVersion)
		if err != nil {
			fmt.Println("更新紀錄檔失敗:", err)
			return
		}

		fmt.Println("通知完成")
	} else {
		fmt.Println("沒有新版本")
	}
	fmt.Println()
}

func getLatestGoVersion() (string, error) {
	resp, err := http.Get(apiURL)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var releases []Release

	err = json.NewDecoder(resp.Body).Decode(&releases)
	if err != nil {
		return "", err
	}

	if len(releases) == 0 {
		return "", fmt.Errorf("沒有版本資料")
	}

	return releases[0].Version, nil
}

func readRecordedVersion() (string, error) {
	data, err := os.ReadFile(recordFile)

	if os.IsNotExist(err) {
		return "", nil
	}

	if err != nil {
		return "", err
	}

	return strings.TrimSpace(string(data)), nil
}

func writeRecordedVersion(version string) error {
	return os.WriteFile(recordFile, []byte(version), 0644)
}

func sendTelegramMessage(message string) error {
	apiURL := fmt.Sprintf(
		"https://api.telegram.org/bot%s/sendMessage",
		botToken,
	)

	data := url.Values{}
	data.Set("chat_id", chatID)
	data.Set("text", message)

	resp, err := http.PostForm(apiURL, data)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("telegram API status: %s", resp.Status)
	}

	return nil
}

func getReleaseInfo(version string) (string, error) {
	resp, err := http.Get("https://go.dev/doc/devel/release")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return "", err
	}

	var result string

	doc.Find("p").Each(func(i int, s *goquery.Selection) {
		id, exists := s.Attr("id")
		if !exists {
			return
		}

		// 找到對應 version 的 <p id="go1.26.3">
		if id == version {
			text := strings.Join(strings.Fields(s.Text()), " ")
			// 只保留前半段（避免 includes）
			// go1.26.3 (released 2026-05-07) includes ...
			// if idx := strings.Index(text, "includes"); idx != -1 {
			// 	result = strings.TrimSpace(text[:idx])
			// }
			if before, _, ok := strings.Cut(text, "includes"); ok {
				result = strings.TrimSpace(before)
			}
		}
	})

	if result == "" {
		return "", fmt.Errorf("version not found")
	}

	return result, nil
}
