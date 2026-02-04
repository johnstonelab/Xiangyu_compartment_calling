#make_possum_bedgraph_bigwig.R

library(readr)
library(dplyr)
library(stringr)
library(data.table)

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 7) {
  stop(
    "Usage:\n",
    "Rscript make_possum_bedgraph_bigwig.R ",
    "<chrom_sizes> <chr_res> <possum_outdir> <hic_base> ",
    "<bedGraphToBigWig> <out_bedgraph> <out_bigwig>\n"
  )
}

# -------------------------
# Assign arguments
# -------------------------
chrom_sizes_path  <- args[1]
chr_res_path      <- args[2]
possum_outdir        <- args[3]
hic_base          <- args[4]
bedGraphToBigWig  <- args[5]
out_bedgraph_path <- args[6]
out_bigwig_path   <- args[7]

print(chrom_sizes_path)
print(chr_res_path)
print(possum_outdir)
print(hic_base)


# -------------------------
# Sanity checks
# -------------------------
stopifnot(file.exists(chrom_sizes_path))
stopifnot(file.exists(chr_res_path))
stopifnot(dir.exists(possum_outdir))
stopifnot(file.exists(bedGraphToBigWig))

# -------------------------
# Read inputs
# -------------------------

chrom_sizes <- read.csv(chrom_sizes_path, sep = "\t", header = FALSE)
colnames(chrom_sizes) <- c("chr","length")

chrom_res <- read.csv(chr_res_path, sep = "\t", header = FALSE)
colnames(chrom_res) <- c("chr","res")


# Match the previous behavior
chrom_sizes <- chrom_sizes %>%
  filter(!(chr %in% c("chrM", "chrY")))

# Join resolution
chrom_sizes <- chrom_sizes %>%
  left_join(chrom_res, by = "chr")

message("Check chrom_sizes")
print(chrom_sizes$length)
print(chrom_sizes$res)

if (any(is.na(chrom_sizes$res))) {
  missing_chr <- chrom_sizes %>%
    filter(is.na(res)) %>%
    pull(chr)
  stop("Missing resolution for: ", paste(missing_chr, collapse = ", "))
}

message("[R] Building bedGraph from POSSUM outputs...")

chr_list <- list()

# -------------------------
# Loop chromosomes
# -------------------------
for (i in 1:nrow(chrom_sizes)) {

  chr_name <- chrom_sizes$chr[i]
  chr_len  <- chrom_sizes$length[i]
  res      <- chrom_sizes$res[i]

  message(paste0(
    "[R] chr=", chr_name,
    " | length=", chr_len,
    " | res=", res
  ))

  possum_file <- file.path(
    possum_outdir,
    paste0(hic_base, "_", res, "_", chr_name, "_output")
  )

  message("[R] reading: ", possum_file)

  if (!file.exists(possum_file)) {
    stop("Cannot find POSSUM output file: ", possum_file)
  }
  
  chr_possum <- read.csv(possum_file, header = FALSE)
  colnames(chr_possum) <- "Value"

  # Replace NA with 0 (your logic)
  chr_possum$Value[is.na(chr_possum$Value)] <- 0

  # Generate bins
  bin_starts <- seq(1, chr_len, by = res)
  bin_ends   <- pmin(bin_starts + res - 1, chr_len)

  row_match <- length(bin_starts) == nrow(chr_possum)
  message(paste("Row match for", chr_name, ":", row_match))

  if (!row_match) {
    stop(
      "Row mismatch for ", chr_name,
      ": bins=", length(bin_starts),
      " vs values=", nrow(chr_possum)
    )
  }

  chr_df <- data.frame(
    chr   = chr_name,
    start = bin_starts,
    end   = bin_ends,
    value = chr_possum$Value
  )
  
  #format the chr_bin (scientific=FALSE)
  chr_df$start <- format(chr_df$start, scientific = FALSE)
  chr_df$end <- format(chr_df$end, scientific = FALSE)
  chr_df$value <- format(chr_df$value, scientific = FALSE)

  chr_list[[chr_name]] <- chr_df
}


# -------------------------
# Combine & write bedGraph
# -------------------------
combined_df <- do.call(rbind, chr_list)

write.table(combined_df, file = out_bedgraph_path, row.names = FALSE, col.names = FALSE, sep = "\t", quote = FALSE)

# -------------------------
# Sort bedGraph
# -------------------------
message("[R] Sorting bedGraph for bigWig...")

sorted_bedgraph_path <- sub(
  "\\.bedgraph$",
  ".sorted.bedgraph",
  out_bedgraph_path
)


cmd_sort <- paste0(
  "LC_COLLATE=C sort -k1,1 -k2,2n -k3,3n ",
  shQuote(out_bedgraph_path),
  " > ",
  shQuote(sorted_bedgraph_path)
)
system(cmd_sort)

# -------------------------
# Convert to bigWig
# -------------------------
message("[R] Converting to bigWig...")

cmd_bw <- paste(
  shQuote(bedGraphToBigWig),
  shQuote(sorted_bedgraph_path),
  shQuote(chrom_sizes_path),
  shQuote(out_bigwig_path)
)
system(cmd_bw)

message("[R] Done.")
message("  bedGraph: ", out_bedgraph_path)
message("  bigWig  : ", out_bigwig_path)

