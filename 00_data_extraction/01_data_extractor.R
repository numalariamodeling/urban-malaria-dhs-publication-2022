## These scripts are used to extract cluster level data and variables for urban settings in Nigeria 
rm(list=ls())
#memory.limit(size = 50000)

## -----------------------------------------
### Paths - change to fit your setup
## -----------------------------------------

user <- Sys.getenv("USERNAME")
Drive <- file.path(gsub("[\\]", "/", gsub("Documents", "", Sys.getenv("HOME"))))
NuDir <- file.path(Drive, "OneDrive", "urban_malaria")
ProjectDir <- file.path(NuDir, "data", 'nigeria','nigeria_dhs' , 'data_analysis')
DataDir <- file.path(ProjectDir, 'data')
ResultDir =file.path(ProjectDir, "results", "research_plots")
GlobDir <- file.path(DataDir, 'africa_health_district_climate', 'climate', 'global')
DHSData <- file.path(DataDir, 'DHS')
RastDir <- file.path(DataDir, "Raster_files")
DataIn <- file.path(DHSData, "Computed_cluster_information", 'urban_malaria_covariates', 'DHS_survey_extract')
GeoDir <- file.path(DHSData, "Computed_cluster_information", 'urban_malaria_covariates', 'geospatial_covariates')
shapes <- file.path(NuDir, 'data', 'nigeria_shapefiles')


# -----------------------------------------
### Required functions and settings
## -----------------------------------------
source("00_data_extraction/data_extractor_functions/data_extractor_functions.R")
options(survey.lonely.psu="adjust") # this option allows admin units with only one cluster to be analyzed


## -----------------------------------------------------------------------------------------
### Read in PR  data (DHS 2010, 2015, 2018, 2021) - this can be downloaded from the DHS website 
## ----------------------------------------------------------------------------------------

dhs <- read.files(DataDir, "*NGPR.*\\.DTA", 'NGPR81FL|NGPR7BFL|NGPR71FL|NGPR61FL', read_dta)  #reads in the PR files



## -----------------------------------------
### Data processing 
## -----------------------------------------

#create a variables for wealth and housing quality, sex, net use, survey design and educational attainment  for all years
dhs <- dhs %>% map(~mutate(., wealth = ifelse(hv270 <4, 0, 1),
                           floor_type = ifelse(hv213 >= 98, NA, ifelse(hv213 %in% c(30, 31, 33, 34, 35),1, 0)),
                           wall_type = ifelse(hv214 >= 98, NA , ifelse (hv214 %in% c(30, 31, 33, 34,35),1, 0)),
                           roof_type = ifelse(hv215 >= 98, NA, ifelse(hv215 %in% c(31),1, 0)),
                           housing_q = ifelse(floor_type == 1 & wall_type == 1 & roof_type == 1,1, 0),
                           all_female_sex = ifelse(hc27 == 1,0, 1), 
                           female_child_sex = all_female_sex,
                           net_use = ifelse(hml12 %in% c(1,2), 1,0),
                           wt=hv005/1000000,strat=hv022,
                           id=hv021, num_p=1,
                           edu_a = ifelse(hc61 %in% c(0, 1, 2), 0,ifelse(hc61 >= 8, NA, ifelse(hc61 == 2|3, 1, NA))),
                           age = ifelse(hv105 >= 98, NA, hv105),
                           age_cat = ifelse(age <18, 1, 0),
                           median_age = age,
                           mean_age =age,
                           household_size = hv013,
                           p_test = ifelse(hml32 > 1, NA, hml32),
                           U5_pop = ifelse(hc1 %in% c(0:59), 1, 0),
                           region = hv024, interview_month = hv006,
                           visitors = hv102)) %>%
  map(~filter(., hv025 == 1)) %>% #filtering to urban areas only 
  map(~dplyr::select(., -c(hv013, hv105, hc61, hv021, hv005, hv022, hml12, hc27, hv215, hv214, hv213, hv270, hv024, hv006)))


#are we using the defacto population to compute all the wealth variables? Is that a reasonable choice

#creating variable for computing pregnant women proportions 
dhs[[1]]$preg_women <- ifelse(dhs[[1]]$hml18 >= 8 , NA, ifelse(dhs[[1]]$hml18 == 1, 1, 0))
dhs[[2]]$preg_women <- ifelse(dhs[[2]]$hml18 >= 8, NA, ifelse(dhs[[2]]$hml18 == 1, 1, 0))
dhs[[3]]$preg_women <- ifelse(dhs[[3]]$hml18 >= 8, NA, ifelse(dhs[[3]]$hml18 == 1, 1, 0))
dhs[[4]]$preg_women <- ifelse(dhs[[4]]$hml18 >= 8, NA, ifelse(dhs[[4]]$hml18 == 1, 1, 0))
#
## -----------------------------------------------
### preliminary estimation with PfPR and DHS data 
## -----------------------------------------------

# create PR dataset by filtering for microscopy (denominator -hh selected for hemoglobin, child slept there last night and have result for test and urban area(hv025). PR is for children 6 - 59 months)
pfpr_df <- dhs %>% map(~filter(., hv042 == 1 & hv103 == 1 & hc1 %in% c(6:59))) #& hml16 <59 & hml32 %in% c(0, 1,6)

#compute number of household members per cluster 
df_num <- dhs %>% map(~dplyr::select(., hv001, hv009)) %>%  map(~dplyr::group_by_(., 'hv001')) %>% map(~summarise(.,num_HH = sum(hv009))) %>% 
  plyr::ldply() 

#compute number of children 6 - 59 per cluster 
df_num <- pfpr_df %>% map(~dplyr::select(., hv001, hc1)) %>%  map(~dplyr::group_by_(., 'hv001')) %>% map(~summarise(.,num_child_6_59 = n())) %>% 
  plyr::ldply() 
median(df_num$num_child_6_59)
IQR(df_num$num_child_6_59)
write.csv(df_num, paste0(DataIn, "/num_children_6_59_months.csv"), row.names = FALSE)



# create PR dataset by filtering for microscopy (denominator -hh selected for hemoglobin, child slept there last night and have result for test and urban area(hv025). PR is for children 6 - 59 months)
pfpr_df <- dhs %>% map(~filter(., hv042 == 1 & hv103 == 1 & hc1 %in% c(6:59) & hml32 %in% c(0, 1,6))) #& hml16 <59 & hml32 %in% c(0, 1,6)

#compute number of children tested for microscopy per cluster 
df_test <- pfpr_df %>% purrr::map(~dplyr::select(., hv001, hml32)) %>%  map(~dplyr::group_by(., 'hv001')) %>% map(~dplyr::summarise(.,child_6_59_tested_malaria = n())) %>% 
  plyr::ldply() 
write.csv(df_test, paste0(DataIn, "/tested_malaria_children_6_59_months.csv"), row.names = FALSE)

pfpr_df %>% purrr::map(~dplyr::select(., hv001, hml32)) %>%  map(~dplyr::group_by(., 'hv001')) %>% map(~dplyr::summarise(.,child_6_59_tested_malaria = mean(hm))) %>% 
  plyr::ldply() 

#median number of visitors by cluster
visitors_num <- dhs %>% map(~dplyr::select(., hv001, visitors)) %>%  map(~filter(., visitors == 0)) %>% map(~dplyr::group_by_(., 'hv001')) %>% map(~summarise(.,visitors = n())) %>% 
  plyr::ldply() 
write.csv(visitors_num, paste0(DataIn, "/num_visitors_DHS_10_15_18.csv"), row.names = FALSE)


## -----------------------------------------
### estimation using all PR files 
## -----------------------------------------

#get malaria count 
df <- pfpr_df %>% map(~dplyr::select(., hv001, hml32)) %>%  map(~filter(., hml32 == 1)) %>%  map(~dplyr::group_by_(., 'hv001')) %>%  map(~summarise(.,positives = n())) %>% 
  plyr::ldply()  %>%mutate(year = str_split(.id, '_', simplify = TRUE)[,4])



df_zero <- pfpr_df %>% map(~dplyr::select(., hv001, hml32)) %>%  map(~filter(., hml32 == 0)) %>%  map(~dplyr::distinct(.,)) %>% 
  plyr::ldply() %>%  mutate(year = str_split(.id, '_', simplify = TRUE)[,4])


write.csv(fin_df, paste0(DataIn, "/positive_microscopy_test_6_59_months.csv"))


#proportions 

vars <- c('net_use', 'edu_a', 'wealth', 'housing_q', 'floor_type', 'wall_type', 'roof_type', 'all_female_sex', 'U5_pop', 'preg_women')

#vars<- c('U5_pop')
for (i in 1:length(vars)) {
  col <- list(vars[i])
  by <- list('hv001')
  df <- dhs %>% 
    map(~drop_na(.,vars[i]))
  df <- pmap(list(df,col,by), estim_prop)
  df <- plyr::ldply(df)
  df[, vars[i]]<- df[, vars[i]]*100
  write.csv(df, file =file.path(DataIn, paste0(vars[i], "_all_DHS_PR_10_15_18_21.csv")))
  
}

dhs[[1]]$state <- as_label(dhs[[1]]$shstate)
dhs[[2]]$state <- as_label(dhs[[2]]$shstate)
dhs[[3]]$state <- as_label(dhs[[3]]$shstate)
dhs[[4]]$state <- as_label(dhs[[4]]$region)

vars <- c('edu_a', 'mean_age', 'median_age', 'household_size')
srvy_fun <- list(estim_prop, estim_mean, estim_median, estim_median)
stat_clu <- list('state', 'hv001', 'hv001', 'hv001')
muilt <- c(100, 1, 1, 1)


for (i in 1:length(vars)) {
  col <- list(vars[i])
  by <- list(stat_clu[[i]])
  df <- dhs%>% 
    map(~drop_na(.,vars[i]))
  df <- pmap(list(df,col,by), srvy_fun[[i]])
  df <- plyr::ldply(df)
  df[, vars[i]]<- df[, vars[i]]*muilt[[i]]
  write.csv(df, file =file.path(DataIn, paste0(vars[i], "_all_state_DHS_PR_10_15_18_21.csv")))
  
}


# month of state, region, month of survey by cluster 
dhs[[4]]$shstate <- dhs[[4]]$region *10
dhs[[4]]$region <- dhs[[4]]$shregion
vars <- c('shstate', 'region', 'interview_month')

for (i in 1:length(vars)){
  if (vars[i] == 'interview month'){
    df <- dhs %>%  map(~dplyr::select(., c(hv001, vars[i])))
    df <- plyr:: ldply(df)
    write.csv(df, file =file.path(DataDir, 'urban_malaria_cluster_est', paste0(vars[i], "_all_DHS_PR_10_15_18_21.csv")))
  }else{
  df <- dhs %>%  map(~dplyr::select(., c(hv001, vars[i])))
  df <- plyr:: ldply(df) %>%  distinct() 
  df[vars[i]] <- as_label(df[vars[i]])
  write.csv(df, file =file.path(DataIn, paste0(vars[i], "_all_DHS_PR_10_15_18_21.csv")))
  }
}


## -----------------------------------------------------------------------------
### estimation using PR files for children tested for malaria with microscopy 
## ------------------------------------------------------------------------------

#proportions 
#overall

pfpr_df<- pfpr_df %>%  map(~mutate(., net_use_child = net_use))

vars <- c('female_child_sex', 'net_use_child', 'p_test')


for (i in 1:length(vars)) {
  col <- list(vars[i])
  by <- list('hv001')
  df <-  pfpr_df %>% 
    map(~drop_na(.,vars[i])) 
  df <- pmap(list(df,col,by), estim_prop)
  df <- plyr::ldply(df)
  df[, vars[i]]<- df[, vars[i]]*100
  write.csv(df, file =file.path(DataIn, paste0(vars[i], "_PfPR_DHS_10_15_18_21.csv")))
  
}

#by state 
pfpr_df[[1]]$state <- as_label(pfpr_df[[1]]$shstate)
pfpr_df[[2]]$state <- as_label(pfpr_df[[2]]$shstate)
pfpr_df[[3]]$state <- as_label(pfpr_df[[3]]$shstate)
pfpr_df[[4]]$state <- as_label(pfpr_df[[4]]$region)


vars <- c('female_child_sex', 'net_use_child', 'p_test')
state <- c('lagos')

for (i in 1:length(vars)) {
  col <- list(vars[i])
  by <- list('hv001')
  df <-  pfpr_df %>% 
    map(~drop_na(.,vars[i])) %>%  map(~filter(., state == state[i]))
  df <- pmap(list(df,col,by), estim_prop)
  df <- plyr::ldply(df)
  write.csv(df, file =file.path(DataIn, paste0(vars[i],  state[i], "_PfPR_DHS_10_15_18_21.csv")))
  
}

#number of children tested and positives per state, year and survey month.
dhs[[4]]$state <- as_label(dhs[[4]]$region)
dhs[[4]]$region <- as_label(dhs[[4]]$shregion)
dhs2 <- dhs  %>% map(~mutate(., yr_reg_imon = paste0(hv007, "_", as_label(region), "_", interview_month))) %>% plyr::ldply() %>%
 dplyr::select(wt, id, strat, yr_reg_imon) %>% 
  mutate(across(where(is.character), str_remove_all, pattern = fixed(" ")))

 pos_region <- dhs %>% map(~ mutate(., test_sum = ifelse(hv042 == 1 & hv103 == 1 & hc1 %in% c(6:59) & hml32 %in% c(0, 1,6), 1, 0))) %>% 
   map(~mutate(., yr_reg_imon = paste0(hv007, "_", as_label(region), "_", interview_month))) %>%  map(~filter(., hml32 == 1)) %>%  
  map(~dplyr::group_by_(., 'yr_reg_imon')) %>% map(~summarise(.,positives = sum(test_sum))) %>% plyr::ldply() %>% 
   mutate(across(where(is.character), str_remove_all, pattern = fixed(" "))) 

 tested <- dhs %>% map(~filter(., hv042 == 1 & hv103 == 1 & hc1 %in% c(6:59) & hml32 %in% c(0, 1,6))) %>% 
   map(~mutate(., yr_reg_imon = paste0(hv007, "_", as_label(region), "_", interview_month))) %>% 
   map(~dplyr::group_by_(., 'yr_reg_imon')) %>% map(~summarise(.,children_tested = n())) %>% plyr::ldply() %>% 
   mutate(across(where(is.character), str_remove_all, pattern = fixed(" "))) %>%
   left_join(dhs2, by = c("yr_reg_imon")) %>% left_join(pos_region, by = c("yr_reg_imon"))
 
dhs_list <- list(tested)

vars<- c('children_tested', "positives")

for (i in 1:length(vars)) {
  col <- list(vars[i])
  by <- list('yr_reg_imon')
  df <- dhs_list %>% 
    map(~drop_na(.,vars[i]))
  df <- pmap(list(df,col,by), estim_sum)
  df <- plyr::ldply(df)
  df[, vars[i]]<- df[, vars[i]]
  write.csv(df, file =file.path(DataIn, paste0(vars[i], "_region_year_month.csv")))
  
}

df_pos <- read.csv(file.path(DataIn, "positives_region_year_month.csv")) %>%
  rename(ci_l_positives = ci_l, ci_u_positives = ci_u) 

dd <- read.csv(file.path(DataIn, "children_tested_region_year_month.csv")) %>%
  rename(ci_l_tested = ci_l, ci_u_tested = ci_u) %>% left_join(df_pos, by = "yr_reg_imon") %>% dplyr::select(-X.x, -X.y) %>%
  mutate_all(~replace(., is.na(.), 0))

write.csv(dd, file =file.path(DataIn, "region_year_month_tests.csv"))
          
## ----------------------------------------------------
### Read in KR  data (DHS 2010, 2015, 2018, 2021) 
## ----------------------------------------------------

dhs <- read.files(DataDir, "*NGKR.*\\.DTA", 'NGKR81FL|NGKR7AFL|NGKR71FL|NGKR61FL', read_dta) #reads in the KR files 
dhs <- dhs %>%  map(~mutate(., fever =  ifelse(h22 >= 8, NA, h22), ACT_use_U5 = ifelse(ml13e >=8, NA, ml13e),
                            wt=v005/1000000,strat=v022,id=v021, num_p=1, med_treat_fever = ifelse(h32z >=8, NA, h32z),)) %>%
  map(~dplyr::select(., c(fever, ACT_use_U5, wt, strat, id, v001, b5, v025, med_treat_fever))) %>% 
  map(~filter(., v025 == 1)) 


#proportions 

vars <- c('fever', 'ACT_use_U5', 'med_treat_fever')

for (i in 1:length(vars)) {
  
  if (vars[i] == 'ACT_use_U5'|vars[i] == 'med_treat_fever' ){
    col <- list(vars[i])
    by <- list('v001')
    dhs <- dhs %>%  map(~filter(., b5 == 1  & fever == 1)) #b5 - child is alive
    df <- dhs %>% 
      map(~drop_na(.,vars[i]))
    df <- pmap(list(df,col,by), estim_prop)
    df <- plyr::ldply(df)
    df[, vars[i]]<- df[, vars[i]]*100
    write.csv(df, file =file.path(DataIn, paste0(vars[i], "_KR_DHS_10_15_18_21.csv")))
    
  }else{
  col <- list(vars[i])
  by <- list('v001')
  df <- dhs %>% 
    map(~drop_na(.,vars[i]))
  df <- pmap(list(df,col,by), estim_prop)
  df <- plyr::ldply(df)
  df[, vars[i]]<- df[, vars[i]]*100
  write.csv(df, file =file.path(DataIn, paste0(vars[i], "_KR_DHS_10_15_18_21.csv")))
  }
}


## ----------------------------------------------------
### estimation using the 2018 IR file 
## ----------------------------------------------------

dhs <- read.files(DataDir, "*NGIR.*\\.DTA", 'NGIR7AFL', read_dta) #reads in the IR files
dhs <- dhs %>%  map(~mutate(., wt=v005/1000000,strat=v022, id=v021)) %>%  map(~filter(., v025 == 1)) 

#create a variable for movement proxy and occupation  
dhs <- dhs %>% map(~mutate(., trips_woman = ifelse(v167 >=99, NA, v167), #Number of trips in last 12 months 
                                duration_travel_woman = ifelse(v168 >=9, NA, v168), #Away for more than one month in the last 12 months 
                                agri_worker_partner = ifelse(v705 %in% c(4, 5), 1, ifelse(v705 >=98, NA, 0)), # if husband/partner is agricultural worker or not
                                last_work_partner = ifelse(v704a >=8, NA, ifelse(v704a %in% c(1, 2), 1, 0)), # if husband/partner has worked in the last 7 days or in the last 12 months
                                agri_worker_woman = ifelse(v717 %in% c(4, 5), 1, ifelse(v717 >=98, NA, 0)), # if woman is agricultural worker or no
                                agri_worker_both = ifelse(agri_worker_partner ==1 & agri_worker_woman ==1, 1, 0), # if both husband and wife are agricultural workers
                      last_work_woman = ifelse(v731 %in% c(1, 2, 3), 1, ifelse(v731 >=9, NA, 0)),#if respondent has worked in the last past year, is currently working, has a job or is on leave in the last 7 days 
                      seasonal_work_woman = ifelse(v732 == 2, 1, ifelse(v732 ==9, NA, 0)))) #if respondent or woman is a seasonal worker or not 
                  


# knowledge questions recode

dhs[[1]]$s1108ai <- ifelse(dhs[[1]]$s1108ai == 1, 1, 0)
dhs[[1]]$s1108ba <- ifelse(dhs[[1]]$s1108ba == 1, 1, 0)
dhs[[1]]$s1108bc <- ifelse(dhs[[1]]$s1108bc  == 0, 1, 0)
dhs[[1]]$s1108bd <- ifelse(dhs[[1]]$s1108bd   == 1, 1, 0)
dhs[[1]]$s1108bf  <- ifelse(dhs[[1]]$s1108bf  == 0, 1, 0)

dhs[[1]]$know_vul <- ifelse(dhs[[1]]$s1108ai == 1 & dhs[[1]]$s1108ba == 1 & dhs[[1]]$s1108bc == 1 & dhs[[1]]$s1108bd == 1 & dhs[[1]]$s1108bf ==1, 1, 0)


#proportions 

vars <- c('know_vul', 'agri_worker_partner', 'last_work_partner', 'agri_worker_woman', 'agri_worker_both', 'last_work_woman', 'seasonal_work_woman' , 'duration_travel_woman')



for (i in 1:length(vars)) {
col <- list(vars[i])
by <- list('v001')
df <- dhs %>% 
  map(~drop_na(.,vars[i]))
df <- pmap(list(df,col,by), estim_prop)
df <- plyr::ldply(df)
df[, vars[i]]<- df[, vars[i]]*100
write.csv(df, file =file.path(DataIn, paste0(vars[i], "_IR_DHS_18.csv")))
}




#median

vars <- c('trips_woman')

for (i in 1:length(vars)) {
  col <- list(vars[i])
  by <- list('v001')
  df <- dhs %>% 
    map(~drop_na(.,vars[i]))
  df <- pmap(list(df,col,by), estim_median)
  df <- plyr::ldply(df)
  write.csv(df, file =file.path(DataIn, paste0(vars[i], "_IR_DHS_18.csv")))
  
}


## ----------------------------------------------------
### estimation using the 2018 MR file 
## ----------------------------------------------------

dhs <- read.files(DataDir, "*NGMR.*\\.DTA", 'NGMR7AFL', read_dta) #reads in the IR files
dhs <- dhs %>%  map(~mutate(., wt=mv005/1000000,strat=mv022, id=mv021)) %>%  map(~filter(., mv025 == 1)) 

look_for(dhs[[1]], 'mv716')

table(dhs[[1]]$mv716)

#create a variable for movement proxy and occupation  
dhs <- dhs %>% map(~mutate(., trips_man = ifelse(mv167 >=97, NA, mv167), #Number of times away from home in the last 12 months 
                           duration_travel_man = ifelse(mv168 >=9, NA, mv168), #Away for more than one month in the last 12 months 
                           agri_worker_man = ifelse(mv717 %in% c(4, 5), 1, ifelse(mv717 >=98, NA, 0)), # if male is agricultural worker or not
                           last_work_man = ifelse(mv731 >=9, NA, ifelse(mv731 %in% c(1, 2), 1, 0)), # if male has worked in the last 12 months
                           seasonal_work_man = ifelse(mv732 == 2, 1, ifelse(mv732 ==9, NA, 0)))) #if man is a seasonal worker or not 



#proportions 

vars <- c('agri_worker_man', 'last_work_man', 'seasonal_work_man' , 'duration_travel_man')



for (i in 1:length(vars)) {
  col <- list(vars[i])
  by <- list('mv001')
  df <- dhs %>% 
    map(~drop_na(.,vars[i]))
  df <- pmap(list(df,col,by), estim_prop)
  df <- plyr::ldply(df)
  df[, vars[i]]<- df[, vars[i]]*100
  write.csv(df, file =file.path(DataIn, paste0(vars[i], "_MR_DHS_18.csv")))
}


#median

vars <- c('trips_man')

for (i in 1:length(vars)) {
  col <- list(vars[i])
  by <- list('mv001')
  df <- dhs %>% 
    map(~drop_na(.,vars[i]))
  df <- pmap(list(df,col,by), estim_median)
  df <- plyr::ldply(df)
  write.csv(df, file =file.path(DataIn, paste0(vars[i], "_MR_DHS_18.csv")))
  
}



## ----------------------------------------------------
### Geospatial covariates extraction 
## ----------------------------------------------------


dhs <- read.files(DHSData, "*FL.shp$", 'NGGE61FL|NGGE71FL|NGGE7BFL|NGGE81FL', shapefile) #read in DHS clusters 
dhs <- map(dhs, st_as_sf) %>%  map(~filter(.x, URBAN_RURA == "U", LATNUM > 0.00000)) %>% map(sf:::as_Spatial) 



# buffers of interest

vars <- c(0, 1000, 2000, 3000, 4000)


#july month rainfall 


files <- list.files(path = file.path(DataDir, "Raster_files") , pattern = "*month_07.tif$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('rainfall', files))]
raster<-sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- c(paste0('month_07_', as.character(vars[i]), 'm'))
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('month_07')))
  df <- plyr::ldply(df) %>% dplyr::select(-c(ID))
  write.csv(df, file =file.path(GeoDir, paste0('month_07_', as.character(vars[i]), 
                                               'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}


#pop density extraction with just columbia data 

files <- list.files(path = file.path(DataDir, "Raster_files") , pattern = "*sec.tif$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('gpw_v4', files))]
raster<-sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- c(paste0('pop_den_', as.character(vars[i]), 'm'))
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('gpw_v4')))
  df <- plyr::ldply(df) %>% dplyr::select(-c(ID))
  write.csv(df, file =file.path(GeoDir, paste0('pop_density_', as.character(vars[i]), 
                                               'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}


#pop density extraction with general FB data: Rename raster files in acceding order for R to load them in same order the surveys.  

raster_3 <- raster(file.path(RastDir, "facebook_pop_density/nga_general_2020.tif"))
raster <- list(raster_3)





for (i in 1:length(vars)) {
  var_name <- paste0('pop_den_FB_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = starts_with('nga')))
  df <- plyr::ldply(df) %>% select(-c(ID))
  write.csv(df, file =file.path(GeoDir, paste0('pop_density_FB_', as.character(vars[i]), 
                                               'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}



#pop density extraction with U5 FB data 

raster <- raster(file.path(RastDir, "facebook_pop_density/nga_children_under_five_2020.tif"))
raster <- list(raster)

files <- list.files(path = file.path(RastDir , "facebook_pop_density") ,pattern = "*five_2020.tif$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('child', files))]
raster<-sapply(files, raster, simplify = F)



for (i in 1:length(vars)) {
  var_name <- paste0('pop_den_U5_FB_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = starts_with('nga')))
  df <- plyr::ldply(df) %>% select(-c(ID))
  write.csv(df, file =file.path(GeoDir, paste0('popd_U5_F_', as.character(vars[i]), 
                                               'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}


#distance to water bodies  

raster <- raster(file.path(RastDir, "distance_to_water_bodies/distance_to_water.tif"))
raster <- list(raster)

for (i in 1:length(vars)) {
  var_name <- paste0('dist_water_bodies_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = starts_with('distance')))
  df <- plyr::ldply(df) %>% dplyr::select(-c(ID))
  write.csv(df, file =file.path(GeoDir, paste0('dist_water_bod_', as.character(vars[i]), 
                                               'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}


#Housing 2000
#loading raster files

files <- list.files(path = file.path(RastDir , "housing") ,pattern = "*GA.tiff$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('2000', files))]
raster<-sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- paste0('housing_2000_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('Nature')))
  df <- plyr::ldply(df) %>% dplyr::select(-c(ID))
  write.csv(df, file = file.path(GeoDir, paste0('housing_2000_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}



#Housing 2015
#loading raster files

files <- list.files(path = file.path(RastDir , "housing") ,pattern = "*GA.tiff$",full.names = TRUE, recursive = TRUE)
files<- files[(grep('2015', files))]
raster<-sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- paste0('housing_2015_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('Nature')))
  df <- plyr::ldply(df) %>% dplyr::select(-c(ID))
  write.csv(df, file = file.path(GeoDir, paste0('housing_2015_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}




#elevation - World Bank  
#loading raster files

files <- list.files(path = file.path(RastDir, "elevation") ,pattern = "*1km.tif$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('MERIT', files))]
raster<-sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- paste0('elevation_', as.character(vars[[i]]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[[i]]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('MERIT')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID))
  write.csv(df, file = file.path(GeoDir, paste0('elevation_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}



#access to cities_
#loading raster files

files <- list.files(path = file.path(RastDir , "accessibility") ,pattern = "*GA.tiff$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('2015_accessibility', files))]
raster<-sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- paste0('access_to_cities_', as.character(2000), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, 2000), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('2015_accessibility')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID))
  write.csv(df, file = file.path(GeoDir, paste0('access_to_cit_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}

hist(df$access_to_cities_2000m)

#minutes to travel one metre 2015, friction decompressed


files <- list.files(path = file.path(RastDir , "accessibility") ,pattern = "*GA.tiff$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('Decompressed', files))]
raster<-sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- paste0('minutes_travel_metre_2015_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('Decompressed')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID))
  write.csv(df, file = file.path(GeoDir, paste0('friction_decomp_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}




#minutes to travel one metre 2019, motorized friction surface 
#loading raster files

files <- list.files(path = file.path(RastDir , "accessibility") ,pattern = "*GA.tiff$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('motorized_friction', files))]
raster<-sapply(files, raster, simplify = F)



for (i in 1:length(vars)) {
  var_name <- paste0('minutes_travel_metre_2019_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('motorized_friction')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID))
  write.csv(df, file = file.path(GeoDir, paste0('motorized_frict_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}



#motorized travel to healthcare 2019 

files <- list.files(path = file.path(RastDir , "accessibility") ,pattern = "*GA.tiff$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('motorized_travel_', files))]
raster<-sapply(files, raster, simplify = F)



for (i in 1:length(vars)) {
  var_name <- paste0('motorized_travel_healthcare_2019_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('motorized_travel_')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID))
  write.csv(df, file = file.path(GeoDir, paste0('motorized_trav_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}



#walking only friction, minutes walking one metre

#loading raster files

files <- list.files(path = file.path(RastDir , "accessibility") ,pattern = "*GA.tiff$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('walking_only_friction_', files))]
raster<-sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- paste0('minutes_walking_metre_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('walking_only_friction_')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID))
  write.csv(df, file = file.path(GeoDir, paste0('walk_only_fric_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}



#walking_only_travel_time_to_healthcare 

files <- list.files(path = file.path(RastDir , "accessibility") ,pattern = "*GA.tiff$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('only_travel', files))]
raster<-sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- paste0('minutes_walk_healthcare_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('only_travel')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID))
  write.csv(df, file = file.path(GeoDir, paste0('walking_trav_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}



#building density 

files <- list.files(path = file.path(RastDir , "NGA_buildings_v1_1") ,pattern = "*ity.tif$", full.names = TRUE, recursive = TRUE)
files<- files[(grep('buildings', files))]
raster<-sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- paste0('building_density_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('buildings')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID))
  write.csv(df, file = file.path(GeoDir, paste0('building_dens_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}


## Geospatial data monthly extraction 



#dhs clusters by year and month of sampling 


dhs_hh <- read.files(DataDir, "*NGPR.*\\.DTA", 'NGPR81FL|NGPR7BFL|NGPR71FL|NGPR61FL', read_dta)  #reads in the PR files

dhs_hh <- dhs_hh %>% map(~filter(., hv025 == 1)) %>%  map(~dplyr::select(., hv001, hv006, hv007)) %>%  map(~distinct(.,)) 

dhs_2010 <- left_join(st_as_sf(dhs[[1]]), dhs_hh[[1]], by = c("DHSCLUST"="hv001")) %>% 
  group_split(hv006) 
for(i in seq_along(dhs_2010)) {names(dhs_2010)[[i]] <- paste0(unique(dhs_2010[[i]]$hv006), '_', unique(dhs_2010[[i]]$hv007))}

dhs_2015 <- left_join(st_as_sf(dhs[[2]]), dhs_hh[[2]], by = c("DHSCLUST"="hv001")) %>% 
  group_split(hv006)
for(i in seq_along(dhs_2015)) {names(dhs_2015)[[i]] <- paste0(unique(dhs_2015[[i]]$hv006), '_', unique(dhs_2015[[i]]$hv007))}


dhs_2018 <- left_join(st_as_sf(dhs[[3]]), dhs_hh[[3]], by = c("DHSCLUST"="hv001")) %>% 
  group_split(hv006) 
for(i in seq_along(dhs_2018)) {names(dhs_2018)[[i]] <- paste0(unique(dhs_2018[[i]]$hv006), '_', unique(dhs_2018[[i]]$hv007))}


dhs_2021 <- left_join(st_as_sf(dhs[[4]]), dhs_hh[[4]], by = c("DHSCLUST"="hv001")) %>% 
  group_split(hv006) 
for(i in seq_along(dhs_2021)) {names(dhs_2021)[[i]] <- paste0(unique(dhs_2021[[i]]$hv006), '_', unique(dhs_2021[[i]]$hv007))}

dhs <- sapply(c(dhs_2010, dhs_2015, dhs_2018, dhs_2021), sf:::as_Spatial, simplify = F)

names(dhs)


#EVI rasters 
files <- list.files(path = file.path(RastDir , "EVI") ,pattern = "*.tif$", full.names = TRUE, recursive = FALSE)
raster <- sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- paste0('EVI_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun_month)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('EVI')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID)) 
  df <- df %>% arrange(month) %>%  group_by(dhs_year, hv001) %>%  slice(1) #use descending to get data for the second month for sensitivity analysis 
  write.csv(df, file = file.path(GeoDir, paste0('EVI_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}



#temperature era5

#loading temp era rasters in months when DHIS/MIS was conducted

files <- list.files(path = file.path(RastDir, "temperature_monthly") ,pattern = "*.tif$", full.names = TRUE, recursive = TRUE)
raster <- sapply(files, raster, simplify = F)


#temp extraction

for (i in 1:length(vars)) {
  var_name <- paste0('temp_survey_month_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun_month)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('temp')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID)) 
  df <- df %>% arrange(month) %>%  group_by(dhs_year, hv001) %>%  slice(1)
  write.csv(df, file = file.path(GeoDir, paste0('temp_surv_month_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}



#precipitation era

#loading era rasters in months when DHIS/MIS was conducted
files <- list.files(path = file.path(RastDir, "rainfall_monthly"), pattern = "*.tif$", full.names = TRUE, recursive = TRUE)
raster <- sapply(files, raster, simplify = F)


#precipitation extraction

for (i in 1:length(vars)) {
  var_name <- paste0('preci_monthly_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun_month)
  df <- df %>% map(~rename_with(., .fn=~paste0(var_name), .cols = contains('rainfall')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID))
  df <- df %>% arrange(month) %>%  group_by(dhs_year, hv001) %>%  slice(1)
  write.csv(df, file = file.path(GeoDir, paste0('precip_monthly_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}



#soil surface wetness

#loading soil surface wetness rasters in months when DHIS/MIS was conducted
files <- list.files(path = file.path(RastDir, "surface_soil_wetness") ,pattern = "*.tif$", full.names = TRUE, recursive = FALSE)
raster <- sapply(files, raster, simplify = F)


for (i in 1:length(vars)) {
  var_name <- paste0('soil_wetness_', as.character(vars[i]), 'm')
  df <- map2(dhs, raster, get_crs)
  df <- pmap(list(raster, df, vars[i]), extract_fun_month)
  df <- df %>%  map(~rename_with(., .fn=~paste0(var_name), .cols = contains('GIOVANNI')))
  df <- plyr::ldply(df)%>% dplyr::select(-c(ID))
  df <- df %>% arrange(month) %>%  group_by(dhs_year, hv001) %>%  slice(1)
  write.csv(df, file = file.path(GeoDir, paste0('soil_wetness_', as.character(vars[i]), 
                                                'm_buffer', "_DHS_10_15_18_21.csv")),row.names = FALSE)
}

