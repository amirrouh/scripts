# FSI Environment Installer

Installs OpenFOAM v2406, CalculiX 2.20, preCICE 3.1.2, and PETSc for fluid-structure interaction simulations.

## Installation

```bash
chmod +x setup_cfd.sh
./setup_cfd.sh -y
```

## Requirements
- Ubuntu 22.04/24.04
- 10GB disk space
- Internet connection

## Components
- **OpenFOAM**: CFD solver
- **CalculiX**: FEA solver with preCICE adapter  
- **preCICE**: Coupling library
- **PETSc**: Scientific computation toolkit

Installation takes ~30-45 minutes. Environment auto-loads on terminal restart.