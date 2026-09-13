# -*- coding: utf-8 -*-
"""Nature-style presentation layer for the bioinf plot gallery.

Specs distilled from (see series post 7 for the full audit):
  - Nature research figure guide (research-figure-guide.nature.com): 89/183 mm
    widths, 5-7 pt final text, bold lowercase panel letters, no gridlines,
    no red/green-only or rainbow encoding, accessible palette.
  - Yuan1z0825/nature-skills, skill `nature-figure` (design-theory.md,
    figure-legend-conventions.md, qa-contract.md).
  - K-Dense-AI/scientific-agent-skills, skill `scientific-visualization`
    (assets/nature.mplstyle used as the numeric starting point).

Blog adaptation: PNG at 300 dpi instead of vector submission files, and
DejaVu Sans instead of Arial (the render host has no Arial; DejaVu is the
matplotlib-bundled humanist sans with near-identical structure).

Two save()-time passes keep 190 legacy figures consistent without touching
every call site:
  - rescale(): scripts pass explicit fontsize=10-14 (slide-era values);
    rescale() shrinks every text artist into the 5.5-11.5 pt band so the
    figure reads at journal density.
  - panels(): multi-panel figures get bold lowercase letters (a, b, c...)
    at each panel's top-left, skipping colorbar axes and twin axes.
"""
import matplotlib.pyplot as plt

# Okabe-Ito colorblind-safe categorical palette (Okabe & Ito 2008;
# Wong, Nat Methods 8:441, 2011). Ordered for contrast on white.
OKABE = ["#0072B2", "#D55E00", "#009E73", "#CC79A7",
         "#E69F00", "#56B4E9", "#F0E442", "#000000"]

NATURE_RC = {
    "figure.dpi": 110,
    "savefig.dpi": 300,
    "figure.facecolor": "white",
    "font.family": "sans-serif",
    "font.sans-serif": ["DejaVu Sans", "Arial", "Liberation Sans", "Helvetica"],
    "font.size": 8.5,
    "axes.titlesize": 9.5,
    "axes.titlepad": 6.0,
    "axes.labelsize": 8.5,
    "axes.linewidth": 0.6,
    "axes.edgecolor": "#333333",
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": False,
    "axes.axisbelow": True,
    "axes.unicode_minus": False,
    "axes.prop_cycle": plt.cycler("color", OKABE),
    "xtick.labelsize": 7.5,
    "ytick.labelsize": 7.5,
    "xtick.direction": "out",
    "ytick.direction": "out",
    "xtick.major.size": 2.5,
    "xtick.major.width": 0.6,
    "xtick.minor.size": 1.5,
    "xtick.minor.width": 0.4,
    "ytick.major.size": 2.5,
    "ytick.major.width": 0.6,
    "ytick.minor.size": 1.5,
    "ytick.minor.width": 0.4,
    "lines.linewidth": 1.2,
    "lines.markersize": 4.0,
    "lines.markeredgewidth": 0.5,
    "legend.fontsize": 7.5,
    "legend.frameon": False,
    "legend.handlelength": 1.6,
    "legend.borderaxespad": 0.4,
    "image.cmap": "viridis",
}


def apply():
    """Install the Nature-style rcParams (call once, before any figure)."""
    plt.rcParams.update(NATURE_RC)


def _clamp(value, k, lo=5.5, hi=11.5):
    return min(max(value * k, lo), hi)


def rescale(fig, k=0.78):
    """Shrink every explicit text artist into the journal-density band.

    Legacy call sites pass fontsize=8..14 (slide-era values). k=0.78 maps
    12 -> 9.4, 10 -> 7.8, 8 -> 6.2; values already inside the band pass
    through the clamp unchanged-ish. Tick labels are read from the rendered
    artists so per-axes tick_params overrides are honoured too.
    """
    for ax in fig.axes:
        for axis in (ax.xaxis, ax.yaxis):
            sizes = [t.get_fontsize() for t in axis.get_ticklabels()
                     if t.get_text()]
            if sizes:
                axis.set_tick_params(labelsize=_clamp(sizes[0], k))
        for artist in (ax.title, ax.xaxis.label, ax.yaxis.label):
            if artist.get_text():
                artist.set_fontsize(_clamp(artist.get_fontsize(), k))
        leg = ax.get_legend()
        if leg is not None:
            for t in leg.get_texts():
                t.set_fontsize(_clamp(t.get_fontsize(), k))
            if leg.get_title().get_text():
                leg.get_title().set_fontsize(
                    _clamp(leg.get_title().get_fontsize(), k))
        for t in ax.texts:
            t.set_fontsize(_clamp(t.get_fontsize(), k))
    for t in fig.texts:
        if t.get_text():
            t.set_fontsize(_clamp(t.get_fontsize(), k))


def panels(fig, fontsize=8.2):
    """Stamp bold lowercase panel letters (a, b, c...) on multi-panel figs.

    Skips colorbar axes (label '<colorbar>') and twin axes (same bbox as an
    already-stamped axes). Single-axes figures are left unlabeled, matching
    Nature practice for one-panel figures.
    """
    data_axes = [ax for ax in fig.axes if ax.get_label() != "<colorbar>"]
    if len(data_axes) < 2:
        return
    letters = "abcdefghijklmnopqrstuvwxyz"
    seen_pos, idx = set(), 0
    for ax in fig.axes:
        if ax.get_label() == "<colorbar>":
            continue
        bb = ax.get_position()
        key = (round(bb.x0, 3), round(bb.y0, 3), round(bb.x1, 3), round(bb.y1, 3))
        if key in seen_pos:
            continue
        seen_pos.add(key)
        if idx < len(letters):
            ax.text(-0.14, 1.05, letters[idx], transform=ax.transAxes,
                    fontsize=fontsize, fontweight="bold",
                    ha="right", va="bottom")
        idx += 1


def finish(fig):
    """Run both save-time passes (rescale, then panel letters)."""
    rescale(fig)
    panels(fig)


def cell_text_color(cmap, vmin, vmax, value):
    """White or near-black text for a heatmap cell, by fill luminance.

    Annotating cells with fixed dark grey disappears on dark fills (the
    design-theory reference's luminance rule). Works for any cmap.
    """
    r, g, b, _ = cmap(min(max((value - vmin) / (vmax - vmin + 1e-12), 0.0), 1.0))
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    return "#1a1a1a" if lum > 0.45 else "white"
