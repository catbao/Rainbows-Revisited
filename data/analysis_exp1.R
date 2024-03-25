library(lme4)
library(lmerTest)
library(merTools)
library(ggplot2)
library(ggthemes)
#library(ggrepel)
library(rcompanion)
library(dplyr)
library(RColorBrewer)
library(emmeans)


# utility to compute average
calcMeansBasic <-function(Data, formula)
{
  d<-groupwiseMean(formula,
                   data = Data,
                   conf = 0.95,
                   digits = 3,
                   R = 0,
                   boot = FALSE,
                   traditional = TRUE,
                   normal = FALSE,
                   basic = FALSE,
                   percentile = FALSE,
                   bca = FALSE
  )
  d$y <- d$Mean
  d
}

exp1 <- read.csv("data_exp1.csv")

# change a few colormap names to more print-friendly names
colormaps <- as.character(exp1$colormap)
colormaps[colormaps=='rainbowjet'] <- 'jet'
colormaps[colormaps=='rainbowcie'] <- 'RGB rainbow'

designs <- as.character(exp1$Design)
designs[designs=='singlehue'] <- 'single-hue'
designs[designs=='multihue'] <- 'multi-hue'

colormapLevels <-c('blues', 'purples', 'reds', 'viridis', 'redpurple', 'plasma', 'greyred', 'coolwarm', 'spectral', 'turbo', 'jet', 'RGB rainbow')
designLevels <- c('single-hue', 'multi-hue', 'divergent', 'rainbow')

exp1$colormap <- factor(colormaps, levels=colormapLevels)
exp1$Design <- factor(designs, levels=designLevels)

# re-center / re-scale distance so that minimum is at zero 
# (makes model intercepts easier to interpret)
exp1$requestedDistance <- exp1$requestedDistance * 100
exp1$distance <- exp1$distance * 100
MIN_D <- min(exp1$distance)
MAX_D <- max(exp1$distance)
exp1$distance <- exp1$distance - MIN_D


# 'correct' as a factor
exp1$correct <- factor(exp1$correct)



# 'success' as a numeric from 'correct' (useful for computing averages)
exp1$success <- as.numeric(as.character(exp1$correct))

# two alternative models to compare 
# (in order of increaseing complexity)
# =====================================

# take the log of LAB length and re-center
exp1$logLAB_Length <- log(exp1$LAB_Length)
MIN_LAB_LENGTH <- min(exp1$logLAB_Length)
exp1$logLAB_Length <- exp1$logLAB_Length - MIN_LAB_LENGTH

# recenter name length
MIN_NAME_LENGTH <- min(exp1$Name_Length)
exp1$Name_Length <- exp1$Name_Length - MIN_NAME_LENGTH

# models
m1 <- glmer(correct ~ distance+Design + (1|subjectid), family = binomial(link = "logit"), data=exp1)
m2 <- glmer(correct ~ distance+Name_Length + (1|subjectid), family = binomial(link = "logit"), data=exp1)
m3 <- glmer(correct ~ distance+logLAB_Length + (1|subjectid), family = binomial(link = "logit"), data=exp1)


# pick best model based on BIC
# =============================
bM12 <- BIC(m2) - BIC(m1)
bM13 <- BIC(m3) - BIC(m1)
bM23 <- BIC(m3) - BIC(m2)

# start with m1, a model based on current design criteria
finalModel <- m1

# test a model based on Name Length
if (bM12 <= 5) {
  print("selecting model 2: Name Length ")
  finalModel <- m2
}

# finally, test a model based on log LAB Distance
if (bM23 <= 5 & bM13 <= 5) {
  print("selecting model 3 -- log LAB Distance")
  finalModel <- m3
}

# pair-wise comparison for m1 (if we need it), which has discrete groups
emmeans(m1, list(pairwise~Design), adjust="Tukey")

# predict variables
# =================

# old-school
#exp1$m1 <- predict(m1, re.form=NA, type="response")
#exp1$m2 <- predict(m2, re.form=NA, type="response")

# w/ prediction interval
#p1 <- predictInterval(m1, which="fixed", type="probability")

#p2 <- predictInterval(m2, which="fixed", type="probability", fix.intercept.variance=TRUE, level=0.95)
#p2$colormap <- exp1$colormap
#p2$Design <- exp1$Design
#p2$distance <- exp1$distance
#p2$fit <- predict(m2, re.form=NA, type="response")
  
# compute accuracy rates (p answer=correct) for plotting
# ======================================================

# compute per-subject success rate
successColormap <- calcMeansBasic(exp1, success~colormap*subjectid)
successDesign <- calcMeansBasic(exp1, success~Design*subjectid)

# reorder designs
successDesign$Design <- factor(successDesign$Design, levels=designLevels)

# add color ramp metrics
nameLength <- calcMeansBasic(exp1, Name_Length~colormap*subjectid)
logLABLength <- calcMeansBasic(exp1, logLAB_Length~colormap*subjectid)

# combine success rates with color metrics in one frame
subjectRates <- data.frame(
  colormap=successColormap$colormap, 
  success=successColormap$Mean,
  NameLength=nameLength$Mean,
  logLABLength=logLABLength$Mean
)

# compute accuracy
nameLength <- calcMeansBasic(subjectRates, NameLength~colormap)
logLABLength <- calcMeansBasic(subjectRates, logLABLength~colormap)
accuracyColormap <- calcMeansBasic(subjectRates, success~colormap + NameLength + logLABLength)

# order colormaps by their design
accuracyColormap$colormap <- factor(accuracyColormap$colormap,
 levels=colormapLevels
)
accuracyDesign <- calcMeansBasic(successDesign, Mean~Design)
accuracyDesign$Design <- factor(accuracyDesign$Design, levels=designLevels)

accuracyNameLength <- accuracyColormap
accuracyNameLength$NameLength <- nameLength$Mean + MIN_NAME_LENGTH

accuracyLABLength <- accuracyColormap
accuracyLABLength$logLABLength <- logLABLength$Mean + MIN_LAB_LENGTH

# plotting
# ========

COLORSET <- c(
  '#c7c7c7', '#969696', '#696969',
  '#cff084', '#95d93d','#4dab00',
  '#99c1f7', '#6399e0', '#2b72cf',
  '#FFA686', '#FF6D3A', '#EC430A',
  '#ff7aa2', '#e33d6f', '#b80037',
  '#deba85', '#faba6b', '#ff9900',
  '#e099db', '#ed66e4', '#db18ce'

  #'#66E395','#22EC6D','#00BC46',
  #'#99e0a5', '#55e668', '#04c224',

  )

DESIGN_COLORS <- c(
  '#B5B5B5',
  '#82CF44',
  '#6399e0',
  '#FA6A3A'
  #'#e33d6f'
)

# plotting functions for model prediction + accuracy
# ==================================================
plotModelDesign <- function(sqrtScale=FALSE)
{
  designStyle=designLevels
  
  # generate distance data
  begin <- -0.02
  jitterWidth <- 100*0.01/5
  if (sqrtScale) {
    begin <- 0
    jitterWidth <- 100*0.01/3.7
  }
  distances <- seq(from=0-0.02, to=MAX_D-MIN_D, by=(MAX_D-MIN_D+0.02)/100)
  dLen <- length(distances)
  modelData <- data.frame(
    distance=rep(distances, length(designStyle)), 
    Design=rep(designStyle, dLen)
  )

  # generate model predictions
  modelData$prediction <- predict(m1, newdata=modelData, re.form=NA, type="response")
  modelData$Design <- factor(modelData$Design, levels=designLevels)
  modelData$distance <- modelData$distance + MIN_D
  
  # average based on req distance
  actualData <- exp1
  actualData$reqDistance <- factor(as.character(actualData$requestedDistance))
  avgData <- calcMeansBasic(actualData, success~reqDistance*colormap + Design)
  avgData$reqDistance <- as.numeric(as.character(avgData$reqDistance))# - MIN_D
  avgData$Design <- factor(avgData$Design, levels=designLevels)
  
  
  p <- ggplot(data=modelData, aes(x=distance, y=prediction, color=Design))
  p <- p + geom_point(data=avgData, aes(x=reqDistance, y=Mean), size=1.5, alpha=0.5, position=position_jitter(height=0, width=jitterWidth))
  p <- p + geom_line()
  p <- p + geom_line(y=0.25, color='black', linetype = 5, size=0.3)
  p <- p + annotate("text", MIN_D+3, y = 0.235, label = "chance")
  p <- p + scale_fill_manual(values=DESIGN_COLORS) + scale_color_manual(values=DESIGN_COLORS)
  p <- p + theme_minimal()+ ylab('Accuracy') + xlab('Inferential distance') 
  if (sqrtScale) {
    p <- p + scale_x_continuous(trans='sqrt')
  }
  p <- p + theme(text = element_text(size=10))
  p
}

plotModelName <- function(sqrtScale=FALSE)
{
  # color name >mean vs <mean
  cutOff <- median(exp1$Name_Length)
  exp1$Name_Level <- rep(NA, length(exp1$Name_Length))
  exp1$Name_Level[ exp1$Name_Length >= cutOff ] <- 'high'
  exp1$Name_Level[ exp1$Name_Length < cutOff ] <- 'low'
  
  high <- max(exp1$Name_Length)
  low <- min(exp1$Name_Length)

  # generate distance data
  begin <- -0.02
  jitterWidth <- 100*0.01/5
  if (sqrtScale) {
    begin <- 0
    jitterWidth <- 100*0.01/3.7
  }
  distances <- seq(from=0-0.02, to=MAX_D-MIN_D, by=(MAX_D-MIN_D+.02)/300)
  
  # re-center around the actual mean
  exp1$realName_Length <- exp1$Name_Length + MIN_NAME_LENGTH
  
  # prepare an ensemble of colormaps
  colormaps <- calcMeansBasic(exp1, Name_Length~colormap + Name_Level)
  colormaps$Name_Length <- colormaps$Mean
  colorRows <- colormaps %>% slice(rep(1:n(), each = length(distances)))
  
  
  highV <- rep(high, length(distances))
  lowV <- rep(low, length(distances))
  highL <- rep('high', length(distances))
  lowL <- rep('low', length(distances))

  modelData <- data.frame(
    distance = rep(distances, length(colormaps$Name_Length)),
    Name_Length = colorRows$Name_Length,
    Name_Level = colorRows$Name_Level,
    colormap = colorRows$colormap
  )
  
  # generate model predictions
  modelData$prediction <- predict(m2, newdata=modelData, re.form=NA, type="response")
  modelData$distance <- modelData$distance + MIN_D
  modelData$Name_Length <- modelData$Name_Length + MIN_NAME_LENGTH
  
  # average based on req distance
  actualData <- exp1
  actualData$reqDistance <- factor(as.character(actualData$requestedDistance))
  avgData <- calcMeansBasic(actualData, success~reqDistance*colormap + realName_Length)
  avgData$reqDistance <- as.numeric(as.character(avgData$reqDistance))# - MIN_D
  avgData$Name_Length <- avgData$realName_Length

  colors <- c('#E83B00', '#511D6E')
  p <- ggplot(data=modelData, aes(x=distance, y=prediction, color=Name_Length))
  p <- p + geom_line(aes(group=colormap), alpha=0.7)
  p <- p + geom_line(aes(group=NA), y=0.25, color='black', linetype = 5, size=0.3)
  p <- p + geom_point(data=avgData, aes(color=Name_Length, x=reqDistance, y=Mean), stroke=0, size=2, alpha=0.5, position=position_jitter(width=jitterWidth, height=0))
  
    p <- p + annotate("text", MIN_D+3, y = 0.235, label = "chance")
  #p <- p + scale_fill_manual(values=colors) + scale_color_manual(values=colors)
  p <- p + scale_color_distiller(palette = "RdBu")
  p <- p + theme_minimal() + ylab('Accuracy') + xlab('Inferential distance')
  if (sqrtScale) {
    p <- p + scale_x_continuous(trans='sqrt')
  }
  p <- p + theme(text = element_text(size=10))
  p
}

plotModelLAB <- function(sqrtScale=FALSE)
{
  # color name >mean vs <mean
  cutOff <- median(exp1$logLAB_Length)

  # generate distance data
  begin <- -0.02
  jitterWidth <- 100*0.01/5
  if (sqrtScale) {
    begin <- 0
    jitterWidth <- 100*0.01/3.7
  }
  
  distances <- seq(from=begin, to=MAX_D-MIN_D, by=(MAX_D-MIN_D+.02)/300)
  
  # re-center around the actual mean
  exp1$reallogLAB_Length <- exp1$logLAB_Length + MIN_LAB_LENGTH
    
  # prepare an ensemble of colormaps
  colormaps <- calcMeansBasic(exp1, reallogLAB_Length~colormap)
  colormaps$logLAB_Length <- colormaps$Mean
  colorRows <- colormaps %>% slice(rep(1:n(), each = length(distances)))

  modelData <- data.frame(
    distance = rep(distances, length(colormaps$logLAB_Length)),
    logLAB_Length = colorRows$logLAB_Length - MIN_LAB_LENGTH,
    colormap = colorRows$colormap
  )
  
  # generate model predictions
  modelData$prediction <- predict(m3, newdata=modelData, re.form=NA, type="response")
  modelData$distance <- modelData$distance + MIN_D
  modelData$logLAB_Length <- modelData$logLAB_Length + MIN_LAB_LENGTH
  
  # average based on req distance
  actualData <- exp1
  actualData$reqDistance <- factor(as.character(actualData$requestedDistance))
  avgData <- calcMeansBasic(actualData, success~reqDistance*colormap + reallogLAB_Length)
  avgData$logLAB_Length <- avgData$reallogLAB_Length
  avgData$reqDistance <- as.numeric(as.character(avgData$reqDistance))# - MIN_D
  
  colors <- c('#E83B00', '#511D6E')
  p <- ggplot(data=modelData, aes(x=distance, y=prediction, color=logLAB_Length))
  p <- p + geom_line(aes(group=colormap), alpha=0.7)
  p <- p + geom_line(y=0.25, color='black', linetype = 5, size=0.3)
  p <- p + geom_point(data=avgData, aes(x=reqDistance, y=Mean), stroke=0, size=2, alpha=0.5, position=position_jitter(width=jitterWidth, height=0))
  p <- p + annotate("text", MIN_D+3, y = 0.235, label = "chance")
  #p <- p + scale_fill_manual(values=colors) + scale_color_manual(values=colors)
  p <- p + scale_color_distiller(palette = "RdBu")
  p <- p + theme_minimal() + ylab('Accuracy') + xlab('Inferential distance') 
  if (sqrtScale) {
    p <- p + scale_x_continuous(trans='sqrt')
  }
  p <- p + theme(text = element_text(size=10))
  p
}



# plotting functions for descriptive Accuracy results
# ===================================================
plotAccuracyByColormap <- function()
{
  p <- ggplot(data=accuracyColormap, aes(x=colormap, fill=colormap, y=Mean))
  p <- p + geom_bar(stat="identity")
  p <- p + geom_errorbar(aes(ymin=Trad.lower, ymax=Trad.upper, width=0.17), size=0.2)
  p <- p + theme_minimal() + coord_cartesian(ylim=c(0.5,0.75))
  p <- p + theme(axis.text.x = element_text(angle = 45, hjust = 1, size=10))
  p <- p + scale_fill_manual(values=COLORSET) + scale_color_manual(values=COLORSET)
  p <- p + ylab('Accuracy')
  p
}

plotAccuracyByDesign <- function()
{
  p <- ggplot(data=accuracyDesign, aes(x=Design, fill=Design, y=Mean))
  p <- p + geom_bar(stat="identity", width=0.85)
  p <- p + geom_errorbar(aes(ymin=Trad.lower, ymax=Trad.upper, width=0.17), size=0.25)
  p <- p + coord_cartesian(ylim=c(0.5,0.75))
  p <- p + scale_fill_manual(values=DESIGN_COLORS) + scale_color_manual(values=DESIGN_COLORS)
  p <- p + theme_minimal() + ylab('Accuracy')
  p <- p + theme(axis.text.x = element_text(angle = 0, hjust = 0.5, size=11.5))
  p
}

plotAccuracyByDesignDots <- function()
{
  # highlight plasma as somewhat of an outlier within this group
  plasma <- subset(accuracyColormap, colormap=='plasma')
  plasma$Design <- factor(rep('multihue', length(plasma$colormap)), levels=designLevels)
  
  p <- ggplot(data=accuracyDesign, aes(x=Design, color=Design, y=Mean))
  p <- p + geom_point(data=successDesign, size=2, alpha=0.25, aes(x=Design, fill=Design, y=Mean), position=position_jitter(width = 0.2, height=0.03))
  p <- p + geom_point(data=plasma, size=2, alpha=0.45, aes(y=Mean, x=Design), fill='black', color='#ff8503', position=position_jitter(width = 0.3, height=0.03))
  
  p <- p + geom_point(shape=18, size=3, color='black', fill='black')
  p <- p + geom_errorbar(aes(ymin=Trad.lower, ymax=Trad.upper, width=0), size=0.3, color='black')
  p <- p + scale_fill_manual(values=DESIGN_COLORS) + scale_color_manual(values=DESIGN_COLORS)
  p <- p + theme_bw() + ylab('Accuracy')
  p
}

accuracyNameLengthBar <- function()
{
  d <- accuracyColormap
  d$colormap <- factor(d$colormap, levels=c('purples', 'reds', 'blues', 'redpurple', 'coolwarm', 'greyred', 'viridis', 'plasma', 'spectral','rainbowcie', 'rainbowjet', 'turbo' ))
  p <- ggplot(data=d, aes(x=colormap, fill=NameLength, y=Mean))
  p <- p + geom_bar(stat="identity")
  p <- p + geom_errorbar(aes(ymin=Trad.lower, ymax=Trad.upper, width=0.3), size=0.3)
  p <- p + coord_cartesian(ylim=c(0.5,0.75))
  p <- p + scale_fill_distiller(palette = "RdBu")
  p <- p + theme_bw()
  p
}


plotAccuracyByName <- function()
{
  set.seed(302)
  p <- ggplot(data=accuracyNameLength, aes(y=Mean, color=colormap, x=NameLength))
  p <- p + geom_point(size=5)
  #p <- p + geom_text_repel(aes(label = colormap), color='black', size = 3.2, label.padding = unit(0.4, "lines"))
  p <- p + scale_fill_manual(values=COLORSET) + scale_color_manual(values=COLORSET)
  p <- p + theme_bw() + ylab('Accuracy') + xlab('Color Name Variation')
  p <- p + theme(text = element_text(size=12))
  p
}

plotAccuracyByLABLength <- function()
{
  p <- ggplot(data=accuracyLABLength, aes(y=Mean, color=colormap, x=logLABLength))
  p <- p + geom_point(size=5)
  p <- p + scale_fill_manual(values=COLORSET) + scale_color_manual(values=COLORSET)
  p <- p + theme_bw() + ylab('Accuracy') + xlab('log(LAB Length)')
  p <- p + theme(text = element_text(size=12))
  p
}

plotLABvName <- function()
{
  data <- accuracyNameLength
  data$logLABLength <- accuracyLABLength$logLABLength

  p <- ggplot(data=data, aes(y=NameLength, color=colormap, x=logLABLength))
  p <- p + geom_point(size=6)
  p <- p + scale_fill_manual(values=COLORSET) + scale_color_manual(values=COLORSET)
  p <- p + theme_bw() + ylab('NameLength')
  p
}
