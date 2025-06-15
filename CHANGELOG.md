# Changelog

All notable changes to the Macan LLVM-MCA Visualizer plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-06-15

### Added
- **Core LLVM-MCA Integration**
  - LLVM-MCA detection and validation
  - Automatic parsing of LLVM-MCA timeline reports
  - Integration with `compile_commands.json` for automatic compilation
  - Support for custom compile flags per file

- **Interactive Analysis Features**
  - Set start/end markers for precise code section analysis (`MacanSetStart`, `MacanSetEnd`)
  - Real-time instruction dependency analysis with timing awareness
  - Interactive cursor-based dependency highlighting
  - Assembly syntax detection (AT&T vs Intel)
  - Comprehensive x86-64 register aliasing support

- **Live Update System**
  - Automatic analysis on file save with configurable debouncing
  - Efficient throttling to prevent excessive computation
  - Toggle live updates with status display
  - Manual update triggering

- **Enhanced Output Display**
  - Dedicated split pane for LLVM-MCA output
  - Structured summary metrics display (IPC, throughput, cycles, etc.)
  - Interactive timeline visualization with dependency highlighting
  - Raw output viewing for debugging

- **Configuration Management**
  - Unified `MacanConfig` command with subcommands
  - CPU architecture setting with tab completion (`MacanSetMarch`)
  - Custom compile flags editing and management
  - Comprehensive setup function with sensible defaults

- **User Interface**
  - Streamlined command set (12 essential commands)
  - Comprehensive help system (`MacanHelp`)
  - Clean, modern output formatting without ASCII art
  - Status line integration for dependency information

### Commands Added
- `MacanRunMCA` - Run LLVM-MCA analysis manually
- `MacanSetStart` - Set analysis start point
- `MacanSetEnd` - Set analysis end point
- `MacanClearMarkers` - Clear start/end markers
- `MacanLiveToggle` - Toggle live updates
- `MacanShowRawOutput` - Show raw LLVM-MCA output
- `MacanCloseAnalysis` - Close analysis window
- `MacanEditCompileFlags` - Edit compile flags
- `MacanClearCustomFlags` - Clear custom compile flags
- `MacanSetMarch` - Set CPU architecture
- `MacanConfig` - Unified configuration management
- `MacanHelp` - Show help information

### Technical Features
- **Dependency Analysis Engine**
  - RAW (Read-After-Write) dependency detection
  - Timing-aware dependency analysis
  - Register aliasing for x86-64 architecture
  - Complex addressing mode support
  - Operand parsing for AT&T and Intel syntax

- **Compilation Pipeline**
  - Automatic .s file generation with LLVM_MCA markers
  - Temporary file management with cleanup
  - Error handling for compilation failures
  - Support for various compiler flags and architectures

- **Performance Optimizations**
  - Debounced analysis to prevent excessive CPU usage
  - Efficient parsing of LLVM-MCA output
  - Smart file watching for live updates
  - Minimal memory footprint

### Initial Release Notes
This is the first stable release of Macan, providing a complete LLVM-MCA integration for Neovim. The plugin has been designed specifically for C source files and provides real-time performance analysis with dependency visualization.

**Key Highlights:**
- Zero-configuration setup for projects with `compile_commands.json`
- Real-time dependency analysis with visual feedback
- Live updates that adapt to your development workflow
- Clean, intuitive command interface
- Comprehensive error handling and user feedback

**Compatibility:**
- Neovim 0.7+
- LLVM tools (llvm-mca, clang/clang++)
- Projects with compile_commands.json
- Tested on Linux and Windows (WSL)