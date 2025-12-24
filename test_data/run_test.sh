#!/bin/bash
set -e

echo "🧪 Running pipeline test..."

if [[ ! -d "samples" ]] || [[ -z "$(ls -A samples 2>/dev/null)" ]]; then
    echo "❌ No test samples in test_data/samples/"
    echo "Add small FASTQ files to test"
    exit 1
fi

../edna_pipeline.sh -i samples -o test_results --no-blast --threads 2

echo "✅ Test completed! Check test_results/"
