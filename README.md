# Fish 12S rRNA Reference Database Creation Pipeline

This pipeline extracts fish 12S rRNA sequences from the MIDORI2 database, performs in-silico PCR with MiFish-U primers, and creates a clean reference database for eDNA metabarcoding analysis.

## Overview

**Target Gene:** 12S rRNA  
**Primers:** MiFish-U (Miya et al. 2015)  
- Forward: `GTYGGKAAAWCTCGTGCCAGC`
- Reverse: `CATAGTGGGGTATCTAATCCYAGTTTG`

**Expected Amplicon Length:** 150-250 bp  
**Target Taxa:** Fish (Actinopterygii, Chondrichthyes, and related classes)

## Requirements

### Input Files (Required)
Place these files in your working directory:

```
MIDORI2_UNIQ_NUC_GB265_srRNA_RAW.fasta
```

You can download MIDORI2 from: http://www.reference-midori.info/

### Software Requirements

- Python 3.8+
- BioPython (`pip install biopython --break-system-packages`)
- BLAST+ (optional, for creating BLAST databases)

### Installation

```bash
# Install BioPython
pip install biopython --break-system-packages

# Install BLAST+ (optional)
sudo apt-get install ncbi-blast+
# or
conda install -c bioconda blast
```

## Pipeline Workflow

### Step 1: Extract Fish 12S Sequences

This script:
1. Reads MIDORI2 FASTA file
2. Filters for fish taxa
3. Performs in-silico PCR with MiFish-U primers
4. Extracts amplicons in the 150-250 bp range
5. Creates clean FASTA and taxonomy files

```bash
python3 01_extract_fish_12s.py
```

**Input:**
- `MIDORI2_UNIQ_NUC_GB265_srRNA_RAW.fasta`

**Output:**
- `12S_fish_amplicons.fasta` - Clean FASTA with fish 12S amplicons
- `12S_fish_taxonomy.csv` - Complete taxonomy for each amplicon
- `extraction_stats.txt` - Detailed statistics

**Expected Runtime:** 5-30 minutes depending on database size

### Step 2: Validate Database

This script performs quality control checks:
- FASTA format validation
- Sequence length distribution
- GC content analysis
- Taxonomic completeness
- Consistency between FASTA and taxonomy files
- Sample sequence searches

```bash
python3 02_validate_database.py
```

**Output:** Validation report printed to screen

### Step 3: Create BLAST Database (Optional)

If your pipeline uses BLAST for taxonomic assignment:

```bash
python3 03_create_blast_db.py
```

**Output:**
- `12S_fish_db.*` - BLAST database files

## Output Files

### 1. `12S_fish_amplicons.fasta`

Clean FASTA file with headers in format:
```
>amplicon_000001|ACCESSION|Genus_species
GTYGGKAAAWCTCGTGCCAGC...CATAGTGGGGTATCTAATCCYAGTTTG
```

**Features:**
- Unique amplicon sequences only (duplicates removed)
- All sequences are 150-250 bp
- Clean, pipeline-compatible headers
- Fish taxa only

### 2. `12S_fish_taxonomy.csv`

Complete taxonomy information:

| Column | Description |
|--------|-------------|
| amplicon_id | Unique amplicon identifier (matches FASTA) |
| accession | GenBank accession number |
| species | Species name |
| genus | Genus name |
| family | Family name |
| order | Order name |
| class | Class name |
| phylum | Phylum name |
| kingdom | Kingdom name |
| sequence_length | Length of amplicon in bp |
| num_duplicates | Number of identical sequences found |

### 3. `extraction_stats.txt`

Summary statistics:
- Total sequences processed
- Fish sequences identified
- Amplicons successfully extracted
- Unique vs. duplicate amplicons

### 4. `12S_fish_db.*` (Optional)

BLAST database files for sequence assignment.

## Usage in Your eDNA Pipeline

### DADA2 Example

```R
library(dada2)

# Assign taxonomy using your reference database
taxa <- assignTaxonomy(
  seqs = seqtab.nochim,
  refFasta = "12S_fish_amplicons.fasta",
  taxLevels = c("Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species"),
  minBoot = 50
)

# Load full taxonomy metadata
tax_metadata <- read.csv("12S_fish_taxonomy.csv")
```

### BLAST Example

```bash
# Using command line
blastn \
  -db 12S_fish_db \
  -query your_asv_sequences.fasta \
  -outfmt "6 qseqid sseqid pident length evalue bitscore" \
  -max_target_seqs 5 \
  -num_threads 4 \
  -out blast_results.txt
```

### Python Example

```python
from Bio import SeqIO
import pandas as pd

# Load sequences
sequences = SeqIO.to_dict(SeqIO.parse("12S_fish_amplicons.fasta", "fasta"))

# Load taxonomy
taxonomy = pd.read_csv("12S_fish_taxonomy.csv")

# Query specific taxa
fish_families = taxonomy['family'].unique()
print(f"Database contains {len(fish_families)} fish families")

# Get sequences for specific family
family_data = taxonomy[taxonomy['family'] == 'Cyprinidae']
print(f"Found {len(family_data)} sequences from Cyprinidae")
```

## Customization

### Modify Target Region or Primers

Edit `01_extract_fish_12s.py`:

```python
# Change primers
PRIMERS = {
    'forward': 'YOUR_FORWARD_PRIMER',
    'reverse': 'YOUR_REVERSE_PRIMER'
}

# Change expected amplicon length
MIN_AMPLICON_LENGTH = 150  # Change as needed
MAX_AMPLICON_LENGTH = 250  # Change as needed
```

### Include/Exclude Taxa

Edit the `is_fish_taxon()` function in `01_extract_fish_12s.py`:

```python
def is_fish_taxon(taxonomy):
    fish_keywords = [
        'Actinopterygii',  # Add or remove taxa
        'Chondrichthyes',
        # Add more taxa here
    ]
    # ... rest of function
```

### Filter by Taxonomic Completeness

After generation, filter the taxonomy file:

```python
import pandas as pd

tax = pd.read_csv("12S_fish_taxonomy.csv")

# Keep only sequences with complete taxonomy
complete = tax[
    (tax['species'] != '') & 
    (tax['genus'] != '') & 
    (tax['family'] != '')
]

complete.to_csv("12S_fish_taxonomy_complete.csv", index=False)

# Extract corresponding sequences
from Bio import SeqIO
complete_ids = set(complete['amplicon_id'])

with open("12S_fish_amplicons_complete.fasta", "w") as out:
    for record in SeqIO.parse("12S_fish_amplicons.fasta", "fasta"):
        if record.id in complete_ids:
            SeqIO.write(record, out, "fasta")
```

## Troubleshooting

### Issue: No sequences extracted

**Possible causes:**
1. Input FASTA file not found
2. No fish sequences in the input
3. Primers don't match any sequences

**Solutions:**
- Check input file path
- Verify MIDORI2 file format
- Check primer sequences (including IUPAC codes)

### Issue: Low amplicon yield

**Possible causes:**
1. Strict length filters
2. Primer mismatch tolerance
3. Limited fish diversity in source database

**Solutions:**
- Adjust `MIN_AMPLICON_LENGTH` and `MAX_AMPLICON_LENGTH`
- Modify primer regex patterns to allow more mismatches
- Use updated MIDORI2 version

### Issue: Too many duplicate sequences

This is expected! Many species share identical 12S sequences in the target region. The pipeline automatically handles this by:
- Keeping unique sequences only
- Recording the number of duplicates
- Associating each sequence with representative taxonomy

### Issue: Missing taxonomy information

Some sequences may have incomplete taxonomy in MIDORI2. Options:
1. Use the sequences anyway (they're still valid reference sequences)
2. Filter to only complete taxonomy (see Customization section)
3. Manually curate important missing taxa

## Database Updates

To update your reference database:

1. Download new MIDORI2 release
2. Re-run the pipeline
3. Compare with previous version:

```bash
# Count sequences
grep -c "^>" 12S_fish_amplicons_old.fasta
grep -c "^>" 12S_fish_amplicons.fasta

# Check new taxa
diff <(cut -d',' -f3 12S_fish_taxonomy_old.csv | sort -u) \
     <(cut -d',' -f3 12S_fish_taxonomy.csv | sort -u)
```

## References

- **MiFish-U Primers:** Miya, M., et al. (2015). "MiFish, a set of universal PCR primers for metabarcoding environmental DNA from fishes." *Royal Society Open Science*, 2(7), 150088.

- **MIDORI2:** Machida, R. J., et al. (2023). "MIDORI2: A collection of quality controlled, preformatted, and regularly updated reference databases for taxonomic assignment of eukaryotic mitochondrial sequences." *Molecular Ecology Resources*.

## Citation

If you use this pipeline, please cite:
- MIDORI2 database
- MiFish primer paper (Miya et al. 2015)
- Your eDNA analysis pipeline (DADA2, QIIME2, etc.)

## Support

For issues or questions:
1. Check the troubleshooting section
2. Validate your input files
3. Review the extraction statistics

## License

This pipeline is provided as-is for research use. Please respect the licenses of:
- MIDORI2 database
- BioPython
- BLAST+ (if used)

---

**Last Updated:** November 2024  
**Version:** 1.0
