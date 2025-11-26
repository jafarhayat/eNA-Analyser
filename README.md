# eDNA 12S Metabarcoding Pipeline

A complete bioinformatics pipeline for processing environmental DNA (eDNA) samples from raw Illumina sequencing reads to species identification. This pipeline was developed to make eDNA analysis accessible and reproducible for researchers working with 12S rRNA amplicon sequencing data.

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/yourusername/eDNA-12S-Pipeline/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## Overview

I developed this pipeline to streamline the analysis of 12S rRNA environmental DNA data, specifically focusing on vertebrate species detection in marine and freshwater environments. The pipeline handles everything from raw paired-end FASTQ files through quality control, ASV/OTU generation, and taxonomic assignment, producing publication-ready results.

### What It Does

- **Quality Control**: Removes low-quality bases and adapters
- **Read Processing**: Merges paired-end reads and removes primer sequences  
- **ASV/OTU Calling**: Generates sequence variants using either DADA2 or OTU clustering
- **Taxonomy Assignment**: Matches sequences against reference databases using BLAST
- **Report Generation**: Creates comprehensive species abundance and diversity reports

### Why I Built This

After working with multiple eDNA datasets, I found that existing pipelines were either:
- Too complex for researchers without bioinformatics backgrounds
- Lacked flexibility in primer selection and ASV methods
- Had unreliable installation processes
- Produced outputs that required extensive post-processing

This pipeline addresses these issues with a focus on:
- **Easy installation**: One-command conda-based setup
- **Flexibility**: Support for multiple primer sets and ASV methods
- **Reliability**: Bulletproof dependency management
- **Usability**: Clear documentation and publication-ready outputs

## Features

✨ **Dual ASV Methods**
- DADA2 exact sequence variants for high-resolution analysis
- OTU clustering (VSEARCH) at customizable similarity thresholds (95%, 97%, 99%)

🧬 **Multiple Primer Support**
- Pre-configured presets: 12S-MiFish, 12S-Teleo, 16S-bacteria, COI-mlcoi
- Custom primer option for any target region

📊 **Comprehensive Outputs**
- Species-by-sample breakdown tables
- Abundance summaries with confidence scores
- Taxonomy assignments with BLAST metrics
- Detailed processing logs

🚀 **Easy Installation**
- Automated conda environment setup
- Dependency verification
- Database preparation

## Requirements

- **Operating System**: Linux or macOS (Windows users can use WSL2)
- **RAM**: 8GB minimum (16GB+ recommended for large datasets)
- **Storage**: 50GB+ for databases and intermediate files
- **Software**: Conda or Miniconda

## Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/jafarhayat/eNA-Analyser.git
cd eNA-Analyser
```

### Step 2: Run the Installation Script

```bash
chmod +x create_edna_pipeline_v2.sh
./create_edna_pipeline_v2.sh
```

```bash
cd eDNA-12S-Pipeline
./install.sh
```

The installer will:
1. Check for conda installation
2. Create the `edna-pipeline` conda environment
3. Install all required dependencies
4. Set up DADA2 via BiocManager
5. Build BLAST databases from your reference files
6. Verify all tools are working

This takes approximately 5-10 minutes on the first installation.

### Step 3: Add Your Reference Database

Place your reference database files in the `Database/` directory:

```bash
# Copy your database files
cp /path/to/your/reference_sequences.fasta Database/
cp /path/to/your/taxonomy_mapping.csv Database/
```

### Step 4: Activate the Environment

```bash
conda activate edna-pipeline
```

### Step 5: Test the Installation

```bash
./edna_pipeline.sh --help
```

You should see the help menu with all available options.

## Usage

### Input Data Structure

Organize your FASTQ files in sample folders:

```
my_samples/
├── sample1/
│   ├── sample1_R1.fq.gz
│   └── sample1_R2.fq.gz
├── sample2/
│   ├── sample2_R1.fq.gz
│   └── sample2_R2.fq.gz
└── sample3/
    ├── sample3_R1.fq.gz
    └── sample3_R2.fq.gz
```

The pipeline recognizes these naming patterns:
- `*.R1.fq.gz` / `*.R2.fq.gz`
- `*_R1_*.fastq.gz` / `*_R2_*.fastq.gz`
- `*_1.fq.gz` / `*_2.fq.gz`

### Basic Analysis

```bash
# Activate environment
conda activate edna-pipeline

# Run with default settings (OTU clustering, MiFish primers)
./edna_pipeline.sh -i /path/to/samples
```

### Using Different Primer Sets

```bash
# List available primer presets
./edna_pipeline.sh --list-presets

# Use Teleo 12S primers
./edna_pipeline.sh -i samples/ --preset 12s-teleo

# Use 16S bacterial primers
./edna_pipeline.sh -i samples/ --preset 16s-bacteria

# Use custom primers
./edna_pipeline.sh -i samples/ --preset custom \
    --forward-primer ACTGGGATTAGATACCCC \
    --reverse-primer TAGAACAGGCTCCTCTAG
```

### Choosing ASV Method

```bash
# Use DADA2 (exact sequence variants)
./edna_pipeline.sh -i samples/ --asv-method dada2

# Use OTU clustering at 97% similarity (default)
./edna_pipeline.sh -i samples/ --asv-method otus

# Use OTU clustering at 99% similarity
./edna_pipeline.sh -i samples/ --asv-method otus --clustering-id 99
```

### Adjusting DADA2 Parameters

```bash
# Strict filtering for high-quality data
./edna_pipeline.sh -i samples/ --asv-method dada2 --max-ee 2

# Relaxed filtering for degraded samples
./edna_pipeline.sh -i samples/ --asv-method dada2 --max-ee 30

# Custom length range
./edna_pipeline.sh -i samples/ --asv-method dada2 \
    --min-len 100 --max-len 200
```

### Complete Example

```bash
# Full analysis with custom settings
./edna_pipeline.sh \
    -i /data/field_samples \
    -o my_results \
    -d Database \
    --asv-method dada2 \
    --max-ee 10 \
    --min-identity 70 \
    --threads 8
```

## Pipeline Steps

The pipeline consists of six main steps:

### 1. Quality Filtering (Trimmomatic)
- Removes low-quality bases using sliding window approach
- Crops reads to 300bp maximum
- Filters out reads shorter than 50bp
- Removes adapter sequences

### 2. Read Merging (FLASH)
- Merges paired-end reads based on overlapping regions
- Requires minimum 10bp overlap
- Creates single consensus sequences

### 3. Primer Removal (Cutadapt)
- Removes forward and reverse primer sequences
- Handles degenerate bases in primers
- Filters sequences by length (50-500bp)

### 4. ASV/OTU Generation

**DADA2 Method:**
- Quality filtering with adjustable error thresholds
- Error rate learning from data
- Denoising and exact sequence variant inference
- Chimera removal

**OTU Method:**
- Dereplication of identical sequences
- Abundance-based sorting
- Clustering at specified similarity (95%, 97%, or 99%)
- De novo chimera detection
- OTU table generation

### 5. Taxonomic Assignment (BLAST)
- Uses blastn-short algorithm optimized for amplicons
- Searches against custom reference database
- Filters hits by identity and coverage thresholds
- Returns best match per sequence variant

### 6. Report Generation (R)
- Merges sequence data with taxonomy
- Calculates abundance metrics
- Generates species-by-sample breakdowns
- Creates summary statistics
- Assigns confidence scores

## Output Files

Results are organized in timestamped directories (`results_YYYYMMDD_HHMMSS/`):

### Main Results (`final_reports/`)

- **ASV_taxonomy_assignments.csv** or **OTU_taxonomy_assignments.csv**
  - Complete taxonomic assignment for each sequence variant
  - Columns: ASV/OTU_ID, Species, Genus, Percent_Identity, E_value, Confidence
  
- **sample_by_sample_taxonomy.csv**
  - Detailed breakdown of species in each sample
  - Columns: Sample_ID, ASV/OTU_ID, Species, Genus, Abundance, Confidence, Percent_Identity
  
- **species_by_sample.csv**
  - Species presence and abundance per sample
  - Columns: Sample_ID, Species, Genus, Total_Reads, ASV/OTU_Count, Avg_Identity
  
- **species_abundance_summary.csv**
  - Overall species summary across all samples
  - Columns: Species, Genus, Total_Reads, ASV/OTU_Count, Samples_Present, Avg_Identity

### Intermediate Files (`intermediate/`)

- `04_dada2/asvs_final.fasta` or `04_otus/otus_final.fasta` - Final sequence variants
- `04_dada2/asv_table.csv` or `04_otus/otu_table.txt` - Abundance matrix
- `01_trimmed/` - Quality-filtered reads
- `02_merged/` - Merged paired-end reads
- `03_primers_removed/` - Primer-trimmed sequences

### Logs (`logs/`)

- `pipeline_full.log` - Complete execution log with all steps
- `pipeline_timestamps.log` - Timing information for each step
- `trimmomatic.log`, `flash.log`, `cutadapt.log`, `dada2.log` - Tool-specific logs

## Bioinformatics Tools Used

This pipeline integrates several well-established bioinformatics tools:

### Core Processing Tools

- **[Trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic)** (Bolger et al. 2014)  
  Quality filtering and adapter removal
  
- **[FLASH](https://ccb.jhu.edu/software/FLASH/)** (Magoč & Salzberg 2011)  
  Fast Length Adjustment of SHort reads - merging paired-end sequences
  
- **[Cutadapt](https://cutadapt.readthedocs.io/)** (Martin 2011)  
  Primer and adapter sequence removal

- **[VSEARCH](https://github.com/torognes/vsearch)** (Rognes et al. 2016)  
  OTU clustering, dereplication, and chimera detection
  
- **[BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi)** (Camacho et al. 2009)  
  Taxonomic assignment via sequence similarity search

### ASV Calling

- **[DADA2](https://benjjneb.github.io/dada2/)** (Callahan et al. 2016)  
  Amplicon Sequence Variant inference via denoising algorithm

### Data Analysis and Visualization

- **R** (R Core Team 2023)


## Database Setup

The pipeline requires a reference database for taxonomic assignment. I've tested it with several databases:

### Supported Database Formats

1. **FASTA file** (required)
   - Contains reference sequences
   - Standard FASTA format with headers
   - Name: `*.fasta` or `*.fa`

2. **Taxonomy CSV file** (optional but recommended)
   - Maps accessions to species names
   - Required columns: `Accession`, `Species`, `Genus`
   - Name: should contain "taxonomy" in filename

### Recommended Databases for 12S

- **MIDORI2** - Comprehensive metazoan reference  
  Download: http://www.reference-midori.info/

- **NCBI RefSeq** - Curated vertebrate sequences  
  Download: https://www.ncbi.nlm.nih.gov/refseq/

- **Custom databases** - Build your own using tools like [CRABS](https://github.com/gjeunen/reference_database_creator)

## Troubleshooting

### Common Issues

**Conda not found**
```bash
# Install Miniconda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
```

**DADA2 installation fails**
```bash
# Try manual installation
conda activate edna-pipeline
R
> if (!require("BiocManager", quietly=TRUE)) install.packages("BiocManager")
> BiocManager::install("dada2")
```

**No samples detected**
- Check your directory structure matches expected format
- Ensure R1 and R2 files are in the same folder
- Verify file naming patterns (R1/R2 designation)

**BLAST returns no hits**
- Try lowering `--min-identity` threshold (default 70%)
- Verify your database is correctly formatted
- Check that primer regions are appropriate for your database

**Out of memory errors**
- Reduce `--threads` number
- Process samples in smaller batches
- Increase system RAM allocation

For more issues, please open an [Issue](https://github.com/yourusername/eDNA-12S-Pipeline/issues) on GitHub.

## Performance

DADA2 is generally slower but more accurate than OTU clustering. Adjust `--threads` based on your system capabilities.

## Contributing

I welcome contributions to improve this pipeline! Here's how you can help:

### Reporting Issues

If you encounter bugs or have suggestions:
1. Check if the issue already exists in [Issues](https://github.com/jafarhayat/eNA-Analyser/issues)
2. Open a new issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Your system information (OS, conda version)
   - Relevant log files

### Areas for Contribution

I'm particularly interested in contributions for:
- Additional primer presets
- Support for other marker genes (18S, ITS, etc.)
- Integration with additional databases
- Performance optimizations
- Additional visualization outputs
- Docker containerization
- Unit tests

## Citation

If you use this pipeline in your research, please cite:

```
(2025). eDNA 12S Metabarcoding Pipeline (Version 2.0.0) 
GitHub. https://github.com/jafarhayat/eNA-Analyser/issues

Citation for paper (will be updated)
```

### Key References for Tools Used

- **DADA2**: Callahan et al. (2016) High-resolution sample inference from Illumina amplicon data. Nature Methods 13:581-583.
- **VSEARCH**: Rognes et al. (2016) VSEARCH: a versatile open source tool for metagenomics. PeerJ 4:e2584.
- **Trimmomatic**: Bolger et al. (2014) Trimmomatic: a flexible trimmer for Illumina sequence data. Bioinformatics 30:2114-2120.
- **FLASH**: Magoč & Salzberg (2011) FLASH: fast length adjustment of short reads. Bioinformatics 27:2957-2963.
- **Cutadapt**: Martin (2011) Cutadapt removes adapter sequences from high-throughput sequencing reads. EMBnet.journal 17:10-12.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

I want to acknowledge the developers of all the bioinformatics tools integrated in this pipeline. The open-source community's contributions to eDNA research have been invaluable.

Special thanks to:
- The DADA2 team for their excellent ASV inference algorithm
- The VSEARCH developers for a fast, reliable clustering tool
- The Conda/Bioconda communities for package management
- Everyone who has contributed to the tools listed above

## Contact

- **GitHub Issues**: For bug reports and feature requests
- **Email**: [hayatovjafar@outlook.com]
- **ORCID**: [https://orcid.org/0000-0003-3968-107X]

## Version History

- **v2.0.0** (2024)
  - Improved installation reliability
  - Added DADA2 support
  - Multiple primer presets
  - Enhanced documentation
  - Comprehensive output reports

- **v1.0.0** (2024)
  - Initial release
  - OTU-based analysis
  - Basic taxonomic assignment

---

**Made for the eDNA research community** 🧬🌊

