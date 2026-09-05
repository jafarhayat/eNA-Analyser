# eNA 12S Pipeline

Complete bioinformatics pipeline for environmental NA (eNA) analysis, from raw Illumina reads to species identification.

[![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)](https://github.com/yourusername/eDNA-12S-Pipeline)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)


## Features

- **Complete Workflow**: Raw FASTQ → Quality Control → ASV/OTU Calling → Taxonomy → Reports
- **Dual ASV Methods**: Choose between DADA2 (exact sequences) or OTU clustering (VSEARCH)
- **MiFish-U primers**: Optimized for fish 12S metabarcoding
- **Comprehensive Reports**: Sample-by-sample breakdown, species summaries, abundance tables
- **Easy Installation**: One-command conda-based setup

## Quick Start

```bash
# 1. Install
git clone https://github.com/jafarhayat/eNA-Analyser.git
cd eDNA-12S-Pipeline
./install.sh

# 2. Activate environment
conda activate edna-pipeline

# 3. Run analysis
./edna_pipeline.sh -i /path/to/samples -o results -d Database/
```

## Requirements

- **System**: Linux or macOS (Windows via WSL2)
- **RAM**: 8GB minimum (16GB+ recommended)
- **Storage**: 50GB+ for database and results
- **Software**: Conda/Miniconda

## Input Requirements

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


### Basic Usage

```bash
# Standard analysis with default settings
./edna_pipeline_v3.2.sh -i raw_data/ -o results/ -d reference_db/

# With fish/non-fish classification
./edna_pipeline_v3.2.sh -i raw_data/ -o results/ -d reference_db/ --fish-split

# Filter low-abundance detections (minimum 10 reads)
./edna_pipeline_v3.2.sh -i raw_data/ -o results/ -d reference_db/ --min-reads 10
```

### Input Directory Structure

```
raw_data/
├── Sample1/
│   ├── Sample1_R1.fastq.gz
│   └── Sample1_R2.fastq.gz
├── Sample2/
│   ├── Sample2_R1.fastq.gz
│   └── Sample2_R2.fastq.gz
└── ...
```

### Reference Database

```
reference_db/
├── combined_database.fasta              # Reference sequences
├── combined_taxonomy.csv                # Taxonomy mapping
└── fish_classification_reference.csv    # (optional, for --fish-split)
```

## Options

### Required Parameters

| Option | Description |
|--------|-------------|
| `-i, --input DIR` | Input directory with sample folders |
| `-o, --output DIR` | Output directory |
| `-d, --database DIR` | Reference database directory |

### Filtering Options

| Option | Default | Description |
|--------|---------|-------------|
| `--min-identity NUM` | 97 | Minimum BLAST identity % for species assignment |
| `--min-alignment NUM` | 80 | Minimum alignment length in bp |
| `--min-reads NUM` | 5 | **NEW in v3.2**: Minimum reads per species per sample |

### Method Options

| Option | Default | Description |
|--------|---------|-------------|
| `--method METHOD` | dada2 | ASV method: `dada2` or `otus` |
| `--threads NUM` | 4 | Number of CPU threads |

### DADA2 Options

| Option | Default | Description |
|--------|---------|-------------|
| `--max-ee NUM` | 2 | Maximum expected errors |
| `--min-len NUM` | 100 | Minimum ASV length (bp) |
| `--max-len NUM` | 250 | Maximum ASV length (bp) |

### OTU Options

| Option | Default | Description |
|--------|---------|-------------|
| `--cluster-id NUM` | 97 | OTU clustering identity % |

### Other Options

| Option | Description |
|--------|-------------|
| `--fish-split` | Separate fish from non-fish species |
| `--no-blast` | Skip BLAST (ASV generation only) |
| `--forward-primer SEQ` | Custom forward primer |
| `--reverse-primer SEQ` | Custom reverse primer |

## Output Files

### Main Reports (`reports/`)

| File | Description |
|------|-------------|
| `species_summary.csv` | All species with total read counts |
| `species_by_sample.csv` | Species per sample (filtered by `--min-reads`) |
| `species_by_sample_ALL.csv` | Species per sample (unfiltered, for comparison) |
| `sample_by_sample_taxonomy.csv` | All ASVs with taxonomy per sample |
| `ASV_taxonomy.csv` | Taxonomy assignment for each ASV |

### Fish Classification (`--fish-split`)

| File | Description |
|------|-------------|
| `fish_species.csv` | Fish species only (filtered) |
| `fish_species_ALL.csv` | Fish species (unfiltered) |
| `non_fish_species.csv` | Non-fish vertebrates |
| `contamination_detected.csv` | Potential contaminants (human, pig, etc.) |

### Intermediate Files (`intermediate/`)

| Directory | Contents |
|-----------|----------|
| `01_trimmed/` | Quality-filtered reads |
| `02_merged/` | Merged paired reads |
| `03_primers_removed/` | Primer-free amplicons |
| `04_asvs/` | Final ASV sequences and abundance table |

## Pipeline Details

### Step 1: Quality Filtering (Trimmomatic)
- Removes low-quality bases from read ends
- Sliding window quality check (4bp window, Q20 threshold)
- Discards reads shorter than 50bp

### Step 2: Read Merging (FLASH)
- Merges overlapping paired-end reads
- Minimum overlap: 10bp
- Maximum overlap: 300bp

### Step 3: Primer Removal (Cutadapt)
- **Critical**: Uses linked adapter syntax (`^FORWARD...REVERSE_RC`)
- Ensures both primers are present and properly oriented
- Discards reads without proper primer pairs
- Output length: 80-250bp

### Step 4: ASV/OTU Generation

**DADA2 (recommended)**:
- Learns error model from data
- Generates exact sequence variants (ASVs)
- Removes chimeras using consensus method

**VSEARCH**:
- Dereplicates sequences
- Clusters at specified identity (default 97%)
- Chimera removal with UCHIME

### Step 5: BLAST Annotation
- Queries ASVs against reference database
- Returns top 5 hits per ASV
- Best hit selected by bitscore

### Step 6: Report Generation
- Aggregates results by species and sample
- Applies confidence filtering
- Generates summary statistics

### Step 7: Fish Classification (optional)
- Categorizes species as fish/non-fish/contamination
- Uses reference classification database
- Separates results into distinct files

## Filtering Explained

### Identity and Alignment Filters (`--min-identity`, `--min-alignment`)

Control which BLAST hits are considered valid species assignments:

| Setting | Use Case |
|---------|----------|
| `--min-identity 99 --min-alignment 150` | Strict: Only confident species-level IDs |
| `--min-identity 97 --min-alignment 100` | Standard: Balanced sensitivity/specificity |
| `--min-identity 90 --min-alignment 80` | Relaxed: Include uncertain matches |

### Read Count Filter (`--min-reads`) - NEW in v3.2

Removes low-abundance detections that may be:
- Cross-contamination between samples
- PCR/sequencing errors
- Environmental background noise

```bash
# Remove species with < 10 reads per sample
./edna_pipeline_v3.2.sh ... --min-reads 10

# Keep all detections (no filtering)
./edna_pipeline_v3.2.sh ... --min-reads 1
```

**Comparison files**: Both filtered (`species_by_sample.csv`) and unfiltered (`species_by_sample_ALL.csv`) versions are generated for comparison.

## Examples

### Example 1: Standard Fish eDNA Analysis

```bash
./edna_pipeline_v3.2.sh \
    -i /path/to/raw_reads/ \
    -o /path/to/results/ \
    -d /path/to/fish_12S_database/ \
    --fish-split \
    --min-reads 5 \
    --threads 8
```

### Example 2: High-Stringency Analysis

```bash
./edna_pipeline_v3.2.sh \
    -i raw_data/ \
    -o results_strict/ \
    -d reference_db/ \
    --min-identity 99 \
    --min-alignment 150 \
    --min-reads 20
```

### Example 3: OTU-Based Analysis

```bash
./edna_pipeline_v3.2.sh \
    -i raw_data/ \
    -o results_otu/ \
    -d reference_db/ \
    --method otus \
    --cluster-id 97
```

### Example 4: Custom Primers (COI)

```bash
./edna_pipeline_v3.2.sh \
    -i raw_data/ \
    -o results_coi/ \
    -d coi_database/ \
    --forward-primer "GGWACWGGWTGAACWGTWTAYCCYCC" \
    --reverse-primer "TANACYTCNGGRTGNCCRAARAAYCA"
```

### Example 5: ASV Generation Only (No Taxonomy)

```bash
./edna_pipeline_v3.2.sh \
    -i raw_data/ \
    -o results_asv_only/ \
    --no-blast
```

## Troubleshooting

### Common Issues

**No reads after primer removal**
- Check primer sequences match your amplicon
- Try increasing error tolerance: modify cutadapt `-e` parameter
- Verify reads are properly oriented

**Low species matches**
- Database may be missing target species
- Try lowering `--min-identity` to see more matches
- Check BLAST results directly: `taxonomy/blast_results.txt`

**Missing species that should be detected**
- Check if species is in reference database
- May be primer binding issue (some species don't amplify)
- Ancient fish (sturgeon) often don't work with MiFish primers

**Ambiguous species assignments**
- Some closely related species cannot be distinguished with 12S
- Check `species_by_sample_ALL.csv` for full results
- Consider using additional markers (COI, 16S)

### Log Files

All processing logs are saved in `OUTPUT_DIR/logs/`:
- `pipeline_YYYYMMDD_HHMMSS.log` - Main pipeline log
- `trimmomatic.log` - Quality filtering details
- `flash.log` - Read merging statistics
- `cutadapt_*.log` - Primer removal per sample
- `dada2.log` - ASV generation (if using DADA2)
- `reports.log` - Report generation details

## Citation

If you use this pipeline, please cite:

```
eDNA Complete Pipeline v3.2
https://github.com/jafarhayat/eNA-Analyser

And the underlying tools:
- DADA2: Callahan et al. (2016) Nature Methods
- VSEARCH: Rognes et al. (2016) PeerJ
- Cutadapt: Martin (2011) EMBnet.journal
- BLAST: Altschul et al. (1990) Journal of Molecular Biology
```

## License

MIT License - see LICENSE file for details

## Acknowledgments

Built with:
- [DADA2](https://benjjneb.github.io/dada2/)
- [VSEARCH](https://github.com/torognes/vsearch)
- [Trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic)
- [FLASH](https://ccb.jhu.edu/software/FLASH/)
- [Cutadapt](https://cutadapt.readthedocs.io/)
- [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi)


Made with ❤️ for the eDNA community
