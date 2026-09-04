# Raspberry Pi 5 报警拍照与 HDMI 四宫格

本目录接替原先位于 FPGA 内的 OV5640、四帧 BRAM 和 HDMI 逻辑。CSI 摄像头与 HDMI 显示器都连接 Raspberry Pi 5；FPGA 只通过 3.3V TTL UART 发送报警事件。

## 为什么选择 UART

报警拍照只需要传递一个低速控制事件，无需在 FPGA 与树莓派之间传图。UART 只占两根信号线，时序简单，Raspberry Pi 5 与 HX7A75A 都是 3.3V 电平；本项目还加入了 ACK 和自动重发，比单根 GPIO 脉冲更不容易丢事件。相较 SPI，UART 不需要额外片选和时钟线；相较以太网，也不依赖网络配置。

通信格式为 115200-8-N-1：

```text
FPGA -> Pi: ALARM\n     # 未收到 ACK 时每 500 ms 重发
Pi -> FPGA: ACK\n       # 收到事件后立即回复
Pi -> FPGA: DONE\n      # 四帧保存并显示成功
Pi -> FPGA: ERR\n       # 相机初始化或抓拍失败
```

## 接线

使用 FPGA 上未接矩阵键盘的另一组 40 针 GPIO 扩展口。请以 `GPIOA_0/GPIOA_1` 丝印和缺口方向确认排针，不要仅凭左右位置猜测。

| 连接 | FPGA 端 | 树莓派 5 的 40 针 GPIO |
|---|---|---|
| FPGA TX -> Pi RX | GPIOA_0，扩展口脚 1，芯片脚 J16 | GPIO15/RXD0，物理脚 10 |
| Pi TX -> FPGA RX | GPIOA_1，扩展口脚 2，芯片脚 H13 | GPIO14/TXD0，物理脚 8 |
| GND <-> GND | 扩展口脚 12 或 30 | 物理脚 6 |

必须交叉 TX/RX，并连接公共地。两块板各自供电，**不要连接两边的 3.3V 或 5V 电源脚，也不要把 5V 接到 UART 信号线**。建议使用不超过 30 cm 的杜邦线。

CSI 摄像头插入 Raspberry Pi 5 的 CAM/DISP 接口，并使用适配树莓派 5 的 22 针排线；显示器连接树莓派的 micro-HDMI，不再连接 FPGA 的 HDMI。

## 树莓派系统配置

建议使用带桌面的 64 位 Raspberry Pi OS Bookworm 或更新版本。Picamera2 是当前受支持的 Python 相机接口，旧版 `picamera`/`raspistill` 不适用于本工程。

1. 将本目录复制到树莓派，进入目录并安装依赖：

   ```bash
   chmod +x scripts/*.sh
   ./scripts/install.sh
   ```

2. 运行 `sudo raspi-config`，进入 `Interface Options -> Serial Port`：

   - Serial login shell 选择 **No**；
   - Serial port hardware 选择 **Yes**。

3. 检查 `/boot/firmware/config.txt`，确保包含：

   ```ini
   enable_uart=1
   dtoverlay=uart0-pi5
   ```

4. 重启并确认 GPIO14/15 的 UART0 设备存在：

   ```bash
   ls -l /dev/ttyAMA0
   pinctrl get 14 15
   ```

   `config.json` 默认使用 `/dev/ttyAMA0`。如果系统实际生成了不同设备名，以 `dmesg | grep -i tty` 和 `ls -l /dev/ttyAMA*` 的结果为准修改配置。

5. 先单独检查摄像头：

   ```bash
   rpicam-hello -t 5000
   ```

官方参考：[UART 配置](https://www.raspberrypi.com/documentation/computers/configuration.html#configure-uarts)、[Raspberry Pi 相机软件](https://www.raspberrypi.com/documentation/computers/camera_software.html)。

## 运行

复制默认配置并启动：

```bash
cp config.example.json config.json
./scripts/run.sh
```

程序启动后先显示色条并等待 FPGA。第四次密码错误时，它会立即回 ACK，连续保存四张 `640×480` JPEG，生成一张 `640×480` 四宫格，并在 HDMI 上保持全屏显示。每次报警文件位于：

```text
captures/YYYYMMDD_HHMMSS_mmmmmm/
├── frame_1.jpg
├── frame_2.jpg
├── frame_3.jpg
├── frame_4.jpg
└── mosaic.jpg
```

按 `Esc` 或 `q` 退出。修改 `config.json` 可调整串口、捕获间隔和保存目录，但 `capture_count` 必须保持为 4。

## 无摄像头自检

在连接 FPGA 前，可先验证保存和四宫格显示：

```bash
./scripts/run.sh --mock-camera --trigger-on-start --windowed
```

无桌面环境时使用：

```bash
./scripts/run.sh --mock-camera --trigger-on-start --headless
```

运行软件单元测试：

```bash
python3 -m unittest discover -s tests -v
```

## FPGA 开关参数

FPGA 顶层参数 `ENABLE_RPI_CAMERA` 默认是 1。若只需要密码锁、不接树莓派，可在 PowerShell 构建时使用：

```powershell
.\password_lock_system\scripts\run_all.ps1 -DisableRaspberryPiCamera
```

关闭后 UART 协议逻辑从综合结果中移除，TX 保持空闲高电平；密码锁、Flash、键盘、数码管、LED 和蜂鸣器均不受影响。

## 自动启动建议

整机联调通过后，可把 `scripts/run.sh` 添加到 Raspberry Pi 桌面环境的自动启动项。由于全屏 OpenCV 窗口需要图形会话，本工程没有默认安装系统级后台服务，以免程序在没有 `DISPLAY`/Wayland 会话时启动失败。
