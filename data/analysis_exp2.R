library(lme4)
library(lmerTest)
library(merTools)
library(ggplot2)
library(rcompanion)
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

exp2 <- read.csv("data_exp2.csv")
exp2$Name_Length <- exp2$Name_Length - min(exp2$Name_Length)

# add design family
# =================
exp2$colormap <- as.character(exp2$colormap)
exp2$colormap[exp2$colormap=='rainbowcie'] <- 'RGB rainbow'
exp2$colormap <- factor(exp2$colormap)

exp2$Design <- rep(NA, length(exp2$colormap))
exp2$Design[ exp2$colormap=='RGB rainbow' ] <- 'rainbow'
exp2$Design[ exp2$colormap=='coolwarm' ] <- 'divergent'
exp2$Design[ exp2$colormap=='viridis'] <- 'multi-hue'
exp2$Design[ exp2$colormap=='blues'] <- 'single-hue'
exp2$Design <- factor(exp2$Design, levels=c('single-hue', 'multi-hue', 'divergent', 'rainbow'))

# reorder colormaps
exp2$colormap <- factor(exp2$colormap, levels=c('blues', 'viridis', 'coolwarm', 'RGB rainbow'))

# subset positive, negative stimuli
# note: selection==99 means subject answered null
# ==================================
positives <- subset(exp2, hasDecoy==1)
negatives <- subset(exp2, hasDecoy==0)

positives$truePositive <- rep(0, length(positives$selection))
negatives$trueNegative <- rep(0, length(negatives$selection))

positives$truePositive[ positives$selection!=99 ] <- 1
negatives$trueNegative[ negatives$selection==99 ] <- 1

# overall means
truePositiveRate <- mean(positives$truePositive)
trueNegativeRate <- mean(negatives$trueNegative)

positives$truePositive <- factor(as.character(positives$truePositive), levels=c("0", "1"))
negatives$trueNegative <- factor(as.character(negatives$trueNegative), levels=c("0", "1"))

# modeling
# =========

# no distance parameter (since there is only a 'primary' model and no 'decoys')
# use trial number as a random effect to account for repeated measures
m1Specificity <- glmer( trueNegative~Design + (1|subjectid) + (1|trial), family = binomial(link = "logit"), data=negatives )
m2Specificity <- glmer( trueNegative~Name_Length + (1|subjectid) + (1|trial), family = binomial(link = "logit"), data=negatives )

# pairwise comparison for m1
emmeans(m1Specificity, list(pairwise~Design), adjust="Tukey")

m1Sensitivity <- glmer( truePositive~Design + distance + (1|subjectid), family = binomial(link = "logit"), data=positives )
m2Sensitivity <- glmer( truePositive~Name_Length + distance + (1|subjectid), family = binomial(link = "logit"), data=positives )

# pairwise comparison for m1
emmeans(m1Sensitivity, list(pairwise~Design), adjust="Tukey")

# split false/true X negatives/positives
# so that we can compute per-subject rates
# =========================================
falseNegatives <- exp2$selection==99 & exp2$hasDecoy==1
exp2$fn[!falseNegatives] <- 0
exp2$fn[falseNegatives] <- 1
exp2$fn <- factor(exp2$fn)
exp2$fnNum <- as.numeric(as.character(exp2$fn))

falsePositives <- exp2$selection!=99 & exp2$hasDecoy==0
exp2$fp[!falsePositives] <- 0
exp2$fp[falsePositives] <- 1
exp2$fp <- factor(exp2$fp)
exp2$fpNum <- as.numeric(as.character(exp2$fp))

# true negatives / positives
trueNegatives <- exp2$selection==99 & exp2$hasDecoy==0
exp2$tn[!trueNegatives] <- 0
exp2$tn[trueNegatives] <- 1
exp2$tn <- factor(exp2$tn)
exp2$tnNum <- as.numeric(as.character(exp2$tn))

truePositives <- exp2$selection!=99 & exp2$hasDecoy==1
exp2$tp[!truePositives] <- 0
exp2$tp[truePositives] <- 1
exp2$tp <- factor(exp2$tp)
exp2$tpNum <- as.numeric(as.character(exp2$tp))


# selection bias? ideally, the probabiltiy of selecting negative vs. positive
# should be the same given they are equally probable in the stimulus set
selectP <- length(subset(exp2, selection!=99)$colormap)/length(exp2$colormap)
selectN <- length(subset(exp2, selection==99)$colormap)/length(exp2$colormap)


# first, compute per-subject rates
# ================================

# false positives
fpSubject <- calcMeansBasic(subset(exp2, hasDecoy==0), fpNum~colormap*subjectid)

# false negatives
fnSubject <- calcMeansBasic(subset(exp2, hasDecoy==1), fnNum~colormap*subjectid)

subjectRate <- data.frame(
  subjectid=fpSubject$subjectid,
  colormap=fpSubject$colormap,
  fp=fpSubject$Mean,
  fn=fnSubject$Mean,
  n=fpSubject$n
)

# summary rates
# =============
fpRate <- calcMeansBasic(subjectRate, fp~colormap)
fnRate <- calcMeansBasic(subjectRate, fn~colormap)

rates <- data.frame(
  colormap=fpRate$colormap,
  n=fpRate$n,

  # false positive rate
  fp=fpRate$Mean,
  fpLower=fpRate$Trad.lower,
  fpUpper=fpRate$Trad.upper,
  
  # false negative rate
  fn=fnRate$Mean,
  fnLower=fnRate$Trad.lower,
  fnUpper=fnRate$Trad.upper

)

rates$sensitivity <- 1-rates$fn
rates$sensitivityLower <- 1-rates$fnUpper
rates$sensitivityUpper <- 1-rates$fnLower

rates$specificity <- 1-rates$fp
rates$specificityLower <- 1-rates$fpUpper
rates$specificityUpper <- 1-rates$fpLower

# ====================
# generate figures
# ====================

DESIGN_COLORS <- c(
  '#B5B5B5',
  '#82CF44',
  '#6399e0',
  '#FA6A3A'
  #'#e33d6f'
)

plotFalsePositives <- function()
{
  p <- ggplot(data=rates, aes(x=colormap, fill=colormap, y=fp)) + geom_bar(stat="identity")
  p <- p + geom_bar(stat="identity")
  p <- p + geom_errorbar(aes(ymin=fpLower, ymax=fpUpper), width=.3) + theme_bw()
  p <- p + scale_fill_manual(values=DESIGN_COLORS) + scale_color_manual(values=DESIGN_COLORS)
  p
}

plotSpecificityDots <- function()
{
  p <- ggplot(data=subjectRate, aes(x=colormap, color=colormap, y=1-fp, width=1.2)) 
  p <- p + geom_point(alpha=0.3, size=3, position=position_jitter(width = 0.2, height=0.03))
  p <- p + geom_point(data=rates, aes(y=1-fp), size=3, shape=18, color="black", position=position_dodge(.8))
  p <- p + geom_errorbar(data=rates, aes(ymin=1-fpLower, ymax=1-fpUpper), width=0, color="black", position=position_dodge(.8))
  p <- p + theme_minimal() + ylab('Specificity') + theme(axis.text.x = element_text(angle = 35, hjust = 1, size=10))
  p <- p + scale_fill_manual(values=DESIGN_COLORS) + scale_color_manual(values=DESIGN_COLORS)
  p
}

plotSpecificityDotsWModel <- function()
{
  modelData <- calcMeansBasic(exp2, Name_Length ~ colormap)
  modelData$Name_Length <- modelData$Mean
  p <- predict(m2Specificity, type="response", re.form=NA, newdata=modelData)
  modelData$prediction <- p
  
  p <- ggplot(data=subjectRate, aes(x=colormap, color=colormap, y=1-fp, width=1.2)) 
  p <- p + geom_point(alpha=0.3, size=3, position=position_jitter(width = 0.2, height=0.03))
  p <- p + geom_point(data=rates, aes(y=1-fp), size=3, shape=18, color="black", position=position_dodge(.8))
  p <- p + geom_line(data=modelData, aes(y=prediction, group=1), color="blue")
  p <- p + geom_errorbar(data=rates, aes(ymin=1-fpLower, ymax=1-fpUpper), width=0, color="black", position=position_dodge(.8))
  p <- p + theme_minimal() + ylab('Specificity') + theme(axis.text.x = element_text(angle = 35, hjust = 1, size=10))
  p <- p + scale_fill_manual(values=DESIGN_COLORS) + scale_color_manual(values=DESIGN_COLORS)
  p
}


plotSpecificity <- function()
{
  p <- ggplot(data=rates, aes(x=colormap, fill=colormap, y=specificity)) 
  p <- p + geom_bar(stat="identity")
  p <- p + geom_errorbar(aes(ymin=specificityLower, ymax=specificityUpper), width=.3) + theme_minimal() + ylab('False positive rate (1-specificity)')
  p <- p + scale_fill_manual(values=DESIGN_COLORS) + scale_color_manual(values=DESIGN_COLORS)
  
  p
}

plotFalseNegatives <- function()
{
  p <- ggplot(data=rates, aes(x=colormap, fill=colormap, y=fn)) + geom_bar(stat="identity")
  p <- p + geom_bar(stat="identity")
  p <- p + geom_errorbar(aes(ymin=fnLower, ymax=fnUpper), width=.3) + theme_minimal() + ylab('False negative rate (1-sensitivity)')
  p <- p + scale_fill_manual(values=DESIGN_COLORS) + scale_color_manual(values=DESIGN_COLORS)
  p
}

plotSensitivityDots <- function()
{
  p <- ggplot(data=subjectRate, aes(x=colormap, color=colormap, y=1-fn, width=1.2)) 
  p <- p + geom_point(alpha=0.3, size=3, position=position_jitter(width = 0.2, height=0.03))
  p <- p + geom_point(data=rates, aes(y=1-fn), size=3, shape=18, color="black", position=position_dodge(.8))
  p <- p + geom_errorbar(data=rates, aes(ymin=1-fnLower, ymax=1-fnUpper), width=0, color="black", position=position_dodge(.8))
  p <- p + scale_fill_manual(values=DESIGN_COLORS) + scale_color_manual(values=DESIGN_COLORS)
  
  #p <- p + geom_bar(stat="identity")
  #p <- p + geom_errorbar(aes(ymin=fpLower, ymax=fpUpper), width=.3) + theme_bw()
  p + theme_minimal() + ylab('Sensitivity') + theme(axis.text.x = element_text(angle = 45, hjust = 1, size=10))
}

plotSensitivityDotsWModel <- function()
{
  d <- mean(positives$distance)
  modelData <- calcMeansBasic(exp2, Name_Length ~ colormap)
  modelData$Name_Length <- modelData$Mean
  modelData$distance <- rep(d, length(modelData$Name_Length))
  p <- predict(m2Sensitivity, type="response", re.form=NA, newdata=modelData)
  modelData$prediction <- p
  
  p <- ggplot(data=subjectRate, aes(x=colormap, color=colormap, y=1-fn, width=1.2)) 
  p <- p + geom_point(alpha=0.3, size=3, position=position_jitter(width = 0.2, height=0.03))
  p <- p + geom_point(data=rates, aes(y=1-fn), size=3, shape=18, color="black", position=position_dodge(.8))
  p <- p + geom_line(data=modelData, aes(y=prediction, group=1), color="blue")
  p <- p + geom_errorbar(data=rates, aes(ymin=1-fnLower, ymax=1-fnUpper), width=0, color="black", position=position_dodge(.8))
  p <- p + scale_fill_manual(values=DESIGN_COLORS) + scale_color_manual(values=DESIGN_COLORS)
  
  #p <- p + geom_bar(stat="identity")
  #p <- p + geom_errorbar(aes(ymin=fpLower, ymax=fpUpper), width=.3) + theme_bw()
  p + theme_minimal() + ylab('Sensitivity') + theme(axis.text.x = element_text(angle = 45, hjust = 1, size=10))
}


plotSensitivity <- function()
{
  p <- ggplot(data=rates, aes(x=colormap, fill=colormap, y=sensitivity)) 
  p <- p + geom_bar(stat="identity")
  p <- p + geom_errorbar(aes(ymin=sensitivityLower, ymax=sensitivityUpper), width=.3) + theme_bw()
  p <- p + scale_fill_manual(values=DESIGN_COLORS) + scale_color_manual(values=DESIGN_COLORS)
  p
}
