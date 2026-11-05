# =====================================================================
# SU schools network: figures and tables from the evidence table
# ---------------------------------------------------------------------
# How to run
#   1. Put this file and the CSV files in one folder.
#   2. In R or RStudio:  setwd("path/to/that/folder")
#   3. First time only:  install.packages("igraph")
#   4. Run:              source("network_figures.R")
# Figures and tables are written to a folder called "figures".
#
# STATUS: Maxwell-only mode (maxwell_only <- TRUE, the default) has been run
# successfully in R with the igraph package. Full-network mode
# (maxwell_only <- FALSE) ran in an earlier version, before the dashed-line
# (incidental ties) change, and has not been re-run since.
# =====================================================================

library(igraph)

# ---- 1. Settings you can change ---------------------------------------
include_retired <- TRUE   # FALSE drops rows marked retired == "yes"
include_weak    <- TRUE   # FALSE drops rows marked confidence == "weak"
include_incidental <- TRUE  # FALSE drops ties marked coverage == "incidental" (drawn dashed)
maxwell_only    <- TRUE   # TRUE = only ties that touch Maxwell (the systematic part of the data);
                          # FALSE = the full network with all schools and all tie types
show_counts     <- TRUE   # Maxwell-only mode: print the number of people inside each school's circle
set.seed(42)              # keeps the automatic layout the same on every run

layer_cols   <- c(courtesy = "#1F6FB2", broad = "#E08A1E", program = "#2E9E5B")
layer_labels <- c(courtesy = "Courtesy appointment",
                  broad    = "Second title or center role",
                  program  = "Teaching, advising or course tie")
# Different curvature per layer so parallel lines between the same two
# schools do not sit on top of each other.
layer_curve  <- c(courtesy = 0, broad = 0.25, program = -0.25)

dir.create("figures", showWarnings = FALSE)

# ---- 2. Read the data -------------------------------------------------
nodes    <- read.csv("nodes.csv",          stringsAsFactors = FALSE)
evidence <- read.csv("edges_evidence.csv", stringsAsFactors = FALSE)
centers  <- read.csv("centers.csv",        stringsAsFactors = FALSE)

ev <- evidence
if (!include_retired) ev <- ev[ev$retired != "yes", ]
if (!include_weak)    ev <- ev[ev$confidence != "weak", ]
if (!include_incidental) ev <- ev[ev$coverage != "incidental", ]

# Ties inside one school are not ties between schools.
ev <- ev[ev$school_1 != ev$school_2, ]

# Safety checks: every school id must exist in nodes.csv
stopifnot(all(c(ev$school_1, ev$school_2) %in% nodes$id))
stopifnot(all(centers$school %in% nodes$id))

# ---- 3. One row per school pair and layer; weight = number of people --
# The network is UNDIRECTED: direction is kept in the evidence table
# (home_school, host_school) but is not drawn, because only Maxwell's
# directory was searched thoroughly.
a <- pmin(ev$school_1, ev$school_2)
b <- pmax(ev$school_1, ev$school_2)
edges <- aggregate(list(weight = ev$id),
                   by = list(from = a, to = b, layer = ev$layer,
                             incidental = ev$coverage == "incidental"),
                   FUN = length)

# ---- 4. Helpers -------------------------------------------------------
build_graph <- function(edge_df, node_df) {
  g <- graph_from_data_frame(edge_df, directed = FALSE, vertices = node_df)
  if (ecount(g) > 0) {
    E(g)$color  <- unname(layer_cols[E(g)$layer])
    E(g)$width  <- pmin(1.5 + 1.5 * E(g)$weight, 10)
    E(g)$curved <- unname(layer_curve[E(g)$layer])
    E(g)$lty    <- ifelse(E(g)$incidental, 2, 1)   # dashed = found incidentally
  }
  # number of distinct partner schools (parallel lines count once)
  partners <- sapply(V(g)$name, function(n) length(unique(as_ids(neighbors(g, n)))))
  V(g)$partners <- as.numeric(partners)
  V(g)$size     <- 25 + 3 * V(g)$partners   # big enough to hold the label inside
  V(g)$color    <- ifelse(V(g)$partners == 0, "#E3E3E3", "#FFFFFF")
  g
}

draw_network <- function(g, lay, title, subtitle = NULL,
                         marks = list(), mark_cols = character(0),
                         show_layers = names(layer_cols), file = NULL,
                         isolate_label = "No tie found:",
                         legend_title = "Tie type (line width = number of people)",
                         after_plot = NULL) {
  if (!is.null(file)) png(file, width = 2200, height = 1700, res = 220)
  op <- par(mar = c(5, 1, 3, 1))
  mc <- if (length(mark_cols) > 0) adjustcolor(mark_cols, alpha.f = 0.18) else character(0)
  plot(g, layout = lay,
       vertex.size = V(g)$size, vertex.color = V(g)$color,
       vertex.frame.color = "grey35",
       vertex.label = sub(" ([^ ]+)$", "\n\\1", V(g)$label),   # wrap the last word onto line 2
       vertex.label.color = "black", vertex.label.family = "sans",
       vertex.label.cex = 0.62, vertex.label.dist = 0,          # label centred inside the circle
       edge.color = E(g)$color, edge.width = E(g)$width,
       edge.curved = E(g)$curved, edge.lty = E(g)$lty,
       mark.groups = marks, mark.col = mc, mark.border = mark_cols,
       main = title)
  legend("topleft", legend = unname(layer_labels[show_layers]),
         col = unname(layer_cols[show_layers]), lwd = 4, bty = "n", cex = 0.75,
         title = legend_title)
  if (length(marks) > 0) {
    legend("bottomright", legend = names(marks), fill = mc, border = mark_cols,
           bty = "n", cex = 0.75, title = "Shared center")
  }
  if (!is.null(after_plot)) after_plot()      # e.g. the counts printed inside the circles
  if (!is.null(subtitle)) mtext(subtitle, side = 1, line = 1.5, cex = 0.7)
  isolates <- V(g)$label[V(g)$partners == 0]
  if (length(isolates) > 0) {
    mtext(paste(isolate_label, paste(isolates, collapse = ", ")),
          side = 1, line = 2.5, cex = 0.7)
  }
  if (ecount(g) > 0 && any(E(g)$incidental)) {
    mtext("Dashed lines: found incidentally while reading other pages, not from a systematic search.",
          side = 1, line = 3.5, cex = 0.7)
  }
  par(op)
  if (!is.null(file)) dev.off()
}

caption <- "Maxwell's directory searched systematically; Newhouse's list for advising roles; dashed ties found incidentally."
# What each tie type rests on (printed under each single-layer figure)
layer_captions <- c(
  courtesy = "From the Maxwell faculty directory (all 8 pages). Other schools' directories were not searched for courtesy titles.",
  broad    = "From the Maxwell faculty directory (all 8 pages). Other schools' directories were not searched for second titles.",
  program  = "Newhouse's people list was read for advising roles (7 of 8 resolved); dashed ties were found incidentally.")
layer_isolate <- c(
  courtesy = "None seen (only Maxwell's directory was searched):",
  broad    = "None seen (only Maxwell's directory was searched):",
  program  = "None seen (only Newhouse's list was searched):")

if (maxwell_only) {
  # =====================================================================
  # MAXWELL-ONLY MODE
  # Only ties that touch Maxwell. Every one of them comes from the
  # systematic read of Maxwell's faculty directory (all 8 pages).
  # =====================================================================
  mx <- edges[(edges$from == "MAX" | edges$to == "MAX") &
                edges$layer %in% c("courtesy", "broad"), ]
  mx$partner  <- ifelse(mx$from == "MAX", mx$to, mx$from)
  partners_mx <- sort(unique(mx$partner))

  # Centers that include Maxwell, and the other schools in them
  mx_centers <- unique(centers$center[centers$school == "MAX"])
  mx_members <- setdiff(unique(centers$school[centers$center %in% mx_centers]), "MAX")

  # Ring layout: Maxwell in the middle, schools on a circle. Schools that
  # share a center sit next to each other so the bubbles stay compact.
  ring_deg <- c(AS = 0, FALK = 45, PROF = 90, LAW = 180, ECS = 225, NEW = 270, ISCH = 315)
  ring_r   <- c(ECS = 1.3)    # pushed outward so the bubbles do not clip it
  stopifnot(all(union(partners_mx, mx_members) %in% names(ring_deg)))
  ring_xy <- function(ids) {
    unname(t(sapply(ids, function(i) {
      if (i == "MAX") return(c(0, 0))
      r <- if (i %in% names(ring_r)) ring_r[[i]] else 1
      c(r * cos(ring_deg[[i]] * pi / 180), r * sin(ring_deg[[i]] * pi / 180))
    })))
  }

  # People linking Maxwell to each partner school, by tie type.
  tab <- as.data.frame.matrix(xtabs(weight ~ partner + layer, data = mx))
  partner_counts <- data.frame(school = rownames(tab),
                               label  = nodes$label[match(rownames(tab), nodes$id)],
                               tab, total = rowSums(tab), row.names = NULL)
  partner_counts <- partner_counts[order(-partner_counts$total), ]

  mx_nodes     <- nodes[nodes$id %in% c("MAX", partners_mx), ]
  mx_nodes_ctr <- nodes[nodes$id %in% c("MAX", partners_mx, mx_members), ]

  mx_draw <- function(edge_df, node_df, title, subtitle, show_layers, file,
                      isolate_label, marks = list(), mark_cols = character(0)) {
    g   <- build_graph(edge_df, node_df)
    lay <- ring_xy(V(g)$name)       # these are also the plot coordinates (range -1 to 1)
    after <- NULL
    ltitle <- "Tie type (line width = number of people)"
    if (show_counts) {
      ltitle <- "Tie type (numbers in circles = number of people)"
      after <- function() {
        for (i in seq_len(vcount(g))) {
          id <- V(g)$name[i]
          if (id == "MAX") next
          row <- partner_counts[partner_counts$school == id, ]
          if (nrow(row) == 0) next
          x <- lay[i, 1]; y <- lay[i, 2] - 0.095     # just below the school's name
          if (length(show_layers) == 2) {
            text(x - 0.04, y, row$courtesy, col = layer_cols[["courtesy"]],
                 font = 2, cex = 0.75, family = "sans")
            text(x, y, "|", col = "grey50", cex = 0.75, family = "sans")
            text(x + 0.04, y, row$broad, col = layer_cols[["broad"]],
                 font = 2, cex = 0.75, family = "sans")
          } else if (row[[show_layers]] > 0) {
            text(x, y, row[[show_layers]], col = layer_cols[[show_layers]],
                 font = 2, cex = 0.85, family = "sans")
          }
        }
      }
    }
    draw_network(g, lay, title, subtitle = subtitle,
                 marks = marks, mark_cols = mark_cols, show_layers = show_layers,
                 isolate_label = isolate_label, file = file,
                 legend_title = ltitle, after_plot = after)
  }

  # Figures 1-3: the star, then one figure per tie type
  mx_cap <- "From the Maxwell faculty directory (all 8 pages). Other schools' directories were not searched."
  mx_draw(mx, mx_nodes, "Maxwell and the schools it connects to", mx_cap,
          c("courtesy", "broad"), "figures/maxwell1_star.png", "None seen:")
  for (L in c("courtesy", "broad")) {
    mx_draw(mx[mx$layer == L, ], mx_nodes, paste("Maxwell ties:", layer_labels[[L]]),
            layer_captions[[L]], L,
            file.path("figures", paste0("maxwell2_", L, ".png")), layer_isolate[[L]])
  }

  # Figure 4: the centers that include Maxwell, as bubbles
  sel <- centers$center %in% mx_centers
  marks_mx <- lapply(split(centers$school[sel], centers$center[sel]),
                     function(s) match(s, mx_nodes_ctr$id))
  sig_mx <- sapply(marks_mx, function(m) paste(sort(m), collapse = "-"))
  marks_mx_merged <- list()
  for (s in unique(sig_mx)) {          # centers with identical member schools share one bubble
    idx <- which(sig_mx == s)
    marks_mx_merged[[paste(names(marks_mx)[idx], collapse = " + ")]] <- marks_mx[[idx[1]]]
  }
  pal_mx  <- c("#C0392B", "#16A085", "#8E44AD", "#2C3E50")
  mx_cols <- setNames(rep_len(pal_mx, length(marks_mx_merged)), names(marks_mx_merged))
  bub_cap <- "Centers whose public pages name Maxwell and other schools. A bubble = schools with people affiliated with that center."

  mx_draw(mx, mx_nodes_ctr, "Maxwell's centers shared with other schools", bub_cap,
          c("courtesy", "broad"), "figures/maxwell3_all_bubbles.png",
          "No tie to Maxwell found:", marks = marks_mx_merged, mark_cols = unname(mx_cols))
  for (cn in names(marks_mx_merged)) {
    mx_draw(mx, mx_nodes_ctr, paste("Shared center:", cn), bub_cap,
            c("courtesy", "broad"),
            file.path("figures", paste0("maxwell3_", gsub("[^A-Za-z0-9]+", "_", cn), ".png")),
            "No tie to Maxwell found:",
            marks = marks_mx_merged[cn], mark_cols = unname(mx_cols[cn]))
  }

  # Tables for the slides ------------------------------------------------
  # (a) how many people link Maxwell to each partner school, by tie type
  #     (table built above, before the figures)
  write.csv(partner_counts, "figures/maxwell_partner_counts.csv", row.names = FALSE)

  # (b) pairs of Maxwell's partners: nobody searched for ties between them.
  #     Pairs that share a Maxwell center are the best ones to test first.
  cp <- combn(partners_mx, 2)
  shared <- apply(cp, 2, function(p) {
    cs <- intersect(mx_centers, centers$center[centers$school == p[1]])
    cs <- cs[cs %in% centers$center[centers$school == p[2]]]
    paste(cs, collapse = " + ")
  })
  untested <- data.frame(school_a = cp[1, ], school_b = cp[2, ],
                         shared_maxwell_centers = shared, stringsAsFactors = FALSE)
  untested <- untested[order(untested$shared_maxwell_centers == "", untested$school_a), ]
  write.csv(untested, "figures/maxwell_untested_pairs.csv", row.names = FALSE)

  # (c) schools that share a center with Maxwell but have no Maxwell tie
  nt <- list()
  for (cn in mx_centers) {
    for (s in setdiff(centers$school[centers$center == cn], c("MAX", partners_mx))) {
      nt[[length(nt) + 1]] <- data.frame(center = cn, school = s, stringsAsFactors = FALSE)
    }
  }
  no_tie <- if (length(nt) > 0) do.call(rbind, nt) else
    data.frame(center = character(0), school = character(0))
  write.csv(no_tie, "figures/maxwell_center_members_no_tie.csv", row.names = FALSE)

  print(partner_counts)
  message("Done (Maxwell-only mode). Figures and tables are in the 'figures' folder.")

} else {

# ---- 5. Figure 1: Maxwell and the schools it connects to --------------
max_edges <- edges[edges$from == "MAX" | edges$to == "MAX", ]
max_nodes <- nodes[nodes$id %in% c("MAX", max_edges$from, max_edges$to), ]
g1   <- build_graph(max_edges, max_nodes)
lay1 <- layout_as_star(g1, center = V(g1)["MAX"])
draw_network(g1, lay1, "Maxwell and the schools it connects to",
             subtitle = "From the Maxwell faculty directory (all 8 pages). Other schools' directories were not searched.",
             show_layers = c("courtesy", "broad"),
             file = "figures/figure1_maxwell_star.png")

# ---- 6. Layout shared by all the other figures ------------------------
g_all <- build_graph(edges, nodes)
if (file.exists("layout.csv")) {
  # optional: columns id, x, y to place the schools by hand
  lc <- read.csv("layout.csv", stringsAsFactors = FALSE)
  lay_all <- as.matrix(lc[match(V(g_all)$name, lc$id), c("x", "y")])
} else {
  lay_all <- layout_with_fr(g_all, niter = 2000)
}

# ---- 7. Figure 2: one figure per tie type, then all three together ----
for (L in names(layer_cols)) {
  g_l <- build_graph(edges[edges$layer == L, ], nodes)
  draw_network(g_l, lay_all, paste("Tie type:", layer_labels[[L]]),
               subtitle = layer_captions[[L]], show_layers = L,
               isolate_label = layer_isolate[[L]],
               file = file.path("figures", paste0("figure2_", L, ".png")))
}
draw_network(g_all, lay_all, "All tie types between SU schools",
             subtitle = caption,
             file = "figures/figure2_all_layers.png")

# ---- 8. Figure 3: shared centers drawn as bubbles ---------------------
marks_all <- lapply(split(centers$school, centers$center),
                    function(s) match(s, V(g_all)$name))
pal <- c("#8E44AD", "#C0392B", "#16A085", "#7F8C8D", "#2C3E50", "#D35400")
center_cols <- setNames(rep_len(pal, length(marks_all)), names(marks_all))

# Centers with exactly the same member schools (here IDJC and IJPM) would be
# drawn on top of each other, so the combined figure merges them into one bubble.
sig <- sapply(marks_all, function(m) paste(sort(m), collapse = "-"))
marks_merged <- list()
for (s in unique(sig)) {
  idx <- which(sig == s)
  marks_merged[[paste(names(marks_all)[idx], collapse = " + ")]] <- marks_all[[idx[1]]]
}
merged_cols <- setNames(rep_len(pal, length(marks_merged)), names(marks_merged))

draw_network(g_all, lay_all, "All tie types with all shared centers",
             subtitle = caption,
             marks = marks_merged, mark_cols = unname(merged_cols),
             file = "figures/figure3_all_bubbles.png")

for (cn in names(marks_all)) {
  draw_network(g_all, lay_all, paste("Shared center:", cn),
               subtitle = caption,
               marks = marks_all[cn], mark_cols = unname(center_cols[cn]),
               file = file.path("figures", paste0("figure3_", cn, ".png")))
}

# ---- 9. Tables: centrality, open triads at Maxwell, shared-center gaps -
# One edge per school pair (all layers added up). weights = NA tells igraph
# NOT to treat the counts as distances.
pair_w <- aggregate(list(weight = edges$weight),
                    by = list(from = edges$from, to = edges$to), FUN = sum)
gw <- graph_from_data_frame(pair_w, directed = FALSE, vertices = nodes)

cent <- data.frame(id          = V(gw)$name,
                   label       = V(gw)$label,
                   degree      = degree(gw),
                   strength    = strength(gw, weights = E(gw)$weight),
                   betweenness = betweenness(gw, directed = FALSE, weights = NA),
                   stringsAsFactors = FALSE)
cent <- cent[order(-cent$degree), ]
write.csv(cent, "figures/centrality.csv", row.names = FALSE)
# NOTE: Maxwell's high centrality is partly by design (its directory was
# searched first), so describe it as a feature of the sample, not a finding.

# Open triads at Maxwell: two schools that both tie to Maxwell but not to
# each other (a structural gap).
nb <- as_ids(neighbors(gw, "MAX"))
open_tri <- data.frame(school_a = character(0), school_b = character(0))
if (length(nb) >= 2) {
  cp <- combn(nb, 2)
  is_open <- apply(cp, 2, function(p) !are_adjacent(gw, p[1], p[2]))
  open_tri <- data.frame(school_a = cp[1, is_open], school_b = cp[2, is_open],
                         stringsAsFactors = FALSE)
}
write.csv(open_tri, "figures/open_triads_at_maxwell.csv", row.names = FALSE)

# Schools that share a center but have no direct person-level tie.
gap_rows <- list()
for (cn in unique(centers$center)) {
  m <- centers$school[centers$center == cn]
  if (length(m) < 2) next
  cp <- combn(m, 2)
  for (k in seq_len(ncol(cp))) {
    if (!are_adjacent(gw, cp[1, k], cp[2, k])) {
      gap_rows[[length(gap_rows) + 1]] <-
        data.frame(center = cn, school_a = cp[1, k], school_b = cp[2, k],
                   stringsAsFactors = FALSE)
    }
  }
}
gaps <- if (length(gap_rows) > 0) do.call(rbind, gap_rows) else
  data.frame(center = character(0), school_a = character(0), school_b = character(0))
write.csv(gaps, "figures/shared_center_no_tie.csv", row.names = FALSE)

print(cent)
message("Done. Figures and tables are in the 'figures' folder.")

}   # end of the full-network branch (maxwell_only = FALSE)
