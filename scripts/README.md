# Terminal Vivado workflow

`fpga.cmd` is the Windows terminal entry point for routine FPGA build/program
cycles. It launches `fpga.ps1` with a process-local execution-policy bypass,
which avoids changing the machine-wide PowerShell policy. The PowerShell
wrapper invokes Vivado in batch mode; the Vivado IDE is not required.

## Commands

```powershell
# Program artifacts/bitstreams/optical_dsp_top.bit.
.\scripts\fpga.cmd program

# Program an explicit image.
.\scripts\fpga.cmd program -Bitstream C:\path\to\image.bit

# Override Vivado discovery or the expected FPGA part pattern.
.\scripts\fpga.cmd program `
  -Bitstream C:\path\to\image.bit `
  -VivadoPath C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat `
  -ExpectedPart "*xc7a100t*"

# Show the exact command without starting Vivado or touching hardware.
.\scripts\fpga.cmd program -Bitstream C:\path\to\image.bit -DryRun

# Available after the first design adds scripts/build_bitstream.tcl.
.\scripts\fpga.cmd build
.\scripts\fpga.cmd build-program

# Build the Milestone 06 XADC bring-up image.
.\scripts\fpga.cmd build `
  -BuildScript scripts\build_xadc_bringup.tcl

# Program the already-built Milestone 06 image.
.\scripts\fpga.cmd program `
  -Bitstream artifacts\bitstreams\xadc_bringup_top.bit

# Build the Milestone 07 capture/UART image.
.\scripts\fpga.cmd build `
  -BuildScript scripts\build_capture_uart_bringup.tcl

# Program the already-built Milestone 07 image.
.\scripts\fpga.cmd program `
  -Bitstream artifacts\bitstreams\capture_uart_bringup_top.bit
```

`build-program` completes the batch build first and contacts hardware only if
Vivado exits successfully. Build support is intentionally gated until a real
top-level design and constraints exist; no placeholder RTL/project was created
during planning.

## Vivado discovery order

1. `-VivadoPath <full executable path>`
2. the `VIVADO_BIN` environment variable
3. `vivado.bat` or `vivado` on `PATH`
4. installations below `C:\AMDDesignTools` and `C:\Xilinx\Vivado`

The resolved executable and every invoked step are printed. Timestamped Vivado
logs and journals are written to `artifacts/logs/`.

## Safety behavior

The programming helper refuses to proceed unless:

- the bitstream exists and has a `.bit` extension;
- the JTAG hardware server can be reached; and
- exactly one attached device matches `-ExpectedPart`.

It does not silently select the first device in an ambiguous JTAG chain. The
default part glob targets the Arty A7-100T. Change it only after the project
plan and board target have been deliberately revised.

The script verifies the device part, assigns `PROGRAM.FILE`, programs the FPGA,
refreshes the device, prints the configuration status, and propagates any
Vivado failure as a nonzero terminal exit.
