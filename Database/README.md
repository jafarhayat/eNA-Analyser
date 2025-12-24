# Database Setup

## Required Files

1. **Reference sequences** (FASTA format)
   - File: `*.fasta` or `*.fa`
   - Format: Standard FASTA with sequence IDs

2. **Taxonomy mapping** (CSV format) - Optional but recommended
   - File: Should contain "taxonomy" in filename
   - Required columns: `id`, `species`, `genus`

## Example Files

### FASTA Format
```
>MiFish_12S_001
ACTGGGATTAGATACCCCACTATGCTTAG...
>MiFish_12S_002
ACTGGGATTAGATACCCCACTATGCTTAT...
```

### Taxonomy CSV Format
```csv
id,species,genus,family,order,class,phylum
MiFish_12S_001,Gadus morhua,Gadus,Gadidae,Gadiformes,Actinopteri,Chordata
MiFish_12S_002,Salmo salar,Salmo,Salmonidae,Salmoniformes,Actinopteri,Chordata
```

## Important Notes

1. **ID Matching**: The `id` column in taxonomy must match FASTA headers exactly
2. **Primer-free sequences**: Database sequences should NOT contain primer regions
3. **BLAST database**: Will be automatically built during installation

## Manual BLAST Database Build

```bash
makeblastdb -in your_sequences.fasta -dbtype nucl -out your_sequences_blast
```
