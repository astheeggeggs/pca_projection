# Plot projected PCs

Once `project_pc.sh` finishes, please run `Rscript plot_projected_pc.r` to plot all the projected PCs. This script also generates a text file containing per-sample projected PCs **without including biobank-specific individual IDs**.

## Required packages

To run the script, please install the following packages.

```
install.packages(c("data.table", "hexbin", "optparse", "patchwork", "R.utils", "tidyverse"))
```

## Available options

```
Rscript plot_projected_pc.R \
  --sscore [path to .sscore output] \
  --phenotype-file [path to phenotype file] \
  --phenotype-col [phenotype column name] \
  --covariate-file [path to covariate file] \
  --pc-prefix [prefix of PC columns: default "PC"] \
  --plot-pc-num [number of PCs to plot] \
  --ancestry [ancestry code: AFR, AMR, EAS, EUR, MID, or SAS] \
  --ancestry-file [path to file containing genetic ancestry labels, must contain ID cols (FID, IID)] \
  --ancestry-col [column name in the ancestry file containing ancestry labels] \
  --sequenced [path to file containing the (FID, IID) of samples with sequence data present (since array data is often used to project samples into PC space)]
  --study [your study name] \
  --out [output name prefix]
```

Ancestry codes for `--ancestry` are:

- African (AFR)
- Admixed American (AMR)
- East Asian (EAS)
- European (EUR)
- Middle Eastern (MID)
- South Asian (SAS)

If your cohort contains multiple ancestries, please use `--ancestry-file` and `--ancestry-col` to specify for each individual.

```
  --ancestry-file [path to ancestry file] \
  --ancestry-col [ancestry column name]
```

If your system doesn't have access to the Internet, please download a reference score file [here](https://storage.googleapis.com/gbmi-public/hgdp_tgp_pca_gbmi_snps_scores.txt.bgz) and specify it via `--reference-score-file`.

## Upload

Please upload all the `.png` files and `.projected.pca.tsv.gz` file to the google bucket of your biobank. Detailed instruction can be found **[here](https://docs.google.com/document/d/1emWqbX8ohi-9rYIW_pKSAFiMHZZUV6zyXwg7qWJNdlc/edit?tab=t.0#bookmark=id.1d2ykxtk9nlm)** including the google bucket names for each biobank.
