#!/bin/sh
#$ -N ARDS_exom-seq
#$ -j y
#$ -cwd
#$ -o /data/scratch/ARDS/ARDS_$JOB_ID.out
#$ -e /data/scratch/ARDS/cuffdiff_$JOB_ID.err
#$ -q all.q
###################qsub [options] above#######################
############################################################
# Softwares file locations, and other settings; change accordingly

PICARD="/data/software/picard"
SAMTOOLS="samtools"
GATK="java -jar /data/software/gatk-3.3/GenomeAnalysisTK.jar"
dataDir="/data/scratch/ARDS/dbGAP-ARDS-fastq" #for Pair-end seq data make sure file names are ordered well
pairEndSeq=true #single or pair

############################################################

ls --format="single-column" $dataDir > tmpDataFiles.txt


while read -r line1; do
	if [ $pairEndSeq = true ] 
	then
		read -r line2;
	fi

	fName=$(echo $line1 | grep -oP "SRR[0-9]*")
	
	if [ $pairEndSeq = true ] 
	then
		bwa mem ucsc.hg19.fasta dbGAP-ARDS-fastq/$line2.fastq dbGAP-ARDS-fastq/$line1.fastq > $fName.sam #read alignment
	else
		bwa mem ucsc.hg19.fasta dbGAP-ARDS-fastq/$line1.fastq > $fName.sam #read alignment
	fi
	
	java -jar $PICARD/SortSam.jar \
	INPUT=$fName.sam \
	OUTPUT=$fName.bam \
	SORT_ORDER=coordinate 

	rm $fName.sam

	java -jar $PICARD/MarkDuplicates.jar \
	INPUT=$fName.bam \
	OUTPUT=$fName''_dedup.bam \
	METRICS_FILE=metrics.txt

	java -jar $PICARD/AddOrReplaceReadGroups.jar \
	RGLB=L001 \
	RGPL=illumina \
	RGPU=C2U2AACXX \
	RGSM=$fName \
	I=$fName''_dedup.bam \
	O=$fName''_AddOrReplaceReadGroups.bam

	rm $fName''_dedup.bam 

	$SAMTOOLS index $fName''_AddOrReplaceReadGroups.bam

	$GATK \
	-T RealignerTargetCreator \
	-R ucsc.hg19.fasta \
	-I $fName''_AddOrReplaceReadGroups.bam \
	--known Mills_and_1000G_gold_standard.indels.hg19.sites.vcf \
	-o $fName''_realigner.intervals

	$GATK \
	-I $fName''_AddOrReplaceReadGroups.bam \
	-R ucsc.hg19.fasta \
	-T IndelRealigner  \
	-targetIntervals $fName''_realigner.intervals \
	-known Mills_and_1000G_gold_standard.indels.hg19.sites.vcf \
	-o $fName''_realigned.bam

	rm $fName''_AddOrReplaceReadGroups.bam

	
	$GATK \
	-I $fName''_realigned.bam \
	-R ucsc.hg19.fasta \
	-T BaseRecalibrator \
	-knownSites dbsnp_138.hg19.vcf \
	-knownSites Mills_and_1000G_gold_standard.indels.hg19.sites.vcf \
	-o $fName''_BaseRecalibrator.grp


	$GATK \
	-R ucsc.hg19.fasta \
	-T PrintReads \
	-BQSR $fName''_BaseRecalibrator.grp \
	-I $fName''_realigned.bam \
	-o $fName''_PrintReads.bam

	rm $fName''_realigned.bam

	$GATK \
	-T HaplotypeCaller \
	-variant_index_type LINEAR \
	-variant_index_parameter 128000 \
	-ERC GVCF \
	-R ucsc.hg19.fasta \
	-I $fName''_PrintReads.bam \
	-stand_emit_conf 10 \
	-stand_call_conf 30 \
	-o raw''_$fName.g.vcf

done < tmpDataFiles.txt

rm tmpDataFiles.txt
