#!/bin/bash

# =============================================================================
# eDNA COMPLETE PIPELINE v3.2
# =============================================================================
# Full eDNA metabarcoding analysis pipeline:
#   1. Quality filtering (Trimmomatic)
#   2. Read merging (FLASH)
#   3. Primer removal (Cutadapt - LINKED ADAPTERS)
#   4. ASV/OTU generation (DADA2 or VSEARCH)
#   5. BLAST annotation
#   6. Species reports
#   7. Fish/Non-fish classification
#
# NEW IN v3.2:
# - --min-reads filter to exclude low-abundance detections per sample
# - Applies to species_by_sample.csv and fish_species.csv
# - Keeps _ALL versions for comparison
#
# Version: 3.2.0
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

VERSION="3.2.0"

# =============================================================================
# DEFAULTS
# =============================================================================

# MiFish-U primers
DEFAULT_FORWARD_PRIMER="GTYGGTAAAWCTCGTGCCAGC"
DEFAULT_REVERSE_PRIMER="CATAGTGGGGTATCTAATCCYAGTTTG"

DEFAULT_THREADS=4
DEFAULT_ASV_METHOD="dada2"
DEFAULT_MIN_IDENTITY=97
DEFAULT_MIN_ALIGNMENT=80

# DADA2
DEFAULT_DADA2_MAXEE=2
DEFAULT_DADA2_MINLEN=100
DEFAULT_DADA2_MAXLEN=250

# OTU
DEFAULT_CLUSTERING_IDENTITY=97

# Read filter (NEW in v3.2)
DEFAULT_MIN_READS=5

# Skip options
SKIP_BLAST=false

# Fish split option
FISH_SPLIT=false

# =============================================================================
# FUNCTIONS
# =============================================================================

show_usage() {
    cat << EOF
================================================================================
eDNA COMPLETE PIPELINE v${VERSION}
================================================================================

Complete eDNA metabarcoding analysis with species identification.

USAGE:
    $0 -i INPUT_DIR -o OUTPUT_DIR -d DATABASE_DIR [OPTIONS]

REQUIRED:
    -i, --input DIR           Input directory with sample folders
    -o, --output DIR          Output directory
    -d, --database DIR        Reference database directory (optional with --no-blast)
                              (must contain: *.fasta and *taxonomy*.csv)

PRIMER OPTIONS:
    --forward-primer SEQ      Forward primer (default: MiFish-U F)
    --reverse-primer SEQ      Reverse primer (default: MiFish-U R)

METHOD OPTIONS:
    --method METHOD           ASV method: dada2 or otus (default: dada2)
    --threads NUM             Number of threads (default: 4)

TAXONOMY FILTERING OPTIONS:
    --min-identity NUM        Minimum BLAST identity % for species reports (default: 97)
                              Lower values (e.g., 90) include more uncertain matches
                              Higher values (e.g., 99) only include confident matches
    --min-alignment NUM       Minimum alignment length in bp (default: 80)

READ COUNT FILTERING (NEW in v3.2):
    --min-reads NUM           Minimum reads per species per sample (default: 5)
                              Species with fewer reads in a sample are excluded
                              from species_by_sample.csv and fish_species.csv
                              Unfiltered versions (*_ALL.csv) are kept for comparison

DADA2 OPTIONS (when --method dada2):
    --max-ee NUM              Max expected errors (default: 2)
                              Higher = more permissive quality filtering
    --min-len NUM             Min ASV length in bp (default: 100)
    --max-len NUM             Max ASV length in bp (default: 250)

OTU OPTIONS (when --method otus):
    --cluster-id NUM          OTU clustering identity % (default: 97)
                              97% = species level, 95% = genus level
    --min-size NUM            Minimum reads per OTU (default: 2)

SKIP OPTIONS:
    --no-blast                Skip BLAST and report generation (ASV/OTU only)
                              Useful for quick ASV generation without taxonomy

CLASSIFICATION OPTIONS:
    --fish-split              Separate fish from non-fish species in output
                              Requires: fish_classification_reference.csv in Database/
                              Generates additional files:
                                • fish_species.csv
                                • non_fish_species.csv
                                • contamination_detected.csv

OUTPUT FILES:
    reports/
    ├── species_summary.csv           - All species with read counts (unfiltered)
    ├── species_by_sample.csv         - Species per sample (filtered by --min-reads)
    ├── species_by_sample_ALL.csv     - Species per sample (unfiltered, for comparison)
    ├── sample_by_sample_taxonomy.csv - All ASVs per sample with taxonomy
    ├── ASV_taxonomy.csv              - Taxonomy for each ASV
    └── (with --fish-split):
        ├── fish_species.csv          - Fish species only (filtered by --min-reads)
        ├── fish_species_ALL.csv      - Fish species (unfiltered, for comparison)
        ├── non_fish_species.csv      - Non-fish vertebrates
        └── contamination_detected.csv - Potential contaminants

EXAMPLES:
    # Standard DADA2 analysis with default settings
    $0 -i raw_data/ -o results/ -d reference_db/

    # Include lower confidence matches (90%+ identity)
    $0 -i raw_data/ -o results/ -d reference_db/ --min-identity 90

    # Strict species identification (99%+ identity)
    $0 -i raw_data/ -o results/ -d reference_db/ --min-identity 99 --min-alignment 150

    # Filter out low-abundance detections (min 10 reads per sample)
    $0 -i raw_data/ -o results/ -d reference_db/ --min-reads 10

    # Separate fish from non-fish species
    $0 -i raw_data/ -o results/ -d reference_db/ --fish-split

    # Combined: fish split with strict read filter
    $0 -i raw_data/ -o results/ -d reference_db/ --fish-split --min-reads 20

    # Use OTU clustering instead of DADA2
    $0 -i raw_data/ -o results/ -d reference_db/ --method otus --cluster-id 97

    # Custom primers with relaxed quality filtering
    $0 -i raw_data/ -o results/ -d reference_db/ \\
       --forward-primer "ACTGGGATTAGATACCCC" \\
       --reverse-primer "TAGAACAGGCTCCTCTAG" \\
       --max-ee 5

    # Generate ASVs only (skip BLAST and taxonomy) - no database needed
    $0 -i raw_data/ -o results/ --no-blast

EOF
}

reverse_complement() {
    echo "$1" | tr 'ATGCRYSWKMBDHVNatgcryswkmbdhvn' 'TACGYRSWMKVHDBNtacgyrswmkvhdbn' | rev
}

log_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required tool not found: $1"
        exit 1
    fi
}

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================

SEQUENCES_DIR=""
OUTPUT_DIR=""
DB_DIR=""
FORWARD_PRIMER="$DEFAULT_FORWARD_PRIMER"
REVERSE_PRIMER="$DEFAULT_REVERSE_PRIMER"
THREADS="$DEFAULT_THREADS"
ASV_METHOD="$DEFAULT_ASV_METHOD"
MIN_IDENTITY="$DEFAULT_MIN_IDENTITY"
MIN_ALIGNMENT="$DEFAULT_MIN_ALIGNMENT"
MIN_READS="$DEFAULT_MIN_READS"
CLUSTERING_IDENTITY="$DEFAULT_CLUSTERING_IDENTITY"
DADA2_MAXEE="$DEFAULT_DADA2_MAXEE"
DADA2_MINLEN="$DEFAULT_DADA2_MINLEN"
DADA2_MAXLEN="$DEFAULT_DADA2_MAXLEN"

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input) SEQUENCES_DIR="$2"; shift 2 ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        -d|--database) DB_DIR="$2"; shift 2 ;;
        --forward-primer) FORWARD_PRIMER="$2"; shift 2 ;;
        --reverse-primer) REVERSE_PRIMER="$2"; shift 2 ;;
        --method) ASV_METHOD="$2"; shift 2 ;;
        --threads) THREADS="$2"; shift 2 ;;
        --min-identity) MIN_IDENTITY="$2"; shift 2 ;;
        --min-alignment) MIN_ALIGNMENT="$2"; shift 2 ;;
        --min-reads) MIN_READS="$2"; shift 2 ;;
        --cluster-id) CLUSTERING_IDENTITY="$2"; shift 2 ;;
        --max-ee) DADA2_MAXEE="$2"; shift 2 ;;
        --min-len) DADA2_MINLEN="$2"; shift 2 ;;
        --max-len) DADA2_MAXLEN="$2"; shift 2 ;;
        --no-blast) SKIP_BLAST=true; shift ;;
        --fish-split) FISH_SPLIT=true; shift ;;
        -h|--help) show_usage; exit 0 ;;
        -v|--version) echo "v${VERSION}"; exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# Validate
if [[ -z "$SEQUENCES_DIR" || -z "$OUTPUT_DIR" ]]; then
    log_error "Input (-i) and output (-o) directories required"
    show_usage
    exit 1
fi

# Database is only required if not using --no-blast
if [[ "$SKIP_BLAST" != "true" && -z "$DB_DIR" ]]; then
    log_error "Database (-d) required (or use --no-blast to skip taxonomy)"
    show_usage
    exit 1
fi

[[ ! -d "$SEQUENCES_DIR" ]] && { log_error "Input not found: $SEQUENCES_DIR"; exit 1; }

# Find database files (only if BLAST is enabled)
DB_FASTA=""
DB_TAXONOMY=""
FISH_REFERENCE=""

if [[ "$SKIP_BLAST" != "true" ]]; then
    [[ ! -d "$DB_DIR" ]] && { log_error "Database not found: $DB_DIR"; exit 1; }
    DB_FASTA=$(ls "$DB_DIR"/*.fasta "$DB_DIR"/*.fa 2>/dev/null | head -1)
    DB_TAXONOMY=$(ls "$DB_DIR"/*taxonomy*.csv "$DB_DIR"/*_tax*.csv 2>/dev/null | head -1)
    [[ -z "$DB_FASTA" ]] && { log_error "No FASTA in $DB_DIR"; exit 1; }
    
    # Check for fish classification reference (for --fish-split)
    if [[ "$FISH_SPLIT" == "true" ]]; then
        FISH_REFERENCE=$(ls "$DB_DIR"/fish_classification_reference.csv "$DB_DIR"/fish_classification*.csv "$DB_DIR"/fish_reference*.csv 2>/dev/null | head -1)
        if [[ -z "$FISH_REFERENCE" ]]; then
            log_error "Fish classification reference not found in $DB_DIR"
            echo ""
            echo "  To use --fish-split, you need fish_classification_reference.csv"
            echo "  Generate it with: python build_fish_reference.py /path/to/ncbi_taxdump/"
            echo "  Then copy it to: $DB_DIR/"
            exit 1
        fi
    fi
fi

# Check dependencies
check_dependency trimmomatic
check_dependency flash
check_dependency cutadapt
check_dependency vsearch

# Only check BLAST dependencies if not skipping
if [[ "$SKIP_BLAST" != "true" ]]; then
    check_dependency blastn
    check_dependency makeblastdb
fi

if [[ "$ASV_METHOD" == "dada2" ]]; then
    if ! R --slave --quiet -e "library(dada2)" 2>/dev/null; then
        log_error "R package 'dada2' not installed"
        exit 1
    fi
fi

# =============================================================================
# SETUP
# =============================================================================

SEQUENCES_DIR=$(realpath "$SEQUENCES_DIR")
[[ -n "$DB_DIR" ]] && DB_DIR=$(realpath "$DB_DIR")
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

REV_RC=$(reverse_complement "$REVERSE_PRIMER")
FWD_LEN=${#FORWARD_PRIMER}
REV_LEN=${#REVERSE_PRIMER}

mkdir -p "$OUTPUT_DIR"/{intermediate,logs,taxonomy,reports}
mkdir -p "$OUTPUT_DIR/intermediate"/{01_trimmed,02_merged,03_primers_removed,04_asvs}

LOGFILE="$OUTPUT_DIR/logs/pipeline_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# Header
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              eDNA COMPLETE PIPELINE v${VERSION}                            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "📁 Input:    $SEQUENCES_DIR"
echo "📁 Output:   $OUTPUT_DIR"
if [[ -n "$DB_DIR" ]]; then
    echo "📁 Database: $DB_DIR"
else
    echo "📁 Database: (not required - --no-blast mode)"
fi
echo ""
echo "🧬 Primers:"
echo "   Forward (${FWD_LEN}bp): $FORWARD_PRIMER"
echo "   Reverse (${REV_LEN}bp): $REVERSE_PRIMER"
echo ""
echo "🔬 Method: $ASV_METHOD"
if [[ "$SKIP_BLAST" == "true" ]]; then
    echo "📊 BLAST: SKIPPED (--no-blast mode)"
else
    echo "📊 BLAST: min_identity=${MIN_IDENTITY}%, min_alignment=${MIN_ALIGNMENT}bp"
    echo "📊 Read filter: min_reads=${MIN_READS} per sample"
fi
if [[ "$FISH_SPLIT" == "true" ]]; then
    echo "🐟 Fish split: ENABLED"
    echo "   Reference: $(basename "$FISH_REFERENCE")"
fi
echo "⚙️  Threads: $THREADS"
echo ""

# =============================================================================
# STEP 0: DETECT SAMPLES
# =============================================================================

log_step "STEP 0: Detecting samples"

SAMPLES=()

for sample_folder in "$SEQUENCES_DIR"/*/; do
    [[ ! -d "$sample_folder" ]] && continue
    sample_name=$(basename "$sample_folder")
    [[ "$sample_name" == "Output"* ]] && continue
    
    r1_file=$(ls "$sample_folder"/*R1*.f*q* 2>/dev/null | head -1)
    r2_file=$(ls "$sample_folder"/*R2*.f*q* 2>/dev/null | head -1)
    
    if [[ -n "$r1_file" && -n "$r2_file" ]]; then
        SAMPLES+=("$sample_name")
        echo "   ✓ $sample_name"
    fi
done

[[ ${#SAMPLES[@]} -eq 0 ]] && { log_error "No samples found"; exit 1; }

echo ""
log_success "Found ${#SAMPLES[@]} samples"

# =============================================================================
# STEP 1: QUALITY FILTERING
# =============================================================================

log_step "STEP 1: Quality filtering (Trimmomatic)"

for sample in "${SAMPLES[@]}"; do
    echo "   Processing: $sample"
    
    r1_file=$(ls "$SEQUENCES_DIR/$sample"/*R1*.f*q* 2>/dev/null | head -1)
    r2_file=$(ls "$SEQUENCES_DIR/$sample"/*R2*.f*q* 2>/dev/null | head -1)
    
    trimmomatic PE -threads "$THREADS" -phred33 \
        "$r1_file" "$r2_file" \
        "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R1_paired.fq.gz" \
        "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R1_unpaired.fq.gz" \
        "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R2_paired.fq.gz" \
        "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R2_unpaired.fq.gz" \
        LEADING:3 TRAILING:3 SLIDINGWINDOW:4:20 MINLEN:50 \
        2>> "$OUTPUT_DIR/logs/trimmomatic.log"
done

log_success "Quality filtering complete"

# =============================================================================
# STEP 2: MERGE PAIRED READS
# =============================================================================

log_step "STEP 2: Merging paired reads (FLASH)"

for sample in "${SAMPLES[@]}"; do
    echo "   Merging: $sample"
    
    flash "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R1_paired.fq.gz" \
          "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R2_paired.fq.gz" \
          -o "$sample" -d "$OUTPUT_DIR/intermediate/02_merged" \
          -m 10 -M 300 -z -t "$THREADS" \
          2>> "$OUTPUT_DIR/logs/flash.log"
done

log_success "Read merging complete"

# =============================================================================
# STEP 3: PRIMER REMOVAL (CRITICAL!)
# =============================================================================

log_step "STEP 3: Removing primers (Cutadapt - LINKED ADAPTERS)"

echo ""
echo "   🔑 Using linked adapter syntax: ^FORWARD...REVERSE_RC"
echo "   🔑 Discarding reads without proper primer pairs"
echo ""

for sample in "${SAMPLES[@]}"; do
    merged="$OUTPUT_DIR/intermediate/02_merged/${sample}.extendedFrags.fastq.gz"
    [[ ! -f "$merged" ]] && continue
    
    echo "   Processing: $sample"
    
    # CRITICAL: Linked adapter syntax
    cutadapt \
        -g "^${FORWARD_PRIMER}...${REV_RC}" \
        -e 0.15 \
        --discard-untrimmed \
        --minimum-length 80 \
        --maximum-length 250 \
        -j "$THREADS" \
        -o "$OUTPUT_DIR/intermediate/03_primers_removed/${sample}_clean.fq.gz" \
        "$merged" \
        >> "$OUTPUT_DIR/logs/cutadapt_${sample}.log" 2>&1
    
    # Verify
    if [[ -f "$OUTPUT_DIR/intermediate/03_primers_removed/${sample}_clean.fq.gz" ]]; then
        count=$(zcat "$OUTPUT_DIR/intermediate/03_primers_removed/${sample}_clean.fq.gz" | wc -l)
        count=$((count / 4))
        first_seq=$(zcat "$OUTPUT_DIR/intermediate/03_primers_removed/${sample}_clean.fq.gz" | sed -n '2p')
        echo "      → $count reads, length ${#first_seq}bp"
    fi
done

log_success "Primer removal complete"

# =============================================================================
# STEP 4: ASV GENERATION
# =============================================================================

if [[ "$ASV_METHOD" == "dada2" ]]; then
    log_step "STEP 4: Generating ASVs (DADA2)"
    
    cat > "$OUTPUT_DIR/run_dada2.R" << 'DADA2_R'
library(dada2)
args <- commandArgs(trailingOnly = TRUE)
input_dir <- args[1]; output_dir <- args[2]; threads <- as.numeric(args[3])
max_ee <- as.numeric(args[4]); min_len <- as.numeric(args[5]); max_len <- as.numeric(args[6])

fnFs <- sort(list.files(input_dir, pattern = "_clean.fq.gz$", full.names = TRUE))
sample_names <- sapply(fnFs, function(x) gsub("_clean.fq.gz$", "", basename(x)))
names(fnFs) <- sample_names

cat(sprintf("Processing %d samples\n", length(fnFs)))

filtered_dir <- file.path(output_dir, "filtered")
dir.create(filtered_dir, showWarnings = FALSE, recursive = TRUE)
filtFs <- file.path(filtered_dir, paste0(sample_names, "_filt.fastq.gz"))

out <- filterAndTrim(fnFs, filtFs, maxN=0, maxEE=max_ee, truncQ=2,
                     minLen=min_len, maxLen=max_len, rm.phix=TRUE,
                     compress=TRUE, multithread=threads>1, verbose=FALSE)

exists <- file.exists(filtFs) & file.size(filtFs) > 20
filtFs <- filtFs[exists]; sample_names <- sample_names[exists]

errF <- learnErrors(filtFs, multithread=threads>1, verbose=FALSE)
derepFs <- derepFastq(filtFs, verbose=FALSE)
names(derepFs) <- sample_names
dadaFs <- dada(derepFs, err=errF, multithread=threads>1, verbose=FALSE)
seqtab <- makeSequenceTable(dadaFs)
seqtab_nochim <- removeBimeraDenovo(seqtab, method="consensus", multithread=threads>1, verbose=FALSE)

asv_seqs <- colnames(seqtab_nochim)
asv_ids <- paste0("ASV_", seq_along(asv_seqs))
writeLines(paste0(">", asv_ids, "\n", asv_seqs), file.path(output_dir, "asvs_final.fasta"))
colnames(seqtab_nochim) <- asv_ids
write.table(t(seqtab_nochim), file.path(output_dir, "asv_table.txt"), sep="\t", quote=FALSE, col.names=NA)

cat(sprintf("Generated %d ASVs\n", length(asv_ids)))
cat(sprintf("Mean length: %.0f bp\n", mean(nchar(asv_seqs))))
DADA2_R

    Rscript "$OUTPUT_DIR/run_dada2.R" \
        "$OUTPUT_DIR/intermediate/03_primers_removed" \
        "$OUTPUT_DIR/intermediate/04_asvs" \
        "$THREADS" "$DADA2_MAXEE" "$DADA2_MINLEN" "$DADA2_MAXLEN" \
        2>&1 | tee -a "$OUTPUT_DIR/logs/dada2.log"

else
    log_step "STEP 4: Generating OTUs (VSEARCH ${CLUSTERING_IDENTITY}%)"
    
    > "$OUTPUT_DIR/intermediate/04_asvs/combined.fasta"
    for sample in "${SAMPLES[@]}"; do
        zcat "$OUTPUT_DIR/intermediate/03_primers_removed/${sample}_clean.fq.gz" 2>/dev/null | \
            awk -v s="$sample" 'NR%4==1 {n++; print ">"s"."n";sample="s";"} NR%4==2 {print}' \
            >> "$OUTPUT_DIR/intermediate/04_asvs/combined.fasta"
    done
    
    cd "$OUTPUT_DIR/intermediate/04_asvs"
    vsearch --derep_fulllength combined.fasta --output unique.fasta --sizeout --threads "$THREADS" 2>/dev/null
    vsearch --sortbysize unique.fasta --output sorted.fasta --minsize 2 --threads "$THREADS" 2>/dev/null
    
    CLUSTER_THRESH=$(awk "BEGIN {printf \"%.2f\", $CLUSTERING_IDENTITY / 100}")
    vsearch --cluster_size sorted.fasta --id "$CLUSTER_THRESH" --centroids otus.fasta --relabel OTU_ --threads "$THREADS" 2>/dev/null
    vsearch --uchime_denovo otus.fasta --nonchimeras asvs_final.fasta --threads "$THREADS" 2>/dev/null
    vsearch --usearch_global combined.fasta --db asvs_final.fasta --id "$CLUSTER_THRESH" --otutabout asv_table.txt --threads "$THREADS" 2>/dev/null
    cd "$OUTPUT_DIR"
fi

ASV_FASTA="$OUTPUT_DIR/intermediate/04_asvs/asvs_final.fasta"
ASV_TABLE="$OUTPUT_DIR/intermediate/04_asvs/asv_table.txt"
ASV_COUNT=$(grep -c "^>" "$ASV_FASTA")

log_success "Generated $ASV_COUNT ASVs"

# Check if skipping BLAST
if [[ "$SKIP_BLAST" == "true" ]]; then
    # =============================================================================
    # SKIP BLAST - ASV ONLY MODE
    # =============================================================================
    
    log_step "Skipping BLAST (--no-blast mode)"
    echo "   ASV generation complete. BLAST and taxonomy assignment skipped."
    
    # Set variables for summary
    BLAST_HITS="N/A"
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎉 ASV Generation Complete (--no-blast mode)${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}📁 Results: $OUTPUT_DIR${NC}"
    echo ""
    
    # Dynamic terminology based on method
    if [[ "$ASV_METHOD" == "dada2" ]]; then
        UNIT_NAME="ASV"
        UNIT_PLURAL="ASVs"
    else
        UNIT_NAME="OTU"
        UNIT_PLURAL="OTUs"
    fi
    
    echo "📊 Output Files:"
    echo "  • intermediate/04_asvs/asvs_final.fasta   - ${UNIT_NAME} sequences (primer-free)"
    echo "  • intermediate/04_asvs/asv_table.txt     - ${UNIT_NAME} abundance matrix"
    echo ""
    echo "📊 Statistics:"
    echo "  • Samples processed: ${#SAMPLES[@]}"
    echo "  • Total ${UNIT_PLURAL}: $ASV_COUNT"
    echo ""
    echo "🔬 Analysis Method: $ASV_METHOD"
    if [[ "$ASV_METHOD" == "dada2" ]]; then
        echo "   └─ Exact sequence variants (ASVs) - single nucleotide resolution"
        echo "   └─ Parameters: maxEE=$DADA2_MAXEE, minLen=$DADA2_MINLEN, maxLen=$DADA2_MAXLEN"
    else
        echo "   └─ OTU clustering at ${CLUSTERING_IDENTITY}% similarity"
    fi
    echo ""
    echo "🧬 Primers used:"
    echo "   └─ Forward: $FORWARD_PRIMER"
    echo "   └─ Reverse: $REVERSE_PRIMER"
    echo ""
    echo "💡 To add taxonomy: re-run without --no-blast flag"
    echo ""
    echo "📋 Log file: $LOGFILE"
    echo ""
    echo -e "${GREEN}✨ Done! ✨${NC}"
    echo ""
    
    exit 0
fi

# =============================================================================
# STEP 5: BLAST ANNOTATION
# =============================================================================

log_step "STEP 5: BLAST taxonomy annotation"

# Build/verify BLAST database
# Remove any extension and add _blast
DB_BASENAME=$(basename "$DB_FASTA")
DB_BASENAME="${DB_BASENAME%.fasta}"
DB_BASENAME="${DB_BASENAME%.fa}"
DB_BLAST="$(dirname "$DB_FASTA")/${DB_BASENAME}_blast"

if [[ ! -f "${DB_BLAST}.nhr" ]]; then
    echo "   Building BLAST database..."
    # Note: -parse_seqids removed to avoid ID format issues
    makeblastdb -in "$DB_FASTA" -dbtype nucl -out "$DB_BLAST" 2>/dev/null
fi

echo "   Running BLAST..."
blastn -task blastn \
    -query "$ASV_FASTA" \
    -db "$DB_BLAST" \
    -out "$OUTPUT_DIR/taxonomy/blast_results.txt" \
    -outfmt "6 qseqid sseqid pident length qlen slen evalue bitscore" \
    -max_target_seqs 5 \
    -evalue 0.001 \
    -num_threads "$THREADS"

BLAST_HITS=$(wc -l < "$OUTPUT_DIR/taxonomy/blast_results.txt")
log_success "BLAST complete: $BLAST_HITS hits"

# =============================================================================
# STEP 6: GENERATE REPORTS
# =============================================================================

log_step "STEP 6: Generating species reports"

if [[ -n "$DB_TAXONOMY" ]]; then
    echo "   Using taxonomy: $(basename "$DB_TAXONOMY")"
else
    echo "   No taxonomy file - using sequence IDs only"
fi

# Generate reports with R
cat > "$OUTPUT_DIR/generate_reports.R" << 'REPORT_R'
suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
})

args <- commandArgs(trailingOnly = TRUE)
blast_file <- args[1]
taxonomy_file <- args[2]
asv_table_file <- args[3]
output_dir <- args[4]
min_identity <- as.numeric(args[5])
min_alignment <- as.numeric(args[6])
min_reads <- as.numeric(args[7])

cat("\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("PROCESSING BLAST RESULTS\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

# Check if BLAST file exists and is not empty
if (!file.exists(blast_file)) {
    cat("ERROR: BLAST results file not found!\n")
    quit(status = 1)
}

blast_lines <- readLines(blast_file, warn = FALSE)
if (length(blast_lines) == 0) {
    cat("ERROR: BLAST results file is empty!\n")
    quit(status = 1)
}

cat(sprintf("BLAST file has %d lines\n", length(blast_lines)))

# Check first line format
first_line <- blast_lines[1]
n_fields <- length(strsplit(first_line, "\t")[[1]])
cat(sprintf("First line has %d tab-separated fields\n", n_fields))

# Read BLAST results with appropriate number of columns
if (n_fields == 8) {
    col_names <- c("ASV_ID", "Subject_ID", "Identity", "Alignment_Length", 
                   "Query_Length", "Subject_Length", "E_value", "Bitscore")
} else if (n_fields == 12) {
    # Standard BLAST outfmt 6
    col_names <- c("ASV_ID", "Subject_ID", "Identity", "Alignment_Length", 
                   "Mismatches", "Gap_Opens", "Q_Start", "Q_End",
                   "S_Start", "S_End", "E_value", "Bitscore")
} else if (n_fields >= 4) {
    # At minimum need: query, subject, identity, length
    col_names <- c("ASV_ID", "Subject_ID", "Identity", "Alignment_Length")
    if (n_fields > 4) {
        col_names <- c(col_names, paste0("V", 5:n_fields))
    }
} else {
    cat(sprintf("ERROR: Unexpected BLAST format with %d fields\n", n_fields))
    cat(sprintf("First line: %s\n", first_line))
    quit(status = 1)
}

blast <- tryCatch({
    read.table(blast_file, sep = "\t", header = FALSE, stringsAsFactors = FALSE,
               col.names = col_names[1:n_fields], fill = TRUE)
}, error = function(e) {
    cat(sprintf("ERROR reading BLAST file: %s\n", e$message))
    return(NULL)
})

if (is.null(blast) || nrow(blast) == 0) {
    cat("ERROR: Could not read BLAST results\n")
    quit(status = 1)
}

# Ensure numeric columns are numeric
blast$Identity <- as.numeric(blast$Identity)
blast$Alignment_Length <- as.numeric(blast$Alignment_Length)

# Add missing columns if needed
if (!"Query_Length" %in% names(blast)) blast$Query_Length <- NA
if (!"Subject_Length" %in% names(blast)) blast$Subject_Length <- NA
if (!"E_value" %in% names(blast)) blast$E_value <- NA
if (!"Bitscore" %in% names(blast)) {
    blast$Bitscore <- blast$Identity * blast$Alignment_Length
} else {
    blast$Bitscore <- as.numeric(blast$Bitscore)
}

# CRITICAL: BLAST adds "lcl|" prefix to sequence IDs - strip it!
blast$Subject_ID <- gsub("^lcl\\|", "", blast$Subject_ID)

cat(sprintf("Total BLAST hits: %d\n", nrow(blast)))
cat(sprintf("Unique ASVs with hits: %d\n", length(unique(blast$ASV_ID))))

# Show sample of BLAST Subject_IDs for debugging
cat("\nSample Subject_IDs from BLAST:\n")
for (sid in head(unique(blast$Subject_ID), 3)) {
    cat(sprintf("  • %s\n", sid))
}

# Read taxonomy if available
taxonomy <- NULL
if (!is.na(taxonomy_file) && taxonomy_file != "NA" && file.exists(taxonomy_file)) {
    taxonomy <- tryCatch({
        read.csv(taxonomy_file, stringsAsFactors = FALSE)
    }, error = function(e) {
        cat(sprintf("Warning: Could not read taxonomy file: %s\n", e$message))
        return(NULL)
    })
    
    if (!is.null(taxonomy) && nrow(taxonomy) > 0) {
        cat(sprintf("\nTaxonomy entries loaded: %d\n", nrow(taxonomy)))
        cat(sprintf("Taxonomy columns: %s\n", paste(names(taxonomy), collapse=", ")))
        
        # Find ID column - try multiple options
        id_cols <- c("id", "ID", "amplicon_id", "accession", "Accession", "seqid")
        id_col <- NULL
        for (col in id_cols) {
            if (col %in% names(taxonomy)) {
                id_col <- col
                break
            }
        }
        
        if (is.null(id_col)) {
            id_col <- names(taxonomy)[1]
            cat(sprintf("Using first column as ID: %s\n", id_col))
        }
        
        # Rename to Subject_ID for joining
        names(taxonomy)[names(taxonomy) == id_col] <- "Subject_ID"
        
        # Show sample taxonomy IDs
        cat("\nSample IDs from taxonomy:\n")
        for (tid in head(taxonomy$Subject_ID, 3)) {
            cat(sprintf("  • %s\n", tid))
        }
        
        # Check for matches
        matches <- sum(blast$Subject_ID %in% taxonomy$Subject_ID)
        cat(sprintf("\nDirect ID matches: %d / %d (%.1f%%)\n", 
                    matches, nrow(blast), 100*matches/nrow(blast)))
        
        # If no direct matches, try multiple matching strategies
        if (matches < nrow(blast) * 0.5) {
            cat("\nTrying alternative matching strategies...\n")
            
            # Strategy 1: Extract accession from BLAST ID and match
            blast$accession_extracted <- sapply(blast$Subject_ID, function(x) {
                m <- regmatches(x, regexpr("[A-Z]{1,2}_?\\d+\\.?\\d*", x))
                if (length(m) > 0) return(m[1])
                return(x)
            })
            
            if ("accession" %in% names(taxonomy)) {
                taxonomy$accession_clean <- gsub("^(gb|emb|dbj|ref)\\|", "", taxonomy$accession)
                matches_acc <- sum(blast$accession_extracted %in% taxonomy$accession_clean)
                cat(sprintf("Accession-based matches: %d\n", matches_acc))
                
                if (matches_acc > matches) {
                    blast <- blast %>%
                        left_join(taxonomy %>% select(-Subject_ID), 
                                  by = c("accession_extracted" = "accession_clean"))
                    matches <- matches_acc
                }
            }
            
            # Strategy 2: Try removing prefix
            if (matches < nrow(blast) * 0.5) {
                blast$Subject_ID_base <- gsub("^[^_]+_", "", blast$Subject_ID)
                taxonomy$Subject_ID_base <- gsub("^[^_]+_", "", taxonomy$Subject_ID)
                
                matches2 <- sum(blast$Subject_ID_base %in% taxonomy$Subject_ID_base)
                cat(sprintf("Base ID matches (prefix stripped): %d\n", matches2))
                
                if (matches2 > matches) {
                    blast$Subject_ID_orig <- blast$Subject_ID
                    blast$Subject_ID <- blast$Subject_ID_base
                    taxonomy$Subject_ID <- taxonomy$Subject_ID_base
                    matches <- matches2
                }
            }
        }
    }
}

# Get best hit per ASV (highest bitscore)
best_hits <- blast %>%
    group_by(ASV_ID) %>%
    arrange(desc(Bitscore), desc(Identity)) %>%
    slice(1) %>%
    ungroup()

cat(sprintf("\nBest hits (one per ASV): %d\n", nrow(best_hits)))

# Show alignment length distribution
cat(sprintf("Alignment lengths: min=%d, max=%d, mean=%.0f\n",
            min(best_hits$Alignment_Length), 
            max(best_hits$Alignment_Length),
            mean(best_hits$Alignment_Length)))

cat(sprintf("Identity range: %.1f%% - %.1f%%\n",
            min(best_hits$Identity), max(best_hits$Identity)))

# Add taxonomy if available and not already joined
if (!is.null(taxonomy) && !"species" %in% names(best_hits)) {
    best_hits <- best_hits %>%
        left_join(taxonomy, by = "Subject_ID")
    
    has_species <- sum(!is.na(best_hits$species) & best_hits$species != "")
    cat(sprintf("ASVs with species from taxonomy: %d\n", has_species))
}

# Add confidence levels
best_hits <- best_hits %>%
    mutate(
        Confidence = case_when(
            Identity >= 99 & Alignment_Length >= 150 ~ "Very_High",
            Identity >= 97 & Alignment_Length >= 100 ~ "High",
            Identity >= 95 & Alignment_Length >= 80 ~ "Medium",
            Identity >= 90 ~ "Low",
            TRUE ~ "Very_Low"
        )
    )

# Fill missing species - use Subject_ID if no taxonomy
if (!"species" %in% names(best_hits)) {
    best_hits$species <- best_hits$Subject_ID
} else {
    best_hits$species[is.na(best_hits$species) | best_hits$species == ""] <- 
        best_hits$Subject_ID[is.na(best_hits$species) | best_hits$species == ""]
}

# Extract genus from species
best_hits$genus <- sapply(best_hits$species, function(sp) {
    if (!is.na(sp) && grepl(" ", sp)) {
        strsplit(sp, " ")[[1]][1]
    } else if (!is.na(sp) && grepl("_", sp)) {
        strsplit(sp, "_")[[1]][1]
    } else {
        sp
    }
})

# Filter high-confidence hits
high_conf <- best_hits %>%
    filter(Identity >= min_identity, Alignment_Length >= min_alignment)

cat(sprintf("\nHigh-confidence hits (>=%d%%, >=%dbp): %d\n", 
            min_identity, min_alignment, nrow(high_conf)))

# Save ASV taxonomy (ALL ASVs)
write.csv(best_hits %>%
              select(ASV_ID, species, 
                     any_of(c("genus", "family", "order", "class", "phylum")),
                     Identity, Alignment_Length, Confidence, Subject_ID, 
                     any_of(c("E_value"))),
          file.path(output_dir, "ASV_taxonomy.csv"), row.names = FALSE)
cat(sprintf("Saved: %s\n", file.path(output_dir, "ASV_taxonomy.csv")))

# Read ASV table
asv_table <- NULL
samples <- c()
if (file.exists(asv_table_file)) {
    asv_table <- tryCatch({
        read.table(asv_table_file, header = TRUE, row.names = 1, 
                   sep = "\t", check.names = FALSE)
    }, error = function(e) {
        cat(sprintf("Warning: Could not read ASV table: %s\n", e$message))
        return(NULL)
    })
    
    if (!is.null(asv_table) && nrow(asv_table) > 0) {
        samples <- colnames(asv_table)
        cat(sprintf("\nASV table: %d ASVs x %d samples\n", nrow(asv_table), ncol(asv_table)))
        cat(sprintf("Samples: %s\n", paste(samples, collapse=", ")))
    }
}

# Create species summary - FILTERED by min_identity (NOT by min_reads - for comparison)
# Ensure Identity is numeric
best_hits$Identity <- as.numeric(best_hits$Identity)
best_hits$Alignment_Length <- as.numeric(best_hits$Alignment_Length)

# Filtered species summary (respects --min-identity and --min-alignment, but NOT --min-reads)
species_summary <- best_hits %>%
    filter(!is.na(species) & species != "") %>%
    filter(Identity >= min_identity & Alignment_Length >= min_alignment) %>%
    group_by(species) %>%
    summarise(
        ASV_Count = n(),
        Mean_Identity = round(mean(Identity, na.rm = TRUE), 2),
        Mean_Alignment = round(mean(Alignment_Length, na.rm = TRUE), 0),
        Best_Confidence = first(Confidence[order(match(Confidence, 
                                c("Very_High", "High", "Medium", "Low", "Very_Low")))]),
        .groups = 'drop'
    ) %>%
    mutate(
        Mean_Identity = ifelse(is.nan(Mean_Identity), 0, Mean_Identity),
        Mean_Alignment = ifelse(is.nan(Mean_Alignment), 0, Mean_Alignment)
    ) %>%
    arrange(desc(ASV_Count))

# Also create unfiltered summary for reference
species_summary_all <- best_hits %>%
    filter(!is.na(species) & species != "") %>%
    group_by(species) %>%
    summarise(
        ASV_Count = n(),
        Mean_Identity = round(mean(Identity, na.rm = TRUE), 2),
        Mean_Alignment = round(mean(Alignment_Length, na.rm = TRUE), 0),
        Best_Confidence = first(Confidence[order(match(Confidence, 
                                c("Very_High", "High", "Medium", "Low", "Very_Low")))]),
        .groups = 'drop'
    ) %>%
    mutate(
        Mean_Identity = ifelse(is.nan(Mean_Identity), 0, Mean_Identity),
        Mean_Alignment = ifelse(is.nan(Mean_Alignment), 0, Mean_Alignment)
    ) %>%
    arrange(desc(ASV_Count))

# Add read counts if ASV table available
if (!is.null(asv_table) && nrow(asv_table) > 0) {
    asv_reads <- data.frame(
        ASV_ID = rownames(asv_table),
        Total_Reads = rowSums(asv_table),
        stringsAsFactors = FALSE
    )
    
    # Filtered reads (for filtered species_summary)
    species_reads_filtered <- best_hits %>%
        filter(Identity >= min_identity & Alignment_Length >= min_alignment) %>%
        left_join(asv_reads, by = "ASV_ID") %>%
        group_by(species) %>%
        summarise(Total_Reads = sum(Total_Reads, na.rm = TRUE), 
                  Samples_Present = n_distinct(ASV_ID),
                  .groups = 'drop')
    
    species_summary <- species_summary %>%
        left_join(species_reads_filtered, by = "species") %>%
        arrange(desc(Total_Reads))
    
    # Unfiltered reads (for ALL species_summary)
    species_reads_all <- best_hits %>%
        left_join(asv_reads, by = "ASV_ID") %>%
        group_by(species) %>%
        summarise(Total_Reads = sum(Total_Reads, na.rm = TRUE), 
                  Samples_Present = n_distinct(ASV_ID),
                  .groups = 'drop')
    
    species_summary_all <- species_summary_all %>%
        left_join(species_reads_all, by = "species") %>%
        arrange(desc(Total_Reads))
}

# Save filtered summary (main output - NOT filtered by min_reads, for comparison)
write.csv(species_summary, file.path(output_dir, "species_summary.csv"), row.names = FALSE)
cat(sprintf("Saved: %s\n", file.path(output_dir, "species_summary.csv")))

# Save unfiltered summary (for reference)
write.csv(species_summary_all, file.path(output_dir, "species_summary_ALL.csv"), row.names = FALSE)
cat(sprintf("Saved: %s (unfiltered)\n", file.path(output_dir, "species_summary_ALL.csv")))

# Sample-level analysis
if (!is.null(asv_table) && nrow(asv_table) > 0 && length(samples) > 0) {
    
    # Convert ASV table to long format
    asv_long <- asv_table %>%
        tibble::rownames_to_column("ASV_ID") %>%
        pivot_longer(-ASV_ID, names_to = "Sample", values_to = "Reads") %>%
        filter(Reads > 0)
    
    cat(sprintf("ASV observations (non-zero): %d\n", nrow(asv_long)))
    
    # Join with taxonomy
    asv_with_tax <- asv_long %>%
        left_join(best_hits %>% 
                      select(ASV_ID, species, any_of("genus"), Identity, Alignment_Length, Confidence),
                  by = "ASV_ID")
    
    # Sample by sample taxonomy (ALL ASVs - for reference)
    sample_by_sample <- asv_with_tax %>%
        mutate(species = ifelse(is.na(species) | species == "", "Unclassified", species)) %>%
        arrange(Sample, desc(Reads)) %>%
        select(Sample, ASV_ID, species, any_of("genus"), Reads, Identity, Confidence)
    
    write.csv(sample_by_sample, file.path(output_dir, "sample_by_sample_taxonomy.csv"), 
              row.names = FALSE)
    cat(sprintf("Saved: %s\n", file.path(output_dir, "sample_by_sample_taxonomy.csv")))
    
    # Species by sample (aggregated) - UNFILTERED version (for comparison)
    species_by_sample_all <- asv_with_tax %>%
        filter(!is.na(species) & species != "" & species != "Unclassified") %>%
        filter(Identity >= min_identity & Alignment_Length >= min_alignment) %>%
        group_by(Sample, species) %>%
        summarise(
            Total_Reads = sum(Reads),
            ASV_Count = n_distinct(ASV_ID),
            Mean_Identity = round(mean(Identity, na.rm = TRUE), 2),
            .groups = 'drop'
        ) %>%
        arrange(Sample, desc(Total_Reads))
    
    write.csv(species_by_sample_all, file.path(output_dir, "species_by_sample_ALL.csv"), 
              row.names = FALSE)
    cat(sprintf("Saved: %s (unfiltered by min-reads)\n", file.path(output_dir, "species_by_sample_ALL.csv")))
    
    # Species by sample - FILTERED by min_reads (main output)
    species_by_sample <- species_by_sample_all %>%
        filter(Total_Reads >= min_reads)
    
    write.csv(species_by_sample, file.path(output_dir, "species_by_sample.csv"), 
              row.names = FALSE)
    cat(sprintf("Saved: %s (filtered: min_reads >= %d)\n", file.path(output_dir, "species_by_sample.csv"), min_reads))
    
    # Report filtering effect
    removed_count <- nrow(species_by_sample_all) - nrow(species_by_sample)
    cat(sprintf("\n📊 Read filter effect: %d species-sample detections removed (< %d reads)\n", 
                removed_count, min_reads))
    
    # Print per-sample summary (using filtered results)
    cat("\n")
    cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    cat(sprintf("RESULTS BY SAMPLE (filtered: identity >= %d%%, alignment >= %dbp, reads >= %d)\n", 
                min_identity, min_alignment, min_reads))
    cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    
    for (samp in unique(samples)) {
        samp_species <- species_by_sample %>% filter(Sample == samp)
        samp_species_all <- species_by_sample_all %>% filter(Sample == samp)
        samp_reads <- sum(asv_long$Reads[asv_long$Sample == samp])
        if (nrow(samp_species) > 0) {
            cat(sprintf("  %s: %d species (%d before filter), %d total reads\n", 
                        samp, nrow(samp_species), nrow(samp_species_all), samp_reads))
        } else {
            cat(sprintf("  %s: 0 classified species (%d before filter), %d total reads\n", 
                        samp, nrow(samp_species_all), samp_reads))
        }
    }
}

# Print species summary
cat("\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat(sprintf("TOP SPECIES DETECTED (filtered: identity >= %d%%, alignment >= %dbp)\n", 
            min_identity, min_alignment))
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat(sprintf("Total species passing filter: %d (unfiltered: %d)\n\n", 
            nrow(species_summary), nrow(species_summary_all)))

top_n <- min(20, nrow(species_summary))
if (top_n > 0) {
    for (i in 1:top_n) {
        sp <- species_summary$species[i]
        n_asv <- species_summary$ASV_Count[i]
        id <- species_summary$Mean_Identity[i]
        aln <- species_summary$Mean_Alignment[i]
        conf <- species_summary$Best_Confidence[i]
        reads <- ifelse("Total_Reads" %in% names(species_summary), 
                        species_summary$Total_Reads[i], NA)
        
        # Truncate long species names
        sp_display <- ifelse(nchar(sp) > 35, paste0(substr(sp, 1, 32), "..."), sp)
        
        if (!is.na(reads)) {
            cat(sprintf("  %2d. %-35s %3d ASVs %7d reads  %.1f%% [%s]\n", 
                        i, sp_display, n_asv, reads, id, conf))
        } else {
            cat(sprintf("  %2d. %-35s %3d ASVs  %.1f%% [%s]\n", 
                        i, sp_display, n_asv, id, conf))
        }
    }
}
cat("\n")
cat("Reports generated successfully!\n")
REPORT_R

Rscript "$OUTPUT_DIR/generate_reports.R" \
    "$OUTPUT_DIR/taxonomy/blast_results.txt" \
    "${DB_TAXONOMY:-NA}" \
    "$ASV_TABLE" \
    "$OUTPUT_DIR/reports" \
    "$MIN_IDENTITY" \
    "$MIN_ALIGNMENT" \
    "$MIN_READS" \
    2>&1 | tee -a "$OUTPUT_DIR/logs/reports.log"

log_success "Reports generated"

# =============================================================================
# STEP 7: FISH/NON-FISH CLASSIFICATION (if --fish-split enabled)
# =============================================================================

if [[ "$FISH_SPLIT" == "true" ]]; then
    log_step "STEP 7: Fish/Non-fish Classification"
    
    echo "   Using reference: $(basename "$FISH_REFERENCE")"
    
    # Generate fish split reports with R
    cat > "$OUTPUT_DIR/fish_split.R" << 'FISHSPLIT_R'
suppressPackageStartupMessages({
    library(dplyr)
})

args <- commandArgs(trailingOnly = TRUE)
species_file <- args[1]
fish_reference_file <- args[2]
output_dir <- args[3]
min_reads <- as.numeric(args[4])

cat("\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("FISH/NON-FISH CLASSIFICATION\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

# Read species data
species_data <- read.csv(species_file, stringsAsFactors = FALSE)
cat(sprintf("Species to classify: %d\n", nrow(species_data)))

# Read fish reference
fish_ref <- read.csv(fish_reference_file, stringsAsFactors = FALSE)
cat(sprintf("Fish reference entries: %d\n", nrow(fish_ref)))

# Check fish reference structure
cat(sprintf("Fish reference columns: %s\n", paste(names(fish_ref), collapse=", ")))

# Count by category in reference
if ("category" %in% names(fish_ref)) {
    ref_summary <- table(fish_ref$category)
    cat("\nReference database composition:\n")
    for (cat_name in names(ref_summary)) {
        cat(sprintf("  %s: %d\n", cat_name, ref_summary[cat_name]))
    }
}

# Standardize species names for matching (lowercase, trim whitespace)
species_data$species_clean <- trimws(tolower(species_data$species))
fish_ref$species_clean <- trimws(tolower(fish_ref$species))

# Match species against reference
species_data <- species_data %>%
    left_join(
        fish_ref %>% select(species_clean, category, is_fish, is_contamination, 
                           any_of(c("family", "order", "class"))),
        by = "species_clean"
    )

# Fill in missing classifications
species_data$category[is.na(species_data$category)] <- "Unknown"
species_data$is_fish[is.na(species_data$is_fish)] <- FALSE
species_data$is_contamination[is.na(species_data$is_contamination)] <- FALSE

# Convert logical if needed
species_data$is_fish <- as.logical(species_data$is_fish)
species_data$is_contamination <- as.logical(species_data$is_contamination)

# Override category for contamination
species_data$category[species_data$is_contamination == TRUE] <- "Contamination"

# Summary
cat("\n")
cat("Classification Results:\n")
cat(sprintf("  🐟 Fish species:        %d\n", sum(species_data$is_fish == TRUE)))
cat(sprintf("  🦎 Non-fish species:    %d\n", sum(species_data$category == "Non-fish")))
cat(sprintf("  ⚠️  Contamination:       %d\n", sum(species_data$is_contamination == TRUE)))
cat(sprintf("  ❓ Unknown:             %d\n", sum(species_data$category == "Unknown")))

# Remove helper column before saving
species_data$species_clean <- NULL

# Split into separate files
fish_species_all <- species_data %>% 
    filter(is_fish == TRUE) %>%
    arrange(desc(Total_Reads))

non_fish_species <- species_data %>% 
    filter(category == "Non-fish") %>%
    arrange(desc(Total_Reads))

contamination <- species_data %>% 
    filter(is_contamination == TRUE) %>%
    arrange(desc(Total_Reads))

unknown_species <- species_data %>%
    filter(category == "Unknown") %>%
    arrange(desc(Total_Reads))

# Apply min_reads filter for fish_species (main output)
fish_species <- fish_species_all %>%
    filter(Total_Reads >= min_reads)

# Save files
# Fish species - UNFILTERED (for comparison)
write.csv(fish_species_all, file.path(output_dir, "fish_species_ALL.csv"), row.names = FALSE)
cat(sprintf("\nSaved: fish_species_ALL.csv (%d species, unfiltered)\n", nrow(fish_species_all)))

# Fish species - FILTERED by min_reads (main output)
write.csv(fish_species, file.path(output_dir, "fish_species.csv"), row.names = FALSE)
cat(sprintf("Saved: fish_species.csv (%d species, filtered: Total_Reads >= %d)\n", nrow(fish_species), min_reads))

# Report filtering effect
removed_fish <- nrow(fish_species_all) - nrow(fish_species)
if (removed_fish > 0) {
    cat(sprintf("  └─ %d fish species removed by min-reads filter\n", removed_fish))
}

write.csv(non_fish_species, file.path(output_dir, "non_fish_species.csv"), row.names = FALSE)
cat(sprintf("Saved: non_fish_species.csv (%d species)\n", nrow(non_fish_species)))

write.csv(contamination, file.path(output_dir, "contamination_detected.csv"), row.names = FALSE)
cat(sprintf("Saved: contamination_detected.csv (%d species)\n", nrow(contamination)))

if (nrow(unknown_species) > 0) {
    write.csv(unknown_species, file.path(output_dir, "unknown_classification.csv"), row.names = FALSE)
    cat(sprintf("Saved: unknown_classification.csv (%d species)\n", nrow(unknown_species)))
}

# Print top fish species (filtered)
if (nrow(fish_species) > 0) {
    cat("\n")
    cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    cat(sprintf("TOP FISH SPECIES DETECTED (filtered: Total_Reads >= %d)\n", min_reads))
    cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    
    top_n <- min(15, nrow(fish_species))
    for (i in 1:top_n) {
        sp <- fish_species$species[i]
        reads <- fish_species$Total_Reads[i]
        fam <- ifelse("family" %in% names(fish_species) && !is.na(fish_species$family[i]), 
                      fish_species$family[i], "")
        
        sp_display <- ifelse(nchar(sp) > 35, paste0(substr(sp, 1, 32), "..."), sp)
        
        if (fam != "") {
            cat(sprintf("  %2d. %-35s %7d reads  [%s]\n", i, sp_display, reads, fam))
        } else {
            cat(sprintf("  %2d. %-35s %7d reads\n", i, sp_display, reads))
        }
    }
}

# Print contamination if any
if (nrow(contamination) > 0) {
    cat("\n")
    cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    cat("⚠️  CONTAMINATION DETECTED\n")
    cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    
    for (i in 1:nrow(contamination)) {
        sp <- contamination$species[i]
        reads <- contamination$Total_Reads[i]
        cat(sprintf("  ⚠️  %-35s %7d reads\n", sp, reads))
    }
}

cat("\n")
cat("Fish/Non-fish classification complete!\n")
FISHSPLIT_R

    Rscript "$OUTPUT_DIR/fish_split.R" \
        "$OUTPUT_DIR/reports/species_summary.csv" \
        "$FISH_REFERENCE" \
        "$OUTPUT_DIR/reports" \
        "$MIN_READS" \
        2>&1 | tee -a "$OUTPUT_DIR/logs/fish_split.log"
    
    log_success "Fish/Non-fish classification complete"
fi

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Pipeline completed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}📁 Results: $OUTPUT_DIR${NC}"
echo ""

# Dynamic terminology based on method
if [[ "$ASV_METHOD" == "dada2" ]]; then
    UNIT_NAME="ASV"
    UNIT_PLURAL="ASVs"
    UNIT_DIR="04_asvs"
    UNIT_FILE="asvs_final.fasta"
    TABLE_FILE="asv_table"
else
    UNIT_NAME="OTU"
    UNIT_PLURAL="OTUs"
    UNIT_DIR="04_asvs"
    UNIT_FILE="asvs_final.fasta"
    TABLE_FILE="asv_table"
fi

echo "📊 Final Reports (in reports/):"
echo "  • species_summary.csv                   - Species list (filtered by identity/alignment)"
echo "  • species_by_sample.csv                 - Species per sample (filtered by min-reads)"
echo "  • species_by_sample_ALL.csv             - Species per sample (unfiltered, for comparison)"
echo "  • species_summary_ALL.csv               - All species (unfiltered, for reference)"
echo "  • sample_by_sample_taxonomy.csv         - All ${UNIT_PLURAL} with taxonomy per sample"
echo "  • ${UNIT_NAME}_taxonomy.csv                 - Taxonomy assignment per ${UNIT_NAME}"

if [[ "$FISH_SPLIT" == "true" ]]; then
    echo ""
    echo "🐟 Fish Classification Reports:"
    echo "  • fish_species.csv                      - Fish species (filtered by min-reads)"
    echo "  • fish_species_ALL.csv                  - Fish species (unfiltered, for comparison)"
    echo "  • non_fish_species.csv                  - Non-fish vertebrates"
    echo "  • contamination_detected.csv            - Potential contaminants"
    if [[ -f "$OUTPUT_DIR/reports/unknown_classification.csv" ]]; then
        echo "  • unknown_classification.csv            - Species not in reference"
    fi
fi

echo ""
echo "📁 Intermediate Files:"
echo "  • intermediate/${UNIT_DIR}/${UNIT_FILE}      - Final ${UNIT_NAME} sequences (primer-free)"
echo "  • intermediate/${UNIT_DIR}/${TABLE_FILE}.txt - ${UNIT_NAME} abundance matrix"
echo "  • taxonomy/blast_results.txt                 - Raw BLAST output"
echo ""
echo "📊 Pipeline Statistics:"
echo "  • Samples processed: ${#SAMPLES[@]}"
echo "  • Total ${UNIT_PLURAL}: $ASV_COUNT"
echo "  • BLAST hits: $BLAST_HITS"
if [[ -f "$OUTPUT_DIR/reports/species_summary.csv" ]]; then
    SPECIES_COUNT=$(tail -n +2 "$OUTPUT_DIR/reports/species_summary.csv" 2>/dev/null | wc -l)
    SPECIES_COUNT=${SPECIES_COUNT:-0}
    SPECIES_ALL=$(tail -n +2 "$OUTPUT_DIR/reports/species_summary_ALL.csv" 2>/dev/null | wc -l)
    SPECIES_ALL=${SPECIES_ALL:-0}
    echo "  • Species identified: $SPECIES_COUNT (filtered) / $SPECIES_ALL (total)"
fi

if [[ "$FISH_SPLIT" == "true" && -f "$OUTPUT_DIR/reports/fish_species.csv" ]]; then
    FISH_COUNT=$(tail -n +2 "$OUTPUT_DIR/reports/fish_species.csv" 2>/dev/null | wc -l)
    FISH_COUNT=${FISH_COUNT:-0}
    FISH_ALL=$(tail -n +2 "$OUTPUT_DIR/reports/fish_species_ALL.csv" 2>/dev/null | wc -l)
    FISH_ALL=${FISH_ALL:-0}
    CONTAM_COUNT=$(tail -n +2 "$OUTPUT_DIR/reports/contamination_detected.csv" 2>/dev/null | wc -l)
    CONTAM_COUNT=${CONTAM_COUNT:-0}
    echo "  • Fish species: $FISH_COUNT (filtered) / $FISH_ALL (total)"
    echo "  • Contamination detected: $CONTAM_COUNT"
fi

echo ""
echo "🔬 Analysis Method: $ASV_METHOD"
if [[ "$ASV_METHOD" == "dada2" ]]; then
    echo "   └─ Exact sequence variants (ASVs) - single nucleotide resolution"
    echo "   └─ Parameters: maxEE=$DADA2_MAXEE, minLen=$DADA2_MINLEN, maxLen=$DADA2_MAXLEN"
else
    echo "   └─ OTU clustering at ${CLUSTERING_IDENTITY}% similarity"
fi
echo ""
echo "🔍 Filter Settings:"
echo "   └─ Minimum identity: ${MIN_IDENTITY}%"
echo "   └─ Minimum alignment: ${MIN_ALIGNMENT}bp"
echo "   └─ Minimum reads per sample: ${MIN_READS}"
echo "   └─ To change: use --min-identity, --min-alignment, --min-reads options"
echo ""
echo "🧬 Primers used (MiFish-U 12S):"
echo "   └─ Forward (${#FORWARD_PRIMER}bp): $FORWARD_PRIMER"
echo "   └─ Reverse (${#REVERSE_PRIMER}bp): $REVERSE_PRIMER"
echo ""
echo "📋 Log file: $LOGFILE"
echo ""
echo "💡 Tips:"
echo "   • To include lower confidence matches: --min-identity 90"
echo "   • For strict species-level ID only: --min-identity 99 --min-alignment 150"
echo "   • To change read threshold: --min-reads 10 (current: ${MIN_READS})"
echo "   • Check *_ALL.csv files for unfiltered results"
if [[ "$FISH_SPLIT" != "true" ]]; then
    echo "   • To separate fish from non-fish: --fish-split"
fi
echo ""
echo -e "${GREEN}✨ Analysis complete! ✨${NC}"
echo ""
