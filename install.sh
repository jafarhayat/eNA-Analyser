#!/bin/bash

# eNA 12S Pipeline v3.0 - Installation Script
# Bulletproof dependency installation with comprehensive checking

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     eDNA 12S Pipeline v3.0 - Installation Script          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="edna-pipeline"

echo -e "${BLUE}📁 Installation directory: $INSTALL_DIR${NC}"
echo ""

# ============================================================================
# Step 1: Check for conda
# ============================================================================
echo -e "${BLUE}Step 1/5: Checking for conda...${NC}"

if ! command -v conda &> /dev/null; then
    echo -e "${RED}❌ Conda not found!${NC}"
    echo ""
    echo -e "${YELLOW}Conda is required to install dependencies.${NC}"
    echo "Please install Miniconda from:"
    echo "  https://docs.conda.io/en/latest/miniconda.html"
    echo ""
    echo "After installation, run this script again."
    exit 1
fi

CONDA_VERSION=$(conda --version | awk '{print $2}')
echo -e "${GREEN}✅ Conda found: v$CONDA_VERSION${NC}"
echo ""

# ============================================================================
# Step 2: Check if environment exists
# ============================================================================
echo -e "${BLUE}Step 2/5: Checking for existing environment...${NC}"

if conda env list | grep -q "^$ENV_NAME "; then
    echo -e "${YELLOW}⚠️  Environment '$ENV_NAME' already exists${NC}"
    echo ""
    read -p "Remove and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "  🗑️  Removing old environment..."
        conda env remove -n "$ENV_NAME" -y
        echo -e "${GREEN}  ✅ Old environment removed${NC}"
    else
        echo "  Using existing environment"
    fi
else
    echo "  No existing environment found"
fi
echo ""

# ============================================================================
# Step 3: Create/update conda environment
# ============================================================================
echo -e "${BLUE}Step 3/5: Creating conda environment...${NC}"
echo "  This may take 5-10 minutes on first installation"
echo ""

if conda env list | grep -q "^$ENV_NAME "; then
    echo "  Environment exists, updating dependencies..."
    conda env update -n "$ENV_NAME" -f "$INSTALL_DIR/environment.yml" --prune
else
    echo "  Creating new environment..."
    conda env create -f "$INSTALL_DIR/environment.yml"
fi

echo ""
echo -e "${GREEN}✅ Conda environment ready${NC}"
echo ""

# ============================================================================
# Step 4: Install DADA2 (BiocManager)
# ============================================================================
echo -e "${BLUE}Step 4/5: Installing DADA2...${NC}"

# Check if already installed
if conda run -n "$ENV_NAME" R --slave --quiet -e "library(dada2)" 2>/dev/null; then
    echo -e "${GREEN}✅ DADA2 already installed${NC}"
else
    echo "  Installing DADA2 via BiocManager..."
    conda run -n "$ENV_NAME" R --slave --quiet << 'RCODE'
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager", repos="http://cran.r-project.org")
BiocManager::install("dada2", update = FALSE, ask = FALSE)
cat("DADA2 installation complete\n")
RCODE
    
    # Verify installation
    if conda run -n "$ENV_NAME" R --slave --quiet -e "library(dada2)" 2>/dev/null; then
        echo -e "${GREEN}✅ DADA2 installed successfully${NC}"
    else
        echo -e "${RED}❌ DADA2 installation failed${NC}"
        echo "  Try manually: conda activate $ENV_NAME; R"
        echo "  Then in R: BiocManager::install('dada2')"
        exit 1
    fi
fi
echo ""

# ============================================================================
# Step 5: Verify all tools
# ============================================================================
echo -e "${BLUE}Step 5/5: Verifying installation...${NC}"

ALL_GOOD=true

# Check each required tool
REQUIRED_TOOLS=("trimmomatic" "flash" "cutadapt" "blastn" "makeblastdb" "Rscript" "vsearch")

for tool in "${REQUIRED_TOOLS[@]}"; do
    if conda run -n "$ENV_NAME" command -v "$tool" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $tool"
    else
        echo -e "  ${RED}✗${NC} $tool"
        ALL_GOOD=false
    fi
done

# Check R packages
echo ""
echo "  Checking R packages..."
R_PACKAGES=("dada2" "dplyr" "tidyr")

for pkg in "${R_PACKAGES[@]}"; do
    if conda run -n "$ENV_NAME" R --slave --quiet -e "library($pkg)" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} R: $pkg"
    else
        echo -e "  ${RED}✗${NC} R: $pkg"
        ALL_GOOD=false
    fi
done

echo ""

if [[ "$ALL_GOOD" == true ]]; then
    echo -e "${GREEN}✅ All dependencies verified${NC}"
else
    echo -e "${RED}❌ Some dependencies missing${NC}"
    echo "  Try recreating the environment: ./install.sh"
    exit 1
fi
echo ""

# ============================================================================
# Setup database (if files exist)
# ============================================================================
echo -e "${BLUE}Setting up database...${NC}"

# Check if database files exist
if ls "$INSTALL_DIR/Database"/*.fasta 1> /dev/null 2>&1 || ls "$INSTALL_DIR/Database"/*.fa 1> /dev/null 2>&1; then
    echo "  Found database FASTA file(s)"
    
    # Build BLAST database if needed
    for fasta in "$INSTALL_DIR/Database"/*.fasta "$INSTALL_DIR/Database"/*.fa; do
        if [[ -f "$fasta" ]]; then
            db_name="${fasta%.fasta}"
            db_name="${db_name%.fa}"
            
            if [[ ! -f "${db_name}_blast.nhr" ]]; then
                echo "  🔨 Building BLAST database for $(basename "$fasta")..."
                conda run -n "$ENV_NAME" makeblastdb \
                    -in "$fasta" \
                    -dbtype nucl \
                    -out "${db_name}_blast" \
                    2>/dev/null
                echo -e "  ${GREEN}✓${NC} BLAST database ready"
            else
                echo -e "  ${GREEN}✓${NC} BLAST database already exists"
            fi
        fi
    done
else
    echo -e "${YELLOW}⚠️  No database files found in Database/ directory${NC}"
    echo "  Please add your database files to: $INSTALL_DIR/Database/"
    echo "  Required files:"
    echo "    - *.fasta (or *.fa) - reference sequences"
    echo "    - *taxonomy*.csv - taxonomy mapping"
fi
echo ""

# Make scripts executable
echo "  Setting permissions..."
chmod +x "$INSTALL_DIR/edna_pipeline.sh"
chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Scripts are executable"
echo ""

# ============================================================================
# Final success message
# ============================================================================
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 Installation Completed Successfully! 🎉      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}NEXT STEPS:${NC}"
echo ""
echo "1. Activate the environment:"
echo -e "   ${YELLOW}conda activate $ENV_NAME${NC}"
echo ""
echo "2. Test the installation:"
echo -e "   ${YELLOW}./edna_pipeline.sh --help${NC}"
echo ""
echo "3. Run analysis:"
echo -e "   ${YELLOW}./edna_pipeline.sh -i /path/to/samples -o results -d Database/${NC}"
echo ""
echo -e "${CYAN}NEW IN v3.0:${NC}"
echo "  • --no-blast option for ASV-only analysis"
echo "  • --min-alignment parameter for better filtering"
echo "  • Improved primer removal with linked adapters"
echo "  • Better BLAST ID handling"
echo "  • Filtered and unfiltered output files"
echo ""
echo -e "${GREEN}Happy analyzing! 🧬${NC}"
echo ""
