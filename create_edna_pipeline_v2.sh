#!/bin/bash

# eNA 12S Pipeline v2 - GitHub Package Creator
# Production-ready package with bulletproof installation

set -e

echo "🚀 Creating eDNA 12S Pipeline v2 Package"
echo "========================================="

PACKAGE_NAME="eNA-12S-Pipeline"
VERSION="2.0.0"

# Remove old package if exists
if [[ -d "$PACKAGE_NAME" ]]; then
    echo "🗑️  Removing old package..."
    rm -rf "$PACKAGE_NAME"
fi

echo "📁 Creating package structure..."
mkdir -p "$PACKAGE_NAME"/{Database,scripts,config,test_data/samples,docs,.github/workflows}

# ============================================================================
# MAIN PIPELINE SCRIPT (Your updated script with improvements)
# ============================================================================
echo "📝 Creating main pipeline script..."
cat > "$PACKAGE_NAME/edna_pipeline.sh" << 'MAINSCRIPT'
#!/bin/bash

# eNA 12S Pipeline v2.0
# Complete pipeline from raw reads to species identification

set -e

# Get script directory (works with symlinks)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
DEFAULT_OUTPUT_DIR="results_$(date +%Y%m%d_%H%M%S)"
DEFAULT_FORWARD_PRIMER="ACTGGGATTAGATACCCC"
DEFAULT_REVERSE_PRIMER="TAGAACAGGCTCCTCTAG"
DEFAULT_THREADS=4
DEFAULT_ASV_METHOD="otus"
DEFAULT_MIN_IDENTITY=70.0
DEFAULT_CLUSTERING_IDENTITY=97
DEFAULT_DADA2_MAXEE=20
DEFAULT_DADA2_MINLEN=80
DEFAULT_DADA2_MAXLEN=250

show_usage() {
    cat << EOF
${CYAN}eDNA 12S Pipeline v2.0${NC}
Complete environmental DNA analysis from raw reads to species identification

${BLUE}USAGE:${NC}
    $(basename $0) -i INPUT_DIR [OPTIONS]

${BLUE}REQUIRED:${NC}
    -i, --input DIR               Input directory with sample folders

${BLUE}GENERAL OPTIONS:${NC}
    -o, --output DIR              Output directory (default: results_YYYYMMDD_HHMMSS)
    -d, --database DIR            Database directory (default: Database)
    --preset PRESET               Use primer preset (see --list-presets)
    --forward-primer SEQ          Forward primer sequence
    --reverse-primer SEQ          Reverse primer sequence
    --asv-method METHOD           ASV method: otus|dada2 (default: otus)
    --min-identity NUM            Minimum BLAST identity % (default: 70.0)
    --threads NUM                 Number of threads (default: 4)
    --list-presets               Show available primer presets
    -h, --help                   Show this help

${BLUE}OTU CLUSTERING OPTIONS (--asv-method otus):${NC}
    --clustering-id NUM           OTU clustering identity % (default: 97)
                                  Common values: 95, 97, 99

${BLUE}DADA2 OPTIONS (--asv-method dada2):${NC}
    --max-ee NUM                  Max expected errors (default: 20)
                                  Lower=stricter, Higher=more permissive
    --min-len NUM                 Minimum ASV length bp (default: 80)
    --max-len NUM                 Maximum ASV length bp (default: 250)

${BLUE}PRIMER PRESETS:${NC}
    12s-mifish    MiFish 12S primers (default)
    12s-teleo     Teleo 12S primers
    16s-bacteria  Bacterial 16S V4 region
    coi-mlcoi     COI Leray primers
    custom        Use --forward-primer and --reverse-primer

${BLUE}EXAMPLES:${NC}
    # Basic analysis with default primers
    $(basename $0) -i samples/

    # Use preset primers
    $(basename $0) -i samples/ --preset 12s-teleo

    # DADA2 with strict filtering
    $(basename $0) -i samples/ --asv-method dada2 --max-ee 2

    # OTU clustering at 99% similarity
    $(basename $0) -i samples/ --asv-method otus --clustering-id 99

    # Custom primers
    $(basename $0) -i samples/ --preset custom \\
        --forward-primer GTCGGTAAAACTCGTGCCAGC \\
        --reverse-primer CATAGTGGGGTATCTAATCCCAGTTTGT

${BLUE}DOCUMENTATION:${NC}
    See docs/ folder for detailed guides:
    - QUICKSTART.md    - Get started in 5 minutes
    - EXAMPLES.md      - Real-world usage examples
    - TROUBLESHOOTING.md - Common issues and solutions

EOF
}

list_presets() {
    cat << EOF
${CYAN}Available Primer Presets:${NC}

${GREEN}12s-mifish${NC} (Default)
  Forward: ACTGGGATTAGATACCCC
  Reverse: TAGAACAGGCTCCTCTAG
  Target: Fish 12S rRNA MiFish region
  Length: ~170bp
  Reference: Miya et al. 2015

${GREEN}12s-teleo${NC}
  Forward: ACACCGCCCGTCACTCT
  Reverse: CTTCCGGTACACTTACCATG
  Target: Fish 12S rRNA Teleo region
  Length: ~160bp
  Reference: Valentini et al. 2016

${GREEN}16s-bacteria${NC}
  Forward: GTGYCAGCMGCCGCGGTAA
  Reverse: GGACTACNVGGGTWTCTAAT
  Target: Bacterial 16S V4 region
  Length: ~250bp
  Reference: Caporaso et al. 2011

${GREEN}coi-mlcoi${NC}
  Forward: GGWACWGGWTGAACWGTWTAYCCYCC
  Reverse: TANACYTCNGGRTGNCCRAARAAYCA
  Target: Metazoan COI
  Length: ~313bp
  Reference: Leray et al. 2013

${GREEN}custom${NC}
  Use --forward-primer and --reverse-primer to specify your own

EOF
}

# Parse arguments
SEQUENCES_DIR=""
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
DB_DIR="$SCRIPT_DIR/Database"
FORWARD_PRIMER="$DEFAULT_FORWARD_PRIMER"
REVERSE_PRIMER="$DEFAULT_REVERSE_PRIMER"
THREADS="$DEFAULT_THREADS"
ASV_METHOD="$DEFAULT_ASV_METHOD"
MIN_IDENTITY="$DEFAULT_MIN_IDENTITY"
CLUSTERING_IDENTITY="$DEFAULT_CLUSTERING_IDENTITY"
DADA2_MAXEE="$DEFAULT_DADA2_MAXEE"
DADA2_MINLEN="$DEFAULT_DADA2_MINLEN"
DADA2_MAXLEN="$DEFAULT_DADA2_MAXLEN"
PRESET=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input) SEQUENCES_DIR="$2"; shift 2 ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        -d|--database) DB_DIR="$2"; shift 2 ;;
        --preset)
            PRESET="$2"
            case "$PRESET" in
                12s-mifish)
                    FORWARD_PRIMER="ACTGGGATTAGATACCCC"
                    REVERSE_PRIMER="TAGAACAGGCTCCTCTAG"
                    ;;
                12s-teleo)
                    FORWARD_PRIMER="ACACCGCCCGTCACTCT"
                    REVERSE_PRIMER="CTTCCGGTACACTTACCATG"
                    ;;
                16s-bacteria)
                    FORWARD_PRIMER="GTGYCAGCMGCCGCGGTAA"
                    REVERSE_PRIMER="GGACTACNVGGGTWTCTAAT"
                    ;;
                coi-mlcoi)
                    FORWARD_PRIMER="GGWACWGGWTGAACWGTWTAYCCYCC"
                    REVERSE_PRIMER="TANACYTCNGGRTGNCCRAARAAYCA"
                    ;;
                custom)
                    # Will be set by --forward-primer and --reverse-primer
                    ;;
                *)
                    echo -e "${RED}❌ Unknown preset: $PRESET${NC}"
                    echo "Use --list-presets to see available options"
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        --forward-primer) FORWARD_PRIMER="$2"; shift 2 ;;
        --reverse-primer) REVERSE_PRIMER="$2"; shift 2 ;;
        --asv-method) ASV_METHOD="$2"; shift 2 ;;
        --clustering-id) CLUSTERING_IDENTITY="$2"; shift 2 ;;
        --min-identity) MIN_IDENTITY="$2"; shift 2 ;;
        --max-ee) DADA2_MAXEE="$2"; shift 2 ;;
        --min-len) DADA2_MINLEN="$2"; shift 2 ;;
        --max-len) DADA2_MAXLEN="$2"; shift 2 ;;
        --threads) THREADS="$2"; shift 2 ;;
        --list-presets) list_presets; exit 0 ;;
        -h|--help) show_usage; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; show_usage; exit 1 ;;
    esac
done

# Validate input
if [[ -z "$SEQUENCES_DIR" ]]; then
    echo -e "${RED}❌ Input directory required (-i)${NC}"
    show_usage
    exit 1
fi

if [[ ! -d "$SEQUENCES_DIR" ]]; then
    echo -e "${RED}❌ Input directory not found: $SEQUENCES_DIR${NC}"
    exit 1
fi

# Validate ASV method
if [[ "$ASV_METHOD" != "otus" && "$ASV_METHOD" != "dada2" ]]; then
    echo -e "${RED}❌ Invalid ASV method: $ASV_METHOD${NC}"
    echo "Valid options: otus, dada2"
    exit 1
fi

PROJECT_DIR=$(pwd)

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        eNA 12S Pipeline v2.0 - Analysis Starting         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📋 Configuration:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📁 Input:           $SEQUENCES_DIR"
echo "  📁 Output:          $OUTPUT_DIR"
echo "  📁 Database:        $DB_DIR"
[[ -n "$PRESET" ]] && echo "  🧬 Primer preset:   $PRESET"
echo "  🧬 Forward primer:  $FORWARD_PRIMER"
echo "  🧬 Reverse primer:  $REVERSE_PRIMER"
echo "  🔬 ASV method:      $ASV_METHOD"
if [[ "$ASV_METHOD" == "otus" ]]; then
    echo "     └─ Clustering:   ${CLUSTERING_IDENTITY}% similarity"
else
    echo "     └─ Max EE:       $DADA2_MAXEE"
    echo "     └─ Length range: ${DADA2_MINLEN}-${DADA2_MAXLEN}bp"
fi
echo "  📊 BLAST identity:  ≥${MIN_IDENTITY}%"
echo "  ⚙️  Threads:         $THREADS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check conda environment
if [[ "$CONDA_DEFAULT_ENV" != "edna-pipeline" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Not in 'edna-pipeline' conda environment${NC}"
    echo "  For best results, run: conda activate edna-pipeline"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Find database files
DB_FASTA=""
DB_TAXONOMY=""

echo -e "${BLUE}🔍 Checking database files...${NC}"
for fasta in "$DB_DIR"/*.fasta "$DB_DIR"/*.fa; do
    if [[ -f "$fasta" ]]; then
        DB_FASTA="$fasta"
        echo "  ✅ Database FASTA: $(basename "$DB_FASTA")"
        break
    fi
done

for csv in "$DB_DIR"/*taxonomy*.csv "$DB_DIR"/*_tax.csv; do
    if [[ -f "$csv" ]]; then
        DB_TAXONOMY="$csv"
        echo "  ✅ Taxonomy CSV: $(basename "$DB_TAXONOMY")"
        break
    fi
done

if [[ -z "$DB_FASTA" ]]; then
    echo -e "${RED}❌ No database FASTA found in $DB_DIR${NC}"
    echo "  Expected: *.fasta or *.fa file"
    exit 1
fi

[[ -z "$DB_TAXONOMY" ]] && echo -e "${YELLOW}  ⚠️  No taxonomy CSV found (BLAST-only mode)${NC}"
echo ""

# Create output structure
mkdir -p "$OUTPUT_DIR"/{intermediate/{01_trimmed,02_merged,03_primers_removed,04_otus,04_dada2},logs,taxonomy,final_reports}

# Detect samples
echo -e "${BLUE}🔍 Detecting samples...${NC}"
SAMPLES=()
cd "$SEQUENCES_DIR"

for sample_folder in */; do
    [[ ! -d "$sample_folder" ]] && continue
    sample_name="${sample_folder%/}"
    
    cd "$sample_folder"
    r1_files=(*.R1.fq.gz *_R1_*.fastq.gz *_R1.fastq.gz *_1.fq.gz)
    r2_files=(*.R2.fq.gz *_R2_*.fastq.gz *_R2.fastq.gz *_2.fq.gz)
    cd ..
    
    if [[ -f "$sample_folder/${r1_files[0]}" && -f "$sample_folder/${r2_files[0]}" ]]; then
        SAMPLES+=("$sample_name")
        echo "  ✓ $sample_name"
    fi
done

cd "$PROJECT_DIR"

if [[ ${#SAMPLES[@]} -eq 0 ]]; then
    echo -e "${RED}❌ No sample pairs found${NC}"
    echo "  Expected structure: input_dir/sample_name/*.R1.fq.gz + *.R2.fq.gz"
    exit 1
fi

echo -e "${GREEN}  Found ${#SAMPLES[@]} samples${NC}"
echo ""

# Log file for full output
LOGFILE="$OUTPUT_DIR/logs/pipeline_full.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') - Pipeline started" >> "$OUTPUT_DIR/logs/pipeline_timestamps.log"

# Step 1: Quality filtering
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Step 1/6: Quality Filtering (Trimmomatic)                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

for sample in "${SAMPLES[@]}"; do
    echo "  📝 Processing: $sample"
    cd "$SEQUENCES_DIR/$sample"
    r1_file=$(ls *.R1.fq.gz *_R1_*.fastq.gz *_R1.fastq.gz *_1.fq.gz 2>/dev/null | head -1)
    r2_file=$(ls *.R2.fq.gz *_R2_*.fastq.gz *_R2.fastq.gz *_2.fq.gz 2>/dev/null | head -1)
    cd "$PROJECT_DIR"
    
    trimmomatic PE -threads $THREADS \
        "$SEQUENCES_DIR/$sample/$r1_file" \
        "$SEQUENCES_DIR/$sample/$r2_file" \
        "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R1_paired.fq.gz" \
        "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R1_unpaired.fq.gz" \
        "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R2_paired.fq.gz" \
        "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R2_unpaired.fq.gz" \
        CROP:300 SLIDINGWINDOW:50:20 MINLEN:50 \
        2>> "$OUTPUT_DIR/logs/trimmomatic.log"
    
    echo "     ✓ Complete"
done

echo -e "${GREEN}✅ Quality filtering complete${NC}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Step 1 complete" >> "$OUTPUT_DIR/logs/pipeline_timestamps.log"
echo ""

# Step 2: Merging
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Step 2/6: Merging Paired Reads (FLASH)                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

for sample in "${SAMPLES[@]}"; do
    echo "  📝 Merging: $sample"
    flash "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R1_paired.fq.gz" \
          "$OUTPUT_DIR/intermediate/01_trimmed/${sample}_R2_paired.fq.gz" \
          -o "$sample" -d "$OUTPUT_DIR/intermediate/02_merged" \
          -m 10 -z 2>> "$OUTPUT_DIR/logs/flash.log"
    echo "     ✓ Complete"
done

echo -e "${GREEN}✅ Read merging complete${NC}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Step 2 complete" >> "$OUTPUT_DIR/logs/pipeline_timestamps.log"
echo ""

# Step 3: Primer removal
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Step 3/6: Removing Primers (Cutadapt)                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

REV_PRIMER_RC=$(echo $REVERSE_PRIMER | tr 'ATGC' 'TACG' | rev)
echo "  Forward primer:    $FORWARD_PRIMER"
echo "  Reverse primer RC: $REV_PRIMER_RC"
echo ""

for sample in "${SAMPLES[@]}"; do
    echo "  📝 Processing: $sample"
    cutadapt -g "$FORWARD_PRIMER" -a "$REV_PRIMER_RC" \
             --minimum-length 50 --maximum-length 500 \
             -o "$OUTPUT_DIR/intermediate/03_primers_removed/${sample}_clean.fq.gz" \
             "$OUTPUT_DIR/intermediate/02_merged/${sample}.extendedFrags.fastq.gz" \
             >> "$OUTPUT_DIR/logs/cutadapt.log" 2>&1
    echo "     ✓ Complete"
done

echo -e "${GREEN}✅ Primer removal complete${NC}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Step 3 complete" >> "$OUTPUT_DIR/logs/pipeline_timestamps.log"
echo ""

# Step 4: ASV generation (method-dependent)
if [[ "$ASV_METHOD" == "dada2" ]]; then
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Step 4/6: DADA2 ASV Calling                              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check DADA2
    if ! R --slave --quiet -e "library(dada2)" 2>/dev/null; then
        echo -e "${RED}❌ DADA2 not installed${NC}"
        echo "  Install: conda install -c bioconda bioconductor-dada2"
        exit 1
    fi
    
    echo "  Parameters: maxEE=$DADA2_MAXEE, minLen=$DADA2_MINLEN, maxLen=$DADA2_MAXLEN"
    echo ""
    
    # Source the DADA2 script from scripts directory
    if [[ -f "$SCRIPT_DIR/scripts/run_dada2.R" ]]; then
        Rscript "$SCRIPT_DIR/scripts/run_dada2.R" \
            "$OUTPUT_DIR/intermediate/03_primers_removed" \
            "$OUTPUT_DIR" \
            "$THREADS" \
            "$DADA2_MAXEE" \
            "$DADA2_MINLEN" \
            "$DADA2_MAXLEN" \
            2>&1 | tee -a "$OUTPUT_DIR/logs/dada2.log"
        DADA2_EXIT=${PIPESTATUS[0]}
    else
        echo -e "${RED}❌ DADA2 script not found: $SCRIPT_DIR/scripts/run_dada2.R${NC}"
        exit 1
    fi
    
    # Check success
    if [[ $DADA2_EXIT -eq 0 ]] && \
       [[ -f "$OUTPUT_DIR/intermediate/04_dada2/asvs_final.fasta" ]]; then
        
        ASV_COUNT=$(grep -c "^>" "$OUTPUT_DIR/intermediate/04_dada2/asvs_final.fasta")
        echo ""
        echo -e "${GREEN}✅ DADA2 complete: $ASV_COUNT ASVs generated${NC}"
        
        # Create symlinks for BLAST step
        mkdir -p "$OUTPUT_DIR/intermediate/04_otus"
        ln -sf "../04_dada2/asvs_final.fasta" "$OUTPUT_DIR/intermediate/04_otus/otus_final.fasta"
        ln -sf "../04_dada2/otu_table.txt" "$OUTPUT_DIR/intermediate/04_otus/otu_table.txt"
    else
        echo -e "${RED}❌ DADA2 failed - check logs/dada2.log${NC}"
        exit 1
    fi
    
else
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Step 4/6: OTU Clustering (VSEARCH ${CLUSTERING_IDENTITY}%)                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    cd "$OUTPUT_DIR/intermediate/04_otus"
    
    # Combine sequences
    > combined_sequences.fasta
    for sample in "${SAMPLES[@]}"; do
        echo "  📝 Adding: $sample"
        zcat "../03_primers_removed/${sample}_clean.fq.gz" | \
        awk -v sample="$sample" 'NR%4==1 {seq_num++; printf ">%s.%d;sample=%s;\n", sample, seq_num, sample} NR%4==2 {print $0}' \
        >> combined_sequences.fasta
    done
    
    TOTAL_SEQS=$(grep -c "^>" combined_sequences.fasta)
    echo "  Total sequences: $TOTAL_SEQS"
    echo ""
    
    echo "  🔄 Dereplicating..."
    vsearch --derep_fulllength combined_sequences.fasta --output unique.fasta --sizeout --threads $THREADS 2>/dev/null
    
    echo "  📊 Sorting by abundance..."
    vsearch --sortbysize unique.fasta --output sorted.fasta --minsize 2 --threads $THREADS 2>/dev/null
    
    CLUSTER_ID=$(echo "scale=2; $CLUSTERING_IDENTITY / 100" | bc)
    echo "  🎯 Clustering at ${CLUSTERING_IDENTITY}%..."
    vsearch --cluster_size sorted.fasta --id $CLUSTER_ID --centroids otus.fasta --relabel OTU_ --threads $THREADS 2>/dev/null
    
    echo "  🧹 Removing chimeras..."
    vsearch --uchime_denovo otus.fasta --nonchimeras otus_final.fasta --threads $THREADS 2>/dev/null
    
    echo "  📋 Creating OTU table..."
    vsearch --usearch_global combined_sequences.fasta --db otus_final.fasta --id $CLUSTER_ID --otutabout otu_table.txt --threads $THREADS 2>/dev/null
    
    OTU_COUNT=$(grep -c "^>" otus_final.fasta)
    cd "$PROJECT_DIR"
    
    echo ""
    echo -e "${GREEN}✅ OTU clustering complete: $OTU_COUNT OTUs from $TOTAL_SEQS sequences${NC}"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Step 4 complete" >> "$OUTPUT_DIR/logs/pipeline_timestamps.log"
echo ""

# Step 5: BLAST
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Step 5/6: BLAST Taxonomy Assignment                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

DB_BLAST="${DB_FASTA%.fasta}_blast"
DB_BLAST="${DB_BLAST%.fa}_blast"

if [[ ! -f "${DB_BLAST}.nhr" ]]; then
    echo "  🔨 Building BLAST database..."
    makeblastdb -in "$DB_FASTA" -dbtype nucl -out "$DB_BLAST" -parse_seqids 2>/dev/null
    echo "     ✓ Database built"
fi

echo "  🔍 Running BLAST (min ${MIN_IDENTITY}% identity)..."
blastn -task blastn-short \
       -query "$OUTPUT_DIR/intermediate/04_otus/otus_final.fasta" \
       -db "$DB_BLAST" \
       -out "$OUTPUT_DIR/taxonomy/blast_results.txt" \
       -outfmt "6 qseqid sseqid pident evalue stitle" \
       -max_target_seqs 1 \
       -evalue 1.0 \
       -word_size 7 \
       -perc_identity "$MIN_IDENTITY" \
       -num_threads $THREADS 2>/dev/null

BLAST_HITS=$(wc -l < "$OUTPUT_DIR/taxonomy/blast_results.txt")
echo "     ✓ $BLAST_HITS hits found"
echo ""
echo -e "${GREEN}✅ BLAST complete${NC}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Step 5 complete" >> "$OUTPUT_DIR/logs/pipeline_timestamps.log"
echo ""

# Step 6: Process results
if [[ -n "$DB_TAXONOMY" && $BLAST_HITS -gt 0 ]]; then
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Step 6/6: Generating Reports                             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    SAMPLE_NAMES=$(IFS=,; echo "${SAMPLES[*]}")
    UNIT_NAME=$(if [[ "$ASV_METHOD" == "dada2" ]]; then echo "ASV"; else echo "OTU"; fi)
    
    # Use taxonomy processing script
    if [[ -f "$SCRIPT_DIR/scripts/process_taxonomy.R" ]]; then
        Rscript "$SCRIPT_DIR/scripts/process_taxonomy.R" \
            "$OUTPUT_DIR/taxonomy/blast_results.txt" \
            "$DB_TAXONOMY" \
            "$OUTPUT_DIR/intermediate/04_otus/otu_table.txt" \
            "$OUTPUT_DIR/final_reports" \
            "$SAMPLE_NAMES" \
            "$UNIT_NAME" \
            2>&1 | tee -a "$OUTPUT_DIR/logs/taxonomy.log"
    else
        echo -e "${YELLOW}⚠️  Taxonomy script not found - basic output only${NC}"
    fi
    
    echo -e "${GREEN}✅ Report generation complete${NC}"
else
    if [[ -z "$DB_TAXONOMY" ]]; then
        echo -e "${YELLOW}⚠️  No taxonomy CSV - BLAST accessions only${NC}"
    elif [[ $BLAST_HITS -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No BLAST hits - try --min-identity lower${NC}"
    fi
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Step 6 complete" >> "$OUTPUT_DIR/logs/pipeline_timestamps.log"
echo ""

# Final summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              🎉 Pipeline Completed Successfully! 🎉        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📊 ANALYSIS SUMMARY${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📁 Results directory: $OUTPUT_DIR"
echo "  🔬 ASV method:        $ASV_METHOD"
if [[ "$ASV_METHOD" == "dada2" ]]; then
    echo "  📈 ASVs generated:    $(grep -c "^>" "$OUTPUT_DIR/intermediate/04_dada2/asvs_final.fasta" 2>/dev/null || echo "N/A")"
else
    echo "  📈 OTUs generated:    $(grep -c "^>" "$OUTPUT_DIR/intermediate/04_otus/otus_final.fasta" 2>/dev/null || echo "N/A")"
fi
echo "  🎯 BLAST hits:        $BLAST_HITS"
echo "  👥 Samples processed: ${#SAMPLES[@]}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}📋 OUTPUT FILES${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Main Results (final_reports/):"
if [[ "$ASV_METHOD" == "dada2" ]]; then
    echo "    • ASV_taxonomy_assignments.csv"
    echo "    • sample_by_sample_taxonomy.csv"
    echo "    • species_by_sample.csv"
    echo "    • species_abundance_summary.csv"
else
    echo "    • OTU_taxonomy_assignments.csv"
    echo "    • sample_by_sample_taxonomy.csv"
    echo "    • species_by_sample.csv"
    echo "    • species_abundance_summary.csv"
fi
echo ""
echo "  Intermediate Files (intermediate/):"
if [[ "$ASV_METHOD" == "dada2" ]]; then
    echo "    • 04_dada2/asvs_final.fasta        - ASV sequences"
    echo "    • 04_dada2/asv_table.csv           - ASV abundances"
else
    echo "    • 04_otus/otus_final.fasta         - OTU sequences"
    echo "    • 04_otus/otu_table.txt            - OTU abundances"
fi
echo ""
echo "  Logs (logs/):"
echo "    • pipeline_full.log                - Complete log"
echo "    • pipeline_timestamps.log          - Step timing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✨ Analysis complete! Check the results directory for outputs. ✨${NC}"
echo ""
MAINSCRIPT

chmod +x "$PACKAGE_NAME/edna_pipeline.sh"

echo "  ✅ Main pipeline created"

# ============================================================================
# R SCRIPTS
# ============================================================================
echo "📝 Creating R analysis scripts..."

# DADA2 script
cat > "$PACKAGE_NAME/scripts/run_dada2.R" << 'DADA2SCRIPT'
#!/usr/bin/env Rscript

library(dada2)
suppressPackageStartupMessages(library(dplyr))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 6) {
    cat("Usage: run_dada2.R <input_dir> <output_dir> <threads> <max_ee> <min_len> <max_len>\n")
    quit(status = 1)
}

input_dir <- args[1]
output_dir <- args[2]
threads <- as.numeric(args[3])
max_ee <- as.numeric(args[4])
min_len <- as.numeric(args[5])
max_len <- as.numeric(args[6])

cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║              DADA2 ASV Analysis - Starting                ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n\n")

cat("Parameters:\n")
cat(sprintf("  Max expected errors: %g\n", max_ee))
cat(sprintf("  Length range:        %d-%d bp\n", min_len, max_len))
cat(sprintf("  Threads:             %d\n\n", threads))

# Get input files
fnFs <- sort(list.files(input_dir, pattern = "_clean.fq.gz$", full.names = TRUE))

if (length(fnFs) == 0) {
    cat("ERROR: No cleaned files found in:", input_dir, "\n")
    quit(status = 1)
}

sample_names <- sapply(fnFs, function(x) gsub("_clean.fq.gz$", "", basename(x)), USE.NAMES = FALSE)
names(fnFs) <- sample_names

cat(sprintf("Found %d samples to process\n\n", length(sample_names)))

# Create filtered directory
filtered_dir <- file.path(output_dir, "intermediate", "04_dada2", "filtered")
dir.create(filtered_dir, showWarnings = FALSE, recursive = TRUE)

filtFs <- file.path(filtered_dir, paste0(sample_names, "_filt.fastq.gz"))

# Step 1: Filter
cat("Step 1/6: Quality filtering...\n")
out <- filterAndTrim(fnFs, filtFs,
                     maxN = 0, maxEE = max_ee, truncQ = 0,
                     minLen = min_len, maxLen = max_len, 
                     rm.phix = TRUE,
                     compress = TRUE, 
                     multithread = threads > 1,
                     verbose = FALSE)

# Check which passed
exists <- file.exists(filtFs) & file.size(filtFs) > 20
filtFs <- filtFs[exists]
sample_names <- sample_names[exists]

if (length(filtFs) == 0) {
    cat("ERROR: No samples passed filtering\n")
    cat("HINT: Try increasing --max-ee for more permissive filtering\n")
    quit(status = 1)
}

cat(sprintf("  ✓ %d samples passed filtering\n\n", length(filtFs)))

# Step 2: Learn errors
cat("Step 2/6: Learning error rates...\n")
errF <- learnErrors(filtFs, multithread = threads > 1, verbose = FALSE)
cat("  ✓ Error model learned\n\n")

# Step 3: Dereplicate
cat("Step 3/6: Dereplicating sequences...\n")
derepFs <- derepFastq(filtFs, verbose = FALSE)
names(derepFs) <- sample_names
cat("  ✓ Dereplication complete\n\n")

# Step 4: Infer ASVs
cat("Step 4/6: Inferring ASVs...\n")
dadaFs <- dada(derepFs, err = errF, multithread = threads > 1, verbose = FALSE)
cat("  ✓ ASV inference complete\n\n")

# Step 5: Make sequence table
cat("Step 5/6: Constructing sequence table...\n")
seqtab <- makeSequenceTable(dadaFs)
cat("  ✓ Sequence table created\n\n")

# Step 6: Remove chimeras
cat("Step 6/6: Removing chimeras...\n")
seqtab_nochim <- removeBimeraDenovo(seqtab, method = "consensus", 
                                     multithread = threads > 1, 
                                     verbose = FALSE)
cat("  ✓ Chimera removal complete\n\n")

cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║                    DADA2 Results Summary                  ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n\n")

cat(sprintf("  Total ASVs:           %d\n", ncol(seqtab_nochim)))
cat(sprintf("  Total reads:          %d\n", sum(seqtab_nochim)))
cat(sprintf("  Avg reads/sample:     %.1f\n", mean(rowSums(seqtab_nochim))))
cat(sprintf("  Avg ASVs/sample:      %.1f\n\n", mean(rowSums(seqtab_nochim > 0))))

# Save results
asv_dir <- file.path(output_dir, "intermediate", "04_dada2")
dir.create(asv_dir, showWarnings = FALSE, recursive = TRUE)

# Save table
write.csv(seqtab_nochim, file.path(asv_dir, "asv_table.csv"))

# Create FASTA
asv_seqs <- colnames(seqtab_nochim)
asv_headers <- paste0("ASV_", seq_along(asv_seqs))
asv_fasta <- file.path(asv_dir, "asvs_final.fasta")

cat(paste0(">", asv_headers, "\n", asv_seqs), file = asv_fasta, sep = "\n")

# Rename table
colnames(seqtab_nochim) <- asv_headers
write.csv(seqtab_nochim, file.path(asv_dir, "asv_table_renamed.csv"))

# Create OTU-style table for compatibility
otu_table <- as.data.frame(t(seqtab_nochim))
write.table(otu_table, file.path(asv_dir, "otu_table.txt"), 
            sep = "\t", quote = FALSE, col.names = NA)

cat("All files saved successfully\n\n")
cat("SUCCESS\n")
DADA2SCRIPT

chmod +x "$PACKAGE_NAME/scripts/run_dada2.R"

# Taxonomy processing script
cat > "$PACKAGE_NAME/scripts/process_taxonomy.R" << 'TAXSCRIPT'
#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 6) {
    cat("Usage: process_taxonomy.R <blast_file> <taxonomy_file> <otu_table> <output_dir> <sample_names> <unit_name>\n")
    quit(status = 1)
}

blast_file <- args[1]
taxonomy_file <- args[2]
otu_table_file <- args[3]
output_dir <- args[4]
sample_names <- args[5]
unit_name <- args[6]

actual_samples <- strsplit(sample_names, ",")[[1]]

cat("Processing taxonomy results...\n\n")

# Read BLAST results
blast_data <- read.table(blast_file, sep = "\t", header = FALSE, 
                        stringsAsFactors = FALSE)
colnames(blast_data) <- c(paste0(unit_name, "_ID"), "Subject_ID", 
                          "Percent_Identity", "E_value", "Subject_Title")

cat(sprintf("  BLAST hits: %d\n", nrow(blast_data)))

# Read taxonomy
taxonomy <- read.csv(taxonomy_file, stringsAsFactors = FALSE)
cat(sprintf("  Taxonomy entries: %d\n\n", nrow(taxonomy)))

# Clean accessions
blast_data$Accession <- gsub("gb\\||emb\\||dbj\\||ref\\||\\|.*", "", 
                            blast_data$Subject_ID)

if ("Accession" %in% colnames(taxonomy)) {
    taxonomy$Accession_Clean <- gsub("gb\\||emb\\||dbj\\||ref\\||\\|.*", "", 
                                    taxonomy$Accession)
} else {
    taxonomy$Accession_Clean <- gsub("gb\\||emb\\||dbj\\||ref\\||\\|.*", "", 
                                    taxonomy[,1])
}

# Merge
blast_with_tax <- merge(blast_data, taxonomy, 
                       by.x = "Accession", 
                       by.y = "Accession_Clean", 
                       all.x = TRUE)

# Extract species names
blast_with_tax$Species_Name <- if("Species" %in% colnames(blast_with_tax)) {
    blast_with_tax$Species
} else if("species" %in% colnames(blast_with_tax)) {
    blast_with_tax$species
} else {
    "Unclassified"
}

blast_with_tax$Genus_Name <- if("Genus" %in% colnames(blast_with_tax)) {
    blast_with_tax$Genus
} else if("genus" %in% colnames(blast_with_tax)) {
    blast_with_tax$genus
} else {
    sapply(blast_with_tax$Species_Name, function(sp) {
        if(!is.na(sp) && sp != "Unclassified" && grepl(" ", sp)) {
            strsplit(sp, " ")[[1]][1]
        } else {
            "Unclassified"
        }
    })
}

# Confidence levels
blast_with_tax$Confidence <- case_when(
    blast_with_tax$Percent_Identity >= 97 ~ "High",
    blast_with_tax$Percent_Identity >= 90 ~ "Medium",
    blast_with_tax$Percent_Identity >= 80 ~ "Low",
    blast_with_tax$Percent_Identity >= 70 ~ "Very_Low",
    TRUE ~ "Extremely_Low"
)

# Best hits
unit_col <- paste0(unit_name, "_ID")
best_hits <- blast_with_tax %>% 
    group_by(.data[[unit_col]]) %>% 
    arrange(desc(Percent_Identity)) %>% 
    slice(1) %>% 
    ungroup()

# Save taxonomy assignments
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

write.csv(
    best_hits %>% select(all_of(unit_col), Species_Name, Genus_Name, 
                        Percent_Identity, E_value, Confidence, Accession),
    file.path(output_dir, paste0(unit_name, "_taxonomy_assignments.csv")), 
    row.names = FALSE
)

cat(sprintf("Saved: %s_taxonomy_assignments.csv\n", unit_name))

# Read OTU table
otu_table <- read.table(otu_table_file, header = TRUE, row.names = 1, 
                       sep = "\t", check.names = FALSE)

# Rename columns to actual sample names
if (ncol(otu_table) == length(actual_samples)) {
    colnames(otu_table) <- actual_samples
}

# Convert to long format
otu_long <- data.frame(
    Sample_ID = rep(colnames(otu_table), each = nrow(otu_table)),
    Unit_ID = rep(rownames(otu_table), ncol(otu_table)),
    Abundance = as.vector(as.matrix(otu_table))
) %>% filter(Abundance > 0)

colnames(otu_long)[2] <- unit_col

# Merge with taxonomy
otu_taxonomy <- merge(
    otu_long, 
    best_hits %>% select(all_of(unit_col), Species_Name, Genus_Name, 
                        Percent_Identity, Confidence), 
    by = unit_col, 
    all.x = TRUE
)

otu_taxonomy$Species_Name[is.na(otu_taxonomy$Species_Name)] <- "Unclassified"

# Save sample-by-sample
write.csv(
    otu_taxonomy %>% arrange(Sample_ID, desc(Abundance)), 
    file.path(output_dir, "sample_by_sample_taxonomy.csv"), 
    row.names = FALSE
)

cat("Saved: sample_by_sample_taxonomy.csv\n")

# Species by sample
sample_species <- otu_taxonomy %>% 
    filter(Species_Name != "Unclassified") %>%
    group_by(Sample_ID, Species_Name, Genus_Name) %>%
    summarise(
        Total_Reads = sum(Abundance), 
        Unit_Count = n_distinct(.data[[unit_col]]), 
        Avg_Identity = round(mean(Percent_Identity, na.rm = TRUE), 2), 
        .groups = 'drop'
    ) %>%
    arrange(Sample_ID, desc(Total_Reads))

colnames(sample_species)[colnames(sample_species) == "Unit_Count"] <- paste0(unit_name, "_Count")

write.csv(sample_species, file.path(output_dir, "species_by_sample.csv"), row.names = FALSE)
cat("Saved: species_by_sample.csv\n")

# Species abundance summary
species_summary <- otu_taxonomy %>% 
    filter(Species_Name != "Unclassified") %>%
    group_by(Species_Name, Genus_Name) %>%
    summarise(
        Total_Reads = sum(Abundance), 
        Unit_Count = n_distinct(.data[[unit_col]]), 
        Samples_Present = n_distinct(Sample_ID), 
        Avg_Identity = round(mean(Percent_Identity, na.rm = TRUE), 2), 
        .groups = 'drop'
    ) %>%
    arrange(desc(Total_Reads))

colnames(species_summary)[colnames(species_summary) == "Unit_Count"] <- paste0(unit_name, "_Count")

write.csv(species_summary, file.path(output_dir, "species_abundance_summary.csv"), row.names = FALSE)
cat("Saved: species_abundance_summary.csv\n\n")

# Print summary
cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║                  Taxonomy Results Summary                 ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n\n")

cat("Results by sample:\n")
for (sample in actual_samples) {
    sample_data <- sample_species %>% filter(Sample_ID == sample)
    if (nrow(sample_data) > 0) {
        cat(sprintf("  %-30s %3d species, %6d reads\n", 
                   sample, nrow(sample_data), sum(sample_data$Total_Reads)))
    }
}

cat(sprintf("\nTop 10 species overall:\n"))
for (i in 1:min(10, nrow(species_summary))) {
    cat(sprintf("  %2d. %-30s %6d reads (%d samples)\n", 
               i, species_summary$Species_Name[i], 
               species_summary$Total_Reads[i], 
               species_summary$Samples_Present[i]))
}

cat("\nProcessing complete!\n")
TAXSCRIPT

chmod +x "$PACKAGE_NAME/scripts/process_taxonomy.R"

echo "  ✅ R scripts created"

# ============================================================================
# INSTALLATION SCRIPT (Bulletproof dependency management)
# ============================================================================
echo "📝 Creating installation script..."

cat > "$PACKAGE_NAME/install.sh" << 'INSTALLSCRIPT'
#!/bin/bash

# eDNA 12S Pipeline v2.0 - Installation Script
# Bulletproof dependency installation with comprehensive checking

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     eDNA 12S Pipeline v2.0 - Installation Script          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="edna-pipeline"

echo -e "${BLUE}📁 Installation directory: $INSTALL_DIR${NC}"
echo ""

# ============================================================================
# Step 1: Check for conda
# ============================================================================
echo -e "${BLUE}Step 1/6: Checking for conda...${NC}"

if ! command -v conda &> /dev/null; then
    echo -e "${RED}❌ Conda not found!${NC}"
    echo ""
    echo -e "${YELLOW}Conda is required to install dependencies.${NC}"
    echo "Please install Miniconda from:"
    echo "  https://docs.conda.io/en/latest/miniconda.html"
    echo ""
    echo "After installation, run this script again."
    exit 1
fi

CONDA_VERSION=$(conda --version | awk '{print $2}')
echo -e "${GREEN}✅ Conda found: v$CONDA_VERSION${NC}"
echo ""

# ============================================================================
# Step 2: Check if environment exists
# ============================================================================
echo -e "${BLUE}Step 2/6: Checking for existing environment...${NC}"

if conda env list | grep -q "^$ENV_NAME "; then
    echo -e "${YELLOW}⚠️  Environment '$ENV_NAME' already exists${NC}"
    echo ""
    read -p "Remove and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "  🗑️  Removing old environment..."
        conda env remove -n "$ENV_NAME" -y
        echo -e "${GREEN}  ✅ Old environment removed${NC}"
    else
        echo "  Using existing environment"
    fi
else
    echo "  No existing environment found"
fi
echo ""

# ============================================================================
# Step 3: Create/update conda environment
# ============================================================================
echo -e "${BLUE}Step 3/6: Creating conda environment...${NC}"
echo "  This may take 5-10 minutes on first installation"
echo ""

if conda env list | grep -q "^$ENV_NAME "; then
    echo "  Environment exists, updating dependencies..."
    conda env update -n "$ENV_NAME" -f "$INSTALL_DIR/environment.yml" --prune
else
    echo "  Creating new environment..."
    conda env create -f "$INSTALL_DIR/environment.yml"
fi

echo ""
echo -e "${GREEN}✅ Conda environment ready${NC}"
echo ""

# ============================================================================
# Step 4: Install DADA2 (BiocManager)
# ============================================================================
echo -e "${BLUE}Step 4/6: Installing DADA2...${NC}"

# Check if already installed
if conda run -n "$ENV_NAME" R --slave --quiet -e "library(dada2)" 2>/dev/null; then
    echo -e "${GREEN}✅ DADA2 already installed${NC}"
else
    echo "  Installing DADA2 via BiocManager..."
    conda run -n "$ENV_NAME" R --slave --quiet << 'RCODE'
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager", repos="http://cran.r-project.org")
BiocManager::install("dada2", update = FALSE, ask = FALSE)
cat("DADA2 installation complete\n")
RCODE
    
    # Verify installation
    if conda run -n "$ENV_NAME" R --slave --quiet -e "library(dada2)" 2>/dev/null; then
        echo -e "${GREEN}✅ DADA2 installed successfully${NC}"
    else
        echo -e "${RED}❌ DADA2 installation failed${NC}"
        echo "  Try manually: conda activate $ENV_NAME; R"
        echo "  Then in R: BiocManager::install('dada2')"
        exit 1
    fi
fi
echo ""

# ============================================================================
# Step 5: Verify all tools
# ============================================================================
echo -e "${BLUE}Step 5/6: Verifying installation...${NC}"

ALL_GOOD=true

# Check each required tool
REQUIRED_TOOLS=("trimmomatic" "flash" "cutadapt" "blastn" "makeblastdb" "Rscript" "vsearch")

for tool in "${REQUIRED_TOOLS[@]}"; do
    if conda run -n "$ENV_NAME" command -v "$tool" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $tool"
    else
        echo -e "  ${RED}✗${NC} $tool"
        ALL_GOOD=false
    fi
done

# Check R packages
echo ""
echo "  Checking R packages..."
R_PACKAGES=("dada2" "dplyr" "tidyr" "vegan")

for pkg in "${R_PACKAGES[@]}"; do
    if conda run -n "$ENV_NAME" R --slave --quiet -e "library($pkg)" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} R: $pkg"
    else
        echo -e "  ${RED}✗${NC} R: $pkg"
        ALL_GOOD=false
    fi
done

echo ""

if [[ "$ALL_GOOD" == true ]]; then
    echo -e "${GREEN}✅ All dependencies verified${NC}"
else
    echo -e "${RED}❌ Some dependencies missing${NC}"
    echo "  Try recreating the environment: ./install.sh"
    exit 1
fi
echo ""

# ============================================================================
# Step 6: Setup database
# ============================================================================
echo -e "${BLUE}Step 6/6: Setting up database...${NC}"

# Check if database files exist
if [[ -f "$INSTALL_DIR/Database"/*.fasta ]] || [[ -f "$INSTALL_DIR/Database"/*.fa ]]; then
    echo "  Found database FASTA file(s)"
    
    # Build BLAST database if needed
    for fasta in "$INSTALL_DIR/Database"/*.fasta "$INSTALL_DIR/Database"/*.fa; do
        if [[ -f "$fasta" ]]; then
            db_name="${fasta%.fasta}"
            db_name="${db_name%.fa}"
            
            if [[ ! -f "${db_name}_blast.nhr" ]]; then
                echo "  🔨 Building BLAST database for $(basename "$fasta")..."
                conda run -n "$ENV_NAME" makeblastdb \
                    -in "$fasta" \
                    -dbtype nucl \
                    -out "${db_name}_blast" \
                    -parse_seqids 2>/dev/null
                echo -e "  ${GREEN}✓${NC} BLAST database ready"
            else
                echo -e "  ${GREEN}✓${NC} BLAST database already exists"
            fi
        fi
    done
else
    echo -e "${YELLOW}⚠️  No database files found in Database/ directory${NC}"
    echo "  Please add your database files to: $INSTALL_DIR/Database/"
    echo "  Required files:"
    echo "    - *.fasta (or *.fa) - reference sequences"
    echo "    - *taxonomy*.csv - taxonomy mapping"
fi
echo ""

# ============================================================================
# Step 7: Make scripts executable
# ============================================================================
echo "  Setting permissions..."
chmod +x "$INSTALL_DIR/edna_pipeline.sh"
chmod +x "$INSTALL_DIR/scripts/"*.R 2>/dev/null || true
chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Scripts are executable"
echo ""

# ============================================================================
# Final success message
# ============================================================================
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 Installation Completed Successfully! 🎉      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}NEXT STEPS:${NC}"
echo ""
echo "1. Activate the environment:"
echo -e "   ${YELLOW}conda activate $ENV_NAME${NC}"
echo ""
echo "2. Test the installation:"
echo -e "   ${YELLOW}./edna_pipeline.sh --help${NC}"
echo ""
echo "3. Run test analysis (if test data available):"
echo -e "   ${YELLOW}cd test_data && ./run_test.sh${NC}"
echo ""
echo "4. Analyze your data:"
echo -e "   ${YELLOW}./edna_pipeline.sh -i /path/to/samples${NC}"
echo ""
echo -e "${CYAN}DOCUMENTATION:${NC}"
echo "  • docs/QUICKSTART.md       - Get started in 5 minutes"
echo "  • docs/EXAMPLES.md         - Real-world usage examples"
echo "  • docs/TROUBLESHOOTING.md  - Common issues and solutions"
echo ""
echo -e "${GREEN}Happy analyzing! 🧬${NC}"
echo ""
INSTALLSCRIPT

chmod +x "$PACKAGE_NAME/install.sh"

echo "  ✅ Installation script created"

# ============================================================================
# CONDA ENVIRONMENT FILE
# ============================================================================
echo "📝 Creating conda environment file..."

cat > "$PACKAGE_NAME/environment.yml" << 'ENVFILE'
name: edna-pipeline
channels:
  - conda-forge
  - bioconda
  - defaults

dependencies:
  # Core
  - python=3.9
  - r-base=4.3
  
  # Bioinformatics tools
  - trimmomatic>=0.39
  - flash>=1.2
  - cutadapt>=4.0
  - blast>=2.12
  - vsearch>=2.21
  
  # R packages (base)
  - r-dplyr>=1.0
  - r-tidyr>=1.2
  - r-stringr>=1.4
  - r-vegan>=2.6
  - r-ggplot2>=3.3
  
  # Utilities
  - bc
  - wget
  - gzip
  
  # Note: DADA2 will be installed via BiocManager during install.sh
ENVFILE

echo "  ✅ Environment file created"

# ============================================================================
# CONFIGURATION FILES
# ============================================================================
echo "📝 Creating configuration files..."

cat > "$PACKAGE_NAME/config/primer_presets.yml" << 'PRESETS'
# Primer Presets for eDNA 12S Pipeline v2.0
# Add custom presets here

presets:
  12s-mifish:
    name: "MiFish 12S"
    forward: "ACTGGGATTAGATACCCC"
    reverse: "TAGAACAGGCTCCTCTAG"
    target: "Fish 12S rRNA"
    length: "~170bp"
    reference: "Miya et al. 2015"
    
  12s-teleo:
    name: "Teleo 12S"
    forward: "ACACCGCCCGTCACTCT"
    reverse: "CTTCCGGTACACTTACCATG"
    target: "Fish 12S rRNA"
    length: "~160bp"
    reference: "Valentini et al. 2016"
    
  16s-bacteria:
    name: "16S V4 Region"
    forward: "GTGYCAGCMGCCGCGGTAA"
    reverse: "GGACTACNVGGGTWTCTAAT"
    target: "Bacterial 16S"
    length: "~250bp"
    reference: "Caporaso et al. 2011"
    
  coi-mlcoi:
    name: "COI Leray"
    forward: "GGWACWGGWTGAACWGTWTAYCCYCC"
    reverse: "TANACYTCNGGRTGNCCRAARAAYCA"
    target: "Metazoan COI"
    length: "~313bp"
    reference: "Leray et al. 2013"
PRESETS

cat > "$PACKAGE_NAME/config/pipeline_defaults.yml" << 'DEFAULTS'
# Default Pipeline Parameters
# Override these with command-line flags

# General
default_threads: 4
default_asv_method: "otus"  # otus or dada2

# OTU clustering
default_clustering_identity: 97  # 95, 97, or 99

# DADA2
default_dada2_maxee: 20
default_dada2_minlen: 80
default_dada2_maxlen: 250

# BLAST
default_min_identity: 70.0
blast_word_size: 7
blast_evalue: 1.0

# Quality filtering
trimmomatic_crop: 300
trimmomatic_slidingwindow: "50:20"
trimmomatic_minlen: 50

# Primer removal
cutadapt_minlen: 50
cutadapt_maxlen: 500

# Read merging
flash_min_overlap: 10
DEFAULTS

echo "  ✅ Configuration files created"

# ============================================================================
# DOCUMENTATION
# ============================================================================
echo "📝 Creating documentation..."

cat > "$PACKAGE_NAME/README.md" << 'README'
# eDNA 12S Pipeline v2.0

Complete bioinformatics pipeline for environmental DNA (eDNA) analysis, from raw Illumina reads to species identification.

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/yourusername/eDNA-12S-Pipeline)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## ✨ Features

- 🧬 **Complete Workflow**: Raw FASTQ → Quality Control → ASV/OTU Calling → Taxonomy → Reports
- 🔬 **Dual ASV Methods**: Choose between OTU clustering (VSEARCH) or DADA2 exact sequences
- 🧪 **Multiple Primer Support**: Pre-configured presets + custom primer option
- 📊 **Comprehensive Reports**: Sample-by-sample breakdown, species summaries, abundance tables
- 🚀 **Easy Installation**: One-command conda-based setup
- 📖 **Extensive Documentation**: Quick start, examples, troubleshooting guides

## 🚀 Quick Start

```bash
# 1. Install
git clone https://github.com/yourusername/eDNA-12S-Pipeline.git
cd eDNA-12S-Pipeline
./install.sh

# 2. Activate environment
conda activate edna-pipeline

# 3. Run analysis
./edna_pipeline.sh -i /path/to/samples
```

## 📋 Requirements

- **System**: Linux or macOS (Windows via WSL2)
- **RAM**: 8GB minimum (16GB+ recommended)
- **Storage**: 50GB+ for database and results
- **Software**: Conda/Miniconda

## 📦 Installation

### Step 1: Clone Repository

```bash
git clone https://github.com/yourusername/eDNA-12S-Pipeline.git
cd eDNA-12S-Pipeline
```

### Step 2: Run Installer

```bash
./install.sh
```

The installer will:
- Create conda environment
- Install all dependencies
- Set up DADA2
- Build BLAST databases
- Verify installation

### Step 3: Activate Environment

```bash
conda activate edna-pipeline
```

## 📂 Input Requirements

### Directory Structure

The pipeline accepts sample folders containing paired-end FASTQ files:

```
samples/
├── sample1/
│   ├── sample1_S1_L001_R1_001.fastq.gz
│   └── sample1_S1_L001_R2_001.fastq.gz
├── sample2/
│   ├── sample2_S2_L001_R1_001.fastq.gz
│   └── sample2_S2_L001_R2_001.fastq.gz
└── ...
```

Supported naming patterns:
- `*.R1.fq.gz` / `*.R2.fq.gz`
- `*_R1_*.fastq.gz` / `*_R2_*.fastq.gz`
- `*_1.fq.gz` / `*_2.fq.gz`

## 🔬 Usage Examples

### Basic Analysis (Default MiFish 12S Primers)

```bash
./edna_pipeline.sh -i samples/
```

### Using Preset Primers

```bash
# List available presets
./edna_pipeline.sh --list-presets

# Use Teleo 12S primers
./edna_pipeline.sh -i samples/ --preset 12s-teleo
```

### DADA2 Method

```bash
# DADA2 with default parameters
./edna_pipeline.sh -i samples/ --asv-method dada2

# Strict quality filtering (high-quality samples)
./edna_pipeline.sh -i samples/ --asv-method dada2 --max-ee 2

# Relaxed filtering (degraded samples)
./edna_pipeline.sh -i samples/ --asv-method dada2 --max-ee 30
```

### OTU Clustering

```bash
# 97% similarity (default)
./edna_pipeline.sh -i samples/ --asv-method otus

# 99% similarity (stricter)
./edna_pipeline.sh -i samples/ --asv-method otus --clustering-id 99
```

### Custom Primers

```bash
./edna_pipeline.sh -i samples/ --preset custom \
    --forward-primer GTCGGTAAAACTCGTGCCAGC \
    --reverse-primer CATAGTGGGGTATCTAATCCCAGTTTGT
```

## 📊 Output Files

### Main Results (`final_reports/`)

- `ASV_taxonomy_assignments.csv` or `OTU_taxonomy_assignments.csv`
  - Complete taxonomy for each sequence variant
- `sample_by_sample_taxonomy.csv`
  - Detailed breakdown per sample
- `species_by_sample.csv`
  - Species abundances in each sample
- `species_abundance_summary.csv`
  - Overall species summary across all samples

### Intermediate Files (`intermediate/`)

- `04_dada2/asvs_final.fasta` or `04_otus/otus_final.fasta`
  - Final sequence variants
- `04_dada2/asv_table.csv` or `04_otus/otu_table.txt`
  - Abundance matrix

### Logs (`logs/`)

- `pipeline_full.log` - Complete execution log
- `pipeline_timestamps.log` - Timing information
- Step-specific logs (trimmomatic, flash, cutadapt, dada2)

## 📚 Documentation

- **[Quick Start Guide](docs/QUICKSTART.md)** - Get started in 5 minutes
- **[Installation Guide](docs/INSTALLATION.md)** - Detailed installation instructions
- **[Usage Examples](docs/EXAMPLES.md)** - Real-world analysis scenarios
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Output Description](docs/OUTPUTS.md)** - Understanding your results

## 🛠️ Pipeline Steps

1. **Quality Filtering** (Trimmomatic) - Remove low-quality bases and adapters
2. **Read Merging** (FLASH) - Merge paired-end reads
3. **Primer Removal** (Cutadapt) - Remove primer sequences
4. **ASV Calling** (DADA2 or VSEARCH) - Generate sequence variants
5. **Taxonomy Assignment** (BLAST) - Match against reference database
6. **Report Generation** (R) - Create summary tables and statistics

## 🗄️ Database

The pipeline requires a reference database:

1. Place your FASTA file in `Database/` directory
2. (Optional) Add taxonomy CSV file for enhanced results
3. BLAST databases are automatically built during installation

Example database structure:
```
Database/
├── reference_sequences.fasta
└── taxonomy_mapping.csv
```

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 📧 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/eDNA-12S-Pipeline/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/eDNA-12S-Pipeline/discussions)
- **Email**: your.email@example.com

## 📚 Citation

If you use this pipeline in your research, please cite:

```
[Your Citation Here]
```

## 🙏 Acknowledgments

Built with:
- [DADA2](https://benjjneb.github.io/dada2/)
- [VSEARCH](https://github.com/torognes/vsearch)
- [Trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic)
- [FLASH](https://ccb.jhu.edu/software/FLASH/)
- [Cutadapt](https://cutadapt.readthedocs.io/)
- [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi)

## 🔄 Version History

- **v2.0.0** (2024) - Major update with improved installation, multiple ASV methods, preset primers
- **v1.0.0** (2024) - Initial release

---

Made with ❤️ for the eDNA community
README

# QUICKSTART.md
cat > "$PACKAGE_NAME/docs/QUICKSTART.md" << 'QUICKSTART'
# Quick Start Guide - 5 Minutes to Results

Get your eDNA analysis running in just 5 minutes!

## Prerequisites

- Linux or macOS (Windows users: use WSL2)
- Conda/Miniconda installed
- 8GB+ RAM
- Your sequencing data ready

## Step-by-Step

### 1. Install (2 minutes)

```bash
git clone https://github.com/yourusername/eDNA-12S-Pipeline.git
cd eDNA-12S-Pipeline
./install.sh
```

Wait while conda installs dependencies (~2 minutes).

### 2. Prepare Your Data (1 minute)

Organize your FASTQ files in sample folders:

```
my_samples/
├── sample1/
│   ├── sample1_R1.fq.gz
│   └── sample1_R2.fq.gz
├── sample2/
│   ├── sample2_R1.fq.gz
│   └── sample2_R2.fq.gz
```

### 3. Activate Environment (5 seconds)

```bash
conda activate edna-pipeline
```

### 4. Run Analysis (2 minutes for small datasets)

```bash
./edna_pipeline.sh -i /path/to/my_samples
```

That's it! The pipeline will:
- ✓ Quality filter your reads
- ✓ Merge paired-end sequences
- ✓ Remove primers
- ✓ Call ASVs/OTUs
- ✓ Assign taxonomy
- ✓ Generate reports

### 5. Check Results (1 minute)

Your results are in `results_YYYYMMDD_HHMMSS/final_reports/`:

```bash
cd results_*/final_reports
ls -lh

# View top species
head -20 species_abundance_summary.csv
```

## Common Scenarios

### Using DADA2 Instead of OTUs

```bash
./edna_pipeline.sh -i samples/ --asv-method dada2
```

### Using Different Primers

```bash
# See available presets
./edna_pipeline.sh --list-presets

# Use Teleo primers
./edna_pipeline.sh -i samples/ --preset 12s-teleo
```

### Custom Primers

```bash
./edna_pipeline.sh -i samples/ --preset custom \
    --forward-primer YOURFORWARDPRIMER \
    --reverse-primer YOURREVERSEPRIMER
```

## Troubleshooting

**Problem**: conda: command not found
- **Solution**: Install Miniconda from https://docs.conda.io/en/latest/miniconda.html

**Problem**: No samples detected
- **Solution**: Check your directory structure matches the expected format

**Problem**: DADA2 installation fails
- **Solution**: Try manually: `conda activate edna-pipeline; R`, then `BiocManager::install('dada2')`

For more help, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## Next Steps

- Read [EXAMPLES.md](EXAMPLES.md) for real-world scenarios
- Explore [OUTPUTS.md](OUTPUTS.md) to understand your results
- Check [INSTALLATION.md](INSTALLATION.md) for advanced setup options

Happy analyzing! 🧬
QUICKSTART

echo "  ✅ Documentation created"

# ============================================================================
# TEST DATA STRUCTURE
# ============================================================================
echo "📝 Creating test data structure..."

cat > "$PACKAGE_NAME/test_data/README.md" << 'TESTREADME'
# Test Data

Small test dataset for validating the pipeline installation.

## Usage

```bash
cd test_data
./run_test.sh
```

This will run the pipeline on minimal test data to verify everything works.

## Adding Your Own Test Data

Place small FASTQ files (1000-5000 reads) in `samples/` directory:

```
samples/
├── test_sample1/
│   ├── test_sample1_R1.fq.gz
│   └── test_sample1_R2.fq.gz
```

Then run: `./run_test.sh`
TESTREADME

cat > "$PACKAGE_NAME/test_data/run_test.sh" << 'TESTSCRIPT'
#!/bin/bash

# Test script for eDNA pipeline

set -e

echo "🧪 Running pipeline test..."
echo ""

if [[ ! -d "samples" ]] || [[ -z "$(ls -A samples 2>/dev/null)" ]]; then
    echo "❌ No test samples found in test_data/samples/"
    echo ""
    echo "To add test data:"
    echo "  1. Create samples/test_sample1/ directory"
    echo "  2. Add small FASTQ files (R1 and R2)"
    echo "  3. Run this script again"
    exit 1
fi

echo "✓ Test samples found"
echo ""

# Run pipeline
../edna_pipeline.sh -i samples -o test_results --threads 2

echo ""
echo "✅ Test completed successfully!"
echo "  Check test_results/ for outputs"
TESTSCRIPT

chmod +x "$PACKAGE_NAME/test_data/run_test.sh"

mkdir -p "$PACKAGE_NAME/test_data/samples"

echo "  ✅ Test data structure created"

# ============================================================================
# DATABASE README
# ============================================================================
echo "📝 Creating database documentation..."

cat > "$PACKAGE_NAME/Database/README.md" << 'DBREADME'
# Database Setup

## Required Files

Place your reference database files in this directory:

1. **Reference sequences** (FASTA format)
   - Name: `reference_sequences.fasta` (or any `.fasta`/`.fa` file)
   - Format: Standard FASTA with headers

2. **Taxonomy mapping** (CSV format) - Optional but recommended
   - Name: Should contain "taxonomy" in filename (e.g., `taxonomy_mapping.csv`)
   - Required columns: `Accession`, `Species`, `Genus`

## File Format Examples

### FASTA Format
```
>NC_001318.1 Gadus morhua mitochondrion
ACTGGGATTAGATACCCCACTATGCTTAG...
>NC_002629.1 Salmo salar mitochondrion
ACTGGGATTAGATACCCCACTATGCTTAT...
```

### Taxonomy CSV Format
```csv
Accession,Species,Genus,Family
NC_001318.1,Gadus morhua,Gadus,Gadidae
NC_002629.1,Salmo salar,Salmo,Salmonidae
```

## Database Sources

### Recommended 12S Databases

1. **MIDORI2**
   - Download: http://www.reference-midori.info/
   - Coverage: Comprehensive fish database
   - Format: Ready to use

2. **NCBI RefSeq**
   - Download: https://www.ncbi.nlm.nih.gov/refseq/
   - Coverage: Broad taxonomic coverage
   - Requires: Taxonomy file creation

3. **CRABS**
   - Tool: https://github.com/gjeunen/reference_database_creator
   - Purpose: Custom database creation
   - Benefit: Trimmed to your primers

## Building BLAST Database

The installer automatically builds BLAST databases.

To manually rebuild:
```bash
conda activate edna-pipeline
makeblastdb -in reference_sequences.fasta \
            -dbtype nucl \
            -out reference_sequences_blast \
            -parse_seqids
```

## Testing Database

After adding files, verify:
```bash
ls -lh
# Should see .fasta and .csv files

# Test BLAST database
blastn -db reference_sequences_blast -query test.fa -outfmt 6
```

## Troubleshooting

**No database files found**
- Check file extensions (.fasta, .fa, .csv)
- Run `./install.sh` to rebuild databases

**BLAST database not found**
- Ensure FASTA files are present
- Re-run install script

For more help, see docs/TROUBLESHOOTING.md
DBREADME

echo "  ✅ Database documentation created"

# ============================================================================
# FINAL PACKAGE SETUP
# ============================================================================
echo ""
echo "📝 Creating LICENSE and final files..."

cat > "$PACKAGE_NAME/LICENSE" << 'LICENSE'
MIT License

Copyright (c) 2024 [Your Name]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LICENSE

cat > "$PACKAGE_NAME/.gitignore" << 'GITIGNORE'
# Results and outputs
results_*/
test_results/

# Python
__pycache__/
*.py[cod]
*$py.class

# R
.Rproj.user/
.Rhistory
.RData
.Ruserdata

# Conda
*.conda
*.tar.bz2

# System files
.DS_Store
Thumbs.db

# Logs
*.log

# Large files (don't commit databases to git by default)
Database/*.fasta
Database/*.fa
Database/*.nhr
Database/*.nin
Database/*.nsq
!Database/README.md

# Test data (add your own)
test_data/samples/*
!test_data/samples/.gitkeep
GITIGNORE

# Create .gitkeep for empty directories
touch "$PACKAGE_NAME/test_data/samples/.gitkeep"

# Version file
echo "2.0.0" > "$PACKAGE_NAME/VERSION"

echo "  ✅ License and git files created"

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ eNA 12S Pipeline v2.0 Package Created Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Package location: $PACKAGE_NAME"
echo ""
echo "📊 Package contents:"
find "$PACKAGE_NAME" -type f | head -30
echo ""
echo "🎯 NEXT STEPS FOR GITHUB:"
echo ""
echo "1. Add your database files:"
echo "   cp /path/to/your/database.fasta $PACKAGE_NAME/Database/"
echo "   cp /path/to/your/taxonomy.csv $PACKAGE_NAME/Database/"
echo ""
echo "2. Test locally:"
echo "   cd $PACKAGE_NAME"
echo "   ./install.sh"
echo "   conda activate edna-pipeline"
echo "   ./edna_pipeline.sh --help"
echo ""
echo "3. Initialize git repository:"
echo "   cd $PACKAGE_NAME"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit: eDNA Pipeline v2.0'"
echo ""
echo "4. Create release on GitHub:"
echo "   - Go to: Releases → Create a new release"
echo "   - Tag: v2.0.0"
echo "   - Title: eDNA 12S Pipeline v2.0"
echo "   - Description: "
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌟 Pipeline is ready! 🌟"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""