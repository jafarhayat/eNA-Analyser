# Quick Start Guide - 5 Minutes to Results

## Prerequisites

- Linux or macOS (Windows users: use WSL2)
- Conda/Miniconda installed
- 8GB+ RAM

## Installation (2 minutes)

```bash
git clone https://github.com/jafarhayat/eNA-Analyser.git
cd eDNA-12S-Pipeline
./install.sh
```

## Prepare Your Data

```
my_samples/
├── sample1/
│   ├── sample1_R1.fq.gz
│   └── sample1_R2.fq.gz
├── sample2/
│   ├── sample2_R1.fq.gz
│   └── sample2_R2.fq.gz
```

## Run Analysis

```bash
conda activate edna-pipeline
./edna_pipeline.sh -i my_samples/ -o results/ -d Database/
```

## Check Results

```bash
head results/reports/species_summary.csv
```

## Common Use Cases

### ASV-only (no taxonomy)
```bash
./edna_pipeline.sh -i samples/ -o results/ --no-blast
```

### Include lower-confidence matches
```bash
./edna_pipeline.sh -i samples/ -o results/ -d Database/ --min-identity 90
```

### Strict species-level only
```bash
./edna_pipeline.sh -i samples/ -o results/ -d Database/ --min-identity 99 --min-alignment 150
```

### Use OTU clustering
```bash
./edna_pipeline.sh -i samples/ -o results/ -d Database/ --method otus
```

## Troubleshooting

**No samples found**: Check directory structure matches expected format

**DADA2 errors**: Try increasing `--max-ee` (e.g., `--max-ee 5`)

**No BLAST hits**: Check database format, try lowering `--min-identity`

For more help, see the full README.md
