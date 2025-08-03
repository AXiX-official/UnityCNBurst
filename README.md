# UnityCNBurst

A tiny program wirte in zig to brute force unitycn's encrypted bundlefile.

## Getting the Executable

### Method 1: Download Prebuilt Binaries (Recommended)

Visit [Releases page](https://github.com/AXiX-official/UnityCNBurst/releases) to download prebuilt binaries for your system:


### Method 2: Build From Source (For Developers)

Ensure you have [Zig](https://ziglang.org/)(higher than 1.4.1) installed.

```bash
git clone https://github.com/AXiX-official/UnityCNBurst
cd UnityCNBurst
zig build -Doptimize=ReleaseFast
```

## Usage

### Basic Command

```bash
UnityCNBurst <bundle_file_path> <global_metadata.dat_path>
```

### Advanced Options

- `-r` : Generate raw hex key set from global-metadata.dat(will generate ascii keys only by default)

### Example

```bash
./UnityCNBurst "11501001.bundlefile" "global-metadata.dat"
Elapsed time: 0.008073 sec
Total keys checked: 187264
Keys per second: 23196333.457203023

Valid key found:
ASCII: Nightingale@2019
Hex: 4E69676874696E67616C654032303139
```