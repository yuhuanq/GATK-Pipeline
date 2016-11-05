# GATK Variant Calling Walkthrough

Relatively succinct walkthrough of the Broad Institute's Genome Analysis Toolkit best practices workflow.

DNA-Seq workflow mainly.

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
RGSM=yourfile \
I=yourfile_dedup.bam \
O=yourfile_AddOrReplaceReadGroups.bam
```

Here we are replacing all read groups in the INPUT file with a single new read group and assigning to the OUTPUT bam file. Flag information available in picard command line overview documentation linked previously.

Indexing the bam file:
Index for fast random access to the genome. 
```bash
>>>$SAMTOOLS index yourfile_AddOrReplaceReadGroups.bam
```
yourfile_AddOrReplaceReadGroups.bai will be produced.

### Realign Indels

Next, we need to perform local realignment on indel affected regions/artficats. Presence of insertions or deletions on the reads in respect to the reference leads to many bases mismatching the reference near the misalignment, which are easily mistaken as SNPs. Thus 

There are 2 steps to the realignment process:

1. Determining (small) suspicious intervals which are likely in need of realignment (RealignerTargetCreator)
2. Running the realigner over those intervals (see the IndelRealigner tool)

```bash
$GATK \
-T RealignerTargetCreator \
-R ucsc.hg19.fasta \
-I yourfile_AddOrReplaceReadGroups.bam \
--known Mills_and_1000G_gold_standard.indels.hg19.sites.vcf \
-o yourfile_realigner.intervals
```

```--known``` flag takes in vcf file argument containing known SNPs and or indels, could be dbSNP or 1000 Genomes indel calls. SNPs found in new read-reference alignment will be ignored.

```bash
$GATK \
-I yourfile_AddOrReplaceReadGroups.bam \
-R ucsc.hg19.fasta \
-T IndelRealigner  \
-targetIntervals yourfile_realigner.intervals \
-known Mills_and_1000G_gold_standard.indels.hg19.sites.vcf \
-o yourfile_realigned.bam
```

### Base recalibration

Variant calling algorithms rely heavily on quality scores assigned to each base call. However, scores assigned by machine prone to systematic error. Base quality score recalibration (BQSR) is a process in which we apply machine learning to model these errors empirically and adjust the quality scores accordingly. This allows us to get more accurate base qualities, which in turn improves the accuracy of our variant calls.

i.e. Recalibrate base quality scores to correct sequencing errors and other experimental artifacts.
read more: https://www.broadinstitute.org/gatk/guide/tooldocs/org_broadinstitute_gatk_tools_walkers_bqsr_BaseRecalibrator.php

Modeling the error,
```bash
$GATK \
-T BaseRecalibrator \
-I yourfile_realigned.bam \
-R ucsc.hg19.fasta \
-knownSites dbsnp_138.hg19.vcf \
-knownSites Mills_and_1000G_gold_standard.indels.hg19.sites.vcf \
-o yourfile_BaseRecalibrator.grp   #.grp for <=3.3, latest version output is .table?
```

Apply recalibration and write to file,
```bash
$GATK \
-T PrintReads \
-R ucsc.hg19.fasta \
-BQSR yourfile_BaseRecalibrator.grp \
-I yourfile_realigned.bam \
-o yourfile_PrintReads.bam
```

Note: Recalibration produces a more accurate estimation of error; doesn't fix it. 

If non-human genome and no known resource for recalibration -> bootstrap a set of known variants. ( – Call	variants	on	realigned,	unrecalibrated	data	– Filter	resul2ng	variants	with	stringent	filters	– Use	variants	that	pass	filters	as	known	for	BQSR	– Repeat	un2l	convergence )

## Variant Discovery
Once pre-processed data, ready to undertake the variant discovery process, i.e. identify the sites where your data displays variation relative to the reference genome, and calculate genotypes for each sample at that site.

1. Variant Calling, maximized sensitivity
2. Variant Filtering, delivers specificity

Minimize false negatives, and false positives.

For DNA, the variant calling step is further subdivided into two separate steps (per-sample calling followed by joint genotyping across samples)

### Calling Variants

Will use HaplotypeCaller to perform local de-novo assembly to call SNPs and indels simultaneously.

De Novo Assembly and De Bruijn Graphs: http://www.cs.jhu.edu/~langmea/resources/lecture_notes/assembly_dbg.pdf

####How HaplotypeCaller works

1. Define active regions
The program determines which regions of the genome it needs to operate on, based on the presence of significant evidence for variation.

2. Determine haplotypes by assembly of the active region
For each ActiveRegion, the program builds a De Bruijn-like graph to reassemble the ActiveRegion, and identifies what are the possible haplotypes present in the data. The program then realigns each haplotype against the reference haplotype using the Smith-Waterman algorithm in order to identify potentially variant sites.

3. Determine likelihoods of the haplotypes given the read data
For each ActiveRegion, the program performs a pairwise alignment of each read against each haplotype using the PairHMM algorithm. This produces a matrix of likelihoods of haplotypes given the read data. These likelihoods are then marginalized to obtain the likelihoods of alleles for each potentially variant site given the read data.

4. Assign sample genotypes
For each potentially variant site, the program applies Bayes' rule, using the likelihoods of alleles given the read data to calculate the likelihoods of each genotype per sample given the read data observed for that sample. The most likely genotype is then assigned to the sample.

```bash
$GATK \
-T HaplotypeCaller \
-variant_index_type LINEAR \
-variant_index_parameter 128000 \
-ERC GVCF \
-R ucsc.hg19.fasta \
-I yourfile_PrintReads.bam \
-stand_emit_conf 10 \
-stand_call_conf 30 \
-o raw_yourfile.g.vcf
```

More flag info at documentation

More: https://www.broadinstitute.org/gatk/gatkdocs/org_broadinstitute_gatk_tools_walkers_haplotypecaller_HaplotypeCaller.php

Refer to GATK/Picard documentation for more detailed descriptions and usages. 
