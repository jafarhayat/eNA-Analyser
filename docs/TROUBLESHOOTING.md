# Troubleshooting Guide

## Installation Issues

### "conda: command not found"
Install Miniconda from: https://docs.conda.io/en/latest/miniconda.html

### DADA2 installation fails
```bash
conda activate edna-pipeline
R
# In R:
BiocManager::install("dada2")
```

## Pipeline Issues

### "No samples found"
Check your directory structure:
```
samples/
├── sample1/
│   ├── sample1_R1.fq.gz  # Must contain R1
│   └── sample1_R2.fq.gz  # Must contain R2
```

### "No reads after primer removal"
- Check primer sequences match your data
- Try increasing `-e` error tolerance in cutadapt
- Verify merged read lengths match expected amplicon size

### DADA2 "No samples passed filtering"
- Increase `--max-ee` (e.g., from 2 to 5 or 10)
- Check sequence quality with FastQC

### "No BLAST hits"
- Verify database FASTA format
- Check if database needs rebuilding
- Lower `--min-identity` to 80 or 70

### Low species matches in reports
- Check `*_ALL.csv` files for unfiltered results
- Verify taxonomy CSV format matches database IDs
- Try `--min-identity 90` for more matches

## Common Errors

### "BLAST database not found"
```bash
cd Database/
makeblastdb -in your_database.fasta -dbtype nucl -out your_database_blast
```

### Memory errors
- Reduce `--threads`
- Process samples in smaller batches

### R package errors
```bash
conda activate edna-pipeline
R -e "install.packages(c('dplyr', 'tidyr', 'tibble'), repos='http://cran.r-project.org')"
```
