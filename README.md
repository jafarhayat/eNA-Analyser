# eDNA 12S Pipeline v3.0

Complete bioinformatics pipeline for environmental DNA (eDNA) analysis, from raw Illumina reads to species identification.

[![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)](https://github.com/yourusername/eDNA-12S-Pipeline)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## ✨ What's New in v3.0

- 🚀 **ASV-only mode** (`--no-blast`): Generate ASVs without taxonomy assignment
- 🎯 **Alignment filtering** (`--min-alignment`): Filter by alignment length
- 🔧 **Improved primer removal**: Proper linked adapter syntax for cutadapt
- 📊 **Dual outputs**: Both filtered and unfiltered results (`*_ALL.csv`)
- 🐛 **BLAST ID fix**: Handles `lcl|` prefix in BLAST output
- 📖 **Better documentation**: Comprehensive help and examples

## ✨ Features

- 🧬 **Complete Workflow**: Raw FASTQ → Quality Control → ASV/OTU Calling → Taxonomy → Reports
- 🔬 **Dual ASV Methods**: Choose between DADA2 (exact sequences) or OTU clustering (VSEARCH)
- 🧪 **MiFish-U primers**: Optimized for fish 12S metabarcoding
- 📊 **Comprehensive Reports**: Sample-by-sample breakdown, species summaries, abundance tables
- 🚀 **Easy Installation**: One-command conda-based setup

## 🚀 Quick Start

```bash
# 1. Install
git clone https://github.com/yourusername/eDNA-12S-Pipeline.git
cd eDNA-12S-Pipeline
./install.sh

# 2. Activate environment
conda activate edna-pipeline

# 3. Run analysis
./edna_pipeline.sh -i /path/to/samples -o results -d Database/
```

## 📋 Requirements

- **System**: Linux or macOS (Windows via WSL2)
- **RAM**: 8GB minimum (16GB+ recommended)
- **Storage**: 50GB+ for database and results
- **Software**: Conda/Miniconda

## 📂 Input Requirements

Organize your FASTQ files in sample folders:

```
samples/
├── sample1/
│   ├── sample1_R1.fq.gz
│   └── sample1_R2.fq.gz
├── sample2/
│   ├── sample2_R1.fq.gz
│   └── sample2_R2.fq.gz
```

## 🔬 Usage Examples

### Standard Analysis (DADA2 + BLAST)

```bash
./edna_pipeline.sh -i samples/ -o results/ -d Database/
```

### ASV-Only Mode (No BLAST)

```bash
./edna_pipeline.sh -i samples/ -o results/ --no-blast
```

### Relaxed Filtering (Include More Matches)

```bash
./edna_pipeline.sh -i samples/ -o results/ -d Database/ \
    --min-identity 90 --min-alignment 80
```

### Strict Species ID (High Confidence Only)

```bash
./edna_pipeline.sh -i samples/ -o results/ -d Database/ \
    --min-identity 99 --min-alignment 150
```

### OTU Clustering Instead of DADA2

```bash
./edna_pipeline.sh -i samples/ -o results/ -d Database/ \
    --method otus --cluster-id 97
```

### Custom Primers

```bash
./edna_pipeline.sh -i samples/ -o results/ -d Database/ \
    --forward-primer "ACTGGGATTAGATACCCC" \
    --reverse-primer "TAGAACAGGCTCCTCTAG"
```

## 📊 Output Files

### Main Reports (`reports/`)

| File | Description |
|------|-------------|
| `species_summary.csv` | Species list with read counts (filtered) |
| `species_by_sample.csv` | Species per sample (filtered) |
| `species_summary_ALL.csv` | All species (unfiltered) |
| `species_by_sample_ALL.csv` | All species per sample (unfiltered) |
| `sample_by_sample_taxonomy.csv` | All ASVs with taxonomy per sample |
| `ASV_taxonomy.csv` | Taxonomy assignment per ASV |

### Intermediate Files (`intermediate/`)

| File | Description |
|------|-------------|
| `04_asvs/asvs_final.fasta` | Final ASV sequences (primer-free) |
| `04_asvs/asv_table.txt` | ASV abundance matrix |

## 🔍 Filtering Options

The pipeline provides two levels of output:

1. **Filtered files** (`species_summary.csv`, `species_by_sample.csv`): 
   - Respect `--min-identity` and `--min-alignment` settings
   - Default: ≥97% identity, ≥80bp alignment

2. **Unfiltered files** (`*_ALL.csv`):
   - Include ALL BLAST hits regardless of thresholds
   - Useful for exploring lower-confidence matches

## 🛠️ Pipeline Steps

1. **Quality Filtering** (Trimmomatic) - Remove low-quality bases
2. **Read Merging** (FLASH) - Merge paired-end reads
3. **Primer Removal** (Cutadapt) - Remove primer sequences using linked adapters
4. **ASV Calling** (DADA2 or VSEARCH) - Generate sequence variants
5. **Taxonomy Assignment** (BLAST) - Match against reference database
6. **Report Generation** (R) - Create summary tables

## 🗄️ Database Setup

Place your reference database files in the `Database/` directory:

```
Database/
├── reference_sequences.fasta   # Required: FASTA sequences
└── taxonomy_mapping.csv        # Optional: Taxonomy CSV
```

The taxonomy CSV should have columns: `id`, `species`, `genus`, etc.

## 📚 Command Line Options

```
REQUIRED:
    -i, --input DIR           Input directory with sample folders
    -o, --output DIR          Output directory
    -d, --database DIR        Reference database directory

PRIMER OPTIONS:
    --forward-primer SEQ      Forward primer (default: MiFish-U F)
    --reverse-primer SEQ      Reverse primer (default: MiFish-U R)

METHOD OPTIONS:
    --method METHOD           ASV method: dada2 or otus (default: dada2)
    --threads NUM             Number of threads (default: 4)

TAXONOMY FILTERING:
    --min-identity NUM        Minimum BLAST identity % (default: 97)
    --min-alignment NUM       Minimum alignment length bp (default: 80)

DADA2 OPTIONS:
    --max-ee NUM              Max expected errors (default: 2)
    --min-len NUM             Min ASV length bp (default: 100)
    --max-len NUM             Max ASV length bp (default: 250)

OTU OPTIONS:
    --cluster-id NUM          OTU clustering identity % (default: 97)

SKIP OPTIONS:
    --no-blast                Skip BLAST and report generation
```

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

Built with:
- [DADA2](https://benjjneb.github.io/dada2/)
- [VSEARCH](https://github.com/torognes/vsearch)
- [Trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic)
- [FLASH](https://ccb.jhu.edu/software/FLASH/)
- [Cutadapt](https://cutadapt.readthedocs.io/)
- [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi)

## 🔄 Version History

- **v3.0.0** (2024) - No Blast mode, alignment filtering, improved primer removal
- **v2.0.0** (2024) - Multiple ASV methods, preset primers
- **v1.0.0** (2024) - Initial release

---

Made with ❤️ for the eDNA community
