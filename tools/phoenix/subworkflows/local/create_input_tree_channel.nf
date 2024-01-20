//
// workflow handles taking in either a samplesheet or directory and creates correct channels.
//

include { CREATE_SAMPLESHEET          } from '../../modules/local/create_samplesheet'

workflow CREATE_INPUT_CHANNEL {
    take:
        indir        // params.indir
        samplesheet  // params.input
        ch_versions

    main:
        //if input directory is passed use it to gather assemblies otherwise use samplesheet
        if (indir != null) {
            def gff_glob = append_to_path(params.indir.toString(),'*.gff')
                //create gff channel with meta information -- annoying, but you have to keep this in the brackets instead of having it once outside.
                gff_ch = Channel.fromPath(gff_glob) // use created regrex to get samples
                    .filter( it -> !(it =~ 'filtered') ) // remove samples that are *.filtered.gff.fa.gz
                    .filter( it -> !(it =~ 'renamed') ) // remove samples that are *.renamed.gff.fa.gz
                    .filter( it -> !(it =~ 'contig') ) // remove samples that are *.contigs.fa.gz
                    .map{ it -> create_meta(it, params.gff_file.toString())} // create meta for sample
                    //.ifEmpty(exit 1, "ERROR: Looks like there isn't assemblies in the folder you passed. PHoeNIx doesn't search recursively!\n") // this doesn't work for some reason. 
                // Checking regrex has correct extension
                gff_ch.collect().map{ it -> check_gff(it) }

            //get valid samplesheet for griphin step in cdc_gff
            CREATE_SAMPLESHEET (
                indir
            )
            ch_versions = ch_versions.mix(CREATE_SAMPLESHEET.out.versions)

            valid_samplesheet = CREATE_SAMPLESHEET.out.samplesheet
        } 

    emit:
        gff_ch      = gff_ch       // channel: [ meta, [ gff_file ] ]
        valid_samplesheet = valid_samplesheet
        versions          = ch_versions

}

/*
========================================================================================
    GROOVY FUNCTIONS
========================================================================================
*/

def append_to_path(full_path, string) {
    if (full_path.toString().endsWith('/')) {
        new_string = full_path.toString() + string
    }  else {
        new_string = full_path.toString() + '/' + string
    }
    return new_string
}

def create_meta(sample, file_extension){
    '''Creating meta: [[id:sample1, single_end:true], $PATH/sample1.gff]'''
    sample_name_minus_path = sample.toString().split('/')[-1] // get the last string after the last backslash
    sample_name = sample_name_minus_path.replaceAll(file_extension, "") // remove file extention to get only sample name 
    def meta = [:] // create meta array
    meta.id = sample_name
    meta.single_end = 'true'
    array = [ meta, sample ]  //file() portion provides full path
    return array
}

// Function to get list of [ meta, [ gff_file ] ]
def create_assembly_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id         = row.sample
    meta.single_end = 'true'

    // add path(s) of the assembly file(s) to the meta map
    def assembly_meta = []
    if (!file(row.assembly).exists()) {
        exit 1, "ERROR: Please check assembly samplesheet -> Assembly gff file does not exist!\n${row.assembly}"
    }
    assembly_meta = [ meta, file(row.assembly) ]
    return assembly_meta
}

def check_gff(scaffold_channel) {
    if (scaffold_channel[1].toString().endsWith(".gff") or scaffold_channel[1].toString().endsWith(".gff") ) {
        //If there is the correct ending just move along
    } else {
         exit 1, "ERROR: No gff found. Either your scaffold regrex is off (gff files should end in '.gff') or the directory provided doesn't contain gff files." 
    }
}