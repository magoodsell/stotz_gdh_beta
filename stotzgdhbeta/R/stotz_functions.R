# Script contains Functions from stotz_Snowflake_SP22/scripts/latest_example_hrrr.R

# Goal:

# make packages more robust of
pacman::p_load(
tidyverse
, sf            # Simple feature - used for spatial data https://cran.r-project.org/web/packages/sf/index.html
, raster        # a spatial (geographic) data structure that divides a region into rectangles https://rspatial.org/raster/pkg/1-introduction.html
, ncdf4         #  https://cran.r-project.org/web/packages/ncdf4/index.html
, reticulate    # interface to Python https://cran.r-project.org/web/packages/reticulate/index.html
, stringi       #  https://cran.r-project.org/web/packages/stringi/index.html
, plyr          # used for manipulation of data https://cran.r-project.org/web/packages/plyr/index.html
, dplyr         # data manipulation https://dplyr.tidyverse.org/
, furrr         # apply mapping functions in parallel using future package https://cran.r-project.org/web/packages/furrr/index.html
#loaded in tidyverse , purrr         # in tidyverse https://purrr.tidyverse.org/
, DBI           # Database Interface
, dbpylr        # a backend for database https://cran.r-project.org/web/packages/dbplyr/index.html
, odbc          #  https://cran.r-project.org/web/packages/odbc/index.html
, spatialrisk   # methods for spatial risk calculations https://cran.r-project.org/web/packages/spatialrisk/index.html
, measurements  #  https://cran.r-project.org/web/packages/measurements/index.html
)



