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

http://samtools.github.io/hts-specs/SAMv1.pdf

```bash
PICARD="/data/software/picard"
SAMTOOLS="samtools"
GATK="java -jar /data/software/gatk-3.3/GenomeAnalysisTK.jar"
```

## Pre-Processing

raw reads --> map to reference --> mark duplicates --> realignment (indels) --> base recalibration => analysis ready reads

### Mapping reads to Reference

Next-generation Sequencing (NGS) -> enormous pile of short reads. Need to align/map to reference genome. 

For DNAseq, map reads using Burrows-Wheeler Aligner, 'bwa mem' algorithm. 
```bash
>>> bwa mem -M [reference] raw_reads.fq > aligned_reads.sam
```
The ```-M``` flag causes BWA to mark shorter split hits as secondary (essential for Picard compatibility).

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

Read groups are set of reads that were generated from a single run from a sequencing machine. They allow GATK to differentiate samples and various technical features associated with the runs. Since this tutorial is for working with raw fastq files (easier if raw sam files), needed to sort sam and now add read groups manually. 

```bash-
java -jar $PICARD/AddOrReplaceReadGroups.jar \
RGLB=L001 \
RGPL=illumina \
RGPU=C2U2AACXX \
RGSM=$fName \
I=$fName''_dedup.bam \
O=$fName''_AddOrReplaceReadGroups.bam
```

Here we are replacing all read groups in the INPUT file with a single new read group and assigning to the OUTPUT bam file. Flag information available in picard command line overview documentation linked previously.

### Realign Indels

Next, we need to perform local realignment on indel affected regions/artficats. Presence of insertions or deletions on the reads in respect to the reference leads to many bases mismatching the reference near the misalignment, which are easily mistaken as SNPs. Thus 

There are 2 steps to the realignment process:

1. Determining (small) suspicious intervals which are likely in need of realignment (RealignerTargetCreator)
2. Running the realigner over those intervals (see the IndelRealigner tool)

```bash
$GATK \
-T RealignerTargetCreator \
-R ucsc.hg19.fasta \
-I $fName''_AddOrReplaceReadGroups.bam \
--known Mills_and_1000G_gold_standard.indels.hg19.sites.vcf \
-o $fName''_realigner.intervals
```

```--known``` flag takes in vcf file argument containing known SNPs and or indels, could be dbSNP or 1000 Genomes indel calls. SNPs found in new read-reference alignment will be ignored.

```bash
$GATK \
-I $fName''_AddOrReplaceReadGroups.bam \
-R ucsc.hg19.fasta \
-T IndelRealigner  \
-targetIntervals $fName''_realigner.intervals \
-known Mills_and_1000G_gold_standard.indels.hg19.sites.vcf \
-o $fName''_realigned.bam
```

### Base recalibration
