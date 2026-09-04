# HX7A75A FPGA 密码锁系统

这是一个面向数字系统课程设计的 FPGA 密码锁工程，目标开发板为 HX7A75A，器件为 Xilinx Artix-7 `xc7a75tfgg484-2`，开发环境为 Vivado 2023.2。

系统以 4×4 矩阵键盘完成密码输入，使用八位数码管和 LED 显示状态，并通过板载 W25Q64 保存管理员密码。连续四次输入错误后，系统进入只能由管理员按键解除的声光报警状态。工程还保留了 OV5640 连拍四帧并通过 HDMI 四宫格显示的可选设计。

## 当前交付状态

仓库中的 [`password_lock_top.bit`](password_lock_system/password_lock_top.bit) 是默认的矩阵键盘优先版，构建参数为 `ENABLE_CAMERA=0`。

| 功能 | 状态 |
|---|---|
| 矩阵键盘、数码管、LED、蜂鸣器 | 已通过 RTL 仿真和实机验证 |
| 密码输入、退格、取消、开锁及自动上锁 | 已通过 RTL 仿真和实机验证 |
| 连续四次错误报警、KEY2 专用解除 | 已通过 RTL 仿真和实机验证 |
| 管理员改密及 W25Q64 掉电保存 | 已通过 RTL 仿真和实机验证 |
| OV5640 初始化、四帧采集、HDMI 四宫格 | 已完成设计和对应 RTL 仿真，尚未连接摄像头和显示器实测 |

默认版最新构建结果：综合和实现均为 0 错误，DRC 违规为 0，WNS 为 `11.046 ns`，WHS 为 `0.093 ns`，CDC 报告显示所有路径均安全定时。

> 摄像头/HDMI 功能尚未完成硬件闭环验证，因此不应把它描述为实机通过。具体记录见[实机验证报告](password_lock_system/实机验证报告.md)。

## 快速使用

1. 按照[矩阵键盘接线说明](password_lock_system/矩阵键盘接线说明.md)连接 4×4 键盘；默认版不需要连接 OV5640。
2. 将板卡通过 JTAG 连接电脑，并确认 Vivado Hardware Manager 能识别 `xc7a75t`。
3. 直接在 Hardware Manager 下载 [`password_lock_top.bit`](password_lock_system/password_lock_top.bit)，或在仓库根目录运行：

   ```powershell
   & 'D:\Xilinx\Vivado\2023.2\bin\vivado.bat' -mode batch -source password_lock_system/scripts/program_fpga.tcl
   ```

4. 将 SW1 从低拨到高进入密码输入，输入四位密码后按 `A` 确认。首次使用或 Flash 中没有有效记录时，默认密码为 `1234`。

常用按键：

| 按键 | 功能 |
|---|---|
| `0`～`9` | 输入密码数字 |
| `A` | 确认；开锁状态下立即上锁 |
| `B` | 退格 |
| `C` | 取消并返回等待状态 |
| KEY1 | SW1 已拨高时进入管理员改密 |
| KEY2 | 解除报警并开始新的四次输入机会 |
| KEY4 | 系统复位 |

完整的接线、数码管提示、改密、报警和排障流程见[使用手册](password_lock_system/使用手册.md)。

## 构建与验证

默认版完整仿真、综合、实现和位流生成：

```powershell
.\password_lock_system\scripts\run_all.ps1
```

只运行默认版 RTL 仿真：

```powershell
.\password_lock_system\scripts\run_all.ps1 -SkipImplementation
```

启用 OV5640 设计及摄像头相关仿真：

```powershell
.\password_lock_system\scripts\run_all.ps1 -EnableCamera
```

也可以直接在 Vivado Tcl Console 中运行：

```tcl
source password_lock_system/scripts/create_project.tcl
source password_lock_system/scripts/build_all.tcl
```

构建成功后，新的位流会复制到 `password_lock_system/password_lock_top.bit`。Vivado 2023.2 在 Windows 上偶尔会在 XSim 输出 `PASS tb_*` 和 `$finish` 后延迟退出；应同时检查各测试的 `PASS` 标记和批处理最终退出状态。

## 目录结构

```text
.
├─ password_lock_system/
│  ├─ rtl/                  # Verilog RTL
│  ├─ sim/                  # SystemVerilog 测试平台与 Flash 模型
│  ├─ constraints/          # HX7A75A 管脚和时序约束
│  ├─ scripts/              # 建工程、测试、构建和下载脚本
│  ├─ third_party/rgb2dvi/  # HDMI TMDS 编码模块及其许可证
│  ├─ vivado/               # 可直接打开的 Vivado 工程入口
│  ├─ password_lock_top.bit # 默认版可下载位流
│  ├─ 使用手册.md
│  ├─ 矩阵键盘接线说明.md
│  └─ 实机验证报告.md
├─ 技术文档及例程/           # 开发板资料与外设参考工程
├─ 课件/                     # 课程资料
└─ 数字系统课程设计-题目新.docx
```

Vivado 的缓存、运行目录、日志和本地验证临时目录已通过 `.gitignore` 排除，不属于交付文件。第三方 `rgb2dvi` 模块的来源版本与许可证分别见 [`UPSTREAM_COMMIT.txt`](password_lock_system/third_party/rgb2dvi/UPSTREAM_COMMIT.txt) 和 [`LICENSE.txt`](password_lock_system/third_party/rgb2dvi/LICENSE.txt)。

## 设计说明

- 默认参数 `ENABLE_CAMERA=0` 会在综合时移除摄像头初始化、采集和四帧 BRAM，并把摄像头控制脚保持在安全静止状态。
- `ENABLE_CAMERA=1` 会加入摄像头时钟约束及 OV5640 数据路径；使用前必须复核摄像头模块供电、排线方向和 HDMI-B 接口。
- W25Q64 使用双日志记录和回读校验；两份记录都无效时回退到默认密码 `1234`。
- 实机板上蜂鸣器 P20 已确认是高电平使能，工程以实测极性为准。
