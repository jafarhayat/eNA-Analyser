# eDNA ASV Pipeline - Complete Working Version

🧬 **Complete pipeline for environmental DNA analysis from raw sequencing reads to comprehensive species identification**

[![Pipeline](https://img.shields.io/badge/pipeline-working-green.svg)]()
[![Conda](https://img.shields.io/badge/conda-supported-brightgreen.svg)](environment.yml)
[![Analysis](https://img.shields.io/badge/analysis-comprehensive-blue.svg)]()

## 🎯 Features

- 🧬 **Complete workflow**: Raw reads → ASVs → Comprehensive species reports
- 🐟 **Optimized for 12S rRNA**: Marine and freshwater species detection
- 📊 **Multiple databases**: Built-in MIDORI2/NCBI + custom database support
- 🔬 **Method comparison**: eDNA vs EV.DNA analysis (optional with --single-method)
- ⚙️ **Configurable parameters**: Identity thresholds, primers, threading
- 📈 **Comprehensive outputs**: 6+ detailed analysis reports
- 🔧 **One-command setup**: Automated conda installation

## 🚀 Quick Start

```bash
# 1. Clone/download and install
git clone https://github.com/yourusername/eDNA-ASV-Pipeline.git
cd eDNA-ASV-Pipeline
./install.sh

# 2. Activate environment  
conda activate edna-pipeline

# 3. Run analysis
./eDNA_pipeline.sh -i raw_data --database ncbi
```

## 📊 Comprehensive Output Files

Every analysis generates these reports in `final_reports/`:

### Core Analysis Files
- **`ASV_taxonomy_assignments.csv`** - Complete taxonomy for each ASV
- **`species_abundance_summary.csv`** - Species abundance with locations/methods
- **`sample_by_sample_taxonomy.csv`** - Detailed sample breakdown
- **`taxonomy_confidence_report.csv`** - Quality assessment

### Method Comparison (when not using --single-method)
- **`method_species_comparison.csv`** - eDNA vs EV.DNA species comparison

### Additional Analyses
- **`location_diversity_summary.csv`** - Location-based diversity
- **`fish_species_summary.csv`** - Fish-specific analysis (when detected)

## 🔧 Usage Examples

### Basic Analysis
```bash
# Auto-detect database, full eDNA vs EV.DNA comparison
./eDNA_pipeline.sh -i raw_data --database ncbi
```

### Single Method Analysis
```bash
# Skip method comparison, treat all samples equally
./eDNA_pipeline.sh -i raw_data --single-method
```

### High Stringency
```bash
# Require 95% identity for species assignment
./eDNA_pipeline.sh -i raw_data --database midori --min-identity 95
```

### Custom Database
```bash
# Use your own reference database
./eDNA_pipeline.sh -i raw_data --custom-db /path/to/my_database
```

### Taxonomy Only
```bash
# Analyze existing ASV data
./eDNA_pipeline.sh -s asv_sequences.fasta -t asv_table.csv --mode taxonomy-only
```

## 🗄️ Database Support

### Built-in Databases
- **MIDORI2**: Marine species optimized for 12S rRNA
- **NCBI**: Comprehensive GenBank sequences

### Custom Databases
Place your files in `Database/` directory:
- `your_sequences.fasta` - Reference sequences
- `your_taxonomy.csv` - Taxonomy information

Required CSV columns: `Accession`, `Species`, `Genus`

## ⚙️ Command Line Options

### Input Options
```bash
-i, --input DIR               # Input directory  
-s, --sequences FILE          # ASV sequences (taxonomy-only)
-t, --table FILE              # ASV table (taxonomy-only)
```

### Analysis Control
```bash
--mode full|asv-only|taxonomy-only    # Analysis mode
--single-method                       # Skip eDNA/EV.DNA comparison
--min-identity NUM                     # BLAST identity threshold (80)
```

### Database Options
```bash
--database midori|ncbi                # Force specific database
--custom-db DIR                       # Use custom database
```

### Processing Options
```bash
--threads NUM                         # Number of threads (4)
--forward-primer SEQ                  # Forward primer
--reverse-primer SEQ                  # Reverse primer
```

## 📁 Input Data Formats

### Folder Structure (Recommended)
```
raw_data/
├── X.eDNA_14/
│   ├── X.eDNA_14_S*.R1.fq.gz
│   └── X.eDNA_14_S*.R2.fq.gz
├── X.EV.DNA_14/
│   ├── X.EV.DNA_14_S*.R1.fq.gz
│   └── X.EV.DNA_14_S*.R2.fq.gz
```

### Flat Files (Also Supported)
```
raw_data/
├── sample1.R1.fq.gz
├── sample1.R2.fq.gz
├── sample2.R1.fq.gz
└── sample2.R2.fq.gz
```

## 🔬 Analysis Features

### Species Detection
- Enhanced fish identification
- Marine vs freshwater classification
- Organism type categorization
- Confidence scoring

### Method Comparison
- Automatic eDNA/EV.DNA detection
- Species presence/absence patterns
- Abundance comparisons
- Log2 fold differences

### Quality Control
- BLAST identity filtering
- Confidence level assignment
- ASV abundance tracking
- Processing statistics

## 🛠️ Installation Requirements

- **System**: Linux, macOS, or Windows with WSL
- **Memory**: 8GB RAM minimum, 16GB recommended
- **Software**: Conda/Miniconda
- **Storage**: 10GB+ free space

## 📚 Documentation

- [Installation Guide](docs/INSTALLATION.md) - Detailed setup
- [Usage Guide](docs/USAGE.md) - Examples and options
- [Database Guide](docs/DATABASES.md) - Custom databases
- [Output Guide](docs/OUTPUTS.md) - Understanding results

## 🎯 Algorithm Overview

1. **Quality Control**: Trimmomatic → FLASH → Cutadapt
2. **ASV Calling**: DADA2 error correction and denoising
3. **Taxonomy**: BLAST search against reference database
4. **Enhancement**: Species validation and classification
5. **Analysis**: Comprehensive reporting and comparisons

## 🔄 Typical Workflow

```bash
# 1. Install once
./install.sh

# 2. For each dataset
conda activate edna-pipeline
./eDNA_pipeline.sh -i your_data --database ncbi

# 3. Review results
ls final_reports/
```

## 💡 Tips & Best Practices

1. **Start with defaults** - adjust parameters as needed
2. **Use single-method** if no eDNA/EV.DNA comparison needed
3. **Check taxonomy_confidence_report.csv** for data quality
4. **Higher min-identity** for more stringent species calls
5. **Custom databases** for specialized taxonomic groups

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- **DADA2**: Benjamin J Callahan et al.
- **MIDORI2**: Machida et al.
- **BLAST**: Altschul et al.
- **Claude ai used as an assistant to create this pipline**
---

⭐ **Star this repository** if you find it useful!  
🐛 **Found an issue?** Please [report it](https://github.com/yourusername/eDNA-ASV-Pipeline/issues)  
📧 **Questions?** Check the documentation or open a discussion
