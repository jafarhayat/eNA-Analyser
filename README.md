# Pipline-EVNA-eNA
# eDNA ASV Pipeline Package Creator

🚀 **Automated script to create a complete, production-ready eDNA analysis pipeline package for GitHub distribution**

This script generates a fully-integrated, working eDNA ASV (Amplicon Sequence Variant) analysis pipeline with comprehensive species identification, method comparison, and customizable parameters.

---

## 📋 Table of Contents

- [Overview](#overview)
- [What This Script Does](#what-this-script-does)
- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Usage](#usage)
- [Generated Pipeline Features](#generated-pipeline-features)
- [Pipeline Usage Examples](#pipeline-usage-examples)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## 🎯 Overview

This is a **package creator script** that generates a complete, working eDNA ASV analysis pipeline. Think of it as a "pipeline factory" - you run this script once, and it creates an entire GitHub-ready pipeline package that can be distributed and used by others.

### What Gets Created

Running this script generates a complete pipeline package named `eDNA-ASV-Pipeline/` with:
- 🧬 Fully working analysis pipeline from raw reads to species identification
- 📊 Automated BLAST taxonomy assignment with custom databases
- 🔬 Optional eDNA vs EV.DNA method comparison
- ⚙️ Configurable parameters (identity thresholds, primers, threading)
- 📈 Comprehensive output reports (6+ analysis files)
- 🐳 One-command conda installation
- 📚 Complete documentation

---

## 🚀 What This Script Does

This creator script automatically generates:

### 1. **Main Pipeline Script** (`eDNA_pipeline.sh`)
- Complete working pipeline with argument parsing
- Database auto-detection (MIDORI2/NCBI/custom)
- Three analysis modes: full, asv-only, taxonomy-only
- All custom features integrated

### 2. **Pipeline Functions** (`scripts/pipeline_functions.sh`)
- Real preprocessing (Trimmomatic → FLASH → Cutadapt)
- DADA2 ASV calling with chimera removal
- BLAST taxonomy assignment
- Comprehensive R-based species analysis
- Method comparison (eDNA vs EV.DNA)

### 3. **Installation System** (`install.sh`)
- Conda environment setup
- DADA2 installation via BiocManager
- Automatic BLAST database building
- Dependency verification

### 4. **Documentation**
- Main README with usage examples
- Installation guide
- Feature descriptions
- Output file explanations

### 5. **Supporting Files**
- Conda environment specification (`environment.yml`)
- Configuration templates
- Directory structure

---

## 🏁 Quick Start

### Step 1: Run the Package Creator

```bash
# Make the creator script executable
chmod +x create_edna_pipeline_package.sh

# Run it to generate the pipeline package
./create_edna_pipeline_package.sh
```

**Output:**
```
🚀 Creating Complete GitHub-Ready eDNA ASV Pipeline Package
============================================================
📁 Creating package structure: eDNA-ASV-Pipeline
  ✅ Package directory structure created
📝 Creating fully working main eDNA pipeline script...
  ✅ Main pipeline script created
📝 Creating comprehensive working pipeline functions...
  ✅ Comprehensive working pipeline functions created
...
✅ Complete GitHub-ready eDNA ASV Pipeline package created!
```

### Step 2: Install the Generated Pipeline

```bash
cd eDNA-ASV-Pipeline
./install.sh
```

### Step 3: Use the Pipeline

```bash
conda activate edna-pipeline
./eDNA_pipeline.sh -i raw_data --database ncbi
```

---

## 📦 Requirements

### For Running the Package Creator Script
- **Bash shell** (Linux, macOS, or Windows WSL)
- **Write permissions** in current directory
- ~50MB free disk space

### For Using the Generated Pipeline
- **Conda/Miniconda** (for environment management)
- **8GB+ RAM** (16GB recommended)
- **10GB+ storage** (for databases and analysis)
- **Linux/macOS** (or Windows WSL)

---

## 💻 Usage

### Basic Usage (Create Package)

```bash
# Simply run the script
./create_edna_pipeline_package.sh
```

### What Happens

1. **Removes old package** (if exists)
2. **Creates directory structure**:
   ```
   eDNA-ASV-Pipeline/
   ├── eDNA_pipeline.sh              # Main pipeline script
   ├── install.sh                    # Installation script
   ├── environment.yml               # Conda environment
   ├── README.md                     # Complete documentation
   ├── scripts/
   │   └── pipeline_functions.sh    # Core functions
   ├── Database/                     # For reference databases
   ├── docs/                         # Documentation
   ├── config/                       # Configuration files
   └── test_data/                    # Test datasets
   ```

3. **Generates all scripts** with full functionality
4. **Creates documentation**
5. **Makes everything executable**

### After Package Creation

```bash
# Navigate to the created package
cd eDNA-ASV-Pipeline

# Copy your database files
cp /path/to/your/database.fasta Database/
cp /path/to/your/taxonomy.csv Database/

# Initialize git repository (optional)
git init
git add .
git commit -m "Initial commit: Complete eDNA ASV Pipeline"

# Push to GitHub (optional)
git remote add origin https://github.com/yourusername/eDNA-ASV-Pipeline.git
git push -u origin main
```

---

## 🎯 Generated Pipeline Features

The created pipeline includes these working features:

### 🧬 Complete Analysis Workflow
- **Quality filtering**: Trimmomatic (adapter removal, quality trimming)
- **Read merging**: FLASH (paired-end read merging)
- **Primer removal**: Cutadapt (primer trimming)
- **ASV calling**: DADA2 (error correction, denoising, chimera removal)
- **Taxonomy assignment**: BLAST (against MIDORI2/NCBI/custom databases)
- **Comprehensive analysis**: R-based species identification and reporting

### 🗄️ Database Support
- **Built-in**: MIDORI2 (marine) and NCBI (comprehensive)
- **Custom**: Your own reference databases
- **Auto-detection**: Finds and configures databases automatically
- **Flexible**: `--custom-db` flag for any database directory

### 🔬 Method Comparison
- **Automatic detection**: Identifies eDNA vs EV.DNA samples
- **Optional**: Use `--single-method` to skip comparison
- **Comprehensive**: Species presence/absence, abundance, fold changes

### ⚙️ Configurable Parameters
```bash
--min-identity NUM        # BLAST identity threshold (default: 80%)
--database midori|ncbi    # Force specific database
--custom-db DIR           # Use custom database
--single-method           # Skip eDNA/EV.DNA comparison
--threads NUM             # Parallel processing (default: 4)
--forward-primer SEQ      # Custom forward primer
--reverse-primer SEQ      # Custom reverse primer
```

### 📊 Output Files (7+ Reports)
1. **ASV_taxonomy_assignments.csv** - Complete taxonomy per ASV
2. **species_abundance_summary.csv** - Species abundance and diversity
3. **sample_by_sample_taxonomy.csv** - Detailed sample breakdown
4. **method_species_comparison.csv** - eDNA vs EV.DNA comparison
5. **taxonomy_confidence_report.csv** - Quality assessment
6. **location_diversity_summary.csv** - Location-based diversity
7. **fish_species_summary.csv** - Fish-specific analysis (when detected)

---

## 📖 Pipeline Usage Examples

Once you've created and installed the pipeline:

### Example 1: Basic Full Analysis

```bash
# Auto-detect database and run complete analysis
./eDNA_pipeline.sh -i /path/to/raw_data --database ncbi
```

**Input:** Raw sequencing files (`.R1.fq.gz` + `.R2.fq.gz`)  
**Output:** 7 comprehensive analysis reports in `final_reports/`

### Example 2: Single Method Analysis

```bash
# Skip eDNA/EV.DNA comparison, treat all samples equally
./eDNA_pipeline.sh -i raw_data --single-method
```

**Use when:** You don't have eDNA/EV.DNA method comparison

### Example 3: High Stringency

```bash
# Require 95% identity for species assignment
./eDNA_pipeline.sh -i raw_data --database midori --min-identity 95
```

**Use when:** You want highly confident species identifications

### Example 4: Custom Database

```bash
# Use your own reference database
./eDNA_pipeline.sh -i raw_data --custom-db /path/to/my_database
```

**Requirements:** 
- `my_database/sequences.fasta`
- `my_database/taxonomy.csv`

### Example 5: Taxonomy Only Mode

```bash
# Analyze existing ASV data
./eDNA_pipeline.sh \
    -s existing_asv_sequences.fasta \
    -t existing_asv_table.csv \
    --mode taxonomy-only \
    --min-identity 90
```

**Use when:** You already have ASV data from another source

### Example 6: Custom Primers

```bash
# Use different primers (e.g., COI instead of 12S)
./eDNA_pipeline.sh -i raw_data \
    --forward-primer GTCGGTAAAACTCGTGCCAGC \
    --reverse-primer CATAGTGGGGTATCTAATCCCAGTTTGT \
    --custom-db coi_database
```

---

## 🎨 Customization

### Modify the Package Creator

You can customize what gets created by editing the creator script:

#### Change Default Parameters

```bash
# In the main script, modify:
DEFAULT_MIN_IDENTITY=80.0    # Change to 85.0 or 90.0
DEFAULT_THREADS=4            # Change to 8 or 16
DEFAULT_FORWARD_PRIMER="..."  # Change to your primer
```

#### Add Custom Databases

```bash
# After creation, add your databases:
cp your_database.fasta eDNA-ASV-Pipeline/Database/
cp your_taxonomy.csv eDNA-ASV-Pipeline/Database/
```

#### Modify Analysis Scripts

All analysis scripts are generated as readable code. After package creation, you can modify:
- `scripts/pipeline_functions.sh` - Core processing logic
- `scripts/run_dada2.R` - DADA2 parameters (created during runtime)
- `scripts/comprehensive_taxonomy_analysis.R` - Taxonomy analysis (created during runtime)

---

## 🔍 Detailed Breakdown

### Package Creator Script Structure

```
create_edna_pipeline_package.sh
├── Package structure creation
├── Main pipeline script generation
│   ├── Argument parsing
│   ├── Configuration defaults
│   └── Mode selection logic
├── Pipeline functions generation
│   ├── Dependency checking
│   ├── Database detection
│   ├── Sample preparation
│   ├── Preprocessing (Trimmomatic/FLASH/Cutadapt)
│   ├── ASV calling (DADA2)
│   ├── Taxonomy assignment (BLAST + R analysis)
│   └── Reporting functions
├── Installation script generation
│   ├── Conda environment setup
│   ├── DADA2 installation
│   └── Database preparation
├── Documentation generation
│   ├── Main README
│   ├── Installation guide
│   └── Usage examples
└── Environment specification
```

### Generated Pipeline Workflow

```
Raw Reads (.R1.fq.gz, .R2.fq.gz)
    ↓
[1] Quality Filtering (Trimmomatic)
    ↓
[2] Read Merging (FLASH)
    ↓
[3] Primer Removal (Cutadapt)
    ↓
[4] ASV Calling (DADA2)
    ├── Error learning
    ├── Dereplication
    ├── ASV inference
    └── Chimera removal
    ↓
[5] Taxonomy Assignment (BLAST)
    ↓
[6] Comprehensive Analysis (R)
    ├── Species identification
    ├── Method comparison
    ├── Diversity analysis
    └── Confidence assessment
    ↓
Output: 7+ comprehensive reports
```

---

## 🛠️ Troubleshooting

### Package Creator Issues

**Problem**: Script won't run
```bash
# Solution: Make it executable
chmod +x create_edna_pipeline_package.sh
```

**Problem**: Permission denied
```bash
# Solution: Run from a directory where you have write permissions
cd ~/Documents
./create_edna_pipeline_package.sh
```

**Problem**: Package already exists
```bash
# Solution: Script automatically removes old version
# Or manually: rm -rf eDNA-ASV-Pipeline
```

### Generated Pipeline Issues

**Problem**: Conda environment creation fails
```bash
# Solution: Update conda first
conda update -n base conda
cd eDNA-ASV-Pipeline
./install.sh
```

**Problem**: DADA2 installation fails
```bash
# Solution: Install manually via R
conda activate edna-pipeline
R
> BiocManager::install("dada2")
```

**Problem**: Database not found
```bash
# Solution: Check database files exist
ls Database/*.fasta
ls Database/*.csv

# Required structure:
# Database/database_name.fasta
# Database/database_name_taxonomy.csv
```

**Problem**: No samples detected
```bash
# Solution: Check file naming
# Expected: *.R1.fq.gz and *.R2.fq.gz
# Or: sample_folders/sample_name/*.R1.fq.gz
```

---

## 📊 Input Data Formats

The generated pipeline accepts:

### Folder Structure (Recommended)
```
raw_data/
├── X.eDNA_14/
│   ├── X.eDNA_14_S12345.R1.fq.gz
│   └── X.eDNA_14_S12345.R2.fq.gz
├── X.EV.DNA_14/
│   ├── X.EV.DNA_14_S67890.R1.fq.gz
│   └── X.EV.DNA_14_S67890.R2.fq.gz
└── YD_eDNA_4.1/
    ├── YD_eDNA_4.1_S11111.R1.fq.gz
    └── YD_eDNA_4.1_S11111.R2.fq.gz
```

### Flat File Structure
```
raw_data/
├── sample1.R1.fq.gz
├── sample1.R2.fq.gz
├── sample2.R1.fq.gz
├── sample2.R2.fq.gz
```

### Database Files
```
Database/
├── ncbi_12s.fasta           # Reference sequences
├── ncbi_taxonomy.csv        # Taxonomy information
├── midori_amplicons.fasta   # Alternative reference
└── midori_taxonomy.csv      # Alternative taxonomy
```

**Taxonomy CSV Format:**
```csv
Accession,Species,Genus,Family,Database
AB123456,Gadus morhua,Gadus,Gadidae,NCBI
AB123457,Salmo salar,Salmo,Salmonidae,NCBI
```

---

## 🧪 Testing the Generated Pipeline

After creating the package:

```bash
# 1. Install
cd eDNA-ASV-Pipeline
./install.sh

# 2. Test help
conda activate edna-pipeline
./eDNA_pipeline.sh --help

# 3. Test with small dataset
./eDNA_pipeline.sh -i test_data --database ncbi --threads 2

# 4. Check outputs
ls final_reports/
# Should see:
# - ASV_taxonomy_assignments.csv
# - species_abundance_summary.csv
# - method_species_comparison.csv
# - taxonomy_confidence_report.csv
# - sample_by_sample_taxonomy.csv
# - location_diversity_summary.csv
```


## 📄 License

MIT License - Free to use, modify, and distribute

---

## 🙏 Acknowledgments

### Pipeline Components
- **DADA2**: Benjamin J Callahan et al. - ASV calling
- **MIDORI2**: Machida et al. - Marine species reference database
- **NCBI GenBank**: Comprehensive sequence database
- **BLAST**: Altschul et al. - Sequence alignment
- **Trimmomatic**: Quality filtering
- **FLASH**: Paired-end read merging
- **Cutadapt**: Primer removal

### Analysis Tools
- **R/Bioconductor**: Statistical analysis framework
- **vegan**: Community ecology analysis
- **dplyr/tidyr**: Data manipulation

---

## 📧 Support

- **GitHub Issues**: Report bugs or request features


---

## 🚀 Quick Reference Card

```bash
# CREATE PACKAGE
./create_edna_pipeline_package.sh

# INSTALL PACKAGE
cd eDNA-ASV-Pipeline && ./install.sh

# ACTIVATE
conda activate edna-pipeline

# RUN BASIC
./eDNA_pipeline.sh -i raw_data --database ncbi

# RUN SINGLE METHOD
./eDNA_pipeline.sh -i raw_data --single-method

# RUN HIGH STRINGENCY
./eDNA_pipeline.sh -i raw_data --min-identity 95

# RUN CUSTOM DATABASE
./eDNA_pipeline.sh -i raw_data --custom-db /path/to/db

# CHECK OUTPUTS
ls final_reports/*.csv
```

---

## ⭐ Key Features at a Glance

| Feature | Description |
|---------|-------------|
| 🧬 **Complete Workflow** | Raw reads → ASVs → Species reports |
| 🗄️ **Database Support** | MIDORI2, NCBI, Custom databases |
| 🔬 **Method Comparison** | eDNA vs EV.DNA analysis |
| ⚙️ **Configurable** | Identity thresholds, primers, threads |
| 📊 **Comprehensive Output** | 7+ detailed analysis reports |
| 🐳 **Easy Setup** | One-command conda installation |
| 🎯 **Optimized** | For 12S rRNA metabarcoding |
| 🔧 **Flexible** | Three analysis modes |

---

**Made with 🧬 for the eDNA community**
