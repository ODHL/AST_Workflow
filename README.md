# ODHL/AST Pipeline

## Background
This pipeline was built from components of two pipelines:

1) PHoeNIx: A short-read pipeline for healthcare-associated and antimicrobial resistant pathogens
2) DRYAD: 

## Dependencies

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.10.3-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=21.10.3`). 

   There are several options for install if you do not already have it on your system:

   * Install into conda environment, which will require a version of Anaconda to be installed on your system.

       ```console
       mamba create -n nextflow -c bioconda nextflow=21.10.6  
       ```

      <!---```console
       mamba create -n nextflow -c bioconda -c conda-forge nf-core=2.2 nextflow=21.10.6 git=2.35.0 openjdk=8.0.312 graphviz
       ```--->

   * If you prefer a to use `curl` or `wget` for install see the [Nextflow Documentaiton](https://www.nextflow.io/docs/latest/getstarted.html) 

2. Install [`Docker`](https://docs.docker.com/engine/installation/) or [`Singularity >=3.8.0`](https://www.sylabs.io/guides/3.0/user-guide/) for full pipeline reproducibility. 

3. Email HAISeq@cdc.gov, with the subject line "krakenDB invite request" to request access to the sharefile link and provide the email address to send invite to.

4. Download the `hash.k2d`, `opts.k2d`, and `taxo.k2d` files needed for the kraken2 subworkflow of PHoeNIx from the CDC sharefile link. You **CANNOT** use a different krakenDB for this as it needs to match the `ktax_map.k2` file that is included in the pipeline. At this time this is not downloadable via command line. Once downloaded the folder containing these files is passed to PHoeNIx via the `--kraken2db`.

5. Run pipeline:
    Initialize
    ```console
    bash run_workflow.sh -p init -n <name of project>
    ```

    Run 
    ```console
    # first Nextflow pass
    bash run_workflow.sh -p analysis -n <name of project>

    # resume nextflow run
    bash run_workflow.sh -p analysis -n <name of project>-r Y

    # to directly run nextflow
    nextflow run -r v1.0.0 -profile docker -entry PHOENIX --kraken2db $PATH_TO_DB
    ```