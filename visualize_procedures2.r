# Visualize CMS data from the Medicare-Provider-Utilization-Payment public use file, year 2012.
# Janos A. Perge, 7/31/2016
# 
# To assess the risk associated with a medical procedure, one needs to better  
# understand the physician who carries out the procedure. This visualization exercise  
# explores the relationships between medical procedures and their cost across physician specialities.
# 
# Before running this script, first run procedures_by_provider2.r to open, rearrange, combine and save CMS data  
# needed for this visualization exercise. 

# load R-packages
rm(list=ls())

packageList = c("data.table","stringr",'plyr', 'ggplot2')

is_installed <- function(mypkg) is.element(mypkg, installed.packages()[,1])

load_or_install<-function(package_names)
{
  for(package_name in package_names)
  {
    if(!is_installed(package_name))
    {
      install.packages(package_name,repos="http://lib.stat.cmu.edu/R/CRAN")
    }
    options(java.parameters = "-Xmx8g")
    library(package_name,character.only=TRUE,quietly=TRUE,verbose=FALSE)
  }
}

load_or_install(packageList)

##************************************************************
## Load and inspect data
##************************************************************
data_filename = 'provider_vs_procedures_2_2012.RData'
start = Sys.time()
load(data_filename)
Sys.time()-start

physician_info = data.table(physician_info, key='provider_type')

# Combine different procedures per provider for showing overall workload:
npi_vs_tot_count = npi_vs_ccs[, .(tot_cnt = sum(proc_cnt, na.rm=T), med_efficacy=median(med_proc_per_patient, na.rm=T), 
                                  tot_pay=sum(est_pay_amt, na.rm=T), tot_bene=sum(bene_cnt, na.rm=T)), by=npi]
npi_vs_tot_count = npi_vs_tot_count[,avg_pay := tot_pay/tot_cnt]

# top provider specialities and head-counts:
counts = data.table(table(physician_info$provider_type))
#range(counts$Freq)
counts = setorder(counts, -N, na.last=TRUE)
top10 = counts[seq(1,10),]
midTierSpecialities = counts[seq(21,32),]
top10

##************************************************************
## Diversity of procedure costs across specialities (plot1)
##************************************************************
setkey(physician_info,npi)
sub_npi_ccs = npi_vs_tot_count[physician_info] 

median.proc.pay.spec = sub_npi_ccs[, .(med.pay = median(avg_pay, na.rm=T), med.proc = median(tot_cnt, na.rm=T)), by=provider_type]
median.proc.pay.spec = setorder(median.proc.pay.spec, med.pay, na.last=TRUE)
median.proc.pay.spec = median.proc.pay.spec[seq(60,79),]
providers = median.proc.pay.spec$provider_type

g <- ggplot(median.proc.pay.spec, aes(x=provider_type, y=med.pay)) 
g + geom_bar(position="dodge",stat="identity") +coord_flip() +
  ggtitle("Cost of procedures")+
  labs(y='Median Procedure Cost ($)')+
  scale_fill_grey()+
  theme_bw()+
  scale_x_discrete(limits=median.proc.pay.spec$provider_type)+
  theme(
    axis.title.y=element_blank(),                            #removes y-axis label
    text=element_text(family="serif"),                       #changes font on entire graph
    plot.title=element_text(face="bold",hjust=c(0,0)) #changes font face and location for graph title
  )

##************************************************************
## Diversity of procedure codes across specialities (plot13)
##************************************************************
#Select for physician types:
phys_sel = c('Dermatology', 'Physical Therapist', 'Cardiology', 'Orthopedic Surgery')
cc = physician_info[provider_type %in% phys_sel] #provider info (and list of npis) within the top popular provider types. 
setkey(cc,npi)
sub_npi_ccs = npi_vs_ccs[cc] # join on selected npi numbers (of popular types), pulling the npi specific info into procedure count

g <- ggplot(sub_npi_ccs, aes(ccs_code, proc_cnt)) + geom_point(color = 'blue', size = 1, alpha=1/4) 
g <- g + facet_wrap(~provider_type, nrow=1) + coord_cartesian(ylim = c(0,200000))
g + labs(x='Procedure type (CCS)', y='# of procedures',title = 'Distribution of procedures is characteristic to the speciality')

##************************************************************
## Diversity of procedure counts and associated costs within a speciality (plot2)
##************************************************************
#select multiple specialities
phys_sel = c('Dermatology', 'Physical Therapist', 'Cardiology', 'Optometry')
cc = physician_info[provider_type %in% phys_sel] #provider info (and list of NPIs) within the top popular provider types. 
setkey(cc,nppes_entity_code)  #remove organizations
cc = cc[nppes_entity_code=='I']
setkey(cc,npi) # join on selected npi numbers (of popular types), pulling the npi specific info into procedure count
sub_npi_ccs = npi_vs_tot_count[cc] 

g <- ggplot(sub_npi_ccs, aes(tot_cnt, tot_pay)) + geom_point(color = 'blue', size = 1, alpha=1/4) 
g = g + facet_wrap(~provider_type, ncol=2)+geom_smooth(method = 'lm', se=FALSE) 
g = g + coord_cartesian(xlim = c(0,20000),ylim = c(0,2000000))
g + labs(x='Total # procedures in 2012', y='Total claims ($/year)', title= 'Diversity of procedure costs within a speciality')

# Cost of procedures varies significantly within specialities. 
# Each dot corresponds to a physician. Certain disciplines vary more, while others 
# (e.g. physical therapist) the cost follows closely the procedure counts.
#
# Some specialities could be divided into subspecialities (e.g. Dermatology, Optometry). 
# These subspecialities have different work loads and pay scales. 
# Other examples of this are: 'Pathology', 'Neurology', 'Radiation Oncology'-three groups, 'Clinical Laboratory'.
# Let's examine why this happens by looking at the most commonly performed procedures within optometry

##************************************************************
## What are the subgroups within optometry? (plot3)
##************************************************************
cc = physician_info[provider_type == 'Optometry']
setkey(cc,nppes_entity_code)  #remove organizations
cc = cc[nppes_entity_code=='I']
setkey(cc,npi) # join on selected npi numbers, pulling the npi specific info into procedure count
sub_npi_ccs = npi_vs_tot_count[cc] 

g <- ggplot(sub_npi_ccs, aes(tot_cnt, tot_pay)) + geom_point(color = 'blue', size = 1, alpha=1/4) 
g = g + coord_cartesian(xlim = c(0,18000),ylim = c(0,600000))
g + labs(x='Total # procedures in 2012', y='Total claims ($/year)', title= 'Optometrists fall into at least two sub-groups')

##************************************************************
## Distribution of procedure codes within optometry (plot4)
##************************************************************
cc = physician_info[provider_type == 'Optometry']
setkey(cc,nppes_entity_code)  #remove organizations
cc = cc[nppes_entity_code=='I']
setkey(cc,npi)
sub_npi_ccs = npi_vs_ccs[cc] # join on selected npi numbers, pulling the npi specific info into procedure count

g <- ggplot(sub_npi_ccs, aes(ccs_code, proc_cnt)) + geom_point(color = 'blue', size = 1, alpha=1/4) 
g <- g + facet_wrap(~provider_type, nrow=1) + coord_cartesian(ylim = c(0,20000))
g + labs(x='Procedure Code (CCS)', y='# of procedures', title= 'Distribution of procedure codes within Optometry')

# Tally of procedure codes within opthalmologists:
common_procedures = data.table(table(sub_npi_ccs$ccs_code))
common_procedures$V1 = as.numeric(common_procedures$V1)
setkey(common_procedures,V1)

codenames = conversion_table[,.(css_desc,ccs_code)] #this altered the original table as well
setkey(codenames,ccs_code)
codenames = unique(codenames)

common_procedures = common_procedures[codenames, nomatch=0] #inner join
common_procedures

# The three common procedures are: 
# -CCS15:Lens and cataract procedures, 
# -CCS220: Ophthalmologic and otologic diagnosis and treatment, and 
# -CCS227: Other diagnostic procedures (interview, evaluation, consultation).   
# Let's examine the relationship across these codes within the group of opthalmologists.

#Rearrange three most common procedure code counts into three columns
setkey(sub_npi_ccs, ccs_code)
common.procs = sub_npi_ccs[ccs_code %in% c(15,220,227)]

longdat = common.procs[,.(npi,ccs_code, proc_cnt)] 
setkey(longdat, "npi","ccs_code")
head(longdat)

widedat = dcast(longdat, npi ~ ccs_code) #convert data.table from long to wide format
widedat[is.na(widedat)] = 1 #Assign a value of '1' to missing data instead of '0' to avoid dividing by zero
setnames(widedat,"15","code15")
setnames(widedat,"220","code220")
setnames(widedat,"227","code227")

widedat = widedat[,ratio := code15/code220]
widedat = widedat[,lensProv := ratio<0.5]

setkey(widedat,lensProv)
cataractProvs = widedat[lensProv==TRUE]
head(cataractProvs)

##************************************************************
## Relationship of the three most common codes within opthalmology (plot5)
##************************************************************
par(mfrow = c(1,3))
plot(widedat$code15, widedat$code220, main ='Code 15 vs 220')
plot(widedat$code15, widedat$code227, main='Code 15 vs 227')
plot(widedat$code220, widedat$code227, main='Code 220 vs 227')
mtext('Relationship of the three most common codes within opthalmology', outer=TRUE)

# Code15 procedure counts when plotted against code220 or 227 counts separate providers into two clusters:
# i) those who perform code15 rarely but do code 220 or 227 frequently (the sharp cluster on the left), and
# ii) those who perform code15 frequently, but code220 or 227 less (the more diffuse cluster in the left and center plot). 
# Code 220 against 227 does not separate providers. So the frequency of code15 relative to the other codes 
# (either 220 or 227) characterizes the provider's subspecialty. (Each symbol in these plots is a provider)

##************************************************************
## Distribution of Code15/220 in opthalmology (plot6)
##************************************************************
# Calculate the ratio of code15/code220 procedures for each provider (above), and
# plot the distribution of this ratio for all optometrist:
qplot(ratio, data = widedat, geom = 'density') + xlim(0, 3) + 
  labs(x='Ratio (code15/220)',y='Frequency', title='Distribution of ratio values in optometry')+
  xlim(0, 1.5)+ theme_bw()

##************************************************************
## Lens/cataract procedure differentiates optometrists (plot7)
##************************************************************

#Ratio of procedures (code15/code220) shows two peaks in the distribution. Let's use this ratio to separate 
#providers into two groups: those which perform code15 frequently and those who do not. 

#Use these two groups to color code the earlier plot:
cc = physician_info[provider_type == 'Optometry']
setkey(cc,nppes_entity_code)  #remove organizations
cc = cc[nppes_entity_code=='I']
setkey(cc,npi) # join on selected npi numbers, pulling the npi specific info into procedure count
sub_npi_ccs = npi_vs_tot_count[cc]
sub_npi_ccs = sub_npi_ccs[,cataract_procedures := npi %in% cataractProvs$npi]

ggplot(sub_npi_ccs, aes(tot_cnt, tot_pay, color=cataract_procedures))+ 
  geom_point(size = 1, alpha=1/4)+
  coord_cartesian(xlim = c(0,18000),ylim = c(0,600000))+
  scale_colour_discrete(name  ="Performs lens/cataract procedure", labels=c("Rarely", "Frequently"))+
  labs(x='Total # procedures in 2012', 
       y='Total claims ($/year)', 
       title= 'Lens/cataract procedure differentiates optometrists')+
  theme_bw()

## Cost of procedures across the three code types:
setkey(npi_vs_ccs, ccs_code)
codeSel = c(15, 220, 227)
cc = npi_vs_ccs[ccs_code %in% codeSel] 
sub_cc = cc[,.(cost_per_procedure = median(est_pay_amt/proc_cnt)), by=ccs_code] 
sub_cc

# As a confirmation: Lens/cataract procedures (code15) are roughly 10 times more expensive   
# as diagnosis and treatment (code220) or diagnostic procedures (code270)

##************************************************************
## Gender inequality
##************************************************************
sub_npi_ccs = npi_vs_tot_count[physician_info] 

# Male providers outnumber female ones by nearly 2-fold:
table(physician_info$nppes_provider_gender)

# Male providers on average also bring in more revenue on medicare claims. 
# While this was initially surprising, notice that males also perform 
# twice as many procedures. The cost per service is actually very comparable across gender:

gend_pay = sub_npi_ccs[,.(tot_revenue=median(tot_pay, na.rm=T), 
                          proc_cnt = median(tot_cnt, na.rm=T), 
                          cost_per_service = median(avg_pay, 
                          na.rm=T)), by= nppes_provider_gender]

ggplot(sub_npi_ccs, aes(x=tot_cnt, fill=nppes_provider_gender)) +
  geom_histogram(binwidth=400, position="dodge")+
  coord_cartesian(xlim = c(0,15000),ylim = c(0,30000))+
  labs(x='# procedures/provider', y='# providers', title= 'Male providers outperform female ones')+
  theme_bw()+
  scale_fill_manual(values=c("gray", "red", "blue"),labels=c("Unknown", "Female", "Male"))+
  guides(fill=guide_legend(title=NULL))+
  theme(legend.position=c(.7, .8))

#Procedure counts and costs across specialities:

providers = c("Clinical Laboratory", "Pathology", "Pulmonary Disease", "Podiatry", "Rheumatology", "Radiation Oncology",
              "Ophthalmology", "Allergy/Immunology", "Nephrology", "Interventional Pain Management",
              "Urology", "Cardiac Electrophysiology", "Dermatology", "Hematology/Oncology", "Cardiology",
              "Diagnostic Radiology", "Ambulance Service Supplier", "Portable X-ray", 
              "Radiation Therapy")

median.proc.pay.spec = sub_npi_ccs[, .(med.pay = median(avg_pay, na.rm=T), 
                                       med.proc = median(tot_cnt, na.rm=T)), 
                                   by=.(provider_type,nppes_provider_gender) ]

setkey(median.proc.pay.spec,nppes_provider_gender)
median.proc.pay.spec = median.proc.pay.spec[nppes_provider_gender  %in% c("M","F")]
setkey(median.proc.pay.spec,provider_type)
median.proc.pay.spec = median.proc.pay.spec[provider_type  %in% providers]

##************************************************************
## Gender specific revenue (plot8)
##************************************************************
ggplot(data=median.proc.pay.spec, aes(x=provider_type,y=med.proc,fill=factor(nppes_provider_gender))) +
  geom_bar(position="dodge",stat="identity") + 
  coord_flip() +
  labs(y='Procedure Count')+
  theme_bw()+
  scale_x_discrete(limits=providers)+
  theme(
    legend.title=element_blank(),  
    legend.position=c(.65,.5),
    axis.title.y=element_blank(), #removes y-axis label
    text=element_text(family="serif",size=10), #changes font on entire graph
    plot.title=element_text(face="bold",hjust=c(0,0)) #changes font face and location for graph title
  ) +
  scale_fill_discrete(labels = c("Female", "Male")) 

##************************************************************
## Cost of procedures is similar across gender (plot9)
##************************************************************
ggplot(data=median.proc.pay.spec, aes(x=provider_type,y=med.pay,fill=factor(nppes_provider_gender))) +
  geom_bar(position="dodge",stat="identity") + 
  coord_flip() +
  labs(y='Cost per procedure ($)')+
  theme_bw()+
  scale_x_discrete(limits=providers)+
  theme(
    legend.title=element_blank(),  
    legend.position=c(.85,.8),
    axis.title.y=element_blank(), #removes y-axis label
    text=element_text(family="serif",size=10), #changes font on entire graph
    plot.title=element_text(face="bold",hjust=c(0,0)) #changes font face and location for graph title
  ) +
  scale_fill_discrete(labels = c("Female", "Male")) 

# Male providers charge more for the total services because they also perform more procedures 

##************************************************************
## Provider's productivity over years of expertise (plot10)
##************************************************************
# Quantify the provider's experience level as the number of years s/he spent practicing. 
# This can be estimated from the provider's graduation year (assuming that most providers 
# start working after graduation). 
# To learn how graduation years were obtained see comments in 'procedures_by_provider2.r'
                                                                                                                                                graduation). To learn how graduation years were obtained see comments in 'procedures_by_provider2.r'#Plot only data points with known graduation years (~75% of all providers)
phys.info = physician_info[!graduation.year %in% NA]

#Select for physician types:
phys_sel = c('Dermatology', 'Physical Therapist', 'Cardiology', 'Orthopedic Surgery')
cc = phys.info[provider_type %in% phys_sel] #provider info (and list of npis) within the top popular provider types. 
setkey(cc,npi)
sub_npi_ccs = npi_vs_tot_count[cc] # inner join on selected npi numbers, pulling the npi specific info into procedure count
sub_npi_ccs = sub_npi_ccs[,expyrs := 2012-graduation.year]

median_freq = sub_npi_ccs[, .(medi = median(tot_cnt, na.rm=T), 
                              med_bene=median(as.numeric(tot_bene), na.rm=T), 
                              med_effic=median(med_efficacy, na.rm=T), na.rm=T), 
                              by=.(expyrs, provider_type)]

g <- ggplot(median_freq, aes(expyrs, med_bene)) + geom_point() 
g = g + facet_wrap(~provider_type, nrow=2) #+geom_smooth(method='lm', se=FALSE) 
g = g + coord_cartesian(xlim = c(0,70),ylim = c(0,3000))
g + labs(x='Work experience (years after graduation)', y='Median # of patients/year', title= "Experience makes more efficient")

##************************************************************
## Procedure/patient (ie. treatment efficacy) remains similar over career (plot11)
##************************************************************
g <- ggplot(median_freq, aes(expyrs, med_effic)) + geom_point() 
g = g + facet_wrap(~provider_type, nrow=2) #+geom_smooth(method='lm', se=FALSE) 
g = g + coord_cartesian(xlim = c(0,60),ylim = c(0,7.5))
g + labs(x='Work experience (years after graduation)', y='Treatment Efficacy (# procedures/patient)', title= "Negligible change in Procedure/patient")

# Productivity (but not necessarily quality of care) depends on experience.
# A provider treats more patients (and performs more procedures/unit time) 
# after years of experience. However, the treatment efficacy is stable over 
# the course of the physician's career (i.e. roughly the same # of procedure/patient). 
# So increased output might be explained if appointment durations shorten over the years. 
# Let's see below if this is really the case. 

# (Note that treatment efficacy is very close to one, so it might be difficult to see improvement in 
# quality of care just by looking at this measure.)

##************************************************************
#Plot office visit times across physician age groups (years of experience) (plot12)
##************************************************************
phys.info = physician_info[!graduation.year %in% NA]
phys.info = phys.info[!office_mins %in% NA]

#Select for physician types:
phys_sel = c('Dermatology', 'Physical Therapist', 'Cardiology', 'Orthopedic Surgery')
cc = phys.info[provider_type %in% phys_sel] #provider info (and list of npis) within the top popular provider types. 
setkey(cc,npi)
sub_npi_ccs = npi_vs_tot_count[cc] # inner join on selected npi numbers, pulling the npi specific info into procedure count
sub_npi_ccs = sub_npi_ccs[,expyrs := 2012-graduation.year]

median_freq = sub_npi_ccs[, .(medi_office_min = median(office_mins, na.rm=T)), 
                          by=.(expyrs, provider_type)]

g <- ggplot(median_freq, aes(expyrs, medi_office_min)) + geom_point() 
g = g + facet_wrap(~provider_type, nrow=2) #+geom_smooth(method='lm', se=FALSE) 
#g = g + coord_cartesian(xlim = c(0,60),ylim = c(0,7.5))
g + labs(x='Work Experience (years after graduation)', y='Medium Length of Office Visit (min))',
         title= "Office visits shorten with the provider's experience")
# Office visit durations do shorten by the providers years of experience. 
# This is in a range of 10-20% decrease over multiple decades, which does not explain 
# the four-fold increase in productivity of experienced providers. Note that office visits 
# are only a fraction of the range of procedures providers perform, thus from this result 
# we cannot say how much time a provider actually spends with a beneficiary.
