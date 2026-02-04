#make_possum_bedgraph_bigwig.R

library(readr)
library(dplyr)
library(stringr)
library(data.table)

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop(
    "Usage:\n",
    "Rscript adjust_possum_signs.R ",
    "<signs> <initial_bg> <out_bg> "
  )
}

# -------------------------
# Assign arguments
# -------------------------
signs_path      <- args[1]
initial_bedgraph_path        <- args[2]
out_bedgraph_path          <- args[3]


print(signs_path)
print(initial_bedgraph_path)
print(out_bedgraph_path)


# -------------------------
# Sanity checks
# -------------------------
stopifnot(file.exists(signs_path))
stopifnot(file.exists(initial_bedgraph_path))


# -------------------------
# Read inputs
# -------------------------

signs <- read.csv(signs_path, sep = "\t", header = FALSE)
colnames(signs) <- c("chr","sign")

signs <- signs %>%
  filter(!(chr %in% c("chrM", "chrY")))

# Map sign to multiplier
signs <- signs %>%
  mutate(mult = case_when(
    sign %in% c("+", "plus", "PLUS", "1")     ~  1,
    sign %in% c("-", "minus", "MINUS", "-1")  ~ -1,
    TRUE ~ NA_real_
  ))

if (any(is.na(signs$mult))) {
  bad <- signs %>% filter(is.na(mult)) %>% pull(chr)
  stop("Invalid sign entries for: ", paste(bad, collapse = ", "),
       " (allowed: + or -)")
}

# -------------------------
# Read bedGraph
# -------------------------
bg <- read.csv(initial_bedgraph_path, sep = "\t", header = FALSE)

colnames(bg) <- c("chr", "start", "end", "value")

# Join multipliers
bg2 <- bg %>%
  left_join(signs %>% select(chr, mult), by = "chr")

# Check that every chr in bedGraph has a sign
if (any(is.na(bg2$mult))) {
  missing <- bg2 %>% filter(is.na(mult)) %>% distinct(chr) %>% pull(chr)
  stop("No sign provided for chr: ", paste(missing, collapse = ", "))
}

# Apply sign
bg2$value <- bg2$value * bg2$mult
bg2$mult <- NULL

# -------------------------
# Write adjusted bedGraph
# -------------------------
write.table(bg2[,c("chr","start","end","value")], file = out_bedgraph_path, row.names = FALSE, col.names = FALSE, sep = "\t", quote = FALSE)

message("[R] Wrote adjusted bedGraph: ", out_bedgraph_path)







