# GATK Variant Calling Walkthrough

Relatively succinct walkthrough of the Broad Institute's Genome Analysis Toolkit best practices workflow.

Refer to  https://www.broadinstitute.org/gatk/guide for more detailed documentation.

## What is GATK?

A Toolkit for Genome Analysis.

More specifically, it's a toolkit for variant discovery.

The GATK is the industry standard for identifying SNPs and indels in germline DNA and RNAseq data.

## Prerequisite packages/software and Documentation
Most likely your cluster/server should already have these installed. Nonetheless,

GATK: https://www.broadinstitute.org/gatk/download/

Picard Tools: http://broadinstitute.github.io/picard/

Samtools: http://www.htslib.org/download/

```bash
PICARD="/data/software/picard"
SAMTOOLS="samtools"
GATK="java -jar /data/software/gatk-3.3/GenomeAnalysisTK.jar"
```

## Pre-Processing

### Mapping reads to Reference

Next-generation Sequencing (NGS) -> enormous pile of short reads. Need to align/map to reference genome. 

For DNAseq, map reads using Burrows-Wheeler Aligner, 'bwa mem' algorithm. 
```bash
>>> bwa mem -M [reference] raw_reads.fq > aligned_reads.sam
```
The -M flag causes BWA to mark shorter split hits as secondary (essential for Picard compatibility).

Next, use Picard sortsam to convert the .sam to .bam (compact binary version, not human readable) and sort the aligned reads by coordinates.
```bash
java -jar $PICARD/SortSam.jar \
INPUT=aligned_reads.sam \ 
OUTPUT=yourfile.bam \
SORT_ORDER=coordinate
```

http://broadinstitute.github.io/picard/command-line-overview.html

### Marking Duplicates

During the sequencing process, the same DNA fragments may be sequenced several times. Resulting duplciate reads are not helpful and can propagate sequencing errors across all the subsequent duplicate reads. In addition, the non-independent nature of duplicate reads violate the assumptions of variant calling. Will mark and delete duplicate reads, leaving original.

```bash
java -jar $PICARD/MarkDuplicates.jar \
INPUT=yourfile.bam \
OUTPUT=yourfile_dedup.bam \
METRICS_FILE=metrics.txt
```

#### Adding read group info

```bash
java -jar $PICARD/AddOrReplaceReadGroups.jar \
RGLB=L001 \
RGPL=illumina \
RGPU=C2U2AACXX \
RGSM=$fName \
I=$fName''_dedup.bam \
O=$fName''_AddOrReplaceReadGroups.bam
```

### Placeholder

Placeholder

```bash
>>> sudo apt-get install vlc
```
