#!/usr/bin/env Rscript

"Usage: process_csv [options]

This utility script converts the 'lrs_tools_master.csv' spreadsheet to a set
of files in 'docs/data' required for the lrs-tools.org website including:

Options:
-s --no-shields    Skip downloading of shields
-c --no-citations  Skip getting Crossref citations
-p --no-packages   Skip downloading of package lists
-a --no-analysis   Skip plotting for analysis page
" -> doc

#### PACKAGES ####

suppressPackageStartupMessages({
    library(readr)
    library(jsonlite)
    library(docopt)
    library(pbapply)
    library(magrittr)
    library(futile.logger)
    library(aRxiv)
})

#### SOURCE ####

source("R/load.R")
source("R/manipulation.R")
source("R/misc.R")
source("R/output.R")
source("R/plotting.R")
source("R/references.R")
source("R/repositories.R")
source("R/titles.R")

#### FUNCTIONS ####

#' Process CSV
#'
#' Process `lrs_tools_master.csv` and create the various output files
process_csv <- function(skip_shields = FALSE, skip_cites = FALSE,
                        skip_packages = FALSE, skip_analysis = FALSE) {

    flog.info("***** STARTING PROCESSING *****")

    flog.info("***** Loading data ******")
    # Load data
    swsheet <- get_swsheet()
    
    if (!skip_packages) {
        pkgs <- get_pkgs()
    } else {
        msg <- "Skipping downloading of package lists, they may be out of date!"
        flog.warn(msg)
        pkgs <- list(BioC  = "DUMMMY",
                     CRAN  = "DUMMY",
                     PyPI  = "DUMMY",
                     Conda = "DUMMY")
    }
    descs <- get_descriptions()
    titles_cache <- get_cached_titles()

    # Add new titles
     titles_cache <- add_to_titles_cache(swsheet, titles_cache)

    # Check repositories
    repos <- check_repos(swsheet$Name, pkgs)

    # Process table
    flog.info("***** Processing table ******")
    swsheet <- swsheet %>%
        add_refs(titles_cache, skip_cites) %>%
        add_github() %>%
        add_repos(repos)

    # Convert to tidy format for technologies
    tidysw_tech <- tidy_swsheet_tech(swsheet)

    # Add technologies to table
    swsheet <- add_techs(swsheet, tidysw_tech)
    
    # Convert to tidy format for categories
    tidysw_cat <- tidy_swsheet_cat(swsheet)
    
    # Add categories to table
    swsheet <- add_cats(swsheet, tidysw_cat)
    
    flog.info("***** Downloading shields ******")
    # Get shields
    if (!skip_shields) {
        get_shields(swsheet)
    } else {
        msg <- paste("Downloading of shields has been skipped,",
                     "they may be out of date!")
        flog.warn(msg)
    }

    # Convert to JSON
    flog.info("***** Converting to JSON *****")
    flog.info("Converting table...")
    make_table_json(swsheet)
    make_tools_json(tidysw_cat)
    make_cats_json(tidysw_cat, swsheet, descs)
    make_techs_json(tidysw_tech, swsheet, descs)

    flog.info("***** Performing analysis *****")
    if (!skip_analysis) {
        # Make plots
        flog.info("Plotting published tools over time...")
        plot_number(swsheet)
        flog.info("Plotting publication status...")
        plot_publication(swsheet)
        flog.info("Plotting platforms...")
        plot_platforms(swsheet)
        flog.info("Plotting technologies...")
        plot_technologies(swsheet)
        flog.info("Plotting categories...")
        plot_categories(swsheet)
    } else {
        flog.warn("Skipping analysis, this may be out of date!")
    }

    if (sum(c(skip_shields, skip_cites, skip_packages, skip_analysis)) == 0) {
        write_footer()
        flog.info("****** All processing complete *****")
    } else {
        msg <- paste("Some processing has been skipped, last updated time will",
                     "not be set!")
        flog.warn(msg)
    }

    flog.info("**** PROCESSING FINISHED *****")
}

#### MAIN CODE ####

logo <- "
                                        ###
                                      #     #
                                    #   @ @   #                            
                                  #   @ @ @ @   #  
                                #   @ @ @ @ @ @   #
                              ##                   ##
                              ##  @ @ @ @ @ @ @ @  ##
                              ##      @ @ @ @    ## 
                                  #     @ @     #
                                    #   @ @   #  
                                      #  @  #
                                        ###
 

                  LLL     RRRRRR   SSSSSSS      DDDDDD    BBBBBB  
                  LLL     RR   RR  SS           DD    D   BB    B
                  LLL     RRRRRR   SSSSSSS  ==  DD    DD  BBBBBB
                  LLL     RR  RRR       SS      DD    D   BB    B
                  LLLLLL  RR   RR  SSSSSSS      DDDDDD    BBBBBB
              

"

cat(logo)

# Show warnings
options(warn = 1)

# Setup logging
layout <- layout.format('[~t] ~l: ~m')
invisible(flog.layout(layout))
invisible(flog.appender(appender.tee("processing.log")))

# Setup progress bar
pboptions(type = "timer", char = "=", style = 3)

# Get options
opts <- docopt(doc)

# Process table
process_csv(opts[["--no-shields"]], opts[["--no-citations"]],
            opts[["--no-packages"]], opts[["--no-analysis"]])
