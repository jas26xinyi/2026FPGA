# HX7A75A FPGA 密码锁与树莓派报警相机

这是一个面向数字系统课程设计的密码锁系统。密码输入、状态显示、密码保存和声光报警运行在 HX7A75A FPGA 上；报警拍照和四宫格显示运行在 Raspberry Pi 5 上。

目标 FPGA 为 Xilinx Artix-7 `xc7a75tfgg484-2`，开发环境为 Vivado 2023.2。摄像头使用 CSI 排线连接树莓派 5，显示器连接树莓派 HDMI；FPGA 不再直接连接摄像头或显示器。

## 系统结构

```text
4x4 矩阵键盘 -> FPGA 密码锁 -> 数码管 / LED / 蜂鸣器
                            -> W25Q64 固定密码
                            -> 3.3V UART 报警事件
                                         |
                                         v
CSI 摄像头 ----------> Raspberry Pi 5 ----------> HDMI 显示器
                               |
                               +---- 四张照片和四宫格文件
```

## 功能状态

| 功能 | 状态 |
|---|---|
| 矩阵键盘、数码管、LED、蜂鸣器 | 已通过 RTL 仿真和实机验证 |
| 密码输入、退格、取消、开锁及自动上锁 | 已通过 RTL 仿真和实机验证 |
| 连续四次错误报警、KEY2 专用解除 | 已通过 RTL 仿真和实机验证 |
| 管理员改密及 W25Q64 掉电保存 | 已通过 RTL 仿真和实机验证 |
| KEY3 易失性临时密码 | 已通过 RTL 仿真，待新版位流实机复测 |
| FPGA 与树莓派 UART 报警协议 | RTL 仿真已通过，待板间联调 |
| 树莓派 CSI 四帧抓拍与 HDMI 四宫格 | 软件单元测试及模拟抓拍已通过，待实物联调 |

实测边界见[实机验证报告](password_lock_system/实机验证报告.md)。未完成板间联调前，不把树莓派拍照路径描述为整机实测通过。

当前默认参数构建已成功生成位流：综合、实现和 DRC 均为 0 error，WNS 为 `11.046 ns`，WHS 为 `0.086 ns`，所有用户时序约束满足；删除四帧缓存后 Block RAM 使用量为 0。

## FPGA 快速使用

1. 按[矩阵键盘接线说明](password_lock_system/矩阵键盘接线说明.md)连接 4×4 键盘。
2. 可直接打开 [`password_lock_system.xpr`](password_lock_system/vivado/password_lock_system.xpr)，或运行构建脚本重新生成工程与位流。
3. 通过 Vivado Hardware Manager 下载 [`password_lock_top.bit`](password_lock_system/password_lock_top.bit)。
4. SW1 拨上进入工作状态，输入四位密码并按 `A`。Flash 无有效记录时默认密码为 `1234`。

常用操作：

| 输入 | 功能 |
|---|---|
| `0`～`9` | 输入密码 |
| `A` | 确认；开锁时立即上锁 |
| `B` | 退格 |
| `C` | 取消 |
| KEY1 | SW1 已拨上时进入管理员改密 |
| KEY2 | 解除报警并重置错误次数 |
| KEY3 | 在 `PASS`/`tEMP` 页面生成或替换临时密码 |
| KEY4 | 系统复位 |

当前实板操作方向已确认：SW1 拨上后可进入工作状态并使用 KEY1 进入 `SEt`；SW5 拨上后蜂鸣器通路接通。完整流程见[使用手册](password_lock_system/使用手册.md)。

## 树莓派连接与运行

推荐使用空闲的另一组 40 针 GPIO 扩展口做 115200-8-N-1 全双工 UART。该方案只占两根 3.3V 信号线，支持 ACK 和自动重发，不通过 FPGA 传输图像。

| 连接 | FPGA | Raspberry Pi 5 |
|---|---|---|
| FPGA TX -> Pi RX | GPIOA_0，扩展口脚 1，J16 | GPIO15/RXD0，物理脚 10 |
| Pi TX -> FPGA RX | GPIOA_1，扩展口脚 2，H13 | GPIO14/TXD0，物理脚 8 |
| 公共地 | 扩展口脚 12 或 30 | GND，物理脚 6 |

TX/RX 必须交叉并连接公共地。两块板各自供电，严禁互接 3.3V/5V 电源脚。树莓派安装、UART 配置、相机自检和运行方法见[树莓派项目说明](raspberry_pi5_camera/README.md)。

## 构建与测试

完整 FPGA 仿真、综合、实现和位流生成：

```powershell
.\password_lock_system\scripts\run_all.ps1
```

只运行 RTL 仿真：

```powershell
.\password_lock_system\scripts\run_all.ps1 -SkipImplementation
```

构建不含树莓派 UART 逻辑的纯密码锁版本：

```powershell
.\password_lock_system\scripts\run_all.ps1 -DisableRaspberryPiCamera
```

树莓派软件测试：

```bash
cd raspberry_pi5_camera
python3 -m unittest discover -s tests -v
./scripts/run.sh --mock-camera --trigger-on-start --windowed
```

FPGA 顶层参数 `ENABLE_RPI_CAMERA` 默认值为 1。关闭后 UART 模块会从综合结果移除，其余密码锁功能不变。

## 目录结构

```text
.
├─ password_lock_system/
│  ├─ rtl/                  # 密码锁、Flash、显示、报警与 UART RTL
│  ├─ sim/                  # SystemVerilog 测试平台和 Flash 模型
│  ├─ constraints/          # HX7A75A 专用管脚与时钟约束
│  ├─ scripts/              # 建工程、测试、构建与下载脚本
│  ├─ vivado/               # 可直接打开的 Vivado 工程
│  ├─ password_lock_top.bit # 可下载位流
│  ├─ 使用手册.md
│  ├─ 矩阵键盘接线说明.md
│  └─ 实机验证报告.md
├─ raspberry_pi5_camera/    # CSI 相机、四帧保存和 HDMI 四宫格程序
├─ 技术文档及例程/           # 开发板资料与原始参考工程
├─ 课件/                     # 课程资料
├─ 计划.txt                  # 当前树莓派相机方案实施计划
└─ 数字系统课程设计-题目新.docx
```

Vivado 缓存、运行目录、日志、树莓派抓拍结果和本地临时目录由 `.gitignore` 排除，不属于源码交付文件。

## 关键设计说明

- 第四次错误进入 `ALAr` 时，FPGA 发送 `ALARM\n`；未收到树莓派 `ACK\n` 时每 500 ms 重发。
- 拍照请求独立锁存，KEY2 可以解除声光报警，但不会取消已经触发的树莓派拍照。
- 树莓派连续抓拍四张 `640×480` 图像，保存四张 JPEG，并生成 `640×480` 的 2×2 四宫格持续显示。
- W25Q64 使用双日志记录和回读校验；两份记录均无效时回退默认密码 `1234`。
- KEY3 临时密码不写入 Flash，复位、重新配置或断电后失效。
- 当前实板 P20 蜂鸣器已确认是高电平使能，工程以实测极性为准。
