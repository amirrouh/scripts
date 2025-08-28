#!/bin/bash

# FSI Environment Installation Script for Ubuntu Systems
# Installs OpenFOAM v2406, CalculiX 2.20, preCICE 3.1.2, and related adapters
# This script EXACTLY follows the Dockerfile implementation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Set LANG as in Dockerfile line 55
export LANG=C.UTF-8

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${PURPLE}===========================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}===========================================${NC}\n"
}

# Check if running as root (containers typically run as root)
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Script directory and assets
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/assets"

# Main function
main() {
    print_header "FSI Environment Installation (Dockerfile-compliant)"
    echo "This script will install (EXACTLY as per Dockerfile):"
    echo "  - OpenFOAM v2406"
    echo "  - CalculiX 2.20 with preCICE adapter"
    echo "  - preCICE 3.1.2"
    echo "  - PETSc 3.16.0"
    echo ""
    
    # Auto-confirm flag
    if [[ "$1" == "-y" ]] || [[ "$1" == "--yes" ]]; then
        print_status "Auto-confirm enabled"
    else
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    # Step 1: Update and install basic utilities (Dockerfile lines 11-16)
    print_header "Installing Dependencies"
    
    # Fix any dpkg issues first
    ${SUDO} dpkg --configure -a 2>/dev/null || true
    
    ${SUDO} apt update
    ${SUDO} apt upgrade -y
    ${SUDO} apt install -y \
        vim wget apt-transport-https flex make gcc g++ build-essential cmake openmpi-bin \
        python3-dev python3-pip libeigen3-dev libyaml-cpp-dev libboost-all-dev libxml2 \
        libxml2-dev libopenblas-dev liblapack-dev libarpack2-dev libspooles-dev git
    
    ${SUDO} apt install tmux -y
    
    # Step 2: Install PETSc (Dockerfile lines 18-26)
    print_header "Installing PETSc 3.16.0"
    
    pip3 install --break-system-packages numpy 2>/dev/null || pip3 install numpy
    
    cd /tmp
    wget http://ftp.mcs.anl.gov/pub/petsc/release-snapshots/petsc-3.16.0.tar.gz
    tar -xzf petsc-3.16.0.tar.gz
    cd petsc-3.16.0
    
    # Configure PETSc with proper PETSC_DIR for source
    export PETSC_DIR="$PWD"
    ./configure --prefix=/usr/local --with-mpi=1 \
        --with-blas-lib=/usr/lib/x86_64-linux-gnu/libopenblas.so \
        --with-lapack-lib=/usr/lib/x86_64-linux-gnu/liblapack.so
    
    make
    ${SUDO} make install
    
    # Set PETSc environment variables (Dockerfile lines 29-30)
    export PETSC_DIR="/usr/local"
    export PETSC_ARCH="arch-linux2-c-debug"
    
    # Step 3: Install preCICE (Dockerfile lines 32-39)
    print_header "Installing preCICE 3.1.2"
    
    cd /tmp
    git clone --branch v3.1.2 https://github.com/precice/precice.git
    cd precice
    mkdir build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DPETSC_DIR=/usr/local -DPETSC_ARCH=arch-linux2-c-debug ..
    make -j$(nproc)
    ${SUDO} make install
    
    # Step 4: Install OpenFOAM (Dockerfile lines 41-53)
    print_header "Installing OpenFOAM v2406"
    
    wget -q -O - https://dl.openfoam.com/add-debian-repo.sh | ${SUDO} bash
    ${SUDO} apt-get update
    ${SUDO} apt-get install -y openfoam2406-dev
    
    # Set up OpenFOAM environment
    mkdir -p /root/OpenFOAM/user-v2406
    cd /tmp
    wget https://sourceforge.net/projects/openfoam/files/v2406/ThirdParty-v2406.tgz
    ${SUDO} tar -xzf ThirdParty-v2406.tgz -C /usr/lib/openfoam/openfoam2406
    rm ThirdParty-v2406.tgz
    
    # Add to bashrc if not present
    if ! grep -q "openfoam2406/etc/bashrc" "$HOME/.bashrc"; then
        echo "source /usr/lib/openfoam/openfoam2406/etc/bashrc" >> "$HOME/.bashrc"
    fi
    
    # Add SHELL exports (Dockerfile lines 52-53)
    ${SUDO} bash -c 'echo "export SHELL=/bin/bash" >> /usr/lib/openfoam/openfoam2406/etc/bashrc'
    ${SUDO} bash -c 'echo "export WM_SHELL=bash" >> /usr/lib/openfoam/openfoam2406/etc/bashrc'
    
    # Step 5: Build OpenFOAM adapter (Dockerfile lines 57-64)
    print_header "Installing OpenFOAM-preCICE Adapter"
    
    ${SUDO} mkdir -p /usr/lib/openfoam/openfoam2406/OpenFOAM-adapter
    ${SUDO} wget https://github.com/precice/openfoam-adapter/releases/download/v1.3.1/openfoam-adapter-v1.3.1-OpenFOAMv1812-v2406-newer.tar.gz -O /usr/lib/openfoam/openfoam2406/OpenFOAM-adapter/openfoam-adapter.tar.gz
    ${SUDO} tar -xzf /usr/lib/openfoam/openfoam2406/OpenFOAM-adapter/openfoam-adapter.tar.gz -C /usr/lib/openfoam/openfoam2406/OpenFOAM-adapter
    ${SUDO} rm /usr/lib/openfoam/openfoam2406/OpenFOAM-adapter/openfoam-adapter.tar.gz
    
    cd /usr/lib/openfoam/openfoam2406/OpenFOAM-adapter
    ADAPTER_DIR=$(${SUDO} find . -mindepth 1 -maxdepth 1 -type d)
    cd "$ADAPTER_DIR"
    ${SUDO} bash -c "source /usr/lib/openfoam/openfoam2406/etc/bashrc && chmod +x Allwmake && ./Allwmake"
    
    # Step 6: Install CalculiX and adapter (Dockerfile lines 66-73)
    print_header "Installing CalculiX 2.20 with preCICE Adapter"
    
    cd /root
    wget http://www.dhondt.de/ccx_2.20.src.tar.bz2
    tar xvjf ccx_2.20.src.tar.bz2
    wget https://github.com/precice/calculix-adapter/archive/refs/heads/master.tar.gz
    tar -xzf master.tar.gz
    cd calculix-adapter-master
    sed -i 's|^FFLAGS = -Wall -O3 -fopenmp $(INCLUDES)|FFLAGS = -Wall -O3 -fopenmp -fallow-argument-mismatch $(INCLUDES)|' Makefile
    make
    
    # Copy additional utilities from assets if available
    if [ -d "$ASSETS_DIR" ]; then
        if [ -f "$ASSETS_DIR/frdToVTKConverter.exe" ]; then
            print_status "Installing frdToVTKConverter.exe utility..."
            cp "$ASSETS_DIR/frdToVTKConverter.exe" /root/calculix-adapter-master/bin/
        fi
        
        if [ -f "$ASSETS_DIR/unical3" ]; then
            print_status "Installing unical3 utility..."
            cp "$ASSETS_DIR/unical3" /root/calculix-adapter-master/bin/
            chmod +x /root/calculix-adapter-master/bin/unical3
        fi
    fi
    
    # Step 7: Install visualization tools (Dockerfile lines 75-78)
    print_header "Installing Visualization Tools"
    
    ${SUDO} apt update -y
    ${SUDO} apt install libxrender1 libxext6 -y
    # Handle different package names for Ubuntu versions
    ${SUDO} apt install libgl1 libglx0 -y 2>/dev/null || \
        ${SUDO} apt install libgl1-mesa-glx libglx-mesa0 -y
    
    pip3 install --break-system-packages ccx2paraview vtk 2>/dev/null || \
        pip3 install ccx2paraview vtk
    
    # Step 8: Set up environment (Dockerfile line 81)
    print_header "Setting Up Environment"
    
    # Create environment script
    cat > "$HOME/fsi_env.sh" << 'EOF'
#!/bin/bash
# FSI Environment Setup (matching Dockerfile)

# PETSc environment (lines 29-30)
export PETSC_DIR="/usr/local"
export PETSC_ARCH="arch-linux2-c-debug"

# OpenFOAM environment
source /usr/lib/openfoam/openfoam2406/etc/bashrc 2>/dev/null

# CalculiX adapter PATH (line 81)
export PATH="/root/calculix-adapter-master/bin:$PATH"

# preCICE library path
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# LANG (line 55)
export LANG=C.UTF-8

echo "FSI environment loaded!"
EOF
    
    chmod +x "$HOME/fsi_env.sh"
    
    # Add to bashrc if not present
    if ! grep -q "fsi_env.sh" "$HOME/.bashrc"; then
        echo "[ -f $HOME/fsi_env.sh ] && source $HOME/fsi_env.sh" >> "$HOME/.bashrc"
    fi
    
    print_header "Installation Complete!"
    print_success "FSI environment installed successfully (Dockerfile-compliant)!"
    echo ""
    echo "To use the environment:"
    echo "  1. Restart terminal or run: source ~/.bashrc"
    echo "  2. Or manually source: source $HOME/fsi_env.sh"
    echo ""
    echo "Installed components:"
    echo "  ✓ PETSc 3.16.0 at /usr/local"
    echo "  ✓ preCICE 3.1.2 at /usr/local"
    echo "  ✓ OpenFOAM v2406 at /usr/lib/openfoam/openfoam2406"
    echo "  ✓ CalculiX 2.20 with adapter at /root/calculix-adapter-master"
    
    # Comprehensive cleanup of temporary and redundant files
    print_header "Cleaning Up"
    print_status "Removing temporary build files..."
    
    # Clean PETSc build files
    rm -rf /tmp/petsc-3.16.0*
    
    # Clean preCICE build files
    rm -rf /tmp/precice
    
    # Clean CalculiX source archives
    rm -f /root/ccx_2.20.src.tar.bz2
    rm -f /root/master.tar.gz
    
    # Clean CalculiX source directory (keep only adapter)
    rm -rf /root/CalculiX
    
    # Clean apt cache to save space
    ${SUDO} apt-get clean
    ${SUDO} apt-get autoremove -y
    
    # Remove build dependencies if desired (commented out by default)
    # ${SUDO} apt-get remove --purge -y build-essential cmake
    
    print_success "Cleanup completed!"
}

# Handle interruption
trap 'print_error "Installation interrupted"; exit 1' INT TERM

# Run main
main "$@"