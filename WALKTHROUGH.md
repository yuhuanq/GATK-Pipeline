# GATK Variant Calling Walkthrough

Relatively succinct walkthrough of the Broad Institute's Genome Analysis Toolkit best practices workflow.

Refer to  https://www.broadinstitute.org/gatk/guide for more detailed documentation.

## What is GATK?

A Toolkit for Genome Analysis.

More specifically, it's a toolkit for variant discovery.

The GATK is the industry standard for identifying SNPs and indels in germline DNA and RNAseq data.

## Prerequisite packages/software
Most likely your cluster/server should already have these installed. Nonetheless,

GATK: https://www.broadinstitute.org/gatk/download/

Picard Tools: http://broadinstitute.github.io/picard/

Samtools: http://www.htslib.org/download/


### Mapping reads to Reference

Next-generation Sequencing (NGS) -> enormous pile of short reads. Need to align/map to reference genome. 

For DNAseq, map reads using Burrows-Wheeler Aligner, 'bwa mem' algorithm. 
```bash
>>> bwa mem -M [reference] yourFile.fastq > yourFile.sam
```

### Placeholder

Placeholder

```bash
>>> sudo dnf install vlc
```
#### Placeholder

Placeholder

### Placeholder

Placeholder

```bash
>>> sudo apt-get install vlc
```
