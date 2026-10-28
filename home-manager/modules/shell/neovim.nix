{ pkgs, ... }:
{
  programs.lazygit.enable = true;

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-unwrapped;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraPackages = with pkgs; [
      ripgrep
      fd
      wl-clipboard
    ];

    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      nvim-web-devicons
      plenary-nvim
      nui-nvim
      telescope-nvim
      telescope-fzf-native-nvim
      neo-tree-nvim
      lazygit-nvim
    ];

    initLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.termguicolors = true
      vim.opt.mouse = "a"
      vim.opt.clipboard = "unnamedplus"
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.signcolumn = "no"
      vim.opt.wrap = false
      vim.opt.scrolloff = 8
      vim.opt.splitright = true
      vim.opt.splitbelow = true
      vim.opt.swapfile = false
      vim.o.winborder = "single"

      vim.cmd.colorscheme("default")

      vim.g.lazygit_floating_window_border_chars = { "┌", "─", "┐", "│", "┘", "─", "└", "│" }

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })

      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
        },
      })
      telescope.load_extension("fzf")

      require("neo-tree").setup({
        close_if_last_window = true,
        popup_border_style = "single",
        filesystem = {
          follow_current_file = { enabled = true },
          filtered_items = { visible = true },
        },
      })

      local builtin = require("telescope.builtin")
      local map = vim.keymap.set
      map("n", "<leader><space>", builtin.find_files, { desc = "Find files" })
      map("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      map("n", "<C-p>", builtin.find_files, { desc = "Find files" })
      map("n", "<leader>/", builtin.live_grep, { desc = "Search text" })
      map("n", "<leader>sg", builtin.live_grep, { desc = "Search text" })
      map("n", "<leader>sw", builtin.grep_string, { desc = "Search word under cursor" })
      map("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
      map("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
      map("n", "<leader>e", "<cmd>Neotree toggle reveal<cr>", { desc = "File tree" })
      map("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "Lazygit" })

      map("n", "<C-h>", "<C-w>h")
      map("n", "<C-j>", "<C-w>j")
      map("n", "<C-k>", "<C-w>k")
      map("n", "<C-l>", "<C-w>l")
      map("n", "<Esc>", "<cmd>nohlsearch<cr>")
    '';
  };
}
