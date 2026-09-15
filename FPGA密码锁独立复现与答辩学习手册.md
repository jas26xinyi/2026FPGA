# FPGA 密码锁独立复现与答辩学习手册

> 目标：从空白 Vivado 工程开始，能够独立重建、仿真、综合、下载并联调本系统；能够面对老师的现场提问，解释某个功能由哪个文件、哪些信号和哪些状态实现，知道修改参数或逻辑后波形与实物会发生什么变化。

本手册以当前工作区源码为准，报告《FPGA密码锁课程设计报告.pdf》作为设计说明和结果依据。重点是报告附录中的 Listing 1（顶层连接）和 Listing 4（FPGA 报警 UART 链路），同时补足它们依赖的状态机、UART 字节层、键盘、数码管、蜂鸣器、W25Q64 SPI、树莓派 Python 程序和 11 组仿真。

关键入口：[Listing 1 顶层源码](password_lock_system/rtl/password_lock_top.v) · [Listing 4 UART 链路](password_lock_system/rtl/rpi_camera_link.v) · [核心状态机](password_lock_system/rtl/lock_controller.v) · [UART 仿真](password_lock_system/sim/tb_rpi_camera_link.sv) · [树莓派主程序](raspberry_pi5_camera/src/app.py) · [全部波形总览](simulation_waveforms/00_仿真波形总览.md)

---

## 0. 学完后的验收标准

完成本手册后，应能不看源码回答以下问题：

1. 为什么系统要分成顶层、控制器、键盘扫描、Flash、显示、蜂鸣器、临时密码和 UART 模块？
2. 第四次输错时，从按下 `A` 到树莓派显示四宫格，中间每个信号怎样变化？
3. `state=0~8` 各是什么状态，状态转移的优先级是什么？
4. 为什么 `capture_start` 只有一个时钟周期，而声光报警持续到 KEY2？
5. 为什么 `link_waiting` 在 KEY2 后仍可能保持为 1？
6. `115200-8-N-1` 每个字段是什么意思？一个字节在线上怎样发送？
7. `ALARM\n`、`ACK\n`、`DONE\n`、`ERR\n` 哪些被 FPGA 实际解析？
8. W25Q64 与 FPGA 使用什么协议？为什么要两个扇区和回读校验？
9. 测试平台为什么在时钟下降沿改变输入？为什么仿真中的 1000 个周期能代表实机 8 秒？
10. 老师要求把输入超时改为 5 秒、UART 改为 57600、报警改为第 3 次触发或蜂鸣器改为 1 kHz时，应修改哪里并同步修改哪些测试？

建议学习顺序：先掌握第 1~7 章的系统与 FPGA 主线，再学习第 8~11 章的 Flash、UART、树莓派和仿真，最后用第 12~15 章做修改练习与口试。

---

## 1. 系统边界与总体数据流

### 1.1 整体结构

```text
                    HX7A75A / XC7A75T FPGA

KEY4 ──> reset_sync ───────────────────────────────┐
SW1/KEY1/KEY2/KEY3 ──> debounce_event ────────────┤
4x4 键盘 ──> keypad_scanner ── key_valid/code ──┐ │
                                                 v v
W25Q64 <──SPI── w25q64_password_store <──> lock_controller
                                                 │
                    ┌────────────────────────────┼─────────────────────┐
                    v                            v                     v
             sevenseg_display             alarm_buzzer          capture_start
              数码管/LED                   LED/蜂鸣器                  │
                                                                        v
                                                                rpi_camera_link
                                                                        │
                                                          3.3 V UART: ALARM/ACK
                                                                        │
                                                                        v
                                                               Raspberry Pi 5
                                                   CSI 相机 -> 四张 JPEG -> 四宫格
                                                                        │
                                                                        v
                                                                    HDMI 显示器
```

最关键的边界：FPGA 与树莓派之间不传输图像。FPGA 只发送一个低带宽报警事件；摄像头初始化、图像采集、JPEG 保存、四宫格合成和 HDMI 显示都由树莓派完成。

### 1.2 三种通信不要混淆

| 通信对象 | 协议/方式 | 主控 | 传输内容 |
|---|---|---|---|
| FPGA - W25Q64 用户 Flash | SPI mode 0 | FPGA | 固定密码记录、状态寄存器、JEDEC ID |
| FPGA - Raspberry Pi 5 | 3.3 V TTL UART，115200-8-N-1 | 双向异步 | `ALARM\n` 和 `ACK\n` 等短文本 |
| Raspberry Pi - CSI 摄像头/HDMI | 树莓派相机与显示接口 | Raspberry Pi | 像素和显示画面，不经过 FPGA |

### 1.3 一次报警的完整事件链

```text
用户输入第 4 个错误密码并按 A
    -> lock_controller 由 USER 转入 ALARM
    -> error_count 置 4
    -> capture_start 拉高 1 个 sys_clk 周期（20 ns）
    -> 顶层把 capture_start 接到 rpi_camera_link.photo_trigger
    -> UART 模块把请求锁存，link_waiting=1
    -> FPGA 发送 ASCII: ALARM\n
    -> Pi 的 uart.readline() 读到一整行
    -> Pi 立即发送 ACK\n
    -> FPGA ACK 状态机识别 A-C-K-LF，link_waiting=0，停止重发
    -> Pi 初始化/复用 CSI 摄像头，连续拍 4 张图
    -> 先写 .partial 临时目录，再合成 mosaic.jpg
    -> 全部成功后把目录原子改名，并在 HDMI 显示四宫格
    -> Pi 发送 DONE\n；失败则显示错误页并发送 ERR\n
```

注意：当前 FPGA 只识别 `ACK\n`，不处理 `DONE\n` 和 `ERR\n`。后两者在当前版本只是树莓派发出的状态消息，不会改变 FPGA 的 LED、蜂鸣器或状态机。

---

## 2. 工程文件地图：每个文件负责什么

### 2.1 FPGA RTL

| 文件 | 职责 | 修改它会影响什么 |
|---|---|---|
| `rtl/password_lock_top.v` | Listing 1；顶层端口、子模块实例化和信号连接 | 整个系统的模块组合、LED 映射、功能开关 |
| `rtl/reset_sync.v` | KEY4 异步复位、三级同步释放 | 上电和按键复位可靠性 |
| `rtl/debounce_event.v` | 板载按键/开关双触发同步、20 ms 消抖、单周期事件 | SW1、KEY1~KEY3 的响应与抖动 |
| `rtl/tick_enable.v` | 把 50 MHz 分频成周期性单周期 `tick` | 键盘扫描速度 |
| `rtl/keypad_scanner.v` | 4 列轮询、16 键编码、消抖、长按单事件、多键屏蔽 | 矩阵键盘全部输入 |
| `rtl/lock_controller.v` | 九状态密码锁 FSM、输入缓存、计时、错误计数、保存/拍照请求 | 密码锁核心行为 |
| `rtl/sevenseg_display.v` | 状态文字、数字显示、8 位动态扫描 | 数码管字形和刷新 |
| `rtl/alarm_buzzer.v` | 2 Hz 间歇节拍和 2 kHz 音调载波 | 报警 LED 与蜂鸣器 |
| `rtl/temporary_password_generator.v` | LFSR 伪随机临时密码、BCD 过滤、排除冲突 | KEY3 临时密码 |
| `rtl/spi_byte_master.v` | SPI mode 0 单字节收发 | W25Q64 的位级时序 |
| `rtl/w25q64_password_store.v` | 双扇区日志、CRC16、擦写、回读校验、默认密码 | 固定密码掉电保存 |
| `rtl/uart_tx_byte.v` | 一个 UART 字节的起始位、8 数据位和停止位发送 | FPGA TX 波形 |
| `rtl/uart_rx_byte.v` | UART RX 同步、中点采样和字节有效脉冲 | FPGA 接收 ACK |
| `rtl/rpi_camera_link.v` | Listing 4；`ALARM\n` 消息、ACK 匹配、500 ms 重发 | FPGA - Pi 应用层协议 |

### 2.2 仿真文件

| 文件 | 对应编号 | 验证对象 |
|---|---:|---|
| `sim/tb_basic_entry_timeout.sv` | 01 | 输入、退格、四位限制、开锁、8/16 秒超时 |
| `sim/tb_basic_admin_save.sv` | 02 | KEY1 改密、保存成功/失败、FErr、管理员超时 |
| `sim/tb_basic_alarm_policy.sv` | 03 | Err1~Err3、第 4 次报警、KEY2、单次拍照脉冲 |
| `sim/tb_keypad_scanner.sv` | 04 | 16 键、列扫描、消抖、长按、多键屏蔽 |
| `sim/tb_sevenseg_display.sv` | 05 | 所有状态文字、数字、低有效位选 |
| `sim/tb_alarm_buzzer.sv` | 06 | 报警载波、间歇节拍和立即静音 |
| `sim/tb_flash_default_fail.sv` | 07 | 空 Flash 默认 1234、写失败不污染旧密码 |
| `sim/tb_flash_journal.sv` | 08 | 双扇区、版本选择、损坏恢复、CS 间隔 |
| `sim/w25q64_model.sv` | 08 的外设模型 | 在仿真中模拟 W25Q64 命令和存储阵列 |
| `sim/tb_temporary_password_generator.sv` | 09 | 临时密码 BCD、避开冲突、替换、复位失效 |
| `sim/tb_rpi_camera_link.sv` | 10 | UART 请求、ACK 清除、重发路径 |
| `sim/tb_lock_controller.sv` | 11 | 固定/临时密码、改密和报警的控制器集成回归 |

### 2.3 约束、脚本和报告

| 文件/目录 | 作用 |
|---|---|
| `constraints/password_lock_system.xdc` | 50 MHz 时钟、管脚编号、LVCMOS33、输入上拉 |
| `scripts/create_project.tcl` | 从源码重新创建 `.xpr` 工程 |
| `scripts/run_tests.tcl` | 选择一个 testbench，行为仿真并检查 `test_pass` |
| `scripts/run_all.ps1` | 依次跑 11 组仿真，可继续综合/实现/位流 |
| `scripts/build_all.tcl` | 综合、实现、报告、复制最终 `.bit` |
| `scripts/generate_waveforms.ps1` | 生成 11 组 WDB/WCFG/VCD/LOG/result |
| `scripts/run_waveform.tcl` | 记录信号、运行仿真、导出波形数据库 |
| `scripts/open_waveform_gui.tcl` | 打开已有 WDB/WCFG |
| `scripts/program_fpga.tcl` | 通过 JTAG 下载 `password_lock_top.bit` |
| `scripts/program_boot_flash.tcl` | 烧写板载配置 Flash，使 FPGA 上电自动加载位流 |
| `reports/` | 时序、利用率、DRC、CDC 等实现报告 |
| `simulation_waveforms/` | 11 组原生波形、截图、日志和逐项说明 |

### 2.4 Raspberry Pi 文件

| 文件 | 作用 |
|---|---|
| `raspberry_pi5_camera/src/app.py` | 主程序：配置、串口循环、ACK、拍摄、保存、显示、DONE/ERR |
| `src/fpga_camera/protocol.py` | 定义协议常量和 `ALARM` 解码规则 |
| `src/fpga_camera/camera.py` | Picamera2 真相机和 MockCamera |
| `src/fpga_camera/mosaic.py` | 四宫格、测试色条、错误画面 |
| `src/fpga_camera/display.py` | OpenCV HDMI 全屏窗口和无头显示替身 |
| `config.example.json` | 串口、分辨率、帧数、间隔、超时、目录配置 |
| `scripts/install.sh` | apt 安装 Picamera2、serial、PIL、OpenCV并配置用户组 |
| `scripts/run.sh` | 切换到项目根目录并运行 `src/app.py` |
| `scripts/run_gui.sh` | 为桌面会话设置显示环境后运行程序 |
| `scripts/install_autostart.sh` | 安装桌面登录自动启动项 |
| `tests/` | 协议解析、四宫格顺序和启动画面恢复单元测试 |

---

## 3. 从空白开始建立 Vivado 系统

### 3.1 环境与器件

- Vivado：2023.2。
- FPGA：Xilinx Artix-7，`xc7a75tfgg484-2`。
- 顶层模块：`password_lock_top`。
- 顶层 RTL 使用 Verilog；测试平台使用 SystemVerilog。
- 时钟：`Y18`，50 MHz，周期 20 ns。

当前机器的 `D:\Xilinx\Vivado\2023.2\bin\vivado.bat` 已验证为 Vivado 2023.2。

### 3.2 路线 A：完全用 Vivado GUI 新建

1. 启动 Vivado 2023.2，选择 **Create Project**。
2. Project name 填 `password_lock_system`，选择一个新目录。
3. 选择 **RTL Project**，可勾选暂不添加文件，也可直接添加。
4. Add Sources：加入 `password_lock_system/rtl/` 下全部 `.v`。
5. Add Constraints：只加入 `constraints/password_lock_system.xdc`。不要再叠加通用板卡 XDC，否则可能出现同一端口多重约束。
6. Add Simulation Sources：加入 `password_lock_system/sim/` 下全部 `.sv`，将文件类型设为 SystemVerilog。
7. Parts 中选择 `xc7a75tfgg484-2`。
8. 在 Sources -> Design Sources 中右键 `password_lock_top`，选择 **Set as Top**。
9. Simulation Sources 中，根据要运行的场景把某个 `tb_*` 设为仿真顶层。
10. Flow Navigator -> Run Simulation -> Run Behavioral Simulation。
11. 仿真通过后依次 Run Synthesis、Run Implementation、Generate Bitstream。
12. Open Hardware Manager -> Open Target -> Auto Connect，选择 FPGA，Program Device，加载 `password_lock_top.bit`。

### 3.3 路线 B：用现有脚本自动重建（推荐复现）

在 PowerShell 中：

```powershell
Set-Location E:\26FPGA\password_lock_system
.\scripts\run_all.ps1
```

`run_all.ps1` 的真实执行顺序：

1. 把 `$ErrorActionPreference` 设为 `Stop`，任何错误立即停止。
2. 检查固定 Vivado 路径是否存在。
3. 设置环境变量 `ENABLE_RPI_CAMERA` 为 1；使用开关参数时设为 0。
4. 依次为 11 个 testbench 启动独立 Vivado batch 进程并运行 `run_tests.tcl`。
5. 每个 testbench 都必须令 `test_pass=1`，否则脚本报错。
6. 未指定 `-SkipImplementation` 时调用 `build_all.tcl`。
7. `build_all.tcl` 重建工程、综合、实现到 write_bitstream、生成报告并复制 `.bit`。
8. `finally` 恢复之前的环境变量并退出目录。

常用命令：

```powershell
# 只做 11 组行为仿真
.\scripts\run_all.ps1 -SkipImplementation

# 综合时完全移除 Raspberry Pi UART 链路
.\scripts\run_all.ps1 -DisableRaspberryPiCamera

# 重新生成 11 组原生波形包
.\scripts\generate_waveforms.ps1

# 只生成 03 和 10 两组波形
.\scripts\generate_waveforms.ps1 -CaseIds 03,10
```

### 3.4 `create_project.tcl` 逐句逻辑

| 行为 | 含义 |
|---|---|
| 由脚本位置向上一级计算 `project_root` | 工程移动到别的目录后仍可复现，不依赖当前工作目录 |
| 默认 `project_dir=vivado` | 正式 `.xpr` 放在 `password_lock_system/vivado` |
| 检查 `VIVADO_PROJECT_DIR` | 波形脚本可为每个 testbench 建独立临时工程，避免污染正式工程 |
| `create_project -force ... -part xc7a75tfgg484-2` | 创建/覆盖工程并指定器件 |
| `target_language Verilog` | 综合源默认 Verilog |
| `simulator_language Mixed` | 允许 Verilog RTL + SystemVerilog testbench |
| 检查 `ENABLE_RPI_CAMERA` 只能为 0/1 | 防止无效综合参数 |
| `add_files rtl/*.v` | 添加设计源 |
| `add_files -fileset constrs_1 ...xdc` | 添加约束 |
| `add_files -fileset sim_1 sim/*.sv` | 添加仿真源 |
| `set_property top password_lock_top` | 设置综合顶层 |
| `set_property generic ...` | 把环境变量值传入顶层参数 |
| `update_compile_order` | 让 Vivado分析模块依赖并更新编译顺序 |
| `close_project` | 保存并关闭工程 |

### 3.5 综合、实现和下载分别做什么

- **Elaboration/RTL Analysis**：检查模块端口、参数、位宽和可综合语法，查看 RTL 原理图。
- **Synthesis**：把 Verilog 转换为 LUT、触发器、IO、时钟资源等网表。
- **Implementation**：进行优化、布局和布线，得到真实路径延迟。
- **Timing Analysis**：验证 20 ns 周期内建立时间、保持时间等是否满足。
- **DRC**：检查管脚、电压、时钟、布线等设计规则。
- **Generate Bitstream**：生成可通过 JTAG 配置 FPGA 的 `.bit`。
- **Program Device**：把 `.bit` 下载到 FPGA SRAM，断电后丢失。
- **Program Boot Flash**：把 MCS 烧入配置 Flash，使 FPGA 上电自动配置。它和保存用户密码的 W25Q64不是同一用途的存储器。

当前保存报告显示：WNS `11.318 ns`、WHS `0.060 ns`、时序违例 0、DRC 违例 0；LUT 1430（3.03%）、寄存器 1063（1.13%）、Block RAM 0。

---

## 4. 阅读代码必须掌握的 Verilog/SystemVerilog 语法

| 语法 | 含义 | 本工程例子 |
|---|---|---|
| `` `timescale 1ns/1ps `` | 仿真时间单位/精度，不是硬件频率 | 所有 RTL/testbench 第 1 行 |
| `module ... endmodule` | 定义硬件模块 | `password_lock_top` |
| `parameter` | 实例化时可覆盖的常量 | `CLOCK_HZ`、`BAUD` |
| `localparam` | 模块内部常量，不作为外部配置接口 | 状态编号、计数周期 |
| `input/output/inout` | 模块端口方向 | 顶层外设端口 |
| `wire` | 由连续赋值或子模块输出驱动的网络 | `photo_trigger` |
| `reg` | 可在 `always` 中赋值的变量；不等同于一定有寄存器 | `state`、组合逻辑临时量 |
| `[15:0]` | 16 位向量，最高位 15，最低位 0 | 四位 BCD 密码 |
| `4'hA` | 4 位十六进制 A | 键盘确认键 |
| `16'h1234` | 16 位十六进制数；本设计把每个半字节当一位十进制 | 默认密码 |
| `assign x = ...` | 连续组合赋值 | LED、UART 禁用路径 |
| `always @(*)` | 组合逻辑，任一依赖信号变化就重算 | 下一状态、字符组合 |
| `always @(posedge clk)` | 上升沿触发的同步时序逻辑 | 状态和计数器 |
| `always @(posedge clk or posedge arst)` | 含异步置位的时序逻辑 | `reset_sync` |
| `=` | 阻塞赋值，语句按顺序立即生效；常用于组合逻辑/testbench | `next_state = state` |
| `<=` | 非阻塞赋值，在当前时钟事件结束时统一更新；用于寄存器 | `state <= next_state` |
| `{a,b}` | 位拼接 | `{entry_digits[11:0],key_code}` |
| `{TW{1'b0}}` | 重复拼接 TW 个 0 | 按参数位宽清零计数器 |
| `x[15:12]` | 位切片 | 密码千位 BCD |
| `?:` | 三目条件运算 | `ACTIVE_LOW ? ~sync1 : sync1` |
| `&&/||/!` | 逻辑与/或/非 | 状态转移条件 |
| `&/|/^/~` | 按位与/或/异或/取反 | CRC、LFSR、密码反码 |
| `==` | 普通相等；X/Z 可能产生未知 | RTL 比较 |
| `===/!==` | 四态严格比较 | testbench 检查 X/Z |
| `function` | 纯计算式复用，有返回值、不可等待时钟 | 键值/段码/CRC映射 |
| `task` | 可含多个语句和时序等待，无函数式返回值 | testbench 输入一个按键 |
| `$clog2(n)` | 容纳 0~n-1 所需位数的上取整对数 | 自动计算计数器位宽 |
| `generate if` | 综合展开阶段选择是否生成硬件 | 是否实例化 Pi UART |
| `initial` | testbench 的一次性激励；本工程不用于可综合 RTL | 各测试场景 |
| `#5` | 仿真延迟 5 个 timescale 单位 | 产生仿真时钟 |
| `@(negedge clk)` | 等待时钟下降沿 | testbench 在采样沿之前准备输入 |
| `repeat/for` | 重复执行 | 超时等待、遍历 16 键 |
| `$fatal/$display/$finish` | 仿真失败、打印、结束 | 自动 PASS/FAIL |

---

## 5. Listing 1：`password_lock_top.v` 逐句理解

### 5.1 第 1 行：仿真尺度

```verilog
`timescale 1ns/1ps
```

表示仿真中的 `#1` 是 1 ns，时间分辨率是 1 ps。板上 50 MHz 由 XDC 的 `create_clock -period 20.000` 决定。

### 5.2 第 3~8 行：模块与可选 UART 参数

```verilog
module password_lock_top #(
    parameter integer ENABLE_RPI_CAMERA = 1
) (
```

`ENABLE_RPI_CAMERA` 是综合期参数，不是板上可拨动的开关。为 1 时生成 `rpi_camera_link`；为 0 时根本不综合这部分逻辑。

### 5.3 第 9~25 行：每个顶层端口

| 端口 | 方向/位宽 | 物理对象与含义 |
|---|---|---|
| `sys_clk` | 输入 1 位 | Y18 板载 50 MHz 时钟 |
| `key_n[3:0]` | 输入 4 位，低有效 | KEY1 管理员、KEY2 解除、KEY3 临时密码、KEY4 复位 |
| `sw[3:0]` | 输入 4 位 | 只使用 `sw[0]` 的上升沿启动普通输入 |
| `keypad_row_n[3:0]` | 输入 4 位，低有效 | 当前被选列上的四行电平 |
| `keypad_col_n[3:0]` | 输出 4 位，低有效 | 逐列输出 1110、1101、1011、0111 |
| `seg_n[7:0]` | 输出 8 位，低有效 | a~g 段和小数点段 |
| `seg_sel[7:0]` | 输出 8 位，低有效 | 8 位数码管位选 |
| `led[3:0]` | 输出 4 位 | 等待、输入、开锁、报警/Flash 故障 |
| `buzzer_n` | 输出 1 位 | 名称沿用旧接口，当前实板实际为高电平使能 |
| `flash_cs_n` | 输出 | W25Q64 片选，低有效 |
| `flash_sclk` | 输出 | SPI 时钟 |
| `flash_mosi` | 输出 | 主机 FPGA 发给 Flash |
| `flash_miso` | 输入 | Flash 发给 FPGA |
| `flash_wp_n/hold_n` | 输出 | 始终置 1，使写保护/HOLD 无效 |
| `rpi_uart_tx` | 输出 | FPGA TX，接 Pi RXD0 |
| `rpi_uart_rx` | 输入 | FPGA RX，接 Pi TXD0 |

### 5.4 第 27~38 行：内部网络

| 信号 | 来源 -> 去向 | 含义 |
|---|---|---|
| `sys_rst` | reset_sync -> 所有模块 | 同步系统复位 |
| `sw1_event` | SW1 消抖 -> controller | 启动普通输入的单周期事件 |
| `admin_event` | KEY1 消抖 -> controller | 进入管理员设置 |
| `alarm_clear_event` | KEY2 消抖 -> controller/keypad | 解除报警并清键盘扫描状态 |
| `temporary_key_event` | KEY3 消抖 -> 顶层门控 | KEY3 原始事件 |
| `temporary_generate_event` | 顶层状态门控 -> generator/controller | 允许的临时密码生成事件 |
| `keypad_event/code` | keypad -> controller | 稳定按键事件和 4 位编码 |
| `flash_init_done` | Flash -> controller | 密码载入完成，可以离开 BOOT |
| `save_request/password` | controller -> Flash | 请求保存新固定密码 |
| `save_done/success` | Flash -> controller | 保存完成及是否成功 |
| `stored_password` | Flash -> controller/generator | 当前固定密码 |
| `entry_digits/count` | controller -> display | 当前输入内容和位数 |
| `temporary_password/valid` | generator -> controller/display | 当前临时密码及有效标志 |
| `photo_trigger` | controller -> rpi link | 第四次错误产生的单周期拍照脉冲 |
| `unlocked/alarm_active/state` | controller -> 显示/报警/LED | 核心状态输出 |
| `display_fault` | controller -> display | 显示 FErr |
| `rpi_link_waiting` | rpi link 输出 | 等待 ACK；目前只在顶层接线，未驱动 LED |

### 5.5 第 40 行：KEY4 复位

```verilog
reset_sync u_sys_reset(.clk(sys_clk),.arst(~key_n[3]),.rst(sys_rst));
```

- KEY4 未按下：`key_n[3]=1`，取反后 `arst=0`。
- KEY4 按下：`key_n[3]=0`，`arst=1`，立即把三级同步寄存器置 111。
- 松开后每个上升沿移入 0：111 -> 110 -> 100 -> 000，`sys_rst` 经过三级同步后释放。
- 这样“按下立即复位，松开整齐退出复位”。

### 5.6 第 42~47 行：板载输入和矩阵键盘

```verilog
debounce_event #(.ACTIVE_LOW(0)) u_sw1(...);
```

SW1 拨上是逻辑 1，所以设 `ACTIVE_LOW=0`。板载 KEY 默认低有效，使用模块默认 `ACTIVE_LOW=1`。`.level()` 表示该输出端口不使用；`.rise_event(...)` 接收消抖后的按下事件。

```verilog
.rst(sys_rst | alarm_clear_event)
```

KEY2 除了让控制器退出报警，还复位键盘扫描器，清除长按或多键锁定残留。`|` 是按位或，这里两个操作数都是 1 位。

### 5.7 第 49~54 行：固定密码存储实例

这六行只是端口接线，不在顶层实现 SPI 算法。顶层把控制器的保存请求送入 W25Q64 模块，把存储模块返回的固定密码、完成和故障信号送回控制器。

### 5.8 第 56~63 行：KEY3 门控与临时密码

```verilog
assign temporary_generate_event = temporary_key_event &&
    (lock_state == 4'd1 || lock_state == 4'd8);
```

只有 WAIT(1) 或 TEMP(8) 状态接受 KEY3。输入、保存、错误和报警期间按 KEY3 不会改变临时密码。

同一个 `temporary_generate_event` 同时送给发生器和控制器：在同一上升沿，发生器更新密码，控制器进入/保持 TEMP；时钟沿结束后显示模块立即看到新密码。

### 5.9 第 65~75 行：控制器实例

这是系统功能的中心：

- 左侧输入：Flash 初始化/固定密码/故障、四种操作事件、临时密码、键盘、保存结果。
- 右侧输出：保存请求、拍照请求、开锁/报警状态、输入缓存、计数和显示故障。
- `.capture_start(photo_trigger)` 证明 Listing 1 将控制器的拍照事件重命名/接线为 UART 模块所用的 `photo_trigger`。

### 5.10 第 77~86 行：显示、LED、蜂鸣器

- 数码管模块收到状态、输入、错误次数、临时密码和故障标志。
- `led[0]` 只在 WAIT 亮。
- `led[1]` 在 USER 或 ADMIN 亮。
- `led[2]` 等于 `unlocked`。
- 报警时 `led[3]` 显示间歇节拍；非报警时显示 `flash_fault`。
- 三目运算 `condition ? a : b` 表示根据条件选择输出。

### 5.11 第 88~98 行：综合期生成分支

```verilog
generate
    if (ENABLE_RPI_CAMERA != 0) begin : g_rpi_camera
        rpi_camera_link ...
    end else begin : g_no_rpi_camera
        assign rpi_uart_tx = 1'b1;
        assign rpi_link_waiting = 1'b0;
    end
endgenerate
```

这是 elaboration/generate 条件，不是 FPGA 运行时状态机。禁用时：TX 固定在 UART 空闲高电平，等待标志为 0，UART 寄存器/LUT 不进入网表。

---

## 6. `lock_controller.v`：系统状态怎样转移

### 6.1 状态表

| 值 | 符号 | 显示 | 进入条件 | 离开条件 |
|---:|---|---|---|---|
| 0 | `ST_BOOT` | INIT | 复位后 | `flash_init_done=1` -> WAIT |
| 1 | `ST_WAIT` | PASS | 初始化完成、取消、上锁、保存完成 | KEY3 -> TEMP；KEY1 -> ADMIN；SW1 -> USER |
| 2 | `ST_USER` | PASS+输入 | SW1 或 KEY2 解除报警 | C/超时 -> WAIT；正确+A -> OPEN；错误+A -> ERROR/ALARM |
| 3 | `ST_ERROR` | ErrN | 前 3 次错误 | 错误显示计时结束 -> USER |
| 4 | `ST_OPEN` | OPEN | 固定或临时密码正确 | A/16秒 -> WAIT；KEY1 -> ADMIN |
| 5 | `ST_ADMIN` | SEt | KEY1 | C/8秒 -> WAIT；四位+A -> SAVE |
| 6 | `ST_SAVE` | SAVE | 管理员提交新密码 | `save_done` -> WAIT |
| 7 | `ST_ALARM` | ALAr | 第 4 次错误 | 只有 KEY2 -> USER |
| 8 | `ST_TEMP` | tEMP+四位密码 | KEY3 | 再按 KEY3 替换；SW1 -> USER；A/C/8秒 -> WAIT |

### 6.2 状态转移优先级

代码中的 `if ... else if ...` 顺序就是优先级：

- WAIT：KEY3 > KEY1 > SW1。
- USER：C 取消 > 无活动超时 > 四位+A 比较。由于按 A 时 `activity=1`，超时条件中的 `!activity` 为假，所以边界上按 A 不会被超时抢走。
- OPEN：A/开锁超时 > KEY1。
- ADMIN：C > 无活动超时 > 四位+A 保存。
- TEMP：新的 KEY3 > SW1 > A/C > 超时。因此 KEY3 与 SW1 同时发生时，替换临时密码优先。
- ALARM：只响应 KEY2。

### 6.3 组合下一状态与时序寄存器

```verilog
always @(*) begin
    next_state = state;
    case (state)
        ...
    endcase
end
```

负责决定“下一拍去哪”。先默认保持原状态可防止组合锁存。

```verilog
always @(posedge clk) begin
    state <= next_state;
    ...
end
```

负责在时钟沿真正更新状态、计数和单周期输出。

### 6.4 输入数字与退格

```verilog
entry_digits <= {entry_digits[11:0], key_code};
```

每个数字占 4 位 BCD，整体左移一位十进制数并在最低半字节追加新键。例如 0012 输入 3 后变为 0123。

```verilog
entry_digits <= {4'h0, entry_digits[15:4]};
```

退格时右移一个半字节，例如 1234 -> 0123。`entry_count` 同步加减，最多为 4。

### 6.5 第四次错误与拍照脉冲

当当前 `error_count=3` 且四位密码错误时，组合逻辑选择 `ST_ALARM`。上升沿：

```verilog
if (next_state == ST_ALARM) begin
    error_count   <= 3'd4;
    capture_start <= 1'b1;
end
```

同时每个非复位周期开头都有：

```verilog
capture_start <= 1'b0;
```

所以只有进入 ALARM 的那个周期被后面的赋值覆盖为 1，下一周期恢复 0。这是“默认清零 + 条件置位”的单周期事件写法。

### 6.6 保存握手

进入 SAVE 的时钟沿：

```verilog
save_password <= entry_digits;
save_request  <= 1'b1;
```

下一周期默认把 `save_request` 清零，但 Flash 已经锁存请求。控制器停留在 SAVE，直到 `save_done=1`。离开 SAVE 时用 `~save_success` 更新 `display_fault`。

### 6.7 输出为何是 Moore 型

```verilog
unlocked     = (state == ST_OPEN);
alarm_active = (state == ST_ALARM);
```

输出只由当前注册状态决定。状态寄存器在上升沿更新后，组合输出随即变化；不会直接被异步按键毛刺驱动。

---

## 7. FPGA 板载输入、键盘、数码管和蜂鸣器

### 7.1 `reset_sync.v`

- `(* ASYNC_REG="TRUE" *)` 告诉 Vivado 这些触发器是异步信号同步链，布局时应尽量靠近。
- `always @(posedge clk or posedge arst)`：异步复位可不等时钟立即置位。
- `sync_ff <= {sync_ff[1:0],1'b0}`：松开后连续移入 0。
- `rst=sync_ff[2]`：经过三级后才解除系统复位。

### 7.2 `debounce_event.v`

默认参数：50 MHz、20 ms、低有效。`COUNT_MAX=1,000,000`，即输入必须与当前稳定状态不同并保持约一百万拍才被接受。

两级 `sync0/sync1` 降低异步输入亚稳态传播风险。`active_sample` 把低有效按键统一变换为“按下=1”。当新采样和当前 `level` 不同，`stable_count` 累加；保持到边界才更新 `level`。只有稳定状态变成按下时才产生一个周期的 `rise_event`，松开不会产生该事件。

### 7.3 `tick_enable.v`

`DIVISOR=CLOCK_HZ/TICK_HZ`。50 MHz 到 1 kHz 时每 50,000 拍产生一个周期的 `tick=1`，不是生成新的时钟。使用 clock enable 比在逻辑中制造大量派生时钟更容易做时序约束。

### 7.4 `keypad_scanner.v`

1. `column_index=0~3` 依次令 `col_n` 为 `1110/1101/1011/0111`。
2. 某列被拉低时，按下的键会让对应 `row_n` 读到 0。
3. 每列采样 4 行，四列组成 16 位 `complete_sample`。
4. 连续 `DEBOUNCE_SCANS=5` 次完整扫描一致才稳定。1 ms/列，完整扫描 4 ms，约 20 ms 消抖。
5. 对 16 位样本逐位相加得到 `key_count`。
6. `key_count=0`：全部释放，重新 `armed=1`。
7. `key_count>1`：多键屏蔽，必须全部释放后才重新允许事件。
8. `key_count=1 && armed`：只产生一个周期 `event_valid`，随后 `armed=0`，所以长按只报一次。

键值布局：

```text
1  2  3  A
4  5  6  B
7  8  9  C
E  0  F  D
```

E/F 对应键盘上的 `*`/`#`。控制器只使用 0~9、A、B、C；D/E/F 当前保留。

### 7.5 `sevenseg_display.v`

- `chars[0:7]` 是 8 个逻辑字符，不直接是段码。
- `encode()` 把数字或字母转换为低有效 `seg_n`。
- `display_fault` 优先级最高，强制显示 FErr。
- TEMP 状态左四位显示 tEMP，右四位显示临时密码。
- 非 TEMP 状态，右侧根据 `entry_count` 显示已经输入的数字。
- `scan` 以总计 8 kHz 步进，每一位约 1 kHz 刷新。
- `digit_sel=~(1<<scan)` 保证每个时隙只有一位为低而点亮；`seg_n` 给出该位段码。人眼视觉暂留把快速轮询看成八位同时亮。

### 7.6 `alarm_buzzer.v`

- `BEEP_HZ=2`：`beep_on` 每半周期翻转，形成有声/静音间歇节拍。
- `TONE_HZ=2000`：有声阶段 `tone_phase` 以 2 kHz 方波翻转。
- `indicator=alarm_active && beep_on`，LED 只跟慢节拍。
- `buzzer_n=(alarm_active && beep_on)?tone_phase:0`，蜂鸣器在有声窗口输出音调。
- 当前板实测 P20 高电平使能，变量名 `buzzer_n` 只是旧接口遗留，不能根据名字误判低有效。

---

## 8. FPGA 与 W25Q64：器件和主控怎样通信

### 8.1 SPI mode 0 的物理含义

W25Q64 使用四根主要 SPI 信号：

| 信号 | 方向 | 含义 |
|---|---|---|
| `flash_cs_n` | FPGA -> Flash | 低有效片选；低电平期间是一条连续命令 |
| `flash_sclk` | FPGA -> Flash | 串行时钟，mode 0 空闲为 0 |
| `flash_mosi` | FPGA -> Flash | FPGA 发送命令、地址和数据 |
| `flash_miso` | Flash -> FPGA | Flash 返回 ID、状态和数据 |

此外 `flash_wp_n` 和 `flash_hold_n` 始终置 1，表示不启用硬件写保护和暂停。

SPI mode 0 表示 CPOL=0、CPHA=0：时钟空闲低；FPGA 在下降沿准备/改变 MOSI，在上升沿采样 MISO。`spi_byte_master` 的 `HALF_DIV=2`，50 MHz 时每两个系统时钟翻转一次 SCLK，因此完整 SCLK 为 `50 MHz/(2*2)=12.5 MHz`。

### 8.2 `spi_byte_master.v` 的一个字节

1. 空闲时 `sclk=0`、`busy=0`、`done=0`。
2. `start=1` 时锁存 `tx_data`，立即把最高位放到 MOSI，进入忙状态。
3. 每到半周期边界：
   - 当前 SCLK=0：拉高 SCLK并把 MISO 移入 `rx_shift`。
   - 当前 SCLK=1：拉低 SCLK并准备下一个 MOSI 位。
4. 完成 8 个上升沿采样后，返回 `rx_data`，`done` 拉高一个周期。

这里 SPI 按 MSB first 发送，与 UART 的 LSB first 不同。

### 8.3 W25Q64 记录格式

每条记录 16 字节/128 位：

| 位/字节 | 内容 | 作用 |
|---|---|---|
| 4 字节 | `MAGIC=0x504C4B31` | 判断是否是本系统记录 |
| 4 字节 | `generation` | 版本号，选择较新的记录 |
| 2 字节 | BCD 密码 | 例如 `16'h2580` |
| 2 字节 | 密码逐位取反 | 检测数据是否一致 |
| 2 字节 | CRC16 | 检查前 12 字节的完整性 |
| 2 字节 | `COMMIT=0xA55A` | 记录已完整提交的标志 |

使用两个 4 KB 扇区：A 地址 `0x000000`，B 地址 `0x001000`。每次保存写入当前有效扇区的另一边，所以写失败时旧记录仍在。

### 8.4 上电读取状态机

```text
S_ID：发送 9F，读取 JEDEC ID
 -> S_READ_A：03 + 地址，读取扇区 A 的 16 字节记录
 -> S_READ_B：读取扇区 B
 -> S_SELECT：验证 MAGIC/BCD/反码/CRC/COMMIT
      两份有效：选 generation 更大者
      仅一份有效：选那一份
      都无效：current_password=1234
 -> init_done=1
 -> S_IDLE
```

`record_valid()` 同时检查五个条件；只要其中一个不满足，整条记录无效。`flash_fault` 还会根据 JEDEC ID 是否为全 0/全 1 指示器件通信异常，但空白记录本身会回退默认密码。

### 8.5 保存状态机

```text
S_IDLE 收到 save_request
 -> 锁存 save_password
 -> target_bank = 非当前扇区
 -> generation + 1，计算反码、CRC、COMMIT
 -> 06 写使能
 -> 20 + 地址，擦除目标 4 KB 扇区
 -> 05 轮询状态寄存器 WIP 位，等待擦除完成
 -> 再发 06 写使能
 -> 02 + 地址 + 16 字节记录，页编程
 -> 05 轮询编程完成
 -> 03 读回目标记录
 -> 对比 verify_record 与 new_record
 -> 成功才更新 current_password 和 active_bank
 -> save_done=1，save_success 给出结果
```

因此管理员按 A 后并不是立刻修改当前密码。只有擦除、写入和回读校验全部通过，`current_password` 才更新。失败时旧扇区和旧密码不变。

### 8.6 重要命令字

| SPI 命令 | 十六进制 | 作用 |
|---|---:|---|
| Read JEDEC ID | `9F` | 识别芯片 |
| Read Data | `03` | 读取记录 |
| Write Enable | `06` | 允许下一次擦除/编程 |
| Sector Erase | `20` | 擦除 4 KB 扇区 |
| Page Program | `02` | 写入记录 |
| Read Status Register | `05` | 查询 WIP 忙位 |

`finish_transaction` 把 CS 拉高并要求保持 `CS_HIGH_CYCLES=4` 个系统时钟，修正了实板连续 SPI 指令间隔不足的问题。

---

## 9. Listing 4：`rpi_camera_link.v` 逐句理解

### 9.1 第 1~10 行：注释和参数

```verilog
module rpi_camera_link #(
    parameter integer CLOCK_HZ     = 50_000_000,
    parameter integer BAUD         = 115_200,
    parameter integer RETRY_CYCLES = 25_000_000
)
```

- `CLOCK_HZ` 必须与实际 FPGA 时钟一致，否则波特率和重试时间错误。
- `BAUD` 必须和树莓派 `config.json` 的 `baud_rate` 一致。
- `RETRY_CYCLES/CLOCK_HZ=0.5 s`，所以未收到 ACK 时每 500 ms 再发一次。

注释中的“请求独立于 `alarm_active` 锁存”由 `link_waiting` 实现。Listing 4 没有 `alarm_active` 输入，因此 KEY2 根本无法直接清除它。

### 9.2 第 12~17 行：端口

| 端口 | 含义 |
|---|---|
| `clk` | 50 MHz 系统时钟 |
| `rst` | 系统复位；会取消所有未完成请求 |
| `photo_trigger` | 控制器第 4 次错误产生的单周期脉冲 |
| `uart_rx` | Pi TXD0 发来的串行位流 |
| `uart_tx` | 发给 Pi RXD0 的串行位流 |
| `link_waiting` | 已锁存报警但尚未收到完整 ACK |

### 9.3 第 19~28 行：每个内部变量

| 变量 | 含义 |
|---|---|
| `tx_send` | 给 `uart_tx_byte` 的单周期“开始发送此字节”命令 |
| `tx_data` | 当前要发送的 8 位 ASCII 字符 |
| `tx_busy` | 字节发送器正在输出 10 位帧 |
| `tx_done` | 一个字节完成后的单周期脉冲 |
| `rx_data` | 接收器刚刚恢复出的 8 位字符 |
| `rx_valid` | `rx_data` 新有效的单周期脉冲 |
| `message_index` | 0~5，对应 `A L A R M LF` |
| `message_active` | 正在发送一整条 `ALARM\n` |
| `byte_issued` | 当前索引的字符是否已提交，防止重复启动 |
| `retry_count` | 等待 ACK 时的 50 MHz 周期计数器 |
| `ack_state` | ACK 字符串匹配进度 0~3/4 |

### 9.4 第 30~34 行：字节层实例化

```verilog
uart_tx_byte #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) u_tx(...);
uart_rx_byte #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) u_rx(...);
```

Listing 4 不自己产生每一个 UART 位，而是把应用层的字符交给 `uart_tx_byte`；接收方向由 `uart_rx_byte` 把串行位恢复成 `rx_data/rx_valid`。

### 9.5 第 36~48 行：`alarm_byte` 函数

```verilog
case (index)
    0: "A";
    1: "L";
    2: "A";
    3: "R";
    4: "M";
    default: 8'h0a;
endcase
```

Verilog 中单个字符字符串可作为 8 位 ASCII。`8'h0a` 是 LF 换行。默认分支服务于索引 5，同时保证 case 完整，不推导锁存。

### 9.6 第 50~59 行：复位值

- `tx_send=0`：不启动发送。
- `tx_data=0`：数据寄存器清零。
- `message_index=0`、`message_active=0`、`byte_issued=0`：当前没有消息。
- `retry_count=0`、`ack_state=0`：重新开始计数和匹配。
- `link_waiting=0`：系统复位会取消尚未确认的拍摄请求。

### 9.7 第 61 行：默认脉冲清零

```verilog
tx_send <= 1'b0;
```

每个周期先清零；只有需要提交新字节的条件满足时，后面的赋值才把它置 1，因此 `tx_send` 是单周期事件。

### 9.8 第 63~70 行：锁存拍摄请求

```verilog
if (photo_trigger) begin
    link_waiting   <= 1'b1;
    message_active <= 1'b1;
    message_index  <= 3'd0;
    byte_issued    <= 1'b0;
    retry_count    <= 32'd0;
    ack_state      <= 3'd0;
end
```

一个 20 ns 的触发脉冲被转换成持续的 `link_waiting=1`。同时让消息从第 0 个字符 A 开始发送，并重新开始 ACK 匹配。

如果新的 `photo_trigger` 在旧请求仍等待时出现，它会重启当前消息和计时；正常控制器只在进入 ALARM 时触发一次，所以标准流程不会反复触发。

### 9.9 第 72~89 行：ACK 字符状态机

```text
ack_state=0 --收到 A--> 1
ack_state=1 --收到 C--> 2
ack_state=2 --收到 K--> 3
ack_state=3 --收到 0A--> 完成，link_waiting=0
```

在状态 1/2/3 中收到新的 A，会退到状态 1，把它视为下一个 `ACK` 的开头；收到其他字符退到 0。这让噪声中的有效 `ACK\n` 仍有机会被找出。

收到 LF 时同时：

```verilog
link_waiting <= 1'b0;
retry_count  <= 32'd0;
```

注意 `message_active` 没有在 ACK 到来时被强制清除。如果 ACK 异常早到、当前 `ALARM` 仍在发送，发送器会完成当前消息，但以后不再重发。真实树莓派只有读完 `ALARM\n` 才回复，所以正常情况下消息已接近或已经完成。

### 9.10 第 91~106 行：发送一整条消息

```verilog
if (!byte_issued && !tx_busy) begin
    tx_data     <= alarm_byte(message_index);
    tx_send     <= 1'b1;
    byte_issued <= 1'b1;
end
```

仅在字节层空闲且当前字符尚未提交时发启动脉冲。`byte_issued` 是必要的，因为 `tx_send` 发出的那个时钟沿，`tx_busy` 也要到时钟沿结束后才变为 1；没有它可能重复提交。

```verilog
if (tx_done) begin
    byte_issued <= 0;
    if (message_index == 5) ...
    else message_index <= message_index + 1;
end
```

一个字符完成后允许提交下一个。索引 5 的 LF 完成后清除 `message_active` 并从 0 准备下一次发送，但保持 `link_waiting=1` 等 ACK。

### 9.11 第 107~114 行：500 ms 重发

只有整条消息不在发送且仍等待 ACK 时才累加 `retry_count`。达到 `RETRY_CYCLES-1`：

- 计数清零；
- `message_active=1`；
- 索引回 0；
- 允许提交第一个字节。

生产参数的“500 ms”从一条 `ALARM\n` 发送结束后开始计时，所以两条消息起始点间隔约为 `500 ms + 0.52 ms`。

### 9.12 同一个 `always` 块里的优先关系

非阻塞赋值的右值都基于当前时钟沿之前的旧值；同一寄存器在同一个 `always` 中被多次赋值时，文本上后执行的赋值最终生效。例如同一周期同时有 `photo_trigger` 和完整 ACK，后面的 ACK 分支可能把 `link_waiting` 清零。正常协议不会安排这两个事件同周期，但理解这一点有助于排查边界条件。

---

## 10. UART 字节层：线上每一位怎样变化

### 10.1 波特率计算

```verilog
CLKS_PER_BIT = (CLOCK_HZ + BAUD/2) / BAUD
```

加 `BAUD/2` 是整数四舍五入。50 MHz、115200 时结果为 434：

```text
实际波特率 = 50,000,000 / 434 ≈ 115207.37 bit/s
单个位 ≈ 8.68 us
一个 8-N-1 字节 = 10 位 ≈ 86.8 us
ALARM\n 共 6 字节 ≈ 0.521 ms
```

### 10.2 `uart_tx_byte.v`

```verilog
frame <= {1'b1, data, 1'b0};
```

得到 10 位向量：`frame[9]=停止位1`、`frame[8:1]=data[7:0]`、`frame[0]=起始位0`。启动时直接输出 0；以后依次输出 `frame[1]` 到 `frame[9]`，所以数据位顺序是 D0 到 D7，即 LSB first。

关键变量：

| 变量 | 含义 |
|---|---|
| `clock_count` | 当前位还需要保持多少系统时钟 |
| `bit_index` | 当前已经输出到哪一位 |
| `frame` | 锁存的 10 位 UART 帧 |
| `busy` | 正在发送；busy 时忽略新 `send` |
| `done` | 停止位保持完毕后的单周期完成脉冲 |

### 10.3 `uart_rx_byte.v`

接收流程：

```text
RX_IDLE：等待同步后的 rx 从 1 变 0
 -> RX_START：等待半个位，在起始位中点确认仍为 0
 -> RX_DATA：每隔一个位周期采样一次，依次写 shift[0]~shift[7]
 -> RX_STOP：等待一个位周期并检查停止位为 1
 -> data=shift，valid=1 一个周期
```

`rx_meta/rx_sync` 是两级同步器，用于把板外异步 UART 输入带入 50 MHz 时钟域。若起始位中点已经回到 1，则认为是毛刺并返回 IDLE。若停止位不是 1，不产生 `valid`；当前实现没有单独输出 framing error。

---

## 11. FPGA - Raspberry Pi 通信协议如何编写

### 11.1 分层定义

一份可讲清楚的通信协议至少包含四层：

1. **电气层**：两边 3.3 V、共地、TX/RX 交叉、线长建议小于 30 cm。
2. **UART 帧层**：115200、8 数据位、无校验、1 停止位、空闲高、LSB first。
3. **消息层**：ASCII 行，以 LF `0x0A` 结束。
4. **事务层**：谁先发、何时 ACK、多久重试、成功失败怎样报告。

### 11.2 当前消息定义

| 方向 | 文本 | 十六进制字节 | 语义 |
|---|---|---|---|
| FPGA -> Pi | `ALARM\n` | `41 4C 41 52 4D 0A` | 发生第 4 次密码错误，请抓拍 |
| Pi -> FPGA | `ACK\n` | `41 43 4B 0A` | 请求已被接收，FPGA 停止重发 |
| Pi -> FPGA | `DONE\n` | `44 4F 4E 45 0A` | 四张图和四宫格成功完成 |
| Pi -> FPGA | `ERR\n` | `45 52 52 0A` | 摄像头初始化或抓拍失败 |

只有 ACK 被 FPGA 实际解析。DONE/ERR 当前是单向状态告知，但没有 FPGA 消费者。

### 11.3 当前事务时序

```text
FPGA                         Raspberry Pi
 |                                |
 |-------- ALARM\n -------------->|
 |<--------- ACK\n ----------------|
 | link_waiting=0                 | 开始/继续相机处理
 |                                | 拍四帧、保存、显示
 |<--------- DONE\n 或 ERR\n ------|
 | 当前 FPGA 忽略                 |
```

若 500 ms 内没有 ACK：

```text
FPGA -------- ALARM\n --------> Pi
     等待 500 ms
FPGA -------- ALARM\n --------> Pi
     持续到收到 ACK 或系统复位
```

### 11.4 为什么选 UART，不选 SPI/单 GPIO/以太网

- 只传一个低速事件，不需要 SPI 的额外时钟和片选线。
- 比单 GPIO 脉冲多了可读消息、ACK 和重发，不容易漏掉窄脉冲。
- 不依赖 IP 地址、交换机和网络配置。
- FPGA 和 Pi 都支持 3.3 V UART，只需两根信号线加地。

### 11.5 当前协议的可靠性边界

它实现的是“至少一次通知”，不是“严格只执行一次”。若 Pi 收到 ALARM 并开始拍摄，但 ACK 在回程丢失，FPGA 会重发；Pi 没有事件编号或去重表，可能再次拍摄。程序拍摄期间也是阻塞执行，不持续读取串口；积压的重发消息可能在拍摄结束后被继续处理。

协议也没有 CRC、序号、最大重试次数或流控。课程设计的短线控制事件可以使用，但答辩时不应称为工业级可靠协议。

若要升级为“接近严格一次”，可设计：

```text
FPGA -> Pi: ALARM,<event_id>\n
Pi   -> FPGA: ACK,<event_id>\n
Pi   -> FPGA: DONE,<event_id>\n 或 ERR,<event_id>\n
```

Pi 保存最近处理过的 `event_id`，重复请求只重发 ACK/DONE，不重复拍照；必要时再加入 CRC。

### 11.6 接线

| FPGA 扩展口 | FPGA 芯片脚 | Raspberry Pi 5 | 方向 |
|---|---|---|---|
| GPIOA_0，脚 1 | J16 | GPIO15/RXD0，物理脚 10 | FPGA -> Pi |
| GPIOA_1，脚 2 | H13 | GPIO14/TXD0，物理脚 8 | Pi -> FPGA |
| GND，脚 12/30 | - | GND，物理脚 6 | 公共参考地 |

不要连接两板的 3.3 V/5 V 电源脚，更不能把 5 V 接到 UART 信号线。

---

## 12. Raspberry Pi 端从安装到代码

### 12.1 系统配置与安装

1. 在 Raspberry Pi OS 中进入项目目录。
2. 执行：

```bash
chmod +x scripts/*.sh
./scripts/install.sh
```

脚本安装 `python3-picamera2`、`python3-serial`、`python3-pil`、`python3-opencv`，并把当前用户加入 `dialout` 串口组。

3. `sudo raspi-config` -> Interface Options -> Serial Port：
   - Serial login shell：No；
   - Serial hardware：Yes。
4. `/boot/firmware/config.txt` 确认：

```ini
enable_uart=1
dtoverlay=uart0-pi5
```

5. 重启，检查：

```bash
ls -l /dev/ttyAMA0
pinctrl get 14 15
rpicam-hello -t 5000
```

6. 创建配置并运行：

```bash
cp config.example.json config.json
./scripts/run.sh
```

### 12.2 `config.example.json` 每个参数

| 参数 | 默认值 | 影响 |
|---|---:|---|
| `serial_port` | `/dev/ttyAMA0` | 使用哪个串口设备 |
| `baud_rate` | 115200 | 必须与 FPGA BAUD 相同 |
| `capture_width/height` | 640/480 | CSI 主流输出尺寸 |
| `mosaic_width/height` | 640/480 | 最终 HDMI 四宫格图像尺寸 |
| `capture_count` | 4 | 程序强制必须为 4 |
| `capture_interval_seconds` | 0.1 | 相邻帧间隔 |
| `capture_timeout_seconds` | 2.0 | 整次四帧抓拍目标超时 |
| `output_directory` | `captures` | 保存根目录 |
| `fullscreen` | true | OpenCV 是否全屏显示 |

### 12.3 `protocol.py` 逐句逻辑

```python
ALARM = "ALARM"
ACK = b"ACK\n"
DONE = b"DONE\n"
ERROR = b"ERR\n"
```

`ALARM` 是解码后的 Python 字符串；其余是要直接写串口的字节串。

```python
command = raw.decode("ascii", errors="strict").strip().upper()
```

- 严格 ASCII 解码；非法字节抛异常并返回 `None`。
- `strip()` 去除 LF、CR 和首尾空格。
- `upper()` 允许输入小写 `alarm`。
- 只在结果恰好为 ALARM 时返回命令，其他噪声忽略。

### 12.4 `app.py` 的结构

#### 导入和默认配置（1~33 行）

- 标准库处理参数、JSON、日志、目录、时间和类型。
- PIL `Image` 处理图像。
- 从本项目导入真/假相机、真/无头显示、四宫格和协议常量。
- `DEFAULTS` 是没有 `config.json` 字段时的回退值。

#### `load_config()`（36~43 行）

先复制默认配置，再用 JSON 覆盖。强制 `capture_count==4`，避免配置声称拍 N 张而实际四宫格只处理四张。

#### `capture_incident()`（46~74 行）

1. `expanduser().resolve()` 得到绝对输出目录。
2. 建立根目录和唯一时间戳。
3. 先创建以点开头的 `.partial` 临时目录。
4. 循环四次：`camera.capture()`、转 RGB、保存 `frame_1~4.jpg`。
5. 用 `time.monotonic()` 计算不受系统时钟校准影响的耗时。
6. 非最后一帧才 sleep，因此共有三次帧间隔。
7. `build_mosaic()` 生成四宫格并保存。
8. `partial.rename(final)` 在同一文件系统内原子提交完整目录。
9. 任一异常都删除临时目录并继续向上抛出。

#### `make_camera()`（77~79 行）

`--mock-camera` 时返回彩色模拟相机；正常时返回 Picamera2 封装。两者都提供 `capture()` 和 `close()`，这叫接口兼容/依赖替换。

#### `load_latest_mosaic()`（82~104 行）

- 只遍历非隐藏目录，忽略 `.partial` 半成品。
- 找到存在的 `mosaic.jpg`，按文件修改时间选最新。
- 在 `with Image.open` 内转 RGB 并 `load()`，确保文件关闭后像素仍在内存。
- 损坏文件只记录日志并回退，不让程序崩溃。

#### `run_capture()`（107~121 行）

成功：显示四宫格、记录完成目录、返回 True。失败：记录异常、显示红色错误页、返回 False。返回值决定主循环发送 DONE 还是 ERR。

#### `main()` 参数（124~143 行）

| 参数 | 作用 |
|---|---|
| `--config` | 指定配置文件 |
| `--mock-camera` | 不使用真实 CSI |
| `--trigger-on-start` | 启动立即拍摄一次，不打开串口 |
| `--headless` | 不创建 HDMI/OpenCV 窗口 |
| `--windowed` | 不全屏，便于调试 |

启动时优先恢复最近完整四宫格；没有记录才显示测试色条。

#### 串口主循环（145~179 行）

```python
with serial.Serial(... timeout=0.10) as uart:
```

打开 115200、8 数据位、无校验、1 停止位串口；`timeout=0.10` 使 `readline()` 最多阻塞约 100 ms，程序还能轮询退出键。

```python
command = decode_command(uart.readline())
if command != ALARM:
    continue
```

逐行读取，只有 ALARM 进入拍摄流程。

```python
uart.write(ACK)
uart.flush()
```

先回 ACK 并等待发送缓冲排空，尽快阻止 FPGA 重发。随后才懒加载摄像头。

摄像头初始化失败：显示错误页、发送 ERR、继续监听。抓拍成功发送 DONE，失败发送 ERR。

#### 清理（180~190 行）

Ctrl+C 返回 0。无论正常退出还是异常，只要创建过相机就 `camera.close()`，并关闭显示窗口。脚本入口用 `sys.exit(main())` 把返回值作为进程退出码。

### 12.5 `camera.py`

- `Picamera2()` 创建相机控制器。
- `create_preview_configuration(main={format:RGB888,size},buffer_count=4)` 设置主流和缓冲数。
- `configure/start` 应用并启动相机，等待 1 秒自动曝光/白平衡预热。
- `capture_array("main")` 得到 NumPy 图像，再转换为 PIL RGB。
- `MockCamera` 每次生成不同底色并写入 `MOCK FRAME n`，用于没有 CSI 的开发机自测。

### 12.6 `mosaic.py`

- 输入必须恰好 4 帧，否则抛 `ValueError`。
- 用整除计算左右/上下尺寸，即使总尺寸为奇数也能完整覆盖。
- 位置固定为左上、右上、左下、右下，对应第 1~4 帧。
- `ImageOps.fit(..., LANCZOS)` 保持比例并裁剪填满象限，不做非比例拉伸。
- `test_pattern` 生成色条和 READY 文本。
- `error_screen` 生成暗红背景和错误摘要。

### 12.7 `display.py`

- `HdmiDisplay` 创建 OpenCV 窗口并可设全屏。
- PIL 是 RGB，OpenCV 显示期望 BGR，所以用 `COLOR_RGB2BGR` 转换。
- `waitKey(1)` 刷新窗口；Esc 或 q 退出。
- `HeadlessDisplay` 的三个方法什么都不做，但保持相同接口，便于服务器/自动测试。

### 12.8 无相机自检

```bash
./scripts/run.sh --mock-camera --trigger-on-start --windowed
./scripts/run.sh --mock-camera --trigger-on-start --headless
python3 -m unittest discover -s tests -v
```

本轮在当前工作区实际执行 Python 单元测试，6 项全部通过。它们覆盖协议解析、四宫格位置、强制四帧、最新完整画面恢复和缺失目录处理；不等于真实 CSI、GPIO UART 和 HDMI 硬件测试。

---

## 13. Vivado 仿真：变量、波形和现实动作怎样对应

### 13.1 Testbench 不是要烧进 FPGA 的硬件

`tb_*.sv` 只在仿真器中运行。它负责产生时钟、复位和外部激励，实例化被测模块 DUT，并用断言检查结果。`initial`、`#5`、`$fatal`、`$finish` 等代码不会进入最终 FPGA。

典型结构：

```systemverilog
reg clk=0;                    // testbench 主动驱动 DUT 输入
wire state;                   // DUT 输出由 testbench 观察
always #5 clk=~clk;           // 10 ns 仿真周期
模块名 dut(...);              // Device Under Test
task key(...); ... endtask    // 可复用激励动作
initial begin                 // 按顺序执行测试场景
    ...
    if (...) $fatal(...);     // 不满足即 FAIL
    test_pass=1;
    $finish;
end
```

测试平台通常在 `negedge clk` 改输入，因为 DUT 在 `posedge clk` 采样。这样输入有半个周期建立时间，避免 testbench 与 DUT 同一上升沿抢执行顺序。

### 13.2 为什么仿真时间被压缩

若直接仿真 50 MHz 的 16 秒，需要 8 亿个周期，浪费时间。控制器测试将 `CLOCK_HZ` 从 50,000,000 改为 1000，将 8/16 秒等比例改为 1/2 个“仿真参数秒”：

```text
仿真输入超时：1000 * 1 = 1000 周期，对应实机 50M * 8
仿真开锁超时：1000 * 2 = 2000 周期，对应实机 50M * 16
```

真实 `always #5` 仍然让一个仿真周期为 10 ns，所以 1000 个周期只消耗 10 us 仿真时间。测试的是周期计数和边界逻辑，不是在计算机里等待真实 8 秒。

### 13.3 波形窗口通用读法

1. 先看 `rst`：高表示复位；下降后模块开始工作。
2. 找输入事件的 0->1，例如 `key_valid`、`sw1`、`photo_trigger`。
3. 找紧随其后的 `clk` 上升沿；同步寄存器在此采样。
4. 查看 `state`、计数器或输出是否在该沿之后改变。
5. 总线交叉表示值变化；Value 列是黄色游标处的值，不代表整条波形。
6. 把密码总线 radix 设为 Hex，因为 `16'h1234` 是四个 BCD 半字节；把普通计数器设为 Unsigned/Decimal。
7. `X` 表示未知/未初始化，`Z` 表示高阻。testbench 中 `previous_password` 初始出现 X 是正常的；板级关键控制信号出现 X 则需排查复位或多驱动。

### 13.4 常用公共变量

| 变量 | 含义 | 现实对应 |
|---|---|---|
| `clk` | 仿真时钟 | 板载 50 MHz 晶振 |
| `rst` | 高有效复位 | KEY4/上电复位后的内部复位 |
| `test_pass` | 全部断言通过后置 1 | 仅仿真验收标志，无板级引脚 |
| `scenario` | testbench 当前场景编号 | 仅用于把长波形分段，无真实硬件意义 |
| `state` | 控制器状态 0~8 | 数码管状态词和操作阶段 |
| `key_valid` | 一个稳定键事件 | 用户按键消抖后的单次动作 |
| `key_code` | 4 位键码 | 0~9/A/B/C/D/*/# |
| `entry_digits` | 4 个 BCD 输入位 | 数码管右侧已经输入的数字 |
| `entry_count` | 已输入位数 0~4 | 决定显示几位、是否允许 A 确认 |
| `error_count` | 累计错误 0~4 | Err1~Err3/ALAr |
| `unlocked` | 当前在 OPEN | 门锁执行器/开锁 LED 的逻辑状态；本项目用 LED 表示 |
| `alarm_active` | 当前在 ALARM | 报警 LED、蜂鸣器使能 |
| `capture_start` | 进入 ALARM 的单周期脉冲 | 触发 Pi 通信模块，不是相机曝光脉冲 |

### 13.5 01 `tb_basic_entry_timeout`

主要变量：

| 变量 | 测试作用 |
|---|---|
| `init_done` | 模拟 Flash 初始化完成 |
| `sw1` | 模拟消抖后的 SW1 单周期事件，不是机械电平全过程 |
| `scenario=1` | 复位/初始化进入 WAIT |
| `scenario=2` | 不足四位、退格、四位上限 |
| `scenario=3` | 1234 开锁和自动上锁 |
| `scenario=4` | 输入无操作超时 |
| `scenario=5` | OPEN 中按 A 立即上锁 |

波形链：`sw1=1` -> 上升沿 -> `state 1->2`；每次 `key_valid=1` -> `entry_digits` 左移追加、`entry_count+1`；输入 1234 后 A -> `state 2->4`、`unlocked=1`；超时/A -> `state 4->1`、输入清零。

现实变化：拨上 SW1、逐个按键、数码管右侧显示数字、正确后显示 OPEN/LED3，16 秒后回 PASS。

### 13.6 02 `tb_basic_admin_save`

| 变量 | 含义 |
|---|---|
| `admin` | KEY1 消抖后的事件 |
| `save_request` | 控制器给 Flash 的单周期保存请求 |
| `save_password` | 本次要保存的新四位密码 |
| `save_done` | testbench 模拟 Flash 操作结束 |
| `save_success` | 模拟回读校验成功/失败 |
| `display_fault` | 1 时数码管优先显示 FErr |

波形：`admin` -> `state=5`；输入 5678+A -> `state=6`、`save_request=1`、`save_password=5678`；`save_done=1/save_success=1` -> WAIT，无故障。第二次模拟 `save_success=0` -> WAIT 且 `display_fault=1`。新 SW1/KEY1/KEY3 操作清除历史 FErr，持续 Flash 故障仍会重新置位。

现实：KEY1 后显示 SEt，输入新密码，显示 SAVE；成功回 PASS，新密码生效；失败显示 FErr，旧密码仍有效。

### 13.7 03 `tb_basic_alarm_policy`

| 变量 | 含义 |
|---|---|
| `clear` | KEY2 消抖后的事件 |
| `temp_event/admin` | 用来证明 KEY3/KEY1 不能绕过报警 |
| `capture_pulses` | 在上升沿统计 `capture_start` 为 1 的次数 |

错误密码 `1111+A` 重复四次：前三次 `state=3` 且 `error_count=1/2/3`，短暂提示后回 USER；第 4 次 `state=7`、`error_count=4`、`alarm_active=1`，`capture_start` 只出现一拍且 `capture_pulses=1`。报警期间除 `clear` 外的事件都无效；KEY2 后 `state=2`、`error_count=0`。

现实：前三次显示 Err1~Err3；第四次显示 ALAr、LED 闪烁和蜂鸣器鸣叫，同时树莓派收到事件；只有 KEY2 停警。

![四次错误、报警与 KEY2 解除波形](simulation_waveforms/03_error_alarm_policy/tb_basic_alarm_policy.png)

### 13.8 04 `tb_keypad_scanner`

| 变量 | 含义 |
|---|---|
| `pressed_keys[15:0]` | testbench 的虚拟 16 键按下矩阵，1 表示按下 |
| `col_n` | DUT 当前拉低的列 |
| `row_n` | testbench 根据按键矩阵和当前列计算的行输入 |
| `expected_code` | 当前期望键码 |
| `event_valid/code` | 扫描器输出的单周期事件和键码 |
| `events` | 已产生事件次数 |
| `scenario=0x10~0x1F` | 顺序检查 16 个物理位置 |

长按测试要求 `events` 只加 1；多键样本不产生事件；全部释放后 16 个位置逐一验证。

现实：四列高速轮询，用户看不到闪烁；按住一个键只输入一次；同时按多个键全部忽略，释放后才能再次输入。

### 13.9 05 `tb_sevenseg_display`

| 变量 | 含义 |
|---|---|
| `state` | 强制遍历 0~8 |
| `entry_digits/count` | 验证右侧输入位 |
| `temporary_password` | 验证 TEMP 右四位 |
| `display_fault` | 验证 FErr 优先级 |
| `digit_sel` | 低有效 8 位位选 |
| `seg_n` | 当前位的低有效段码 |

`count_zeroes(digit_sel)==1` 证明任一时隙只使能一个数码管。testbench 直接查看 DUT 内部 `chars[]`，验证 INIT/PASS/Err3/OPEN/SEt/SAVE/ALAr/tEMP/FErr。

现实：波形上位选快速移动、段码随位改变；人眼看到稳定八位内容。若位选有多个 0，实物可能重影；全 1 则全灭。

### 13.10 06 `tb_alarm_buzzer`

仿真把 `CLOCK_HZ=40`、`BEEP_HZ=2`、`TONE_HZ=5`，让节拍在几十个周期内可见。

| 变量 | 现实含义 |
|---|---|
| `alarm_active` | 状态机报警使能 |
| `indicator` | 慢节拍 LED |
| `buzzer_n` | 有声窗口中的方波载波 |

波形应出现：非报警两个输出为 0；报警开始为高相位；有声阶段 `buzzer_n` 翻转；静音阶段两者为 0；清除报警后组合输出立即变 0，不必等计数周期结束。

### 13.11 07 `tb_flash_default_fail`

`flash_miso` 被固定为 1，模拟空白/不可读总线。主要变量：

- `cs/sclk/mosi`：SPI 命令活动。
- `init_done`：读取流程完成。
- `password`：必须回退为 1234。
- `save/save_done/save_ok/fault`：请求保存、完成、结果和故障。

写入无法回读验证时 `save_ok=0`，`password` 仍为 1234。现实中对应 Flash 接线错误、器件异常或写/回读失败，数码管显示 FErr，旧密码不被污染。

### 13.12 08 `tb_flash_journal`

| 变量 | 含义 |
|---|---|
| `new_password` | 本次保存值 |
| `miso` | `w25q64_model` 返回数据 |
| `cs_high_cycles` | 两次 CS 拉低之间的高电平周期数 |
| `enforce_cs_gap` | 初始化后开启 CS 间隔断言 |
| `flash.mem[]` | 仿真模型内部 8 KB 存储阵列 |

测试先保存 5678，再保存 2468；复位后应选 generation 更高的 2468。随后故意破坏新记录的 COMMIT 字节，再复位应恢复旧扇区 5678。这对应掉电中断新写入但旧密码仍可恢复。

### 13.13 09 `tb_temporary_password_generator`

| 变量 | 含义 |
|---|---|
| `generate_event` | 模拟允许后的 KEY3 单周期事件 |
| `stored_password` | 固定密码，候选不能等于它 |
| `temporary_password` | 新临时密码 |
| `temporary_valid` | 是否允许该密码参与比较 |
| `previous_password` | testbench 保存的上一临时密码 |

测试 32 次生成，检查四个半字节均 <=9、不等于固定密码、不等于上一临时密码；复位后 valid=0。初始 `previous_password=X` 是尚未赋值的 testbench 变量，不是模块故障。

现实：PASS/TEMP 页面按 KEY3 显示一组四位数；再次按替换旧密码；KEY4、重新配置或断电后失效。它是确定性 LFSR 伪随机，不适合作为密码学随机源。

### 13.14 10 `tb_rpi_camera_link`（Listing 4 对应仿真）

仿真参数：`CLOCK_HZ=800`、`BAUD=100`，因此 `CLKS_PER_BIT=8`；`RETRY_CYCLES=200`。这些只为快速看到波形，生产值仍是 50 MHz/115200/25,000,000。

| 变量 | 含义 | 波形判断 |
|---|---|---|
| `photo_trigger` | 第 4 次错误事件 | 一拍高后 `link_waiting=1` |
| `uart_tx` | FPGA 发出的串行位 | 空闲 1，消息开始下降到起始位 0 |
| `uart_rx` | testbench 模拟 Pi 发回的串行位 | 按 8 个 clk/位注入 ACK |
| `link_waiting` | 等待完整 ACK | 触发后高，A-C-K-LF 后低 |
| `message_active` | 内部整条消息发送中 | 六个字符期间为高 |
| `message_index` | 当前字符 0~5 | 随 `tx_done` 增加 |
| `rx_valid` | 收到一个完整字节 | 每个 ACK 字符结束时脉冲 |
| `rx_data` | 当前接收字符 | 41、43、4B、0A |
| `tx_starts` | testbench 统计 TX 所有下降沿 | 名称并不严格等于起始位数 |

必须知道当前测试的薄弱点：

```verilog
always @(negedge uart_tx) tx_starts = tx_starts + 1;
```

它统计所有 1->0 跳变，包括数据位内部跳变，不只统计 UART 起始位。最终 `tx_starts<3` 的断言又使用从第一次消息开始的累计值，所以不能严格自动证明“第二次请求发生了重发”。当前 RTL 确实有重发逻辑，保存波形也能看到重试等待后的第二段发送活动，但答辩时应说“代码和波形支持重发结论，现有自动断言仍可加强”，不要说测试平台逐字节严格验证了全部消息和重发次数。

此外测试平台在触发后较早注入 ACK，没有先解码 FPGA 完整输出，因而主要验证接收匹配和等待清除，不是完整的双端协议闭环模型。

![FPGA 报警 UART、ACK 与重发波形](simulation_waveforms/10_extra_camera_uart/tb_rpi_camera_link.png)

### 13.15 11 `tb_lock_controller`

这是不经过真实键盘/Flash/UART字节层的控制器集成回归。它直接驱动控制器端口，依次验证：

- 固定密码 1234 开锁；
- 临时密码 2468 开锁；
- 替换为 1357 后旧 2468 被拒绝；
- 固定密码在临时密码有效时仍可使用；
- 管理员保存 5678；
- 四次错误报警；
- KEY1/KEY3/键盘不能解除；
- KEY2 后进入 USER、错误次数清零；
- 解除后的第一次错误显示 Err1；
- 输入超时。

它证明各功能能在同一个控制器实例中共同工作，但不包含矩阵扫描、真实 SPI 或 UART 位波形。

### 13.16 在 Vivado GUI 打开和操作波形

打开已有波形：

```tcl
open_wave_database E:/26FPGA/simulation_waveforms/10_extra_camera_uart/tb_rpi_camera_link.wdb
open_wave_config E:/26FPGA/simulation_waveforms/10_extra_camera_uart/tb_rpi_camera_link.wcfg
```

常用操作：

1. 在波形树选信号 -> Add to Wave Window。
2. 右键总线 -> Radix -> Hexadecimal/Unsigned。
3. Zoom Fit 看全程；放大某次事件前后。
4. 点击时间轴放置黄色游标，Value 列读取该时刻值。
5. 用两个游标测量位宽：UART 仿真中一个位应为 8 个 clk；实机参数推导应为约 434 个 clk。
6. 先看 testbench 顶层信号，再展开 `dut` 看 `message_active`、`message_index`、`ack_state`、`retry_count` 等内部信号。

---

## 14. 功能、代码、波形和实物的一一对应

| 功能 | 关键代码/参数 | 仿真应看到 | 实物应看到 |
|---|---|---|---|
| 上电 | `reset_sync`、`ST_BOOT`、`flash_init_done` | rst 释放，state 0->1 | INIT 后 PASS |
| 开始输入 | SW1 `rise_event`、WAIT->USER | sw1 脉冲，state 1->2 | 拨上 SW1 后可输入 |
| 数字输入 | `entry_digits` 拼接、`entry_count+1` | 每个 key_valid 后总线增加一位 | 右侧逐位显示 |
| 退格 | B、右移 4 位 | entry_count-1，最低有效数字删除 | 数码管少一位 |
| 取消 | C、USER/ADMIN->WAIT | state ->1，输入清零 | 回 PASS |
| 正确开锁 | 固定/有效临时密码比较 | state 2->4，unlocked=1 | OPEN、开锁 LED |
| 自动上锁 | `OPEN_TICKS` | 计时边界 state 4->1 | 16 秒回 PASS |
| 错误 | `error_count` | 1/2/3 和 ERROR 状态 | Err1/Err2/Err3 |
| 第 4 次报警 | `error_count==3` -> ALARM | capture_start 一拍，alarm_active 持续 | ALAr、LED/蜂鸣器、Pi 拍照 |
| KEY2 | ALARM->USER | clear 脉冲，error_count->0 | 停警并直接可重新输入 |
| 管理员改密 | ADMIN->SAVE、save handshake | save_request/password、done/success | SEt -> SAVE -> PASS/FErr |
| 临时密码 | LFSR、temporary_valid | generate_event 后密码变化 | tEMP + 四位数 |
| UART 请求 | `message_index` 0~5 | uart_tx 六个 8-N-1 帧 | Pi 日志收到 ALARM |
| ACK | `ack_state` | rx_data A/C/K/LF，waiting->0 | FPGA 停止重发 |
| 四宫格 | Pi `capture_incident/build_mosaic` | 不属于 Vivado 波形 | 4 JPEG + mosaic + HDMI |

---

## 15. 老师要求现场改功能时，改哪里

### 15.1 把输入超时从 8 秒改为 5 秒

改 `lock_controller.v` 参数默认值：

```verilog
parameter integer LOCK_TIMEOUT_S = 5
```

影响 USER、ADMIN、TEMP 三类超时。还要更新报告、使用手册和控制器 testbench 的期望/说明；如果测试仍覆盖边界，应保持参数缩放并修改等待周期。

### 15.2 把开锁时间从 16 秒改为 10 秒

改 `OPEN_TIMEOUT_S=10`。波形中 OPEN 高电平持续周期变短，实物 OPEN 和开锁 LED 10 秒后熄灭。

### 15.3 第 3 次错误就报警

当前第四次判断是：

```verilog
else if (error_count == 3'd3) next_state = ST_ALARM;
```

改为比较 2，并在进入报警时把 `error_count` 设 3。必须同步修改 `tb_basic_alarm_policy` 和 `tb_lock_controller` 的错误循环、断言、显示说明。只改比较不改显示/测试会造成逻辑与文档不一致。

### 15.4 把 UART 改为 57600

至少同步改两端：

- FPGA `rpi_camera_link.v` 的 `BAUD=57_600`，或顶层实例覆盖参数。
- Pi `config.json` 的 `baud_rate=57600`。

UART testbench若仍覆盖同一算法，可保持缩小参数，也可专门增加对生产 `CLKS_PER_BIT` 的计算断言。只改一边会产生乱码和无 ACK 重发。

### 15.5 把重发时间从 500 ms 改为 1 s

改 `RETRY_CYCLES=CLOCK_HZ`，不要直接只写固定 50,000,000 后又忘记时钟可配置。同步修改 `tb_rpi_camera_link` 的覆盖参数和等待长度。

### 15.6 改协议消息

例如改成 `PHOTO\n`：

1. FPGA `alarm_byte()` 改字符和消息长度终止索引。
2. `message_index` 位宽若消息更长要重新计算。
3. Pi `protocol.py` 的命令常量/解码规则同步修改。
4. testbench 必须真正解码 TX 字节并断言内容。
5. README、报告协议表同步修改。

不能只改字符串而不改 `message_index==5`，否则会少发或多发字节。

### 15.7 让 DONE/ERR 真正影响 FPGA

需要把 ACK 匹配器扩展为多消息行解析器，并新增输出，例如 `capture_done`、`capture_error`。顶层再把它们接到控制器或 LED。必须先定义策略：

- DONE 是否熄灭某个等待 LED？
- ERR 是否显示相机故障？
- ERR 是否影响声光报警？
- KEY2 和 ERR 同时到达谁优先？

当前设计故意让 Pi 拍摄结果不影响密码锁安全状态，所以不能未经需求定义就直接让 ERR 清报警。

### 15.8 改蜂鸣器频率或节拍

- 音调：`alarm_buzzer.v` 的 `TONE_HZ`。
- 间歇频率：`BEEP_HZ`。

例如 1 kHz 音调：`TONE_HZ=1000`。波形中载波半周期加倍，实物音调降低。修改 testbench 的缩小参数或断言等待拍数。

### 15.9 改按键消抖时间

- SW/KEY：`debounce_event.DEBOUNCE_MS`。
- 矩阵键盘：`COLUMN_TICK_HZ` 和 `DEBOUNCE_SCANS`共同决定。

矩阵稳定时间约为：

```text
4 列 / COLUMN_TICK_HZ * DEBOUNCE_SCANS
```

默认约 `4/1000*5=20 ms`。太短易抖动，太长手感迟钝。

### 15.10 改数码管文字

改 `sevenseg_display.v` 的状态到 `chars[]` 映射；若需要新字母，还要在 `encode()` 中增加段码。低有效共阳板卡中，段码 0 表示该段点亮。修改后更新 `tb_sevenseg_display` 的 `check_word()` 期望。

### 15.11 改矩阵键盘接线或键值

- 物理管脚变化：改 XDC。
- 行列角色/顺序变化：先用示波/仿真确定，再改 XDC 或 `decode_key()` 映射。
- 不要同时随意改排线、XDC 和 decode，否则难以定位转置问题。

### 15.12 改固定默认密码

需要统一检查多个位置：

- `w25q64_password_store` 复位和无有效记录回退值。
- `lock_controller` 的 `save_password` 复位初值虽不是当前密码，但应保持一致性。
- Flash 与控制器相关 testbench 的期望。
- 使用手册和报告。

已经写入 W25Q64 的有效记录优先于默认值，所以仅改 RTL 默认密码不会覆盖板上现有 2580；要通过管理员改密或清除用户 Flash 记录。

### 15.13 改拍摄张数或四宫格尺寸

- 分辨率：Pi `config.json` 的 capture/mosaic 宽高。
- 当前拍摄张数被 `load_config()` 强制为 4，`capture_incident()` 也写死 `range(4)`，`build_mosaic()` 要求四帧。
- 若改为 6 张，必须同时重新设计布局、循环、验证和文件说明，不能只改 JSON。

---

## 16. 常见故障与定位顺序

### 16.1 Vivado 找不到顶层或端口

检查：所有 RTL 是否加入 Design Sources；`password_lock_top` 是否 Set as Top；XDC 端口名是否与顶层完全一致；仿真顶层是否错误设成设计顶层。

### 16.2 仿真一直不结束

检查 testbench 是否到达 `$finish`，是否在 `wait(init_done)` 等待永远不会变高的信号；查看 Tcl Console 最后状态。当前 Windows/Vivado 环境关闭 XSim 可能卡住，因此脚本让每个测试单独启动进程。

### 16.3 数码管乱码/全灭/重影

依次检查：`seg_n`/`digit_sel` 是否低有效；XDC 位序是否正确；任一时刻 `digit_sel` 是否只有一个 0；刷新是否约每位 1 kHz；SW6 是否在数码管档位。

### 16.4 键盘只有对角线正确

典型行列转置。检查排线 R/C 丝印、`col_n` 实际输出位置和 `row_n` 输入位置。本工程已经在 XDC 交换角色，保持当前实机排线即可。

### 16.5 蜂鸣器不响

检查 ALARM 状态、`alarm_active`、波形中 `buzzer_n` 是否有载波、P20 约束、SW5 是否接通。当前实板实测高电平使能，不要照旧版手册反相。

### 16.6 Flash 始终默认 1234 或 FErr

先看 `flash_cs_n/sclk/mosi/miso` 是否活动，再看 JEDEC ID 是否非全 0/全 1、CS 高电平间隔、WP/HOLD 是否为 1。确认使用的是用户 W25Q64，而不是 FPGA 配置 Flash。写失败时旧密码保留是设计行为。

### 16.7 Pi 一直收不到 ALARM

按顺序检查：

1. FPGA 是否真的进入 `state=7`，`capture_start` 是否有一拍。
2. `ENABLE_RPI_CAMERA` 是否为 1。
3. FPGA TX 是否接 Pi GPIO15/RXD0 物理脚 10。
4. TX/RX 是否交叉且共地。
5. 两边是否都是 3.3 V、115200-8-N-1。
6. Pi serial login shell 是否关闭、UART 硬件是否启用。
7. `/dev/ttyAMA0` 是否存在且用户在 dialout 组。
8. 逻辑分析仪上 FPGA TX 空闲应为高，报警时应看到六个 UART 字节。

### 16.8 FPGA 一直重发 ALARM

说明 `link_waiting` 未被完整 `ACK\n` 清除。检查 Pi TX -> FPGA RX 接线、Pi 是否实际写出 LF、两端波特率、FPGA RX 上拉、`rx_valid/rx_data/ack_state`。`ACK\r\n` 在当前 FPGA 匹配器中可能因 CR 打断 `K` 后的 LF 匹配；Python 当前发送的是严格 `ACK\n`。

### 16.9 Pi 收到报警但相机失败

ACK 会在相机初始化前发出，所以 FPGA 停止重发并不证明拍摄成功。检查 `rpicam-hello`、CSI 排线方向、Picamera2、2 秒超时和程序日志；失败应显示红色错误页并发 ERR，但 FPGA 当前不会处理 ERR。

### 16.10 报警产生重复目录

可能是 ACK 丢失导致 FPGA重发，而 Pi 没有事件 ID 去重；也可能串口缓冲中积压多个 ALARM。查看时间戳、Pi 日志和 FPGA `link_waiting/retry_count`，需要严格一次语义时升级协议。

---

## 17. 独立复现验收清单

### 17.1 纯软件/无板阶段

- [ ] 能从 GUI 或 `create_project.tcl` 建立工程。
- [ ] 设计顶层为 `password_lock_top`，器件正确。
- [ ] 11 个 testbench 均可选择并运行。
- [ ] `run_all.ps1 -SkipImplementation` 通过。
- [ ] 能打开 WDB/WCFG并解释状态、事件和计数器。
- [ ] Raspberry Pi 项目 6 个单元测试通过。
- [ ] MockCamera 能生成 4 张图和 `mosaic.jpg`。

### 17.2 FPGA 板级阶段

- [ ] JTAG 下载位流后 INIT -> PASS。
- [ ] 16 键映射正确，长按不重复、多键被屏蔽。
- [ ] 1234/当前 Flash 密码开锁，B/C/A 行为正确。
- [ ] 8 秒输入超时、16 秒开锁超时正确。
- [ ] Err1~Err3、第 4 次 ALAr、KEY2 策略正确。
- [ ] KEY1 改密、复位恢复和断电保持正确。
- [ ] KEY3 临时密码实机生成、替换、开锁、复位失效。
- [ ] LED、数码管、蜂鸣器与状态一致。

### 17.3 FPGA - Pi 联调阶段

- [ ] TX/RX 交叉、公共地、无电源互接。
- [ ] Pi 显示 READY/最近一次四宫格并监听 ttyAMA0。
- [ ] 第 4 次错误时 Pi 日志收到 ALARM。
- [ ] FPGA 收到 ACK 后不再重发。
- [ ] 四张 640x480 JPEG 和 mosaic 完整保存。
- [ ] HDMI显示新四宫格。
- [ ] KEY2 停警后四宫格仍保留。
- [ ] 第二次报警新建目录并更新画面。
- [ ] 拔掉/阻断 Pi TX 时能观察 FPGA 重发。

### 17.4 综合实现阶段

- [ ] Synthesis/Implementation 达到 100%。
- [ ] DRC violations=0。
- [ ] WNS/WHS 非负，TNS/THS=0。
- [ ] 生成新的 `password_lock_top.bit`。
- [ ] 确认构建参数 ENABLE_RPI_CAMERA 与预期一致。

---

## 18. 高频口试题与标准回答

### Q1：Listing 1 的作用是什么？

它是顶层接线模块，不负责某一个算法。它定义板级端口，完成复位和按键消抖实例化，把键盘、Flash、临时密码、控制器、显示、蜂鸣器和 Pi UART 用内部 wire 连接，并通过 generate 参数决定是否综合 UART。

### Q2：状态机为什么分组合和时序两部分？

组合部分根据当前状态和输入计算 `next_state`；时序部分只在时钟上升沿把 `state` 更新为 `next_state`并更新寄存器。这样状态变化同步、易于时序分析，并避免输入毛刺直接改变状态。

### Q3：为什么密码写成 `16'h1234` 而不是十进制 1234？

它是四位 BCD：每个 4 位半字节保存一个十进制数字，`1/2/3/4`分别位于 `[15:12]`、`[11:8]`、`[7:4]`、`[3:0]`。便于键盘追加、退格和数码管逐位显示。

### Q4：第四次错误如何只触发一次相机？

只有从 USER 转入 ALARM 的时钟沿执行 `capture_start<=1`；每个普通周期开头默认清零，停留在 ALARM 时不再触发。因此报警持续，但拍照事件只有一拍。UART 模块再用 `link_waiting` 把这一拍锁存成长期请求。

### Q5：KEY2 为什么不取消拍照？

KEY2 只进入 `lock_controller` 并改变 `alarm_active/state`。`rpi_camera_link` 没有 KEY2 或 alarm_active 输入，只能由 ACK 或系统复位清除 `link_waiting`，所以已产生的请求不会被取消。

### Q6：UART 为什么空闲是 1？

标准异步 UART 约定空闲高电平，发送从低起始位开始，使接收器能用下降沿检测一帧开始。8-N-1 每帧还包含一个高停止位。

### Q7：FPGA 怎样知道 Pi 收到了请求？

Pi 收到 `ALARM\n` 后立即发送 `ACK\n`。FPGA UART 接收器按位恢复字节，ACK 状态机依次匹配 A、C、K、LF；完整匹配后清除 `link_waiting`。

### Q8：DONE 和 ERR 有什么作用？

Pi 会在抓拍成功/失败后发送 DONE/ERR，但当前 FPGA 未实现这两条消息的解析，所以它们不改变硬件状态，只能在树莓派侧日志/串口中观察。真正停止重发的是 ACK。

### Q9：为什么先 ACK 再拍照？

ACK 表示请求已接受，而不是工作完成。先 ACK 能在相机初始化和约 1.35 秒抓拍期间阻止 FPGA 每 500 ms 重发。完成结果再用 DONE/ERR报告。

### Q10：SPI 和 UART 的区别？

SPI 是同步主从总线，FPGA提供 SCLK 和 CS，W25Q64按 mode 0、MSB first 通信；UART 无共享时钟，双方约定波特率，通过起始/停止位同步，数据 LSB first。SPI 用于本地高速 Flash，UART用于板间低速事件。

### Q11：为什么双扇区比直接覆盖一个地址可靠？

擦除或写入过程中掉电可能破坏目标记录。交替写另一扇区，且只有回读、CRC和 COMMIT全部通过才切换当前密码，可以保留上一份有效记录用于恢复。

### Q12：LFSR 是真随机吗？

不是，是由固定反馈关系和种子产生的确定性伪随机序列。按键时刻决定采到哪个状态，足够课程设计临时访客密码，但不具备密码学安全性。

### Q13：为什么仿真 PASS 不等于实物一定通过？

RTL 仿真验证逻辑模型；实物还受管脚、极性、电压、亚稳态、机械抖动、Flash时序、UART接线、相机驱动等影响。必须再经过综合时序、DRC和板级联调。

### Q14：`wire` 和 `reg` 的区别？

`wire` 表示网络，由连续赋值或模块端口驱动；Verilog 的 `reg` 表示可在过程块中赋值的变量。是否综合成触发器取决于过程是否为时钟触发及赋值是否完整，而不是只看名字。

### Q15：阻塞赋值和非阻塞赋值为什么不能乱用？

组合逻辑用阻塞 `=` 让语句按顺序计算即时结果；同步时序用非阻塞 `<=` 模拟所有寄存器在同一时钟沿同时采样旧值。如果状态寄存器用阻塞赋值，仿真执行顺序可能产生与真实并行硬件不一致的行为。

---

## 19. 最终掌握路线

第一遍：只画出系统框图和九状态转移图，能讲完整报警链。
第二遍：打开 `password_lock_top.v`，遮住注释，逐行说出每根 wire 的来源和去向。
第三遍：打开 `rpi_camera_link.v`，手工画出消息发送、ACK匹配和重发三个小状态过程。
第四遍：在 Vivado打开 01、03、08、10、11 的 WDB，使用游标逐事件解释输入、采样沿和输出。
第五遍：自己把输入超时改成 5 秒、UART改成 57600，在分支/副本中同步修改 testbench并验证。
第六遍：断开 Pi 的 TX 回线观察 FPGA 重发，再恢复接线观察 ACK清除。
第七遍：不看本手册回答第 18 章问题，并能指出当前 UART testbench和协议的边界。

真正达到独立复现的标志，不是能背代码，而是面对任一功能都能沿以下链路定位：

```text
现实操作
 -> 顶层物理端口/XDC
 -> 输入同步与事件
 -> 控制器状态/计数器
 -> 模块握手或外设协议
 -> 可观察输出
 -> 对应 testbench 激励、断言和波形
```

只要这条链能从前向后讲，也能从异常现象反向定位文件和信号，就已经具备独立重建、修改和答辩解释能力。
