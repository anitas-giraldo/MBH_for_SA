### Create inclusion probabilities ####

## for multibeam and lidar #######
#install.packages("MBHdesign")
library( MBHdesign)
library( parallel)
library( class)
library( fields)
#install.packages("pdist")
library( pdist)
library( raster)
library( rgdal)
library( sp)

# clear environment ----
rm(list = ls())

# Set working directory ####
w.dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
s.dir <- paste(w.dir, "spatial_data", sep ='/')
d.dir <- paste(w.dir, "InNOutMP", sep ='/')


#read in data -----

# read in the inclusion probs

inclProbs <- raster(paste(d.dir, "inclProbs_InNOutMP-d1.tif", sep='/'))
plot(inclProbs)
inclProbs <- setValues( inclProbs, values( inclProbs) / sum( values( inclProbs), na.rm=TRUE))
plot(inclProbs)
rootInclProbs <- inclProbs
rootInclProbs <- setValues( rootInclProbs, sqrt( values( rootInclProbs)))
zones <- readRDS( "SWZones_forInNOutMP.RDS") # this one in different folder
Deans <- readRDS( "DeansPints_forinNOutMP.RDS")
swrast <- readRDS("SWRasters_forInNOutMP.RDS")
#if( class( BRUVS) != "SpatialPointsDataFrame")
Deans <- SpatialPointsDataFrame( coords=Deans[,c("Longitude","Latitude")], data=Deans, proj4string = CRS( proj4string( zones[[1]])))
straw.nums <- readRDS( "StrawmanNumbers_Zones.RDS")
names(straw.nums) <- c("InsideMP", "OutsideMP")


################################
####  choose reference sites
####  This is a one-step sample and hence
####  uses orignal inclProbs
################################

# working out density dependent probs of inclusion
tmpD <- spTransform( Deans, CRS="+init=epsg:3577")
tmpDist <- as.matrix( dist( coordinates( tmpD)))
tmpDist1 <- apply( tmpDist, 1, function(x) sum( x<1000))
Deans@data$sampleProbs <- 1 / sqrt( tmpDist1)  #to alter the importance a little bit
Deans@data$sampleProbs <- Deans@data$sampleProbs / sum( Deans@data$sampleProbs, na.rm=TRUE)
Deans@data$inclProbs <- raster::extract(inclProbs, Deans)
Deans@data$sampleProbs <- Deans@data$sampleProbs * Deans@data$inclProbs #TPI inclusion probs are zero in most places


numRef <- rep( NA, 2)
names( numRef) <- c("InsideMP","OutsideMP")

for( zz in c( "InsideMP","OutsideMP")){
  myZone <- zones[[zz]]
  #if( zz == "MUS")
    #myZone = zones$AMP - zones$IUCN2
  tmpDrop <- as.vector( as.matrix( over( Deans, myZone)))
  length1 <- length(tmpDrop)
  wna <- which(is.na(tmpDrop))
  lengthna <- length(wna)
  length2 <- length1-lengthna
  numRef[zz] <- min( floor( straw.nums[zz]/2), length2)
  #numRef[zz] <- min( floor( straw.nums[zz]), length2)
  #numRef[zz] <- min( floor( straw.nums[zz]/2), sum( length2, na.rm=TRUE))
  prob <- Deans@data[!is.na( tmpDrop),"sampleProbs"]
  prob <- na.exclude(prob)
  prob <- as.vector(prob)
  length3 <- length(prob)
  
  Deans@data[!is.na( tmpDrop), "f"][sample.int(length3, numRef[zz], prob, replace=FALSE)] <- TRUE
  
  #Deans@data[!is.na( tmpDrop), "f"][sample.int(length2, numRef[zz], prob=Deans@data[!is.na( tmpDrop),"sampleProbs"], replace=FALSE)] <- TRUE
  #Deans@data[!is.na( tmpDrop), "f"][sample.int( sum( tmpDrop, na.rm=TRUE), numRef[zz], replace=FALSE)] <- TRUE
}

Deans@data$sampleProbs

# load legacy sites ----
#legacySites <- readOGR(dsn="C:/Users/00093391/Dropbox/UWA/Research Associate/MBHpackage/Ningaloo19_Data/legacySites_2019-12-23.shp")

# Deans Points are trated as legacy sites --
Deans2 <- Deans
table( Deans@data$f) / table( Deans2@data$f)

plot( inclProbs)
plot( Deans, add=TRUE)
points( coordinates( Deans)[Deans@data$f,], col='red')

legacySites <- Deans@data[Deans@data$f,]
legacySites <- SpatialPointsDataFrame( coords=legacySites[,c("Longitude","Latitude")], data=legacySites, proj4string=CRS(proj4string(inclProbs)))
# 35 legacy sites


############################
####  Spatial sample of new sites
####  from altered incl. probs.
############################

### Here use quasiSamp to get random points ####
## these points will be the center of buffer for transects ###

####  Set the seed for reproducability
#set.seed( 777)
#### HAVE NOT BEEN ABLE TO MAKE THIS FUNCTION WORK ----
newSites <- list(InsideMP=NULL,OutsideMP=NULL)
for( zz in c("InsideMP", "OutsideMP")){
  print( zz)
  #the number of samples to take (specified minus the legacy number)
  #numby <- floor( (straw.nums[zz]))
  #numby <- floor( (straw.nums[zz] - numRef[zz])/2)
  numby <- floor( (straw.nums[zz] - numRef[zz]))
  #set up spatial domain
  myZone <- zones[[zz]]
  #if( zz == "AMP"){
  # myZone = zones$AMP - zones$IUCN2
  #set.seed( 747)
  #}
  #tmpIP <- mask( rootInclProbs_agg_100m, myZone)
  tmpIP <- mask( inclProbs, myZone)
  tmpIP <- crop( tmpIP, myZone)
  #take the sample of clusters based on root incl probs
  newSites[[zz]] <- quasiSamp( n=numby, potential.sites=coordinates( tmpIP), inclusion.probs=values(tmpIP), nSampsToConsider=5000)
  
  #plotting (maybe remove at a later date?)
  tmpIPFull <- mask( inclProbs, myZone)
  tmpIPFull <- crop( tmpIPFull, myZone)
  plot( tmpIPFull)
  plot( legacySites, add=TRUE, pch=1, col='red')
  points( newSites[[zz]][,c("x","y")], pch=20, col='black')
}
newSites <- do.call( "rbind", newSites)
newSites <- SpatialPointsDataFrame( coords=newSites[,c("x","y")], data=newSites, proj4string=CRS(proj4string(inclProbs)))
#some of the spatial balance is not great...  Presumably because the balance of the reference sites is also not great...


###############################
####  Choose new points within clusters
####  Here I need to choose transects not points
##############################

getlocal <- function(ii){
  point <- newSites[ii,c("x","y")]
  r2 <- rasterize( point, inclProbs, field=1)
  pbuf <- buffer( r2, width=600) ## units are in metres
  buf <- mask( inclProbs, pbuf)
  buffer <- trim(buf, pad=0)
  return( buffer)
}


sampWithOver <- 10


fullSample <- list()
fullZones <- list()



## Get bruvs accoring to clusters ---
for( ii in 1:nrow(newSites)){
  tmp <- getlocal(ii)
  fullZones[[ii]] <- rownames( newSites@data)[ii]
  tmpm <- raster::as.matrix(tmp)
  tmpm <- t(tmpm)
  tmpdf <- as.data.frame (
    cbind (coordinates (tmp), as.numeric (tmpm)))
  colnames(tmpdf) <- c("x", "y", "inclProbs_design1")
  tmpdf <- tmpdf[ order(tmpdf$y, tmpdf$x),]  # order ascending first by northing and then by easting
  fullSample[[ii]] <- quasiSamp( n=sampWithOver, potential.sites=coordinates(tmp), inclusion.probs=values(tmp), nSampsToConsider=10000)
  #fullSample[[ii]] <- transectSamp( n=sampWithOver, potential.sites = tmpdf[,c(1,2)], 
                                    #potential.sites= tmpdf[,c("x","y")],
                                    #inclusion.probs= incprobdf[,3],
                                    #inclusion.probs= tmpdf[,3],
                                    #control=gb.control
                                    #constrainedSet=gb.constraints.bool
  
  plot( tmp)
  points( fullSample[[ii]]$points[,c("x","y")], pch=20, col='red')
  #plot( legacySites, add=TRUE, pch=4, col='blue')
}


fullSample <- do.call( "rbind", fullSample[1:38])
bruvs <- SpatialPointsDataFrame( coords=fullSample[,c("x","y")], data=fullSample, proj4string=CRS(proj4string(inclProbs)))

plot(inclProbs)
points(bruvs, pch =20)



## Get bruvs accoring to Dean's points ---

# fixing that some NAs in Incl Probs
plot(inclProbs)
points(Deans)

Deans3 <- as.data.frame(Deans)
Deans3 <- Deans3[!is.na(Deans3$inclProbs),]
str(Deans3) # 31 Obs
coordinates(Deans3) <- ~Longitude+Latitude

plot(inclProbs)
points(Deans)
points(Deans3, pch=20)




getlocal <- function(ii){
  point <- Deans3[ii,c("Longitude.1","Latitude.1")]
  r2 <- rasterize( point, inclProbs, field=1)
  pbuf <- buffer( r2, width=600) ## units are in metres
  buf <- mask( inclProbs, pbuf)
  buffer <- trim(buf, pad=0)
  return( buffer)
}


sampWithOver <- 10


fullSampled <- list()
fullZonesd <- list()


for( ii in 1:nrow(Deans3)){
  tmp <- getlocal(ii)
  fullZones[[ii]] <- rownames( Deans3@data)[ii]
  tmpm <- raster::as.matrix(tmp)
  tmpm <- t(tmpm)
  tmpdf <- as.data.frame (
    cbind (coordinates (tmp), as.numeric (tmpm)))
  colnames(tmpdf) <- c("x", "y", "inclProbs_design1")
  tmpdf <- tmpdf[ order(tmpdf$y, tmpdf$x),]  # order ascending first by northing and then by easting
  fullSampled[[ii]] <- quasiSamp( n=sampWithOver, potential.sites=coordinates(tmp), inclusion.probs=values(tmp), nSampsToConsider=10000)
  #fullSample[[ii]] <- transectSamp( n=sampWithOver, potential.sites = tmpdf[,c(1,2)], 
  #potential.sites= tmpdf[,c("x","y")],
  #inclusion.probs= incprobdf[,3],
  #inclusion.probs= tmpdf[,3],
  #control=gb.control
  #constrainedSet=gb.constraints.bool
  
  plot( tmp)
  points( fullSampled[[ii]]$points[,c("x","y")], pch=20, col='red')
  #plot( legacySites, add=TRUE, pch=4, col='blue')
}


fullSampled <- do.call( "rbind", fullSampled[1:31])
bruvsd <- SpatialPointsDataFrame( coords=fullSampled[,c("x","y")], data=fullSampled, proj4string=CRS(proj4string(inclProbs)))



plot(inclProbs)
points(bruvs, pch =20)
points(bruvsd, pch = 20, col="red")
points(newSites, pch=20, col="blue")
points(Deans3, pch=20, col = "green")
points(Deans, pch=20, col = "orange")


# join clusters : new sites and Deans ----
nsdf <- as.data.frame(newSites)
ddf <- as.data.frame(Deans3)
head(nsdf)
names(nsdf)
nsdf <- nsdf[,c(1:4)]
head(nsdf)
nsdf$class <- "MBH"
#
head(ddf)
names(ddf) 
ddf <- ddf[,c(4,3,23,20)]
head(ddf)
names(ddf) <- c("x",  "y", "inclusion.probabilities", "ID" )
ddf$class <- "Legacy"
# join
clusters <- rbind(nsdf, ddf)
str(clusters) # 69

# make sp --
coordinates(clusters) <- ~x+y


# join BRUVs: bruvs and bruvsd ----
bdf <- as.data.frame(bruvs)
bddf <- as.data.frame(bruvsd)
head(bdf)
bdf <- bdf[,c(1:4)]
bdf$class <- "MBH"
head(bddf)
bddf <- bddf[,c(1:4)]
bddf$class <- "Legacy"
#join
bruvsall <- rbind(bdf, bddf)

# make sp --
coordinates(bruvsall) <- ~x+y


# To save ----

pdf(paste(w.dir, "InNOutMP", "InNOutMP-Clusters-d1.pdf", sep='/'), height=7, width=8)
plot(inclProbs, main = "Inclusion probabilities - Clusters - Design1")
points(bruvs, pch=20, cex = 0.4, col='black')
points(bruvsd, pch=20, cex = 0.7, col='blue')
#plot(swnp, add=T)
dev.off()




### plot nicely #####
library(dichromat)
library(RColorBrewer)
pal <- colorRampPalette(c("red","blue"))
pdf(paste(w.dir, "InNOutMP", "InNOutMP-Bathy-BRUVs-Clusters-d1.pdf", sep='/'), height=7, width=8)
plot(swrast$bathy, main ="Bathymetry - Clusters - D1", col = rev(brewer.pal(20, "RdYlBu")))
#plot(tpi, main ="Clustered Stereo-BRUVs - SW", col = pal1)
points(bruvs, pch=21, cex = 0.5, bg='white')
points(bruvsd, pch=21, cex = 0.5, bg='green')
plot(zones$SWMP, add=T)
#plot(swnp, add=T)
#points(wp, add = T, pch=20, cex = 0.7, col='green')
dev.off()









####  Write the shape files

d.dir <- paste(w.dir, "Fish-HWY", sep='/')

writeOGR(fullSample3, dsn=d.dir, layer="FHWY-BRUVS-d5", driver="ESRI Shapefile", overwrite_layer=TRUE)
#writeOGR(fullSample3, dsn=d.dir, layer=paste( "Bruvs4.8", Sys.Date(), sep="_"), driver="ESRI Shapefile", overwrite_layer=TRUE)
writeOGR(clustersp, dsn=d.dir, layer="FHWY-24clusters-d5", driver="ESRI Shapefile", overwrite_layer=TRUE)
