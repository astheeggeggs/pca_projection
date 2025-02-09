#!/usr/bin/env Rscript

library(data.table)
library(hexbin)
library(optparse)
library(patchwork)
library(R.utils)
library(tidyverse)
options(datatable.fread.datatable = FALSE)

plt_theme <-
  theme_classic(base_size = 8) +
  theme(
    panel.background = element_rect(fill = "transparent", color = NA),
    plot.background = element_rect(fill = "transparent", color = NA),
    legend.background = element_rect(fill = "transparent", color = NA),
    legend.box.background = element_rect(fill = "transparent", color = NA),
    plot.margin = margin(0.1, 0.1, 0.1, 0.1, unit = "cm")
  )


# cf: https://github.com/macarthur-lab/gnomad_lof/blob/master/R/constants.R
get_pop_colors <- function(pop = NULL) {
  color_afr <- "#941494"
  color_amr <- "#ED1E24"
  color_asj <- "coral"
  color_eas <- "#108C44"
  color_eur <- color_nfe <- "#6AA5CD"
  color_fin <- "#002F6C"
  color_mde <- "#33CC33"
  color_mid <- "#EEA9B8"
  color_oth <- "#ABB9B9"
  color_sas <- "#FF9912"

  color_cases <- "darkorange"
  color_controls <- "darkblue"

  pop_colors <- c(
    AFR = color_afr,
    AMR = color_amr,
    ASJ = color_asj,
    CSA = color_sas,
    EAS = color_eas,
    EUR = color_eur,
    FIN = color_fin,
    MDE = color_mde,
    MID = color_mid,
    NFE = color_nfe,
    SAS = color_sas,
    cases = color_cases,
    controls = color_controls,
    Reference = "gray60",
    Remaining = "gray60"
  )

  if (!is.null(pop)) {
    return(pop_colors[pop])
  }
  return(pop_colors)
}


# cf. https://github.com/atgu/ukbb_pan_ancestry/blob/master/plot_ukbb_pca.R
plot_pca <- function(dataset, first_pc, second_pc, color_pop, xlim = NULL, ylim = NULL) {
  pc_biplot <-
    dplyr::arrange(dataset, !!as.symbol(color_pop)) %>%
    ggplot(aes_string(x = first_pc, y = second_pc, color = color_pop)) +
    geom_point(data = dataset %>% filter(!!color_pop %in% c("Reference", "Remaining")), color = "gray60", alpha = 0.2) +
    geom_point(data = dataset %>% filter(!(!!color_pop %in% c("Reference", "Remaining"))), alpha = 0.2) +
    guides(color = guide_legend(override.aes = list(alpha = 1))) +
    plt_theme +
    scale_color_manual(values = get_pop_colors(), name = "Population", na.value = "grey50") +
    coord_cartesian(xlim = xlim, ylim = ylim)
  return(pc_biplot)
}


plot_pca_density <- function(dataset, first_pc, second_pc, xlim = NULL, ylim = NULL) {
  pc_biplot <-
    ggplot(dataset, aes_string(x = first_pc, y = second_pc)) +
    geom_hex(bins = 50) +
    plt_theme +
    scale_fill_gradientn(
      trans = "log", name = "Count",
      colours = rev(RColorBrewer::brewer.pal(5, "Spectral"))
    ) +
    coord_cartesian(xlim = xlim, ylim = ylim)
  return(pc_biplot)
}


save_plots <- function(plots, prefix, pc_num) {
  ggsave(
    sprintf("%s.all.PC1-%d.png", prefix, pc_num),
    plots,
    height = 3 * (pc_num %/% 4 + 1),
    width = 6,
    dpi = 300
  )

  for (i in seq(1, pc_num, by = 2)) {
    ggsave(
      sprintf("%s.PC%d-%d.png", prefix, i, i + 1),
      plots[[(i + 1) / 2]] + theme(
        legend.position = "none",
        axis.title = element_blank(),
        axis.text = element_blank()
      ),
      height = 6,
      width = 6,
      bg = "transparent",
      dpi = 300
    )
  }

  return(NULL)
}

main <- function(args)
{
  plot_pcs <- paste0("PC", seq(args$plot_pc_num))

  # Load reference score
  message(sprintf("Loading --reference-score-file %s", args$reference_score_file))
  reference_score <- data.table::fread(args$reference_score_file)
  reference_range <-
    purrr::map(plot_pcs, function(pc) {
      range(reference_score[[pc]])
    }) %>%
    magrittr::set_names(plot_pcs)
  padding_percent_plot <- 20
  scaling_range_plot <- 1 + padding_percent_plot/100

  # Load projected PCs
  message(sprintf("Loading --sscore %s", args$sscore))
  projected_pc <- data.table::fread(args$sscore, colClasses = list(character = c("#FID", "IID")))
  colnames(projected_pc) <- gsub("^#", "", colnames(projected_pc))
  colnames(projected_pc) <- gsub("_SUM$", "", colnames(projected_pc))
  # available ID cols: PLINK2 now accepts only IID
  id_cols <- intersect(colnames(projected_pc), c("FID", "IID"))

  # Load projected PCs
  message(sprintf("Loading --sscore-vars %s", args$sscore_vars))
  n_sscore_vars <- data.table::fread(args$sscore_vars, header = FALSE) %>%
    nrow()

  # divide by sqrt(n_sscore_vars)
  projected_pc[, plot_pcs] <- projected_pc[, plot_pcs] / sqrt(n_sscore_vars)

  # Load or set ancestry
  if (!is.null(args$ancestry)) {
    projected_pc <- dplyr::mutate(projected_pc, pop = args$ancestry)
  } else {
    message(sprintf("Loading --ancestry-file %s", args$ancestry_file))
    ancestry <-
      data.table::fread(args$ancestry_file, colClasses = list(character = id_cols)) %>%
      dplyr::rename(pop = !!as.symbol(args$ancestry_col)) %>%
      dplyr::select(id_cols, pop)
    projected_pc <- dplyr::left_join(projected_pc, ancestry)
  }

  if (!is.null(args$sequenced)) {
    # Left join with the set of samples that have QCed sequencing data
    seq <- data.table::fread(args$sequenced, colClasses = list(character = id_cols)) %>%
      dplyr::select(id_cols)
    # Only retain samples with sequence information
    projected_pc <- dplyr::inner_join(projected_pc, seq)
  }

  pops <- c("AFR", "AMR", "ASJ", "CSA", "EAS", "EUR", "FIN", "MDE", "MID", "NFE", "SAS")
  reference_score <- reference_score %>% mutate(IID = s, FID = s, pop = "Reference") %>% select(-s)
  projected_pc <- projected_pc %>%  mutate(pop = ifelse(pop %in% pops, pop, "Remaining"))
  score_list <- list(reference = reference_score, projected = projected_pc)
  projected_pc <- data.table::rbindlist(score_list, use.names=TRUE, fill=TRUE)
  projected_pc$pop <- factor(projected_pc$pop, levels = c(pops, "Reference", "Remaining"))

  # Plot PC figures
  plot_all <- function(df, prefix, study, pc_num, reference_range = list()) {
    pcs <- paste0("PC", seq(pc_num))
    pca_pops_only <-
      Reduce(`+`, c(apply(matrix(pcs, ncol = 2, byrow = TRUE), 1, function(pc) {
        plot_pca(df %>% filter(pop != "Remaining"), pc[1], pc[2], "pop",
          xlim = reference_range[[pc[1]]] * scaling_range_plot,
          ylim = reference_range[[pc[2]]] * scaling_range_plot)
      }), list(patchwork::guide_area()))) +
      patchwork::plot_layout(ncol = 2, guides = "collect") +
      patchwork::plot_annotation(
        title = sprintf("%s (by ancestry): # samples = %d, # variants = %d",
          study, nrow(df), n_sscore_vars),
        theme = theme(plot.title = element_text(size = 8))
      )

    pca_no_ref <-
      Reduce(`+`, c(apply(matrix(pcs, ncol = 2, byrow = TRUE), 1, function(pc) {
        plot_pca(df %>% filter(pop != "Reference"), pc[1], pc[2], "pop",
          xlim = reference_range[[pc[1]]] * scaling_range_plot,
          ylim = reference_range[[pc[2]]] * scaling_range_plot)
      }), list(patchwork::guide_area()))) +
      patchwork::plot_layout(ncol = 2, guides = "collect") +
      patchwork::plot_annotation(
        title = sprintf("%s (by ancestry): # samples = %d, # variants = %d",
          study, nrow(df), n_sscore_vars),
        theme = theme(plot.title = element_text(size = 8))
      )

    pca_density <-
      Reduce(`+`, apply(matrix(pcs, ncol = 2, byrow = TRUE), 1, function(pc) {
        plot_pca_density(df %>% filter(pop != "Reference"), pc[1], pc[2],
          xlim = reference_range[[pc[1]]] * scaling_range_plot,
          ylim = reference_range[[pc[2]]] * scaling_range_plot) +
          theme(legend.position = "none")
      })) +
      patchwork::plot_layout(ncol = 2) +
      patchwork::plot_annotation(
        title = sprintf("%s (density): # samples = %d, # variants = %d", study, nrow(df), n_sscore_vars),
        theme = theme(plot.title = element_text(size = 8))
      )

    pca_density_no_remaining <-
      Reduce(`+`, apply(matrix(pcs, ncol = 2, byrow = TRUE), 1, function(pc) {
        plot_pca_density(df %>% filter(!(pop %in% c("Reference", "Remaining"))), pc[1], pc[2],
          xlim = reference_range[[pc[1]]] * scaling_range_plot,
          ylim = reference_range[[pc[2]]] * scaling_range_plot) +
          theme(legend.position = "none")
      })) +
      patchwork::plot_layout(ncol = 2) +
      patchwork::plot_annotation(
        title = sprintf("%s (density): # samples = %d, # variants = %d", study, nrow(df), n_sscore_vars),
        theme = theme(plot.title = element_text(size = 8))
      )

    save_plots(pca_pops_only, paste0(prefix, ".pca.ancestry"), pc_num)
    save_plots(pca_no_ref, paste0(prefix, ".pca.ancestry.no.ref"), pc_num)
    save_plots(
      pca_density,
      paste0(prefix, ".pca.density"),
      pc_num
    )
    save_plots(
      pca_density_no_remaining,
      paste0(prefix, ".pca.pops.density"),
      pc_num
    )
  }

  message("Plotting PC figures...")
  plot_all(
    projected_pc,
    paste0(args$out, ".projected"),
    args$study,
    pc_num = args$plot_pc_num,
    reference_range = reference_range
  )

  # Export per-sample PC values
  if (!args$disable_export) {
    fname <- paste0(args$out, ".projected.pca.tsv.gz")
    message(paste("Removing individual IDs and exporting", fname))
    dplyr::select(projected_pc, -id_cols) %>% 
      data.table::fwrite(fname, sep = "\t")
  }

  warnings()
  message("Successfully finished!")
}

option_list <- list(
  optparse::make_option(
    "--sscore",
    type = "character",
    help = "Path to the PLINK 2's .sscore output",
  ),
  optparse::make_option(
    "--sscore-vars",
    type = "character",
    help = "Path to the PLINK 2's .sscore.vars output",
    dest = "sscore_vars"
  ),
  optparse::make_option(
    "--study",
    type = "character",
    help = "Name of your study",
  ),
  optparse::make_option(
    "--sequenced",
    type = "character",
    help = paste0("Path to the set of samples that were sequenced.",
      "Note that this is included because often there are more genotyped samples (used to define PCs) ",
      "than sequenced samples, so we need to filter to the set of sequenced samples.
      Two columns (IID and FID), with a header.")
  ),
  optparse::make_option(
    "--ancestry",
    type = "character",
    help = "Continental ancestry of participants",
  ),
  optparse::make_option(
    "--ancestry-file",
    type = "character",
    help = "Path to an ancestry file",
    dest = "ancestry_file"
  ),
  optparse::make_option(
    "--ancestry-col",
    type = "character",
    help = "Name of ancestry column",
    dest = "ancestry_col"
  ),
  optparse::make_option(
    "--pc-prefix",
    type = "character",
    default = "PC",
    help = "Prefix of PC columns",
    dest = "pc_prefix"
  ),
  optparse::make_option(
    "--plot-pc-num",
    type = "integer",
    default = 10,
    help = "Number of PCs being plotted",
    dest = "plot_pc_num"
  ),
  optparse::make_option(
    "--reference-score-file",
    type = "character",
    default = "https://storage.googleapis.com/gbmi-public/hgdp_tgp_pca_gbmi_snps_scores.txt.bgz",
    help = "Path to a reference score file [Required if your system doesn't have the Internet access]",
    dest = "reference_score_file"
  ),
  optparse::make_option(
    "--out",
    type = "character",
    help = "Output prefix",
  ),
  optparse::make_option(
    c("--disable-export"),
    action = "store_true",
    default = FALSE,
    help = "Do not export per-sample projected PC values",
    dest = "disable_export"
  )
)

args <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

# Input check
if (is.null(args$sscore)) {
  stop("Please specify --sscore.")
}

if (is.null(args$study)) {
  stop("Please specify --study.")
}

if (is.null(args$sscore_vars)) {
  fname <- paste0(args$sscore, ".vars")
  if (!file.exists(fname)) {
    stop("Please specify --sscore-vars.")
  }
  args$sscore_vars <- fname
}

if (is.null(args$ancestry) & (is.null(args$ancestry_file) | is.null(args$ancestry_col))) {
  stop("Please specify either --ancestry or --ancestry-file and --ancestry-col.")
}

if (is.null(args$reference_score_file)) {
  stop("Please specify --reference-score-file.")
}

# Only plot even number of cohort PCs
args$plot_pc_num <- 2 * args$plot_pc_num %/% 2

if (is.null(args$out)) {
  stop("Please specify --out.")
}

message("Started running with the following args:")
print(args)

main(args)
