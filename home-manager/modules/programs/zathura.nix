{ ... }:
{
  programs.zathura = {
    enable = true;
    options = {
      selection-clipboard = "clipboard";
      recolor = "true";
      recolor-keephue = "true";
      statusbar-h-padding = 0;
      statusbar-v-padding = 0;
      page-padding = 1;
      adjust-open = "best-fit";
      pages-per-row = "1";
      scroll-page-aware = "true";
      scroll-full-overlap = "0.01";
      scroll-step = "100";
    };
  };
}
