
# NeoApple2 - Apple2fpga的Xilinx Zynq移植版

Feng Zhou, 2021-7

[EN](README.md) | 中文

这是Stephen a. Edwards的Apple2fpga (http://www.cs.columbia.edu/~sedwards/apple2fpga/)在Xilinx Zynq平台上的移植。它在PYNQ-Z1 FPGA板上运行，可以模拟出一台Apple II+计算机。

主要功能，

 * 视频输出通过板载HDMI端口完成。
 * PS/2键盘输入。
 * 声音输出通过板载3.5mm单声道插座完成。
 * 单色/彩色模式切换。
 * MicroSD卡.nib格式软盘映像的加载。

![完成照片](doc/setup.jpg)

## 运行二进制包

你可以[下载二进制包](http://zhoufeng.net/neoapple2/)来运行，你下载的二进制包里有一个BOOT.BIN文件，这已经包括运行NeoApple2所需的所有内容了。但运行前，需要集齐以下硬件：

* [PYNQ-Z1](https://store.digilentinc.com/pynq-z1-python-productivity-for-zynq-7000-arm-fpga-soc/) FPGA板（淘宝上有）。
* [Pmod PS2](https://store.digilentinc.com/pmod-ps2-keyboard-mouse-connector/)连接键盘的适配器板（这个可能不好买，但自己用PS/2插座焊一个很容易）。
* PS/2键盘（不支持USB键盘）。
* MicroSD卡，用于保存软盘映像。
* 支持HDMI的显示器。
* 一根HDMI线。
* 一根MicroUSB线。
* 一台电脑，通过USB与Z1连接。
* 如果你需要声音，则还需要一根从Z1到音箱的3.5毫米音频线，或一个3.5毫米插头的耳机。

现在连接硬件：
1. 将**Pmod PS2**插入Z1上的PMODA插座的上层（PMOD插座分上下两层，各6针，需要插上面一层）。然后将PS/2键盘插入Pmod PS2。
2. 通过Z1上的HDMI OUT端口将Z1连接到您的显示器。
3. 将你的音箱线或耳机连接到Z1左边的音频插孔。
4. 用MicroUSB电缆连接Z1到你的电脑。
5. 切换JP4跳线（在板子左上角）到MicroSD位置。在此设置中，板子从MicroSD卡启动。
6. 用读卡器将MicroSD卡插入计算机。然后格式化为FAT32格式 (exFAT多半也是可以的)。然后将`BOOT.BIN`文件复制到根目录。
7. 将你拥有的任何Apple II软盘映像文件复制到MicroSD卡根目录下。[Internet Archive](https://archive.org/)有很多Apple II软件和游戏。我们只支持`.nib`格式，但[dsk2nib](https://github.com/slotek/dsk2nib)可以很方便地将`.dsk`, `.do`转换成`.nib`。

现在打开PYNQ Z1。**按键盘任意键或BTN0**。几秒钟后，你会看到“]”提示。

要加载磁盘映像，请在PC上打开任何串行控制台软件（例如[Putty](https://www.putty.org/)），连接到Z1（COM4或COM6）。然后可以操作命令行：

* `list`列出所有磁盘映像。

* `load <x>`加载软盘映像。

常见的Apple II命令，
```
CATALOG
PR#6
CALL -1184
LOAD
RUN
BRUN
```

## 从源代码编译

从源代码编译的简要说明：

* 安装Xilinx Vivado设计套件 - HLx版本 - 2020.2。然后安装[PYNQ-Z1 board files](https://github.com/cathalmccabe/pynq-z1_board_files)。
* 安装[Digilent IP库](https://github.com/Digilent/vivado-library)。
* 在`neoapple2/`中编译Vivado代码，以获得定义硬件“平台”的XSA文件。
  * 在Vivado tcl Shell中`source neoapple2/neoapple2.tcl`。创建实际的项目文件。
  * 双击打开生成的项目文件`neoapple2.xpr`，进入Vivado。
  * 点击“generate bitstream”(在左下角)来编译整个项目。
  * `File -> Export Hardware -> Include bitstream -> neoapple2.xsa`
  * `Tools -> Launch Vitis IDE`
* 在Vitis IDE中，编译`neoapple2ui`中的workspace来生成最终的SD卡引导映像，
  * 如果你还没在`neoapple2ui`工作区中，通过`File -> Switch workspace`打开它。
  * `File -> New -> Platform Project`，并将项目命名为`neoapple2`，对于"hardware specification"，选择上面生成的`neoapple2.xsa`。然后按“完成”。
  * `Project -> Build All`编译所有代码。如果一切顺利，您将在`neoapple2ui/neoapple2ui_system/Debug/sd_card/BOOT.BIN`中获得引导映像。

## 进一步的文档

系统的设计与实现请看[技术报告](doc/Porting_Apple2fpga.pdf)（英文）。

视频演示：

[![Youtube video](https://img.youtube.com/vi/H2rrs8nJgQQ/0.jpg)](https://www.youtube.com/watch?v=H2rrs8nJgQQ)

## 留言

请在[这里](https://github.com/zf3/neoapple2/issues/1)留言.
