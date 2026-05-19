# DanXi-nix

[![Nix Flake](https://img.shields.io/badge/Nix-Flake-blue.svg?logo=nixos&logoColor=white)](flake.nix)

This repository provides the independent, pure, and declarative **Nix/NixOS packaging** and **development environments** for **[DanXi](https://github.com/DanXi-Dev/DanXi)** — the all-rounded service app for Fudan University students.

---

## 🚀 Usage

Since this repository is fully powered by **Nix Flakes**, you can run, develop, or build DanXi directly without manual installation or pre-configuring Flutter/Android SDKs.

### 1. Run Directly (Linux Desktop)
Launch the latest compiled Linux desktop version of DanXi directly from GitHub:
```shell
nix run github:DanXi-Dev/DanXi-nix
```

### 2. Build from Source

The build outputs will be symlinked to the local `./result/` directory.

```shell
# Build Linux Desktop binary
nix build github:DanXi-Dev/DanXi-nix

# Build Android APK (Declarative Sandbox Build)
nix build github:DanXi-Dev/DanXi-nix#android
```

### 3. Development Shell

Enter a pure, reproducible development environment containing the exact Flutter SDK, Android SDK/Tools, and Linux native dependencies needed for DanXi:

```shell
# cd DanXi-Dev/DanXi

# Enter the default development shell
nix develop github:DanXi-Dev/DanXi-nix

# Alternative: Build Android APK inside the development shell environment
nix develop github:DanXi-Dev/DanXi-nix -c flutter build apk
```

---

## 🛠️ Integrate into NixOS Configuration

If you want to install DanXi permanently on your NixOS system via your system configuration flake:

### Step 1: Add to `flake.nix` Inputs

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  
  # Add DanXi-nix as an input
  dan-xi.url = "github:DanXi-Dev/DanXi-nix";
};
```

### Step 2: Add to packages

#### Add via `environment.systemPackages`

```nix
outputs = { nixpkgs, dan-xi, ... }: {
  nixosConfigurations.${host} = nixpkgs.lib.nixosSystem {
    modules = [
      ({ pkgs, ... }: {
        environment.systemPackages = [
          # Install the default Linux desktop package
          dan-xi.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
      })
    ];
  };
};
```

#### Add via `home.packages`

```nix
outputs = { nixpkgs, home-manager, dan-xi, ... }: {
  homeConfigurations.${user} = home-manager.lib.homeManagerConfiguration {
    modules = [
      ({ pkgs, ... }: {
        home.packages = [
          # Install the default Linux desktop package to user profile
          dan-xi.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
      })
    ];
  };
};
```

---

## 🔄 Maintenance & Updates

As a standalone package manager repository, keeping DanXi updated with the upstream repository is straightforward.

To update the tracked upstream commit of `DanXi` source code and bump the `flake.lock`:

```shell
nix flake update dan-xi-src
```

## 📄 License

This Nix packaging repository inherits the licensing of the main [DanXi](https://github.com/DanXi-Dev/DanXi) project.
