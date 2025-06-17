# Contributing to Macan

I'm not really that strict when it comes to these guidelines.
So if you have something you can contribute, shoot a PR my way.
I'll take a look at it, and if it feels like a good addition, let's incorporate it.

Cheers!

## Quick Start for Developers

### Prerequisites
- Neovim 0.7+ with Lua support
- LLVM tools (`llvm-mca`, `clang`/`clang++`)
- Git
- A C project with `compile_commands.json` for testing

### Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/aelobdog/macan.nvim.git
   cd macan.nvim
   ```

2. **Install for development**:
   ```bash
   # Create a symlink in your Neovim config
   ln -s $(pwd) ~/.local/share/nvim/site/pack/dev/start/macan.nvim
   ```

3. **Restart Neovim** and test:
   ```vim
   :lua require('macan').setup()
   :MacanHelp
   ```

## Project Structure

```
macan.nvim/
├── lua/macan/
│   ├── init.lua                # Main plugin entry point and commands
│   ├── config.lua              # Configuration management
│   ├── llvm_mca.lua            # LLVM-MCA integration and parsing
│   ├── dependency_analysis.lua # Instruction dependency analysis
│   ├── live_update.lua         # Live update functionality
│   ├── output.lua              # Output display and formatting
│   ├── markers.lua             # Start/end marker management
│   ├── compile_commands.lua    # compile_commands.json parsing
│   ├── compile_flags_ui.lua    # Custom compile flags UI
│   └── asmgen.lua              # Assembly generation
├── plugin/
│   └── macan.vim               # Vim plugin registration
├── README.md                   # User documentation
├── CHANGELOG.md                # Version history
├── CONTRIBUTING.md             # This file
└── LICENSE                     # MIT license
```

## Architecture Overview

### Core Components

1. **init.lua** - Plugin initialization and command definitions
2. **llvm_mca.lua** - LLVM-MCA tool integration and output parsing
3. **dependency_analysis.lua** - Instruction dependency detection engine
4. **output.lua** - Display formatting and window management
5. **live_update.lua** - Automatic analysis triggers and debouncing

### Data Flow

```
C Source File → Markers → Assembly Generation → LLVM-MCA → Parsing → Dependency Analysis → Display
     ↑                                                                                        ↓
   Live Updates ←───────────────────────────────────────────────────────────────────── User Interaction
```

## Areas for Contribution

- **More CPU architectures**: ARM, RISC-V support
- **Assembly syntax**: Intel syntax improvements
- **Performance**: Optimize dependency analysis
- **Error handling**: Better error messages and recovery
- **Testing**: Automated test suite
- **UI improvements**: Better visual feedback
- **Language support**: C++ templates, inline assembly
- **Export features**: Save analysis results
- **Themes**: Customizable highlighting colors
- **Plugins**: Integration with other Neovim plugins
